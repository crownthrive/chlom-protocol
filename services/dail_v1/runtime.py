"""Portable, standard-library-only runtime for the production DAIL v1 chain.

The event-hash contract matches the deployed DAIL schema 1.1.0 contract. The
runtime also provides append idempotency, append-only correction records,
complete verification, sanitized cold exports, and isolated restore checks.
Hashes establish technical integrity, not legal ownership or authority.
"""

from __future__ import annotations

import copy
import hashlib
import json
import math
import os
import re
import threading
import uuid
from dataclasses import dataclass, replace
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence


SCHEMA_VERSION = "1.1.0"
COLD_EXPORT_FORMAT = "chlom.dail.cold-export"
CORRECTION_EVENT_TYPE = "dail.correction.v1"
GENESIS_MARKER = "GENESIS"
ZERO_HASH = "0" * 64

_HASH_PATTERN = re.compile(r"^[0-9a-f]{64}$")
_EVENT_KEYS = frozenset(
    {
        "schema_version", "sequence", "event_id", "event_type",
        "entity_type", "entity_id", "entity_version", "actor_did",
        "actor_ref", "payload", "payload_jsonb_text", "payload_sha256",
        "idempotency_key", "request_sha256", "previous_event_hash",
        "event_hash", "occurred_at",
    }
)
_EXPORT_KEYS = frozenset(
    {"format", "schema_version", "created_at", "integrity", "receipts", "receipts_sha256"}
)
_INTEGRITY_KEYS = frozenset(
    {"source_verification", "event_count", "first_sequence", "last_sequence", "head_hash", "receipt_head_hash"}
)
_RECEIPT_KEYS = frozenset(
    {
        "sequence", "event_id_sha256", "event_type_sha256",
        "entity_ref_sha256", "occurred_at", "payload_sha256",
        "previous_event_hash", "event_hash", "previous_receipt_hash",
        "receipt_hash",
    }
)


class DAILRuntimeError(Exception):
    """Base exception for portable DAIL runtime failures."""


class InvalidEvent(DAILRuntimeError, ValueError):
    """An append request or serialized event violates the DAIL contract."""


class IdempotencyConflict(DAILRuntimeError):
    """An idempotency key was reused for a different logical request."""


class ReplayDetected(DAILRuntimeError):
    """An event identifier was submitted more than once."""


class RestoreVerificationError(DAILRuntimeError):
    """An isolated restore did not match its integrity anchors."""

    def __init__(self, errors: Sequence[str]):
        self.errors = tuple(errors)
        super().__init__("; ".join(self.errors))


@dataclass(frozen=True)
class VerificationReport:
    ok: bool
    event_count: int
    head_hash: str
    errors: tuple[str, ...]

    def as_dict(self) -> dict[str, Any]:
        return {
            "ok": self.ok,
            "event_count": self.event_count,
            "head_hash": self.head_hash,
            "errors": list(self.errors),
        }


@dataclass(frozen=True)
class ColdExport:
    """Canonical sanitized document plus its out-of-band SHA-256 anchor."""

    canonical_json: str
    export_sha256: str

    def as_dict(self) -> dict[str, Any]:
        return _load_json_no_duplicates(self.canonical_json)


@dataclass(frozen=True)
class ColdRestoreReport:
    ok: bool
    event_count: int
    head_hash: str
    receipt_head_hash: str
    export_sha256: str
    restore_directory: str | None = None

    def as_dict(self) -> dict[str, Any]:
        return {
            "ok": self.ok,
            "event_count": self.event_count,
            "head_hash": self.head_hash,
            "receipt_head_hash": self.receipt_head_hash,
            "export_sha256": self.export_sha256,
            "restore_directory": self.restore_directory,
        }


def _validate_json_value(value: Any, path: str = "value") -> None:
    if value is None or isinstance(value, (str, bool)):
        return
    if isinstance(value, int) and not isinstance(value, bool):
        return
    if isinstance(value, float):
        if not math.isfinite(value):
            raise InvalidEvent(f"{path} contains a non-finite number")
        return
    if isinstance(value, list):
        for index, item in enumerate(value):
            _validate_json_value(item, f"{path}[{index}]")
        return
    if isinstance(value, dict):
        for key, item in value.items():
            if not isinstance(key, str):
                raise InvalidEvent(f"{path} contains a non-string object key")
            _validate_json_value(item, f"{path}.{key}")
        return
    raise InvalidEvent(f"{path} contains unsupported type {type(value).__name__}")


