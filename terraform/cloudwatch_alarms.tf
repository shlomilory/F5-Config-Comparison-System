# ============================================================================
# CLOUDWATCH ALARMS
# ============================================================================

# Lambda Errors Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "f5-comparison-lambda-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alert when F5 comparison Lambda function errors"
  alarm_actions       = [aws_sns_topic.f5_comparison.arn]

  dimensions = {
    FunctionName = aws_lambda_function.f5_comparison.function_name
  }

  tags = merge(
    var.tags,
    {
      Name = "f5-comparison-lambda-errors-${var.environment}"
    }
  )
}

# High Critical Count Alarm
resource "aws_cloudwatch_metric_alarm" "high_critical_count" {
  alarm_name          = "f5-comparison-high-critical-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CriticalCount"
  namespace           = "F5/ConfigComparison"
  period              = 300
  statistic           = "Maximum"
  threshold           = 10
  alarm_description   = "Alert when critical differences exceed threshold"
  alarm_actions       = [aws_sns_topic.f5_comparison.arn]

  tags = merge(
    var.tags,
    {
      Name = "f5-comparison-high-critical-${var.environment}"
    }
  )
}

# Lambda Duration Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "f5-comparison-lambda-duration-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = 100000  # 100 seconds (buffer before 120s timeout)
  alarm_description   = "Alert when Lambda execution time is high"
  alarm_actions       = [aws_sns_topic.f5_comparison.arn]

  dimensions = {
    FunctionName = aws_lambda_function.f5_comparison.function_name
  }

  tags = merge(
    var.tags,
    {
      Name = "f5-comparison-lambda-duration-${var.environment}"
    }
  )
}