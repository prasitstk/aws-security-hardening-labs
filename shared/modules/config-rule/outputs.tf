output "rule_arn" {
  description = "ARN of the Config rule"
  value       = aws_config_config_rule.this.arn
}

output "rule_id" {
  description = "ID of the Config rule"
  value       = aws_config_config_rule.this.rule_id
}

output "remediation_configuration_arn" {
  description = "ARN of the remediation configuration (null if remediation is disabled)"
  value       = var.enable_remediation ? aws_config_remediation_configuration.this[0].arn : null
}
