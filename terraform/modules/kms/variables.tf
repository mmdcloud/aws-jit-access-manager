variable "name_prefix" {
  type        = string
  description = "Prefix for resource naming"
}

variable "environment" {
  type        = string
  description = "Deployment environment (e.g. prod, staging, dev)"
}

variable "deletion_window_in_days" {
  type        = number
  description = "Duration in days after which the key is deleted upon destruction"
  default     = 30
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}

