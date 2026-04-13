# AWS Security Hardening Labs

![Terraform CI](https://github.com/prasitstk/aws-security-hardening-labs/actions/workflows/terraform-ci.yml/badge.svg)

A collection of AWS security hardening labs built entirely with Terraform. Explore managed and custom Config rules, SSM-based auto-remediation, compliance dashboards, and event-driven notifications. Designed as a progressive series from basic governance to advanced posture management.

---

## Labs

| # | Lab | Description | Key Services |
|---|-----|-------------|--------------|
| 01 | [Config Rules Compliance Baseline](labs/01-config-rules-compliance-baseline/) | Set up AWS Config recorder with managed rules (`restricted-ssh`, `required-tags`) and SSM remediation | Config, SSM, S3, IAM |
| 02 | [Custom Rules and Conformance Packs](labs/02-custom-rules-conformance-packs/) | Custom Lambda rule (Node.js 22.x), Guard policy, and managed rule bundled in a conformance pack | Config, Lambda, Conformance Packs |
| 03 | [SSM Automation EC2 Remediation](labs/03-ssm-automation-ec2-remediation/) | Custom Python Lambda detecting EC2 in public subnets with automatic SSM termination | Config, Lambda, SSM, VPC |
| 04 | [EBS Volume Cleanup with Config Remediation](labs/04-ebs-volume-cleanup-with-config-remediation/) | Managed rule detecting unattached EBS volumes with SSM snapshot-and-delete remediation and EventBridge notifications | Config, SSM, EventBridge, SNS |

Each lab includes a detailed README with architecture diagram, deployment steps, validation commands, and cost estimate.

---

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.5
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with appropriate credentials
- An AWS account with permissions for Config, S3, IAM, SSM, Lambda, EventBridge, SNS
- Default region: `us-east-1`

---

## Quick Start

```bash
# Clone the repo
git clone https://github.com/prasitstk/aws-security-hardening-labs.git
cd aws-security-hardening-labs

# Pick a lab
cd labs/01-config-rules-compliance-baseline/infrastructure/terraform

# Configure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set a globally unique config_bucket_name

# Deploy
terraform init
terraform plan
terraform apply

# Clean up (avoid ongoing charges)
terraform destroy
```

---

## Local Validation

Run the validation script before pushing to catch formatting and syntax issues locally (the same checks that CI runs on GitHub):

```bash
# From the repo root
bash tests/validate.sh
```

This finds every Terraform directory under `shared/modules/` and `labs/`, then runs `terraform init`, `fmt -check`, and `validate` on each. Expected output when everything passes:

```
=== Terraform Validation Suite ===

Validating labs/01-config-rules-compliance-baseline/infrastructure/terraform... OK
Validating labs/02-custom-rules-conformance-packs/infrastructure/terraform... OK
Validating labs/03-ssm-automation-ec2-remediation/infrastructure/terraform... OK
Validating labs/04-ebs-volume-cleanup-with-config-remediation/infrastructure/terraform... OK
Validating shared/modules/config-compliance-dashboard... OK
Validating shared/modules/config-recorder... OK
Validating shared/modules/config-rule... OK

All checks passed
```

> **Note:** Each `terraform init` downloads the AWS provider, so the first run requires internet access and takes a minute or two.

---

## Shared Modules

Reusable Terraform modules consumed by all labs via relative paths:

| Module | Purpose |
|--------|---------|
| [`config-recorder`](shared/modules/config-recorder/) | AWS Config recorder singleton: IAM role, versioned S3 bucket, recorder, delivery channel |
| [`config-rule`](shared/modules/config-rule/) | Config rule wrapper supporting managed rules, custom Lambda rules, and optional SSM remediation |
| [`config-compliance-dashboard`](shared/modules/config-compliance-dashboard/) | Compliance monitoring: custom metrics Lambda, CloudWatch dashboard, alarms, EventBridge + SNS |

See each module's README for usage examples and input/output documentation.

---

## Comparative Analysis

See [`COMPARISON.md`](COMPARISON.md) for a structured comparison of AWS Config rule mechanisms — managed rules, custom Lambda rules, Guard policies, and conformance packs — with decision matrices, cost analysis, and trade-off discussion based on hands-on implementation across all labs.

---

## Directory Structure

```
aws-security-hardening-labs/
  README.md
  COMPARISON.md
  CLAUDE.md
  LICENSE
  .gitignore
  .devcontainer/devcontainer.json
  .github/
    dependabot.yml
    workflows/terraform-ci.yml  # Layer 2: CI/CD pipeline
  tests/validate.sh             # Local validation script
  docs/
  shared/
    modules/
      config-recorder/                  # Singleton Config recorder + S3 + IAM
      config-rule/                      # Config rule + optional SSM remediation
      config-compliance-dashboard/      # Layer 3: CloudWatch dashboard + metrics Lambda + alarms + SNS
    policies/
      config-service-role.json          # IAM trust policy template
      config-s3-delivery.json           # S3 bucket policy template
  labs/
    01-config-rules-compliance-baseline/
    02-custom-rules-conformance-packs/
    03-ssm-automation-ec2-remediation/
    04-ebs-volume-cleanup-with-config-remediation/
```

---

## Cost Awareness

AWS Config pricing (us-east-1):

| Component | Cost |
|-----------|------|
| Configuration items recorded | $0.003 per item |
| Config rule evaluations | $0.001 per evaluation |
| Conformance pack evaluations | $0.001 per evaluation |

Estimated cost per lab: **$2-20/month** depending on test resources deployed. See each lab's README for a specific cost breakdown.

**Always run `terraform destroy` when done** to avoid ongoing charges from the Config recorder and S3 storage.

---

## Important: Config Recorder Singleton

AWS Config allows only **one recorder per region per account**. Labs using the `config-recorder` shared module cannot run simultaneously in the same account/region. Deploy and destroy one lab at a time, or use separate AWS accounts.

---

## Enhancement Roadmap

This collection follows the [5-Layer Enhancement Model](CLAUDE.md#5-layer-enhancement-model):

| Layer | Status |
|-------|--------|
| 1. Infrastructure as Code (Terraform) | Done — all labs |
| 2. CI/CD Pipeline (GitHub Actions) | Done — terraform fmt/validate on push and PR |
| 3. Monitoring & Observability (CloudWatch) | Done — compliance dashboard, metrics Lambda, alarms, EventBridge + SNS |
| 4. Finance Domain Twist (PCI-DSS, SOX) | Planned |
| 5. Multi-Cloud Extension (Azure Policy) | Planned |

Additional labs covering Security Hub, IAM Access Analyzer, and CloudTrail + Athena analytics are planned for future additions.

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
