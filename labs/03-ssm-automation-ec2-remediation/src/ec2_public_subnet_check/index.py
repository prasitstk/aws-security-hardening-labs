"""Custom AWS Config rule: Detects EC2 instances running in public subnets.

A subnet is considered "public" if its associated route table contains a route
with destination 0.0.0.0/0 or ::/0 pointing to an Internet Gateway (igw-*).

Reference: AWS Config Custom Rule Developer Guide
https://docs.aws.amazon.com/config/latest/developerguide/evaluate-config_develop-rules_lambda-functions.html
"""

import json
import logging
from datetime import datetime

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client("ec2")
config = boto3.client("config")


def lambda_handler(event, context):
    invoking_event = json.loads(event["invokingEvent"])

    result_token = event["resultToken"]

    # Handle oversized configuration items
    if (
        invoking_event.get("messageType")
        == "OversizedConfigurationItemChangeNotification"
    ):
        configuration_item = get_configuration_item(
            invoking_event["configurationItemSummary"]["resourceType"],
            invoking_event["configurationItemSummary"]["resourceId"],
        )
    else:
        configuration_item = invoking_event.get("configurationItem", {})

    resource_type = configuration_item.get("resourceType", "")
    resource_id = configuration_item.get("resourceId", "")
    configuration_item_status = configuration_item.get("configurationItemStatus", "")

    # Skip deleted resources
    if configuration_item_status in ("ResourceDeleted", "ResourceNotRecorded"):
        compliance = "NOT_APPLICABLE"
        annotation = f"Resource {resource_id} has been deleted."
    elif resource_type != "AWS::EC2::Instance":
        compliance = "NOT_APPLICABLE"
        annotation = f"Resource type {resource_type} is not evaluated by this rule."
    else:
        compliance, annotation = evaluate_ec2_instance(configuration_item)

    logger.info(
        "Evaluation result: resource=%s, compliance=%s, annotation=%s",
        resource_id,
        compliance,
        annotation,
    )

    config.put_evaluations(
        Evaluations=[
            {
                "ComplianceResourceType": resource_type,
                "ComplianceResourceId": resource_id,
                "ComplianceType": compliance,
                "Annotation": annotation[:255],
                "OrderingTimestamp": datetime.utcnow().isoformat() + "Z",
            }
        ],
        ResultToken=result_token,
    )

    return {"compliance": compliance, "annotation": annotation}


def get_configuration_item(resource_type, resource_id):
    """Fetch the current configuration item for oversized items."""
    result = config.get_resource_config_history(
        resourceType=resource_type,
        resourceId=resource_id,
        limit=1,
    )
    items = result.get("configurationItems", [])
    return items[0] if items else {}


def evaluate_ec2_instance(configuration_item):
    """Determine if the EC2 instance is in a public subnet."""
    resource_id = configuration_item.get("resourceId", "")

    # Extract subnet ID from the configuration item
    config_data = configuration_item.get("configuration", {})
    if isinstance(config_data, str):
        config_data = json.loads(config_data)

    subnet_id = config_data.get("subnetId")
    vpc_id = config_data.get("vpcId")

    if not subnet_id:
        return "NOT_APPLICABLE", f"Instance {resource_id} has no subnet ID."

    if is_public_subnet(subnet_id, vpc_id):
        return (
            "NON_COMPLIANT",
            f"Instance {resource_id} is in public subnet {subnet_id} "
            f"(route table has a route to an Internet Gateway).",
        )

    return (
        "COMPLIANT",
        f"Instance {resource_id} is in private subnet {subnet_id}.",
    )


def is_public_subnet(subnet_id, vpc_id):
    """Check if a subnet has a route to an Internet Gateway."""
    # Look for an explicit route table association
    response = ec2.describe_route_tables(
        Filters=[
            {"Name": "association.subnet-id", "Values": [subnet_id]},
        ]
    )
    route_tables = response.get("RouteTables", [])

    # Fall back to the VPC main route table if no explicit association
    if not route_tables and vpc_id:
        response = ec2.describe_route_tables(
            Filters=[
                {"Name": "vpc-id", "Values": [vpc_id]},
                {"Name": "association.main", "Values": ["true"]},
            ]
        )
        route_tables = response.get("RouteTables", [])

    for rt in route_tables:
        for route in rt.get("Routes", []):
            gateway_id = route.get("GatewayId", "")
            destination = route.get("DestinationCidrBlock", "") or route.get(
                "DestinationIpv6CidrBlock", ""
            )
            if gateway_id.startswith("igw-") and destination in ("0.0.0.0/0", "::/0"):
                return True

    return False
