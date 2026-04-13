# config-recorder

Reusable Terraform module that provisions the AWS Config recorder stack: IAM service role, S3 delivery bucket, Config recorder, and delivery channel.

AWS Config recorder is a **singleton per region** — only one can exist at a time. This module extracts the recorder setup so that multiple labs can share it without duplication.

## Usage

```hcl
module "config_recorder" {
  source = "../../shared/modules/config-recorder"

  bucket_name         = "my-config-delivery-bucket"
  environment         = "dev"
  recording_frequency = "DAILY"

  tags = {
    Project = "aws-security-hardening-labs"
    Lab     = "01-config-rules-compliance-baseline"
  }
}
```

## Inputs

| Name | Type | Default | Required | Description |
|---|---|---|---|---|
| `bucket_name` | `string` | — | yes | S3 bucket name for Config delivery (must be globally unique) |
| `environment` | `string` | `"dev"` | no | Environment name for tagging |
| `recording_frequency` | `string` | `"CONTINUOUS"` | no | `CONTINUOUS` or `DAILY` |
| `resource_types` | `list(string)` | `[]` | no | Resource types to record (empty = all) |
| `tags` | `map(string)` | `{}` | no | Tags for all resources |

## Outputs

| Name | Description |
|---|---|
| `recorder_id` | ID of the AWS Config recorder |
| `iam_role_arn` | ARN of the Config service IAM role |
| `bucket_arn` | ARN of the S3 delivery bucket |
| `bucket_name` | Name of the S3 delivery bucket |
| `delivery_channel_id` | ID of the Config delivery channel |
