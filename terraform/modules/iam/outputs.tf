output "request_handler_role_arn" {
  description = "ARN of the Request Handler Lambda IAM Role"
  value       = aws_iam_role.request_handler.arn
}

output "request_handler_role_name" {
  description = "Name of the Request Handler Lambda IAM Role"
  value       = aws_iam_role.request_handler.name
}

output "approval_handler_role_arn" {
  description = "ARN of the Approval Handler Lambda IAM Role"
  value       = aws_iam_role.approval_handler.arn
}

output "approval_handler_role_name" {
  description = "Name of the Approval Handler Lambda IAM Role"
  value       = aws_iam_role.approval_handler.name
}

output "revocation_handler_role_arn" {
  description = "ARN of the Revocation Handler Lambda IAM Role"
  value       = aws_iam_role.revocation_handler.arn
}

output "revocation_handler_role_name" {
  description = "Name of the Revocation Handler Lambda IAM Role"
  value       = aws_iam_role.revocation_handler.name
}

output "scheduler_execution_role_arn" {
  description = "ARN of the EventBridge Scheduler Execution IAM Role"
  value       = aws_iam_role.scheduler.arn
}

output "scheduler_execution_role_name" {
  description = "Name of the EventBridge Scheduler Execution IAM Role"
  value       = aws_iam_role.scheduler.name
}

