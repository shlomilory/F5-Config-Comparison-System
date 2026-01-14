# 🏗️ Architecture Documentation

## System Architecture Overview

The F5 Configuration Comparison System is built on AWS serverless architecture with a focus on security, cost optimization, and operational excellence.

---

## Architecture Principles

### 1. **Serverless-First**
- Event-driven execution (no servers to manage)
- Pay-per-use pricing model
- Automatic scaling (not needed, but available)
- Zero maintenance overhead

### 2. **Security by Design**
- Private VPC with no internet gateway
- VPC endpoints for AWS service access
- SSH key-based authentication
- Secrets stored in AWS Secrets Manager
- Least-privilege IAM policies
- Sensitive data masking in reports

### 3. **Cost Optimization**
- VPC endpoints instead of NAT Gateway ($32/month savings)
- On-demand Lambda execution (only pay for actual runs)
- S3 lifecycle policies for old reports
- DynamoDB TTL for automatic cleanup
- Biannual schedule minimizes execution

### 4. **Operational Excellence**
- Infrastructure as Code (100% Terraform)
- Comprehensive logging and monitoring
- Automated alerting
- Historical tracking
- Self-documenting code

---

## Detailed Component Architecture

### AWS Lambda Function

**Purpose:** Core comparison engine

**Configuration:**
```
Runtime: Python 3.11
Memory: 512 MB
Timeout: 120 seconds
VPC: Private subnet with VPC endpoints
IAM Role: Least-privilege permissions
```

**Key Responsibilities:**
1. Retrieve SSH credentials from Secrets Manager
2. Connect to F5 servers via SSH/SFTP
3. Download configuration files
4. Parse LTM virtual server configurations
5. Perform site-aware intelligent comparison
6. Generate interactive HTML report
7. Upload report to S3
8. Store metadata in DynamoDB
9. Publish metrics to CloudWatch
10. Send Teams notification

**Execution Flow:**
```python
lambda_handler(event, context)
  ↓
get_ssh_credentials() → Secrets Manager
  ↓
copy_file_from_remote(server1) → F5 Site 1
copy_file_from_remote(server2) → F5 Site 2
  ↓
mask_sensitive_data(config1)
mask_sensitive_data(config2)
  ↓
parse_ltm_virtual_servers(config1)
parse_ltm_virtual_servers(config2)
  ↓
compare_virtual_servers(vs1, vs2)
  ↓
analyze_patterns(comparison_data) → Smart analysis
  ↓
generate_enhanced_html(...)
  ↓
upload_to_s3(report)
  ↓
store_comparison_metadata(dynamodb)
  ↓
publish_cloudwatch_metrics(...)
  ↓
send_enhanced_webhook(teams)
```

---

### VPC Architecture

**Network Design:**

```
VPC: ${var.vpc_id}
├─ Private Subnet: ${var.subnet_id}
│  ├─ Lambda ENI (Elastic Network Interface)
│  └─ Security Group: lambda-sg
│     ├─ Egress to F5 servers (SSH port 22)
│     ├─ Egress to VPC endpoints (HTTPS port 443)
│     └─ Egress to internet (HTTPS for Teams)
│
├─ VPC Endpoints (6 total):
│  ├─ S3 (Gateway endpoint - no cost per hour)
│  ├─ DynamoDB (Gateway endpoint - no cost per hour)
│  ├─ Secrets Manager (Interface endpoint)
│  ├─ CloudWatch Logs (Interface endpoint)
│  ├─ CloudWatch Monitoring (Interface endpoint)
│  └─ SNS (Interface endpoint)
│
└─ Security Group: vpc-endpoints-sg
   └─ Ingress from lambda-sg (HTTPS port 443)
```

**Why No NAT Gateway?**
- VPC endpoints provide private access to AWS services
- Lambda only needs to reach AWS services and F5 servers
- Saves $32/month (NAT Gateway cost)
- More secure (no internet exposure)

