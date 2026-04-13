output "dashboard_name" {
  description = "Name of the CloudWatch compliance dashboard"
  value       = aws_cloudwatch_dashboard.compliance.dashboard_name
}

output "dashboard_arn" {
  description = "ARN of the CloudWatch compliance dashboard"
  value       = aws_cloudwatch_dashboard.compliance.dashboard_arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS notification topic"
  value       = aws_sns_topic.compliance.arn
}

output "lambda_function_arn" {
  description = "ARN of the compliance metrics Lambda function"
  value       = aws_lambda_function.compliance_metrics.arn
}

output "noncompliant_alarm_arn" {
  description = "ARN of the non-compliant resource count alarm"
  value       = aws_cloudwatch_metric_alarm.noncompliant.arn
}
