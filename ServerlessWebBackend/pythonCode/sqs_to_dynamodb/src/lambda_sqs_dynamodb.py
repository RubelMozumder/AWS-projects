import boto3
import json
from decimal import Decimal
import random
import string
import os
from boto3.dynamodb.types import TypeSerializer

CLIENT = boto3.client("dynamodb")
TABLE_NAME = os.environ.get("TABLE_NAME", "ServerlessWebBackend-Table")
SERIALIZER = TypeSerializer()


def generate_id(length=12):
    chars = string.ascii_letters + string.digits
    return ''.join(random.choices(chars, k=length))


def _normalize_value(value):
    if isinstance(value, float):
        return Decimal(str(value))
    if isinstance(value, dict):
        return {k: _normalize_value(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_normalize_value(v) for v in value]
    return value


def _extract_orders(event):
    records = event.get("Records") if isinstance(event, dict) else None
    if not records:
        return [event]

    orders = []
    for record in records:
        body = record.get("body", "{}")
        if isinstance(body, str):
            orders.append(json.loads(body))
        elif isinstance(body, dict):
            orders.append(body)
        else:
            orders.append({})
    return orders


def put_item(event, context):
    """Put an order in DynamoDB table"""
    print("Received event: " + json.dumps(event, indent=2))
    orders = _extract_orders(event)
    for order in orders:
        if not isinstance(order, dict):
            order = {"payload": order}

        # Ensure table partition key exists while preserving all payload fields.
        order_id = order.get("id") or order.get("orderId") or generate_id()
        order["id"] = str(order_id)
        item = _normalize_value(order)

        print("Putting item in DynamoDB: " + json.dumps(order, indent=2))
        CLIENT.put_item(
            TableName=TABLE_NAME,
            Item={k: SERIALIZER.serialize(v) for k, v in item.items()},
        )
    