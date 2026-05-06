import boto3
import json
import os

client = boto3.client("sns")
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN")


def publish_to_sns(event, context):
    if not SNS_TOPIC_ARN:
        raise RuntimeError("SNS_TOPIC_ARN is not configured")

    records = event.get("Records", []) if isinstance(event, dict) else []
    print("Received records:", len(records))

    for record in records:
        if record.get("eventName") == "INSERT":
            new_record = record.get("dynamodb", {}).get("NewImage", {})

            message = {"default": json.dumps(new_record)}

            response = client.publish(
                TopicArn=SNS_TOPIC_ARN,
                Message=json.dumps(message),
                MessageStructure="json",
            )

            print("SNS response:", response)
