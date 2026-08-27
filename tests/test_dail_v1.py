import copy
import hashlib
import json
import math
import tempfile
import unittest
from pathlib import Path

from services.dail_v1 import (
    CORRECTION_EVENT_TYPE,
    DAILLedger,
    IdempotencyConflict,
    InvalidEvent,
    ReplayDetected,
    RestoreVerificationError,
    payload_sha256_from_jsonb_text,
    postgres_jsonb_text,
    production_event_hash,
    restore_cold_export_isolated,
)


T0 = "2026-08-26T12:00:00Z"
T1 = "2026-08-26T12:01:00+00:00"


def seeded_ledger() -> DAILLedger:
    ledger = DAILLedger()
    ledger.append(
        event_type="rights.claim.received.v1",
        entity_type="work",
        entity_id="work-001",
        entity_version="1.0.0",
        payload={"work_id": "work-001", "facts": ["a", "b"]},
        actor_ref="service:intake",
        idempotency_key="request-001",
        event_id="event-001",
        occurred_at=T0,
    )
    ledger.append(
        event_type="rights.review.requested.v1",
        entity_type="work",
        entity_id="work-001",
        entity_version="1.0.0",
        payload={"work_id": "work-001", "priority": 3},
        actor_ref="service:review",
        idempotency_key="request-002",
        event_id="event-002",
        occurred_at=T1,
    )
    return ledger


class ProductionHashContractTests(unittest.TestCase):
    def test_live_schema_1_1_vector_matches_production_head(self):
        actual = production_event_hash(
            previous_event_hash=(
                "6cad0afd1de5457ff742ba13f645a7089034dbe727cacfd83decf70a0cb391f9"
            ),
            event_id="9674914a-9cd8-4750-b49b-48444584a199",
            schema_version="1.1.0",
            event_type="watchdog.dail.integrity.pass",
            entity_type="module",
            entity_id="ct.chlom.dail",
            entity_version="0.1.0",
            actor_did=None,
            actor_ref="ct.chlom.agent.dail",
            payload_sha256=(
                "aef543c13dc2e6c4c7b61612a062e0808201cc86f2309ff27a2acbe97310a8b5"
            ),
            occurred_at="2026-08-26T23:17:00.493353Z",
        )
        self.assertEqual(
            "80357ddeb6fd60734c7d32e267e371c081e952e1fdf6e77abaeed24ab39687b4",
            actual,
        )

    def test_payload_hash_uses_exact_postgres_jsonb_text_bytes(self):
        jsonb_text = '{"b": 2, "aa": 1, "nested": {"x": true}}'
        expected = hashlib.sha256(jsonb_text.encode("utf-8")).hexdigest()
        self.assertEqual(expected, payload_sha256_from_jsonb_text(jsonb_text))

    def test_portable_renderer_uses_postgres_key_order_and_spacing(self):
        self.assertEqual(
            '{"b": 2, "aa": 1, "nested": {"x": true}}',
            postgres_jsonb_text({"nested": {"x": True}, "aa": 1, "b": 2}),
        )


