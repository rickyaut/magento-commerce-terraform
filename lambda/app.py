"""Lambda handler — no FastAPI, plain dict routing."""
import json
import ingest as ingest_mod
import search as search_mod
import insights as insights_mod


def handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method", "GET").upper()
    path   = event.get("rawPath", "/")
    body   = {}
    if event.get("body"):
        try:
            body = json.loads(event["body"])
        except Exception:
            pass

    if path == "/ingest" and method == "POST":
        return ingest_mod.ingest(body)
    if path == "/ingest" and method == "DELETE":
        return ingest_mod.delete(body)
    if path == "/search" and method == "POST":
        return search_mod.search(body)
    if path == "/insights/cloud":
        return insights_mod.cloud()
    if path == "/insights/recent":
        return insights_mod.recent()

    return {"statusCode": 404, "body": json.dumps({"error": "Not found"})}
