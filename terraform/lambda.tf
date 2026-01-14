# ============================================================================
# LAMBDA FUNCTION
# ============================================================================

resource "aws_lambda_function" "f5_comparison" {
  filename         = var.lambda_package_path
  function_name    = var.lambda_function_name
  role             = aws_iam_role.lambda.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = filebase64sha256(var.lambda_package_path)
  runtime          = "python3.11"
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  vpc_config {
    subnet_ids         = [var.lambda_subnet_id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      S3_BUCKET_NAME      = aws_s3_bucket.reports.id
      SECRET_NAME         = aws_secretsmanager_secret.f5_credentials.name
      SNS_TOPIC_ARN       = aws_sns_topic.f5_comparison.arn
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.comparison_history.name
      TEAMS_WEBHOOK_URL   = var.teams_webhook_url
      SERVER1             = var.f5_server1_ip
      SERVER2             = var.f5_server2_ip
      CONFIG_PATH         = var.f5_config_path
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.lambda_function_name}-${var.environment}"
    }
  )

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_iam_role_policy_attachment.lambda_policy
  ]
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.lambda_function_name}-logs-${var.environment}"
    }
  )
}