# PentaWorkforce OS™ v1

**Status:** Production database foundation  
**Phase:** CrownThrive Phase 3  
**Runtime:** ThriveBase / Supabase Postgres  
**Exposure:** Server-only, private-by-default  
**Authority rule:** Penta systems may exercise authority that already exists; they may never manufacture authority.

## Purpose

PentaWorkforce OS™ is CrownThrive's governed living workforce and agent-operating environment. It turns the Penta family into an institutional chain of command, workforce experience, accountability system, cost-control layer, feedback system, escalation path, and evidentiary operating record instead of a collection of disconnected agent names.

It is additive to CHLOM, PentaRFA, PentaSuite, PentaHybrid, the Penta interface contract, and the existing `penta_system_registry`. It does not replace lease authority, CHLOM governance, provider permissions, rights controls, or founder/human authority boundaries.

## Canonical chain of command

| Rank | System | Institutional function | May issue |
| ---: | --- | --- | --- |
| 500 | PentaBoard™ | Ecosystem governance | Directives |
| 450 | PentaLegal™ | Cross-cutting legal-control gate | Legal holds and legal advisories |
| 400 | PentaDirectors™ | Supervision of all lower operating ranks | Policies, SOPs, SLAs |
| 350 | PentaHR™ | Cross-cutting workforce lifecycle control | Policy-governed HR cases/actions |
| 300 | PentaManagers™ | Direct management of agents/workers | Bounded contracts and task orders |
| 200 | PentaCohorts™ | Mission/team operating units | No independent higher authority |
| 100 | PentaWorkers™ | Agent/service/human execution layer | Executes assigned authority only |

`PentaBoard™ -> PentaDirectors™ -> PentaManagers™ -> PentaCohorts™ -> workers/agents` is the ordinary supervisory chain. PentaLegal™ and PentaHR™ are cross-cutting controls with explicit boundaries; their placement does not create permission to bypass CHLOM or valid higher authority.

## Living-environment systems

### PentaCohorts™
Creates governed, time-bounded mission teams with a manager, contract instrument, purpose, membership, state, and measurable success criteria. Cohort membership never raises an agent's authority ceiling.

### PentaAccelerator™
Tracks nomination, screening, acceleration, graduation, pause, and exit. Progression is evidence-based. Graduation may recommend a new role or lease but cannot silently expand scope, TTL, provider permissions, risk ceiling, or decision authority.

### PentaNotes™
Captures feedback, proposals, breakdowns, wins, luck signals, risks, commendations, process gaps, and incident observations. Notes carry evidence references, visibility, lifecycle state, and optional votes.

Voting is deliberative evidence. A vote is never self-executing punishment, pay action, contract revocation, access revocation, or authority change.

### PentaTriage™
Routes breakdowns and incidents into P0-P4 cases with accountable owners, evidence, containment/remediation states, and destination systems. Triage can contain and route conditions; final disciplinary, legal, financial, or authority consequences still require the proper instrument.

### PentaHealth™
Tracks agent/runtime health, workload, safety, availability, heartbeat, capacity, and error rate. The v1 schema explicitly disallows medical data. It is not a diagnostic system and does not make protected-health-based employment, benefit, or governance decisions.

### PentaHR™
Tracks onboarding, offboarding, role changes, grievances, conduct/performance cases, accommodation routing, and policy acknowledgements. Governed actions require policy/evidence and preserve review or appeal when applicable.

### PentaBenefits™
Tracks policy-backed eligibility and entitlement state. It is an entitlement ledger, not an authority to promise unauthorized compensation, coverage, or economic value.

### PentaPay™
Tracks compensation eligibility, approvals, holds, externally completed payment receipts, stipends, fees, milestones, royalty accruals, reimbursements, credits, and adjustments. PentaPay™ does **not** move money in v1. Self-approval is prohibited and `provider_money_movement` is constrained to false.

### PentaCost™
Provides budget scopes, soft limits, hard limits, commitments, spends, releases, and refunds. The database locks the applicable budget row and fails closed when committed plus spent value would exceed the hard limit. PentaCost™ controls abuse but cannot invent spend authority.

### PentaLegal™
Provides bounded legal holds and legal advisories in the governance-instrument system. It does not claim an attorney-client relationship, court authority, completed filing, legal registration, or final legal conclusion without independent evidence.

## Governance instruments

The database enforces issuer separation:

- PentaBoard™ can issue `directive`.
- PentaDirectors™ can issue `policy`, `sop`, and `sla`.
- PentaManagers™ can issue `contract` and `task_order` and must name a target.
- PentaLegal™ can issue `legal_hold` and `legal_advisory`.
- Non-legal instruments cannot bind an equal or higher authority rank.
- An issuer assignment and issuer role must both be active at write time.
- Self-approval is prohibited where approval is modeled.