class DAILAppendTests(unittest.TestCase):
    def test_deterministic_hash_ignores_input_object_key_order(self):
        first = DAILLedger()
        second = DAILLedger()
        common = {
            "event_type": "asset.registered.v1",
            "entity_type": "asset",
            "entity_id": "asset-001",
            "entity_version": "1.0.0",
            "actor_ref": "service:registry",
            "idempotency_key": "request-001",
            "event_id": "event-001",
            "occurred_at": T0,
        }
        event_a = first.append(payload={"z": 1, "nested": {"b": 2, "a": 1}}, **common)
        event_b = second.append(payload={"nested": {"a": 1, "b": 2}, "z": 1}, **common)
        self.assertEqual(event_a["payload_sha256"], event_b["payload_sha256"])
        self.assertEqual(event_a["event_hash"], event_b["event_hash"])
        self.assertEqual("2026-08-26T12:00:00.000000Z", event_a["occurred_at"])

    def test_append_builds_and_fully_verifies_production_chain(self):
        ledger = seeded_ledger()
        report = ledger.verify()
        self.assertTrue(report.ok, report.errors)
        self.assertEqual(2, report.event_count)
        self.assertIsNone(ledger.events[0]["previous_event_hash"])
        self.assertEqual(ledger.events[0]["event_hash"], ledger.events[1]["previous_event_hash"])
        self.assertEqual(ledger.events[-1]["event_hash"], report.head_hash)

    def test_exact_retry_is_idempotent_and_conflicting_retry_is_rejected(self):
        ledger = seeded_ledger()
        original = ledger.events[0]
        retry = ledger.append(
            event_type=original["event_type"],
            entity_type=original["entity_type"],
            entity_id=original["entity_id"],
            entity_version=original["entity_version"],
            payload=original["payload"],
            actor_ref=original["actor_ref"],
            idempotency_key=original["idempotency_key"],
            event_id="a-different-transport-event-id",
            occurred_at="2030-01-01T00:00:00Z",
        )
        self.assertEqual(original, retry)
        self.assertEqual(2, len(ledger.events))
        with self.assertRaises(IdempotencyConflict):
            ledger.append(
                event_type=original["event_type"],
                entity_type=original["entity_type"],
                entity_id=original["entity_id"],
                payload={"work_id": "changed"},
                actor_ref=original["actor_ref"],
                idempotency_key=original["idempotency_key"],
            )

    def test_duplicate_event_id_is_replay(self):
        ledger = seeded_ledger()
        with self.assertRaises(ReplayDetected):
            ledger.append(
                event_type="another.event.v1",
                entity_type="work",
                entity_id="work-002",
                payload={},
                actor_ref="service:test",
                idempotency_key="request-003",
                event_id="event-001",
                occurred_at=T1,
            )

    def test_invalid_json_and_unanchored_float_rendering_are_rejected(self):
        ledger = DAILLedger()
        for invalid_payload in (
            {"not_finite": math.nan},
            {1: "non-string-key"},
            {"set": {"not", "json"}},
            {"float_needs_postgres_text": 1.25},
        ):
            with self.assertRaises(InvalidEvent):
                ledger.append(
                    event_type="test.event.v1",
                    entity_type="test",
                    entity_id="test-001",
                    payload=invalid_payload,
                    actor_ref="service:test",
                    idempotency_key="invalid",
                    occurred_at=T0,
                )
        with self.assertRaises(InvalidEvent):
            ledger.append(
                event_type="test.event.v1",
                entity_type="test",
                entity_id="test-001",
                payload={},
                actor_ref="service:test",
                idempotency_key="naive-time",
                occurred_at="2026-08-26T12:00:00",
            )

    def test_authoritative_jsonb_text_supports_scaled_numeric_payload(self):
        ledger = DAILLedger()
        event = ledger.append(
            event_type="metric.recorded.v1",
            entity_type="metric",
            entity_id="metric-001",
            payload={"ratio": 1.25},
            payload_jsonb_text='{"ratio": 1.25}',
            actor_ref="service:metrics",
            idempotency_key="metric-001",
            event_id="metric-event-001",
            occurred_at=T0,
        )
        self.assertEqual(
            hashlib.sha256(b'{"ratio": 1.25}').hexdigest(), event["payload_sha256"]
        )
        self.assertTrue(ledger.verify().ok, ledger.verify().errors)


