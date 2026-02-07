variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "mcp-server"
}

variable "app_env" {
  description = "Application environment"
  type        = string
  default     = "production"
}

variable "vpc_id" {
  description = "VPC ID where ECS tasks will run"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the ECS tasks"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "task_cpu" {
  description = "CPU units for the task (256, 512, 1024, etc.)"
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Memory for the task in MB (512, 1024, 2048, etc.)"
  type        = string
  default     = "512"
}

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = 8000
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

variable "assign_public_ip" {
  description = "Assign public IP to ECS tasks"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project   = "mcp-server"
    ManagedBy = "Terraform"
  }
}

# Secrets variables
variable "cognito_region" {
  description = "AWS Cognito region"
  type        = string
  default     = "us-east-1"
}

variable "user_pool_id" {
  description = "Cognito User Pool ID"
  type        = string
  sensitive   = true
}

variable "app_client_id" {
  description = "Cognito App Client ID"
  type        = string
  sensitive   = true
}

variable "oauth_client_id" {
  description = "OAuth Client ID"
  type        = string
  sensitive   = true
}

variable "oauth_client_secret" {
  description = "OAuth Client Secret"
  type        = string
  sensitive   = true
}

variable "token_url" {
  description = "OAuth Token URL"
  type        = string
  sensitive   = true
}
