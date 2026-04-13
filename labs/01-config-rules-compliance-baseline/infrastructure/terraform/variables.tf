variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for tagging and resource naming."
  type        = string
  default     = "config-rules-compliance-baseline"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "config_bucket_name" {
  description = "S3 bucket name for AWS Config delivery. Must be globally unique."
  type        = string
}

variable "create_test_resources" {
  description = "Whether to create test resources that trigger noncompliant evaluations."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}
