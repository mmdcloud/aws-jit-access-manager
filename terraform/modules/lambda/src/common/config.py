import json
import logging
import os
import sys
from typing import Any, Dict

# Configure structured logging
logger = logging.getLogger("jit_access_manager")
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO").upper())

if not logger.handlers:
    handler = logging.StreamHandler(sys.stdout)
    formatter = logging.Formatter(
        json.dumps({
            "timestamp": "%(asctime)s",
            "level": "%(levelname)s",
            "name": "%(name)s",
            "message": "%(message)s"
        })
    )
    handler.setFormatter(formatter)
    logger.addHandler(handler)

# Configuration values from environment
DYNAMODB_TABLE = os.environ.get("DYNAMODB_TABLE", "JITAccessRequests")
STATUS_INDEX = os.environ.get("STATUS_INDEX", "Status-ExpiryTime-Index")
USER_INDEX = os.environ.get("USER_INDEX", "Username-RequestedTime-Index")
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN", "")
SSO_INSTANCE_ARN = os.environ.get("SSO_INSTANCE_ARN", "")
IDENTITY_STORE_ID = os.environ.get("IDENTITY_STORE_ID", "")
SCHEDULER_GROUP_NAME = os.environ.get("SCHEDULER_GROUP_NAME", "default")
SCHEDULER_ROLE_ARN = os.environ.get("SCHEDULER_ROLE_ARN", "")
REVOCATION_LAMBDA_ARN = os.environ.get("REVOCATION_LAMBDA_ARN", "")
MAX_DURATION_HOURS = int(os.environ.get("MAX_DURATION_HOURS", "8"))
AUTO_APPROVAL_ENABLED = os.environ.get("AUTO_APPROVAL_ENABLED", "false").lower() == "true"


def api_response(status_code: int, body: Any) -> Dict[str, Any]:
    """Format standardized API Gateway HTTP response."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "OPTIONS,GET,POST",
            "Access-Control-Allow-Headers": "Content-Type,Authorization"
        },
        "body": json.dumps(body, default=str)
    }

