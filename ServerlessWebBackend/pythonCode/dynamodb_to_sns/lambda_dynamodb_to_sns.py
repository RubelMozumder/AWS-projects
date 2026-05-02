import boto3
import json

client = boto3.client("sns")


def publish_to_sns(event, context):
    for record in event.get("Records", []):
        if record.get("eventName") == "INSERT":
            new_record = record["dynamodb"]["NewImage"]

            message = {"default": json.dumps(new_record)}

            response = client.publish(
                TargetArn="arn:aws:sns:eu-central-1:897035677417:POC-topic",
                Message=json.dumps(message),
                MessageStructure="json",
            )

            print("SNS response:", response)
