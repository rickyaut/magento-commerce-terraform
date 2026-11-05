import json
import os
import boto3

REGION      = os.environ.get("REGION", "ap-southeast-2")
BUCKET      = os.environ.get("BUCKET", "magento-kb")
KB_ID       = os.environ.get("KB_ID", "")
DS_ID       = os.environ.get("DS_ID", "")
TABLE       = os.environ.get("TABLE", "magento-search-logs")
S3_PREFIX   = "products"

s3       = boto3.client("s3", region_name=REGION)
bedrock  = boto3.client("bedrock-agent-runtime", region_name=REGION)
bedrock_agent = boto3.client("bedrock-agent", region_name=REGION)
ddb      = boto3.resource("dynamodb", region_name=REGION).Table(TABLE)


def ok(body: dict, status: int = 200) -> dict:
    return {"statusCode": status, "body": json.dumps(body)}


def err(msg: str, status: int = 400) -> dict:
    return {"statusCode": status, "body": json.dumps({"error": msg})}
