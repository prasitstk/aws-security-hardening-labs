variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for tagging and resource naming."
  type        = string
  default     = "ssm-automation-ec2-remediation"
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

variable "vpc_cidr" {
  description = "CIDR block for the lab VPC."
  type        = string
  default     = "10.100.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.100.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet."
  type        = string
  default     = "10.100.2.0/24"
}

variable "notification_email" {
  description = "Email address for compliance SNS notifications. Leave empty to skip."
  type        = string
  default     = ""
}

variable "create_test_resources" {
  description = "Whether to create a test EC2 instance in the public subnet to trigger noncompliant evaluation."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}
