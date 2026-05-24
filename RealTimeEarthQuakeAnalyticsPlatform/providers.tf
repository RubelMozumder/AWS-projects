# =============================================================
# Providers & Terraform Version Constraints
# =============================================================
# Terraform >= 1.6 is required for full Terraform Stacks support
# AWS provider ~> 5.0 includes aws_scheduler_schedule resource

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # default_tags applies these tags to every resource in this root module.
  # Individual modules may add their own tags on top of these.
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
