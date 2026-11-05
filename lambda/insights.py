"""Search insights: word cloud and recent search terms."""
import re
from collections import Counter
from common import ddb, ok

MAX_QUERIES = 500
_TOKEN_RE   = re.compile(r"[a-z0-9]+")
_STOP       = frozenset("a an the is are was were be been being have has had do does did "
                        "will would could should may might shall can need i you he she it "
                        "we they what which who this that these those and or but if in on "
                        "at to for of with by from".split())


def _load(limit: int = MAX_QUERIES) -> list[dict]:
    return ddb.query(
        KeyConditionExpression="PK = :pk AND begins_with(SK, :sk)",
        ExpressionAttributeValues={":pk": "SEARCH", ":sk": "Q#"},
        ScanIndexForward=False,
        Limit=limit,
    )["Items"]


def _tokenize(text: str) -> list[str]:
    return [t for t in _TOKEN_RE.findall(text.lower())
            if len(t) >= 3 and t not in _STOP]


def cloud() -> dict:
    rows    = _load()
    counter = Counter()
    for r in rows:
        counter.update(_tokenize(r.get("q", "")))
    top = counter.most_common(60)
    return ok({"total": len(rows),
               "words": [{"word": w, "count": c} for w, c in top]})


def recent() -> dict:
    rows = _load(100)
    return ok({"queries": [{"query": r.get("q", ""),
                             "sk": r["SK"]} for r in rows]})
