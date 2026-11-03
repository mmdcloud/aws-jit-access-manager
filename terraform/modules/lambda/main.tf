# ==============================================================================
# Dead Letter Queue (SQS) for Failed Lambda Executions
# ==============================================================================
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name_prefix}-lambda-dlq"
  kms_master_key_id         = var.kms_key_arn
  message_retention_seconds = 1209600 # 14 days

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-lambda-dlq"
    }
  )
}

# ==============================================================================
# Packaging Lambda Archives
# ==============================================================================
data "archive_file" "request_handler" {
  type        = "zip"
  output_path = "${path.module}/build/request_handler.zip"

  source {
    content  = file("${path.module}/src/request_handler/index.py")
    filename = "index.py"
  }

  source {
    content  = file("${path.module}/src/common/__init__.py")
    filename = "common/__init__.py"
  }
  source {
    content  = file("${path.module}/src/common/config.py")
    filename = "common/config.py"
  }
  source {
    content  = file("${path.module}/src/common/db.py")
    filename = "common/db.py"
  }
  source {
    content  = file("${path.module}/src/common/sso.py")
    filename = "common/sso.py"
  }
  source {
    content  = file("${path.module}/src/common/scheduler.py")
    filename = "common/scheduler.py"
  }
  source {
    content  = file("${path.module}/src/common/notifier.py")
    filename = "common/notifier.py"
  }
}

data "archive_file" "approval_handler" {
  type        = "zip"
  output_path = "${path.module}/build/approval_handler.zip"

  source {
    content  = file("${path.module}/src/approval_handler/index.py")
    filename = "index.py"
  }

  source {
    content  = file("${path.module}/src/common/__init__.py")
    filename = "common/__init__.py"
  }
  source {
    content  = file("${path.module}/src/common/config.py")
    filename = "common/config.py"
  }
  source {
    content  = file("${path.module}/src/common/db.py")
    filename = "common/db.py"
  }
  source {
    content  = file("${path.module}/src/common/sso.py")
    filename = "common/sso.py"
  }
  source {
    content  = file("${path.module}/src/common/scheduler.py")
    filename = "common/scheduler.py"
  }
  source {
    content  = file("${path.module}/src/common/notifier.py")
    filename = "common/notifier.py"
  }
}

data "archive_file" "revocation_handler" {
  type        = "zip"
  output_path = "${path.module}/build/revocation_handler.zip"

  source {
    content  = file("${path.module}/src/revocation_handler/index.py")
    filename = "index.py"
  }

  source {
    content  = file("${path.module}/src/common/__init__.py")
    filename = "common/__init__.py"
  }
  source {
    content  = file("${path.module}/src/common/config.py")
    filename = "common/config.py"
  }
  source {
    content  = file("${path.module}/src/common/db.py")
    filename = "common/db.py"
  }
  source {
    content  = file("${path.module}/src/common/sso.py")
    filename = "common/sso.py"
  }
  source {
    content  = file("${path.module}/src/common/scheduler.py")
    filename = "common/scheduler.py"
  }
  source {
    content  = file("${path.module}/src/common/notifier.py")
    filename = "common/notifier.py"
  }
}

# ==============================================================================
# CloudWatch Log Groups
# ==============================================================================
resource "aws_cloudwatch_log_group" "request_handler" {
  name              = "/aws/lambda/${var.name_prefix}-request-handler"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "approval_handler" {
  name              = "/aws/lambda/${var.name_prefix}-approval-handler"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "revocation_handler" {
  name              = "/aws/lambda/${var.name_prefix}-revocation-handler"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

# ==============================================================================
# Lambda Functions
# ==============================================================================
resource "aws_lambda_function" "request_handler" {
  function_name    = "${var.name_prefix}-request-handler"
  description      = "Receives and validates JIT access requests"
  role             = var.request_handler_role_arn
  runtime          = "python3.12"
  handler          = "index.lambda_handler"
  architectures    = [var.architecture]
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size
  filename         = data.archive_file.request_handler.output_path
  source_code_hash = data.archive_file.request_handler.output_base64sha256

  tracing_config {
    mode = "Active"
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  environment {
    variables = {
      DYNAMODB_TABLE     = var.dynamodb_table_name
      STATUS_INDEX       = var.status_index_name
      USER_INDEX         = var.username_index_name
      SNS_TOPIC_ARN      = var.sns_topic_arn
      SSO_INSTANCE_ARN   = var.sso_instance_arn
      IDENTITY_STORE_ID  = var.identity_store_id
      MAX_DURATION_HOURS = tostring(var.max_duration_hours)
      LOG_LEVEL          = "INFO"
    }
  }

  depends_on = [aws_cloudwatch_log_group.request_handler]
  tags       = var.tags
}

resource "aws_lambda_function" "revocation_handler" {
  function_name    = "${var.name_prefix}-revocation-handler"
  description      = "Revokes expired or manually terminated JIT access assignments"
  role             = var.revocation_handler_role_arn
  runtime          = "python3.12"
  handler          = "index.lambda_handler"
  architectures    = [var.architecture]
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size
  filename         = data.archive_file.revocation_handler.output_path
  source_code_hash = data.archive_file.revocation_handler.output_base64sha256

  tracing_config {
    mode = "Active"
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  environment {
    variables = {
      DYNAMODB_TABLE       = var.dynamodb_table_name
      STATUS_INDEX         = var.status_index_name
      SNS_TOPIC_ARN        = var.sns_topic_arn
      SSO_INSTANCE_ARN     = var.sso_instance_arn
      SCHEDULER_GROUP_NAME = var.scheduler_group_name
      LOG_LEVEL            = "INFO"
    }
  }

  depends_on = [aws_cloudwatch_log_group.revocation_handler]
  tags       = var.tags
}

resource "aws_lambda_function" "approval_handler" {
  function_name    = "${var.name_prefix}-approval-handler"
  description      = "Approves/rejects JIT access and provisions temporary IAM Identity Center assignments"
  role             = var.approval_handler_role_arn
  runtime          = "python3.12"
  handler          = "index.lambda_handler"
  architectures    = [var.architecture]
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size
  filename         = data.archive_file.approval_handler.output_path
  source_code_hash = data.archive_file.approval_handler.output_base64sha256

  tracing_config {
    mode = "Active"
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  environment {
    variables = {
      DYNAMODB_TABLE        = var.dynamodb_table_name
      STATUS_INDEX          = var.status_index_name
      SNS_TOPIC_ARN         = var.sns_topic_arn
      SSO_INSTANCE_ARN      = var.sso_instance_arn
      IDENTITY_STORE_ID     = var.identity_store_id
      SCHEDULER_GROUP_NAME  = var.scheduler_group_name
      SCHEDULER_ROLE_ARN    = var.scheduler_execution_role_arn
      REVOCATION_LAMBDA_ARN = aws_lambda_function.revocation_handler.arn
      LOG_LEVEL             = "INFO"
    }
  }

  depends_on = [aws_cloudwatch_log_group.approval_handler]
  tags       = var.tags
}

