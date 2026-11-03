output "api_endpoint" {
  description = "The base endpoint URL of the JIT Access Management HTTP API Gateway"
  value       = module.api_gateway.api_endpoint
}

output "api_id" {
  description = "The ID of the HTTP API Gateway"
  value       = module.api_gateway.api_id
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table tracking JIT access requests"
  value       = module.dynamodb.table_name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = module.dynamodb.table_arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for notifications and alerts"
  value       = module.sns.topic_arn
}

output "kms_key_arn" {
  description = "ARN of the customer managed KMS key encrypting JIT access resources"
  value       = module.kms.key_arn
}

output "sso_instance_arn" {
  description = "IAM Identity Center Instance ARN in use"
  value       = module.identity_center.sso_instance_arn
}

output "identity_store_id" {
  description = "IAM Identity Center Identity Store ID in use"
  value       = module.identity_center.identity_store_id
}

output "sample_admin_permission_set_arn" {
  description = "ARN of sample JIT Admin permission set (if created)"
  value       = module.identity_center.sample_admin_permission_set_arn
}

output "sample_readonly_permission_set_arn" {
  description = "ARN of sample JIT ReadOnly permission set (if created)"
  value       = module.identity_center.sample_readonly_permission_set_arn
}

output "lambda_functions" {
  description = "Names and ARNs of the provisioned Lambda functions"
  value = {
    request_handler = {
      name = module.lambda.request_handler_function_name
      arn  = module.lambda.request_handler_arn
    }
    approval_handler = {
      name = module.lambda.approval_handler_function_name
      arn  = module.lambda.approval_handler_arn
    }
    revocation_handler = {
      name = module.lambda.revocation_handler_function_name
      arn  = module.lambda.revocation_handler_arn
    }
  }
}

output "scheduler_group_name" {
  description = "Name of the EventBridge Scheduler schedule group"
  value       = module.eventbridge.schedule_group_name
}

# ==============================================================================
# Helper curl templates for testing and automation
# ==============================================================================
output "curl_example_create_request" {
  description = "Sample curl command to submit a new JIT access request"
  value       = "curl -X POST ${module.api_gateway.api_endpoint}/requests -H 'Content-Type: application/json' -d '{\"username\":\"john.doe\",\"target_account_id\":\"123456789012\",\"permission_set_arn\":\"arn:aws:sso:::permissionSet/ssoins-xxxx/ps-xxxx\",\"duration_hours\":2,\"reason\":\"Emergency incident INC-1024 database investigation\"}'"
}

output "curl_example_list_requests" {
  description = "Sample curl command to view all active or pending requests"
  value       = "curl -X GET '${module.api_gateway.api_endpoint}/requests?status=PENDING'"
}

output "curl_example_approve_request" {
  description = "Sample curl command to approve a pending request"
  value       = "curl -X POST ${module.api_gateway.api_endpoint}/requests/<REQUEST_ID>/approve -H 'Content-Type: application/json' -d '{\"approver\":\"secops.lead\",\"notes\":\"Approved for incident INC-1024\"}'"
}

output "curl_example_revoke_request" {
  description = "Sample curl command to manually terminate an active session early"
  value       = "curl -X POST ${module.api_gateway.api_endpoint}/requests/<REQUEST_ID>/revoke -H 'Content-Type: application/json' -d '{\"reason\":\"Incident resolved early by engineering\"}'"
}

