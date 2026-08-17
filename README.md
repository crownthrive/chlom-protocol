# CHLOM™ — Phase 2 Governed Registry

**Compliance Hybrid Licensing and Ownership Model** is CrownThrive's governed rights and institutional operating system for **Rights, Rules, Roles, Revenue, Records, and Remedies**.

> **Status:** Phase 2 foundation / pre-alpha. This public repository documents public-safe architecture, formal research, schemas and operating registries. It does not represent a live public blockchain, token, DAO, autonomous legal authority, production oracle network or deployed CHLOM mainnet.

## Production-first doctrine
CHLOM is being rebuilt first as a cloud-first, API-first, event-driven, multi-tenant and human-governed platform. The objective is to govern assets, rights, policies, actors, revenue, evidence, agreements, corrections and remedies consistently across CrownThrive before optional decentralized settlement is introduced.

## Six canonical functions
1. **Rights** — assets, versions, provenance, authority, permissions and restrictions.
2. **Rules** — policies, conditions, eligibility, risk and approval requirements.
3. **Roles** — organizations, actors, credentials, delegated authority and separation of duties.
4. **Revenue** — fees, allocations, royalties, commissions, holds, adjustments and reconciliation.
5. **Records** — DAIL events, evidence references, approvals, versions, agreements and audit history.
6. **Remedies** — disputes, holds, corrections, suspensions, revocations, appeals and restoration.

## Canonical corrections
- **DLA** = Dynamic Licensing Asset.
- **DAIL** = Decentralized Autonomous Information Ledger.
- Historical **Decentralized Licensing Authority** responsibilities move to Licensing Stewardship / Issuer Authority.
- Historical DAL meanings are split among DAIL, Case Management, Identity/Attestations, and Revenue Allocation.

## Repository map
```text
registry/            machine-readable public-safe operating records
schemas/             JSON Schemas
help-center/         recovered title taxonomy and reconstruction policy
docs/architecture/   current baseline, target architecture and ADRs
services/            Phase 3 service contracts
scripts/             registry validation
tests/               automated validation tests
.github/              CI and change-control templates
artifacts/            retained formal/research artifacts
```

## Public / private boundary
The source recovery package classifies major CHLOM materials as internal or restricted. This public repository therefore stores source metadata and reconciled public-safe abstractions, not confidential documents, raw evidence, secrets, Fingerprint implementation details or private economic logic.

## Validation
```bash
python -m pip install -r requirements-dev.txt
python scripts/validate_registry.py
python -m unittest discover -s tests -v
```

See `docs/architecture/SOURCE_RECONCILIATION.md` for authority and conflict rules.
