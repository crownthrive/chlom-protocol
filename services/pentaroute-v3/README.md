# PentaRoute v3

PentaRoute is the CrownThrive Phase 3 governed routing, transport, liveness, and bounded-recovery family.

## Current-state doctrine

CHLOM's current operating architecture is cloud-first, API-first, event-driven, multi-tenant, and human-governed. DAIL means **Decentralized Autonomous Information Ledger**. Historical blockchain, token, DAO, ZK, validator, bridge, and public-settlement designs remain gated target architecture unless verified by current production evidence.

PentaRoute operates inside that current-state architecture. It does not manufacture legal authority, provider authority, licensing authority, economic authority, or destructive authority.

## Core routing components

- PentaRoute — routing orchestrator
- PentaTun — runtime execution
- PentaBeata — heartbeat and liveness
- PentaFetch — bounded fetch
- PentaGet — GET
- PentaHead — HEAD
- PentaOptions — OPTIONS
- PentaPost — POST
- PentaPut — PUT
- PentaPatch — PATCH
- PentaDelete — DELETE only where an exact operation is separately certified

The runtime registry now extends beyond the original transport verbs into Phase 3 primitives for discovery, inspection, validation, authorization, queueing, retry, reconciliation, testing, certification, deployment, rollback, release, vaulting, auditing, scheduling, publishing, and related bounded operations. Runtime status is authoritative for the current component count.

## Phase 3 autonomy

**PentaRoute Autonomy** is the self-executing supervisory layer for PentaRoute, Software Factory continuity, and Phase 3 bounded-provider convergence.

- service: `ct.pentaroute.autonomy.v3`
- agent: `ct.penta.agent.route` / **PentaRoute Agent**
- agent autonomy ceiling: `A2`
- decision ceiling: `D2`
- self approval: `false`
- D3: human-governed
- universal delete: `false`
- provider authority manufacture: `false`
- money movement authority: `false`

The supervisor runs every five minutes through pg_cron job `ct-pentaroute-autonomy-v3` and calls `integration_control.pentaroute_autonomy_cycle_v3()`.

It supervises only this exact critical scheduler allowlist:

- `ct-software-factory-dispatch-v3`
- `ct-software-factory-continuity-v5`
- `ct-software-factory-tick-v2`
- `ct-phase3-self-discovery-v3`
- `ct-phase3-bounded-write-convergence-v3`
- `pentabeata-heartbeat-v3`

If one of those jobs is missing, disabled, stale, or failed, PentaRoute Autonomy can recreate/reactivate it from a hard-coded canonical schedule and dispatch only the matching hard-coded recovery function. It does not accept arbitrary SQL or arbitrary provider commands.

See [AUTONOMY_V3.md](./AUTONOMY_V3.md) for the complete control contract and production proof.

## Contract and authorization

All Phase 3 PentaRoute components are registered in ThriveBase under `integration_control.pentaroute_components_v3` and `integration_control.phase3_runtime_assets_v3`.

Read routes must resolve to a registered CrownThrive service. Mutation routes must additionally match:

1. an exact operation-level Phase 3 `write_verified` certificate;
2. the exact HTTP method;
3. the exact endpoint-catalog path;
4. an open service write gate; and
5. a maximum automatic risk class of D2.

D3 remains human-governed. Rights grants, enforcement decisions, live economics, protected-data disclosure, and destructive actions remain human-governed. PentaDelete does not provide universal delete authority.

The underlying PentaRoute authorization, catalog, receipt, status, and Phase 3 discovery RPCs are service-role restricted. External/runtime access is expected to traverse governed service surfaces rather than raw anonymous database execution.

## Runtime and liveness

PentaTun routes only to active Phase 3 runtime assets.

PentaBeata runs every five minutes through pg_cron job `pentabeata-heartbeat-v3`.

PentaRoute Autonomy writes a private evidence receipt for each supervisory cycle to `integration_control.pentaroute_autonomy_runs_v3`, including scheduler checks, recovery results, and current PentaRoute, Phase 3, and Software Factory snapshots.

## Control surfaces

- PentaRoute: `https://tzajnzshmtzjenqulehq.supabase.co/functions/v1/pentaroute`
- PentaBeata: `https://tzajnzshmtzjenqulehq.supabase.co/functions/v1/pentabeata`
- PentaRoute Autonomy: `https://tzajnzshmtzjenqulehq.supabase.co/functions/v1/pentaroute-autonomy-v3`

The autonomy Edge Function requires JWT verification. Scheduled self-execution is database-native through pg_cron and therefore does not depend on the HTTP control surface remaining available.

## Production proof — 2026-08-26

After PentaRoute Autonomy was registered and executed:

- autonomy cycle: `OPERATIONAL`
- stale critical schedulers: `0`
- emergency scheduler repairs required: `0`
- PentaRoute: `OPERATIONAL`
- active registered components: `52`
- Phase 3 controller: `ACTIVE_AUTONOMOUS`
- active Phase 3 lanes: `15`
- self-discovery lanes: `14`
- verified lanes: `1`
- factory certification queue: `15`
- factory pending: `14`
- factory certified: `1`
- `universal_delete=false`
- `uncertified_mutations=false`
- `d3_human_governance=true`

These counts are deployment-time evidence, not permanent constants. Query live status surfaces for current values.

## Source files

- `autonomy.ts` — deployed PentaRoute Autonomy Edge Function source
- `AUTONOMY_V3.md` — institutional handoff and operating contract
- `../../migrations/20260826_pentaroute_phase3_autonomy_v3.sql` — database registration, self-execution, evidence, and RPC hardening
