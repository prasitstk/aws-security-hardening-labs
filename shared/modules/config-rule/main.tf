# -----------------------------------------------------------------------------
# AWS Config Rule Module
# Creates: Config rule (managed or custom Lambda) + optional SSM remediation
# -----------------------------------------------------------------------------

resource "aws_config_config_rule" "this" {
  name             = var.rule_name
  input_parameters = var.input_parameters

  source {
    owner             = var.source_owner
    source_identifier = var.source_identifier

    dynamic "source_detail" {
      for_each = var.source_details
      content {
        event_source = source_detail.value.event_source
        message_type = source_detail.value.message_type
      }
    }
  }

  dynamic "scope" {
    for_each = length(var.scope_resource_types) > 0 ? [1] : []

    content {
      compliance_resource_types = var.scope_resource_types
    }
  }

  maximum_execution_frequency = length(var.source_details) > 0 ? null : var.evaluation_frequency

  tags = var.tags
}

# --- SSM Remediation (conditional) ---

resource "aws_config_remediation_configuration" "this" {
  count = var.enable_remediation ? 1 : 0

  config_rule_name = aws_config_config_rule.this.name
  target_type      = "SSM_DOCUMENT"
  target_id        = var.remediation_document_name
  automatic        = var.automatic_remediation

  maximum_automatic_attempts = var.automatic_remediation ? var.max_remediation_attempts : null
  retry_attempt_seconds      = var.automatic_remediation ? var.remediation_retry_seconds : null

  dynamic "parameter" {
    for_each = var.remediation_parameters

    content {
      name           = parameter.key
      resource_value = parameter.value == "RESOURCE_ID" ? "RESOURCE_ID" : null
      static_value   = parameter.value != "RESOURCE_ID" ? parameter.value : null
    }
  }
}
