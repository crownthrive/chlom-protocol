# PentaPolicy / PentaPolice / PentaGovernance v1

## Canonical flow

`PentaPolicy -> PentaGovernance -> PentaPolice`

PentaPolicy authors, versions, classifies, and routes policy. PentaGovernance ratifies D3/live authority. PentaPolice enforces only policy valid for the current authority mode and emits enforcement receipts.

## Authority model

- Development, testing, and certification are bounded to D2 or lower.
- A requested D3 policy is automatically reduced to D2 while operating in development/testing/certification mode.
- D3 becomes effective only in live mode and remains subject to PentaGovernance ratification and reserved human authority.
- PentaPolice cannot create policy or manufacture authority.
- PentaPolicy cannot self-ratify D3.
- PentaGovernance returns a ratification reference downstream; PentaPolice then enforces the ratified policy.

## Self-Funding Business Engine binding

`ct.self_funding_engine.v1` is currently `D2/testing`, with `live_authority=false` and production money movement blocked.

The canonical lifecycle policy is `ct.policy.self_funding_engine.lifecycle.v1`.

Testing permits simulation, allocation testing, certification, readback, reconciliation dry runs, and refund/dispute dry runs. Live settlement requires an explicit founder live directive, transition to D3, governance ratification, and downstream PentaPolice enforcement.

## Runtime tables

- `penta_policy_authority_modes`
- `penta_policy_proposals`
- `penta_policy_ratifications`
- `penta_police_enforcement_receipts`

## Runtime functions

- `penta_policy_effective_risk_v1`
- `penta_policy_propose_v1`
- `penta_governance_ratify_policy_v1`
- `penta_police_enforce_v1`

All write/decision RPCs are service-role-only and the tables are protected by RLS.
