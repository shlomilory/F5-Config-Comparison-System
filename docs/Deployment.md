# 🚀 Deployment Guide

Complete step-by-step guide to deploy the F5 Configuration Comparison System to your AWS environment.

---

## Prerequisites

### Required Tools

- **AWS Account** with appropriate permissions
- **AWS CLI** (v2.x or later) configured with credentials
- **Terraform** (>= 1.0) installed
- **Git** for version control
- **SSH Access** to F5 servers
- **Text Editor** (VS Code, Sublime, etc.)

### Required Permissions

Your AWS user/role needs these permissions:
- Lambda (CreateFunction, UpdateFunctionCode, etc.)
- IAM (CreateRole, AttachRolePolicy, etc.)
- S3 (CreateBucket, PutObject, etc.)
- DynamoDB (CreateTable, etc.)
- VPC (CreateVpcEndpoint, etc.)
- Secrets Manager (CreateSecret, PutSecretValue, etc.)
- CloudWatch (CreateLogGroup, PutMetricAlarm, etc.)
- SNS (CreateTopic, Subscribe, etc.)
- EventBridge (PutRule, PutTargets, etc.)

### Network Requirements

- **VPC** with private subnet(s)
- **Network connectivity** to F5 servers (VPN, Direct Connect, or Transit Gateway)
- **Route** from Lambda subnet to F5 network (10.x.x.x)
- **Security groups** allowing SSH (port 22) to F5 servers

---

## Deployment Overview

```
Total Time: ~30 minutes
Difficulty: Intermediate
Steps: 8 main phases
```

---

## Phase 1: Repository Setup

### 1.1 Clone the Repository

```bash
git clone https://github.com/yourusername/F5-Config-Comparison-System.git
cd F5-Config-Comparison-System
```

### 1.2 Review Project Structure

```
F5-Config-Comparison-System/
├── README.md
├── terraform/           # Infrastructure as Code
├── lambda/             # Lambda function code
├── docs/               # Documentation
└── examples/           # Sample outputs
```

---

## Phase 2: F5 Server Preparation

### 2.1 Create F5 User Account

On **both F5 servers**, create a dedicated user:

```bash
# SSH to F5 server
ssh admin@f5-server-ip

# Create user (choose appropriate UID)
tmsh create auth user f5_comparison password <initial-password> \
  shell tmsh partition-access add { all-partitions { role admin } }

# Set user home directory
tmsh modify auth user f5_comparison shell bash

# Save config
tmsh save sys config
```

### 2.2 Generate SSH Key Pair

On your **local machine**:

```bash
# Generate 4096-bit RSA key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/f5_comparison_key -C "f5_comparison"

# Set proper permissions
chmod 600 ~/.ssh/f5_comparison_key
chmod 644 ~/.ssh/f5_comparison_key.pub

# View public key
cat ~/.ssh/f5_comparison_key.pub
```

### 2.3 Deploy Public Key to F5 Servers

On **each F5 server**:

```bash
# SSH as the new user
ssh f5_comparison@f5-server-ip

# Create .ssh directory
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Add public key to authorized_keys
cat >> ~/.ssh/authorized_keys << 'EOF'
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC... f5_comparison
EOF

# Set permissions
chmod 600 ~/.ssh/authorized_keys

# Exit and test key-based auth
exit
ssh -i ~/.ssh/f5_comparison_key f5_comparison@f5-server-ip
```

### 2.4 Verify Config File Access

```bash
# Verify user can read config
ssh -i ~/.ssh/f5_comparison_key f5_comparison@f5-server-ip \
  "cat /config/bigip.conf | head -20"

# Should display F5 configuration
```

---

## Phase 3: AWS Configuration

### 3.1 Configure AWS CLI

```bash
# Configure AWS credentials
aws configure

# Verify access
aws sts get-caller-identity

# Set region
export AWS_REGION=us-east-1  # or your preferred region
```

### 3.2 Identify Network Resources

Get your VPC and subnet information:

```bash
# List VPCs
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' --output table

# List subnets in your VPC
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-xxxxxxxxx" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Note down:
# - VPC ID: vpc-xxxxxxxxx
# - Subnet ID: subnet-xxxxxxxxx
# - Availability Zone: us-east-1a
```

### 3.3 Verify Network Connectivity

```bash
# Check route table for subnet
aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=subnet-xxxxxxxxx" \
  --query 'RouteTables[0].Routes' \
  --output table

# Verify route to F5 network (10.x.x.x/8 or similar)
```

---

## Phase 4: Store SSH Credentials in Secrets Manager

### 4.1 Create Secret JSON