def _canonical_json(value: Any) -> str:
    _validate_json_value(value)
    return json.dumps(
        value, allow_nan=False, ensure_ascii=False,
        separators=(",", ":"), sort_keys=True,
    )


def _sha256_text(value: str) -> str:
    try:
        encoded = value.encode("utf-8")
    except UnicodeEncodeError as exc:
        raise InvalidEvent("text is not valid UTF-8") from exc
    return hashlib.sha256(encoded).hexdigest()


def _hash_json(value: Any) -> str:
    return _sha256_text(_canonical_json(value))


def _json_clone(value: Any) -> Any:
    return json.loads(_canonical_json(value))


def _reject_json_constant(value: str) -> None:
    raise ValueError(f"non-standard JSON constant: {value}")


def _load_json_no_duplicates(value: str) -> Any:
    def reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, item in pairs:
            if key in result:
                raise RestoreVerificationError((f"duplicate JSON key: {key}",))
            result[key] = item
        return result

    try:
        return json.loads(
            value,
            object_pairs_hook=reject_duplicate_keys,
            parse_constant=_reject_json_constant,
        )
    except RestoreVerificationError:
        raise
    except (TypeError, ValueError, json.JSONDecodeError) as exc:
        raise RestoreVerificationError((f"invalid JSON: {exc}",)) from exc


def _normalize_text(value: Any, field: str, *, maximum: int = 512) -> str:
    if not isinstance(value, str):
        raise InvalidEvent(f"{field} must be a string")
    normalized = value.strip()
    if not normalized:
        raise InvalidEvent(f"{field} must not be empty")
    if len(normalized) > maximum:
        raise InvalidEvent(f"{field} exceeds {maximum} characters")
    return normalized


def _normalize_optional_text(value: Any, field: str, *, maximum: int = 512) -> str | None:
    if value is None:
        return None
    return _normalize_text(value, field, maximum=maximum)


def _normalize_hash_field(value: Any, field: str, *, maximum: int = 512) -> str:
    normalized = _normalize_text(value, field, maximum=maximum)
    if "|" in normalized:
        raise InvalidEvent(
            f"{field} must not contain the production hash delimiter '|'"
        )
    return normalized


def _normalize_optional_hash_field(
    value: Any,
    field: str,
    *,
    maximum: int = 512,
) -> str | None:
    if value is None:
        return None
    return _normalize_hash_field(value, field, maximum=maximum)


def _normalize_timestamp(value: str | datetime | None) -> str:
    if value is None:
        parsed = datetime.now(timezone.utc)
    elif isinstance(value, datetime):
        parsed = value
    elif isinstance(value, str):
        candidate = value.strip()
        if candidate.endswith("Z"):
            candidate = candidate[:-1] + "+00:00"
        try:
            parsed = datetime.fromisoformat(candidate)
        except ValueError as exc:
            raise InvalidEvent("timestamp must be valid RFC 3339") from exc
    else:
        raise InvalidEvent("timestamp must be a string, datetime, or None")
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise InvalidEvent("timestamp must include a UTC offset")
    return (
        parsed.astimezone(timezone.utc)
        .isoformat(timespec="microseconds")
        .replace("+00:00", "Z")
    )


def _require_hash(value: Any, field: str, *, restore: bool = False) -> str:
    if not isinstance(value, str) or _HASH_PATTERN.fullmatch(value) is None:
        message = f"{field} must be a lowercase SHA-256 hash"
        if restore:
            raise RestoreVerificationError((message,))
        raise InvalidEvent(message)
    return value


def _jsonb_key_order(key: str) -> tuple[int, bytes]:
    encoded = key.encode("utf-8")
    return len(encoded), encoded


def _jsonb_order(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: _jsonb_order(value[key]) for key in sorted(value, key=_jsonb_key_order)}
    if isinstance(value, list):
        return [_jsonb_order(item) for item in value]
    if isinstance(value, float):
        raise InvalidEvent(
            "portable JSONB rendering does not infer numeric scale; provide "
            "payload_jsonb_text read from PostgreSQL"
        )
    return value


