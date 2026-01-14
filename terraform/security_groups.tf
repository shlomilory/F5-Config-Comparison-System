# ============================================================================
# SECURITY GROUPS
# ============================================================================

# Lambda Security Group
resource "aws_security_group" "lambda" {
  name        = "${var.lambda_function_name}-sg-${var.environment}"
  description = "Security group for F5 comparison Lambda function"
  vpc_id      = var.vpc_id

  # Outbound to F5 servers (SSH)
  egress {
    description = "SSH to F5 Site 1"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.f5_server1_ip}/32"]
  }

  egress {
    description = "SSH to F5 Site 2"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.f5_server2_ip}/32"]
  }

  # Outbound to VPC endpoints (HTTPS)
  egress {
    description = "HTTPS to VPC Endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  # Outbound to Teams webhook (if needed)
  egress {
    description = "HTTPS for external notifications"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.lambda_function_name}-sg-${var.environment}"
    }
  )
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "f5-vpc-endpoints-sg-${var.environment}"
  description = "Security group for VPC endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTPS from Lambda"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "f5-vpc-endpoints-sg-${var.environment}"
    }
  )
}