```bash
# Read private key and create JSON (Linux/Mac)
cat > /tmp/f5_secret.json <<EOF
{
  "username": "f5_comparison",
  "private_key": "$(cat ~/.ssh/f5_comparison_key)"
}
EOF

# For Windows PowerShell:
# $key = Get-Content ~/.ssh/f5_comparison_key -Raw
# $secret = @{username="f5_comparison"; private_key=$key} | ConvertTo-Json
# $secret | Out-File -FilePath f5_secret.json -Encoding ASCII
```

### 4.2 Create Secret in AWS

```bash
# Create secret
aws secretsmanager create-secret \
  --name f5_comparison_secrets \
  --description "SSH credentials for F5 comparison tool" \
  --secret-string file:///tmp/f5_secret.json \
  --region $AWS_REGION

# Verify secret was created
aws secretsmanager describe-secret \
  --secret-id f5_comparison_secrets \
  --region $AWS_REGION

# Clean up local file
rm /tmp/f5_secret.json
```

### 4.3 Note the Secret ARN

```bash
# Get secret ARN (you'll need this)
aws secretsmanager describe-secret \
  --secret-id f5_comparison_secrets \
  --region $AWS_REGION \
  --query 'ARN' \
  --output text
```

---

## Phase 5: Configure Microsoft Teams Webhook

### 5.1 Create Incoming Webhook in Teams

1. Open Microsoft Teams
2. Navigate to your target channel
3. Click **⋯** (three dots) → **Connectors**
4. Search for **"Incoming Webhook"**
5. Click **Configure**
6. Name: `F5 Configuration Alerts`
7. (Optional) Upload icon
8. Click **Create**
9. **Copy the webhook URL** (starts with `https://...webhook.office.com/...`)

### 5.2 Test Webhook (Optional)

```bash
# Test webhook with curl
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"text":"🧪 Test from F5 Comparison System - Setup in progress!"}' \
  https://your-webhook-url-here
```

---

## Phase 6: Configure Terraform

### 6.1 Navigate to Terraform Directory

```bash
cd terraform/
```

### 6.2 Create terraform.tfvars

```bash
# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars  # or use your preferred editor
```

### 6.3 Configure Variables

Edit `terraform.tfvars`:

```hcl
# ============================================================================
# AWS Configuration
# ============================================================================
aws_region  = "us-east-1"        # Your AWS region
aws_profile = "default"           # AWS CLI profile name

# ============================================================================
# Network Configuration
# ============================================================================
vpc_id            = "vpc-xxxxxxxxx"          # Your VPC ID
subnet_id         = "subnet-xxxxxxxxx"       # Private subnet ID
availability_zone = "us-east-1a"             # Subnet's AZ

# ============================================================================
# F5 Server Configuration
# ============================================================================
f5_site1_ip    = "10.100.50.10"              # F5 Site 1 IP address
f5_site2_ip    = "10.200.50.10"              # F5 Site 2 IP address
f5_config_path = "/config/bigip.conf"        # Path to config file

# ============================================================================
# Secrets & Notifications
# ============================================================================
secret_name       = "f5_comparison_secrets"                    # Secret name in Secrets Manager
teams_webhook_url = "https://your-teams-webhook-url"           # Teams webhook URL
sns_email         = "your-email@example.com"                   # Email for SNS alerts

# ============================================================================
# Lambda Configuration
# ============================================================================
lambda_function_name = "f5-config-comparison"
lambda_memory_size   = 512                   # MB (512-10240)
lambda_timeout       = 120                   # seconds (max 900)

# ============================================================================
# Storage Configuration
# ============================================================================
s3_bucket_name      = "f5-comparison-reports-your-company"      # Unique bucket name
dynamodb_table_name = "f5-comparison-history"

# ============================================================================
# Scheduling
# ============================================================================
# Biannual: January 1 and July 1 at 11:00 UTC
schedule_expression = "cron(0 11 1 1,7 ? *)"

# For testing: Every day at 14:00 UTC
# schedule_expression = "cron(0 14 * * ? *)"

# ============================================================================
# Tags
# ============================================================================
environment = "production"
project     = "f5-config-comparison"
owner       = "devops-team"
```

### 6.4 Review Main Configuration

Check `main.tf` to ensure all resources match your requirements.

---

## Phase 7: Deploy Infrastructure with Terraform

### 7.1 Initialize Terraform

```bash
# Initialize Terraform (downloads providers)
terraform init

# Expected output:
# Terraform has been successfully initialized!
```

### 7.2 Validate Configuration

```bash
# Validate syntax
terraform validate

# Expected output:
# Success! The configuration is valid.
```

### 7.3 Plan Deployment

```bash
# Generate execution plan
terraform plan -out=tfplan

# Review the plan carefully:
# - How many resources will be created?
# - Are all values correct?
# - Any unexpected changes?
```

