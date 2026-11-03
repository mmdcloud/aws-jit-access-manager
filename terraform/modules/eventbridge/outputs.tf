output "schedule_group_name" {
  description = "Name of the EventBridge Scheduler schedule group"
  value       = aws_scheduler_schedule_group.jit_schedules.name
}

output "schedule_group_arn" {
  description = "ARN of the EventBridge Scheduler schedule group"
  value       = aws_scheduler_schedule_group.jit_schedules.arn
}

output "sweeper_rule_arn" {
  description = "ARN of the EventBridge sweeper rule"
  value       = aws_cloudwatch_event_rule.reconciliation_sweeper.arn
}

output "sweeper_rule_name" {
  description = "Name of the EventBridge sweeper rule"
  value       = aws_cloudwatch_event_rule.reconciliation_sweeper.name
}

