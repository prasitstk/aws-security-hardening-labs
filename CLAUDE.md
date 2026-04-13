# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Public collection repo for AWS security hardening labs. Combines content from `aws-config-labs` (Config rules, remediation, conformance packs) and `aws-security-posture-labs` (Security Hub, IAM Access Analyzer, CloudTrail analytics — pending migration). Each lab is built from scratch using AWS documentation as reference, with Terraform as the IaC baseline.

## Terraform Commands

Each lab has Terraform under `labs/NN-name/infrastructure/terraform/`.

```bash
cd labs/01-config-rules-compliance-baseline/infrastructure/terraform

terraform init          # First time or after provider changes
terraform plan          # Preview
terraform apply         # Deploy
terraform destroy       # Always tear down after testing to avoid charges
```

A `terraform.tfvars.example` is provided in each lab. Copy to `terraform.tfvars` and set a globally unique `config_bucket_name` before applying. The `.gitignore` excludes `*.tfvars` (but keeps `*.tfvars.example`).

## Architecture

### Shared Modules

Labs consume reusable modules via relative paths (e.g., `source = "../../../../shared/modules/config-recorder"`):

- **`shared/modules/config-recorder/`** — Singleton per region. Creates IAM role, versioned+encrypted S3 bucket, Config recorder (CONTINUOUS mode), and delivery channel. Labs must `depends_on` this before adding rules.
- **`shared/modules/config-rule/`** — Wraps managed (`source_owner = "AWS"`) or custom Lambda rules. Supports JSON `input_parameters`, scoped resource types, and optional SSM remediation. Remediation parameters use a `map(string)` where the value `"RESOURCE_ID"` maps to `resource_value` and anything else becomes `static_value`.
- **`shared/policies/`** — JSON templates for IAM trust policy and S3 bucket policy (uses `${account_id}` / `${bucket_name}` interpolation via `templatefile`).

### Lab Structure Pattern

```
labs/NN-topic-name/
  README.md
  architecture.drawio          # Source diagram (draw.io XML)
  architecture.png             # Exported at 2x scale
  infrastructure/terraform/    # main.tf, variables.tf, outputs.tf, versions.tf
  src/                         # Lambda functions or scripts (when needed)
```

All labs use the same provider constraints: Terraform `>= 1.5`, AWS provider `>= 5.0`. Default region is `us-east-1`.

### 5-Layer Enhancement Model

1. **IaC** — Terraform baseline (all labs start here)
2. **CI/CD** — GitHub Actions
3. **Monitoring** — CloudWatch dashboards, alerts, compliance trend analysis
4. **Finance Domain** — Financial regulatory compliance (PCI-DSS, SOX)
5. **Multi-Cloud** — AWS Config + Azure Policy side-by-side

### Lab Status

| Lab | Status | Layers |
|-----|--------|--------|
| 01 — Config Rules Compliance Baseline | Complete | 1 (IaC) |
| 02 — Custom Rules and Conformance Packs | Complete | 1 (IaC) |
| 03 — SSM Automation EC2 Remediation | Complete | 1 (IaC) |
| 04 — EBS Volume Cleanup with Config Remediation | Complete | 1 (IaC) |
| 05-07 — Security Posture labs | Pending migration | — |

## AWS Provider v6 Gotchas

The `>= 5.0` constraint resolves to AWS provider v6.x. Key differences from v5:

- `aws_config_remediation_configuration` parameter block: `resource_value` and `static_value` are **flat string attributes**, not nested blocks. Use `parameter { name = "..." resource_value = "RESOURCE_ID" }` directly.
- `aws_config_config_rule` exported attribute is `rule_id` (not `config_rule_id`).
- `managed_policy_arns` on `aws_iam_role` is deprecated — use `aws_iam_role_policy_attachment` instead.
- `data.aws_region.current.name` is deprecated — use `.id` instead.
- Always validate resource schemas against the installed provider version (v6.x), not older docs.

## Security-Specific Gotchas

- **Config recorder is a singleton per region.** Only one Config recorder can exist per AWS region per account. Labs using the `config-recorder` module cannot run simultaneously in the same account/region. Deploy one lab at a time, or use separate accounts.
- **Security Hub requires Config.** Security Hub standards evaluate Config rules under the hood. The future `security-baseline` module handles this dependency.
- **Security Hub findings take time.** After enabling standards, initial compliance evaluation takes 2-4 hours.

## Architecture Diagrams

Labs use draw.io (`.drawio` XML with `mxgraph.aws4.*` stencils). Export workflow:

```bash
/Applications/draw.io.app/Contents/MacOS/draw.io --export --format png --scale 2 --border 10 -b white -o architecture.png architecture.drawio
```

**Note:** Use `-b white` (short flag) for background. The long form `--background` is misinterpreted as an input path.

Commit both `.drawio` and `.png`. The README references the PNG.

Use **direct shape** style for AWS icons (`sketch=0;...shape=mxgraph.aws4.{service};`), not the legacy `resourceIcon` wrapper.

## Conventions

- Lab directories: `NN-descriptive-topic-name` (kebab-case)
- Tags: every resource gets `local.common_tags` (`Project`, `Environment`, `ManagedBy`)
- Test resources: gated by a `create_test_resources` bool variable, intentionally noncompliant to trigger Config rules
- Git commits: Conventional Commits format — `type(scope): description`
