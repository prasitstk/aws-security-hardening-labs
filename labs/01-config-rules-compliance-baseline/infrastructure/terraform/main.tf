# -----------------------------------------------------------------------------
# Lab 01: Config Rules Compliance Baseline
# Deploys: Config recorder, restricted-ssh rule, required-tags rule,
#          SSM remediation for restricted-ssh, optional test resources.
# -----------------------------------------------------------------------------

locals {
  common_tags = merge({
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }, var.tags)
}

# --- Config Recorder (shared module) ---

module "config_recorder" {
  source = "../../../../shared/modules/config-recorder"

  bucket_name    = var.config_bucket_name
  environment    = var.environment
  resource_types = ["AWS::EC2::Instance", "AWS::EC2::SecurityGroup"]
  tags           = local.common_tags
}

# --- Config Rule: restricted-ssh ---

module "rule_restricted_ssh" {
  source = "../../../../shared/modules/config-rule"

  rule_name            = "restricted-ssh"
  source_identifier    = "INCOMING_SSH_DISABLED"
  scope_resource_types = ["AWS::EC2::SecurityGroup"]
  tags                 = local.common_tags

  enable_remediation        = true
  remediation_document_name = "AWS-DisablePublicAccessForSecurityGroup"
  automatic_remediation     = false

  remediation_parameters = {
    GroupId          = "RESOURCE_ID"
    IpAddressToBlock = "0.0.0.0/0"
  }

  depends_on = [module.config_recorder]
}

# --- Config Rule: required-tags ---

module "rule_required_tags" {
  source = "../../../../shared/modules/config-rule"

  rule_name            = "required-tags"
  source_identifier    = "REQUIRED_TAGS"
  scope_resource_types = ["AWS::EC2::Instance"]
  tags                 = local.common_tags

  input_parameters = jsonencode({
    tag1Key   = "Environment"
    tag1Value = "Dev"
  })

  depends_on = [module.config_recorder]
}

# --- Compliance Monitoring Dashboard (Layer 3) ---

module "compliance_dashboard" {
  source = "../../../../shared/modules/config-compliance-dashboard"

  project_name       = var.project_name
  config_rule_names  = ["restricted-ssh", "required-tags"]
  notification_email = var.notification_email
  tags               = local.common_tags

  depends_on = [
    module.rule_restricted_ssh,
    module.rule_required_tags,
  ]
}

# --- Test Resources (optional, for validating noncompliant evaluations) ---

data "aws_ami" "amazon_linux_2" {
  count = var.create_test_resources ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_vpc" "test" {
  count = var.create_test_resources ? 1 : 0

  cidr_block           = "10.99.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = false

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-test-vpc"
  })
}

resource "aws_subnet" "test" {
  count = var.create_test_resources ? 1 : 0

  vpc_id     = aws_vpc.test[0].id
  cidr_block = "10.99.1.0/24"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-test-subnet"
  })
}

# Noncompliant: allows SSH from 0.0.0.0/0 (triggers restricted-ssh rule)
resource "aws_security_group" "test_open_ssh" {
  count = var.create_test_resources ? 1 : 0

  name        = "${var.project_name}-test-open-ssh"
  description = "Noncompliant SG: allows SSH from anywhere (test resource)"
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

# Noncompliant: missing Environment tag (triggers required-tags rule)
resource "aws_instance" "test_missing_tags" {
  count = var.create_test_resources ? 1 : 0

  ami           = data.aws_ami.amazon_linux_2[0].id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.test[0].id

  tags = {
    Name      = "${var.project_name}-test-no-env-tag"
    ManagedBy = "terraform"
    # Deliberately missing Environment tag to trigger required-tags rule
  }
}
