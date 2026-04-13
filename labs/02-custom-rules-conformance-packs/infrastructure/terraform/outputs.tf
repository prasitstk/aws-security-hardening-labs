output "config_recorder_id" {
  description = "ID of the Config recorder."
  value       = module.config_recorder.recorder_id
}

output "delivery_bucket_name" {
  description = "Name of the Config delivery S3 bucket."
  value       = module.config_recorder.bucket_name
}

output "delivery_bucket_arn" {
  description = "ARN of the Config delivery S3 bucket."
  value       = module.config_recorder.bucket_arn
}

output "lambda_function_arn" {
  description = "ARN of the instance count check Lambda function."
  value       = aws_lambda_function.instance_count_check.arn
}

output "conformance_pack_name" {
  description = "Name of the deployed conformance pack."
  value       = aws_config_conformance_pack.ec2_compliance.name
}

output "conformance_pack_arn" {
  description = "ARN of the deployed conformance pack."
  value       = aws_config_conformance_pack.ec2_compliance.arn
}

output "test_instance_ids" {
  description = "Instance IDs of the test EC2 instances (null if test resources disabled)."
  value = var.create_test_resources ? {
    compliant    = aws_instance.test_ec2_compliant[0].id
    noncompliant = aws_instance.test_ec2_noncompliant[0].id
  } : null
}

output "test_security_group_id" {
  description = "ID of the noncompliant test security group (null if test resources disabled)."
  value       = var.create_test_resources ? aws_security_group.test_noncompliant[0].id : null
}
