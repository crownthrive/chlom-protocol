import unittest
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parents[1]

class RegistryTests(unittest.TestCase):
    def load(self, name):
        return yaml.safe_load((ROOT/'registry'/name).read_text())

    def test_six_functions(self):
        data = self.load('core.yaml')
        self.assertEqual([x['id'] for x in data['functions']], ['rights','rules','roles','revenue','records','remedies'])

    def test_dla_dail_names(self):
        items = {x['id']: x for x in self.load('components.yaml')['components']}
        self.assertEqual(items['dla']['name'], 'Dynamic Licensing Asset')
        self.assertEqual(items['dail']['name'], 'Decentralized Autonomous Information Ledger')

    def test_decentralized_features_not_active(self):
        items = {x['id']: x for x in self.load('components.yaml')['components']}
        for key in ['token-economy','dao','substrate-chain','cross-chain']:
            self.assertNotEqual(items[key]['status'], 'active')

    def test_help_center_count(self):
        data = yaml.safe_load((ROOT/'help-center'/'recovery-policy.yaml').read_text())
        self.assertEqual(data['recovered_record_count'], 795)

if __name__ == '__main__':
    unittest.main()
