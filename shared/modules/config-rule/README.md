# config-rule

Reusable Terraform module that creates an AWS Config rule with optional SSM automatic remediation. Supports both AWS managed rules and custom Lambda rules.

## Usage — Managed Rule

```hcl
module "s3_versioning_rule" {
  source = "../../shared/modules/config-rule"

  rule_name          = "s3-bucket-versioning-enabled"
  source_identifier  = "S3_BUCKET_VERSIONING_ENABLED"
  source_owner       = "AWS"
  scope_resource_types = ["AWS::S3::Bucket"]

  tags = {
    Project = "aws-security-hardening-labs"
  }
}
```

## Usage — Managed Rule with Remediation

```hcl
module "s3_encryption_rule" {
  source = "../../shared/modules/config-rule"

  rule_name          = "s3-bucket-encryption-enabled"
  source_identifier  = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  source_owner       = "AWS"
  scope_resource_types = ["AWS::S3::Bucket"]

  enable_remediation        = true
  remediation_document_name = "AWS-EnableS3BucketEncryption"
  automatic_remediation     = true
  max_remediation_attempts  = 3
  remediation_retry_seconds = 60

  remediation_parameters = {
    BucketName       = "RESOURCE_ID"
    SSEAlgorithm     = "AES256"
  }

  tags = {
    Project = "aws-security-hardening-labs"
  }
}
```

## Usage — Custom Lambda Rule

```hcl
module "custom_tag_check" {
  source = "../../shared/modules/config-rule"

  rule_name         = "required-tags-check"
  source_identifier = aws_lambda_function.config_rule.arn
  source_owner      = "CUSTOM_LAMBDA"
  scope_resource_types = ["AWS::EC2::Instance", "AWS::S3::Bucket"]

  source_details = [
    {
      event_source = "aws.config"
      message_type = "ConfigurationItemChangeNotification"
    }
  ]

  input_parameters = jsonencode({
    requiredTags = "Environment,Owner,CostCenter"
  })

  tags = {
    Project = "aws-security-hardening-labs"
  }
}
```

## Inputs

| Name | Type | Default | Required | Description |
|---|---|---|---|---|
| `rule_name` | `string` | — | yes | Config rule name |
| `source_identifier` | `string` | — | yes | Managed rule ID or Lambda ARN |
| `source_owner` | `string` | `"AWS"` | no | `AWS` or `CUSTOM_LAMBDA` |
| `input_parameters` | `string` | `null` | no | JSON input parameters |
| `scope_resource_types` | `list(string)` | `[]` | no | Resource types to evaluate |
| `evaluation_frequency` | `string` | `null` | no | Frequency for periodic rules |
| `source_details` | `list(object)` | `[]` | no | Source detail blocks for custom Lambda rules (event triggers) |
| `enable_remediation` | `bool` | `false` | no | Enable SSM remediation |
| `remediation_document_name` | `string` | `null` | no | SSM document for remediation |
| `automatic_remediation` | `bool` | `false` | no | Auto-remediate or manual |
| `max_remediation_attempts` | `number` | `3` | no | Max auto-remediation attempts |
| `remediation_retry_seconds` | `number` | `60` | no | Seconds between retries |
| `remediation_parameters` | `map(string)` | `{}` | no | SSM document parameters |
| `tags` | `map(string)` | `{}` | no | Tags for the Config rule |

## Outputs

| Name | Description |
|---|---|
| `rule_arn` | ARN of the Config rule |
| `rule_id` | ID of the Config rule |
| `remediation_configuration_arn` | ARN of the remediation config (null if disabled) |