def postgres_jsonb_text(payload: Mapping[str, Any]) -> str:
    """Render integer-only JSON like PostgreSQL ``jsonb::text``.

    PostgreSQL numeric formatting carries scale information that a Python float
    does not. Payloads containing floats must supply exact database text to
    :meth:`DAILLedger.append`. Keys use PostgreSQL's length-then-byte order.
    """

    if not isinstance(payload, Mapping):
        raise InvalidEvent("payload must be a JSON object")
    ordered = _jsonb_order(_json_clone(dict(payload)))
    return json.dumps(
        ordered, allow_nan=False, ensure_ascii=False, separators=(", ", ": ")
    )


def payload_sha256_from_jsonb_text(payload_jsonb_text: str) -> str:
    """Hash the exact UTF-8 bytes returned by PostgreSQL ``jsonb::text``."""

    if not isinstance(payload_jsonb_text, str):
        raise InvalidEvent("payload_jsonb_text must be a string")
    try:
        _load_json_no_duplicates(payload_jsonb_text)
    except RestoreVerificationError as exc:
        raise InvalidEvent(str(exc)) from exc
    return _sha256_text(payload_jsonb_text)


def production_event_hash(
    *,
    previous_event_hash: str | None,
    event_id: str,
    schema_version: str,
    event_type: str,
    entity_type: str,
    entity_id: str,
    entity_version: str | None,
    actor_did: str | None,
    actor_ref: str | None,
    payload_sha256: str,
    occurred_at: str | datetime,
) -> str:
    """Return the deployed DAIL v1.1.0 pipe-delimited event hash."""

    previous = (
        GENESIS_MARKER
        if previous_event_hash is None
        else _require_hash(previous_event_hash, "previous_event_hash")
    )
    fields = (
        previous,
        _normalize_hash_field(event_id, "event_id", maximum=128),
        _normalize_hash_field(schema_version, "schema_version", maximum=32),
        _normalize_hash_field(event_type, "event_type", maximum=128),
        _normalize_hash_field(entity_type, "entity_type", maximum=128),
        _normalize_hash_field(entity_id, "entity_id", maximum=512),
        _normalize_optional_hash_field(
            entity_version, "entity_version", maximum=128
        ) or "",
        _normalize_optional_hash_field(actor_did, "actor_did", maximum=512)
        or _normalize_optional_hash_field(actor_ref, "actor_ref", maximum=512)
        or "",
        _require_hash(payload_sha256, "payload_sha256"),
        _normalize_timestamp(occurred_at),
    )
    return _sha256_text("|".join(fields))


def _request_hash(
    *,
    event_type: str,
    entity_type: str,
    entity_id: str,
    entity_version: str | None,
    actor_did: str | None,
    actor_ref: str | None,
    payload_sha256: str,
) -> str:
    return _hash_json(
        {
            "event_type": event_type,
            "entity_type": entity_type,
            "entity_id": entity_id,
            "entity_version": entity_version,
            "actor_did": actor_did,
            "actor_ref": actor_ref,
            "payload_sha256": payload_sha256,
        }
    )


