import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EDGE_SOURCE = ROOT / "supabase" / "functions" / "chlom-mesh-status" / "index.ts"
MIGRATION = (
    ROOT
    / "migrations"
    / "20260826_chlom_mesh_status_service_role_hardening_v1.sql"
)


class ChlomMeshStatusHardeningTests(unittest.TestCase):
    def test_edge_uses_server_side_service_role_for_fixed_rpc(self):
        source = EDGE_SOURCE.read_text(encoding="utf-8")
        self.assertIn('Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")', source)
        self.assertIn('client.rpc("chlom_mesh_public_status_v1")', source)
        self.assertNotIn('Deno.env.get("SUPABASE_ANON_KEY")', source)
        self.assertNotRegex(source, r"client\.rpc\([^\"']")

    def test_edge_allowlists_and_validates_the_public_response(self):
        source = EDGE_SOURCE.read_text(encoding="utf-8")
        self.assertNotIn("...data", source)
        self.assertIn("Treat the service-role RPC response as untrusted input", source)
        self.assertIn("const healthy =", source)
        self.assertIn("if (!healthy)", source)
        self.assertIn('contract: "ct.chlom.mesh.status.v1"', source)
        self.assertIn("binding_summary: {", source)
        self.assertIn("latest_heartbeat: {", source)
        self.assertNotIn("bindings: data", source)
        for internal_field in (
            "source_document",
            "source_table",
            "vault_policy_ref",
            "authority_ceiling",
        ):
            self.assertNotIn(internal_field, source)

    def test_database_wrapper_is_not_directly_public(self):
        sql = re.sub(r"\s+", " ", MIGRATION.read_text(encoding="utf-8").lower())
        self.assertIn(
            "revoke execute on function public.chlom_mesh_public_status_v1() "
            "from public, anon, authenticated",
            sql,
        )
        self.assertIn(
            "grant execute on function public.chlom_mesh_public_status_v1() "
            "to service_role, postgres",
            sql,
        )
        self.assertNotRegex(
            sql,
            r"grant execute on function public\.chlom_mesh_public_status_v1\(\) "
            r"to [^;]*(?:anon|authenticated)",
        )


if __name__ == "__main__":
    unittest.main()
