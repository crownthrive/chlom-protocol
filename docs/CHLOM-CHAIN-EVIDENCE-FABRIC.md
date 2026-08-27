# CHLOM Chain Evidence Fabric v1

## Purpose

The CHLOM Chain Evidence Fabric is the governed blockchain access and evidence
plane for CrownThrive. It gives CHLOM, PentaBound, DAIL, PentaPay,
PentaTreasury, PentaCosts, PentaRelease, PentaRoute, and authorized ecosystem
runtimes one interoperable interface for:

- bounded, provider-neutral blockchain JSON-RPC reads;
- Google Blockchain Analytics queries through BigQuery;
- deterministic evidence envelopes and DAIL projections;
- transaction verification;
- MCP tools and versioned REST contracts;
- preparation of non-broadcast evidence anchor intents.

The runtime never infers authority from a configured endpoint, API key,
successful provider response, repository merge, or deployed function.

## Provider strategy

Google Blockchain Analytics through BigQuery is the durable Google integration.
Google Blockchain RPC and Blockchain Node Engine are represented only as
transitional adapters because their published shutdown date is 2026-12-15.

RPC provider selection is server-side and environment-bound. Requests cannot
supply arbitrary endpoints. The default priority is QuickNode, CrownThrive
custom endpoint, transitional Google RPC, Alchemy, then Infura. A missing
provider produces a fail-closed configuration hold.

## Google authentication

Production uses Vercel OIDC and Google Cloud Workload Identity Federation.
No service-account JSON key is required or accepted by the runtime.

Required values:

- `GCP_PROJECT_ID`
- `GCP_PROJECT_NUMBER`
- `GCP_SERVICE_ACCOUNT_EMAIL`
- `GCP_WORKLOAD_IDENTITY_POOL_ID`
- `GCP_WORKLOAD_IDENTITY_POOL_PROVIDER_ID`
- `GCP_BIGQUERY_LOCATION`

The service account requires the minimum BigQuery permissions needed to create
query jobs in the billing project and read the selected public datasets.

## Cost controls

The analytics API accepts predefined query templates only. Arbitrary SQL is not
accepted. Queries use named parameters, bounded row limits, bounded lookback
windows, partition filters where applicable, and
`CHLOM_BIGQUERY_MAX_BYTES_BILLED`.

## Write boundary

Read-only JSON-RPC methods are allowlisted. Administrative, debug, personal,
engine, miner, and transaction-pool namespaces are prohibited.

`eth_sendRawTransaction` is unreachable unless all three conditions converge:

1. `CHLOM_CHAIN_WRITE_ENABLED=true`;
2. `CHLOM_GOVERNANCE_STATE=promoted`;
3. the request carries an exact `x-chlom-ecac-digest` matching the active
   environment-bound ECAC digest.

The service does not accept, generate, persist, or expose private keys.

## Evidence

Each successful RPC or analytics operation returns:

- source/provider/chain/operation identity;
- request digest;
- payload digest;
- evidence digest;
- observed timestamp;
- authority state;
- endpoint fingerprint when applicable;
- deterministic DAIL event type and idempotency key.

The v1 runtime returns the DAIL projection but does not manufacture a database
write. A later DAIL adapter must independently persist and read back the
projection under its own authority.

## MCP

The production MCP endpoint is:

`https://chlom-protocol.vercel.app/api/mcp`

Registered tools:

- `chlom_provider_status`
- `chlom_chain_read`
- `chlom_verify_transaction`
- `chlom_query_blockchain_analytics`
- `chlom_prepare_evidence_anchor`

The MCP endpoint is stateless and protected by the same CHLOM bearer perimeter
as the REST API.
