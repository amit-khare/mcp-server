# Terraform ECS Deployment for MCP Server

This Terraform configuration deploys the MCP server to AWS ECS Fargate.

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform installed (>= 1.0)
3. Docker image built and pushed to ECR
4. VPC with private subnets

## Setup

1. **Copy the example variables file:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars` with your actual values:**
   - Update VPC ID and subnet IDs
   - Add your secret values (NEVER commit this file)

3. **Add terraform.tfvars to .gitignore:**
   ```bash
   echo "terraform.tfvars" >> ../.gitignore
   ```

## Deployment Steps

### 1. Build and Push Docker Image

```bash
# Navigate to project root
cd ..

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <YOUR_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

# Build Docker image
docker build -t mcp-server .

# Tag image
docker tag mcp-server:latest <ECR_REPOSITORY_URL>:latest

# Push to ECR
docker push <ECR_REPOSITORY_URL>:latest
```

### 2. Initialize Terraform

```bash
cd terraform
terraform init
```

### 3. Plan Deployment

```bash
terraform plan
```

### 4. Apply Configuration

```bash
terraform apply
```

## Managing Secrets

Secrets are stored in AWS Secrets Manager. To update:

1. Update values in `terraform.tfvars`
2. Run `terraform apply`

Or manually in AWS Console:
- Navigate to Secrets Manager
- Find the secret named `mcp-server-secrets`
- Update values

## Accessing Logs

View logs in CloudWatch:
```bash
aws logs tail /ecs/mcp-server --follow
```

## Updating the Service

After pushing a new Docker image:

```bash
# Force new deployment
aws ecs update-service \
  --cluster mcp-server-cluster \
  --service mcp-server-service \
  --force-new-deployment
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## Security Notes

- Secrets are stored in AWS Secrets Manager (encrypted at rest)
- ECS tasks use IAM roles for AWS service access
- Security groups restrict network access
- CloudWatch logs are retained for 7 days by default

## Cost Optimization

- Default: 1 Fargate task (256 CPU, 512 MB)
- Estimated cost: ~$5-10/month
- Adjust `desired_count`, `task_cpu`, and `task_memory` as needed
