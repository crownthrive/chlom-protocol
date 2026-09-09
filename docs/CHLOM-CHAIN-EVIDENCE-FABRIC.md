# CHLOM Chain Evidence Fabric v1.1

## Operating role

The CHLOM Chain Evidence Fabric is CrownThrive's governed blockchain access and
evidence plane. It gives CHLOM, PentaBound, DAIL, PentaPay, PentaTreasury,
PentaCosts, PentaRelease, PentaRoute, and authorized ecosystem runtimes one
interoperable interface for bounded chain reads and independently reproducible
evidence.

The production architecture is deliberately framework-neutral: a static Vercel
control surface is paired with native Vercel Functions. This matches the
existing Vercel project's deployment classification and prevents a successful
build from being mistaken for a routable runtime.

## Interfaces

- `/api/health` — public, non-secret readiness readback.
- `/api/v1/rpc` — bearer-protected, server-configured JSON-RPC.
- `/api/v1/analytics` — bearer-protected Google Blockchain Analytics templates.
- `/api/v1/attest` — bearer-protected, non-broadcast anchor intent creation.
- `/api/mcp` — bearer-protected stateless Streamable HTTP MCP endpoint.

## Liveness and readiness

Provider liveness and data-plane readiness are separate states. A Vercel
production or preview deployment may truthfully report `OPERATIONAL` while
`readinessStatus` remains `CONFIGURATION_HOLD`. The `X-CHLOM-Readiness` header
and explicit hold list identify missing API, provider, governance, or ECAC
bindings without turning a valid control-plane deployment into a false failure
or a false pass.

## Current MCP contract

The primary MCP protocol is `2026-07-28`. It is stateless and implements
`server/discover`, per-request protocol metadata, deterministic tool listings,
`MCP-Protocol-Version`, `Mcp-Method`, and `Mcp-Name` validation. Origin headers
are validated to reduce DNS-rebinding exposure. A constrained
`2025-11-25` initialization fallback remains for older clients.

MCP tools:

- `chlom_provider_status`
- `chlom_chain_read`
- `chlom_verify_transaction`
- `chlom_query_blockchain_analytics`
- `chlom_prepare_evidence_anchor`

No MCP tool broadcasts transactions or accepts private keys.

## Google architecture

Google Blockchain Analytics through BigQuery is the durable Google lane.
Google Blockchain RPC and Blockchain Node Engine are represented only as
transitional adapters because their published shutdown date is 2026-12-15.

Production Google authentication uses Vercel OIDC and Google Cloud Workload
Identity Federation. The Vercel subject token is minted for the exact Google
workload-provider audience before STS exchange. The runtime does not require a
long-lived service-account JSON key.

Required Google values:

- `GCP_PROJECT_ID`
- `GCP_PROJECT_NUMBER`
- `GCP_SERVICE_ACCOUNT_EMAIL`
- `GCP_WORKLOAD_IDENTITY_POOL_ID`
- `GCP_WORKLOAD_IDENTITY_POOL_PROVIDER_ID`
- `GCP_BIGQUERY_LOCATION`

## Cost and query controls

The analytics API accepts predefined templates only. Arbitrary SQL is not
accepted. Queries use named parameters, partition-aware timestamp filters,
bounded row limits, bounded lookback windows, and
`CHLOM_BIGQUERY_MAX_BYTES_BILLED`.

## RPC provider controls

RPC provider selection is server-side and environment-bound. Requests cannot
supply arbitrary endpoints. The default priority is QuickNode,
CrownThrive-managed custom endpoint, transitional Google RPC, Alchemy, then
Infura. Missing providers produce a configuration hold.

Read-only methods are allowlisted. Administrative, debug, personal, engine,
miner, and transaction-pool namespaces are prohibited.

`eth_sendRawTransaction` is unreachable unless all three controls converge:

1. `CHLOM_CHAIN_WRITE_ENABLED=true`;
2. `CHLOM_GOVERNANCE_STATE=promoted`;
3. the request carries an exact `x-chlom-ecac-digest` matching the active
   environment-bound ECAC digest.

The service does not accept, generate, persist, or expose private keys.

## Evidence and DAIL

Every successful RPC or analytics operation returns source identity, request
and payload digests, an evidence digest, observation time, authority state, and
a deterministic DAIL event type and idempotency key.

The runtime produces a DAIL projection. It does not claim that projection was
persisted until an independently authorized DAIL adapter writes and reads it
back. Anchor preparation likewise does not claim chain publication.
