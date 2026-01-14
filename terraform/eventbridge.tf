# ============================================================================
# EVENTBRIDGE RULE FOR SCHEDULED COMPARISON
# ============================================================================

resource "aws_cloudwatch_event_rule" "f5_comparison" {
  name                = "f5-comparison-schedule-${var.environment}"
  description         = "Trigger F5 configuration comparison on schedule"
  schedule_expression = var.schedule_expression

  tags = merge(
    var.tags,
    {
      Name = "f5-comparison-schedule-${var.environment}"
    }
  )
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.f5_comparison.name
  target_id = "F5ComparisonLambda"
  arn       = aws_lambda_function.f5_comparison.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.f5_comparison.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.f5_comparison.arn
}