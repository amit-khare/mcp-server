# MCP Server with JWT Authentication

> A Model Context Protocol (MCP) server with JWT-based authentication using AWS Cognito

## Table of Contents
- [Overview](#overview)
- [Features](#features)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Running the Server](#running-the-server)
- [API Endpoints](#api-endpoints)
- [Authentication](#authentication)
- [Development](#development)
- [Testing](#testing)
- [Docker Deployment](#docker-deployment)
- [AWS ECS Deployment](#aws-ecs-deployment)
- [Security Considerations](#security-considerations)

## Overview

This project implements a secure MCP (Model Context Protocol) server that validates JWT bearer tokens from AWS Cognito before executing protected tools. The server exposes authenticated tools over HTTP and integrates with AWS Cognito for identity and access management.

## Features

- ✅ JWT-based authentication with AWS Cognito
- ✅ Custom `AuthProvider` implementation
- ✅ Protected MCP tools requiring authentication
- ✅ Environment-based configuration using Pydantic
- ✅ Docker support for containerization
- ✅ Terraform configuration for AWS ECS deployment
- ✅ CloudWatch logging integration
- ✅ AWS Secrets Manager for secure credential storage

## Project Structure

```
mcp-server/
├── server.py              # Main MCP server with FastMCP
├── auth.py                # AWS Cognito JWT verification utilities
├── config.py              # Pydantic settings configuration
├── requirements.txt       # Python dependencies
├── pyproject.toml         # Project metadata and uv configuration
├── Dockerfile            # Docker container configuration
├── .env                  # Environment variables (not committed)
├── .gitignore           # Git ignore rules
├── tests/               # Test directory
│   ├── __init__.py
│   └── test_config.py   # Configuration tests
└── terraform/           # AWS infrastructure as code
    ├── main.tf          # ECS cluster, service, task definition
    ├── variables.tf     # Terraform variables
    ├── secrets.tf       # AWS Secrets Manager configuration
    ├── iam.tf          # IAM roles and policies
    ├── outputs.tf      # Terraform outputs
    ├── .gitignore      # Terraform-specific ignores
    ├── terraform.tfvars.example  # Example configuration
    └── README.md       # Deployment instructions
```

## Prerequisites

- Python 3.13+
- [uv](https://github.com/astral-sh/uv) package manager
- AWS Account (for Cognito integration)
- AWS Cognito User Pool configured
- Docker (optional, for containerization)
- Terraform (optional, for AWS deployment)

## Installation

### 1. Clone the Repository

```bash
git clone <repository-url>
cd mcp-server
```

### 2. Create Virtual Environment

The project uses `uv` for dependency management:

```bash
# Create .venv and install dependencies
uv venv
source .venv/bin/activate  # On macOS/Linux
# or
.venv\Scripts\activate  # On Windows
```

### 3. Install Dependencies

```bash
uv pip install -r requirements.txt
```

Required packages:
- `fastmcp` - MCP server framework
- `python-jose[cryptography]` - JWT handling
- `httpx` - HTTP client for JWKS fetching
- `pydantic-settings` - Configuration management

## Configuration

### Environment Variables

Create a `.env` file in the project root:

```env
# Application Environment
APP_ENV=local

# AWS Cognito Configuration
COGNITO_REGION=us-east-1
USER_POOL_ID=us-east-1_XXXXXXXXX
APP_CLIENT_ID=your-cognito-app-client-id

# OAuth Configuration (if using OAuth flow)
OAUTH_CLIENT_ID=your-oauth-client-id
OAUTH_CLIENT_SECRET=your-oauth-client-secret
TOKEN_URL=https://auth.example.com/token
```

### Configuration Management

The project uses Pydantic for type-safe configuration management ([config.py](config.py)):

```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    app_env: str = "local"
    oauth_client_id: str
    oauth_client_secret: str
    cognito_region: str
    user_pool_id: str
    app_client_id: str
    token_url: str

    class Config:
        env_file = ".env"
        case_sensitive = False
```

**Note**: `case_sensitive = False` allows uppercase environment variables to map to lowercase field names.

## Running the Server

### Local Development

```bash
uv run server.py
```

The server will start on `http://0.0.0.0:8000/mcp`

### Using Docker

Build and run the container:

```bash
# Build image
docker build -t mcp-server .

# Run container
docker run --env-file .env -p 8000:8000 mcp-server
```

## API Endpoints

### Base URL
```
http://localhost:8000/mcp
```

### Available Tools

All tools require authentication via JWT bearer token.

#### 1. `add` - Add Two Numbers
```json
{
  "tool": "add",
  "arguments": {
    "a": 5,
    "b": 3
  }
}
```

**Response:**
```json
{
  "result": 8
}
```

#### 2. `get_user_info` - Get Authenticated User Info
```json
{
  "tool": "get_user_info",
  "arguments": {}
}
```

**Response:**
```json
{
  "result": {
    "user": "sub-value-from-jwt",
    "username": "user@example.com",
    "scope": "openid profile email"
  }
}
```

## Authentication

### Authentication Flow

1. **Client Request**: Client sends request with `Authorization: Bearer <JWT_TOKEN>` header
2. **Token Validation**: `CognitoTokenValidator.verify_token()` decodes and validates the JWT
3. **AccessToken Creation**: Creates `AccessToken` object with claims, scopes, and expiration
4. **Tool Execution**: Protected tools access user info via `get_access_token()` dependency

### JWT Verification

#### Local Testing (Current Implementation)

[server.py](server.py) currently disables signature verification:

```python
decoded = jwt.decode(
    token,
    options={"verify_signature": False}
)
```

⚠️ **This is for testing only!** Do not use in production.

#### Production Implementation

[auth.py](auth.py) provides full JWT verification with JWKS:

```python
@lru_cache
def get_jwks():
    return httpx.get(JWKS_URL).json()

def verify_token(token: str):
    jwks = get_jwks()
    header = jwt.get_unverified_header(token)
    
    key = next(
        k for k in jwks["keys"] if k["kid"] == header["kid"]
    )
    
    claims = jwt.decode(
        token,
        key,
        algorithms=["RS256"],
        audience=APP_CLIENT_ID,
        issuer=f"https://cognito-idp.{COGNITO_REGION}.amazonaws.com/{USER_POOL_ID}",
    )
    
    return claims
```

**For production**, update `CognitoTokenValidator` to use `auth.verify_token()` instead of the simplified version.

### Custom AuthProvider

The server implements a custom `AuthProvider`:

```python
class CognitoTokenValidator(AuthProvider):
    async def verify_token(self, token: str) -> Optional[AccessToken]:
        try:
            decoded = jwt.decode(token, options={"verify_signature": False})
            scope_str = decoded.get("scope", "") or ""
            scopes = [s for s in scope_str.split() if s]
            
            return AccessToken(
                token=token,
                client_id=decoded.get("client_id") or decoded.get("sub") or "unknown",
                scopes=scopes,
                expires_at=decoded.get("exp"),
                claims=decoded,
            )
        except Exception:
            return None
```

## Development

### Project Setup

1. **Configure Python Environment**:
   ```bash
   # Point VS Code to .venv
   # Command Palette (Cmd+Shift+P) → Python: Select Interpreter
   # Select: .venv/bin/python
   ```

2. **Install Development Tools**:
   ```bash
   uv pip install pytest black isort mypy
   ```

3. **Code Formatting**:
   ```bash
   black .
   isort .
   ```

### Adding New Tools

Add new protected tools in [server.py](server.py):

```python
@mcp.tool()
async def my_new_tool(param: str) -> dict:
    """Description of the tool."""
    from fastmcp.server.dependencies import get_access_token
    
    # Get authenticated user
    token = get_access_token()
    user_id = token.claims.get("sub")
    
    # Your tool logic here
    return {"result": f"Hello {user_id}"}
```

## Testing

### Running Tests

```bash
# Run all tests
uv run python -m pytest

# Run specific test file
uv run python tests/test_config.py
```

### Test Structure

Tests are located in the `tests/` directory:

```python
# tests/test_config.py
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from config import settings

print(settings.oauth_client_id)
```

## Docker Deployment

### Building the Image

```bash
docker build -t mcp-server:latest .
```

### Running Locally

```bash
docker run --env-file .env -p 8000:8000 mcp-server:latest
```

### Pushing to Registry

```bash
# AWS ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

docker tag mcp-server:latest <ECR_REPOSITORY_URL>:latest
docker push <ECR_REPOSITORY_URL>:latest
```

## AWS ECS Deployment

Complete Terraform configuration is available in the `terraform/` directory.

### Quick Start

1. **Configure Terraform Variables**:
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

2. **Initialize Terraform**:
   ```bash
   terraform init
   ```

3. **Deploy Infrastructure**:
   ```bash
   terraform plan
   terraform apply
   ```

### Infrastructure Components

- **ECS Cluster**: Fargate cluster for running containers
- **ECS Service**: Manages task instances with desired count
- **Task Definition**: Container configuration with 256 CPU / 512 MB memory
- **ECR Repository**: Docker image registry
- **Secrets Manager**: Encrypted storage for credentials
- **CloudWatch Logs**: Application logging
- **IAM Roles**: Execution and task roles with proper permissions
- **Security Groups**: Network access control

### Secrets Management

Secrets are stored in AWS Secrets Manager and injected as environment variables:

```json
{
  "COGNITO_REGION": "us-east-1",
  "USER_POOL_ID": "us-east-1_XXXXXXXXX",
  "APP_CLIENT_ID": "your-app-client-id",
  "OAUTH_CLIENT_ID": "your-oauth-client-id",
  "OAUTH_CLIENT_SECRET": "your-oauth-client-secret",
  "TOKEN_URL": "https://auth.example.com/token"
}
```

### Viewing Logs

```bash
aws logs tail /ecs/mcp-server --follow
```

### Updating the Service

After pushing a new Docker image:

```bash
aws ecs update-service \
  --cluster mcp-server-cluster \
  --service mcp-server-service \
  --force-new-deployment
```

## Security Considerations

### Production Checklist

- [ ] Enable JWT signature verification using JWKS
- [ ] Use AWS Secrets Manager for all credentials
- [ ] Enable HTTPS/TLS for all endpoints
- [ ] Implement rate limiting
- [ ] Enable CloudWatch monitoring and alarms
- [ ] Use VPC endpoints for AWS service access
- [ ] Implement least-privilege IAM policies
- [ ] Enable AWS WAF for API protection
- [ ] Rotate credentials regularly
- [ ] Enable CloudTrail for audit logging

### Current Security Notes

⚠️ **JWT signature verification is currently disabled** for local testing. Enable full verification before production deployment.

✅ Secrets are stored in AWS Secrets Manager (encrypted at rest)
✅ ECS tasks use IAM roles (no hardcoded credentials)
✅ Security groups restrict network access
✅ CloudWatch logs for audit trail

### Best Practices

1. **Never commit `.env` or `terraform.tfvars`** - Added to `.gitignore`
2. **Use AWS Secrets Manager** - Not environment variables in ECS
3. **Rotate credentials** - Implement regular rotation policies
4. **Monitor and alert** - Set up CloudWatch alarms
5. **Use private subnets** - ECS tasks should not be publicly accessible

## Troubleshooting

### Common Issues

**Import errors (`ModuleNotFoundError`)**:
```bash
# Ensure virtual environment is activated
source .venv/bin/activate

# Reinstall dependencies
uv pip install -r requirements.txt

# Point VS Code to correct interpreter
# Cmd+Shift+P → Python: Select Interpreter → .venv/bin/python
```

**Pydantic import errors**:
- Ensure `pydantic-settings` is installed
- Update imports: `from pydantic_settings import BaseSettings`

**Configuration errors**:
- Check `.env` file exists and has all required variables
- Verify `case_sensitive = False` in config.py

**Docker build failures**:
- Check Dockerfile syntax
- Ensure requirements.txt is up to date
- Verify base image is accessible

## License

[Specify your license]

## Contributing

[Add contributing guidelines]

## Support

For issues and questions:
- Open an issue on GitHub
- Check existing documentation
- Review CloudWatch logs for runtime errors
