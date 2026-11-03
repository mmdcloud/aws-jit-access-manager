data "aws_caller_identity" "current" {}

resource "aws_sns_topic" "notifications" {
  name              = "${var.name_prefix}-notifications"
  kms_master_key_id = var.kms_key_arn

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-notifications"
    }
  )
}

resource "aws_sns_topic_policy" "this" {
  arn = aws_sns_topic.notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${var.name_prefix}-sns-policy"
    Statement = [
      {
        Sid    = "AllowAccountPublishAndSubscribe"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "SNS:Publish",
          "SNS:RemovePermission",
          "SNS:SetTopicAttributes",
          "SNS:DeleteTopic",
          "SNS:ListSubscriptionsByTopic",
          "SNS:GetTopicAttributes",
          "SNS:Receive",
          "SNS:AddPermission",
          "SNS:Subscribe"
        ]
        Resource = aws_sns_topic.notifications.arn
      },
      {
        Sid    = "AllowLambdaAndCloudWatchPublish"
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "cloudwatch.amazonaws.com",
            "events.amazonaws.com"
          ]
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.notifications.arn
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "email" {
  for_each  = toset(var.notification_emails)
  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "email"
  endpoint  = each.value
}

