# ==============================================================================
# EventBridge Scheduler Schedule Group (for dynamic one-time expiration timers)
# ==============================================================================
resource "aws_scheduler_schedule_group" "jit_schedules" {
  name = "${var.name_prefix}-schedules"

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-schedules"
    }
  )
}

# ==============================================================================
# EventBridge Rule (Periodic Reconciliation Sweeper)
# Acts as a fail-safe safety net to ensure no expired privileges remain active.
# ==============================================================================
resource "aws_cloudwatch_event_rule" "reconciliation_sweeper" {
  name                = "${var.name_prefix}-sweeper-rule"
  description         = "Periodic reconciliation sweeper to revoke any expired JIT access assignments"
  schedule_expression = var.sweeper_schedule_expression

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-sweeper-rule"
    }
  )
}

resource "aws_cloudwatch_event_target" "reconciliation_sweeper" {
  rule      = aws_cloudwatch_event_rule.reconciliation_sweeper.name
  target_id = "TriggerRevocationSweeper"
  arn       = var.revocation_handler_arn

  input = jsonencode({
    action = "SWEEP"
    source = "aws.events"
    reason = "Periodic reconciliation sweeper invocation"
  })
}

resource "aws_lambda_permission" "allow_eventbridge_sweeper" {
  statement_id  = "AllowExecutionFromEventBridgeSweeper"
  action        = "lambda:InvokeFunction"
  function_name = var.revocation_handler_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.reconciliation_sweeper.arn
}

