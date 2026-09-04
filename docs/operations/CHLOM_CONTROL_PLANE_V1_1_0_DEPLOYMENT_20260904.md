# CHLOM Control Plane v1.1.0 — Production Deployment

**Observed:** 2026-09-04 15:09:19 UTC  
**Release state:** `BOUNDED_OPERATIONAL`  
**Authority:** CrownThrive, LLC  
**System:** CHLOM — Compliance Hybrid Licensing and Ownership Model

## Production cutover

The production Edge Function `chlom-control-plane-v1` is active in ThriveBase project `tzajnzshmtzjenqulehq` as provider version `4`. The deployed bundle SHA-256 is `b1426595021a29106b7f10e344527a390af1f1ed36becb645ed5c1dcddaad540`. Provider JWT verification is enabled.

Gateway version `1.1.0` invokes `ct.chlom.authenticated-control-plane-dispatch.v3`. Dispatcher v3 repairs the read-path incompatibility in v2: `status` and `capabilities` are bounded, authenticated reads without mutation idempotency keys; mutation actions require a 16–128 character idempotency key, apply transaction-scoped advisory locking, detect payload conflicts, and return the first persisted result on a valid replay.

## Provider boundary proof

| Test | Result |
| --- | --- |
| Unauthenticated `GET /status` | HTTP `401`, `UNAUTHORIZED_NO_AUTH_HEADER` |
| CrownThrive-origin `OPTIONS /dispatch` | HTTP `204`; gateway `1.1.0`; dispatcher v3 headers present |
| Unapproved-origin `OPTIONS /dispatch` | HTTP `403`, `ORIGIN_DENIED` |
| Provider state | `ACTIVE` |
| `verify_jwt` | `true` |

## Authenticated mutation and replay canary

The database-authenticated founder context executed `register_asset_binding` through dispatcher v3 using idempotency key `ct.canary.chlom.gateway.v1.1.0.20260904.01`.

- Binding ID: `a20e8ac0-4a7c-4651-8906-9577216a3cdf`
- Binding record SHA-256: `02f2385b3fcfd15ed69f72c0653874faa36b283d312da104640e1a42e827bc29`
- Dispatch request ID: `81b8ac87-9ce5-4943-9f77-2852af406c32`
- Dispatch receipt ID: `fdc799fa-0c8a-4d8c-a803-fe9cd25588d0`
- Idempotency response SHA-256: `da00654e853d76800f11fa6cd9afe3d0a308f039f29aab727fcc86ff56946f53`
- First execution: `idempotent_replay=false`
- Second execution: `idempotent_replay=true`
- Duplicate domain mutations: `0`

The domain event was DAIL sequence `2323191`; the dispatch receipt was sequence `2323192`.

## Deployment registry

Gateway deployment version `2` was persisted under `ct.gateway.chlom-authenticated-gateway-v1`.

- Deployment manifest SHA-256: `07f55628b2c66dda701c758c55273cdad85272348a744160ba275f5fb26df432`
- Registry DAIL event: `165c80b0-eb08-43e1-a17a-e5f157e4af6e`
- Registry DAIL sequence: `2323281`
- Registry DAIL event hash: `b06d038e83cb756433b2a604f76829a4ebae51d239a7ed6eb4dc65567782b703`

## DAIL assurance

Post-deployment catch-up returned `PASS_GLOBAL_COMPACT_CHAIN` with sequence lag `0`, verified through sequence `2323298`, current head sequence `2323298`, and base checkpoint `dfb2018c-7dba-4200-b8af-16951efd4cc8`.

## Explicit exclusions

This release does not move money, confirm a production token mint, activate tokenomics, activate validators, confirm a public-chain anchor, or adjudicate legal title. External execution remains disabled. A real browser- or application-issued founder session still must be exercised for the separately classified `EXTERNAL_SIGNED_SESSION_CANARY`; the authenticated database-context canary is not mislabeled as that provider session.
