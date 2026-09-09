import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "migrations" / "20260826_dail_phase4_assurance_v1.sql"
LINK_INDEX_MIGRATION = (
    ROOT
    / "migrations"
    / "20260826_dail_checkpoint_receipt_link_index_v1.sql"
)
HASH_DELIMITER_MIGRATION = (
    ROOT / "migrations" / "20260827_dail_hash_delimiter_hardening_v1.sql"
)


class DailPhase4MigrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sql = MIGRATION.read_text(encoding="utf-8")
        cls.normalized = re.sub(r"\s+", " ", cls.sql.lower())

    def test_migration_is_additive_to_the_existing_dail(self):
        self.assertIn("create table if not exists chlom_runtime.dail_cold_checkpoints_v1", self.normalized)
        self.assertIn("create table if not exists chlom_runtime.dail_recovery_drill_receipts_v1", self.normalized)
        self.assertNotIn("alter table chlom_runtime.dail_events", self.normalized)
        self.assertNotIn("drop table chlom_runtime.dail_events", self.normalized)
        self.assertNotIn("create or replace function chlom_runtime.append_dail_event", self.normalized)
        self.assertNotIn("create or replace function chlom_runtime.verify_dail_chain", self.normalized)

    def test_receipts_are_append_only_and_fail_closed(self):
        for table in (
            "dail_cold_checkpoints_v1",
            "dail_recovery_drill_receipts_v1",
        ):
            self.assertIn(
                f"alter table chlom_runtime.{table} force row level security",
                self.normalized,
            )
            self.assertRegex(
                self.normalized,
                rf"before update or delete on chlom_runtime\.{table}",
            )
            self.assertRegex(
                self.normalized,
                rf"before truncate on chlom_runtime\.{table}",
            )
        self.assertIn("dail assurance receipts are append-only", self.normalized)
        self.assertIn("from public, anon, authenticated, service_role", self.normalized)

    def test_security_definer_functions_pin_an_empty_search_path(self):
        for function_name in (
            "record_dail_cold_checkpoint_v1",
            "record_dail_recovery_drill_v1",
            "read_dail_phase4_assurance_status_v1",
        ):
            pattern = (
                rf"create or replace function chlom_runtime\.{function_name}.*?"
                rf"security definer set search_path = ''"
            )
            self.assertRegex(self.normalized, pattern)
        self.assertNotRegex(
            self.normalized,
            r"grant execute on function chlom_runtime\.[^(]+\([^;]+\) to (?:public|anon|authenticated)",
        )

    def test_checkpoint_uses_the_ledger_global_append_lock(self):
        self.assertIn("chlom_runtime.dail.global.v1", self.sql)
        self.assertIn("snapshot event count does not match its dail source prefix", self.normalized)
        self.assertIn("hot dail readback is internally inconsistent", self.normalized)

    def test_checkpoint_binds_verifier_output_to_an_independent_receipt_chain(self):
        self.assertIn("verifier_output jsonb not null", self.normalized)
        self.assertIn("verifier_output_sha256 text not null", self.normalized)
        self.assertIn("previous_checkpoint_receipt_sha256 text", self.normalized)
        self.assertIn("checkpoint_receipt_sha256 text not null unique", self.normalized)
        self.assertIn("coalesce(v_previous_checkpoint_receipt_sha256, 'genesis')", self.normalized)
        self.assertIn("pg_catalog.jsonb_build_object", self.normalized)

    def test_recovery_scope_and_phase_claims_are_bounded(self):
        for scope in ("metadata_manifest", "ledger_lineage", "full_data_restore"):
            self.assertIn(scope, self.sql)
        self.assertIn("isolated_non_production", self.sql)
        self.assertIn("METADATA_RECOVERY_VERIFIED", self.sql)
        self.assertIn("BOUNDED_COLD_ASSURANCE_ONLY", self.sql)
        self.assertIn("'institutional_phase4_activation', false", self.sql)

    def test_only_the_existing_sanitized_public_status_rpc_is_opened(self):
        expected = (
            "grant execute on function public.chlom_mesh_public_status_v1() "
            "to anon, authenticated, service_role"
        )
        self.assertIn(expected, self.normalized)
        public_grants = re.findall(
            r"grant execute on function public\.[^(]+\([^;]*?\)\s+to\s+[^;]+",
            self.normalized,
        )
        self.assertEqual(public_grants, [expected])

    def test_checkpoint_receipt_foreign_key_has_a_followup_covering_index(self):
        sql = re.sub(
            r"\s+", " ", LINK_INDEX_MIGRATION.read_text(encoding="utf-8").lower()
        )
        self.assertIn(
            "create index if not exists "
            "dail_cold_checkpoints_previous_receipt_v1_idx on "
            "chlom_runtime.dail_cold_checkpoints_v1 "
            "( previous_checkpoint_receipt_sha256 ) "
            "where previous_checkpoint_receipt_sha256 is not null",
            sql,
        )
        self.assertNotIn("drop ", sql)
        self.assertNotIn("grant ", sql)

    def test_production_hash_delimiter_inputs_are_fail_closed(self):
        sql = re.sub(
            r"\s+", " ", HASH_DELIMITER_MIGRATION.read_text(encoding="utf-8").lower()
        )
        self.assertIn("set local lock_timeout = '5s'", sql)
        self.assertIn(
            "add constraint dail_events_hash_delimiter_v1_check check",
            sql,
        )
        for field in (
            "schema_version",
            "event_type",
            "entity_type",
            "entity_id",
            "entity_version",
            "actor_did",
            "actor_ref",
        ):
            self.assertRegex(sql, rf"strpos\((?:coalesce\()?{field}")
        self.assertIn(
            "validate constraint dail_events_hash_delimiter_v1_check",
            sql,
        )
        self.assertNotIn("drop ", sql)
        self.assertNotIn("grant ", sql)


if __name__ == "__main__":
    unittest.main()
