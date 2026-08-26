"""gpu-gate — control-plane gate for GPU production onboarding.

Receives a raw validation report from a GPU node and DECIDES whether the node
may be provisioned. The node reports; the control plane is authoritative —
a node cannot gate itself.

Gate policy (server-side, configurable via env):
  any FAIL  -> RMA        (return material authorization: pull the node from the fleet)
  any WARN  -> HOLD       (pending manual review / bandwidth burn test)
  else      -> PROVISION

Every report is appended to DynamoDB as an audit record keyed by
(node_id, report_ts), so onboarding/RMA decisions are fully traceable.
"""

import json
import os
from datetime import datetime, timezone

import boto3

TABLE = os.environ.get("NODES_TABLE", "gpu-nodes")
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE)


def decide(checks):
    """Apply gate policy to raw checks. Returns (decision, reasons)."""
    reasons = []
    statuses = []
    for c in checks:
        if not isinstance(c, dict):
            continue
        st = c.get("status")
        statuses.append(st)
        if st in ("FAIL", "WARN"):
            reasons.append(f"{c.get('name')}={c.get('value')} ({st})")
    if "FAIL" in statuses:
        return "RMA", reasons
    if "WARN" in statuses:
        return "HOLD", reasons
    return "PROVISION", reasons


def handler(event, context):
    body = event.get("body") or "{}"
    if isinstance(body, str):
        try:
            body = json.loads(body)
        except json.JSONDecodeError:
            body = {}

    node_id = body.get("node_id") or body.get("serial")
    checks = body.get("checks")
    if not node_id or not isinstance(checks, list):
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "node_id and checks[] are required"}),
        }

    decision, reasons = decide(checks)
    report_ts = datetime.now(timezone.utc).isoformat()

    table.put_item(Item={
        "node_id": node_id,
        "report_ts": report_ts,
        "decision": decision,
        "reasons": reasons,
        "check_count": len(checks),
        "source": body.get("source", "unknown"),
    })

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({
            "node_id": node_id,
            "decision": decision,
            "reasons": reasons,
            "report_ts": report_ts,
        }),
    }