class DAILCorrectionAndRestoreTests(unittest.TestCase):
    def test_correction_appends_without_mutating_original(self):
        ledger = seeded_ledger()
        original = copy.deepcopy(ledger.events[0])
        correction = ledger.append_correction(
            target_event_id="event-001",
            reason="Source documentation superseded the received fact.",
            replacement_payload={"work_id": "work-001", "facts": ["a", "c"]},
            actor_ref="human:steward",
            idempotency_key="correction-001",
            event_id="event-003",
            occurred_at="2026-08-26T12:02:00Z",
        )
        self.assertEqual(CORRECTION_EVENT_TYPE, correction["event_type"])
        self.assertEqual(original, ledger.events[0])
        self.assertEqual(3, len(ledger.events))
        self.assertTrue(ledger.verify().ok, ledger.verify().errors)

    def test_correction_requires_prior_target_and_actor(self):
        ledger = seeded_ledger()
        with self.assertRaises(InvalidEvent):
            ledger.append_correction(
                target_event_id="missing",
                reason="Correction",
                replacement_payload={},
                actor_ref="human:steward",
                idempotency_key="correction-001",
            )
        with self.assertRaises(InvalidEvent):
            ledger.append_correction(
                target_event_id="event-001",
                reason="Correction",
                replacement_payload={},
                idempotency_key="correction-002",
            )

    def test_full_restore_preserves_idempotency(self):
        source = seeded_ledger()
        restored = DAILLedger.restore_isolated(
            source.events,
            expected_head_hash=source.head_hash,
            expected_full_state_sha256=source.full_state_sha256,
        )
        retry = restored.append(
            event_type="rights.claim.received.v1",
            entity_type="work",
            entity_id="work-001",
            entity_version="1.0.0",
            payload={"facts": ["a", "b"], "work_id": "work-001"},
            actor_ref="service:intake",
            idempotency_key="request-001",
        )
        self.assertEqual("event-001", retry["event_id"])
        self.assertEqual(2, len(restored.events))

    def test_full_restore_detects_payload_tampering_and_replay(self):
        source = seeded_ledger()
        tampered = source.events
        tampered[0]["payload"]["work_id"] = "altered"
        with self.assertRaises(RestoreVerificationError) as caught:
            DAILLedger.restore_isolated(
                tampered,
                expected_head_hash=source.head_hash,
                expected_full_state_sha256=source.full_state_sha256,
            )
        self.assertIn("does not represent payload", str(caught.exception))
        replayed = source.events
        replayed[1]["event_id"] = replayed[0]["event_id"]
        with self.assertRaises(RestoreVerificationError) as caught:
            DAILLedger.restore_isolated(
                replayed,
                expected_head_hash=source.head_hash,
                expected_full_state_sha256=source.full_state_sha256,
            )
        self.assertIn("replays event_id", str(caught.exception))

    def test_wrong_full_restore_head_is_rejected(self):
        source = seeded_ledger()
        with self.assertRaises(RestoreVerificationError) as caught:
            DAILLedger.restore_isolated(
                source.events,
                expected_head_hash="f" * 64,
                expected_full_state_sha256=source.full_state_sha256,
            )
        self.assertIn("does not match expected_head_hash", str(caught.exception))

    def test_hash_delimiter_is_rejected_in_every_variable_hash_field(self):
        base = {
            "previous_event_hash": None,
            "event_id": "event-001",
            "schema_version": "1.1.0",
            "event_type": "a",
            "entity_type": "b",
            "entity_id": "c",
            "entity_version": "1",
            "actor_did": None,
            "actor_ref": "service:test",
            "payload_sha256": "a" * 64,
            "occurred_at": T0,
        }
        for field in (
            "event_id",
            "schema_version",
            "event_type",
            "entity_type",
            "entity_id",
            "entity_version",
            "actor_ref",
        ):
            with self.subTest(field=field):
                invalid = dict(base)
                invalid[field] = f"safe|unsafe"
                with self.assertRaisesRegex(InvalidEvent, "hash delimiter"):
                    production_event_hash(**invalid)

    def test_full_restore_anchor_binds_idempotency_metadata(self):
        source = seeded_ledger()
        tampered = source.events
        tampered[0]["idempotency_key"] = "attacker-selected-key"
        with self.assertRaises(RestoreVerificationError) as caught:
            DAILLedger.restore_isolated(
                tampered,
                expected_head_hash=source.head_hash,
                expected_full_state_sha256=source.full_state_sha256,
            )
        self.assertIn("full_state_sha256", str(caught.exception))


