aws_region                     = "us-east-1"
environment                    = "prod"
project_name                   = "jit-access-manager"
dynamodb_table_name            = "JITAccessRequests"
dynamodb_billing_mode          = "PAY_PER_REQUEST"
point_in_time_recovery_enabled = true
notification_emails            = ["security-alerts@example.com"]
create_sample_permission_sets  = false
max_duration_hours             = 8
log_retention_days             = 30
lambda_architecture            = "arm64"
sweeper_schedule_expression    = "rate(5 minutes)"
cors_allowed_origins           = ["*"]

tags = {
  Environment = "prod"
  ManagedBy   = "Terraform"
  Project     = "JIT-Access-Manager"
}

