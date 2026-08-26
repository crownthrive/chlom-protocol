import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVICE = ROOT / "services" / "penta-governance-v1"


class PentaGovernanceManifestTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads(
            (SERVICE / "penta-governance-interface-contract.v1.json").read_text(encoding="utf-8")
        )
        cls.readme = (SERVICE / "README.md").read_text(encoding="utf-8")

    def test_three_branches_are_canonical(self):
        branches = self.manifest["branches"]
        self.assertEqual(branches["executive"]["name"], "PentaExecutive™")
        self.assertEqual(branches["legislative"]["name"], "PentaLegislative™")
        self.assertEqual(branches["judicial"]["name"], "PentaJudicial™")

    def test_executive_uses_existing_chain_without_new_rank(self):
        executive = self.manifest["branches"]["executive"]
        self.assertEqual(executive["uses_existing_chain"], ["PentaBoard™", "PentaDirectors™", "PentaManagers™"])
        self.assertFalse(executive["creates_new_supervisory_rank"])
        self.assertEqual(executive["emergency_ttl_hours"], 72)
        self.assertTrue(executive["emergency_judicial_review"])

    def test_democracy_is_one_membership_one_vote(self):
        democracy = self.manifest["democracy"]
        self.assertEqual(democracy["name"], "PentaDemocracy™")
        self.assertEqual(democracy["vote_weight"], 1)
        self.assertFalse(democracy["agent_votes_may_satisfy_human_ratification"])
        self.assertTrue(democracy["eligibility_snapshot"])
        self.assertTrue(democracy["conflict_disclosure"])
        self.assertTrue(democracy["recusal"])

    def test_high_risk_requires_human_and_panel_controls(self):
        self.assertTrue(self.manifest["branches"]["legislative"]["d2_d3_human_ratification"])
        self.assertEqual(self.manifest["branches"]["judicial"]["d2_d3_minimum_non_recused_judges"], 3)
        self.assertFalse(self.manifest["branches"]["judicial"]["party_may_judge_own_case"])

    def test_checks_and_balances_are_present(self):
        required = {
            "veto", "override", "judicial_stay", "judicial_review", "legislative_review",
            "confirmation", "no_confidence", "remand", "charter_challenge",
            "emergency_review", "human_ratification",
        }
        self.assertTrue(required.issubset(set(self.manifest["checks_and_balances"])))

    def test_governance_does_not_manufacture_authority(self):
        bounds = self.manifest["authority_boundaries"]
        self.assertFalse(bounds["authority_manufacture"])
        self.assertFalse(bounds["external_legal_authority"])
        self.assertFalse(bounds["provider_authority_manufacture"])
        self.assertFalse(bounds["money_movement"])
        self.assertTrue(bounds["CHLOM_remains_higher_order_envelope"])

    def test_internal_governance_is_not_misrepresented_as_sovereign(self):
        self.assertFalse(self.manifest["sovereign_government"])
        self.assertFalse(self.manifest["branches"]["judicial"]["public_court"])
        self.assertIn("Not sovereign government", self.readme)

    def test_provider_verification_is_recorded(self):
        verification = self.manifest["verification"]
        self.assertTrue(verification["provider_applied"])
        self.assertTrue(verification["d2_without_human_ratification_rejected"])
        self.assertTrue(verification["emergency_action_over_72_hours_rejected"])
        self.assertTrue(verification["rls_verified"])

    def test_marks_are_asserted_not_falsely_registered(self):
        trademark = self.manifest["trademark"]
        self.assertEqual(trademark["owner"], "CrownThrive, LLC")
        self.assertFalse(trademark["federal_registration_claimed"])
        self.assertEqual(
            set(trademark["marks"]),
            {"PentaExecutive™", "PentaLegislative™", "PentaJudicial™", "PentaDemocracy™"},
        )

    def test_database_surface_count(self):
        self.assertEqual(self.manifest["database"]["table_count"], 17)
        self.assertEqual(len(self.manifest["database"]["tables"]), 17)


if __name__ == "__main__":
    unittest.main()
