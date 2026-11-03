variable "name_prefix" {
  type        = string
  description = "Prefix for resource naming"
}

variable "revocation_handler_arn" {
  type        = string
  description = "ARN of the Revocation Handler Lambda function"
}

variable "revocation_handler_name" {
  type        = string
  description = "Name of the Revocation Handler Lambda function"
}

variable "sweeper_schedule_expression" {
  type        = string
  description = "Schedule expression for periodic reconciliation sweeper (cron or rate)"
  default     = "rate(5 minutes)"
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}

