import json
import time
from datetime import datetime, timezone
from typing import Any, Dict, List

from common.config import (
    SCHEDULER_GROUP_NAME,
    SSO_INSTANCE_ARN,
    api_response,
    logger
)
from common.db import get_request, query_active_expired_requests, update_request_status
from common.notifier import send_notification
from common.scheduler import delete_revocation_schedule
from common.sso import deprovision_account_assignment


def revoke_single_request(request_id: str, trigger_reason: str, final_status: str = "EXPIRED") -> Dict[str, Any]:
    """
    Core function to deprovision an active JIT assignment and update its state.
    """
    logger.info(f"Initiating revocation for request '{request_id}' with reason: {trigger_reason}")
    item = get_request(request_id)
    if not item:
        logger.warning(f"Request '{request_id}' not found in DynamoDB")
        return {"success": False, "error": f"Request '{request_id}' not found."}

    current_status = item.get("Status")
    if current_status not in ["ACTIVE", "APPROVED"]:
        logger.info(f"Request '{request_id}' is already in '{current_status}' status. No action needed.")
        return {"success": True, "status": current_status, "message": "Already inactive."}

    target_account_id = item.get("TargetAccountID")
    permission_set_arn = item.get("PermissionSetArn")
    user_id = item.get("UserId") or item.get("Username")

    # 1. Deprovision IAM Identity Center Account Assignment
    sso_result = deprovision_account_assignment(
        sso_instance_arn=SSO_INSTANCE_ARN,
        target_account_id=target_account_id,
        permission_set_arn=permission_set_arn,
        principal_id=user_id,
        principal_type="USER"
    )

    now = datetime.now(timezone.utc)

    # 2. Delete the EventBridge Scheduler schedule if one was registered
    schedule_name = item.get("ScheduleName")
    if schedule_name:
        delete_revocation_schedule(schedule_name, SCHEDULER_GROUP_NAME)

    # 3. Update DynamoDB status
    updated_record = update_request_status(
        request_id=request_id,
        new_status=final_status,
        extra_fields={
            "RevocationReason": trigger_reason,
            "RevokedTime": now.isoformat(),
            "SSORevokeRequestId": sso_result.get("request_id", "")
        }
    )

    # 4. Notify security and user
    send_notification(
        subject=f"JIT Access Temporary Session TERMINATED ({final_status})",
        message_data={
            "EventType": "AccessRevoked",
            "RequestID": request_id,
            "Username": item.get("Username"),
            "TargetAccount": target_account_id,
            "PermissionSet": permission_set_arn,
            "FinalStatus": final_status,
            "Reason": trigger_reason,
            "RevokedAt": now.isoformat()
        }
    )

    logger.info(f"Successfully revoked request '{request_id}' to status '{final_status}'")
    return {
        "success": True,
        "request_id": request_id,
        "final_status": final_status,
        "sso_result": sso_result
    }


def handle_sweeper() -> Dict[str, Any]:
    """
    Fail-safe reconciliation sweeper triggered periodically by EventBridge Rule.
    Scans for any ACTIVE requests where ExpiryTime has passed.
    """
    now_epoch = int(time.time())
    logger.info(f"Running periodic reconciliation sweeper at epoch {now_epoch}")
    overdue_requests = query_active_expired_requests(now_epoch)

    results: List[Dict[str, Any]] = []
    for item in overdue_requests:
        req_id = item["RequestID"]
        logger.info(f"Sweeper found overdue active request: {req_id}")
        res = revoke_single_request(
            request_id=req_id,
            trigger_reason="Reconciliation sweeper detected expired session",
            final_status="EXPIRED"
        )
        results.append(res)

    logger.info(f"Sweeper finished. Processed {len(results)} expired requests.")
    return {"swept_count": len(results), "results": results}


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Multi-source handler for revocation:
    - EventBridge Scheduler (one-time dynamic trigger)
    - EventBridge Rule (periodic sweeper cron)
    - API Gateway (manual early revocation)
    """
    logger.info(f"Received revocation event: {json.dumps(event, default=str)}")

    # Check if triggered by EventBridge Sweeper
    if event.get("action") == "SWEEP" or event.get("source") == "aws.events":
        result = handle_sweeper()
        return api_response(200, result)

    # Check if triggered by EventBridge Scheduler for a specific request
    if "request_id" in event and event.get("action") == "EXPIRE":
        req_id = event["request_id"]
        reason = event.get("reason", "Scheduled session window expired")
        result = revoke_single_request(req_id, reason, final_status="EXPIRED")
        return api_response(200, result)

    # Check if triggered by API Gateway HTTP request (e.g., POST /requests/{id}/revoke)
    path_params = event.get("pathParameters") or {}
    if "id" in path_params:
        req_id = path_params["id"]
        body_raw = event.get("body", "{}")
        body = json.loads(body_raw) if isinstance(body_raw, str) else (body_raw or {})
        reason = body.get("reason", "Manual early revocation requested by operator")
        result = revoke_single_request(req_id, reason, final_status="REVOKED")
        if not result.get("success") and "not found" in result.get("error", ""):
            return api_response(404, result)
        return api_response(200, result)

    logger.warning("Unrecognized revocation trigger payload")
    return api_response(400, {"error": "Invalid revocation trigger payload."})

