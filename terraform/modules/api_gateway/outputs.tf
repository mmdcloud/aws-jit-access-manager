output "api_id" {
  description = "The ID of the HTTP API Gateway"
  value       = aws_apigatewayv2_api.this.id
}

output "api_endpoint" {
  description = "The base URL endpoint of the HTTP API Gateway"
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "api_execution_arn" {
  description = "The execution ARN of the HTTP API Gateway"
  value       = aws_apigatewayv2_api.this.execution_arn
}

output "stage_name" {
  description = "The name of the default stage"
  value       = aws_apigatewayv2_stage.default.name
}

output "routes" {
  description = "List of configured routes"
  value = [
    "POST /requests",
    "GET /requests",
    "GET /requests/{id}",
    "POST /requests/{id}/approve",
    "POST /requests/{id}/reject",
    "POST /requests/{id}/revoke"
  ]
}

