# Penta Democratic Governance™ v1

**Status:** Production foundation  
**Phase:** CrownThrive Phase 3  
**Runtime:** ThriveBase / Supabase Postgres  
**Scope:** Internal CrownThrive/Penta organizational governance  
**Not sovereign government:** These are internal governance mechanisms. They do not create state, court, statutory, provider, contractual, or external legal authority.

## Constitutional placement

PentaWorkforce OS™ remains the living workforce environment. The existing operating chain remains intact:

`PentaBoard™ -> PentaDirectors™ -> PentaManagers™ -> PentaCohorts™ -> workers/agents`

The new governance architecture is built **alongside** that chain rather than replacing it.

- **PentaBoard™** retains expressly reserved/founder/constitutional directive authority already valid inside CrownThrive and CHLOM.
- **PentaExecutive™** is the execution/administration branch. It uses the existing Board-Director-Manager chain to carry out valid directives, enacted internal governance, budgets, appointments, operations, remands, and bounded emergency actions.
- **PentaLegislative™** is the democratic deliberative/enactment branch. It introduces, debates, amends, votes on, confirms, authorizes, and can override internal governance measures within delegated authority.
- **PentaJudicial™** is the independent internal review/adjudication branch. It handles appeals, internal policy/authority disputes, election challenges, due-process claims, disciplinary review, executive review, charter interpretation, stays, remands, reversals, and internal remedies.
- **PentaDemocracy™** is the participatory substrate used across the system: constituencies, eligibility, one-membership/one-vote ballots, direct/representative/hybrid participation, delegation, quorum, initiatives, referenda, confirmation, human ratification, conflict disclosure, recusal, and override mechanics.

## Separation of powers

### Executive

PentaExecutive™ does not add a new supervisory rank. It formalizes the existing administrative chain as an executive branch.

Executive action types include implementation orders, administrative rules, vetoes, appointments, budget execution, remand responses, and time-limited emergency action.

Controls:

- Issuers must have an active PentaBoard™, PentaDirectors™, or PentaManagers™ assignment.
- Executive actions cannot create legislative or judicial authority.
- D2/D3 executive actions automatically require legislative review.
- Emergency actions must expire in **72 hours or less**.
- Emergency actions automatically require **both legislative and judicial review**.
- Executive actors cannot finally adjudicate disputes over their own actions.

### Legislative

PentaLegislative™ is designed for democratic governance by use and affected scope rather than for a single permanent electorate.

Legislative objects include initiatives, acts, policy frameworks, budgets, rules, charter amendments, resolutions, appointment confirmations, and override measures.

The legislative lifecycle supports:

`draft -> introduced -> committee -> debate -> ballot -> passed/failed -> vetoed/overridden -> enacted`

Amendments are separately recorded with proposer, patch, rationale, and disposition.

The legislative branch does **not** manage workers directly and cannot override CHLOM, reserved Board/founder authority, external law, contracts, rights, or provider permissions.

### Judicial

PentaJudicial™ is an independent internal adjudication and review system. It is not a public court and does not claim sovereign or judicial authority outside CrownThrive's internal governance envelope.

Supported case types include appeals, policy review, authority disputes, election challenges, due process, contract disputes, disciplinary review, charter review, and executive review.

Supported dispositions include affirm, reverse, remand, stay, dismiss, interpret, modify, and invalidate an internal action.

Controls:

- A party to a case cannot sit as a judge in that case.
- A declared judicial conflict requires recusal.
- D0/D1 matters require at least one non-recused judge.
- D2/D3 matters require at least **three** non-recused judges.
- Reversal, modification, or invalidation requires an explicit remedy.
- Decisions retain reasoning, holding, precedent scope, appeal deadline, and lifecycle state.

## Democratic substrate

PentaDemocracy™ makes participation contextual. A constituency may represent the whole workforce or only the people/agents materially affected by a policy, contract, budget, cohort, entitlement, right, or governance action.

The v1 foundation provides two initial constituency models:

1. **Penta Workforce Electorate™** — hybrid direct/representative participation across eligible governed workers, agents, representatives, and authorized human participants.
2. **Affected Constituency™** — direct participation by subjects materially affected by the question being decided.