## Feedback, ramifications, and due process

`penta_notes` and `penta_note_votes` create the feedback/deliberation layer. `penta_ramifications` creates the consequence/remedy layer.

Positive outcomes such as recognition and accelerator nomination may be recorded directly. Remediation, restriction, contract review, cost hold, or pay hold require an authority instrument. Restrictive ramifications must preserve appeal availability. Evidence references and an auditable state machine are retained so outcomes can be reviewed, reversed, or completed without rewriting history.

## Existing-system bindings

PentaWorkforce OS™ binds to existing CrownThrive systems rather than replacing them:

- **CHLOM** remains the higher-order rights, governance, licensing, compliance, and authority envelope.
- **PentaRFA™** remains the request path for new agent authority/lifecycle requests.
- **PentaSuite™** remains the bounded lease/TTL source for generated agents.
- **PentaHybrid™** remains a human/agent decision surface where already authorized.
- **Penta system registry** remains the canonical machine-readable registry of Penta systems.
- Existing PentaSuite leases are mirrored as workforce subjects/worker assignments with `authority_inherited=false`; reconciliation cannot increase their lease authority.

## Data model

The v1 production foundation adds 21 governed tables:

`penta_workforce_system_state`, `penta_workforce_roles`, `penta_workforce_subjects`, `penta_workforce_units`, `penta_workforce_assignments`, `penta_governance_instruments`, `penta_cohorts`, `penta_cohort_members`, `penta_notes`, `penta_note_votes`, `penta_triage_cases`, `penta_health_snapshots`, `penta_hr_cases`, `penta_benefit_entitlements`, `penta_pay_entries`, `penta_cost_budgets`, `penta_cost_events`, `penta_accelerator_records`, `penta_ramifications`, `penta_mark_registry`, and `penta_workforce_events`.

All are RLS-enabled. `anon` and `authenticated` table privileges are revoked. No client-facing RLS policies are created in v1 because the sensitive workforce layer is intentionally service-role/server-only. Public exposure requires a later bounded interface contract and explicit authorization.

## Runtime guardrails

1. No authority manufacture.
2. No self-approval.
3. No direct money movement.
4. No medical decisioning.
5. Notes/votes do not self-execute punishment.
6. Restrictive ramifications preserve appeal.
7. PentaCost™ hard caps fail closed.
8. Manager contracts/task orders require targets.
9. Equal-or-higher-rank binding is rejected for ordinary instruments.
10. PentaSuite lease reconciliation never expands authority.
11. Sensitive tables remain server-only by default.
12. Every material lifecycle change should emit or retain an auditable reference.

## Operating loop

The canonical loop is:

`PentaBoard directive -> PentaDirector policy/SOP/SLA -> PentaManager contract/task order -> PentaCohort/worker execution -> PentaNotes/PentaHealth/PentaCost/PentaPay telemetry -> PentaTriage when needed -> authorized ramification/remedy/appeal -> audit/learning -> policy or contract refinement`.

This is the institutional feedback loop that makes the Penta environment adaptive while preserving chain-of-command discipline.

## Trademark and naming policy

PentaWorkforce OS™ uses `penta_mark_registry` to preserve the canonical Penta family and render current claimed Penta marks with `™`. The registry is seeded from every current `penta_system_registry` canonical name beginning with `Penta`, so wrapped or composed uses retain the underlying Penta mark identity instead of dropping it.

The internal registry is **not** a USPTO filing or a claim of federal registration. `®` is prohibited by database constraint unless the mark is recorded as registered and a registration number is present. Until independently verified registration exists, use `™` (or `SM` where deliberately designated for a service mark) rather than `®`.

Canonical notice: `Penta*™ marks are claimed marks of CrownThrive, LLC. Use of ™ denotes a claimed mark and does not represent federal registration. Registered-symbol usage requires independently verified registration.`

## Production verification

The provider migration `penta_workforce_os_v1` was applied to the CrownThrive ThriveBase project on 2026-08-26. Post-apply verification showed seven active authority roles, five bootstrap governance subjects/assignments, the active bootstrap Board directive, server-only RLS posture, and 23 current Penta-family marks with zero records using the registered symbol.

Negative-control checks also passed: a Board attempt to issue a Director-owned policy was rejected, and a test spend above a PentaCost™ hard limit was rejected with no verification residue persisted.

## Source replay order

For source-controlled replay, apply these files in order:

1. `migrations/penta_workforce_os_v1/001_tables.sql`
2. `migrations/penta_workforce_os_v1/002_guardrails.sql`
3. `migrations/penta_workforce_os_v1/003_bootstrap_registry.sql`
4. `migrations/penta_workforce_os_v1/004_marks_reconciliation.sql`

The four ordered segments reproduce the production migration while keeping review units readable.
