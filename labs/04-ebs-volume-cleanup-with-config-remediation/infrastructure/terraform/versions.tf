terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "aws-security-hardening-labs"
      Lab       = "04-ebs-volume-cleanup-with-config-remediation"
      ManagedBy = "terraform"
    }
  }
}
