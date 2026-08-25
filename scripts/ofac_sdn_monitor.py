#!/usr/bin/env python3
"""Poll OFAC's SDN Advanced XML feed and record a tamper-evident state snapshot."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import tempfile
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

SOURCE_URL = "https://sanctionslistservice.ofac.treas.gov/api/PublicationPreview/exports/SDN_ADVANCED.XML"
USER_AGENT = "CrownThrive-CHLOM-OFAC-SDN-Monitor/1.0 (+https://github.com/crownthrive1/chlom-protocol)"


def fetch_feed() -> bytes:
    request = urllib.request.Request(SOURCE_URL, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def extract_publish_date(data: bytes) -> str | None:
    root = ET.fromstring(data)
    # OFAC's advanced model can evolve; search by local-name rather than hard-coding a namespace.
    for element in root.iter():
        if element.tag.rsplit("}", 1)[-1].lower() in {"dateofissue", "publishdate", "publisheddate"}:
            if element.text and element.text.strip():
                return element.text.strip()
    return None


def load_state(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--state-file", default="registry/ofac_sdn_feed_state.json")
    args = parser.parse_args()

    state_path = Path(args.state_file)
    state_path.parent.mkdir(parents=True, exist_ok=True)

    data = fetch_feed()
    # Fail closed if OFAC returns an HTML/error payload instead of XML.
    extract_publish_date(data)

    current_hash = sha256(data)
    previous = load_state(state_path)
    changed = previous.get("sha256") != current_hash
    checked_at = datetime.now(timezone.utc).isoformat()

    new_state = {
        "source": "U.S. Treasury / OFAC Sanctions List Service",
        "dataset": "Specially Designated Nationals (SDN) — Advanced XML",
        "source_url": SOURCE_URL,
        "sha256": current_hash,
        "published_date": extract_publish_date(data),
        "checked_at_utc": checked_at,
        "changed_since_last_check": changed,
    }

    state_path.write_text(json.dumps(new_state, indent=2) + "\n", encoding="utf-8")

    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a", encoding="utf-8") as fh:
            fh.write(f"changed={'true' if changed else 'false'}\n")
            fh.write(f"sha256={current_hash}\n")
            fh.write(f"published_date={new_state['published_date'] or ''}\n")

    print(json.dumps(new_state, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
