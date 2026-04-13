variable "project_name" {
  description = "Project name used for resource naming and metric namespace."
  type        = string
}

variable "config_rule_names" {
  description = "List of AWS Config rule names to monitor for compliance metrics."
  type        = list(string)
}

variable "notification_email" {
  description = "Email address for SNS notifications. Leave empty to skip email subscription."
  type        = string
  default     = ""
}

variable "evaluation_interval_minutes" {
  description = "How often (in minutes) the Lambda polls Config compliance status."
  type        = number
  default     = 5
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
