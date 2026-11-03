variable "name_prefix" {
  type        = string
  description = "Prefix for resource naming"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
}

variable "architecture" {
  type        = string
  description = "Lambda instruction set architecture (x86_64 or arm64)"
  default     = "arm64"
}

variable "lambda_timeout" {
  type        = number
  description = "Lambda function timeout in seconds"
  default     = 30
}

variable "lambda_memory_size" {
  type        = number
  description = "Lambda function memory allocation in MB"
  default     = 256
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention in days"
  default     = 30
}

variable "kms_key_arn" {
  type        = string
  description = "KMS Key ARN for encrypting logs, DLQs and environment variables"
}

variable "request_handler_role_arn" {
  type        = string
  description = "IAM Role ARN for Request Handler Lambda"
}

variable "approval_handler_role_arn" {
  type        = string
  description = "IAM Role ARN for Approval Handler Lambda"
}

variable "revocation_handler_role_arn" {
  type        = string
  description = "IAM Role ARN for Revocation Handler Lambda"
}

variable "scheduler_execution_role_arn" {
  type        = string
  description = "IAM Role ARN for EventBridge Scheduler to assume"
}

variable "dynamodb_table_name" {
  type        = string
  description = "Name of the DynamoDB table"
}

variable "status_index_name" {
  type        = string
  description = "Name of the Status-ExpiryTime GSI"
}

variable "username_index_name" {
  type        = string
  description = "Name of the Username-RequestedTime GSI"
}

variable "sns_topic_arn" {
  type        = string
  description = "ARN of the SNS topic for notifications"
}

variable "sso_instance_arn" {
  type        = string
  description = "ARN of the AWS IAM Identity Center instance"
}

variable "identity_store_id" {
  type        = string
  description = "IAM Identity Center Identity Store ID"
  default     = ""
}

variable "scheduler_group_name" {
  type        = string
  description = "Name of the EventBridge Scheduler schedule group"
}

variable "max_duration_hours" {
  type        = number
  description = "Maximum allowed duration for access requests in hours"
  default     = 8
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}

