variable "name_prefix" {
  type        = string
  description = "Prefix for resource naming"
}

variable "kms_key_arn" {
  type        = string
  description = "KMS Key ARN for SNS Topic encryption"
}

variable "notification_emails" {
  type        = list(string)
  description = "List of email addresses to receive JIT access notifications"
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}

