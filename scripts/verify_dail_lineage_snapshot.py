#!/usr/bin/env python3
"""Verify a payload-free CHLOM DAIL lineage snapshot in isolation."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


HASH_LENGTH = 64
TOP_LEVEL_KEYS = {
    "format",
    "classification",
    "restore_scope",
    "payloads_included",
    "actor_identifiers_included",
    "entity_identifiers_included",
    "source",
    "events",
    "corrections",
    "limitations",
}
SOURCE_KEYS = {
    "project_ref",
    "captured_at",
    "event_count",
    "min_sequence_id",
    "max_sequence_id",
    "head_event_hash",
    "head_created_at",
    "payload_bytes_not_exported",
    "integrity_state",
    "verifier_failure_count",
    "documented_correction_count",
}
EVENT_KEYS = {
    "sequence_id",
    "previous_event_hash",
    "event_hash",
    "payload_sha256",
    "created_at",
}
CORRECTION_KEYS = {
    "sequence_id",
    "original_event_hash",
    "expected_event_hash",
    "payload_sha256",
    "previous_event_hash",
    "correction_state",
    "defect_class",
    "created_at",
}


class SnapshotError(ValueError):
    """Raised when a lineage snapshot fails a required invariant."""


def _object_without_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise SnapshotError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _require_exact_keys(value: dict[str, Any], expected: set[str], label: str) -> None:
    if set(value) != expected:
        missing = sorted(expected - set(value))
        extra = sorted(set(value) - expected)
        raise SnapshotError(f"{label} keys differ; missing={missing}, extra={extra}")


def _require_hash(value: Any, label: str, *, nullable: bool = False) -> str | None:
    if nullable and value is None:
        return None
    if (
        not isinstance(value, str)
        or len(value) != HASH_LENGTH
        or any(character not in "0123456789abcdef" for character in value)
    ):
        raise SnapshotError(f"{label} is not a lowercase SHA-256 value")
    return value


def _require_integer(
    value: Any,
    label: str,
    *,
    minimum: int = 0,
) -> int:
    if type(value) is not int or value < minimum:
        raise SnapshotError(f"{label} must be an integer greater than or equal to {minimum}")
    return value


def _parse_timestamp(value: Any, label: str) -> datetime:
    if not isinstance(value, str) or not value.strip():
        raise SnapshotError(f"{label} must be a non-empty RFC 3339 timestamp")
    candidate = value.strip()
    if candidate.endswith("Z"):
        candidate = candidate[:-1] + "+00:00"
    try:
        parsed = datetime.fromisoformat(candidate)
    except ValueError as error:
        raise SnapshotError(f"{label} is not a valid RFC 3339 timestamp") from error
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise SnapshotError(f"{label} must include a UTC offset")
    return parsed.astimezone(timezone.utc)


def _reject_json_constant(value: str) -> None:
    raise SnapshotError(f"non-standard JSON constant: {value}")


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def verify_snapshot(path: Path, expected_sha256: str) -> dict[str, Any]:
    expected_hash = _require_hash(expected_sha256, "external snapshot anchor")
    try:
        actual_sha256 = _sha256(path)
    except OSError as error:
        raise SnapshotError(f"cannot read snapshot: {error}") from error
    if actual_sha256 != expected_hash:
        raise SnapshotError("snapshot SHA-256 does not match the external anchor")

    try:
        document = json.loads(
            path.read_text(encoding="utf-8"),
            object_pairs_hook=_object_without_duplicates,
            parse_constant=_reject_json_constant,
        )
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise SnapshotError(f"snapshot is not valid UTF-8 JSON: {error}") from error
    if not isinstance(document, dict):
        raise SnapshotError("snapshot root must be an object")
    _require_exact_keys(document, TOP_LEVEL_KEYS, "snapshot")

    if document["format"] != "ct.chlom.dail-lineage-snapshot.v1":
        raise SnapshotError("unsupported snapshot format")
    if document["classification"] != "private_integrity_metadata":
        raise SnapshotError("snapshot classification is not private integrity metadata")
    if document["restore_scope"] != "ledger_lineage":
        raise SnapshotError("snapshot does not declare ledger-lineage scope")
    for field in (
        "payloads_included",
        "actor_identifiers_included",
        "entity_identifiers_included",
    ):
        if document[field] is not False:
            raise SnapshotError(f"{field} must be false")

    source = document["source"]
    if not isinstance(source, dict):
        raise SnapshotError("source must be an object")
    _require_exact_keys(source, SOURCE_KEYS, "source")
    if (
        not isinstance(source["project_ref"], str)
        or not source["project_ref"].strip()
        or len(source["project_ref"].strip()) > 128
    ):
        raise SnapshotError("source project_ref is invalid")
    captured_at = _parse_timestamp(source["captured_at"], "source captured_at")
    head_created_at = _parse_timestamp(
        source["head_created_at"], "source head_created_at"
    )
    if captured_at < head_created_at:
        raise SnapshotError("source capture predates its head event")
    head_hash = _require_hash(source["head_event_hash"], "source head")
    event_count = _require_integer(source["event_count"], "source event_count", minimum=1)
    min_sequence_id = _require_integer(
        source["min_sequence_id"], "source min_sequence_id", minimum=1
    )
    max_sequence_id = _require_integer(
        source["max_sequence_id"], "source max_sequence_id", minimum=1
    )
    if max_sequence_id < min_sequence_id:
        raise SnapshotError("source sequence boundary is inverted")
    if event_count > max_sequence_id - min_sequence_id + 1:
        raise SnapshotError("source event_count exceeds its sequence boundary")
    _require_integer(
        source["payload_bytes_not_exported"],
        "source payload_bytes_not_exported",
    )
    verifier_failure_count = _require_integer(
        source["verifier_failure_count"], "source verifier_failure_count"
    )
    documented_correction_count = _require_integer(
        source["documented_correction_count"],
        "source documented_correction_count",
    )
    if verifier_failure_count != 0:
        raise SnapshotError("source verifier recorded failures")
    if source["integrity_state"] not in {
        "pass",
        "pass_with_documented_legacy_correction",
    }:
        raise SnapshotError("source integrity state is not passing")

    events = document["events"]
    if not isinstance(events, list) or len(events) != event_count:
        raise SnapshotError("event rows do not match source event_count")
    previous_hash: str | None = None
    previous_sequence = 0
    seen_sequences: set[int] = set()
    event_by_sequence: dict[int, dict[str, Any]] = {}
    event_time_by_sequence: dict[int, datetime] = {}
    for index, event in enumerate(events):
        if not isinstance(event, dict):
            raise SnapshotError(f"events[{index}] must be an object")
        _require_exact_keys(event, EVENT_KEYS, f"events[{index}]")
        sequence_id = _require_integer(
            event["sequence_id"], f"events[{index}] sequence_id", minimum=1
        )
        if sequence_id <= previous_sequence or sequence_id in seen_sequences:
            raise SnapshotError(f"events[{index}] has invalid sequence order")
        if event["previous_event_hash"] != previous_hash:
            raise SnapshotError(f"sequence {sequence_id} breaks physical chain linkage")
        _require_hash(event["payload_sha256"], f"sequence {sequence_id} payload hash")
        event_hash = _require_hash(event["event_hash"], f"sequence {sequence_id} event hash")
        event_created_at = _parse_timestamp(
            event["created_at"], f"sequence {sequence_id} created_at"
        )
        if event_created_at > captured_at:
            raise SnapshotError(f"sequence {sequence_id} postdates the source capture")
        seen_sequences.add(sequence_id)
        event_by_sequence[sequence_id] = event
        event_time_by_sequence[sequence_id] = event_created_at
        previous_sequence = sequence_id
        previous_hash = event_hash

    if events[0]["sequence_id"] != min_sequence_id:
        raise SnapshotError("minimum sequence does not match source boundary")
    if events[-1]["sequence_id"] != max_sequence_id:
        raise SnapshotError("maximum sequence does not match source boundary")
    if previous_hash != head_hash:
        raise SnapshotError("restored lineage head does not match source head")
    if event_time_by_sequence[max_sequence_id] != head_created_at:
        raise SnapshotError("head event timestamp does not match source boundary")

    corrections = document["corrections"]
    if not isinstance(corrections, list):
        raise SnapshotError("corrections must be an array")
    accepted_corrections = 0
    active_documented_corrections = 0
    seen_correction_sequences: set[int] = set()
    for index, correction in enumerate(corrections):
        if not isinstance(correction, dict):
            raise SnapshotError(f"corrections[{index}] must be an object")
        _require_exact_keys(correction, CORRECTION_KEYS, f"corrections[{index}]")
        sequence_id = _require_integer(
            correction["sequence_id"],
            f"correction {index} sequence_id",
            minimum=1,
        )
        if sequence_id in seen_correction_sequences:
            raise SnapshotError(f"correction {index} repeats a corrected sequence")
        event = event_by_sequence.get(sequence_id)
        if event is None:
            raise SnapshotError(f"correction {index} targets a missing sequence")
        for key in (
            "original_event_hash",
            "expected_event_hash",
            "payload_sha256",
        ):
            _require_hash(correction[key], f"correction {index} {key}")
        _require_hash(
            correction["previous_event_hash"],
            f"correction {index} previous_event_hash",
            nullable=True,
        )
        # A retained correction can describe either an immutable legacy event
        # (the stored hash remains original) or a separately documented physical
        # repair (the stored hash now equals the accepted expected hash).
        if event["event_hash"] not in {
            correction["original_event_hash"],
            correction["expected_event_hash"],
        }:
            raise SnapshotError(
                f"correction {index} original/expected hash does not match event"
            )
        if correction["payload_sha256"] != event["payload_sha256"]:
            raise SnapshotError(f"correction {index} payload hash does not match event")
        if correction["previous_event_hash"] != event["previous_event_hash"]:
            raise SnapshotError(f"correction {index} previous hash does not match event")
        if correction["correction_state"] != "accepted":
            raise SnapshotError(f"correction {index} is not accepted")
        if (
            not isinstance(correction["defect_class"], str)
            or not correction["defect_class"].strip()
        ):
            raise SnapshotError(f"correction {index} has no defect class")
        correction_created_at = _parse_timestamp(
            correction["created_at"], f"correction {index} created_at"
        )
        if correction_created_at < event_time_by_sequence[sequence_id]:
            raise SnapshotError(f"correction {index} predates its event")
        if correction_created_at > captured_at:
            raise SnapshotError(f"correction {index} postdates the source capture")
        if correction["original_event_hash"] == correction["expected_event_hash"]:
            raise SnapshotError(f"correction {index} does not change the expected hash")
        accepted_corrections += 1
        if event["event_hash"] == correction["original_event_hash"]:
            active_documented_corrections += 1
        seen_correction_sequences.add(sequence_id)

    if active_documented_corrections != documented_correction_count:
        raise SnapshotError(
            "active correction rows do not match source documented_correction_count"
        )
    if source["integrity_state"] == "pass" and active_documented_corrections != 0:
        raise SnapshotError("passing source has an active documented correction")
    if (
        source["integrity_state"] == "pass_with_documented_legacy_correction"
        and active_documented_corrections == 0
    ):
        raise SnapshotError("corrected source has no active documented correction")

    limitations = document["limitations"]
    if (
        not isinstance(limitations, list)
        or not limitations
        or any(not isinstance(item, str) or not item.strip() for item in limitations)
    ):
        raise SnapshotError("limitations must be a non-empty string array")

    return {
        "ok": True,
        "scope": "ledger_lineage",
        "snapshot_sha256": actual_sha256,
        "event_count": event_count,
        "min_sequence_id": events[0]["sequence_id"],
        "max_sequence_id": events[-1]["sequence_id"],
        "head_event_hash": head_hash,
        "correction_rows": len(corrections),
        "accepted_correction_rows": accepted_corrections,
        "active_documented_correction_rows": active_documented_corrections,
        "payloads_restored": False,
        "full_data_restore": False,
        "institutional_phase4_activation": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("snapshot", type=Path)
    parser.add_argument("--expected-sha256", required=True)
    parser.add_argument("--materialize", type=Path)
    arguments = parser.parse_args()

    try:
        receipt = verify_snapshot(arguments.snapshot, arguments.expected_sha256)
        if arguments.materialize is not None:
            if arguments.materialize.exists():
                raise SnapshotError("isolated restore destination already exists")
            try:
                arguments.materialize.mkdir(mode=0o700, parents=False)
                restored_snapshot = arguments.materialize / arguments.snapshot.name
                shutil.copy2(arguments.snapshot, restored_snapshot)
                restored_snapshot.chmod(0o600)
                receipt["restore_directory"] = str(arguments.materialize.resolve())
                receipt_path = arguments.materialize / "RESTORE_VERIFICATION.json"
                receipt_path.write_text(
                    json.dumps(receipt, separators=(",", ":"), sort_keys=True) + "\n",
                    encoding="utf-8",
                )
                receipt_path.chmod(0o600)
            except OSError as error:
                raise SnapshotError(
                    f"cannot materialize isolated recovery: {error}"
                ) from error
        print(json.dumps(receipt, sort_keys=True))
        return 0
    except SnapshotError as error:
        print(json.dumps({"ok": False, "error": str(error)}, sort_keys=True))
        return 1


if __name__ == "__main__":
    sys.exit(main())