class DAILLedger:
    """Storage-neutral implementation of the deployed DAIL chain contract."""

    def __init__(self) -> None:
        self._events: list[dict[str, Any]] = []
        self._idempotency: dict[str, tuple[str, int]] = {}
        self._event_ids: set[str] = set()
        self._lock = threading.RLock()

    @property
    def events(self) -> list[dict[str, Any]]:
        with self._lock:
            return copy.deepcopy(self._events)

    @property
    def head_hash(self) -> str:
        with self._lock:
            return self._events[-1]["event_hash"] if self._events else ZERO_HASH

    @property
    def full_state_sha256(self) -> str:
        """Out-of-band digest covering every serialized event field.

        The production chain head intentionally follows the deployed v1.1.0
        formula and therefore does not bind operational metadata such as the
        idempotency key. A complete event-row restore must verify this separate
        digest as well as the chain head.
        """

        with self._lock:
            return _hash_json(self._events)

    def append(
        self,
        *,
        event_type: str,
        entity_type: str,
        entity_id: str,
        payload: Mapping[str, Any],
        idempotency_key: str,
        entity_version: str | None = None,
        actor_did: str | None = None,
        actor_ref: str | None = None,
        event_id: str | None = None,
        occurred_at: str | datetime | None = None,
        payload_jsonb_text: str | None = None,
    ) -> dict[str, Any]:
        return self._append(
            event_type=event_type,
            entity_type=entity_type,
            entity_id=entity_id,
            entity_version=entity_version,
            payload=payload,
            actor_did=actor_did,
            actor_ref=actor_ref,
            idempotency_key=idempotency_key,
            event_id=event_id,
            occurred_at=occurred_at,
            payload_jsonb_text=payload_jsonb_text,
            allow_reserved_event_type=False,
        )

    def append_correction(
        self,
        *,
        target_event_id: str,
        reason: str,
        replacement_payload: Mapping[str, Any],
        idempotency_key: str,
        actor_did: str | None = None,
        actor_ref: str | None = None,
        event_id: str | None = None,
        occurred_at: str | datetime | None = None,
        payload_jsonb_text: str | None = None,
    ) -> dict[str, Any]:
        target_id = _normalize_text(target_event_id, "target_event_id", maximum=128)
        correction_reason = _normalize_text(reason, "reason", maximum=2048)
        if actor_did is None and actor_ref is None:
            raise InvalidEvent("a correction requires actor_did or actor_ref")
        with self._lock:
            target = next(
                (event for event in self._events if event["event_id"] == target_id), None
            )
            if target is None:
                raise InvalidEvent("correction target must identify an earlier event")
            return self._append(
                event_type=CORRECTION_EVENT_TYPE,
                entity_type=target["entity_type"],
                entity_id=target["entity_id"],
                entity_version=target["entity_version"],
                payload={
                    "target_event_id": target_id,
                    "reason": correction_reason,
                    "replacement_payload": replacement_payload,
                },
                actor_did=actor_did,
                actor_ref=actor_ref,
                idempotency_key=idempotency_key,
                event_id=event_id,
                occurred_at=occurred_at,
                payload_jsonb_text=payload_jsonb_text,
                allow_reserved_event_type=True,
            )

    def _append(
        self,
        *,
        event_type: str,
        entity_type: str,
        entity_id: str,
        entity_version: str | None,
        payload: Mapping[str, Any],
        actor_did: str | None,
        actor_ref: str | None,
        idempotency_key: str,
        event_id: str | None,
        occurred_at: str | datetime | None,
        payload_jsonb_text: str | None,
        allow_reserved_event_type: bool,
    ) -> dict[str, Any]:
        event_type_value = _normalize_text(event_type, "event_type", maximum=128)
        if event_type_value == CORRECTION_EVENT_TYPE and not allow_reserved_event_type:
            raise InvalidEvent("use append_correction for correction events")
        entity_type_value = _normalize_text(entity_type, "entity_type", maximum=128)
        entity_id_value = _normalize_text(entity_id, "entity_id", maximum=512)
        entity_version_value = _normalize_optional_text(
            entity_version, "entity_version", maximum=128
        )
        actor_did_value = _normalize_optional_text(actor_did, "actor_did", maximum=512)
        actor_ref_value = _normalize_optional_text(actor_ref, "actor_ref", maximum=512)
        key_value = _normalize_text(idempotency_key, "idempotency_key", maximum=256)
        if not isinstance(payload, Mapping):
            raise InvalidEvent("payload must be a JSON object")
        payload_value = _json_clone(dict(payload))
        jsonb_text = (
            postgres_jsonb_text(payload_value)
            if payload_jsonb_text is None
            else payload_jsonb_text
        )
        payload_hash = payload_sha256_from_jsonb_text(jsonb_text)
        try:
            parsed_jsonb = _load_json_no_duplicates(jsonb_text)
        except RestoreVerificationError as exc:
            raise InvalidEvent(str(exc)) from exc
        if _canonical_json(parsed_jsonb) != _canonical_json(payload_value):
            raise InvalidEvent("payload_jsonb_text does not represent payload")
        request_sha256 = _request_hash(
            event_type=event_type_value,
            entity_type=entity_type_value,
            entity_id=entity_id_value,
            entity_version=entity_version_value,
            actor_did=actor_did_value,
            actor_ref=actor_ref_value,
            payload_sha256=payload_hash,
        )

        with self._lock:
            prior = self._idempotency.get(key_value)
            if prior is not None:
                prior_request_hash, sequence = prior
                if prior_request_hash != request_sha256:
                    raise IdempotencyConflict(
                        "idempotency key is already bound to a different request"
                    )
                return copy.deepcopy(self._events[sequence - 1])
            event_id_value = (
                _normalize_text(event_id, "event_id", maximum=128)
                if event_id is not None else str(uuid.uuid4())
            )
            if event_id_value in self._event_ids:
                raise ReplayDetected(f"event_id already exists: {event_id_value}")
            occurred_at_value = _normalize_timestamp(occurred_at)
            previous_hash = self._events[-1]["event_hash"] if self._events else None
            event_hash = production_event_hash(
                previous_event_hash=previous_hash,
                event_id=event_id_value,
                schema_version=SCHEMA_VERSION,
                event_type=event_type_value,
                entity_type=entity_type_value,
                entity_id=entity_id_value,
                entity_version=entity_version_value,
                actor_did=actor_did_value,
                actor_ref=actor_ref_value,
                payload_sha256=payload_hash,
                occurred_at=occurred_at_value,
            )
            event = {
                "schema_version": SCHEMA_VERSION,
                "sequence": len(self._events) + 1,
                "event_id": event_id_value,
                "event_type": event_type_value,
                "entity_type": entity_type_value,
                "entity_id": entity_id_value,
                "entity_version": entity_version_value,
                "actor_did": actor_did_value,
                "actor_ref": actor_ref_value,
                "payload": payload_value,
                "payload_jsonb_text": jsonb_text,
                "payload_sha256": payload_hash,
                "idempotency_key": key_value,
                "request_sha256": request_sha256,
                "previous_event_hash": previous_hash,
                "event_hash": event_hash,
                "occurred_at": occurred_at_value,
            }
            self._events.append(event)
            self._event_ids.add(event_id_value)
            self._idempotency[key_value] = (request_sha256, event["sequence"])
            return copy.deepcopy(event)

    def verify(self) -> VerificationReport:
        """Recompute payload, event, link, replay, and correction invariants."""

        with self._lock:
            events = copy.deepcopy(self._events)
        errors: list[str] = []
        expected_previous_hash: str | None = None
        event_ids: set[str] = set()
        idempotency_keys: set[str] = set()
        for position, event in enumerate(events, start=1):
            prefix = f"event[{position}]"
            if not isinstance(event, dict):
                errors.append(f"{prefix} must be an object")
                continue
            if set(event) != _EVENT_KEYS:
                missing = sorted(_EVENT_KEYS - set(event))
                extra = sorted(set(event) - _EVENT_KEYS)
                errors.append(f"{prefix} has invalid fields (missing={missing}, extra={extra})")
                continue
            try:
                _validate_json_value(event, prefix)
                if event["schema_version"] != SCHEMA_VERSION:
                    errors.append(f"{prefix} has unsupported schema_version")
                if type(event["sequence"]) is not int or event["sequence"] != position:
                    errors.append(f"{prefix} sequence is not contiguous")
                event_id = _normalize_text(event["event_id"], "event_id", maximum=128)
                if event_id in event_ids:
                    errors.append(f"{prefix} replays event_id {event_id}")
                event_type = _normalize_text(event["event_type"], "event_type", maximum=128)
                entity_type = _normalize_text(event["entity_type"], "entity_type", maximum=128)
                entity_id = _normalize_text(event["entity_id"], "entity_id", maximum=512)
                entity_version = _normalize_optional_text(
                    event["entity_version"], "entity_version", maximum=128
                )
                actor_did = _normalize_optional_text(event["actor_did"], "actor_did", maximum=512)
                actor_ref = _normalize_optional_text(event["actor_ref"], "actor_ref", maximum=512)
                key = _normalize_text(event["idempotency_key"], "idempotency_key", maximum=256)
                if key in idempotency_keys:
                    errors.append(f"{prefix} reuses idempotency_key {key}")
                if not isinstance(event["payload"], dict):
                    errors.append(f"{prefix} payload must be an object")
                parsed_jsonb = _load_json_no_duplicates(event["payload_jsonb_text"])
                if _canonical_json(parsed_jsonb) != _canonical_json(event["payload"]):
                    errors.append(f"{prefix} payload_jsonb_text does not represent payload")
                payload_hash = payload_sha256_from_jsonb_text(event["payload_jsonb_text"])
                if event["payload_sha256"] != payload_hash:
                    errors.append(f"{prefix} payload_sha256 mismatch")
                expected_request_hash = _request_hash(
                    event_type=event_type,
                    entity_type=entity_type,
                    entity_id=entity_id,
                    entity_version=entity_version,
                    actor_did=actor_did,
                    actor_ref=actor_ref,
                    payload_sha256=payload_hash,
                )
                if event["request_sha256"] != expected_request_hash:
                    errors.append(f"{prefix} request_sha256 mismatch")
                if event["occurred_at"] != _normalize_timestamp(event["occurred_at"]):
                    errors.append(f"{prefix} occurred_at is not canonical UTC")
                if event["previous_event_hash"] != expected_previous_hash:
                    errors.append(f"{prefix} previous_event_hash mismatch")
                expected_hash = production_event_hash(
                    previous_event_hash=event["previous_event_hash"],
                    event_id=event_id,
                    schema_version=event["schema_version"],
                    event_type=event_type,
                    entity_type=entity_type,
                    entity_id=entity_id,
                    entity_version=entity_version,
                    actor_did=actor_did,
                    actor_ref=actor_ref,
                    payload_sha256=event["payload_sha256"],
                    occurred_at=event["occurred_at"],
                )
                if event["event_hash"] != expected_hash:
                    errors.append(f"{prefix} event_hash mismatch")
                if event_type == CORRECTION_EVENT_TYPE:
                    self._verify_correction(event["payload"], event_ids, prefix, errors)
                event_ids.add(event_id)
                idempotency_keys.add(key)
                expected_previous_hash = event["event_hash"]
            except (DAILRuntimeError, TypeError, KeyError) as exc:
                errors.append(f"{prefix} is invalid: {exc}")
        return VerificationReport(
            ok=not errors,
            event_count=len(events),
            head_hash=expected_previous_hash or ZERO_HASH,
            errors=tuple(errors),
        )

    @staticmethod
    def _verify_correction(
        payload: Any,
        earlier_event_ids: set[str],
        prefix: str,
        errors: list[str],
    ) -> None:
        required = {"target_event_id", "reason", "replacement_payload"}
        if not isinstance(payload, dict) or set(payload) != required:
            errors.append(f"{prefix} correction payload has invalid fields")
            return
        if payload.get("target_event_id") not in earlier_event_ids:
            errors.append(f"{prefix} correction target is not an earlier event")
        if not isinstance(payload.get("reason"), str) or not payload["reason"].strip():
            errors.append(f"{prefix} correction reason is empty")
        if not isinstance(payload.get("replacement_payload"), dict):
            errors.append(f"{prefix} correction replacement_payload must be an object")

    @classmethod
    def restore_isolated(
        cls,
        events: Sequence[Mapping[str, Any]],
        *,
        expected_head_hash: str,
        expected_full_state_sha256: str,
    ) -> "DAILLedger":
        if not isinstance(events, Sequence) or isinstance(events, (str, bytes)):
            raise RestoreVerificationError(("events must be a sequence",))
        restored = cls()
        restored._events = copy.deepcopy(list(events))
        report = restored.verify()
        errors = list(report.errors)
        try:
            anchored_head = _require_hash(expected_head_hash, "expected_head_hash", restore=True)
        except RestoreVerificationError as exc:
            errors.extend(exc.errors)
            anchored_head = ""
        if anchored_head and report.head_hash != anchored_head:
            errors.append("restored head_hash does not match expected_head_hash")
        try:
            anchored_state = _require_hash(
                expected_full_state_sha256,
                "expected_full_state_sha256",
                restore=True,
            )
        except RestoreVerificationError as exc:
            errors.extend(exc.errors)
            anchored_state = ""
        try:
            restored_state = _hash_json(restored._events)
        except InvalidEvent as exc:
            errors.append(f"restored full state is invalid: {exc}")
            restored_state = ""
        if anchored_state and restored_state != anchored_state:
            errors.append(
                "restored full_state_sha256 does not match expected_full_state_sha256"
            )
        if errors:
            raise RestoreVerificationError(errors)
        for event in restored._events:
            restored._event_ids.add(event["event_id"])
            restored._idempotency[event["idempotency_key"]] = (
                event["request_sha256"], event["sequence"]
            )
        return restored

    def export_cold(self, *, created_at: str | datetime | None = None) -> ColdExport:
        report = self.verify()
        if not report.ok:
            raise RestoreVerificationError(report.errors)
        events = self.events
        receipts: list[dict[str, Any]] = []
        previous_receipt_hash = ZERO_HASH
        for event in events:
            entity_ref = "|".join(
                (event["entity_type"], event["entity_id"], event["entity_version"] or "")
            )
            receipt_without_hash = {
                "sequence": event["sequence"],
                "event_id_sha256": _sha256_text(event["event_id"]),
                "event_type_sha256": _sha256_text(event["event_type"]),
                "entity_ref_sha256": _sha256_text(entity_ref),
                "occurred_at": event["occurred_at"],
                "payload_sha256": event["payload_sha256"],
                "previous_event_hash": event["previous_event_hash"] or GENESIS_MARKER,
                "event_hash": event["event_hash"],
                "previous_receipt_hash": previous_receipt_hash,
            }
            receipt_hash = _hash_json(receipt_without_hash)
            receipts.append({**receipt_without_hash, "receipt_hash": receipt_hash})
            previous_receipt_hash = receipt_hash
        document = {
            "format": COLD_EXPORT_FORMAT,
            "schema_version": SCHEMA_VERSION,
            "created_at": _normalize_timestamp(created_at),
            "integrity": {
                "source_verification": "pass",
                "event_count": len(events),
                "first_sequence": 1 if events else None,
                "last_sequence": len(events) if events else None,
                "head_hash": report.head_hash,
                "receipt_head_hash": previous_receipt_hash,
            },
            "receipts": receipts,
            "receipts_sha256": _hash_json(receipts),
        }
        canonical = _canonical_json(document)
        return ColdExport(canonical_json=canonical, export_sha256=_sha256_text(canonical))


