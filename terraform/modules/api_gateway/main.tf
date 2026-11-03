# ==============================================================================
# CloudWatch Log Group for API Gateway Access Logs
# ==============================================================================
resource "aws_cloudwatch_log_group" "api_access_logs" {
  name              = "/aws/apigateway/${var.name_prefix}-api"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

# ==============================================================================
# HTTP API Gateway (v2)
# ==============================================================================
resource "aws_apigatewayv2_api" "this" {
  name          = "${var.name_prefix}-api"
  description   = "API for Just-In-Time (JIT) Access Management System"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = var.cors_allowed_origins
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization", "X-Amz-Date", "X-Api-Key", "X-Amz-Security-Token"]
    max_age       = 300
  }

  tags = var.tags
}

# ==============================================================================
# Stage with Access Logging and Throttling
# ==============================================================================
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access_logs.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      httpMethod              = "$context.httpMethod"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      protocol                = "$context.protocol"
      responseLength          = "$context.responseLength"
      integrationLatency      = "$context.integrationLatency"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }

  default_route_settings {
    throttling_burst_limit = var.throttling_burst_limit
    throttling_rate_limit  = var.throttling_rate_limit
  }

  tags = var.tags
}

# ==============================================================================
# Lambda Integrations
# ==============================================================================
resource "aws_apigatewayv2_integration" "request_handler" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.request_handler_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "approval_handler" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.approval_handler_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "revocation_handler" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.revocation_handler_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# ==============================================================================
# API Routes
# ==============================================================================
# Request handler routes
resource "aws_apigatewayv2_route" "post_requests" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /requests"
  target    = "integrations/${aws_apigatewayv2_integration.request_handler.id}"
}

resource "aws_apigatewayv2_route" "get_requests" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /requests"
  target    = "integrations/${aws_apigatewayv2_integration.request_handler.id}"
}

resource "aws_apigatewayv2_route" "get_request_by_id" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /requests/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.request_handler.id}"
}

# Approval handler routes
resource "aws_apigatewayv2_route" "post_approve" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /requests/{id}/approve"
  target    = "integrations/${aws_apigatewayv2_integration.approval_handler.id}"
}

resource "aws_apigatewayv2_route" "post_reject" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /requests/{id}/reject"
  target    = "integrations/${aws_apigatewayv2_integration.approval_handler.id}"
}

# Revocation handler route (manual early revocation)
resource "aws_apigatewayv2_route" "post_revoke" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /requests/{id}/revoke"
  target    = "integrations/${aws_apigatewayv2_integration.revocation_handler.id}"
}

# ==============================================================================
# Lambda Invoke Permissions
# ==============================================================================
resource "aws_lambda_permission" "api_gw_request_handler" {
  statement_id  = "AllowAPIGatewayInvokeRequestHandler"
  action        = "lambda:InvokeFunction"
  function_name = var.request_handler_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gw_approval_handler" {
  statement_id  = "AllowAPIGatewayInvokeApprovalHandler"
  action        = "lambda:InvokeFunction"
  function_name = var.approval_handler_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gw_revocation_handler" {
  statement_id  = "AllowAPIGatewayInvokeRevocationHandler"
  action        = "lambda:InvokeFunction"
  function_name = var.revocation_handler_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

