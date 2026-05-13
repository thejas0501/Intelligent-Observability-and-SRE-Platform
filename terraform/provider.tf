terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "intelligent-observability-sre-platform-thejas"
    key    = "project1/terraform.tfstate"
    region = "ap-south-1"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "intelligent-observability-sre"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "thejas"
    }
  }
}