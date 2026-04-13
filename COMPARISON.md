# AWS Config Rule Types — Comparative Analysis

A structured comparison of AWS Config rule mechanisms to inform architecture decisions. Based on hands-on implementation across Labs 01-04.

---

## Comparison Dimensions

| Dimension | Managed Rules | Custom Lambda Rules | Guard Custom Policies | Conformance Packs |
|---|---|---|---|---|
| **Setup complexity** | Low — 1 Terraform resource, no code | High — Lambda + IAM role + policy + permission + log group | Medium — 1 resource with inline Guard DSL | Medium — YAML template bundling other rule types |
| **Evaluation logic** | Predefined by AWS (200+ rules) | Any logic you can write in code (Node.js, Python) | Declarative Guard clauses against configuration items | N/A — delegates to bundled rules |
| **Supported resource types** | Per-rule (documented in AWS docs) | Any resource type Config records | Any resource type Config records | Any resource type (via bundled rules) |
| **Custom remediation** | SSM Automation documents only | Lambda can self-remediate directly (terminate, modify, etc.) | None built-in — pair with separate remediation config | Can include `RemediationConfiguration` in template |
| **Cost model** | $0.001/evaluation | Lambda cost ($0.20/1M req) + $0.001/evaluation | $0.001/evaluation | Per-rule evaluation cost (no pack surcharge) |
| **Multi-account support** | Org rules via `aws_config_organization_managed_rule` | Org rules via `aws_config_organization_custom_lambda_rule` | Org rules via `aws_config_organization_custom_policy_rule` | Organization conformance packs |
| **Drift detection** | Config tracks; no self-healing | Can detect and auto-remediate in same Lambda | Detect only — no remediation capability | Depends on bundled rules and remediation config |
| **Use case fit** | Common compliance checks (SSH, tags, encryption) | Complex logic, cross-resource checks, self-remediation | Simple property checks, naming/tagging policies | At-scale deployment of rule bundles across accounts |

## When to Use What

### Managed Rules

Best for: **Standard compliance checks** that AWS has already implemented. Use when the check maps directly to an AWS-provided rule identifier (e.g., `INCOMING_SSH_DISABLED`, `REQUIRED_TAGS`, `ENCRYPTED_VOLUMES`).

- Lab 01 uses `INCOMING_SSH_DISABLED` and `REQUIRED_TAGS` — deployed in minutes with zero custom code
- Lab 04 uses `EC2_VOLUME_INUSE_CHECK` — detects unattached EBS volumes for cleanup
- Over 200 managed rules available; always check the managed rule list before writing custom logic

### Custom Lambda Rules

Best for: **Complex evaluation logic** that requires API calls, cross-resource lookups, or in-line remediation. The most flexible option — any logic you can write, you can evaluate.

- Lab 02 uses a Node.js 22.x Lambda that counts running instances, sorts by launch time, and auto-terminates extras
- Lab 03 uses a Python Lambda that calls `ec2:DescribeRouteTables` to classify subnets as public or private
- Overhead is real: each Lambda rule needs IAM role + policy + log group + permission + zip packaging

### Guard Policies

Best for: **Simple property checks** using declarative rules. No Lambda overhead — the Guard runtime evaluates configuration items directly using a compact DSL.

- Lab 02 uses a Guard rule that checks `configuration.groupName` against a required value
- Guard syntax is concise: `configuration.property == "expected_value"`
- Cannot call APIs or perform cross-resource checks — strictly evaluates the configuration item
- `guard-2.x.x` runtime supports comparison operators, `when` conditionals, and list operations

### Conformance Packs

Best for: **Bundling multiple rules** into a single deployable unit. Useful for compliance frameworks (PCI-DSS, SOX, CIS Benchmarks) where you need consistent rule sets.

- Lab 02 deploys all 3 rule types (Lambda, Guard, Managed) in one conformance pack
- YAML template uses CloudFormation-style syntax with `AWS::Config::ConfigRule` resources
- Parameters allow injecting environment-specific values (e.g., Lambda ARN)
- Organization conformance packs push rule sets to all member accounts

## Key Trade-offs

**Lambda flexibility vs Guard simplicity** — Lambda rules can do anything (API calls, multi-resource checks, self-remediation), but each requires 5-6 Terraform resources. Guard rules need just one resource with inline policy text, but can only check properties on the configuration item itself.

**Standalone rules vs conformance packs** — Standalone rules are easier to manage individually and work with the shared `config-rule` module (Labs 01, 03, 04). Conformance packs are better for deploying rule sets atomically, especially across multiple accounts, but rules are defined in YAML rather than Terraform resources.

**Self-remediation vs SSM remediation** — Lambda self-remediation (Lab 02) is immediate and contained within the rule evaluation. SSM remediation (Labs 01, 03, 04) is more auditable, supports approval workflows, and integrates with existing SSM automation. Lambda remediation causes Terraform state drift; SSM remediation is tracked in SSM execution history.

**Cost at scale** — Managed rules and Guard rules cost $0.001/evaluation with no additional overhead. Lambda rules add Lambda invocation costs (usually negligible) but increase operational complexity. Conformance packs have no surcharge — you pay per-rule evaluation costs only.

## References

- [AWS Config Managed Rules](https://docs.aws.amazon.com/config/latest/developerguide/managed-rules-by-aws-config.html)
- [AWS Config Custom Rules](https://docs.aws.amazon.com/config/latest/developerguide/evaluate-config_develop-rules.html)
- [AWS CloudFormation Guard](https://docs.aws.amazon.com/cfn-guard/latest/ug/what-is-guard.html)
- [AWS Config Conformance Packs](https://docs.aws.amazon.com/config/latest/developerguide/conformance-packs.html)
