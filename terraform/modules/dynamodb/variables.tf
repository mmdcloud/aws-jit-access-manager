variable "name_prefix" {
  type        = string
  description = "Prefix for resource naming"
}

variable "table_name" {
  type        = string
  description = "Name of the DynamoDB table for JIT access requests"
  default     = ""
}

variable "billing_mode" {
  type        = string
  description = "DynamoDB billing mode (PAY_PER_REQUEST or PROVISIONED)"
  default     = "PAY_PER_REQUEST"
}

variable "read_capacity" {
  type        = number
  description = "Read capacity units for PROVISIONED mode"
  default     = 5
}

variable "write_capacity" {
  type        = number
  description = "Write capacity units for PROVISIONED mode"
  default     = 5
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of the KMS key for server-side encryption"
}

variable "point_in_time_recovery_enabled" {
  type        = bool
  description = "Enable DynamoDB point-in-time recovery (PITR)"
  default     = true
}

variable "deletion_protection_enabled" {
  type        = bool
  description = "Enable DynamoDB deletion protection"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}