### Voting rules

- One active governance membership = one vote. Database `vote_weight` is constrained to `1`.
- Ballot eligibility is snapshotted before voting.
- Suspended/expired memberships cannot vote.
- Recusal requires a disclosed conflict.
- Quorum and approval ratios are explicit ballot properties.
- D2/D3 ballots **must** set `human_ratification_required=true`.
- Agent/service votes may participate where authorized, but they cannot satisfy required human ratification.
- The tally records human and total participation separately.
- Direct, representative, and hybrid constituency modes are supported.
- Delegation is explicit, scoped, revocable, and time-bounded.

## Checks and balances

The governance database explicitly models:

- executive veto;
- legislative override;
- legislative review;
- appointment confirmation;
- judicial review;
- judicial stay;
- remand;
- charter challenge;
- emergency review;
- no-confidence mechanisms;
- human ratification;
- conflict disclosure and recusal;
- appeal.

Every check is recorded in `penta_checks_balances_events` with initiator, target branch, source authority, evidence, outcome, and resolution reference.

## Relationship to PentaBoard™

PentaBoard™ is not discarded or reduced to a ceremonial role. It remains the CrownThrive governance/directive layer with any valid reserved/founder powers already established by CrownThrive and CHLOM.

The three-branch model exists beneath and alongside that reserved layer so ordinary institutional decisions can be distributed democratically and reviewed rather than concentrated in one operational chain.

A Board directive still cannot manufacture authority that CrownThrive, CHLOM, law, contract, rights, or a provider does not already possess.

## Relationship to PentaDirectors™ and PentaManagers™

PentaDirectors™ and PentaManagers™ remain the operating management structure.

- Directors supervise lower ranks and issue policies/SOPs/SLAs where already authorized.
- Managers issue bounded contracts/task orders to agents and workers.
- The executive branch gives these actions a branch/governance context.
- The legislative branch can authorize or constrain ordinary internal governance within its delegated domain.
- The judicial branch can review disputed internal actions and issue bounded remedies.

No branch silently raises an assignment's existing PentaSuite™, PentaRFA™, CHLOM, provider, risk, money, or rights ceiling.

## Production data model

The three-branch foundation adds 17 internal tables:

- `penta_governance_charters`
- `penta_governance_branches`
- `penta_constituencies`
- `penta_governance_memberships`
- `penta_vote_delegations`
- `penta_legislative_sessions`
- `penta_legislative_items`
- `penta_legislative_amendments`
- `penta_ballots`
- `penta_ballot_eligibility`
- `penta_ballot_votes`
- `penta_executive_actions`
- `penta_appointments`
- `penta_judicial_cases`
- `penta_judicial_panel_members`
- `penta_judicial_decisions`
- `penta_checks_balances_events`

All are RLS-enabled, and direct `anon`/`authenticated` table privileges are revoked. The layer is server-only until a separately governed client interface is authorized.

## Runtime functions

- `penta_runtime.penta_validate_ballot_vote_v1()`
- `penta_runtime.penta_close_ballot_v1(uuid)`
- `penta_runtime.penta_executive_action_guard_v1()`
- `penta_runtime.penta_judicial_panel_guard_v1()`
- `penta_runtime.penta_judicial_decision_guard_v1()`
- `penta_runtime.penta_governance_status_v1()`

## Production verification

Provider migrations were applied to ThriveBase on 2026-08-26.

Verified state:

- Penta Democratic Governance Charter™: active.
- PentaExecutive™: active.
- PentaLegislative™: active.
- PentaJudicial™: active.
- PentaDemocracy™: production registry entry active.
- Two initial constituencies active.
- Governance tables checked are RLS-enabled.
- D2 ballot without human ratification: rejected by database constraint.
- 96-hour emergency action: rejected; emergency TTL ceiling is 72 hours.

## Marks

PentaExecutive™, PentaLegislative™, PentaJudicial™, and PentaDemocracy™ are recorded in `penta_mark_registry` as CrownThrive, LLC claimed marks using `™`. They are **not** represented as federally registered marks. `®` remains prohibited unless registration is independently verified and recorded.
