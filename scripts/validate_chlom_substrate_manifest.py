#!/usr/bin/env python3
"""Validate the non-negotiable source contract for the CHLOM cryptographic substrate."""

from __future__ import annotations

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "substrate" / "chlom-l1" / "runtime-manifest.json"
MIGRATIONS = ROOT / "ops" / "custody" / "CHLOM_PRODUCTION_MIGRATION_MANIFEST_20260903.json"
REQUIRED_PALLETS = {
    "authority",
    "identity",
    "rights",
    "licensing",
    "settlement",
    "tokenization",
    "oracle",
    "checkpoint",
}


def fail(message: str) -> None:
    raise SystemExit(f"CHLOM substrate validation failed: {message}")


def main() -> int:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    migration_manifest = json.loads(MIGRATIONS.read_text(encoding="utf-8"))

    if manifest.get("contract") != "ct.chlom.substrate-runtime-candidate.v1":
        fail("unexpected runtime manifest contract")
    if manifest.get("polkadot_sdk", {}).get("tag") != "polkadot-stable2506-7":
        fail("Polkadot SDK tag drift")
    if set(manifest.get("pallets", [])) != REQUIRED_PALLETS:
        fail("required pallet set is incomplete or contains unreviewed additions")

    production = manifest.get("production", {})
    forbidden_true = {
        "live_validator_network",
        "production_wasm_deployed",
        "public_external_nft_mint",
        "chlom_coin_issued",
        "chm_governance_token_issued",
        "native_external_money_movement",
    }
    asserted = sorted(key for key in forbidden_true if production.get(key) is not False)
    if asserted:
        fail(f"uncertified production claims: {asserted}")

    for pallet in REQUIRED_PALLETS:
        path = ROOT / "substrate" / "chlom-l1" / "pallets" / pallet / "src" / "lib.rs"
        if not path.is_file():
            fail(f"missing pallet source: {pallet}")

    source = "\n".join(
        path.read_text(encoding="utf-8")
        for path in (ROOT / "substrate" / "chlom-l1" / "pallets").glob("*/src/lib.rs")
    )
    required_phrases = {
        "money_movement_authorized",
        "autonomous_legal_effect",
        "raw_private_evidence",
        "provider_receipt",
        "previous_record_hash",
    }
    missing = sorted(phrase for phrase in required_phrases if phrase not in source)
    if missing:
        fail(f"missing fail-closed source controls: {missing}")

    migrations = migration_manifest.get("migrations", [])
    if len(migrations) != 6:
        fail("provider migration count mismatch")
    for migration in migrations:
        digest = migration.get("sql_sha256", "")
        if len(digest) != 64 or any(char not in "0123456789abcdef" for char in digest):
            fail(f"invalid migration digest: {migration.get('name')}")
        if int(migration.get("sql_bytes", 0)) <= 0:
            fail(f"invalid migration byte count: {migration.get('name')}")

    print("CHLOM substrate manifest: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
