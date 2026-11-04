terraform {
  required_version = ">= 1.17.0, < 2.0.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_ecr_repository" "careops" {
  name                 = "careops-platform"
  image_tag_mutability = "IMMUTABLE"

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Project     = "careops-platform"
    Environment = "learning"
    ManagedBy   = "terraform"
  }
}

output "repository_url" {
  description = "ECR repository address for the CareOps Docker image"
  value       = aws_ecr_repository.careops.repository_url
}