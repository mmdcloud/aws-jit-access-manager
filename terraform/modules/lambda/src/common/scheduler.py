import json
from typing import Any, Dict
import boto3
from botocore.exceptions import ClientError
from .config import logger

scheduler = boto3.client("scheduler")


def create_revocation_schedule(
    schedule_name: str,
    group_name: str,
    target_lambda_arn: str,
    scheduler_role_arn: str,
    at_expression: str,
    payload: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Create a one-time EventBridge Scheduler schedule targeting the revocation Lambda.
    ActionAfterCompletion='DELETE' ensures automatic cleanup after firing.
    """
    logger.info(
        f"Creating EventBridge schedule '{schedule_name}' in group '{group_name}' "
        f"at expression '{at_expression}'"
    )
    try:
        response = scheduler.create_schedule(
            Name=schedule_name,
            GroupName=group_name,
            ScheduleExpression=f"at({at_expression})",
            ScheduleExpressionTimezone="UTC",
            FlexibleTimeWindow={"Mode": "OFF"},
            Target={
                "Arn": target_lambda_arn,
                "RoleArn": scheduler_role_arn,
                "Input": json.dumps(payload),
                "RetryPolicy": {
                    "MaximumEventAgeInSeconds": 3600,
                    "MaximumRetryAttempts": 3
                }
            },
            ActionAfterCompletion="DELETE"
        )
        logger.info(f"Schedule created successfully: {response.get('ScheduleArn')}")
        return {"success": True, "schedule_arn": response.get("ScheduleArn")}
    except ClientError as e:
        error_code = e.response.get("Error", {}).get("Code", "Unknown")
        error_msg = e.response.get("Error", {}).get("Message", str(e))
        logger.error(f"Failed to create EventBridge schedule: [{error_code}] {error_msg}")
        return {"success": False, "error_code": error_code, "message": error_msg}


def delete_revocation_schedule(schedule_name: str, group_name: str) -> bool:
    """
    Delete an EventBridge Scheduler schedule (e.g., when manually revoked or already fired).
    """
    logger.info(f"Deleting EventBridge schedule '{schedule_name}' from group '{group_name}'")
    try:
        scheduler.delete_schedule(Name=schedule_name, GroupName=group_name)
        return True
    except ClientError as e:
        error_code = e.response.get("Error", {}).get("Code", "Unknown")
        if error_code == "ResourceNotFoundException":
            logger.info(f"Schedule '{schedule_name}' already removed or expired")
            return True
        logger.warning(f"Error deleting schedule '{schedule_name}': {e}")
        return False

