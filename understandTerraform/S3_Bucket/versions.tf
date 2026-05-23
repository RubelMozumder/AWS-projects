terraform {
  required_version = ">= 1.7" # minimum Terraform version

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # 6.x only, never 7.x
    }
  }
}

provider "aws" {
  region = "eu-west-1" # change to your preferred region
}