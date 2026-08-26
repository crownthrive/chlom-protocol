# PentaRoute v3

PentaRoute is the CrownThrive Phase 3 governed routing and transport family.

## Components

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
- PentaDelete — DELETE

## Contract

All components are Phase 3 / contract v3 and are registered in ThriveBase under `integration_control.pentaroute_components_v3` and `integration_control.phase3_runtime_assets_v3`.

Read routes must resolve to a registered CrownThrive service. Mutation routes must additionally match an exact operation-level Phase 3 `write_verified` certificate, exact HTTP method, exact endpoint-catalog path, open service write gate, and a maximum automatic risk class of D2. D3 remains human-governed. PentaDelete does not provide universal delete authority.

PentaTun routes only to active Phase 3 runtime assets. PentaBeata runs every five minutes through pg_cron job `pentabeata-heartbeat-v3`.

## Live proof

- PentaRoute: `https://tzajnzshmtzjenqulehq.supabase.co/functions/v1/pentaroute`
- PentaBeata: `https://tzajnzshmtzjenqulehq.supabase.co/functions/v1/pentabeata`

Independent ThriveBase `pg_net` tests on 2026-08-26 returned HTTP 200 for both PentaRoute and PentaBeata. PentaRoute reported `OPERATIONAL`, Phase 3, contract v3, 11 active components, `universal_delete=false`, `uncertified_mutations=false`, and `d3_human_governance=true`.

Authorization tests also confirmed: registered GET routes are allowed; exact certified `thrivetools_seo/audits.create` POST is allowed after endpoint-catalog reconciliation; attempting to reuse that certificate for DELETE is denied.