class DAILColdRouteTests(unittest.TestCase):
    def test_cold_export_is_allowlisted_and_contains_no_source_secrets(self):
        ledger = DAILLedger()
        ledger.append(
            event_type="restricted.fact.received.v1",
            entity_type="private_work",
            entity_id="private-work-987",
            payload={
                "api_token": "never-export-this-token",
                "personal_record": "never-export-this-record",
            },
            actor_ref="private-actor@example.test",
            idempotency_key="private-idempotency-key",
            event_id="private-event-id",
            occurred_at=T0,
        )
        cold_export = ledger.export_cold(created_at=T1)
        serialized = cold_export.canonical_json
        for forbidden_value in (
            "private-work-987",
            "never-export-this-token",
            "never-export-this-record",
            "private-actor@example.test",
            "private-idempotency-key",
            "private-event-id",
            "restricted.fact.received.v1",
        ):
            self.assertNotIn(forbidden_value, serialized)
        receipt = cold_export.as_dict()["receipts"][0]
        self.assertNotIn("payload", receipt)
        self.assertNotIn("actor_ref", receipt)
        self.assertNotIn("idempotency_key", receipt)

    def test_isolated_cold_restore_checks_anchors_and_materializes_once(self):
        ledger = seeded_ledger()
        cold_export = ledger.export_cold(created_at=T1)
        with tempfile.TemporaryDirectory() as temporary_directory:
            destination = Path(temporary_directory) / "isolated-restore"
            report = restore_cold_export_isolated(
                cold_export,
                destination=destination,
                expected_export_sha256=cold_export.export_sha256,
                expected_head_hash=ledger.head_hash,
            )
            self.assertTrue(report.ok)
            self.assertEqual(2, report.event_count)
            self.assertTrue((destination / "dail-cold-export.json").is_file())
            stored_report = json.loads(
                (destination / "RESTORE_VERIFICATION.json").read_text(encoding="utf-8")
            )
            self.assertEqual(cold_export.export_sha256, stored_report["export_sha256"])
            with self.assertRaises(RestoreVerificationError):
                restore_cold_export_isolated(
                    cold_export,
                    destination=destination,
                    expected_export_sha256=cold_export.export_sha256,
                    expected_head_hash=ledger.head_hash,
                )

    def test_cold_restore_detects_document_tamper_and_wrong_head(self):
        ledger = seeded_ledger()
        cold_export = ledger.export_cold(created_at=T1)
        document = cold_export.as_dict()
        document["receipts"][0]["occurred_at"] = "2026-08-26T12:00:01.000000Z"
        with tempfile.TemporaryDirectory() as temporary_directory:
            with self.assertRaises(RestoreVerificationError) as caught:
                restore_cold_export_isolated(
                    document,
                    destination=Path(temporary_directory) / "tampered",
                    expected_export_sha256=cold_export.export_sha256,
                    expected_head_hash=ledger.head_hash,
                )
            self.assertIn("external anchor", str(caught.exception))
            with self.assertRaises(RestoreVerificationError) as caught:
                restore_cold_export_isolated(
                    cold_export,
                    destination=Path(temporary_directory) / "wrong-head",
                    expected_export_sha256=cold_export.export_sha256,
                    expected_head_hash="e" * 64,
                )
            self.assertIn("head_hash does not match the external anchor", str(caught.exception))

    def test_empty_ledger_cold_route_is_valid(self):
        ledger = DAILLedger()
        cold_export = ledger.export_cold(created_at=T0)
        with tempfile.TemporaryDirectory() as temporary_directory:
            report = restore_cold_export_isolated(
                cold_export,
                destination=Path(temporary_directory) / "empty",
                expected_export_sha256=cold_export.export_sha256,
                expected_head_hash=ledger.head_hash,
            )
        self.assertEqual(0, report.event_count)
        self.assertEqual("0" * 64, report.head_hash)


if __name__ == "__main__":
    unittest.main()
