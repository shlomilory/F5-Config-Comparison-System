# 🔧 Troubleshooting Guide

Common issues and solutions for the F5 Configuration Comparison System.

---

## Table of Contents

- [Deployment Issues](#deployment-issues)
- [Lambda Execution Issues](#lambda-execution-issues)
- [Network & Connectivity](#network--connectivity)
- [Authentication & Permissions](#authentication--permissions)
- [Data & Storage Issues](#data--storage-issues)
- [Notification Issues](#notification-issues)
- [Performance Issues](#performance-issues)
- [Debugging Tools](#debugging-tools)

---

## Deployment Issues

### Issue: Terraform Init Fails

**Symptoms:**
```
Error: Failed to install provider
Error: Failed to query available provider packages
```

**Causes:**
- No internet connectivity
- Terraform version too old
- Provider registry blocked

**Solutions:**

1. **Check Terraform version:**
   ```bash
   terraform version
   # Should be >= 1.0
   
   # Upgrade if needed
   brew upgrade terraform  # Mac
   # or download from https://www.terraform.io/downloads
   ```

2. **Check internet connectivity:**
   ```bash
   curl -I https://registry.terraform.io
   ```

3. **Use terraform mirror (if registry blocked):**
   ```bash
   terraform providers mirror /path/to/mirror
   terraform init -plugin-dir=/path/to/mirror
   ```

---

### Issue: Terraform Apply Fails - Resource Already Exists

**Symptoms:**
```
Error: error creating S3 bucket: BucketAlreadyExists
Error: error creating DynamoDB table: ResourceInUseException
```

**Cause:** Resources with same name already exist

**Solutions:**

1. **Change resource names in terraform.tfvars:**
   ```hcl
   s3_bucket_name = "f5-comparison-reports-yourcompany-v2"
   dynamodb_table_name = "f5-comparison-history-v2"
   ```

2. **Import existing resources:**
   ```bash
   terraform import aws_s3_bucket.reports f5-comparison-reports
   terraform import aws_dynamodb_table.history f5-comparison-history
   ```

3. **Destroy and recreate:**
   ```bash
   # WARNING: This deletes data!
   terraform destroy
   terraform apply
   ```

---

### Issue: VPC Endpoint Creation Fails

**Symptoms:**
```
Error: error creating VPC Endpoint: InvalidParameter
The specified subnet does not exist
```

**Cause:** Subnet ID is incorrect or doesn't exist

**Solutions:**

1. **Verify subnet exists:**
   ```bash
   aws ec2 describe-subnets \
     --subnet-ids subnet-xxxxxxxxx \
     --region your-region
   ```

2. **List available subnets:**
   ```bash
   aws ec2 describe-subnets \
     --filters "Name=vpc-id,Values=vpc-xxxxxxxxx" \
     --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]' \
     --output table
   ```

3. **Update terraform.tfvars with correct subnet ID**

---

## Lambda Execution Issues

### Issue: Lambda Timeout

**Symptoms:**
```
Task timed out after 120.00 seconds
```

**Causes:**
- F5 configuration files are very large
- Network latency to F5 servers
- SSH connection slow

**Solutions:**

1. **Increase Lambda timeout:**
   ```bash
   aws lambda update-function-configuration \
     --function-name f5-config-comparison \
     --timeout 300 \
     --region your-region
   ```

2. **Increase Lambda memory (more CPU):**
   ```bash
   aws lambda update-function-configuration \
     --function-name f5-config-comparison \
     --memory-size 1024 \
     --region your-region
   ```

3. **Check Lambda logs for bottlenecks:**
   ```bash
   aws logs tail /aws/lambda/f5-config-comparison \
     --since 10m \
     --format short \
     --region your-region
   ```

---

### Issue: Lambda Out of Memory

**Symptoms:**
```
Runtime exited with error: signal: killed
Runtime.ExitError
MemoryError
```

**Cause:** Configuration files too large for allocated memory

**Solutions:**

1. **Increase Lambda memory:**
   ```bash
   aws lambda update-function-configuration \
     --function-name f5-config-comparison \
     --memory-size 2048 \
     --region your-region
   ```

2. **Check memory usage in logs:**
   ```bash
   aws logs tail /aws/lambda/f5-config-comparison \
     --since 10m \
     --filter-pattern "Memory" \
     --region your-region
   ```

**Memory Recommendations:**
- <3,000 VS: 512 MB
- 3,000-5,000 VS: 1024 MB
- 5,000-10,000 VS: 2048 MB
- >10,000 VS: 4096 MB

---

### Issue: Lambda Cannot Find Module

**Symptoms:**
```
Unable to import module 'lambda_function': No module named 'paramiko'
ModuleNotFoundError: No module named 'boto3'
```

**Cause:** Lambda deployment package missing dependencies

**Solutions:**

1. **Rebuild Lambda package with dependencies:**
   ```bash
   cd lambda/
   
   # Install dependencies
   pip install -r requirements.txt -t .
   
   # Create deployment package
   zip -r function.zip .
   
   # Upload to Lambda
   aws lambda update-function-code \
     --function-name f5-config-comparison \
     --zip-file fileb://function.zip \
     --region your-region
   ```

2. **Or redeploy with Terraform:**
   ```bash
   cd terraform/
   terraform apply -replace="aws_lambda_function.f5_comparison"
   ```

---

## Network & Connectivity

### Issue: SSH Connection Timeout

**Symptoms:**
```
[ERROR] Error in lambda handler: [Errno 110] Connection timed out
TimeoutError: [Errno 110] Connection timed out
```

**Causes:**
- Lambda cannot reach F5 servers
- Security group blocking traffic
- No route to F5 network
- Firewall blocking Lambda subnet

**Diagnosis:**

1. **Check Lambda security group egress rules:**
   ```bash
   aws ec2 describe-security-groups \
     --group-ids sg-xxxxxxxxx \
     --query 'SecurityGroups[0].IpPermissionsEgress' \
     --region your-region
   ```
   
   **Should have:**
   - Port 22 to F5 Site 1 IP
   - Port 22 to F5 Site 2 IP

2. **Check route table:**
   ```bash
   aws ec2 describe-route-tables \
     --filters "Name=association.subnet-id,Values=subnet-xxxxxxxxx" \
     --query 'RouteTables[0].Routes' \
     --region your-region
   ```
   
   **Should have route to F5 network** (e.g., 10.0.0.0/8)

3. **Test SSH from a server in same subnet:**
   ```bash
   # Launch test EC2 in same subnet
   ssh -i key.pem user@f5-ip-address
   ```

**Solutions:**

1. **Update security group to allow SSH egress:**
   ```bash
   aws ec2 authorize-security-group-egress \
     --group-id sg-xxxxxxxxx \
     --ip-permissions IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges='[{CidrIp=10.100.50.10/32}]' \
     --region your-region
   ```

2. **Check firewall/Aviatrix rules:**
   - Contact network team
   - Verify Lambda subnet (10.183.0.0/24) can reach F5 network
   - Add firewall rules if needed

3. **Verify F5 SSH is listening:**
   ```bash
   # From machine that can reach F5
   nc -zv f5-ip-address 22
   # Should show: Connection to f5-ip-address 22 port [tcp/ssh] succeeded!
   ```

---

### Issue: SSH Authentication Failed

**Symptoms:**
```
[ERROR] Authentication (publickey) failed
paramiko.ssh_exception.AuthenticationException
Permission denied (publickey)
```

**Causes:**
- Wrong SSH key in Secrets Manager
- Public key not deployed to F5
- F5 user doesn't exist
- Wrong username

**Diagnosis:**

1. **Test SSH key manually:**
   ```bash
   # Download key from Secrets Manager
   aws secretsmanager get-secret-value \
     --secret-id f5_comparison_secrets \
     --query 'SecretString' \
     --output text | jq -r '.private_key' > /tmp/test_key
   
   chmod 600 /tmp/test_key
   
   # Test SSH
   ssh -i /tmp/test_key username@f5-ip-address
   ```

2. **Check F5 authorized_keys:**
   ```bash
   ssh admin@f5-ip-address
   cat ~f5_comparison/.ssh/authorized_keys
   # Should contain your public key
   ```

3. **Verify F5 user exists:**
   ```bash
   ssh admin@f5-ip-address
   tmsh list auth user f5_comparison
   ```

**Solutions:**

1. **Regenerate and redeploy SSH key:**
   ```bash
   # Generate new key
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/f5_new_key
   
   # Deploy to F5 (both servers)
   ssh-copy-id -i ~/.ssh/f5_new_key.pub f5_comparison@f5-site1-ip
   ssh-copy-id -i ~/.ssh/f5_new_key.pub f5_comparison@f5-site2-ip
   
   # Update Secrets Manager
   aws secretsmanager update-secret \
     --secret-id f5_comparison_secrets \
     --secret-string "{\"username\":\"f5_comparison\",\"private_key\":\"$(cat ~/.ssh/f5_new_key)\"}" \
     --region your-region
   ```

2. **Check authorized_keys permissions on F5:**
   ```bash
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/authorized_keys
   ```

---

### Issue: VPC Endpoint Not Working

**Symptoms:**
```
Could not connect to the endpoint URL: "https://s3.region.amazonaws.com/"
Unable to connect to DynamoDB
Secrets Manager timeout
```

**Cause:** VPC endpoint misconfigured or security group blocking

**Diagnosis:**

1. **Verify VPC endpoints exist:**
   ```bash
   aws ec2 describe-vpc-endpoints \
     --filters "Name=vpc-id,Values=vpc-xxxxxxxxx" \
     --query 'VpcEndpoints[*].[VpcEndpointId,ServiceName,State]' \
     --output table \
     --region your-region
   ```
   
   **Should show:** All endpoints in "available" state

2. **Check VPC endpoint security group:**
   ```bash
   aws ec2 describe-security-groups \
     --group-ids sg-yyyyyyyyy \
     --query 'SecurityGroups[0].IpPermissions' \
     --region your-region
   ```
   
   **Should allow:** Ingress from Lambda security group on port 443

**Solutions:**

1. **Update VPC endpoint security group:**
   ```bash
   aws ec2 authorize-security-group-ingress \
     --group-id sg-vpc-endpoints \
     --source-group sg-lambda \
     --protocol tcp \
     --port 443 \
     --region your-region
   ```

2. **Recreate VPC endpoints:**
   ```bash
   cd terraform/
   terraform destroy -target=aws_vpc_endpoint.s3
   terraform apply
   ```

---

## Authentication & Permissions

### Issue: Secrets Manager Access Denied

**Symptoms:**
```
AccessDeniedException: User is not authorized to perform: secretsmanager:GetSecretValue
botocore.exceptions.ClientError: An error occurred (AccessDeniedException)
```

**Cause:** Lambda IAM role lacks permission to access secret

**Diagnosis:**

1. **Check IAM policy:**
   ```bash
   aws iam get-role-policy \
     --role-name f5-comparison-lambda-role \
     --policy-name f5-comparison-lambda-policy \
     --query 'PolicyDocument' \
     --region your-region
   ```

2. **Verify secret ARN pattern:**
   ```bash
   aws secretsmanager describe-secret \
     --secret-id f5_comparison_secrets \
     --query 'ARN' \
     --region your-region
   ```

**Solutions:**

1. **Update IAM policy with wildcard:**
   ```json
   {
     "Effect": "Allow",
     "Action": "secretsmanager:GetSecretValue",
     "Resource": "arn:aws:secretsmanager:region:account:secret:f5_comparison_secrets-*"
   }
   ```

2. **Apply via Terraform:**
   ```bash
   cd terraform/
   terraform apply
   ```

3. **Force Lambda to pick up new policy:**
   ```bash
   terraform apply -replace="aws_lambda_function.f5_comparison"
   ```

---

### Issue: S3 Access Denied

**Symptoms:**
```
An error occurred (AccessDenied) when calling the PutObject operation
ClientError: Access Denied
```

**Cause:** Lambda role lacks S3 permissions

**Solutions:**

1. **Verify IAM policy includes S3:**
   ```bash
   aws iam get-role-policy \
     --role-name f5-comparison-lambda-role \
     --policy-name f5-comparison-lambda-policy \
     --region your-region | jq '.PolicyDocument.Statement[] | select(.Action[] | contains("s3:"))'
   ```

2. **Check S3 bucket policy (if any):**
   ```bash
   aws s3api get-bucket-policy \
     --bucket f5-comparison-reports \
     --region your-region
   ```

3. **Redeploy with Terraform to fix:**
   ```bash
   cd terraform/
   terraform apply
   ```

---

## Data & Storage Issues

### Issue: Report Not Uploaded to S3

**Symptoms:**
- Lambda succeeds but no report in S3
- CloudWatch logs show "Uploaded to S3" but file missing

**Diagnosis:**

1. **Check CloudWatch logs for actual S3 key:**
   ```bash
   aws logs tail /aws/lambda/f5-config-comparison \
     --since 10m \
     --filter-pattern "Uploaded" \
     --region your-region
   ```

2. **List S3 bucket contents:**
   ```bash
   aws s3 ls s3://f5-comparison-reports/comparisons/ \
     --recursive \
     --region your-region
   ```

**Solutions:**

1. **Check S3 lifecycle policies:**
   ```bash
   aws s3api get-bucket-lifecycle-configuration \
     --bucket f5-comparison-reports \
     --region your-region
   ```

2. **Verify S3 bucket exists:**
   ```bash
   aws s3 ls s3://f5-comparison-reports \
     --region your-region
   ```

---

### Issue: DynamoDB Write Failed

**Symptoms:**
```
Error storing in DynamoDB
ProvisionedThroughputExceededException
ValidationException
```

**Causes:**
- Table doesn't exist
- Schema mismatch
- Throttling (unlikely with on-demand)

**Solutions:**

1. **Verify table exists:**
   ```bash
   aws dynamodb describe-table \
     --table-name f5-comparison-history \
     --region your-region
   ```

2. **Check recent writes:**
   ```bash
   aws dynamodb scan \
     --table-name f5-comparison-history \
     --max-items 5 \
     --region your-region
   ```

3. **Recreate table:**
   ```bash
   cd terraform/
   terraform destroy -target=aws_dynamodb_table.comparison_history
   terraform apply
   ```

---

## Notification Issues

### Issue: No Teams Notification Received

**Symptoms:**
- Lambda succeeds
- Logs show "Webhook sent successfully"
- But no message in Teams

**Diagnosis:**

1. **Check CloudWatch logs:**
   ```bash
   aws logs tail /aws/lambda/f5-config-comparison \
     --since 10m \
     --filter-pattern "webhook" \
     --region your-region
   ```

2. **Test webhook manually:**
   ```bash
   curl -X POST \
     -H "Content-Type: application/json" \
     -d '{"text":"Test from command line"}' \
     https://your-teams-webhook-url
   ```

**Solutions:**

1. **Verify webhook URL is correct:**
   ```bash
   aws lambda get-function-configuration \
     --function-name f5-config-comparison \
     --query 'Environment.Variables.TEAMS_WEBHOOK_URL' \
     --region your-region
   ```

2. **Check if webhook expired:**
   - Teams webhooks can be deleted
   - Recreate webhook in Teams
   - Update Lambda environment variable

3. **Verify webhook payload format:**
   - Check Lambda logs for actual payload sent
   - Ensure JSON is valid
   - Test with simplified payload

---

### Issue: Teams Webhook Returns Error

**Symptoms:**
```
[ERROR] Error sending webhook: 400 Client Error
[ERROR] Error sending webhook: Invalid payload
```

**Cause:** Teams webhook payload format incorrect

**Solutions:**

1. **Use simplified payload:**
   ```python
   payload = {"text": "Simple test message"}
   ```

2. **Validate JSON:**
   ```bash
   # Extract payload from logs
   echo '{"text":"test"}' | jq '.'
   ```

3. **Check Teams connector status:**
   - Teams channel → ⋯ → Connectors
   - Verify "Incoming Webhook" is still configured

---

## Performance Issues

### Issue: Slow Execution (>60 seconds)

**Symptoms:**
- Lambda duration > 60 seconds
- Multiple virtual servers (>5,000)

**Diagnosis:**

1. **Check execution time breakdown in logs:**
   ```bash
   aws logs tail /aws/lambda/f5-config-comparison \
     --since 10m \
     --format short \
     --region your-region | grep -E "INFO|seconds"
   ```

2. **Identify bottleneck:**
   - SSH connection slow?
   - File transfer slow?
   - Parsing slow?
   - HTML generation slow?

**Solutions:**

1. **Increase Lambda memory (more CPU):**
   ```bash
   aws lambda update-function-configuration \
     --function-name f5-config-comparison \
     --memory-size 2048 \
     --region your-region
   ```

2. **Optimize code:**
   - Use streaming for large files
   - Parallelize F5 connections
   - Optimize parsing logic

---

## Debugging Tools

### CloudWatch Logs Insights Queries

**Find all errors:**
```
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 50
```

**Execution time analysis:**
```
fields @timestamp, @duration
| stats avg(@duration), max(@duration), min(@duration)
```

**Find timeouts:**
```
fields @timestamp, @message
| filter @message like /Task timed out/
| sort @timestamp desc
```

**SSH connection issues:**
```
fields @timestamp, @message
| filter @message like /SSH|Connection|Authentication/
| sort @timestamp desc
```

---

### Lambda Test Event

**Manual test event:**
```json
{
  "test": true,
  "server1": "10.100.50.10",
  "server2": "10.200.50.10"
}
```

**Invoke with AWS CLI:**
```bash
aws lambda invoke \
  --function-name f5-config-comparison \
  --payload '{"test":true}' \
  --cli-read-timeout 120 \
  --log-type Tail \
  --query 'LogResult' \
  --output text \
  response.json | base64 --decode

cat response.json | jq '.'
```

---

### Check All AWS Resources

**Verify all components:**
```bash
# Lambda
aws lambda get-function --function-name f5-config-comparison

# S3
aws s3 ls s3://f5-comparison-reports

# DynamoDB
aws dynamodb describe-table --table-name f5-comparison-history

# Secrets Manager
aws secretsmanager describe-secret --secret-id f5_comparison_secrets

# VPC Endpoints
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=vpc-xxx"

# EventBridge
aws events describe-rule --name f5-biannual-comparison

# CloudWatch Alarms
aws cloudwatch describe-alarms --alarm-names f5-comparison-high-critical-count
```

---

## Getting Help

### Information to Gather

When seeking help, provide:

1. **CloudWatch Logs:**
   ```bash
   aws logs tail /aws/lambda/f5-config-comparison \
     --since 30m \
     --region your-region > logs.txt
   ```

2. **Lambda Configuration:**
   ```bash
   aws lambda get-function-configuration \
     --function-name f5-config-comparison \
     --region your-region > lambda-config.json
   ```

3. **Error Message:**
   - Full error from CloudWatch Logs
   - Stack trace if available

4. **Environment Details:**
   - AWS region
   - Number of virtual servers
   - F5 software version
   - Network architecture

### Support Channels

- 📚 Review [documentation](../README.md)
- 🐛 Open [GitHub Issue](https://github.com/yourusername/F5-Config-Comparison-System/issues)
- 💬 Community forums

---

## Preventive Measures

### Regular Maintenance

1. **Monthly:**
   - Review CloudWatch logs
   - Check cost explorer
   - Verify reports being generated

2. **Quarterly:**
   - Update Lambda dependencies
   - Rotate SSH keys
   - Review IAM policies

3. **Annually:**
   - Review architecture
   - Update Terraform
   - Audit security

---

**Most issues are related to network connectivity or IAM permissions.**

**Always start by checking CloudWatch Logs!** 🔍