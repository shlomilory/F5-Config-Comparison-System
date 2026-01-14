# ============================================================================
# DATA SOURCES
# ============================================================================

# VPC Information
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Subnet Information
data "aws_subnet" "lambda_subnet" {
  id = var.lambda_subnet_id
}

# Route Table for VPC Endpoints
data "aws_route_table" "lambda_subnet" {
  subnet_id = var.lambda_subnet_id
}

# Current AWS Account ID
data "aws_caller_identity" "current" {}

# Current AWS Region
data "aws_region" "current" {}