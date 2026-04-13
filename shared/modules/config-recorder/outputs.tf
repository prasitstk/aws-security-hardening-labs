output "recorder_id" {
  description = "ID of the AWS Config recorder"
  value       = aws_config_configuration_recorder.this.id
}

output "iam_role_arn" {
  description = "ARN of the IAM role used by the Config recorder"
  value       = aws_iam_role.config.arn
}

output "bucket_arn" {
  description = "ARN of the S3 bucket used for Config delivery"
  value       = aws_s3_bucket.config_delivery.arn
}

output "bucket_name" {
  description = "Name of the S3 bucket used for Config delivery"
  value       = aws_s3_bucket.config_delivery.id
}

output "delivery_channel_id" {
  description = "ID of the Config delivery channel"
  value       = aws_config_delivery_channel.this.id
}
