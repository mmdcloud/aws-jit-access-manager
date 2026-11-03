variable "name_prefix" {
  type        = string
  description = "Prefix for resource naming"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
}

variable "request_handler_arn" {
  type        = string
  description = "ARN of the Request Handler Lambda function"
}

variable "request_handler_name" {
  type        = string
  description = "Name of the Request Handler Lambda function"
}

variable "approval_handler_arn" {
  type        = string
  description = "ARN of the Approval Handler Lambda function"
}

variable "approval_handler_name" {
  type        = string
  description = "Name of the Approval Handler Lambda function"
}

variable "revocation_handler_arn" {
  type        = string
  description = "ARN of the Revocation Handler Lambda function"
}

variable "revocation_handler_name" {
  type        = string
  description = "Name of the Revocation Handler Lambda function"
}

variable "kms_key_arn" {
  type        = string
  description = "KMS Key ARN for encrypting API access logs"
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention in days for API Gateway access logs"
  default     = 30
}

variable "throttling_rate_limit" {
  type        = number
  description = "API Gateway default route throttling rate limit (requests/sec)"
  default     = 100
}

variable "throttling_burst_limit" {
  type        = number
  description = "API Gateway default route throttling burst limit"
  default     = 200
}

variable "cors_allowed_origins" {
  type        = list(string)
  description = "List of allowed CORS origins"
  default     = ["*"]
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}

