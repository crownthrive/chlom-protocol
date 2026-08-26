# CrownThrive Phase 3 Bounded-Write Certification v3

Current institutional contract: `ct.policy.phase3-bounded-write-certification.v3`.

This layer is additive. It does not delete, overwrite, or reinterpret earlier provider certifications. Previous runtime versions remain historical evidence; current provider-write decisions are made at the operation level.

## Promotion requirements

A provider operation may become `verified_write` only when all applicable controls are proven: verified credential custody, explicit operation/risk classification, bounded input scope, idempotency or a documented non-applicable append-only condition, rollback/compensating action or a documented non-destructive append-only condition, read-after-write verification, durable audit evidence, and an endpoint allowlist that does not implicitly authorize arbitrary writes.

A service-level `write_gate=true` means only that at least one operation has passed the v3 certificate. It does **not** grant provider-wide mutation authority. The verified operations remain enumerated in `services.metadata.verified_write_operations`; universal delete, arbitrary admin mutation, D3 auto-promotion, money movement, payout/refund, credential mutation, and other irreversible actions remain outside this automatic lane.

## Current result

`thrivetools_seo:audits.create` is Phase 3 `verified_write`. Existing provider evidence shows HTTP 201 acceptance followed by HTTP 200 exact read-after-write verification for audit id 67. The v3 contract therefore permits only `audits.create` for hosts already in the governed SEO website inventory.

The following remain explicit Phase 3 candidates/blocks until missing controls are independently proven: Adserver.Online/AdLuxe, CrownLytics, Locticians, Partnero, Reward Loyalty, Stripe general provider mutations, ThrivePush, ThriveTools OPT, and CrownThrive Sites Mesh. SoundCloud remains retired.

## Automation

ThriveBase job `ct-phase3-bounded-write-convergence-v3` evaluates the certificate ledger every five minutes. It can promote only certificates already marked `verified_write`; it cannot manufacture missing provider authority.

## Phase 3 runtime discovery

Newly observed runtime assets are registered in `integration_control.phase3_runtime_assets_v3` under current contract `v3`, including Google Cloud control, Cloud Functions control, API Keys control, Maps key routing, Google sales research, CHLOM publication worker/bridge, factory compiler/planner/property binder, external-surface fail-closed adapter, and the Phase 3 hard-exit snapshot. Registry presence never implies provider privilege.

## Public proof

Sanitized runtime proof: `https://tzajnzshmtzjenqulehq.supabase.co/functions/v1/crownthrive-phase3-proof`

The public proof intentionally exposes certification state and guardrails but no credentials, provider payloads, private identities, or destructive controls.