def _coerce_export_document(value: ColdExport | Mapping[str, Any] | str | bytes) -> dict[str, Any]:
    if isinstance(value, ColdExport):
        document = value.as_dict()
    elif isinstance(value, bytes):
        try:
            document = _load_json_no_duplicates(value.decode("utf-8"))
        except UnicodeDecodeError as exc:
            raise RestoreVerificationError(("cold export is not UTF-8",)) from exc
    elif isinstance(value, str):
        document = _load_json_no_duplicates(value)
    elif isinstance(value, Mapping):
        document = copy.deepcopy(dict(value))
    else:
        raise RestoreVerificationError(("cold export must be JSON or an object",))
    if not isinstance(document, dict):
        raise RestoreVerificationError(("cold export root must be an object",))
    return document


def _verify_cold_export(
    value: ColdExport | Mapping[str, Any] | str | bytes,
    *,
    expected_export_sha256: str,
    expected_head_hash: str,
) -> tuple[dict[str, Any], ColdRestoreReport]:
    document = _coerce_export_document(value)
    expected_export = _require_hash(
        expected_export_sha256, "expected_export_sha256", restore=True
    )
    expected_head = _require_hash(expected_head_hash, "expected_head_hash", restore=True)
    errors: list[str] = []
    try:
        canonical = _canonical_json(document)
    except InvalidEvent as exc:
        raise RestoreVerificationError((f"cold export is not JSON data: {exc}",)) from exc
    actual_export_hash = _sha256_text(canonical)
    if actual_export_hash != expected_export:
        errors.append("cold export SHA-256 does not match the external anchor")
    if set(document) != _EXPORT_KEYS:
        errors.append("cold export has fields outside the public allowlist")
    if document.get("format") != COLD_EXPORT_FORMAT:
        errors.append("cold export format is unsupported")
    if document.get("schema_version") != SCHEMA_VERSION:
        errors.append("cold export schema_version is unsupported")
    try:
        if document.get("created_at") != _normalize_timestamp(document.get("created_at")):
            errors.append("cold export created_at is not canonical UTC")
    except InvalidEvent as exc:
        errors.append(f"cold export created_at is invalid: {exc}")

    integrity = document.get("integrity")
    receipts = document.get("receipts")
    if not isinstance(integrity, dict) or set(integrity) != _INTEGRITY_KEYS:
        errors.append("cold export integrity block has invalid fields")
        integrity = {}
    if not isinstance(receipts, list):
        errors.append("cold export receipts must be an array")
        receipts = []
    if integrity.get("source_verification") != "pass":
        errors.append("source ledger was not verified before export")
    event_count = integrity.get("event_count")
    if type(event_count) is not int or event_count < 0:
        errors.append("integrity event_count must be a non-negative integer")
        event_count = -1
    if event_count != len(receipts):
        errors.append("receipt count does not match integrity event_count")
    if document.get("receipts_sha256") != _hash_json(receipts):
        errors.append("receipts_sha256 mismatch")

    prior_event_hash = GENESIS_MARKER
    prior_receipt_hash = ZERO_HASH
    for position, receipt in enumerate(receipts, start=1):
        prefix = f"receipt[{position}]"
        if not isinstance(receipt, dict) or set(receipt) != _RECEIPT_KEYS:
            errors.append(f"{prefix} has fields outside the public allowlist")
            continue
        if type(receipt.get("sequence")) is not int or receipt["sequence"] != position:
            errors.append(f"{prefix} sequence is not contiguous")
        for field in (
            "event_id_sha256", "event_type_sha256", "entity_ref_sha256",
            "payload_sha256", "event_hash", "previous_receipt_hash", "receipt_hash",
        ):
            if not isinstance(receipt.get(field), str) or _HASH_PATTERN.fullmatch(receipt[field]) is None:
                errors.append(f"{prefix} {field} is not a SHA-256 hash")
        previous_event_hash = receipt.get("previous_event_hash")
        if previous_event_hash != GENESIS_MARKER and (
            not isinstance(previous_event_hash, str)
            or _HASH_PATTERN.fullmatch(previous_event_hash) is None
        ):
            errors.append(f"{prefix} previous_event_hash is invalid")
        try:
            if receipt.get("occurred_at") != _normalize_timestamp(receipt.get("occurred_at")):
                errors.append(f"{prefix} occurred_at is not canonical UTC")
        except InvalidEvent as exc:
            errors.append(f"{prefix} occurred_at is invalid: {exc}")
        if previous_event_hash != prior_event_hash:
            errors.append(f"{prefix} previous_event_hash mismatch")
        if receipt.get("previous_receipt_hash") != prior_receipt_hash:
            errors.append(f"{prefix} previous_receipt_hash mismatch")
        expected_receipt_hash = _hash_json(
            {key: receipt[key] for key in receipt if key != "receipt_hash"}
        )
        if receipt.get("receipt_hash") != expected_receipt_hash:
            errors.append(f"{prefix} receipt_hash mismatch")
        if isinstance(receipt.get("event_hash"), str):
            prior_event_hash = receipt["event_hash"]
        if isinstance(receipt.get("receipt_hash"), str):
            prior_receipt_hash = receipt["receipt_hash"]

    expected_first = 1 if receipts else None
    expected_last = len(receipts) if receipts else None
    final_event_hash = prior_event_hash if receipts else ZERO_HASH
    if integrity.get("first_sequence") != expected_first:
        errors.append("integrity first_sequence mismatch")
    if integrity.get("last_sequence") != expected_last:
        errors.append("integrity last_sequence mismatch")
    if integrity.get("head_hash") != final_event_hash:
        errors.append("integrity head_hash does not match the last receipt")
    if integrity.get("head_hash") != expected_head:
        errors.append("integrity head_hash does not match the external anchor")
    if integrity.get("receipt_head_hash") != prior_receipt_hash:
        errors.append("integrity receipt_head_hash does not match the last receipt")
    if errors:
        raise RestoreVerificationError(errors)
    return document, ColdRestoreReport(
        ok=True,
        event_count=event_count,
        head_hash=final_event_hash,
        receipt_head_hash=prior_receipt_hash,
        export_sha256=actual_export_hash,
    )


