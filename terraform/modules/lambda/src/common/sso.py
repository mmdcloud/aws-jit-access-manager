from typing import Any, Dict, Optional
import boto3
from botocore.exceptions import ClientError
from .config import logger

sso_admin = boto3.client("sso-admin")
identity_store = boto3.client("identitystore")


def get_user_id_by_username(identity_store_id: str, username: str) -> Optional[str]:
    """
    Look up user in IAM Identity Center Identity Store by UserName.
    Returns the UserId (PrincipalId) if found, otherwise None.
    """
    if not identity_store_id:
        logger.warning("No IDENTITY_STORE_ID configured; cannot look up user in identity store")
        return None

    try:
        response = identity_store.list_users(
            IdentityStoreId=identity_store_id,
            Filters=[
                {
                    "AttributePath": "UserName",
                    "AttributeValue": username
                }
            ]
        )
        users = response.get("Users", [])
        if users:
            user_id = users[0]["UserId"]
            logger.info(f"Resolved username '{username}' to UserId '{user_id}'")
            return user_id
        logger.warning(f"No user found matching username '{username}'")
        return None
    except ClientError as e:
        logger.error(f"Error querying IdentityStore for user '{username}': {e}")
        return None


def provision_account_assignment(
    sso_instance_arn: str,
    target_account_id: str,
    permission_set_arn: str,
    principal_id: str,
    principal_type: str = "USER"
) -> Dict[str, Any]:
    """
    Call sso-admin CreateAccountAssignment to grant temporary access.
    """
    logger.info(
        f"Provisioning access: Principal={principal_id} TargetAccount={target_account_id} "
        f"PermissionSet={permission_set_arn}"
    )
    try:
        response = sso_admin.create_account_assignment(
            InstanceArn=sso_instance_arn,
            TargetId=target_account_id,
            TargetType="AWS_ACCOUNT",
            PermissionSetArn=permission_set_arn,
            PrincipalType=principal_type,
            PrincipalId=principal_id
        )
        status_info = response.get("AccountAssignmentCreationStatus", {})
        logger.info(f"Provisioning response: {status_info}")
        return {
            "success": True,
            "status": status_info.get("Status", "IN_PROGRESS"),
            "request_id": status_info.get("RequestId")
        }
    except ClientError as e:
        error_code = e.response.get("Error", {}).get("Code", "Unknown")
        error_msg = e.response.get("Error", {}).get("Message", str(e))
        logger.error(f"Failed to create account assignment: [{error_code}] {error_msg}")
        # If already exists, consider successful
        if error_code == "ConflictException":
            return {"success": True, "status": "ALREADY_EXISTS", "message": error_msg}
        return {"success": False, "error_code": error_code, "message": error_msg}


def deprovision_account_assignment(
    sso_instance_arn: str,
    target_account_id: str,
    permission_set_arn: str,
    principal_id: str,
    principal_type: str = "USER"
) -> Dict[str, Any]:
    """
    Call sso-admin DeleteAccountAssignment to revoke temporary access.
    """
    logger.info(
        f"Deprovisioning access: Principal={principal_id} TargetAccount={target_account_id} "
        f"PermissionSet={permission_set_arn}"
    )
    try:
        response = sso_admin.delete_account_assignment(
            InstanceArn=sso_instance_arn,
            TargetId=target_account_id,
            TargetType="AWS_ACCOUNT",
            PermissionSetArn=permission_set_arn,
            PrincipalType=principal_type,
            PrincipalId=principal_id
        )
        status_info = response.get("AccountAssignmentDeletionStatus", {})
        logger.info(f"Deprovisioning response: {status_info}")
        return {
            "success": True,
            "status": status_info.get("Status", "IN_PROGRESS"),
            "request_id": status_info.get("RequestId")
        }
    except ClientError as e:
        error_code = e.response.get("Error", {}).get("Code", "Unknown")
        error_msg = e.response.get("Error", {}).get("Message", str(e))
        logger.error(f"Failed to delete account assignment: [{error_code}] {error_msg}")
        if error_code == "ResourceNotFoundException":
            return {"success": True, "status": "ALREADY_DELETED", "message": error_msg}
        return {"success": False, "error_code": error_code, "message": error_msg}

