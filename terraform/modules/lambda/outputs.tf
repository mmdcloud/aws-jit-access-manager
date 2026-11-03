output "request_handler_function_name" {
  description = "Name of the Request Handler Lambda function"
  value       = aws_lambda_function.request_handler.function_name
}

output "request_handler_arn" {
  description = "ARN of the Request Handler Lambda function"
  value       = aws_lambda_function.request_handler.arn
}

output "approval_handler_function_name" {
  description = "Name of the Approval Handler Lambda function"
  value       = aws_lambda_function.approval_handler.function_name
}

output "approval_handler_arn" {
  description = "ARN of the Approval Handler Lambda function"
  value       = aws_lambda_function.approval_handler.arn
}

output "revocation_handler_function_name" {
  description = "Name of the Revocation Handler Lambda function"
  value       = aws_lambda_function.revocation_handler.function_name
}

output "revocation_handler_arn" {
  description = "ARN of the Revocation Handler Lambda function"
  value       = aws_lambda_function.revocation_handler.arn
}

output "dlq_arn" {
  description = "ARN of the Dead Letter SQS queue"
  value       = aws_sqs_queue.dlq.arn
}

