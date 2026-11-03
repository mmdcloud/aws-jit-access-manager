import json
from typing import Any, Dict
import boto3
from botocore.exceptions import ClientError
from .config import SNS_TOPIC_ARN, logger

sns = boto3.client("sns")


def send_notification(subject: str, message_data: Dict[str, Any]) -> bool:
    """
    Publish a structured alert notification to the SNS topic.
    """
    if not SNS_TOPIC_ARN:
        logger.warning("No SNS_TOPIC_ARN configured; skipping notification")
        return False

    formatted_body = (
        f"{subject}\n"
        f"{'=' * len(subject)}\n\n"
    )
    for key, value in message_data.items():
        formatted_body += f"- {key}: {value}\n"

    try:
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f"[JIT Access] {subject[:80]}",
            Message=formatted_body,
            MessageAttributes={
                "EventType": {
                    "DataType": "String",
                    "StringValue": message_data.get("EventType", "Alert")
                }
            }
        )
        logger.info(f"Published notification for '{subject}'")
        return True
    except ClientError as e:
        logger.error(f"Failed to publish SNS notification: {e}")
        return False

