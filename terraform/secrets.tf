# Secrets Manager Secret
resource "aws_secretsmanager_secret" "app_secrets" {
  name                    = "${var.project_name}-secrets"
  description             = "Application secrets for ${var.project_name}"
  recovery_window_in_days = 7

  tags = var.tags
}

# Secrets Manager Secret Version
resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    COGNITO_REGION       = var.cognito_region
    USER_POOL_ID         = var.user_pool_id
    APP_CLIENT_ID        = var.app_client_id
    OAUTH_CLIENT_ID      = var.oauth_client_id
    OAUTH_CLIENT_SECRET  = var.oauth_client_secret
    TOKEN_URL            = var.token_url
  })
}
