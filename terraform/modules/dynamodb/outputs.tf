output "table_name" {
  description = "The name of the DynamoDB table"
  value       = aws_dynamodb_table.jit_requests.name
}

output "table_arn" {
  description = "The ARN of the DynamoDB table"
  value       = aws_dynamodb_table.jit_requests.arn
}

output "table_stream_arn" {
  description = "The ARN of the DynamoDB Table Stream"
  value       = aws_dynamodb_table.jit_requests.stream_arn
}

output "status_expiry_index_name" {
  description = "Name of the Status-ExpiryTime GSI"
  value       = "Status-ExpiryTime-Index"
}

output "username_requested_index_name" {
  description = "Name of the Username-RequestedTime GSI"
  value       = "Username-RequestedTime-Index"
}

