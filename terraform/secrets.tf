# ============================================================================
# SECRETS MANAGER FOR F5 CREDENTIALS
# ============================================================================

resource "aws_secretsmanager_secret" "f5_credentials" {
  name        = var.secret_name
  description = "SSH credentials for F5 configuration comparison"

  recovery_window_in_days = 7

  tags = merge(
    var.tags,
    {
      Name = "${var.secret_name}-${var.environment}"
    }
  )
}

# Note: Secret value should be set manually or via separate secure process
# Example structure:
# {
#   "username": "f5_comparison_user",
#   "private_key": "-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----"
# }