def restore_cold_export_isolated(
    value: ColdExport | Mapping[str, Any] | str | bytes,
    *,
    destination: str | os.PathLike[str],
    expected_export_sha256: str,
    expected_head_hash: str,
) -> ColdRestoreReport:
    """Verify both external anchors, then write a brand-new restore folder."""

    document, report = _verify_cold_export(
        value,
        expected_export_sha256=expected_export_sha256,
        expected_head_hash=expected_head_hash,
    )
    restore_directory = Path(destination)
    try:
        restore_directory.mkdir(mode=0o700, parents=False, exist_ok=False)
    except FileExistsError as exc:
        raise RestoreVerificationError(("restore destination already exists",)) from exc
    except OSError as exc:
        raise RestoreVerificationError((f"cannot create restore destination: {exc}",)) from exc
    final_report = replace(report, restore_directory=str(restore_directory.resolve()))
    try:
        export_path = restore_directory / "dail-cold-export.json"
        report_path = restore_directory / "RESTORE_VERIFICATION.json"
        export_path.write_text(_canonical_json(document) + "\n", encoding="utf-8")
        os.chmod(export_path, 0o600)
        report_path.write_text(
            _canonical_json(final_report.as_dict()) + "\n", encoding="utf-8"
        )
        os.chmod(report_path, 0o600)
    except OSError as exc:
        raise RestoreVerificationError((f"cannot materialize isolated restore: {exc}",)) from exc
    return final_report
