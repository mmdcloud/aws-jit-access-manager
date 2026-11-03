variable "name_prefix" {
  type        = string
  description = "Prefix for resource naming"
}

variable "dynamodb_table_arn" {
  type        = string
  description = "ARN of the DynamoDB table"
}

variable "sns_topic_arn" {
  type        = string
  description = "ARN of the SNS topic"
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of the KMS encryption key"
}

variable "sso_instance_arn" {
  type        = string
  description = "ARN of the IAM Identity Center instance (optional, defaults to wildcard if not provided)"
  default     = "*"
}

variable "revocation_function_name" {
  type        = string
  description = "Name of the revocation Lambda function for scheduler target scoping"
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}

