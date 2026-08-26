# PentaFederation v1

PentaFederation is the governed Penta-facing federation facade for CrownThrive Federation.

## Runtime contract

- System: `ct.penta.federation.v1`
- Parent: CrownThrive Federation
- Canonical repository parent: `ct.repo.crownthrive-support`
- Canonical state: `institutional_federation`
- Canonical repository transport: `repository-federation-bus`
- Authority ceiling: A2 / D2
- State: `controlled_test`

## Deployed surfaces

- `penta-federation-control` — dedicated JWT-protected HTTP control/read facade.
- `penta-federation-mcp` — dedicated JWT-protected stateless MCP facade.
- `penta-control-v1` — umbrella Penta control surface, with federation functions embedded.
- `penta-mcp-v1` — umbrella Penta MCP surface, with federation tools embedded.

## Dedicated control actions

- `status`
- `member_state`
- `route_plan`

The facade does not expose provider writes, rights grants, money movement, child voting activation, or D3 activation.

## MCP tools

- `penta_federation_status`
- `penta_federation_member_state`
- `penta_federation_route_plan`

`route_plan` is an evaluation surface only. Repository federation writes remain on `repository-federation-bus` and retain GitHub Actions OIDC, repository identity, lifecycle, agent capability, parent-lock, idempotency and evidence controls.

## Database contract

The migration establishes:

- `public.penta_federation_system_state`
- `public.penta_federation_bindings`
- `public.penta_federation_events`
- `public.penta_federation_proofs`
- `penta_runtime.penta_federation_status_v1()`
- `penta_runtime.penta_federation_member_state_v1(text)`
- `penta_runtime.penta_federation_route_plan_v1(text,text,text,text)`
- `penta_runtime.penta_federation_record_event_v1(...)`

Client table access is deny-by-default. Direct privileges are revoked from `anon` and `authenticated`; service runtime access is through `service_role` and governed RPC/Edge surfaces.

## Verification

Runtime/governance proof:

- key: `ct.penta.federation.proof.runtime.v1.2026-08-26`
- result: `PASS`
- score: `1.0`
- SHA-256: `940fb8442dd3f99211c14e28eb9a08632a5bce6868ebbd009346122d664112b5`

The proof records a controlled-test verification, not a production-promotion claim.
