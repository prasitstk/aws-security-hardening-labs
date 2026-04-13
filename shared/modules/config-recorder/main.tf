# -----------------------------------------------------------------------------
# AWS Config Recorder Module
# Creates: IAM role, S3 bucket, Config recorder, delivery channel
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# --- IAM Role for AWS Config ---

resource "aws_iam_role" "config" {
  name               = "aws-config-role-${var.environment}"
  assume_role_policy = file("${path.module}/../../policies/config-service-role.json")
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# --- S3 Bucket for Config Delivery ---

resource "aws_s3_bucket" "config_delivery" {
  bucket        = var.bucket_name
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_versioning" "config_delivery" {
  bucket = aws_s3_bucket.config_delivery.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config_delivery" {
  bucket = aws_s3_bucket.config_delivery.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "config_delivery" {
  bucket = aws_s3_bucket.config_delivery.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "config_delivery" {
  bucket = aws_s3_bucket.config_delivery.id

  policy = templatefile("${path.module}/../../policies/config-s3-delivery.json", {
    bucket_name = var.bucket_name
    account_id  = data.aws_caller_identity.current.account_id
  })

  depends_on = [aws_s3_bucket_public_access_block.config_delivery]
}

# --- AWS Config Recorder ---

resource "aws_config_configuration_recorder" "this" {
  name     = "config-recorder-${var.environment}"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = length(var.resource_types) == 0
    include_global_resource_types = length(var.resource_types) == 0
    resource_types                = var.resource_types
  }

  # recording_mode requires AWS provider >= 5.25; CONTINUOUS is the default.
  # The recording_frequency variable is kept for future use.
}

# --- Delivery Channel ---

resource "aws_config_delivery_channel" "this" {
  name           = "config-channel-${var.environment}"
  s3_bucket_name = aws_s3_bucket.config_delivery.id

  depends_on = [aws_config_configuration_recorder.this]
}

# --- Enable Recorder ---

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.this]
}
