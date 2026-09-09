# Contributing to CHLOM

CHLOM contributions must preserve CrownThrive OS source-of-truth rules, CHLOM component identity, intellectual property, evidence lineage, current/historical separation, public/private boundaries, and fail-closed authority.

Before contributing, read `README.md`, `LICENSE`, `AGENTS.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, and `docs/archive/README.md`.

## Required pull-request context

Material changes should identify:

- the affected CHLOM component, stable ID, contract/schema/service version, and institutional Phase 3 context;
- governing source, issue, policy, decision, or evidence;
- current state and intended state;
- rights, security, privacy, compliance, integration, economic, or cultural implications;
- tests and readbacks performed;
- rollback/compensation or correction path where applicable;
- documentation/archive impact;
- unresolved gates.

## State discipline

Do not collapse `candidate`, `CONTROLLED_TEST`, `HOLD`, `verified_read`, `verified_write`, `PRODUCTION`, `HISTORICAL`, and `SUPERSEDED` into one state. A Phase 3 umbrella does not renumber or promote an independently versioned component.

## Provider and integration changes

Provider capability is not CrownThrive authority. A provider-write promotion must satisfy the controlling operation-level certification contract and evidence requirements. Do not infer general provider mutation authority from one certified operation.

## Historical material

Preserve historical papers and prior contracts. When superseding material, record the successor and effective state rather than silently rewriting old evidence.

## Automated contributions

AI, agents, scripts, and factories must follow the same review, evidence, rights, licensing, security, and authority requirements as human contributors. Generated scale does not expand authority.

## Rights

Do not submit material without authority to submit it. Acceptance does not automatically create compensation, ownership, joint authorship, confidentiality, partnership, certification, or rights in unrelated CrownThrive Material. Additional written rights instruments may be required.

## Validation

Run the repository baseline and scope-specific tests applicable to the change. At minimum where relevant:

```bash
python scripts/validate_registry.py
python scripts/validate_integration_mesh.py
python -m unittest discover -s tests -v
```

A merged change is source acceptance for its scope; it is not automatic proof of external deployment, provider certification, legal status, payment, entitlement, or commercial activation.
