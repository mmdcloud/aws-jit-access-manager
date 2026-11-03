import time
from typing import Any, Dict, List, Optional
import boto3
from boto3.dynamodb.conditions import Key
from .config import DYNAMODB_TABLE, STATUS_INDEX, USER_INDEX, logger

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(DYNAMODB_TABLE)


def save_request(item: Dict[str, Any]) -> None:
    """Save a new JIT access request item."""
    logger.info(f"Saving request {item.get('RequestID')} for user {item.get('Username')}")
    table.put_item(Item=item)


def get_request(request_id: str) -> Optional[Dict[str, Any]]:
    """Retrieve an access request by RequestID."""
    logger.info(f"Fetching request {request_id}")
    response = table.get_item(Key={"RequestID": request_id})
    return response.get("Item")


def update_request_status(
    request_id: str,
    new_status: str,
    extra_fields: Optional[Dict[str, Any]] = None
) -> Dict[str, Any]:
    """
    Update the status of an access request and optionally merge additional attributes.
    """
    logger.info(f"Updating request {request_id} status to {new_status}")
    update_expr = "SET #s = :status, UpdatedTime = :updated_time"
    expr_names = {"#s": "Status"}
    expr_values = {
        ":status": new_status,
        ":updated_time": int(time.time())
    }

    if extra_fields:
        for k, v in extra_fields.items():
            attr_alias = f"#{k}"
            val_alias = f":{k}"
            update_expr += f", {attr_alias} = {val_alias}"
            expr_names[attr_alias] = k
            expr_values[val_alias] = v

    response = table.update_item(
        Key={"RequestID": request_id},
        UpdateExpression=update_expr,
        ExpressionAttributeNames=expr_names,
        ExpressionAttributeValues=expr_values,
        ReturnValues="ALL_NEW"
    )
    return response.get("Attributes", {})


def query_active_expired_requests(current_epoch: int) -> List[Dict[str, Any]]:
    """
    Query the Status-ExpiryTime-Index for ACTIVE requests whose ExpiryTime <= current_epoch.
    Used by the reconciliation sweeper to clean up any overdue sessions.
    """
    logger.info(f"Querying active expired requests where ExpiryTime <= {current_epoch}")
    response = table.query(
        IndexName=STATUS_INDEX,
        KeyConditionExpression=Key("Status").eq("ACTIVE") & Key("ExpiryTime").lte(current_epoch)
    )
    items = response.get("Items", [])
    while "LastEvaluatedKey" in response:
        response = table.query(
            IndexName=STATUS_INDEX,
            KeyConditionExpression=Key("Status").eq("ACTIVE") & Key("ExpiryTime").lte(current_epoch),
            ExclusiveStartKey=response["LastEvaluatedKey"]
        )
        items.extend(response.get("Items", []))
    return items


def query_requests_by_status(status: str, limit: int = 50) -> List[Dict[str, Any]]:
    """Query requests by Status using Status-ExpiryTime-Index."""
    logger.info(f"Querying requests with status {status}")
    response = table.query(
        IndexName=STATUS_INDEX,
        KeyConditionExpression=Key("Status").eq(status),
        ScanIndexForward=False,
        Limit=limit
    )
    return response.get("Items", [])


def query_requests_by_user(username: str, limit: int = 50) -> List[Dict[str, Any]]:
    """Query requests by Username using Username-RequestedTime-Index."""
    logger.info(f"Querying requests for user {username}")
    response = table.query(
        IndexName=USER_INDEX,
        KeyConditionExpression=Key("Username").eq(username),
        ScanIndexForward=False,
        Limit=limit
    )
    return response.get("Items", [])


def scan_all_requests(limit: int = 50) -> List[Dict[str, Any]]:
    """Scan latest requests across all statuses."""
    response = table.scan(Limit=limit)
    return response.get("Items", [])

