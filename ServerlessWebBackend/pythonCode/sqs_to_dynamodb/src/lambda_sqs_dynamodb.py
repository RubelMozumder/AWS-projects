import boto3, json
import random
import string
import os

global CLIENT, TABLE_NAME
CLIENT = boto3.client("dynamodb")
TABLE_NAME = os.environ.get("TABLE_NAME", None)  # Default to "OrdersTable" if not set


def generate_id(length=12):
    chars = string.ascii_letters + string.digits
    return ''.join(random.choices(chars, k=length))

def put_item(event, context):
    """Put an order in DynamoDB table"""
    print("Received event: " + json.dumps(event, indent=2))
    for record in event["Records"]:
        print("Processing record: " + json.dumps(record, indent=2))
        order = json.loads(record["body"])
        print("Putting item in DynamoDB: " + json.dumps(order, indent=2))
        order_id = order.get("orderId", generate_id())
        customer_name = order.get("customerName", "Unknown Customer")
        product = order.get("product", "Unknown Product")
        quantity = order.get("quantity", 0)
        CLIENT.put_item(
            TableName=TABLE_NAME,
            Item={
                "orderId": {"S": order_id},
                "customerName": {"S": customer_name},
                "product": {"S": product},
                "quantity": {"N": str(quantity)},
            },
        )    
    