**Network Path to F5 Servers:**
```
Lambda (10.183.0.x)
  ↓
VPC Route Table
  ↓
Transit Gateway / VPN / Direct Connect
  ↓
On-Premises Network
  ↓
F5 Servers (10.x.x.x, 10.y.y.y)
```

---

### Storage Architecture

#### **Amazon S3**

**Bucket Structure:**
```
s3://f5-comparison-reports/
├─ comparisons/
│  ├─ 20260111-141729_f5_ltm_comparison.zip
│  ├─ 20260701-120000_f5_ltm_comparison.zip
│  └─ ...
```

**Configuration:**
- Versioning: Enabled
- Encryption: AES-256 (SSE-S3)
- Public Access: Blocked
- Lifecycle Policy:
  - Move to Glacier after 90 days
  - Delete after 365 days

**Access:**
- Lambda: PutObject, GetObject
- Users: Presigned URLs (7-day expiration)

#### **Amazon DynamoDB**

**Table Design:**
```
Table: f5-comparison-history
├─ Primary Key: comparison_id (String)
│  Format: "{server1}_vs_{server2}"
│  Example: "10.x.x.x_vs_10.y.y.y"
│
├─ Sort Key: timestamp (String)
│  Format: ISO 8601
│  Example: "2026-01-11T14:17:29Z"
│
├─ Attributes:
│  ├─ server1 (String)
│  ├─ server2 (String)
│  ├─ s3_url (String)
│  ├─ total_vs (Number)
│  ├─ with_differences (Number)
│  ├─ critical_count (Number)
│  ├─ warning_count (Number)
│  ├─ match_count (Number)
│  ├─ no_redundancy_count (Number)
│  ├─ critical_percentage (Number)
│  ├─ warning_percentage (Number)
│  ├─ match_percentage (Number)
│  ├─ risk_level (String: LOW/MEDIUM/HIGH)
│  ├─ assessment (String)
│  └─ ttl (Number: Unix timestamp)
│
└─ TTL: 90 days (automatic deletion)
```

**Capacity Mode:** On-demand (no capacity planning needed)

---

### Monitoring & Alerting

#### **CloudWatch Logs**

**Log Groups:**
```
/aws/lambda/f5-config-comparison
├─ Execution logs
├─ SSH connection details
├─ Comparison statistics
├─ Error traces
└─ Performance metrics
```

**Retention:** 30 days

#### **CloudWatch Metrics**

**Custom Metrics (Namespace: F5/ConfigComparison):**
- `TotalVirtualServers` (Count)
- `CriticalCount` (Count)
- `WarningCount` (Count)
- `MatchCount` (Count)
- `CriticalPercentage` (Percent)

**Standard Lambda Metrics:**
- Invocations
- Errors
- Duration
- Throttles
- ConcurrentExecutions

#### **CloudWatch Alarms**

**1. High Critical Count**
```
Metric: CriticalCount
Threshold: > 150 (> 6% of 2,500 servers)
Period: 5 minutes
Actions: SNS notification
```

**2. Lambda Errors**
```
Metric: Errors
Threshold: > 0
Period: 5 minutes
Actions: SNS notification
```

---

### Security Architecture

#### **IAM Roles & Policies**

