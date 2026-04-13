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

output "config_rule_arns" {
  description = "ARNs of all deployed Config rules"
  value = {
    restricted_ssh = module.rule_restricted_ssh.rule_arn
    required_tags  = module.rule_required_tags.rule_arn
  }
}

output "test_security_group_id" {
  description = "ID of the noncompliant test security group (null if test resources disabled)"
  value       = var.create_test_resources ? aws_security_group.test_open_ssh[0].id : null
}

output "test_instance_id" {
  description = "ID of the noncompliant test EC2 instance (null if test resources disabled)"
  value       = var.create_test_resources ? aws_instance.test_missing_tags[0].id : null
}
