output "topic_arn" {
  description = "The ARN of the SNS topic for JIT access notifications"
  value       = aws_sns_topic.notifications.arn
}

output "topic_name" {
  description = "The name of the SNS topic"
  value       = aws_sns_topic.notifications.name
}

