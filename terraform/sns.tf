# ============================================================================
# SNS TOPIC FOR ALERTS
# ============================================================================

resource "aws_sns_topic" "f5_comparison" {
  name = "f5-comparison-alerts-${var.environment}"

  tags = merge(
    var.tags,
    {
      Name = "f5-comparison-alerts-${var.environment}"
    }
  )
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.sns_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.f5_comparison.arn
  protocol  = "email"
  endpoint  = var.sns_email
}