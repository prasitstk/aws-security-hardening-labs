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

output "vpc_id" {
  description = "ID of the lab VPC"
  value       = aws_vpc.this.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = aws_subnet.private.id
}

output "config_rule_arn" {
  description = "ARN of the ec2-in-public-subnet Config rule"
  value       = module.rule_ec2_public_subnet.rule_arn
}

output "lambda_function_arn" {
  description = "ARN of the custom Config rule Lambda function"
  value       = aws_lambda_function.ec2_public_subnet_check.arn
}

output "ssm_automation_role_arn" {
  description = "ARN of the SSM Automation role for remediation"
  value       = aws_iam_role.ssm_automation.arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch compliance dashboard"
  value       = module.compliance_dashboard.dashboard_name
}

output "sns_topic_arn" {
  description = "ARN of the compliance notification SNS topic"
  value       = module.compliance_dashboard.sns_topic_arn
}

output "test_instance_id" {
  description = "ID of the noncompliant test EC2 instance (null if test resources disabled)"
  value       = var.create_test_resources ? aws_instance.test_public_ec2[0].id : null
}
