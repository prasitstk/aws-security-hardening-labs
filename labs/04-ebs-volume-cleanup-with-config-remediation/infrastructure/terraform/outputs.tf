output "config_recorder_id" {
  description = "ID of the AWS Config recorder"
  value       = module.config_recorder.recorder_id
}

output "delivery_bucket_name" {
  description = "Name of the S3 bucket used for Config delivery"
  value       = module.config_recorder.bucket_name
}

output "delivery_bucket_arn" {
  description = "ARN of the S3 bucket used for Config delivery"
  value       = module.config_recorder.bucket_arn
}

output "config_rule_arn" {
  description = "ARN of the ec2-volume-inuse-check Config rule"
  value       = module.rule_ec2_volume_inuse.rule_arn
}

output "ssm_automation_role_arn" {
  description = "ARN of the IAM role used by SSM Automation for remediation"
  value       = aws_iam_role.ssm_automation.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for Config and remediation notifications"
  value       = aws_sns_topic.config_notifications.arn
}

output "test_volume_id" {
  description = "ID of the noncompliant test EBS volume (null if test resources disabled)"
  value       = var.create_test_resources ? aws_ebs_volume.test_unattached[0].id : null
}
