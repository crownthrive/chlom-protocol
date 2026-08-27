import copy
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from scripts.verify_dail_lineage_snapshot import SnapshotError, verify_snapshot


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/verify_dail_lineage_snapshot.py"


class DailLineageSnapshotVerifierTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)
        self.first_hash = "1" * 64
        self.second_hash = "2" * 64
        self.payload_hash = "a" * 64
        self.document = {
            "format": "ct.chlom.dail-lineage-snapshot.v1",
            "classification": "private_integrity_metadata",
            "restore_scope": "ledger_lineage",
            "payloads_included": False,
            "actor_identifiers_included": False,
            "entity_identifiers_included": False,
            "source": {
                "project_ref": "example",
                "captured_at": "2026-08-26 00:00:02+00",
                "event_count": 2,
                "min_sequence_id": 1,
                "max_sequence_id": 3,
                "head_event_hash": self.second_hash,
                "head_created_at": "2026-08-26 00:00:01+00",
                "payload_bytes_not_exported": 10,
                "integrity_state": "pass",
                "verifier_failure_count": 0,
                "documented_correction_count": 0,
            },
            "events": [
                {
                    "sequence_id": 1,
                    "previous_event_hash": None,
                    "event_hash": self.first_hash,
                    "payload_sha256": self.payload_hash,
                    "created_at": "2026-08-26 00:00:00+00",
                },
                {
                    "sequence_id": 3,
                    "previous_event_hash": self.first_hash,
                    "event_hash": self.second_hash,
                    "payload_sha256": self.payload_hash,
                    "created_at": "2026-08-26 00:00:01+00",
                },
            ],
            "corrections": [],
            "limitations": ["lineage only"],
        }

    def tearDown(self):
        self.temporary_directory.cleanup()

    def write(self, document=None):
        path = self.root / "snapshot.json"
        path.write_text(json.dumps(document or self.document), encoding="utf-8")
        return path

    @staticmethod
    def anchor(path):
        return hashlib.sha256(path.read_bytes()).hexdigest()

    def test_valid_snapshot_preserves_gapped_sequence_and_chain(self):
        path = self.write()
        report = verify_snapshot(path, self.anchor(path))
        self.assertTrue(report["ok"])
        self.assertEqual(2, report["event_count"])
        self.assertEqual(3, report["max_sequence_id"])
        self.assertFalse(report["full_data_restore"])

    def test_chain_tamper_is_detected(self):
        tampered = copy.deepcopy(self.document)
        tampered["events"][1]["previous_event_hash"] = "f" * 64
        path = self.write(tampered)
        with self.assertRaisesRegex(SnapshotError, "breaks physical chain"):
            verify_snapshot(path, self.anchor(path))

    def test_external_hash_tamper_is_detected(self):
        with self.assertRaisesRegex(SnapshotError, "external anchor"):
            verify_snapshot(self.write(), "f" * 64)

    def test_documented_physical_hash_repair_is_accepted(self):
        repaired = copy.deepcopy(self.document)
        repaired["corrections"] = [
            {
                "sequence_id": 3,
                "original_event_hash": "3" * 64,
                "expected_event_hash": self.second_hash,
                "payload_sha256": self.payload_hash,
                "previous_event_hash": self.first_hash,
                "correction_state": "accepted",
                "defect_class": "legacy_event_hash_construction_defect",
                "created_at": "2026-08-26 00:00:02+00",
            }
        ]
        path = self.write(repaired)
        report = verify_snapshot(path, self.anchor(path))
        self.assertEqual(1, report["accepted_correction_rows"])

    def test_payload_or_actor_export_claim_fails_closed(self):
        for field in (
            "payloads_included",
            "actor_identifiers_included",
            "entity_identifiers_included",
        ):
            invalid = copy.deepcopy(self.document)
            invalid[field] = True
            path = self.write(invalid)
            with self.assertRaisesRegex(SnapshotError, f"{field} must be false"):
                verify_snapshot(path, self.anchor(path))

    def test_rejects_invalid_source_metadata(self):
        cases = (
            ("captured_at", "not-a-time", "captured_at"),
            ("payload_bytes_not_exported", -1, "payload_bytes_not_exported"),
            ("documented_correction_count", 1, "correction rows"),
        )
        for field, value, message in cases:
            with self.subTest(field=field):
                invalid = copy.deepcopy(self.document)
                invalid["source"][field] = value
                path = self.write(invalid)
                with self.assertRaisesRegex(SnapshotError, message):
                    verify_snapshot(path, self.anchor(path))

    def test_external_anchor_is_mandatory_and_well_formed(self):
        path = self.write()
        for invalid in (None, "", "F" * 64):
            with self.subTest(anchor=invalid):
                with self.assertRaisesRegex(SnapshotError, "external snapshot anchor"):
                    verify_snapshot(path, invalid)

    def test_cli_materializes_snapshot_and_verification_receipt(self):
        path = self.write()
        destination = self.root / "isolated-materialization"
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                str(path),
                "--expected-sha256",
                self.anchor(path),
                "--materialize",
                str(destination),
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertTrue((destination / path.name).is_file())
        receipt = json.loads(
            (destination / "RESTORE_VERIFICATION.json").read_text(encoding="utf-8")
        )
        self.assertTrue(receipt["ok"])
        self.assertEqual(str(destination.resolve()), receipt["restore_directory"])


if __name__ == "__main__":
    unittest.main()
