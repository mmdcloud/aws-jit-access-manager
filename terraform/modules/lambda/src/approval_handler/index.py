import json
import time
from datetime import datetime, timezone
from typing import Any, Dict

from common.config import (
    IDENTITY_STORE_ID,
    REVOCATION_LAMBDA_ARN,
    SCHEDULER_GROUP_NAME,
    SCHEDULER_ROLE_ARN,
    SSO_INSTANCE_ARN,
    api_response,
    logger
)
from common.db import get_request, update_request_status
from common.notifier import send_notification
from common.scheduler import create_revocation_schedule
from common.sso import get_user_id_by_username, provision_account_assignment


def handle_approve(request_id: str, body: Dict[str, Any]) -> Dict[str, Any]:
    """Approve a pending JIT access request and provision permissions."""
    approver = body.get("approver", "system-admin")
    notes = body.get("notes", "Approved via JIT Access API")

    item = get_request(request_id)
    if not item:
        return api_response(404, {"error": f"Request '{request_id}' not found."})

    current_status = item.get("Status")
    if current_status != "PENDING":
        return api_response(409, {
            "error": f"Request '{request_id}' is in status '{current_status}'. Only PENDING requests can be approved."
        })

    username = item.get("Username")
    # Separation of duties check
    if approver == username:
        return api_response(403, {
            "error": "Separation of duties violation: Requester cannot self-approve their own access request."
        })

    target_account_id = item.get("TargetAccountID")
    permission_set_arn = item.get("PermissionSetArn")
    duration_hours = int(item.get("DurationHours", 1))

    # Resolve User Principal ID
    user_id = item.get("UserId")
    if not user_id or user_id == username:
        if IDENTITY_STORE_ID:
            resolved_id = get_user_id_by_username(IDENTITY_STORE_ID, username)
            if resolved_id:
                user_id = resolved_id

    if not user_id:
        return api_response(400, {
            "error": f"Unable to resolve PrincipalId for username '{username}'. Verify user in Identity Center."
        })

    # Recalculate expiry window starting from approval time
    now = datetime.now(timezone.utc)
    current_epoch = int(now.timestamp())
    expiry_epoch = current_epoch + (duration_hours * 3600)
    expiry_iso = datetime.fromtimestamp(expiry_epoch, timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")

    # 1. Provision IAM Identity Center Account Assignment
    sso_result = provision_account_assignment(
        sso_instance_arn=SSO_INSTANCE_ARN,
        target_account_id=target_account_id,
        permission_set_arn=permission_set_arn,
        principal_id=user_id,
        principal_type="USER"
    )

    if not sso_result.get("success"):
        logger.error(f"SSO provisioning failed: {sso_result}")
        return api_response(502, {
            "error": "Failed to provision IAM Identity Center access assignment.",
            "details": sso_result
        })

    # 2. Schedule automatic revocation via EventBridge Scheduler
    schedule_name = f"jit-expire-{request_id}"
    scheduler_result = create_revocation_schedule(
        schedule_name=schedule_name,
        group_name=SCHEDULER_GROUP_NAME,
        target_lambda_arn=REVOCATION_LAMBDA_ARN,
        scheduler_role_arn=SCHEDULER_ROLE_ARN,
        at_expression=expiry_iso,
        payload={
            "request_id": request_id,
            "action": "EXPIRE",
            "reason": "Scheduled expiration time reached"
        }
    )

    # 3. Update DynamoDB status to ACTIVE
    updated_record = update_request_status(
        request_id=request_id,
        new_status="ACTIVE",
        extra_fields={
            "Approver": approver,
            "ApprovalNotes": notes,
            "ApprovedTime": now.isoformat(),
            "ExpiryTime": expiry_epoch,
            "ExpiryTimeISO": expiry_iso,
            "ScheduleName": schedule_name,
            "SSORequestId": sso_result.get("request_id", ""),
            "UserId": user_id
        }
    )

    # 4. Notify requester and security channel
    send_notification(
        subject="JIT Access Request APPROVED - Temporary Access Granted",
        message_data={
            "EventType": "RequestApproved",
            "RequestID": request_id,
            "Username": username,
            "TargetAccount": target_account_id,
            "PermissionSet": permission_set_arn,
            "Approver": approver,
            "Status": "ACTIVE",
            "ActiveUntil": f"{expiry_iso} UTC",
            "Duration": f"{duration_hours} hour(s)"
        }
    )

    return api_response(200, {
        "message": f"Request '{request_id}' approved. Access granted until {expiry_iso} UTC.",
        "request": updated_record,
        "scheduler": scheduler_result
    })


def handle_reject(request_id: str, body: Dict[str, Any]) -> Dict[str, Any]:
    """Reject a pending JIT access request."""
    approver = body.get("approver", "system-admin")
    rejection_reason = body.get("reason", "Request rejected by approver.")

    item = get_request(request_id)
    if not item:
        return api_response(404, {"error": f"Request '{request_id}' not found."})

    current_status = item.get("Status")
    if current_status != "PENDING":
        return api_response(409, {
            "error": f"Request '{request_id}' is in status '{current_status}'. Only PENDING requests can be rejected."
        })

    now = datetime.now(timezone.utc)
    updated_record = update_request_status(
        request_id=request_id,
        new_status="REJECTED",
        extra_fields={
            "Approver": approver,
            "RejectionReason": rejection_reason,
            "RejectedTime": now.isoformat()
        }
    )

    send_notification(
        subject="JIT Access Request REJECTED",
        message_data={
            "EventType": "RequestRejected",
            "RequestID": request_id,
            "Username": item.get("Username"),
            "TargetAccount": item.get("TargetAccountID"),
            "Approver": approver,
            "RejectionReason": rejection_reason,
            "Status": "REJECTED"
        }
    )

    return api_response(200, {
        "message": f"Request '{request_id}' has been rejected.",
        "request": updated_record
    })


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Lambda entry point for JIT Approval Handler."""
    logger.info(f"Received approval event: {json.dumps(event, default=str)}")
    path = event.get("rawPath", event.get("path", ""))
    path_params = event.get("pathParameters") or {}
    request_id = path_params.get("id")

    if not request_id:
        return api_response(400, {"error": "Missing 'id' parameter in request path."})

    body_raw = event.get("body", "{}")
    body = json.loads(body_raw) if isinstance(body_raw, str) else (body_raw or {})

    try:
        if path.endswith("/approve"):
            return handle_approve(request_id, body)
        elif path.endswith("/reject"):
            return handle_reject(request_id, body)
        else:
            return api_response(400, {"error": "Invalid action. Supported paths are /approve and /reject."})
    except Exception as e:
        logger.exception(f"Unhandled error in approval handler: {e}")
        return api_response(500, {"error": "Internal server error", "details": str(e)})

