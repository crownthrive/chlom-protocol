#!/usr/bin/env python3
import argparse
import json
import socket
import ssl
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

USER_AGENT = "CrownThrive-CHLOM-Integration-Certifier/1.0 (+https://github.com/crownthrive1/chlom-protocol)"


def probe(url: str, timeout: int = 12):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "*/*"}, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ssl.create_default_context()) as resp:
            code = resp.getcode()
            ctype = resp.headers.get("Content-Type", "")
            return {
                "transport_reachable": True,
                "http_status": code,
                "content_type": ctype,
                "classification": "REACHABLE_2XX" if 200 <= code < 300 else "REACHABLE_HTTP",
                "error": None,
            }
    except urllib.error.HTTPError as exc:
        # An HTTP response proves DNS/TLS/HTTP transport reachability even when auth or route semantics reject us.
        return {
            "transport_reachable": True,
            "http_status": exc.code,
            "content_type": exc.headers.get("Content-Type", "") if exc.headers else "",
            "classification": "REACHABLE_AUTH_REQUIRED" if exc.code in (401, 403) else "REACHABLE_HTTP_NON_2XX",
            "error": str(exc.reason),
        }
    except (urllib.error.URLError, socket.timeout, TimeoutError, ssl.SSLError) as exc:
        return {
            "transport_reachable": False,
            "http_status": None,
            "content_type": "",
            "classification": "UNREACHABLE",
            "error": str(exc),
        }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--registry", default="registry/integrations.json")
    ap.add_argument("--output", default="registry/integration-runtime-certification.json")
    args = ap.parse_args()

    registry = json.loads(Path(args.registry).read_text())
    existing = {}
    out_path = Path(args.output)
    if out_path.exists():
        try:
            existing_doc = json.loads(out_path.read_text())
            existing = {x["integration_id"]: x for x in existing_doc.get("integrations", [])}
        except Exception:
            existing = {}

    now = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    rows = []
    for item in registry["integrations"]:
        p = probe(item["endpoint"])
        prior = existing.get(item["integration_id"], {})
        external = prior.get("external_certification_evidence", [])
        rows.append({
            "integration_id": item["integration_id"],
            "name": item["name"],
            "checked_at": now,
            "endpoint": item["endpoint"],
            "transport": p,
            "registered_certification_status": item.get("certification_status", "UNKNOWN"),
            "runtime_classification": (
                "TRANSPORT_VERIFIED" if p["transport_reachable"] else "DEGRADED_UNREACHABLE"
            ),
            "authenticated_runtime_certified": False,
            "external_certification_evidence": external,
            "notes": "Transport verification does not prove authenticated read/write/admin authority. Authenticated certification remains separate unless evidence is explicitly recorded."
        })

    doc = {
        "schema_version": "1.0.0",
        "ledger_id": "ct.mesh.integration-runtime-certification.v1",
        "generated_at": now,
        "canonical_registry": "ct.mesh.integrations.v1",
        "policy": {
            "transport_reachability_is_not_authenticated_certification": True,
            "fail_closed_for_unreachable_integrations": True,
            "preserve_external_certification_evidence": True,
            "secrets_in_repository": False
        },
        "integrations": rows
    }
    out_path.write_text(json.dumps(doc, indent=2) + "\n")

    unreachable = [r["integration_id"] for r in rows if not r["transport"]["transport_reachable"]]
    print(json.dumps({"checked": len(rows), "unreachable": unreachable}))
    if unreachable:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
