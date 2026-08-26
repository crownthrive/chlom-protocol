# CrownThrive Services Stack — Repair Verification

Verified: 2026-08-26T02:09:33.120Z

## Root cause

Version 6 performed a module-startup read of `./widget.html`, while the deployed Edge Function bundle contained only `index.ts`. The absent resource caused the worker to terminate before request handling.

## Repair

Supabase Edge Function `crownthrive-services-stack` was redeployed as deployment version `7`, service version `0.1.1`, with the dashboard resource packaged inline. No external file read is required during module startup.

Deployment SHA-256: `9ceba73d6afe6a822c83ea920f918a9011c157ce0f27ac4707f825d8957c84ff`

## Independent provider-side verification

ThriveBase/Postgres invoked the public sanitized proof endpoint through `pg_net` as request id `265`.

- HTTP status: `200`
- timed out: `false`
- error: `null`
- healthy: `true`
- protected runtime reached: `true`
- protected health HTTP status: `200`
- service version: `0.1.1`
- startup resource safe: `true`
- widget packaging: `INLINE`
- `tools/list`: HTTP `200`
- tool count: `12`
- `resources/list`: HTTP `200`
- resource count: `1`
- `resources/read`: HTTP `200`
- declared widget bytes: `672`
- returned widget bytes: `672`
- secret exposed: `false`
- provider write enabled: `false`

The four protected-runtime calls made by the proof service also appear in Supabase Edge logs as HTTP `200` against deployment version `7`.

## Public proof

https://tzajnzshmtzjenqulehq.supabase.co/functions/v1/crownthrive-services-stack-proof

The proof surface is read-only and sanitized. The underlying `crownthrive-services-stack` remains JWT-gated.