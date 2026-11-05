"""Ingest a product into S3 and trigger Bedrock KB sync."""
import json
from common import s3, bedrock_agent, ok, err, BUCKET, KB_ID, DS_ID, S3_PREFIX


def _product_text(p: dict) -> str:
    parts = [
        f"Name: {p.get('name', '')}",
        f"SKU: {p.get('sku', '')}",
        f"Price: {p.get('price', '')}",
        f"Status: {'Enabled' if str(p.get('status', '1')) == '1' else 'Disabled'}",
        f"URL Key: {p.get('url_key', '')}",
        f"Image: {p.get('image', '')}",
    ]
    if p.get("description"):
        parts.append(f"Description: {p['description']}")
    if p.get("short_description"):
        parts.append(f"Short Description: {p['short_description']}")
    if p.get("categories"):
        parts.append(f"Categories: {', '.join(p['categories'])}")
    if p.get("attributes"):
        for k, v in p["attributes"].items():
            parts.append(f"{k}: {v}")
    return "\n".join(parts)


def _sync():
    if KB_ID and DS_ID:
        try:
            bedrock_agent.start_ingestion_job(knowledgeBaseId=KB_ID, dataSourceId=DS_ID)
        except bedrock_agent.exceptions.ConflictException:
            pass  # job already running, S3 change will be picked up


def ingest(body: dict) -> dict:
    sku = body.get("sku")
    if not sku:
        return err("Missing sku")

    text = _product_text(body)
    key  = f"{S3_PREFIX}/{sku}.txt"

    s3.put_object(Bucket=BUCKET, Key=key, Body=text.encode(),
                  ContentType="text/plain",
                  Metadata={"sku": sku, "name": body.get("name", ""),
                             "price": str(body.get("price", "")),
                             "url_key": body.get("url_key", ""),
                             "image": body.get("image", "")})
    _sync()
    return ok({"status": "ingested", "key": key})


def delete(body: dict) -> dict:
    sku = body.get("sku")
    if not sku:
        return err("Missing sku")

    key = f"{S3_PREFIX}/{sku}.txt"
    s3.delete_object(Bucket=BUCKET, Key=key)
    _sync()
    return ok({"status": "deleted", "key": key})
