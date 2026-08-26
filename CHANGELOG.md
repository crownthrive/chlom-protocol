# CHLOM Changelog

## Phase 3 PentaRoute Autonomy — 2026-08-26

### Self-executing control plane
- Activated `ct.penta.agent.route` as the PentaRoute Agent at A2/D2 with no self-approval, no vote eligibility, no universal delete, and no provider-authority manufacture.
- Added `PentaRoute Autonomy` as a registered Phase 3 runtime component and deployed `pentaroute-autonomy-v3` as the authenticated operational control surface.
- Added database-native five-minute supervision through `ct-pentaroute-autonomy-v3` so self-execution does not depend on the HTTP surface.
- Supervises the existing Software Factory dispatch/continuity/tick, Phase 3 self-discovery/convergence, and PentaBeata heartbeat schedulers rather than creating a duplicate orchestration stack.
- Added exact allowlisted scheduler recreation/reactivation and bounded recovery dispatch for missing, disabled, stale, or failed critical jobs.
- Added private autonomy-cycle evidence receipts with scheduler, PentaRoute, Phase 3, and factory-certification snapshots.
- Restricted raw PentaRoute authorization/catalog/receipt/status and Phase 3 discovery RPC execution to the service role and converted the human catalog view to security-invoker semantics.
- Initial production cycle returned `OPERATIONAL` with zero stale jobs and zero emergency repairs; PentaRoute reported 52 registered active components after the autonomy supervisor was added.
- Preserved current CHLOM doctrine: DAIL = Decentralized Autonomous Information Ledger; cloud/API-first current state; D3, rights, enforcement, live economics, destructive actions, and protected-data disclosure remain human-governed.

## 2.0.0-alpha.1 — 2026-08-17

### Phase 2 recovery baseline
- Reconciled the CHLOM recovery package, 795-title Help Center structure, historical technical corpus, and current CrownThrive operating doctrine.
- Established six canonical functions: Rights, Rules, Roles, Revenue, Records, Remedies.
- Canonicalized DAIL as Decentralized Autonomous Information Ledger and DLA as Dynamic Licensing Asset.
- Preserved legacy DLA authority, DAL, token, DAO, ZK, Substrate, oracle, bridge and smart-treasury designs as historical/target architecture with explicit status labels.
- Added public-safe machine-readable registries, source lineage, lifecycle states, platform integrations, agents, permissions, events, workflows, roadmap and help-center recovery manifest.
- Added human approval gates, append-only correction doctrine, private-by-default evidence rules, validation tests and GitHub change controls.
