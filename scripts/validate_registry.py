from pathlib import Path
import json
import re
import sys
import yaml
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / 'registry'
SCHEMAS = ROOT / 'schemas'

ERRORS = []

def err(msg):
    ERRORS.append(msg)

for path in sorted(REGISTRY.glob('*.yaml')):
    try:
        data = yaml.safe_load(path.read_text())
    except Exception as exc:
        err(f'{path}: invalid YAML: {exc}')
        continue
    if data is None:
        err(f'{path}: empty YAML')

for path in sorted(SCHEMAS.glob('*.json')):
    try:
        schema = json.loads(path.read_text())
        Draft202012Validator.check_schema(schema)
    except Exception as exc:
        err(f'{path}: invalid JSON Schema: {exc}')

secret_patterns = [r'\bsk_(live|test)_[A-Za-z0-9]+', r'\bwhsec_[A-Za-z0-9]+', r'Bearer\s+[A-Fa-f0-9]{20,}', r'-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----']
for path in ROOT.rglob('*'):
    if not path.is_file() or '.git' in path.parts:
        continue
    if path.suffix.lower() not in {'.md','.yaml','.yml','.json','.py','.txt'}:
        continue
    text = path.read_text(errors='ignore')
    for pattern in secret_patterns:
        if re.search(pattern, text):
            err(f'{path}: possible secret matched {pattern}')

if ERRORS:
    print('\n'.join(f'ERROR: {e}' for e in ERRORS))
    sys.exit(1)
print('CHLOM registry validation passed')
