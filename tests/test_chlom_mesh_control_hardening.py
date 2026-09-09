import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EDGE_SOURCE = ROOT / "supabase/functions/chlom-mesh-control/index.ts"


class ChlomMeshControlHardeningTests(unittest.TestCase):
    def test_edge_is_fail_closed_before_any_database_call(self):
        source = EDGE_SOURCE.read_text(encoding="utf-8")
        self.assertNotIn("...data", source)
        self.assertNotIn("error.message", source)
        self.assertNotIn("createClient", source)
        self.assertNotIn(".rpc(", source)
        self.assertIn('service: "ct.chlom.mesh.control.v2"', source)
        self.assertIn(
            'error_code: "CONTROL_AUTHORITY_AND_IDEMPOTENCY_GATE_REQUIRED"',
            source,
        )
        self.assertIn('execution_effect: "NONE"', source)
        self.assertIn("Authentication alone must never manufacture CHLOM authority", source)

    def test_edge_does_not_parse_or_echo_an_unaccepted_request(self):
        source = EDGE_SOURCE.read_text(encoding="utf-8")
        self.assertNotIn("request.json", source)
        self.assertNotIn("body.", source)
        self.assertNotIn("payload", source)
        self.assertNotIn("idempotency_key", source)


if __name__ == "__main__":
    unittest.main()
