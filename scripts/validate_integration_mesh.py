#!/usr/bin/env python3
import json
import sys
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
POLICY = ROOT / "registry" / "integration_mesh_policy.json"
REGISTRY = ROOT / "registry" / "integrations.json"

REQUIRED_CAPS = {"read", "write", "delete", "admin"}


def load(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def fail(msg: str):
    print(f"ERROR: {msg}", file=sys.stderr)
    raise SystemExit(1)


def main():
    policy = load(POLICY)
    registry = load(REGISTRY)

    if policy.get("defaults", {}).get("credential_material_in_git") is not False:
        fail("credential material must be prohibited from Git")

    ids = set()
    for item in registry.get("integrations", []):
        iid = item.get("integration_id")
        if not iid or iid in ids:
            fail(f"missing or duplicate integration_id: {iid!r}")
        ids.add(iid)

        endpoint = item.get("endpoint")
        parsed = urlparse(endpoint or "")
        if parsed.scheme != "https" or not parsed.netloc:
            fail(f"{iid}: endpoint must be an absolute HTTPS URL")

        if item.get("persistent_binding") is not True:
            fail(f"{iid}: persistent_binding must be true")

        caps = item.get("capabilities", {})
        if set(caps) != REQUIRED_CAPS or not all(isinstance(caps[k], bool) for k in REQUIRED_CAPS):
            fail(f"{iid}: capabilities must explicitly declare boolean read/write/delete/admin")

        binding = item.get("credential_binding", {})
        mode = binding.get("mode")
        secret_ref = binding.get("secret_ref")
        if mode == "VAULT" and not secret_ref:
            fail(f"{iid}: VAULT mode requires secret_ref")
        if mode != "VAULT" and secret_ref:
            fail(f"{iid}: secret_ref is allowed only for VAULT mode")

        health = item.get("health", {})
        if health.get("enabled") is not True:
            fail(f"{iid}: health monitoring must be enabled")

        failure = item.get("failure_policy", {})
        if failure.get("bypass_provider_controls") is not False:
            fail(f"{iid}: provider controls may never be bypassed")

    print(f"PASS: {len(ids)} governed integration(s) validated")


if __name__ == "__main__":
    main()
