# ============================================================================
# F5 Configuration Comparison System - Variables
# ============================================================================

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile name"
  type        = string
  default     = "default"
}

variable "environment" {
  description = "Environment name (e.g., production, staging, dev)"
  type        = string
  default     = "production"
}

variable "owner" {
  description = "Owner/team responsible for the resources"
  type        = string
  default     = "DevOps"
}

variable "vpc_id" {
  description = "VPC ID where resources will be deployed"
  type        = string
}

variable "lambda_subnet_id" {
  description = "Private subnet ID for Lambda function"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name for comparison reports (must be globally unique)"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for comparison history"
  type        = string
  default     = "f5-comparison-history"
}

variable "secret_name" {
  description = "Secrets Manager secret name for F5 SSH credentials"
  type        = string
  default     = "f5_comparison_secrets"
}

variable "lambda_function_name" {
  description = "Lambda function name"
  type        = string
  default     = "f5-config-comparison"
}

variable "lambda_package_path" {
  description = "Path to Lambda deployment package"
  type        = string
  default     = "./lambda_deployment.zip"
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 512
  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Lambda memory must be between 128 and 10240 MB."
  }
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 120
  validation {
    condition     = var.lambda_timeout >= 3 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 3 and 900 seconds."
  }
}

variable "f5_server1_ip" {
  description = "F5 server IP address - Site 1"
  type        = string
}

variable "f5_server2_ip" {
  description = "F5 server IP address - Site 2"
  type        = string
}

variable "f5_config_path" {
  description = "Path to F5 configuration file on the servers"
  type        = string
  default     = "/config/bigip.conf"
}

variable "teams_webhook_url" {
  description = "Microsoft Teams webhook URL for notifications"
  type        = string
  sensitive   = true
  default     = ""
}

variable "sns_email" {
  description = "Email address for SNS notifications"
  type        = string
  default     = ""
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 30
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.cloudwatch_log_retention_days)
    error_message = "Log retention must be a valid CloudWatch retention period."
  }
}

variable "schedule_expression" {
  description = "EventBridge schedule expression for running comparisons"
  type        = string
  default     = "cron(0 11 1 1,7 ? *)"  # Biannual: Jan 1 and Jul 1 at 11:00 UTC
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}