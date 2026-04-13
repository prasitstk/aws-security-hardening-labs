"""
Lambda function that polls AWS Config compliance status and publishes
custom CloudWatch metrics for dashboard visualization.

Metrics published to ConfigCompliance/<project_name> namespace:
- CompliantRuleCount: number of rules in COMPLIANT state
- NonCompliantRuleCount: number of rules in NON_COMPLIANT state
- InsufficientDataRuleCount: number of rules with INSUFFICIENT_DATA
- NonCompliantResourceCount (per rule): count of non-compliant resources
"""

import os
import boto3
from datetime import datetime, timezone

config_client = boto3.client("config")
cw_client = boto3.client("cloudwatch")

NAMESPACE = os.environ["METRICS_NAMESPACE"]
RULE_NAMES = os.environ.get("RULE_NAMES", "").split(",")


def lambda_handler(event, context):
    rule_names = [r.strip() for r in RULE_NAMES if r.strip()]

    compliant = 0
    non_compliant = 0
    insufficient = 0
    metric_data = []
    now = datetime.now(timezone.utc)

    for rule_name in rule_names:
        try:
            resp = config_client.describe_compliance_by_config_rule(
                ConfigRuleNames=[rule_name]
            )
        except config_client.exceptions.NoSuchConfigRuleException:
            continue

        for result in resp.get("ComplianceByConfigRules", []):
            status = result.get("Compliance", {}).get("ComplianceType", "INSUFFICIENT_DATA")

            if status == "COMPLIANT":
                compliant += 1
            elif status == "NON_COMPLIANT":
                non_compliant += 1
            else:
                insufficient += 1

        try:
            eval_resp = config_client.get_compliance_details_by_config_rule(
                ConfigRuleName=rule_name,
                ComplianceTypes=["NON_COMPLIANT"],
                Limit=100,
            )
            nc_count = len(eval_resp.get("EvaluationResults", []))
        except Exception:
            nc_count = 0

        metric_data.append({
            "MetricName": "NonCompliantResourceCount",
            "Dimensions": [{"Name": "RuleName", "Value": rule_name}],
            "Timestamp": now,
            "Value": nc_count,
            "Unit": "Count",
        })

    metric_data.extend([
        {
            "MetricName": "CompliantRuleCount",
            "Timestamp": now,
            "Value": compliant,
            "Unit": "Count",
        },
        {
            "MetricName": "NonCompliantRuleCount",
            "Timestamp": now,
            "Value": non_compliant,
            "Unit": "Count",
        },
        {
            "MetricName": "InsufficientDataRuleCount",
            "Timestamp": now,
            "Value": insufficient,
            "Unit": "Count",
        },
    ])

    cw_client.put_metric_data(Namespace=NAMESPACE, MetricData=metric_data)

    return {
        "compliant": compliant,
        "non_compliant": non_compliant,
        "insufficient_data": insufficient,
        "rules_evaluated": len(rule_names),
    }
