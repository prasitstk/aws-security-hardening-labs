/**
 * Custom AWS Config Rule — EC2 Instance Count Check
 *
 * Evaluates running EC2 instances. The first-launched instance is COMPLIANT;
 * all additional instances are NON_COMPLIANT and auto-terminated.
 *
 * Runtime: Node.js 22.x (ESM, built-in AWS SDK v3)
 */

import {
  EC2Client,
  DescribeInstancesCommand,
  TerminateInstancesCommand,
} from "@aws-sdk/client-ec2";
import {
  ConfigServiceClient,
  PutEvaluationsCommand,
} from "@aws-sdk/client-config-service";

const ec2 = new EC2Client();
const configService = new ConfigServiceClient();

export const handler = async (event) => {
  const invokingEvent = JSON.parse(event.invokingEvent);
  const resultToken = event.resultToken;

  // Handle oversized notification — re-evaluate via API
  if (
    invokingEvent.messageType ===
    "OversizedConfigurationItemChangeNotification"
  ) {
    const configItem = invokingEvent.configurationItemSummary;
    const evaluation = await evaluateInstance(configItem.resourceId);
    await putEvaluation(
      evaluation,
      configItem.resourceId,
      configItem.resourceType,
      configItem.configurationItemCaptureTime,
      resultToken
    );
    return;
  }

  const configItem = invokingEvent.configurationItem;

  // Skip deleted resources
  if (configItem.configurationItemStatus === "ResourceDeleted") {
    await putEvaluation(
      "NOT_APPLICABLE",
      configItem.resourceId,
      configItem.resourceType,
      configItem.configurationItemCaptureTime,
      resultToken
    );
    return;
  }

  // Only evaluate EC2 instances
  if (configItem.resourceType !== "AWS::EC2::Instance") {
    await putEvaluation(
      "NOT_APPLICABLE",
      configItem.resourceId,
      configItem.resourceType,
      configItem.configurationItemCaptureTime,
      resultToken
    );
    return;
  }

  const evaluation = await evaluateInstance(configItem.resourceId);
  await putEvaluation(
    evaluation,
    configItem.resourceId,
    configItem.resourceType,
    configItem.configurationItemCaptureTime,
    resultToken
  );
};

async function evaluateInstance(instanceId) {
  // List all running instances
  const response = await ec2.send(
    new DescribeInstancesCommand({
      Filters: [
        { Name: "instance-state-name", Values: ["running", "pending"] },
      ],
    })
  );

  const instances = response.Reservations.flatMap((r) => r.Instances).sort(
    (a, b) => new Date(a.LaunchTime) - new Date(b.LaunchTime)
  );

  if (instances.length === 0) {
    return "NOT_APPLICABLE";
  }

  // First-launched instance is compliant; all others are not
  const firstInstanceId = instances[0].InstanceId;

  if (instanceId === firstInstanceId) {
    return "COMPLIANT";
  }

  // Auto-terminate the noncompliant instance
  console.log(`Terminating noncompliant instance: ${instanceId}`);
  try {
    await ec2.send(
      new TerminateInstancesCommand({ InstanceIds: [instanceId] })
    );
    console.log(`Successfully terminated instance: ${instanceId}`);
  } catch (err) {
    console.error(`Failed to terminate instance ${instanceId}:`, err);
  }

  return "NON_COMPLIANT";
}

async function putEvaluation(
  complianceType,
  resourceId,
  resourceType,
  orderingTimestamp,
  resultToken
) {
  await configService.send(
    new PutEvaluationsCommand({
      Evaluations: [
        {
          ComplianceResourceType: resourceType,
          ComplianceResourceId: resourceId,
          ComplianceType: complianceType,
          OrderingTimestamp: new Date(orderingTimestamp),
        },
      ],
      ResultToken: resultToken,
    })
  );
}
