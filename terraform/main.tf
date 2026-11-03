locals {
  name_prefix              = "${var.environment}-${var.project_name}"
  revocation_function_name = "${local.name_prefix}-revocation-handler"

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      Project     = var.project_name
    }
  )
}

# ==============================================================================
# 1. KMS Customer Managed Key (CMK)
# ==============================================================================
module "kms" {
  source = "./modules/kms"

  name_prefix             = local.name_prefix
  environment             = var.environment
  deletion_window_in_days = var.kms_deletion_window_in_days
  tags                    = local.tags
}

# ==============================================================================
# 2. DynamoDB Table (JITAccessRequests)
# ==============================================================================
module "dynamodb" {
  source = "./modules/dynamodb"

  name_prefix                    = local.name_prefix
  table_name                     = var.dynamodb_table_name
  billing_mode                   = var.dynamodb_billing_mode
  kms_key_arn                    = module.kms.key_arn
  point_in_time_recovery_enabled = var.point_in_time_recovery_enabled
  deletion_protection_enabled    = var.deletion_protection_enabled
  tags                           = local.tags
}

# ==============================================================================
# 3. Amazon SNS Topic (Alerts & Notifications)
# ==============================================================================
module "sns" {
  source = "./modules/sns"

  name_prefix         = local.name_prefix
  kms_key_arn         = module.kms.key_arn
  notification_emails = var.notification_emails
  tags                = local.tags
}

# ==============================================================================
# 4. IAM Identity Center Discovery & Sample Permission Sets
# ==============================================================================
module "identity_center" {
  source = "./modules/identity_center"

  sso_instance_arn              = var.sso_instance_arn
  identity_store_id             = var.identity_store_id
  create_sample_permission_sets = var.create_sample_permission_sets
  tags                          = local.tags
}

# ==============================================================================
# 5. IAM Roles & Least-Privilege Policies
# ==============================================================================
module "iam" {
  source = "./modules/iam"

  name_prefix              = local.name_prefix
  dynamodb_table_arn       = module.dynamodb.table_arn
  sns_topic_arn            = module.sns.topic_arn
  kms_key_arn              = module.kms.key_arn
  sso_instance_arn         = module.identity_center.sso_instance_arn
  revocation_function_name = local.revocation_function_name
  tags                     = local.tags
}

# ==============================================================================
# 6. Lambda Functions (Request, Approval, Revocation)
# ==============================================================================
module "lambda" {
  source = "./modules/lambda"

  name_prefix                  = local.name_prefix
  environment                  = var.environment
  architecture                 = var.lambda_architecture
  log_retention_days           = var.log_retention_days
  kms_key_arn                  = module.kms.key_arn
  request_handler_role_arn     = module.iam.request_handler_role_arn
  approval_handler_role_arn    = module.iam.approval_handler_role_arn
  revocation_handler_role_arn  = module.iam.revocation_handler_role_arn
  scheduler_execution_role_arn = module.iam.scheduler_execution_role_arn
  dynamodb_table_name          = module.dynamodb.table_name
  status_index_name            = module.dynamodb.status_expiry_index_name
  username_index_name          = module.dynamodb.username_requested_index_name
  sns_topic_arn                = module.sns.topic_arn
  sso_instance_arn             = module.identity_center.sso_instance_arn
  identity_store_id            = module.identity_center.identity_store_id
  scheduler_group_name         = module.eventbridge.schedule_group_name
  max_duration_hours           = var.max_duration_hours
  tags                         = local.tags

  depends_on = [module.eventbridge]
}

# ==============================================================================
# 7. EventBridge (Scheduler Group & Periodic Reconciliation Sweeper)
# ==============================================================================
module "eventbridge" {
  source = "./modules/eventbridge"

  name_prefix                 = local.name_prefix
  revocation_handler_arn      = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${local.revocation_function_name}"
  revocation_handler_name     = local.revocation_function_name
  sweeper_schedule_expression = var.sweeper_schedule_expression
  tags                        = local.tags
}

data "aws_caller_identity" "current" {}

# ==============================================================================
# 8. API Gateway HTTP API
# ==============================================================================
module "api_gateway" {
  source = "./modules/api_gateway"

  name_prefix             = local.name_prefix
  environment             = var.environment
  request_handler_arn     = module.lambda.request_handler_arn
  request_handler_name    = module.lambda.request_handler_function_name
  approval_handler_arn    = module.lambda.approval_handler_arn
  approval_handler_name   = module.lambda.approval_handler_function_name
  revocation_handler_arn  = module.lambda.revocation_handler_arn
  revocation_handler_name = module.lambda.revocation_handler_function_name
  kms_key_arn             = module.kms.key_arn
  log_retention_days      = var.log_retention_days
  throttling_rate_limit   = var.throttling_rate_limit
  throttling_burst_limit  = var.throttling_burst_limit
  cors_allowed_origins    = var.cors_allowed_origins
  tags                    = local.tags
}