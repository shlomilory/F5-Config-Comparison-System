# ⚙️ Configuration Reference

Complete reference for all configuration options in the F5 Configuration Comparison System.

---

## Table of Contents

- [Terraform Variables](#terraform-variables)
- [Lambda Environment Variables](#lambda-environment-variables)
- [AWS Resource Configuration](#aws-resource-configuration)
- [F5 Server Configuration](#f5-server-configuration)
- [Schedule Configuration](#schedule-configuration)
- [Notification Configuration](#notification-configuration)

---

## Terraform Variables

All Terraform variables are defined in `terraform/variables.tf` and can be overridden in `terraform.tfvars`.

### AWS Configuration

#### `aws_region`
- **Type:** `string`
- **Required:** Yes
- **Default:** None
- **Description:** AWS region to deploy resources
- **Example:** `"us-east-1"`, `"eu-west-1"`, `"ap-southeast-1"`
- **Notes:** Choose region closest to your F5 servers for lowest latency

#### `aws_profile`
- **Type:** `string`
- **Required:** No
- **Default:** `"default"`
- **Description:** AWS CLI profile name
- **Example:** `"production"`, `"devops"`
- **Notes:** Use named profiles for better credential management

```hcl
aws_region  = "us-east-1"
aws_profile = "default"
```

---

### Network Configuration

#### `vpc_id`
- **Type:** `string`
- **Required:** Yes
- **Default:** None
- **Description:** VPC ID where Lambda will be deployed
- **Example:** `"vpc-0a1b2c3d4e5f6g7h8"`
- **How to find:**
  ```bash
  aws ec2 describe-vpcs \
    --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' \
    --output table
  ```

#### `subnet_id`
- **Type:** `string`
- **Required:** Yes
- **Default:** None
- **Description:** Private subnet ID for Lambda ENI
- **Example:** `"subnet-9h8g7f6e5d4c3b2a1"`
- **Requirements:**
  - Must be a **private** subnet
  - Should have route to F5 network
  - Recommended: Use subnet with VPC endpoints
- **How to find:**
  ```bash
  aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=vpc-xxxxxxxxx" \
    --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]' \
    --output table
  ```

#### `availability_zone`
- **Type:** `string`
- **Required:** Yes
- **Default:** None
- **Description:** Availability zone of the subnet
- **Example:** `"us-east-1a"`, `"eu-west-1b"`
- **Notes:** Must match the subnet's AZ

```hcl
vpc_id            = "vpc-0a1b2c3d4e5f6g7h8"
subnet_id         = "subnet-9h8g7f6e5d4c3b2a1"
availability_zone = "us-east-1a"
```

---

### F5 Server Configuration

#### `f5_site1_ip`
- **Type:** `string`
- **Required:** Yes
- **Default:** None
- **Description:** IP address of first F5 server
- **Example:** `"10.100.50.10"`, `"192.168.1.100"`
- **Notes:**
  - Must be reachable from Lambda subnet
  - Can be IPv4 address only
  - Do not include port number

#### `f5_site2_ip`
- **Type:** `string`
- **Required:** Yes
- **Default:** None
- **Description:** IP address of second F5 server
- **Example:** `"10.200.50.10"`, `"192.168.2.100"`
- **Notes:** Same requirements as `f5_site1_ip`

#### `f5_config_path`
- **Type:** `string`
- **Required:** No
- **Default:** `"/config/bigip.conf"`
- **Description:** Path to F5 configuration file
- **Example:** `"/config/bigip.conf"`, `"/config/bigip_base.conf"`
- **Notes:**
  - Default path works for standard F5 installations
  - User must have read access to this file

```hcl
f5_site1_ip    = "10.100.50.10"
f5_site2_ip    = "10.200.50.10"
f5_config_path = "/config/bigip.conf"
```

---

### Secrets & Credentials

#### `secret_name`
- **Type:** `string`
- **Required:** Yes
- **Default:** `"f5_comparison_secrets"`
- **Description:** Name of secret in AWS Secrets Manager
- **Example:** `"f5_comparison_secrets"`, `"prod-f5-ssh-keys"`
- **Notes:**
  - Secret must exist before Terraform apply
  - Contains SSH username and private key

**Secret Format:**
```json
{
  "username": "f5_comparison",
  "private_key": "-----BEGIN RSA PRIVATE KEY-----\n..."
}
```

#### `teams_webhook_url`
- **Type:** `string`
- **Required:** Yes
- **Default:** None
- **Description:** Microsoft Teams incoming webhook URL
- **Example:** `"https://outlook.office.com/webhook/..."`
- **How to create:**
  1. Teams channel → ⋯ → Connectors
  2. Add "Incoming Webhook"
  3. Copy URL
- **Notes:**
  - URL is sensitive - do not commit to git
  - Test webhook before deploying

#### `sns_email`
- **Type:** `string`
- **Required:** No
- **Default:** `""`
- **Description:** Email address for SNS alert notifications
- **Example:** `"devops@example.com"`
- **Notes:**
  - Will receive CloudWatch alarm notifications
  - Must confirm SNS subscription via email

```hcl
secret_name       = "f5_comparison_secrets"
teams_webhook_url = "https://outlook.office.com/webhook/..."
sns_email         = "devops@example.com"
```

---

### Lambda Configuration

#### `lambda_function_name`
- **Type:** `string`
- **Required:** No
- **Default:** `"f5-config-comparison"`
- **Description:** Name of Lambda function
- **Example:** `"f5-config-comparison"`, `"prod-f5-comparison"`
- **Constraints:**
  - 1-64 characters
  - Letters, numbers, hyphens, underscores only
  - Must be unique in region

#### `lambda_memory_size`
- **Type:** `number`
- **Required:** No
- **Default:** `512`
- **Description:** Lambda memory allocation in MB
- **Range:** `128` to `10240` (in 1 MB increments)
- **Recommendation:**
  - **512 MB:** Good for <3,000 virtual servers
  - **1024 MB:** For 3,000-5,000 virtual servers
  - **2048 MB:** For >5,000 virtual servers
- **Notes:**
  - More memory = more CPU = faster execution
  - Cost increases linearly with memory

#### `lambda_timeout`
- **Type:** `number`
- **Required:** No
- **Default:** `120`
- **Description:** Lambda timeout in seconds
- **Range:** `1` to `900`
- **Recommendation:**
  - **120 seconds:** Good for <3,000 virtual servers
  - **180 seconds:** For 3,000-5,000 virtual servers
  - **300 seconds:** For >5,000 virtual servers
- **Notes:**
  - Should be > expected execution time
  - Current execution time: ~16 seconds for 2,500 VS

```hcl
lambda_function_name = "f5-config-comparison"
lambda_memory_size   = 512
lambda_timeout       = 120
```

---

### Storage Configuration

#### `s3_bucket_name`
- **Type:** `string`
- **Required:** Yes
- **Default:** None
- **Description:** S3 bucket name for comparison reports
- **Example:** `"f5-comparison-reports-acme-corp"`
- **Constraints:**
  - Must be globally unique
  - 3-63 characters
  - Lowercase letters, numbers, hyphens only
  - Cannot start/end with hyphen
- **Naming convention:** `f5-comparison-reports-{company-name}`

#### `dynamodb_table_name`
- **Type:** `string`
- **Required:** No
- **Default:** `"f5-comparison-history"`
- **Description:** DynamoDB table name for comparison metadata
- **Example:** `"f5-comparison-history"`, `"prod-f5-history"`
- **Constraints:**
  - 3-255 characters
  - Letters, numbers, hyphens, underscores, dots

```hcl
s3_bucket_name      = "f5-comparison-reports-acme"
dynamodb_table_name = "f5-comparison-history"
```

---

### Scheduling

#### `schedule_expression`
- **Type:** `string`
- **Required:** No
- **Default:** `"cron(0 11 1 1,7 ? *)"`
- **Description:** EventBridge schedule expression (cron or rate)
- **Format:** `cron(minute hour day-of-month month day-of-week year)`

**Common Schedules:**

| Schedule | Expression | Description |
|----------|------------|-------------|
| Biannual (Jan 1 & July 1 at 11:00 UTC) | `cron(0 11 1 1,7 ? *)` | Default |
| Quarterly (1st of Jan/Apr/Jul/Oct) | `cron(0 11 1 1,4,7,10 ? *)` | Every 3 months |
| Monthly (1st at 11:00 UTC) | `cron(0 11 1 * ? *)` | Monthly |
| Weekly (Monday at 11:00 UTC) | `cron(0 11 ? * MON *)` | Weekly |
| Daily (11:00 UTC) | `cron(0 11 * * ? *)` | Daily |
| Every 6 hours | `rate(6 hours)` | Continuous |

**Cron Format:**
```
cron(minute hour day-of-month month day-of-week year)
     0-59   0-23  1-31         1-12   1-7         *

Examples:
cron(0 11 1 1,7 ? *)      # Jan 1 & July 1 at 11:00 UTC
cron(0 14 * * ? *)        # Every day at 14:00 UTC
cron(0 9 ? * MON *)       # Every Monday at 09:00 UTC
cron(30 8 1 * ? *)        # 1st of month at 08:30 UTC
```

**Notes:**
- Use `?` for day-of-month OR day-of-week (not both)
- Times are in UTC
- For testing, use daily schedule
- For production, use biannual

```hcl
# Production: Biannual
schedule_expression = "cron(0 11 1 1,7 ? *)"

# Testing: Daily at 14:00 UTC
# schedule_expression = "cron(0 14 * * ? *)"

# Testing: Every 6 hours
# schedule_expression = "rate(6 hours)"
```

---

### Tags

#### `environment`
- **Type:** `string`
- **Required:** No
- **Default:** `"production"`
- **Description:** Environment name
- **Example:** `"production"`, `"staging"`, `"development"`

#### `project`
- **Type:** `string`
- **Required:** No
- **Default:** `"f5-config-comparison"`
- **Description:** Project name
- **Example:** `"f5-config-comparison"`, `"infrastructure-automation"`

#### `owner`
- **Type:** `string`
- **Required:** No
- **Default:** `"devops"`
- **Description:** Team or person responsible
- **Example:** `"devops-team"`, `"network-team"`, `"john.doe@example.com"`

```hcl
environment = "production"
project     = "f5-config-comparison"
owner       = "devops-team"
```

---

## Lambda Environment Variables

These are automatically set by Terraform and passed to Lambda:

### `S3_BUCKET_NAME`
- **Value:** From `s3_bucket_name` variable
- **Usage:** Where to upload comparison reports
- **Example:** `"f5-comparison-reports-acme"`

### `SECRET_NAME`
- **Value:** From `secret_name` variable
- **Usage:** Secret name in Secrets Manager for SSH credentials
- **Example:** `"f5_comparison_secrets"`

### `SNS_TOPIC_ARN`
- **Value:** Created SNS topic ARN
- **Usage:** Where to send alert notifications
- **Example:** `"arn:aws:sns:us-east-1:123456789012:f5-comparison-notifications"`

### `DYNAMODB_TABLE_NAME`
- **Value:** From `dynamodb_table_name` variable
- **Usage:** Where to store comparison metadata
- **Example:** `"f5-comparison-history"`

### `TEAMS_WEBHOOK_URL`
- **Value:** From `teams_webhook_url` variable
- **Usage:** Microsoft Teams webhook for notifications
- **Example:** `"https://outlook.office.com/webhook/..."`

### `SERVER1`
- **Value:** From `f5_site1_ip` variable
- **Usage:** First F5 server IP address
- **Example:** `"10.100.50.10"`

### `SERVER2`
- **Value:** From `f5_site2_ip` variable
- **Usage:** Second F5 server IP address
- **Example:** `"10.200.50.10"`

### `CONFIG_PATH`
- **Value:** From `f5_config_path` variable
- **Usage:** Path to F5 configuration file
- **Example:** `"/config/bigip.conf"`

---

## AWS Resource Configuration

### S3 Bucket

**Configuration:**
```hcl
versioning = true
encryption = "AES256"
public_access_block = true

lifecycle_rules:
  - id: "archive-old-reports"
    enabled: true
    transitions:
      - days: 90
        storage_class: "GLACIER"
    expiration:
      - days: 365
```

**Folder Structure:**
```
s3://f5-comparison-reports-acme/
└── comparisons/
    ├── 20260101-110000_f5_ltm_comparison.zip
    ├── 20260701-110000_f5_ltm_comparison.zip
    └── ...
```

### DynamoDB Table

**Configuration:**
```hcl
billing_mode = "PAY_PER_REQUEST"  # On-demand
hash_key     = "comparison_id"
range_key    = "timestamp"

ttl_enabled       = true
ttl_attribute_name = "ttl"  # 90 days
```

**Schema:**
```
Primary Key: comparison_id (String)
Sort Key: timestamp (String)
TTL: ttl (Number)

Attributes:
- server1, server2, s3_url
- total_vs, critical_count, warning_count, match_count
- critical_percentage, risk_level, assessment
```

### VPC Endpoints

**Created Endpoints:**
1. **S3** (Gateway) - Free
2. **DynamoDB** (Gateway) - Free
3. **Secrets Manager** (Interface) - $7.30/month
4. **CloudWatch Logs** (Interface) - $7.30/month
5. **CloudWatch Monitoring** (Interface) - $7.30/month
6. **SNS** (Interface) - $7.30/month

**Total:** ~$29.20/month for interface endpoints

### CloudWatch Alarms

**1. High Critical Count**
```hcl
metric_name         = "CriticalCount"
comparison_operator = "GreaterThanThreshold"
threshold           = 150  # > 6% of 2,500 servers
evaluation_periods  = 1
period             = 300  # 5 minutes
statistic          = "Maximum"
```

**2. Lambda Errors**
```hcl
metric_name         = "Errors"
comparison_operator = "GreaterThanThreshold"
threshold           = 0
evaluation_periods  = 1
period             = 300
statistic          = "Sum"
```

---

## F5 Server Configuration

### User Requirements

**User Account:**
```bash
username: f5_comparison
shell: bash
partition_access: all-partitions (role: admin)
```

**Permissions Needed:**
- Read access to `/config/bigip.conf`
- SSH access (key-based authentication)
- SFTP access

### SSH Key Format

**Supported:**
- RSA 2048-bit or 4096-bit
- ED25519
- ECDSA

**Not Supported:**
- DSA (deprecated)

**Example Generation:**
```bash
ssh-keygen -t rsa -b 4096 -f f5_comparison_key -C "f5_comparison"
```

### authorized_keys Setup

**Location:** `~/.ssh/authorized_keys`

**Permissions:**
```bash
~/.ssh/              700 (drwx------)
~/.ssh/authorized_keys 600 (-rw-------)
```

**Format:**
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC... f5_comparison
```

---

## Example Configurations

### Minimal Configuration

```hcl
# terraform.tfvars
aws_region  = "us-east-1"
vpc_id      = "vpc-abc123"
subnet_id   = "subnet-xyz789"

f5_site1_ip = "10.100.50.10"
f5_site2_ip = "10.200.50.10"

s3_bucket_name = "f5-reports-mycompany"
teams_webhook_url = "https://outlook.office.com/webhook/..."
```

### Full Configuration

```hcl
# terraform.tfvars
# AWS
aws_region  = "us-east-1"
aws_profile = "production"

# Network
vpc_id            = "vpc-abc123"
subnet_id         = "subnet-xyz789"
availability_zone = "us-east-1a"

# F5 Servers
f5_site1_ip    = "10.100.50.10"
f5_site2_ip    = "10.200.50.10"
f5_config_path = "/config/bigip.conf"

# Secrets
secret_name       = "f5_comparison_secrets"
teams_webhook_url = "https://outlook.office.com/webhook/..."
sns_email         = "devops@example.com"

# Lambda
lambda_function_name = "f5-config-comparison"
lambda_memory_size   = 1024  # Increased for large configs
lambda_timeout       = 180   # Increased timeout

# Storage
s3_bucket_name      = "f5-comparison-reports-acme"
dynamodb_table_name = "f5-comparison-history"

# Schedule - Monthly
schedule_expression = "cron(0 11 1 * ? *)"

# Tags
environment = "production"
project     = "f5-config-comparison"
owner       = "network-team"
```

---

## Advanced Configuration

### Custom IAM Policies

To add additional permissions:

```hcl
# terraform/iam.tf
resource "aws_iam_role_policy" "lambda_additional" {
  name = "additional-permissions"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "arn:aws:kms:*:*:key/*"
      }
    ]
  })
}
```

### Multiple F5 Pairs

To compare multiple F5 pairs, deploy separate stacks:

```bash
# Stack 1: Primary datacenters
terraform workspace new primary
terraform apply -var-file=primary.tfvars

# Stack 2: DR datacenters
terraform workspace new dr
terraform apply -var-file=dr.tfvars
```

### Custom Alerting Thresholds

Modify `terraform/cloudwatch_alarms.tf`:

```hcl
resource "aws_cloudwatch_metric_alarm" "high_critical_custom" {
  alarm_name          = "f5-high-critical-custom"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 200  # Custom threshold
  # ...
}
```

---

## Validation

### Pre-Deployment Checklist

- [ ] VPC and subnet exist
- [ ] Subnet has route to F5 network
- [ ] SSH keys deployed to F5 servers
- [ ] Secrets Manager secret created
- [ ] Teams webhook tested
- [ ] S3 bucket name is unique
- [ ] All variables in terraform.tfvars
- [ ] No sensitive values in git

### Post-Deployment Validation

```bash
# Verify all resources created
terraform state list

# Test Lambda
aws lambda invoke --function-name f5-config-comparison response.json

# Check logs
aws logs tail /aws/lambda/f5-config-comparison --since 5m

# Verify S3 report
aws s3 ls s3://your-bucket/comparisons/

# Check DynamoDB
aws dynamodb scan --table-name f5-comparison-history --max-items 1
```

---

## Support

For configuration questions:
- Review [DEPLOYMENT.md](DEPLOYMENT.md)
- Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- Open GitHub issue

---

**Configuration complete!** 🎉