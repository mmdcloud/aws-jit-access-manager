import json
import re
import time
import uuid
from datetime import datetime, timezone
from typing import Any, Dict

from common.config import (
    IDENTITY_STORE_ID,
    MAX_DURATION_HOURS,
    api_response,
    logger
)
from common.db import (
    get_request,
    query_requests_by_status,
    query_requests_by_user,
    save_request,
    scan_all_requests
)
from common.notifier import send_notification
from common.sso import get_user_id_by_username


def validate_request_payload(body: Dict[str, Any]) -> tuple[bool, str]:
    """Validate required input fields and constraints."""
    required = ["username", "target_account_id", "permission_set_arn", "duration_hours", "reason"]
    for field in required:
        if field not in body or not body[field]:
            return False, f"Missing required field: '{field}'"

    # Validate target account ID format (12-digit AWS account)
    account_id = str(body["target_account_id"]).strip()
    if not re.match(r"^\d{12}$", account_id):
        return False, "Invalid 'target_account_id'. Must be a 12-digit AWS account ID."

    # Validate duration
    try:
        duration = int(body["duration_hours"])
        if duration <= 0 or duration > MAX_DURATION_HOURS:
            return False, f"'duration_hours' must be between 1 and {MAX_DURATION_HOURS}."
    except (ValueError, TypeError):
        return False, "'duration_hours' must be an integer."

    # Validate reason length
    if len(str(body["reason"]).strip()) < 5:
        return False, "'reason' must be at least 5 characters describing the business justification."

    return True, ""


def handle_post_request(body: Dict[str, Any]) -> Dict[str, Any]:
    """Process new access request submission."""
    is_valid, error_msg = validate_request_payload(body)
    if not is_valid:
        return api_response(400, {"error": error_msg})

    username = str(body["username"]).strip()
    target_account_id = str(body["target_account_id"]).strip()
    permission_set_arn = str(body["permission_set_arn"]).strip()
    duration_hours = int(body["duration_hours"])
    reason = str(body["reason"]).strip()

    # Verify user exists in IAM Identity Center IdentityStore
    user_id = None
    if IDENTITY_STORE_ID:
        user_id = get_user_id_by_username(IDENTITY_STORE_ID, username)
        if not user_id:
            logger.warning(f"Username '{username}' not found in Identity Store")

    request_id = f"jit-{uuid.uuid4().hex[:10]}"
    now = datetime.now(timezone.utc)
    current_epoch = int(now.timestamp())
    expiry_epoch = current_epoch + (duration_hours * 3600)
    expiry_iso = datetime.fromtimestamp(expiry_epoch, timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")

    # Keep record for 30 days after expiry for compliance audit trail
    ttl_epoch = expiry_epoch + (30 * 86400)

    item = {
        "RequestID": request_id,
        "Username": username,
        "UserId": user_id or username,
        "TargetAccountID": target_account_id,
        "PermissionSetArn": permission_set_arn,
        "DurationHours": duration_hours,
        "Reason": reason,
        "Status": "PENDING",
        "RequestedTime": now.isoformat(),
        "ExpiryTime": expiry_epoch,
        "ExpiryTimeISO": expiry_iso,
        "TTL": ttl_epoch
    }

    save_request(item)

    # Publish notification to approvers
    send_notification(
        subject="New JIT Access Request Submitted",
        message_data={
            "EventType": "RequestSubmitted",
            "RequestID": request_id,
            "Username": username,
            "TargetAccount": target_account_id,
            "PermissionSet": permission_set_arn,
            "DurationHours": f"{duration_hours} hour(s)",
            "Reason": reason,
            "Status": "PENDING",
            "RequestedAt": now.isoformat()
        }
    )

    return api_response(201, {
        "message": "JIT access request submitted successfully. Awaiting approval.",
        "request": item
    })


def handle_get_request(path_params: Dict[str, Any], query_params: Dict[str, Any]) -> Dict[str, Any]:
    """Handle retrieving access requests."""
    # Check if querying single request by ID
    if path_params and "id" in path_params:
        req_id = path_params["id"]
        item = get_request(req_id)
        if not item:
            return api_response(404, {"error": f"Request '{req_id}' not found."})
        return api_response(200, {"request": item})

    # Query list
    query_params = query_params or {}
    limit = int(query_params.get("limit", 50))

    if "status" in query_params:
        items = query_requests_by_status(query_params["status"].upper(), limit=limit)
    elif "username" in query_params:
        items = query_requests_by_user(query_params["username"], limit=limit)
    else:
        items = scan_all_requests(limit=limit)

    return api_response(200, {"count": len(items), "requests": items})


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Lambda entry point for JIT Access Request Handler."""
    logger.info(f"Received event: {json.dumps(event, default=str)}")
    http_method = event.get("requestContext", {}).get("http", {}).get("method", event.get("httpMethod", "GET"))

    path_params = event.get("pathParameters") or {}
    query_params = event.get("queryStringParameters") or {}

    try:
        if http_method == "POST":
            body_raw = event.get("body", "{}")
            body = json.loads(body_raw) if isinstance(body_raw, str) else body_raw
            return handle_post_request(body)
        elif http_method == "GET":
            return handle_get_request(path_params, query_params)
        else:
            return api_response(405, {"error": f"Method {http_method} not allowed."})
    except Exception as e:
        logger.exception(f"Unhandled error processing request: {e}")
        return api_response(500, {"error": "Internal server error", "details": str(e)})

