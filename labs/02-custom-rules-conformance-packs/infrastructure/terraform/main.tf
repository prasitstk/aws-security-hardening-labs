# -----------------------------------------------------------------------------
# Lab 02: Custom Rules and Conformance Packs
# Deploys: Config recorder, custom Lambda rule (instance count check),
#          Guard custom policy (SG name check), managed rule (restricted-ssh),
#          all bundled in a conformance pack, optional test resources.
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
data "aws_availability_zones" "available" {
  state = "available"
}

# =============================================================================
# Config Recorder (shared module)
# =============================================================================

module "config_recorder" {
  source = "../../../../shared/modules/config-recorder"

  bucket_name    = var.config_bucket_name
  environment    = var.environment
  resource_types = ["AWS::EC2::Instance", "AWS::EC2::SecurityGroup"]
  tags           = local.common_tags
}

# =============================================================================
# Lambda — Custom Config Rule: EC2 Instance Count Check
# =============================================================================

resource "aws_iam_role" "lambda_config_rule" {
  name = "${var.project_name}-lambda-config-rule"

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

  tags = local.common_tags
}

resource "aws_iam_role_policy" "lambda_config_rule" {
  name = "${var.project_name}-lambda-config-rule"
  role = aws_iam_role.lambda_config_rule.id

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
        Sid    = "EC2DescribeAndTerminate"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:TerminateInstances",
        ]
        Resource = "*"
      },
      {
        Sid    = "ConfigPutEvaluations"
        Effect = "Allow"
        Action = [
          "config:PutEvaluations",
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-instance-count-check"
  retention_in_days = 7

  tags = local.common_tags
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../src/instance_count_check"
  output_path = "${path.module}/../../src/instance_count_check.zip"
}

resource "aws_lambda_function" "instance_count_check" {
  function_name    = "${var.project_name}-instance-count-check"
  description      = "Custom Config rule: checks EC2 instance count, auto-terminates excess"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  role             = aws_iam_role.lambda_config_rule.arn
  timeout          = 30
  memory_size      = 128

  depends_on = [
    aws_iam_role_policy.lambda_config_rule,
    aws_cloudwatch_log_group.lambda,
  ]

  tags = local.common_tags
}

resource "aws_lambda_permission" "config_invoke" {
  statement_id   = "AllowConfigInvoke"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.instance_count_check.function_name
  principal      = "config.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

# =============================================================================
# Conformance Pack — Deploys All 3 Config Rules
# =============================================================================

resource "aws_config_conformance_pack" "ec2_compliance" {
  name = "${var.project_name}-ec2-compliance"

  input_parameter {
    parameter_name  = "InstanceCountCheckLambdaArn"
    parameter_value = aws_lambda_function.instance_count_check.arn
  }

  template_body = <<-YAML
    Parameters:
      InstanceCountCheckLambdaArn:
        Type: String
    Resources:
      InstanceCountCheckRule:
        Type: AWS::Config::ConfigRule
        Properties:
          ConfigRuleName: instance-count-check
          Description: "Checks EC2 instance count — first-launched is compliant, others are terminated"
          Scope:
            ComplianceResourceTypes:
              - AWS::EC2::Instance
          Source:
            Owner: CUSTOM_LAMBDA
            SourceIdentifier:
              Ref: InstanceCountCheckLambdaArn
            SourceDetails:
              - EventSource: aws.config
                MessageType: ConfigurationItemChangeNotification
              - EventSource: aws.config
                MessageType: OversizedConfigurationItemChangeNotification
      SgNameCheckRule:
        Type: AWS::Config::ConfigRule
        Properties:
          ConfigRuleName: sg-name-check
          Description: "Guard policy — security groups must be named '${var.required_sg_name}'"
          Scope:
            ComplianceResourceTypes:
              - AWS::EC2::SecurityGroup
          Source:
            Owner: CUSTOM_POLICY
            CustomPolicyDetails:
              EnableDebugLogDelivery: true
              PolicyRuntime: guard-2.x.x
              PolicyText: |
                rule check_sg_name {
                  resourceType == "AWS::EC2::SecurityGroup"
                  configuration.groupName == "${var.required_sg_name}"
                }
            SourceDetails:
              - EventSource: aws.config
                MessageType: ConfigurationItemChangeNotification
              - EventSource: aws.config
                MessageType: OversizedConfigurationItemChangeNotification
      RestrictedSshRule:
        Type: AWS::Config::ConfigRule
        Properties:
          ConfigRuleName: restricted-ssh
          Description: "AWS managed rule — security groups should not allow unrestricted SSH"
          Scope:
            ComplianceResourceTypes:
              - AWS::EC2::SecurityGroup
          Source:
            Owner: AWS
            SourceIdentifier: INCOMING_SSH_DISABLED
  YAML

  depends_on = [
    module.config_recorder,
    aws_lambda_permission.config_invoke,
  ]
}

# =============================================================================
# Test Resources (optional — gated by var.create_test_resources)
# =============================================================================

resource "aws_vpc" "test" {
  count = var.create_test_resources ? 1 : 0

  cidr_block           = "10.98.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = false

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-test-vpc"
  })
}

resource "aws_subnet" "test" {
  count = var.create_test_resources ? 1 : 0

  vpc_id            = aws_vpc.test[0].id
  cidr_block        = "10.98.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-test-subnet"
  })
}

# Noncompliant: NOT named 'my-security-group' (triggers sg-name-check),
# allows SSH from 0.0.0.0/0 (triggers restricted-ssh)
resource "aws_security_group" "test_noncompliant" {
  count = var.create_test_resources ? 1 : 0

  name        = "${var.project_name}-test-open-ssh"
  description = "Noncompliant SG: wrong name + allows SSH from anywhere"
  vpc_id      = aws_vpc.test[0].id

  ingress {
    description = "SSH from anywhere (intentionally noncompliant)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-test-open-ssh"
  })
}

data "aws_ami" "amazon_linux_2023" {
  count = var.create_test_resources ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Compliant: first-launched instance passes the instance-count-check rule
resource "aws_instance" "test_ec2_compliant" {
  count = var.create_test_resources ? 1 : 0

  ami                    = data.aws_ami.amazon_linux_2023[0].id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.test[0].id
  vpc_security_group_ids = [aws_security_group.test_noncompliant[0].id]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-test-ec2-compliant"
  })

  depends_on = [module.config_recorder]
}

# Noncompliant: second instance triggers instance-count-check → auto-terminated
resource "aws_instance" "test_ec2_noncompliant" {
  count = var.create_test_resources ? 1 : 0

  ami                    = data.aws_ami.amazon_linux_2023[0].id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.test[0].id
  vpc_security_group_ids = [aws_security_group.test_noncompliant[0].id]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-test-ec2-noncompliant"
  })

  depends_on = [aws_instance.test_ec2_compliant]
}