**Expected resources (~25):**
- 1 Lambda function
- 1 Lambda permission
- 1 IAM role + 1 IAM policy
- 1 S3 bucket + lifecycle config
- 1 DynamoDB table
- 1 Secrets Manager secret (reference)
- 6 VPC endpoints
- 2 Security groups
- 1 SNS topic
- 1 EventBridge rule + target
- 2 CloudWatch alarms
- 1 CloudWatch log group

### 7.4 Apply Configuration

```bash
# Apply the plan
terraform apply tfplan

# Or apply without pre-generated plan:
terraform apply

# Type 'yes' when prompted

# Expected time: 3-5 minutes
```

### 7.5 Capture Outputs

```bash
# View all outputs
terraform output

# Save specific outputs
terraform output lambda_function_arn
terraform output s3_bucket_name
terraform output dynamodb_table_name
```

---

## Phase 8: Testing & Verification

### 8.1 Manual Lambda Test

```bash
# Invoke Lambda manually
aws lambda invoke \
  --function-name f5-config-comparison \
  --region $AWS_REGION \
  --cli-read-timeout 120 \
  --log-type Tail \
  --query 'LogResult' \
  --output text \
  response.json | base64 --decode

# Check response
cat response.json | jq '.'
```

**Expected response:**
```json
{
  "statusCode": 200,
  "body": "{\"message\":\"F5 LTM comparison completed successfully\",\"servers\":[\"10.x.x.x\",\"10.y.y.y\"],\"timestamp\":\"20260111-141729\"}"
}
```

### 8.2 Check CloudWatch Logs

```bash
# Tail Lambda logs (real-time)
aws logs tail /aws/lambda/f5-config-comparison \
  --follow \
  --region $AWS_REGION

# Or get recent logs
aws logs tail /aws/lambda/f5-config-comparison \
  --since 5m \
  --region $AWS_REGION \
  --format short
```

**Expected logs:**
```
[INFO] Starting F5 LTM virtual server comparison
[INFO] Retrieved SSH credentials successfully
[INFO] Connecting to 10.x.x.x via SSH
[INFO] Connected successfully
[INFO] Connecting to 10.y.y.y via SSH
[INFO] Connected successfully
[INFO] Found 1234 virtual servers in 10.x.x.x
[INFO] Found 1267 virtual servers in 10.y.y.y
[INFO] Analysis complete - Risk Level: MEDIUM
[INFO] Report generated successfully
[INFO] Uploaded to S3
[INFO] Teams notification sent
```

### 8.3 Verify S3 Report

```bash
# List reports in S3
aws s3 ls s3://f5-comparison-reports-your-company/comparisons/ \
  --region $AWS_REGION

# Download latest report
LATEST_REPORT=$(aws s3 ls s3://f5-comparison-reports-your-company/comparisons/ \
  --region $AWS_REGION | sort | tail -1 | awk '{print $4}')

aws s3 cp s3://f5-comparison-reports-your-company/comparisons/$LATEST_REPORT . \
  --region $AWS_REGION

# Extract and open
unzip $LATEST_REPORT
open comparison.html  # or start comparison.html on Windows
```

### 8.4 Check DynamoDB

```bash
# Query comparison history
aws dynamodb scan \
  --table-name f5-comparison-history \
  --region $AWS_REGION \
  --max-items 5

# Get specific comparison
aws dynamodb get-item \
  --table-name f5-comparison-history \
  --key '{"comparison_id":{"S":"10.x.x.x_vs_10.y.y.y"}}' \
  --region $AWS_REGION
```

### 8.5 Verify Teams Notification

Check your Microsoft Teams channel for the notification card with:
- Comparison summary
- Statistics (critical, warnings, matches)
- Risk assessment
- Link to detailed report

### 8.6 Check CloudWatch Metrics

```bash
# List custom metrics
aws cloudwatch list-metrics \
  --namespace "F5/ConfigComparison" \
  --region $AWS_REGION

# Get latest critical count
aws cloudwatch get-metric-statistics \
  --namespace "F5/ConfigComparison" \
  --metric-name CriticalCount \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Maximum \
  --region $AWS_REGION
```

---

## Phase 9: Schedule Verification

### 9.1 Verify EventBridge Rule

```bash
# Get rule details
aws events describe-rule \
  --name f5-biannual-comparison \
  --region $AWS_REGION

# Verify schedule expression
aws events describe-rule \
  --name f5-biannual-comparison \
  --region $AWS_REGION \
  --query 'ScheduleExpression' \
  --output text
```

Expected: `cron(0 11 1 1,7 ? *)`

### 9.2 Verify Lambda Permission

```bash
# Check Lambda resource policy
aws lambda get-policy \
  --function-name f5-config-comparison \
  --region $AWS_REGION | jq '.Policy | fromjson'
```

