terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-devops-demo"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "DevOps-Team"
      CostCenter  = "Engineering"
    }
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}
