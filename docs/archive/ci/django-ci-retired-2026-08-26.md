# Retired CI Record — Django CI

**Retired:** 2026-08-26  
**Repository:** `crownthrive1/chlom-protocol`  
**Former workflow:** `.github/workflows/django.yml`

## Reason for retirement

The workflow was a stale Django template and no longer represented the repository's executable architecture.

At retirement time:

- the repository did not contain `manage.py`;
- the workflow attempted to install from `requirements.txt`, which was not present at the repository root;
- the workflow matrix targeted Python 3.7, 3.8 and 3.9;
- the 2026-08-26 pull-request run failed during the Python 3.7 setup step before dependencies or application tests could execute;
- the repository's actual registry/governance validation is performed by `.github/workflows/validate-registry.yml`.

## Continuity rule

This record is historical evidence only. Do not restore the Django workflow unless a real Django application is added to this repository with an explicit supported-Python contract, dependency manifest and application test target.

## Replacement validation path

The active CHLOM registry validation path remains responsible for registry parsing, secret-pattern scanning and unit-test discovery under `tests/`.
