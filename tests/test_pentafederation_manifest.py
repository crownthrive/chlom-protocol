import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "registry" / "pentafederation.json"


class PentaFederationManifestTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads(MANIFEST.read_text())

    def test_identity_and_parent_are_canonical(self):
        self.assertEqual(self.data["system_id"], "ct.penta.federation.v1")
        self.assertEqual(self.data["name"], "PentaFederation")
        self.assertEqual(self.data["parent_federation"], "CrownThrive Federation")
        self.assertEqual(
            self.data["canonical_repository_parent"]["repo_id"],
            "ct.repo.crownthrive-support",
        )

    def test_release_state_is_not_overstated(self):
        self.assertEqual(self.data["status"], "CONTROLLED_TEST")
        self.assertEqual(
            self.data["promotion"]["current_state"],
            "CONTROLLED_TEST",
        )

    def test_authority_does_not_expand_through_federation(self):
        guardrails = self.data["guardrails"]
        self.assertTrue(guardrails["fail_closed"])
        self.assertTrue(guardrails["d3_human_reserved"])
        self.assertFalse(guardrails["authority_manufacture"])
        self.assertFalse(guardrails["self_approval"])
        self.assertFalse(guardrails["provider_write_inherited"])
        self.assertFalse(guardrails["money_movement_inherited"])
        self.assertFalse(guardrails["rights_grant_inherited"])
        self.assertFalse(guardrails["child_voting_inherited"])

    def test_facade_is_evaluation_only(self):
        self.assertFalse(
            self.data["interfaces"]["write_execution_exposed_by_facade"]
        )
        self.assertEqual(
            set(self.data["interfaces"]["read_and_evaluate"]),
            {"status", "member_state", "route_plan"},
        )

    def test_verification_proof_is_pinned(self):
        proof = self.data["verification"]
        self.assertEqual(proof["result"], "PASS")
        self.assertEqual(proof["score"], 1.0)
        self.assertEqual(len(proof["sha256"]), 64)


if __name__ == "__main__":
    unittest.main()
