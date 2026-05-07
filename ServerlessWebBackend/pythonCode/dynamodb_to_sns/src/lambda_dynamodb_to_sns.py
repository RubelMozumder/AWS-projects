import boto3
import json
import os
from boto3.dynamodb.types import TypeDeserializer

client = boto3.client("sns")
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN")
DESERIALIZER = TypeDeserializer()


def _deserialize_dynamodb_item(item):
    return {k: DESERIALIZER.deserialize(v) for k, v in item.items()}


def publish_to_sns(event, context):
    if not SNS_TOPIC_ARN:
        raise RuntimeError("SNS_TOPIC_ARN is not configured")

    records = event.get("Records", []) if isinstance(event, dict) else []
    print("Received records:", len(records))

    for record in records:
        event_name = record.get("eventName")
        if event_name not in {"INSERT", "MODIFY"}:
            continue

        new_record = record.get("dynamodb", {}).get("NewImage", {})
        if not new_record:
            continue

        payload = _deserialize_dynamodb_item(new_record)
        message = f"DynamoDB {event_name}: {json.dumps(payload, default=str)}"

        response = client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Message=message,
            Subject="DynamoDB Change",
        )

        print("SNS response:", response)