Should show EventBridge permission to invoke Lambda.

---

## Troubleshooting

### Common Issues

#### 1. Lambda Timeout

**Symptom:** Lambda times out after 120 seconds

**Solution:**
```bash
# Increase timeout
aws lambda update-function-configuration \
  --function-name f5-config-comparison \
  --timeout 300 \
  --region $AWS_REGION
```

#### 2. SSH Connection Failed

**Symptom:** `Connection timed out` or `Permission denied`

**Diagnosis:**
```bash
# Test SSH from local machine
ssh -i ~/.ssh/f5_comparison_key f5_comparison@10.x.x.x

# Check Lambda security group
aws ec2 describe-security-groups \
  --group-ids sg-xxxxxxxxx \
  --region $AWS_REGION

# Verify route table
aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=subnet-xxxxxxxxx" \
  --region $AWS_REGION
```

**Solutions:**
- Verify security group allows egress to F5 IPs on port 22
- Check route table has path to F5 network
- Verify F5 allows SSH from Lambda subnet
- Check firewall rules (e.g., Aviatrix, Palo Alto)

#### 3. Secrets Manager Access Denied

**Symptom:** `AccessDeniedException` when retrieving secret

**Solution:**
```bash
# Check IAM policy
aws iam get-role-policy \
  --role-name f5-comparison-lambda-role \
  --policy-name f5-comparison-lambda-policy \
  --region $AWS_REGION

# Verify secret ARN pattern in policy matches actual secret
aws secretsmanager describe-secret \
  --secret-id f5_comparison_secrets \
  --region $AWS_REGION \
  --query 'ARN'
```

#### 4. VPC Endpoint Issues

**Symptom:** Cannot reach AWS services (S3, DynamoDB, etc.)

**Solution:**
```bash
# Verify VPC endpoints exist
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=vpc-xxxxxxxxx" \
  --region $AWS_REGION

# Check endpoint security group
aws ec2 describe-security-groups \
  --group-ids sg-yyyyyyyyy \
  --region $AWS_REGION
```

#### 5. Teams Webhook Not Working

**Symptom:** No Teams notification received

**Diagnosis:**
- Check CloudWatch logs for webhook errors
- Test webhook manually with curl
- Verify webhook URL is correct

**Solution:**
```bash
# Test webhook
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"text":"Test"}' \
  https://your-webhook-url
```

---

## Maintenance

### Update Lambda Code

```bash
# After updating lambda/lambda_function.py
cd lambda/
zip -r ../function.zip .

aws lambda update-function-code \
  --function-name f5-config-comparison \
  --zip-file fileb://../function.zip \
  --region $AWS_REGION

# Or use Terraform
cd ../terraform/
terraform apply -replace="aws_lambda_function.f5_comparison"
```

### Rotate SSH Keys

```bash
# Generate new key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/f5_comparison_key_new

# Deploy to F5 servers
# Update secret in Secrets Manager
aws secretsmanager update-secret \
  --secret-id f5_comparison_secrets \
  --secret-string file:///tmp/new_secret.json \
  --region $AWS_REGION

# Test Lambda
aws lambda invoke \
  --function-name f5-config-comparison \
  --region $AWS_REGION \
  response.json
```

### Update Schedule

```bash
# Edit terraform/variables.tf or terraform.tfvars
# Change schedule_expression

# Apply changes
cd terraform/
terraform apply

# Verify
aws events describe-rule \
  --name f5-biannual-comparison \
  --region $AWS_REGION
```

---

## Cleanup / Decommissioning

### Remove All Resources

```bash
# WARNING: This will delete all data!

cd terraform/

# Destroy infrastructure
terraform destroy

# Type 'yes' when prompted

# Manually delete S3 bucket if needed
aws s3 rb s3://f5-comparison-reports-your-company \
  --force \
  --region $AWS_REGION

# Delete secret
aws secretsmanager delete-secret \
  --secret-id f5_comparison_secrets \
  --force-delete-without-recovery \
  --region $AWS_REGION
```

---

## Next Steps

1. **Monitor First Few Runs**
   - Check logs for any issues
   - Verify reports are accurate
   - Adjust thresholds if needed

2. **Set Up Alerts**
   - Configure SNS email subscriptions
   - Add CloudWatch alarm actions
   - Test alerting workflow

3. **Documentation**
   - Document any custom configurations
   - Create runbooks for your team
   - Update wiki/confluence

4. **Optimization**
   - Review costs after first month
   - Adjust Lambda memory if needed
   - Optimize schedule if required

---

## Support

For issues or questions:
- Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- Review CloudWatch logs
- Open GitHub issue
- Contact maintainers

---

**Deployment complete! 🎉**

Your F5 Configuration Comparison System is now running in production!