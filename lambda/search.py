"""Semantic product search via Bedrock KB retrieval."""
import time
import uuid
from common import bedrock, ddb, ok, err, KB_ID, REGION


def search(body: dict) -> dict:
    query = (body.get("query") or "").strip()
    if not query:
        return err("Missing query")

    top_k = min(int(body.get("top_k", 10)), 20)

    results = bedrock.retrieve(
        knowledgeBaseId=KB_ID,
        retrievalQuery={"text": query},
        retrievalConfiguration={"managedSearchConfiguration": {"numberOfResults": top_k}},
    )["retrievalResults"]

    products = []
    for r in results:
        text  = r["content"]["text"]
        score = r.get("score", 0)
        meta  = r.get("metadata", {})
        # parse fields from the plain-text document
        fields = {}
        for line in text.splitlines():
            if ": " in line:
                k, v = line.split(": ", 1)
                fields[k.strip().lower()] = v.strip()
        products.append({
            "sku":     meta.get("sku") or fields.get("sku", ""),
            "name":    meta.get("name") or fields.get("name", ""),
            "price":   meta.get("price") or fields.get("price", ""),
            "url_key": meta.get("url_key") or fields.get("url key", ""),
            "image":   meta.get("image") or fields.get("image", ""),
            "score":   round(score, 4),
        })

    # log search query for insights
    try:
        ts = int(time.time() * 1000)
        ddb.put_item(Item={
            "PK": "SEARCH",
            "SK": f"Q#{ts}-{uuid.uuid4().hex[:6]}",
            "q":  query,
        })
    except Exception:
        pass

    return ok({"query": query, "results": products})
