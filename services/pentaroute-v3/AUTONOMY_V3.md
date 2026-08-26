# PentaRoute Phase 3 Autonomy

Status: `ACTIVE_AUTONOMOUS`

Service: `ct.pentaroute.autonomy.v3`

Agent: `ct.penta.agent.route` / **PentaRoute Agent**

Autonomy ceiling: `A2`

Decision ceiling: `D2`

## Purpose

PentaRoute Autonomy is the Phase 3 supervisory control surface for CrownThrive routing, factory continuity, bounded provider discovery, certification convergence, and runtime liveness. It does not replace the existing Software Factory or Phase 3 takeover controller. It supervises those existing rails and re-enters them when a known critical scheduler is absent, disabled, stale, or failed.

This implementation follows the current CHLOM operating baseline: cloud-first, API-first, event-driven, multi-tenant, and human-governed. DAIL means **Decentralized Autonomous Information Ledger**. Historical blockchain, DAO, token, ZK, bridge, validator, and public-settlement concepts remain gated target architecture unless independently evidenced as current production truth.

## Self-execution loop

`ct-pentaroute-autonomy-v3` runs every five minutes through `pg_cron` and executes `integration_control.pentaroute_autonomy_cycle_v3()`.

The cycle supervises the following exact scheduler allowlist:

1. `ct-software-factory-dispatch-v3` — every minute
2. `ct-software-factory-continuity-v5` — every two minutes
3. `ct-software-factory-tick-v2` — every five minutes
4. `ct-phase3-self-discovery-v3` — every five minutes
5. `ct-phase3-bounded-write-convergence-v3` — every five minutes
6. `pentabeata-heartbeat-v3` — every five minutes

For each scheduler the supervisor:

1. Verifies the job exists.
2. Recreates only a missing job using its hard-coded canonical schedule and command.
3. Reactivates only a known disabled job.
4. Checks last successful execution and latest status.
5. If stale or failed, invokes only the matching hard-coded recovery function.
6. Records the result and current Phase 3 / PentaRoute / factory snapshots.

There is no dynamic SQL execution path, arbitrary command injection path, universal administrative mutation path, or provider-authority manufacture path in this supervisor.

## Evidence and continuity

Every autonomy cycle writes a receipt to:

`integration_control.pentaroute_autonomy_runs_v3`

The private run record includes:

- start and completion timestamps
- operational/degraded/error state
- healed schedulers
- stale schedulers
- per-scheduler liveness and recovery evidence
- Phase 3 snapshot
- PentaRoute snapshot
- Software Factory certification-queue snapshot
- guardrail metadata

The table is private by default. Direct anonymous and authenticated execution is not granted. Service-role access is used by the governed control surface.

## Runtime registration

PentaRoute Autonomy is registered in:

- `penta_runtime.agent_registry_v1`
- `integration_control.pentaroute_components_v3`
- `integration_control.phase3_runtime_assets_v3`

The agent has no vote eligibility and cannot self-approve.

## Control surface

Supabase Edge Function: `pentaroute-autonomy-v3`

- `GET` returns autonomy status through the service-role RPC path.
- `POST {"action":"cycle"}` requires a service-role JWT and invokes one bounded supervisory cycle.
- Scheduled autonomy does **not** depend on the Edge Function. The five-minute control loop runs database-native through `pg_cron`, so loss of the HTTP surface does not stop self-execution.

## Mandatory guardrails

PentaRoute Autonomy may automatically operate only through previously established A2/D2 controls.

It may not:

- grant rights or licenses
- make legal/compliance determinations
- move money or activate live economics
- disclose protected data
- approve its own work
- manufacture provider authority
- perform universal delete
- execute arbitrary destructive actions
- promote D3 operations
- bypass exact provider-operation certification

D3, rights grants, enforcement decisions, live economics, destructive actions, and protected-data disclosure remain human-governed.

## Production proof — 2026-08-26

Initial autonomous cycle result:

- state: `OPERATIONAL`
- healed schedulers: `0`
- stale schedulers: `0`
- critical schedulers healthy: `6/6`
- PentaRoute state: `OPERATIONAL`
- active registered PentaRoute components after autonomy registration: `52`
- Phase 3 controller: `ACTIVE_AUTONOMOUS`
- Phase 3 active lanes: `15`
- self-discovery lanes: `14`
- verified lanes: `1`
- factory certification queue: `15`
- factory pending: `14`
- factory certified: `1`

These counts are a deployment-time proof, not a permanent architecture constant. Query the live status surfaces for current counts.

## Source/runtime relationship

The runtime is authoritative for observed production state. This repository is the durable implementation and doctrine record. If repository prose and verified runtime evidence conflict, record the difference, preserve history, and reconcile through the governed change path rather than silently rewriting evidence.