**Lambda Execution Role:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::f5-comparison-reports",
        "arn:aws:s3:::f5-comparison-reports/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:Query"
      ],
      "Resource": "arn:aws:dynamodb:${region}:${account}:table/f5-comparison-history"
    },
    {
      "Effect": "Allow",
      "Action": "secretsmanager:GetSecretValue",
      "Resource": "arn:aws:secretsmanager:${region}:${account}:secret:f5_comparison_secrets-*"
    },
    {
      "Effect": "Allow",
      "Action": "sns:Publish",
      "Resource": "arn:aws:sns:${region}:${account}:f5-comparison-notifications"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:${region}:${account}:log-group:/aws/lambda/f5-config-comparison*"
    },
    {
      "Effect": "Allow",
      "Action": "cloudwatch:PutMetricData",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface"
      ],
      "Resource": "*"
    }
  ]
}
```

**Principle:** Least privilege - only permissions required for operation

#### **Secrets Management**

**Secret Structure:**
```json
{
  "username": "f5_username",
  "private_key": "-----BEGIN RSA PRIVATE KEY-----\n..."
}
```

**Access Pattern:**
1. Lambda retrieves secret at runtime
2. Writes private key to /tmp (ephemeral)
3. Uses Paramiko for SSH authentication
4. /tmp cleared after execution

**Rotation:** Manual (recommend quarterly rotation)

---

### Scheduling Architecture

#### **EventBridge Rule**

**Schedule Expression:**
```
cron(0 11 1 1,7 ? *)
```

**Translation:**
- Minute: 0
- Hour: 11 (UTC)
- Day of Month: 1
- Month: 1, 7 (January, July)
- Day of Week: ? (any)
- Year: * (every year)

**Execution Times:**
- January 1 at 11:00 UTC
- July 1 at 11:00 UTC

**Target:** Lambda function
**Retry Policy:** 2 retries with exponential backoff
**Dead Letter Queue:** SNS topic for failed invocations

---

## Comparison Logic Architecture

### Site-Aware Intelligence

**IP Normalization:**
```python
def normalize_site_ip(ip_str):

    if matches_pattern("10.100.x.x"):
        return normalize_to_SITE_pattern(), 'SITE1'
    elif matches_pattern("10.200.x.x"):
        return normalize_to_SITE_pattern(), 'SITE2'
    else:
        return ip_str, 'OTHER'
```

**Classification Logic:**
```python
def classify_ip_difference(ip1, ip2):
    norm1, site1 = normalize_site_ip(ip1)
    norm2, site2 = normalize_site_ip(ip2)
    
    if norm1 == norm2:
        return (False, 'MATCH')  # Same host, different sites
    
    if site1 == site2:
        return (True, 'CRITICAL')  # Same site, different hosts
    
    if site1 != site2:
        return (True, 'WARNING')  # Different sites, different hosts
```

### Environment Classification

**Pattern Matching:**
```python
def get_environment_type(vs_name):
    name_lower = vs_name.lower()
    
    if name_lower.startswith('prod'):
        return 'PROD'
    elif name_lower.startswith('corp') or name_lower.startswith('crp'):
        return 'CORP'
    elif name_lower.startswith('sb'):
        return 'SANDBOX'
    else:
        return 'UNKNOWN'
```

**Risk Adjustment by Environment:**
- **PROD:** IP differences = CRITICAL
- **CORP:** IP differences = WARNING
- **SANDBOX:** IP differences = WARNING
- **All Environments:** Cross-site IPs ignored (expected)

### Risk Scoring

**Formula:**
```
Critical Percentage = (Critical Count / Total Virtual Servers) × 100

