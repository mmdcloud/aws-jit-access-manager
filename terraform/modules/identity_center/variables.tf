variable "sso_instance_arn" {
  type        = string
  description = "Explicit IAM Identity Center Instance ARN. If left empty, will be auto-discovered via data source."
  default     = ""
}

variable "identity_store_id" {
  type        = string
  description = "Explicit IAM Identity Center Identity Store ID. If left empty, will be auto-discovered via data source."
  default     = ""
}

variable "create_sample_permission_sets" {
  type        = bool
  description = "Whether to create sample JIT permission sets in IAM Identity Center (e.g. JIT-Admin, JIT-ReadOnly)"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}

