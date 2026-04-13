# -----------------------------------------------------------------------------
# Config Compliance Dashboard Module
# Creates: Lambda (compliance metrics), CloudWatch dashboard, alarm,
#          EventBridge (scheduled + compliance events), SNS notifications.
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  metrics_namespace = "ConfigCompliance/${var.project_name}"
}

# =============================================================================
# Lambda — Compliance Metrics Publisher
# =============================================================================

resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-compliance-metrics"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "lambda" {
  name = "${var.project_name}-compliance-metrics"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Sid    = "ConfigRead"
        Effect = "Allow"
        Action = [
          "config:DescribeComplianceByConfigRule",
          "config:GetComplianceDetailsByConfigRule",
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-compliance-metrics"
  retention_in_days = 7

  tags = var.tags
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src/compliance_metrics"
  output_path = "${path.module}/src/compliance_metrics.zip"
}

resource "aws_lambda_function" "compliance_metrics" {
  function_name    = "${var.project_name}-compliance-metrics"
  description      = "Polls Config compliance status and publishes CloudWatch metrics"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler          = "index.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda.arn
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      METRICS_NAMESPACE = local.metrics_namespace
      RULE_NAMES        = join(",", var.config_rule_names)
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda,
    aws_cloudwatch_log_group.lambda,
  ]

  tags = var.tags
}

# =============================================================================
# EventBridge — Scheduled Lambda Trigger
# =============================================================================

resource "aws_cloudwatch_event_rule" "scheduled_metrics" {
  name                = "${var.project_name}-compliance-metrics-schedule"
  description         = "Trigger compliance metrics Lambda every ${var.evaluation_interval_minutes} minutes"
  schedule_expression = "rate(${var.evaluation_interval_minutes} minutes)"

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.scheduled_metrics.name
  target_id = "compliance-metrics-lambda"
  arn       = aws_lambda_function.compliance_metrics.arn
}

resource "aws_lambda_permission" "eventbridge_invoke" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.compliance_metrics.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scheduled_metrics.arn
}

# =============================================================================
# EventBridge — Config Compliance Change Events → SNS
# =============================================================================

resource "aws_cloudwatch_event_rule" "compliance_change" {
  name        = "${var.project_name}-compliance-change"
  description = "Capture Config compliance state changes"

  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      configRuleName = var.config_rule_names
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "sns_compliance" {
  rule      = aws_cloudwatch_event_rule.compliance_change.name
  target_id = "sns-compliance-change"
  arn       = aws_sns_topic.compliance.arn
}

# =============================================================================
# SNS — Notifications
# =============================================================================

resource "aws_sns_topic" "compliance" {
  name = "${var.project_name}-compliance-notifications"
  tags = var.tags
}

resource "aws_sns_topic_policy" "compliance" {
  arn = aws_sns_topic.compliance.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgePublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.compliance.arn
      },
      {
        Sid    = "AllowCloudWatchAlarmPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.compliance.arn
      },
    ]
  })
}

resource "aws_sns_topic_subscription" "email" {
  count = var.notification_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.compliance.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# =============================================================================
# CloudWatch Alarm — Non-Compliant Resources
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "noncompliant" {
  alarm_name          = "${var.project_name}-noncompliant-rules"
  alarm_description   = "Fires when any Config rule reports non-compliant resources"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "NonCompliantRuleCount"
  namespace           = local.metrics_namespace
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.compliance.arn]
  ok_actions    = [aws_sns_topic.compliance.arn]

  tags = var.tags
}

# =============================================================================
# CloudWatch Dashboard
# =============================================================================

resource "aws_cloudwatch_dashboard" "compliance" {
  dashboard_name = "${var.project_name}-compliance"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Rule Compliance Status Over Time"
          view   = "timeSeries"
          region = data.aws_region.current.id
          period = 300
          stat   = "Maximum"
          metrics = [
            [local.metrics_namespace, "CompliantRuleCount", { label = "Compliant", color = "#2ca02c" }],
            [local.metrics_namespace, "NonCompliantRuleCount", { label = "Non-Compliant", color = "#d62728" }],
            [local.metrics_namespace, "InsufficientDataRuleCount", { label = "Insufficient Data", color = "#ff7f0e" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Non-Compliant Resources per Rule"
          view   = "timeSeries"
          region = data.aws_region.current.id
          period = 300
          stat   = "Maximum"
          metrics = [
            for rule in var.config_rule_names : [
              local.metrics_namespace, "NonCompliantResourceCount",
              "RuleName", rule,
              { label = rule }
            ]
          ]
        }
      },
      {
        type   = "alarm"
        x      = 0
        y      = 6
        width  = 12
        height = 3
        properties = {
          title  = "Alarm Status"
          alarms = [aws_cloudwatch_metric_alarm.noncompliant.arn]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 3
        properties = {
          title  = "Metrics Lambda Errors"
          view   = "timeSeries"
          region = data.aws_region.current.id
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.compliance_metrics.function_name, { label = "Errors", color = "#d62728" }],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.compliance_metrics.function_name, { label = "Invocations", color = "#1f77b4" }],
          ]
        }
      },
    ]
  })
}
