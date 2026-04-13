# -----------------------------------------------------------------------------
# Lab 03: SSM Automation EC2 Remediation
# Deploys: Config recorder, VPC (public + private subnets), custom Lambda
#          Config rule to detect EC2 in public subnets, SSM Automation
#          remediation (AWS-TerminateEC2Instance), optional test EC2 instance.
# -----------------------------------------------------------------------------

locals {
  common_tags = merge({
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }, var.tags)
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# --- Config Recorder (shared module) ---

module "config_recorder" {
  source = "../../../../shared/modules/config-recorder"

  bucket_name    = var.config_bucket_name
  environment    = var.environment
  resource_types = ["AWS::EC2::Instance"]
  tags           = local.common_tags
}

# =============================================================================
# VPC + Networking
# =============================================================================

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

# --- Public Subnet ---

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.public_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-subnet"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# --- Private Subnet ---

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-subnet"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-rt"
  })
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# --- Security Group (egress-only, no ingress — managed via SSM) ---

resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Egress-only SG for lab instances (no ingress, managed via SSM)"
  vpc_id      = aws_vpc.this.id

  egress {
    description = "Allow HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow HTTP outbound"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-web-sg"
  })
}

# =============================================================================
# Lambda — Custom Config Rule: EC2 Public Subnet Check
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
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Sid    = "EC2DescribeRouteTables"
        Effect = "Allow"
        Action = [
          "ec2:DescribeRouteTables",
        ]
        Resource = "*"
      },
      {
        Sid    = "ConfigPutEvaluations"
        Effect = "Allow"
        Action = [
          "config:PutEvaluations",
          "config:GetResourceConfigHistory",
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-ec2-public-subnet-check"
  retention_in_days = 7

  tags = local.common_tags
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../src/ec2_public_subnet_check"
  output_path = "${path.module}/../../src/ec2_public_subnet_check.zip"
}

resource "aws_lambda_function" "ec2_public_subnet_check" {
  function_name    = "${var.project_name}-ec2-public-subnet-check"
  description      = "Custom Config rule: detects EC2 instances in public subnets"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler          = "index.lambda_handler"
  runtime          = "python3.12"
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
  function_name  = aws_lambda_function.ec2_public_subnet_check.function_name
  principal      = "config.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

# =============================================================================
# Config Rule — EC2 Public Subnet Check (shared module)
# =============================================================================

module "rule_ec2_public_subnet" {
  source = "../../../../shared/modules/config-rule"

  rule_name            = "ec2-in-public-subnet"
  source_identifier    = aws_lambda_function.ec2_public_subnet_check.arn
  source_owner         = "CUSTOM_LAMBDA"
  scope_resource_types = ["AWS::EC2::Instance"]

  source_details = [
    {
      event_source = "aws.config"
      message_type = "ConfigurationItemChangeNotification"
    },
    {
      event_source = "aws.config"
      message_type = "OversizedConfigurationItemChangeNotification"
    },
  ]

  enable_remediation        = true
  remediation_document_name = "AWS-TerminateEC2Instance"
  automatic_remediation     = true
  max_remediation_attempts  = 3
  remediation_retry_seconds = 60

  remediation_parameters = {
    InstanceId           = "RESOURCE_ID"
    AutomationAssumeRole = aws_iam_role.ssm_automation.arn
  }

  tags = local.common_tags

  depends_on = [
    module.config_recorder,
    aws_lambda_permission.config_invoke,
  ]
}

# =============================================================================
# SSM Automation Role — For AWS-TerminateEC2Instance
# =============================================================================

resource "aws_iam_role" "ssm_automation" {
  name = "${var.project_name}-ssm-automation"

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
  name = "${var.project_name}-ssm-automation"
  role = aws_iam_role.ssm_automation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerminateEC2"
        Effect = "Allow"
        Action = [
          "ec2:TerminateInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
        ]
        Resource = "*"
      },
    ]
  })
}

# =============================================================================
# Test Resources (optional) — Noncompliant EC2 in Public Subnet
# =============================================================================

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

resource "aws_iam_role" "test_ssm_instance" {
  count = var.create_test_resources ? 1 : 0

  name = "${var.project_name}-test-ssm-instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "test_ssm_instance" {
  count = var.create_test_resources ? 1 : 0

  role       = aws_iam_role.test_ssm_instance[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "test_ssm_instance" {
  count = var.create_test_resources ? 1 : 0

  name = "${var.project_name}-test-ssm-instance"
  role = aws_iam_role.test_ssm_instance[0].name

  tags = local.common_tags
}

# Noncompliant: EC2 in public subnet (triggers ec2-in-public-subnet rule)
resource "aws_instance" "test_public_ec2" {
  count = var.create_test_resources ? 1 : 0

  ami                    = data.aws_ami.amazon_linux_2023[0].id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.test_ssm_instance[0].name

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-test-public-ec2"
  })

  depends_on = [module.config_recorder]
}
