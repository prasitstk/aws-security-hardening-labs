# config-compliance-dashboard

Reusable Terraform module that creates a compliance monitoring stack for AWS Config rules: a Lambda function that publishes custom CloudWatch metrics, a dashboard for compliance visualization, alarms, EventBridge rules for compliance change events, and SNS notifications.

## How It Works

1. A scheduled EventBridge rule triggers a Lambda function every N minutes (default: 5)
2. The Lambda calls `config:DescribeComplianceByConfigRule` to get current compliance status
3. It publishes custom metrics to a `ConfigCompliance/<project_name>` CloudWatch namespace
4. A CloudWatch dashboard visualizes compliance trends and per-rule non-compliant resource counts
5. A CloudWatch alarm fires when any rule reports non-compliant resources
6. EventBridge captures Config compliance change events and forwards them to SNS

## Usage

```hcl
module "compliance_dashboard" {
  source = "../../../../shared/modules/config-compliance-dashboard"

  project_name     = "my-lab"
  config_rule_names = ["restricted-ssh", "required-tags"]
  notification_email = "ops@example.com"

  tags = {
    Project = "aws-security-hardening-labs"
  }
}
```

## Inputs

| Name | Type | Default | Required | Description |
|---|---|---|---|---|
| `project_name` | `string` | -- | yes | Project name for resource naming and metric namespace |
| `config_rule_names` | `list(string)` | -- | yes | Config rule names to monitor |
| `notification_email` | `string` | `""` | no | Email for SNS notifications (leave empty to skip) |
| `evaluation_interval_minutes` | `number` | `5` | no | How often Lambda polls compliance status |
| `tags` | `map(string)` | `{}` | no | Tags for all resources |

## Outputs

| Name | Description |
|---|---|
| `dashboard_name` | Name of the CloudWatch compliance dashboard |
| `dashboard_arn` | ARN of the CloudWatch compliance dashboard |
| `sns_topic_arn` | ARN of the SNS notification topic |
| `lambda_function_arn` | ARN of the compliance metrics Lambda |
| `noncompliant_alarm_arn` | ARN of the non-compliant alarm |
