variable "aws_region" {
  type        = string
  description = "AWS Region for deploying JIT Access Manager infrastructure"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Target deployment environment (dev, staging, prod)"
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod", "test"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod, test."
  }
}

variable "project_name" {
  type        = string
  description = "Project identifier used in resource naming and tags"
  default     = "jit-access-manager"
}

variable "dynamodb_table_name" {
  type        = string
  description = "Name of the DynamoDB table for tracking JIT access requests"
  default     = "JITAccessRequests"
}

variable "dynamodb_billing_mode" {
  type        = string
  description = "DynamoDB billing mode (PAY_PER_REQUEST or PROVISIONED)"
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.dynamodb_billing_mode)
    error_message = "Billing mode must be either PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "point_in_time_recovery_enabled" {
  type        = bool
  description = "Enable point-in-time recovery for the DynamoDB table"
  default     = true
}

variable "deletion_protection_enabled" {
  type        = bool
  description = "Enable deletion protection on the DynamoDB table"
  default     = false
}

variable "notification_emails" {
  type        = list(string)
  description = "List of administrator/security team emails to receive JIT access notifications"
  default     = []
}

variable "sso_instance_arn" {
  type        = string
  description = "IAM Identity Center Instance ARN. If omitted, will be auto-discovered via data source."
  default     = ""
}

variable "identity_store_id" {
  type        = string
  description = "IAM Identity Center Identity Store ID. If omitted, will be auto-discovered via data source."
  default     = ""
}

variable "create_sample_permission_sets" {
  type        = bool
  description = "Set to true to create sample JIT Permission Sets (Admin, ReadOnly) in IAM Identity Center"
  default     = false
}

variable "max_duration_hours" {
  type        = number
  description = "Maximum permitted duration for temporary access in hours (1-24)"
  default     = 8

  validation {
    condition     = var.max_duration_hours >= 1 && var.max_duration_hours <= 24
    error_message = "max_duration_hours must be between 1 and 24 hours."
  }
}

variable "log_retention_days" {
  type        = number
  description = "Retention period for CloudWatch Logs in days"
  default     = 30
}

variable "lambda_architecture" {
  type        = string
  description = "Instruction set architecture for Lambda functions (arm64 or x86_64)"
  default     = "arm64"

  validation {
    condition     = contains(["arm64", "x86_64"], var.lambda_architecture)
    error_message = "lambda_architecture must be either arm64 or x86_64."
  }
}

variable "sweeper_schedule_expression" {
  type        = string
  description = "Schedule expression for periodic reconciliation sweeper (e.g. rate(5 minutes))"
  default     = "rate(5 minutes)"
}

variable "cors_allowed_origins" {
  type        = list(string)
  description = "Allowed CORS origins for API Gateway"
  default     = ["*"]
}

variable "throttling_rate_limit" {
  type        = number
  description = "API Gateway throttling rate limit in requests/second"
  default     = 100
}

variable "throttling_burst_limit" {
  type        = number
  description = "API Gateway throttling burst limit"
  default     = 200
}

variable "kms_deletion_window_in_days" {
  type        = number
  description = "KMS Key deletion window in days"
  default     = 30
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources"
  default     = {}
}

