output "sso_instance_arn" {
  description = "The discovered or configured IAM Identity Center Instance ARN"
  value       = local.sso_instance_arn
}

output "identity_store_id" {
  description = "The discovered or configured Identity Store ID"
  value       = local.identity_store_id
}

output "sample_admin_permission_set_arn" {
  description = "ARN of the sample Admin permission set if created"
  value       = try(aws_ssoadmin_permission_set.jit_admin[0].arn, "")
}

output "sample_readonly_permission_set_arn" {
  description = "ARN of the sample ReadOnly permission set if created"
  value       = try(aws_ssoadmin_permission_set.jit_readonly[0].arn, "")
}

