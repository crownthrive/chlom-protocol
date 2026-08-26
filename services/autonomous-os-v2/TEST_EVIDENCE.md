# CrownThrive Autonomous OS v2 — Verification Evidence

As-of: 2026-08-26T00:28:33Z
Runtime: `ct.autonomous-os.v2` v2.0.1
Proof service: `ct.autonomous-os.v2.proof`

## Independent provider-side test

ThriveBase/Postgres invoked the public proof endpoint through `pg_net` as request id `52`.

Result:
- HTTP status: `200`
- timed out: `false`
- protected runtime reached: `true`
- protected runtime HTTP status: `200`
- runtime state: `OPERATIONAL`

Assertions:
- canonical CHLOM integration registry: PASS
- vault-only credential policy: PASS
- CrownThrive IO/MCP hardcoded `UNLIMITED`: PASS
- AdLuxe / Adserve hardcoded `3,000,000`: PASS
- authenticated CrownThrive API Control: PASS

Transport checks:
- GitHub API: HTTP 200
- U.S. Treasury OFAC SDN Advanced XML: HTTP 200
- CrownThrive IO: HTTP 200
- Adserve Online: HTTP 200

Internal control-plane readback:
- service: `ct.integration.api-control.v4.1`
- authenticated: `true`
- MCP protocol: `2026-07-28`
- write operations enabled by that read control plane: `false`

## Continuous execution

ThriveBase pg_cron job `152`, named `ct-autonomous-os-v2-proof-heartbeat`, invokes the public proof endpoint hourly at minute 17.

The separate GitHub Integration Runtime Certification workflow continues to run on its own schedule as a second failure-domain verification path.

## Public proof endpoint

`https://tzajnzshmtzjenqulehq.supabase.co/functions/v1/crownthrive-autonomous-os-v2-proof`

This endpoint is intentionally read-only and returns sanitized verification data. The protected runtime remains JWT-gated.
