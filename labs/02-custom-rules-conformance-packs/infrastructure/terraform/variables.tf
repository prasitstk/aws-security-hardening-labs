variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for tagging and resource naming."
  type        = string
  default     = "custom-rules-conformance-packs"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "config_bucket_name" {
  description = "Globally unique name for the Config delivery S3 bucket."
  type        = string
}

variable "required_sg_name" {
  description = "Required security group name for the Guard custom policy rule."
  type        = string
  default     = "my-security-group"
}

variable "create_test_resources" {
  description = "Whether to create intentionally noncompliant test resources."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}
