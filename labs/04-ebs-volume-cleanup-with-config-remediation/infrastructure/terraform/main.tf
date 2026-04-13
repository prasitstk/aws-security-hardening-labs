# -----------------------------------------------------------------------------
# Lab 04: EBS Volume Cleanup with Config Remediation
# Deploys: Config recorder, ec2-volume-inuse-check rule, SSM Automation
#          remediation (snapshot + delete), SNS + EventBridge notifications,
#          optional test EBS volume.
# -----------------------------------------------------------------------------

locals {
  common_tags = merge({
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }, var.tags)
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# --- Section 1: Config Recorder (shared module) ---

module "config_recorder" {
  source = "../../../../shared/modules/config-recorder"

  bucket_name    = var.config_bucket_name
  environment    = var.environment
  resource_types = ["AWS::EC2::Volume"]
  tags           = local.common_tags
}

# --- Section 2: Config Rule — ec2-volume-inuse-check ---

module "rule_ec2_volume_inuse" {
  source = "../../../../shared/modules/config-rule"

  rule_name            = "ec2-volume-inuse-check"
  source_identifier    = "EC2_VOLUME_INUSE_CHECK"
  scope_resource_types = ["AWS::EC2::Volume"]
  tags                 = local.common_tags

  enable_remediation        = true
  remediation_document_name = "AWSConfigRemediation-DeleteUnusedEBSVolume"
  automatic_remediation     = true

  remediation_parameters = {
    VolumeId             = "RESOURCE_ID"
    AutomationAssumeRole = aws_iam_role.ssm_automation.arn
    CreateSnapshot       = tostring(var.create_snapshot_before_delete)
  }

  depends_on = [module.config_recorder]
}

# --- Section 3: SSM Automation IAM Role ---

resource "aws_iam_role" "ssm_automation" {
  name = "${var.project_name}-ssm-automation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ssm.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "ssm_automation" {
  name = "${var.project_name}-ssm-automation-policy"
  role = aws_iam_role.ssm_automation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2VolumeOperations"
        Effect = "Allow"
        Action = [
          "ec2:DeleteVolume",
          "ec2:CreateSnapshot",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots"
        ]
        Resource = "*"
      },
      {
        Sid    = "SSMAutomationOperations"
        Effect = "Allow"
        Action = [
          "ssm:StartAutomationExecution",
          "ssm:GetAutomationExecution"
        ]
        Resource = "*"
      }
    ]
  })
}

# --- Section 4: SNS + EventBridge Notifications ---

resource "aws_sns_topic" "config_notifications" {
  name = "${var.project_name}-notifications"
  tags = local.common_tags
}

resource "aws_sns_topic_policy" "config_notifications" {
  arn = aws_sns_topic.config_notifications.arn

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
        Resource = aws_sns_topic.config_notifications.arn
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "email" {
  count = var.notification_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.config_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# EventBridge rule: Config compliance change events
resource "aws_cloudwatch_event_rule" "config_compliance_change" {
  name        = "${var.project_name}-compliance-change"
  description = "Capture Config compliance changes for ec2-volume-inuse-check"

  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      configRuleName = ["ec2-volume-inuse-check"]
    }
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "sns_compliance" {
  rule      = aws_cloudwatch_event_rule.config_compliance_change.name
  target_id = "sns-compliance"
  arn       = aws_sns_topic.config_notifications.arn
}

# EventBridge rule: SSM Automation status changes
resource "aws_cloudwatch_event_rule" "ssm_automation_status" {
  name        = "${var.project_name}-ssm-automation-status"
  description = "Capture SSM Automation execution status changes for EBS volume remediation"

  event_pattern = jsonencode({
    source      = ["aws.ssm"]
    detail-type = ["EC2 Automation Execution Status-change Notification"]
    detail = {
      Definition = ["AWSConfigRemediation-DeleteUnusedEBSVolume"]
    }
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "sns_remediation" {
  rule      = aws_cloudwatch_event_rule.ssm_automation_status.name
  target_id = "sns-remediation"
  arn       = aws_sns_topic.config_notifications.arn
}

# --- Section 5: Test Resources ---

resource "aws_ebs_volume" "test_unattached" {
  count = var.create_test_resources ? 1 : 0

  availability_zone = "${data.aws_region.current.id}a"
  size              = 1
  type              = "gp3"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-test-unattached"
  })
}