Risk Level:
- LOW: < 1%
- MEDIUM: 1-5%
- HIGH: > 5%
```

**Assessment:**
- LOW: "Minimal critical issues"
- MEDIUM: "Some critical issues require attention"
- HIGH: "Significant critical issues detected"

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        EXECUTION TRIGGER                         │
│  EventBridge Rule (Biannual) OR Manual Invocation               │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      LAMBDA INITIALIZATION                       │
│  1. Load environment variables                                   │
│  2. Initialize AWS clients (S3, DynamoDB, Secrets, CloudWatch)  │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CREDENTIAL RETRIEVAL                          │
│  Secrets Manager → Get SSH username + private key               │
│  Write private key to /tmp/id_rsa                               │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
                    ▼                   ▼
        ┌──────────────────┐  ┌──────────────────┐
        │  F5 SITE 1       │  │  F5 SITE 2       │
        │  SSH Connect     │  │  SSH Connect     │
        │  SFTP Download   │  │  SFTP Download   │
        │  /config/bigip   │  │  /config/bigip   │
        └────────┬─────────┘  └────────┬─────────┘
                 │                     │
                 └─────────┬───────────┘
                           │
                           ▼
        ┌─────────────────────────────────────┐
        │     CONFIGURATION PROCESSING        │
        │  1. Mask sensitive data             │
        │  2. Parse LTM virtual servers       │
        │  3. Extract configurations          │
        └─────────────────┬───────────────────┘
                          │
                          ▼
        ┌─────────────────────────────────────┐
        │    INTELLIGENT COMPARISON           │
        │  1. Site-aware IP analysis          │
        │  2. Environment classification      │
        │  3. Risk scoring                    │
        │  4. Pattern analysis                │
        └─────────────────┬───────────────────┘
                          │
                          ▼
        ┌─────────────────────────────────────┐
        │      REPORT GENERATION              │
        │  1. Generate HTML with JavaScript   │
        │  2. Compress to ZIP                 │
        │  3. Generate presigned URL          │
        └─────────────────┬───────────────────┘
                          │
            ┌─────────────┼─────────────┬─────────────┐
            │             │             │             │
            ▼             ▼             ▼             ▼
        ┌─────┐     ┌─────────┐   ┌──────────┐  ┌────────┐
        │ S3  │     │DynamoDB │   │CloudWatch│  │ Teams  │
        │Store│     │Metadata │   │ Metrics  │  │Webhook │
        └─────┘     └─────────┘   └──────────┘  └────────┘
```

---

## Scalability Considerations

### Current Scale
- **Virtual Servers:** ~2,500
- **Execution Time:** ~16 seconds
- **Memory Usage:** ~186 MB (of 512 MB allocated)
- **Frequency:** 2 times per year

### Scale Limits
- **Lambda Memory:** Can increase to 10,240 MB if needed
- **Lambda Timeout:** Can increase to 900 seconds (15 minutes)
- **Virtual Servers:** Tested with 2,500, can likely handle 10,000+
- **Concurrent Executions:** Not a concern (biannual schedule)

### Optimization for Larger Scale
1. **Parallel Processing:** Add threading for F5 downloads
2. **Streaming:** Process configs incrementally instead of in-memory
3. **Chunking:** Split comparison into batches
4. **Step Functions:** Orchestrate multi-stage processing

---

## Disaster Recovery

### Backup Strategy
- **S3:** Cross-region replication (optional)
- **DynamoDB:** Point-in-time recovery enabled
- **Terraform State:** Stored in S3 with versioning

### Recovery Procedures
1. **Lambda Failure:** Automatic retry by EventBridge
2. **Complete Region Failure:** Redeploy in new region via Terraform
3. **Data Loss:** Restore from S3 versioning or DynamoDB backups

### RTO/RPO
- **RTO (Recovery Time Objective):** < 1 hour (Terraform redeploy)
- **RPO (Recovery Point Objective):** 0 (S3 versioning, DynamoDB PITR)

---

## Future Architecture Enhancements

### Planned Improvements
1. **Multi-Region Support**
   - Deploy Lambda in multiple regions
   - Compare F5 servers across global sites

2. **Real-Time Monitoring**
   - Add continuous drift detection
   - Hourly sampling instead of biannual

3. **Automated Remediation**
   - Generate Terraform configs for fixes
   - Auto-create tickets in Jira/ServiceNow

4. **Enhanced Analytics**
   - Grafana dashboard for metrics
   - Trend analysis over time
   - Predictive alerting (ML-based)

5. **API Gateway**
   - REST API for on-demand comparisons
   - Web UI for report browsing

---

## References

- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [AWS VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/)
- [Paramiko Documentation](http://docs.paramiko.org/)
- [F5 BIG-IP Configuration Guide](https://techdocs.f5.com/)