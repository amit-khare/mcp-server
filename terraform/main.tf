terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# ECR Repository
resource "aws_ecr_repository" "app" {
  name                 = var.project_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = var.project_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name  = var.project_name
    image = "${aws_ecr_repository.app.repository_url}:latest"

    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]

    environment = [
      {
        name  = "APP_ENV"
        value = var.app_env
      }
    ]

    secrets = [
      {
        name      = "COGNITO_REGION"
        valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:COGNITO_REGION::"
      },
      {
        name      = "USER_POOL_ID"
        valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:USER_POOL_ID::"
      },
      {
        name      = "APP_CLIENT_ID"
        valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:APP_CLIENT_ID::"
      },
      {
        name      = "OAUTH_CLIENT_ID"
        valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:OAUTH_CLIENT_ID::"
      },
      {
        name      = "OAUTH_CLIENT_SECRET"
        valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:OAUTH_CLIENT_SECRET::"
      },
      {
        name      = "TOKEN_URL"
        valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:TOKEN_URL::"
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }

    essential = true
  }])

  tags = var.tags
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-ecs-tasks"
  })
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = var.assign_public_ip
  }

  tags = var.tags
}
