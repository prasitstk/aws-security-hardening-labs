variable "rule_name" {
  description = "Name of the Config rule."
  type        = string
}

variable "source_identifier" {
  description = "For managed rules: the rule identifier (e.g., S3_BUCKET_VERSIONING_ENABLED). For custom rules: the Lambda function ARN."
  type        = string
}

variable "source_owner" {
  description = "Owner of the Config rule source. AWS for managed rules, CUSTOM_LAMBDA for custom Lambda rules."
  type        = string
  default     = "AWS"

  validation {
    condition     = contains(["AWS", "CUSTOM_LAMBDA"], var.source_owner)
    error_message = "source_owner must be either AWS or CUSTOM_LAMBDA."
  }
}

variable "input_parameters" {
  description = "JSON string of input parameters for the Config rule."
  type        = string
  default     = null
}

variable "scope_resource_types" {
  description = "List of AWS resource types the rule evaluates (e.g., [\"AWS::S3::Bucket\"])."
  type        = list(string)
  default     = []
}

variable "evaluation_frequency" {
  description = "Evaluation frequency for periodic rules. Ignored for change-triggered rules."
  type        = string
  default     = null

  validation {
    condition     = var.evaluation_frequency == null ? true : contains(["One_Hour", "Three_Hours", "Six_Hours", "Twelve_Hours", "TwentyFour_Hours"], var.evaluation_frequency)
    error_message = "evaluation_frequency must be one of: One_Hour, Three_Hours, Six_Hours, Twelve_Hours, TwentyFour_Hours."
  }
}

variable "enable_remediation" {
  description = "Whether to create an automatic remediation configuration for this rule."
  type        = bool
  default     = false
}

variable "remediation_document_name" {
  description = "SSM document name for remediation (e.g., AWS-EnableS3BucketEncryption). Required if enable_remediation is true."
  type        = string
  default     = null
}

variable "automatic_remediation" {
  description = "Whether remediation runs automatically or requires manual approval."
  type        = bool
  default     = false
}

variable "max_remediation_attempts" {
  description = "Maximum number of automatic remediation attempts."
  type        = number
  default     = 3
}

variable "remediation_retry_seconds" {
  description = "Seconds to wait between remediation retry attempts."
  type        = number
  default     = 60
}

variable "remediation_parameters" {
  description = "Map of parameter names to values for the SSM remediation document."
  type        = map(string)
  default     = {}
}

variable "source_details" {
  description = "List of source detail blocks for custom Lambda rules (event triggers). Leave empty for managed rules."
  type = list(object({
    event_source = string
    message_type = string
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to the Config rule."
  type        = map(string)
  default     = {}
}
