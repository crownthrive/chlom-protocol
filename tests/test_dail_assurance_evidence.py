import hashlib
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "developers/manifests/dail-phase4-assurance.v1.json"
RECEIPT_PATH = (
    ROOT
    / "artifacts/receipts"
    / "dail-phase4-assurance-production-evidence-2026-08-26.v1.json"
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class DailAssuranceEvidenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        cls.receipt = json.loads(RECEIPT_PATH.read_text(encoding="utf-8"))

    def test_phase_boundary_fails_closed(self):
        phase = self.manifest["phase_boundary"]
        self.assertEqual(3, phase["current_institutional_phase"])
        self.assertEqual(4, phase["target_institutional_phase"])
        self.assertEqual("HOLD", phase["phase4_state"])
        self.assertIs(False, phase["phase4_activation_authorized"])
        self.assertIs(False, phase["automatic_activation"])

        certification = self.receipt["certification_boundary"]
        self.assertIs(False, certification["phase4_readiness_certified"])
        self.assertIs(False, certification["institutional_phase4_activated"])
        self.assertEqual("HOLD", certification["decision"])

    def test_hot_and_cold_claims_remain_bounded(self):
        current = self.manifest["current_state"]
        self.assertEqual("PASS", current["hot_status_route_state"])
        self.assertEqual(
            "HOLD_AUTHORITY_AND_ACTOR_BOUND_IDEMPOTENCY_REQUIRED",
            current["authenticated_control_route_state"],
        )
        self.assertEqual(
            "NONE", current["authenticated_control_route_execution_effect"]
        )
        self.assertEqual(
            "LEDGER_LINEAGE_RECOVERY_VERIFIED", current["cold_state"]
        )
        self.assertEqual(
            "BOUNDED_COLD_ASSURANCE_ONLY", current["cold_assurance_state"]
        )
        for key in (
            "full_data_bearing_dail_export_verified",
            "isolated_postgresql_17_data_restore_verified",
            "rpo_rto_verified",
            "infrastructure_failover_verified",
            "failback_verified",
            "external_anchor_verified",
            "independent_phase4_conformance_verified",
        ):
            self.assertIs(False, current[key], key)

        cold = self.receipt["cold_route"]
        self.assertEqual("ledger_lineage", cold["scope"])
        self.assertIs(False, cold["contains_event_payloads"])
        self.assertIs(False, cold["contains_actor_or_entity_identifiers"])
        self.assertIs(False, cold["full_data_or_database_restore"])
        self.assertIs(False, cold["production_failover"])

        control = self.receipt["authenticated_control_route"]
        self.assertEqual(
            "HOLD_AUTHORITY_AND_ACTOR_BOUND_IDEMPOTENCY_REQUIRED",
            control["state"],
        )
        self.assertIs(False, control["database_call_performed"])
        self.assertIs(False, control["request_body_parsed_or_persisted"])
        self.assertEqual("NONE", control["execution_effect"])
        self.assertIs(False, control["authenticated_hold_response_verified"])
        self.assertIs(False, control["authenticated_request_acceptance_verified"])

    def test_checkpoint_and_drill_evidence_cross_reference(self):
        checkpoint = self.manifest["ledger_lineage_checkpoint"]
        drill = self.manifest["ledger_lineage_recovery_drill"]
        self.assertEqual(checkpoint["checkpoint_id"], self.receipt["checkpoint"]["checkpoint_id"])
        self.assertEqual(checkpoint["receipt_sha256"], self.receipt["checkpoint"]["receipt_sha256"])
        self.assertEqual(drill["drill_id"], self.receipt["recovery_drill"]["drill_id"])
        self.assertEqual("PASS", drill["result"])
        self.assertEqual("ledger_lineage", drill["scope"])
        self.assertIs(True, drill["tamper_injection_rejected"])
        self.assertIs(False, drill["full_data_restore_verified"])

        for artifact in ("package", "manifest"):
            self.assertEqual(
                checkpoint[artifact]["object_id"],
                self.receipt["private_custody"][artifact]["object_id"],
            )
            self.assertEqual(
                checkpoint[artifact]["sha256"],
                self.receipt["private_custody"][artifact]["sha256"],
            )

    def test_source_hashes_match_the_evidence_receipt(self):
        deployment = self.receipt["deployment_evidence"]
        for key in (
            "edge_function",
            "control_edge_function",
            "assurance_migration",
            "service_role_hardening_migration",
            "receipt_link_index_migration",
            "hash_delimiter_hardening_migration",
            "lineage_recovery_verifier",
        ):
            record = deployment[key]
            path = ROOT / record["path"]
            self.assertTrue(path.is_file(), record["path"])
            self.assertEqual(record["source_sha256"], sha256(path), record["path"])

    def test_activation_predicate_count_is_consistent(self):
        predicates = self.manifest["activation_predicates"]
        met_count = sum(item["met"] is True for item in predicates)
        logic = self.manifest["activation_logic"]
        self.assertEqual(logic["required_predicate_count"], len(predicates))
        self.assertEqual(logic["currently_met_predicate_count"], met_count)
        self.assertEqual("HOLD", logic["current_result"])


if __name__ == "__main__":
    unittest.main()
