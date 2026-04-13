variable "bucket_name" {
  description = "Name of the S3 bucket for Config delivery. Must be globally unique."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod). Used for tagging and naming."
  type        = string
  default     = "dev"
}

variable "recording_frequency" {
  description = "Recording frequency for the Config recorder. CONTINUOUS records all changes in real time. DAILY records once per 24-hour period."
  type        = string
  default     = "CONTINUOUS"

  validation {
    condition     = contains(["CONTINUOUS", "DAILY"], var.recording_frequency)
    error_message = "recording_frequency must be either CONTINUOUS or DAILY."
  }
}

variable "resource_types" {
  description = "List of AWS resource types to record. Empty list means record all supported resource types."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}
