#!/usr/bin/env python3
"""Fail-closed source verifier for the CHLOM production control plane."""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EDGE = ROOT / "supabase/functions/chlom-control-plane-v1/index.ts"
DENO = ROOT / "supabase/functions/chlom-control-plane-v1/deno.json"
ACCESS = ROOT / "migrations/20260904063134_chlom_api_access_registry_v1.sql"
CAPABILITIES = ROOT / "migrations/20260904063147_chlom_api_capabilities_v1.sql"
DISPATCH_V1 = ROOT / "migrations/20260904063223_chlom_api_dispatch_v1.sql"
FOUNDER = ROOT / "migrations/20260904063240_chlom_founder_api_operator_v1.sql"
DISPATCH_V2 = ROOT / "migrations/20260904064558_chlom_api_idempotent_dispatch_v2.sql"
EVIDENCE = ROOT / "evidence/chlom-control-plane-v1/2026-09-04.production-evidence.json"

FILES = [EDGE, DENO, ACCESS, CAPABILITIES, DISPATCH_V1, FOUNDER, DISPATCH_V2, EVIDENCE]
HEX64 = re.compile(r"^[0-9a-f]{64}$")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def read(path: Path) -> str:
    require(path.is_file(), f"missing required file: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


def main() -> None:
    contents = {path: read(path) for path in FILES}
    edge = contents[EDGE]
    access = contents[ACCESS]
    capabilities = contents[CAPABILITIES]
    dispatch_v1 = contents[DISPATCH_V1]
    founder = contents[FOUNDER]
    dispatch_v2 = contents[DISPATCH_V2]

    require("SUPABASE_SERVICE_ROLE_KEY" not in edge, "gateway must not use a service-role key")
    require("SUPABASE_ANON_KEY" in edge, "gateway must forward caller JWT through anon-key transport")
    require("authorization" in edge.lower(), "gateway must require bearer authorization")
    require("Idempotency-Key".lower() in edge.lower(), "gateway must enforce mutation idempotency")
    require("MAX_REQUEST_BYTES" in edge and "MAX_RESPONSE_BYTES" in edge, "gateway must bound I/O")
    require("chlom_api_dispatch_v2" in edge, "gateway must invoke dispatch v2")

    for route in ("/status", "/capabilities", "/health", "/dispatch"):
        require(route in edge, f"gateway route missing: {route}")

    excluded = (
        "external_money_movement",
        "production_token_mint_confirmation",
        "tokenomics_activation",
        "validator_activation",
        "public_chain_anchor_confirmation",
        "legal_title_adjudication",
    )
    for action in excluded:
        require(action in edge, f"edge exclusion missing: {action}")
        require(action in capabilities, f"capability exclusion missing: {action}")

    require("force row level security" in access.lower(), "operator and dispatch tables must force RLS")
    require("reject_append_only_mutation_v1" in access, "operator and dispatch tables must be append-only")
    require("authority_rank_v1" in access, "authority ordering function missing")

    require("CHLOM_API_ACTION_NOT_ALLOWED" in dispatch_v1, "dispatcher must fail closed on unknown action")
    require("CHLOM_API_SCOPE_DENIED" in dispatch_v1, "dispatcher must enforce scopes")
    require("CHLOM_API_AUTHORITY_DENIED" in dispatch_v1, "dispatcher must enforce authority")
    require("append_dail_event" in dispatch_v1, "dispatcher must append a DAIL receipt")
    require("raw_request_payload_recorded', false" in dispatch_v1, "dispatcher must not record raw request payloads")

    require("lower(u.email) = 'contact@crownthrive.com'" in founder, "founder enrollment must resolve confirmed identity")
    require("email_confirmed_at is not null" in founder, "founder enrollment must fail closed without confirmation")
    require("raw_credentials_recorded', false" in founder, "founder enrollment must not record credentials")

    require("pg_advisory_xact_lock" in dispatch_v2, "dispatch v2 must serialize identical idempotency keys")
    require("CHLOM_API_IDEMPOTENCY_KEY_REQUIRED" in dispatch_v2, "mutation idempotency must be mandatory")
    require("CHLOM_API_IDEMPOTENCY_CONFLICT" in dispatch_v2, "idempotency payload conflicts must fail")
    require("unique (operator_user_id, action, idempotency_key_hash)" in dispatch_v2.lower(), "idempotency uniqueness missing")
    require("reject_append_only_mutation_v1" in dispatch_v2, "idempotency receipts must be append-only")

    evidence = json.loads(contents[EVIDENCE])
    require(evidence["contract"] == "ct.chlom.production-gateway-evidence.v1", "unexpected evidence contract")
    require(evidence["gateway"]["status"] == "ACTIVE", "gateway evidence is not ACTIVE")
    require(evidence["gateway"]["verify_jwt"] is True, "provider JWT gate is not asserted")
    require(evidence["gateway"]["unauthenticated_probe"]["http_status"] == 401, "unauthenticated denial probe missing")
    require(evidence["dail"]["integrity_state"] == "PASS_GLOBAL_COMPACT_CHAIN", "DAIL global compact-chain pass missing")
    require(evidence["dail"]["sequence_span_lag"] == 0, "DAIL lag is nonzero")
    require(evidence["canary"]["second_execution_idempotent_replay"] is True, "idempotent replay proof missing")
    require(evidence["canary"]["duplicate_bindings_created"] == 0, "canary created duplicates")
    require(evidence["counts"]["money_movement"] == 0, "evidence must not imply money movement")
    require(evidence["counts"]["external_production_mint_confirmed"] == 0, "evidence must not imply production minting")

    for field in (
        evidence["gateway"]["deployment_sha256"],
        evidence["canary"]["binding_record_sha256"],
        evidence["canary"]["asset_dail_event_hash"],
        evidence["canary"]["dispatch_result_sha256"],
        evidence["canary"]["receipt_dail_event_hash"],
    ):
        require(bool(HEX64.fullmatch(field)), f"invalid SHA-256 value: {field!r}")

    manifest = {
        str(path.relative_to(ROOT)): hashlib.sha256(contents[path].encode("utf-8")).hexdigest()
        for path in FILES
    }
    print(json.dumps({"ok": True, "contract": "ct.chlom.source-verification.v1", "files": manifest}, indent=2))


if __name__ == "__main__":
    main()
