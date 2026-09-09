# PentaFederation™ — Canonical Federation Architecture v1

**Owner:** CrownThrive, LLC  
**Canonical product name:** PentaFederation™  
**Product contract:** `ct.penta.federation.v1`  
**Runtime control plane:** ThriveBase  
**Governance plane:** CHLOM™  
**Canonical parent:** CrownThrive Federation  
**Canonical repository parent:** `ct.repo.CrownThrive-OS` (`crownthrive1/CrownThrive-OS`)  
**State:** controlled test; runtime deployed and verified, production promotion remains governed by the parent PentaFabric/federation release gate.

## Purpose

PentaFederation is CrownThrive's bounded federation governance and routing facade. It gives Penta systems, repositories, services, frameworks and participating runtimes one governed way to discover federation state, inspect member capability, evaluate routes and hand off work to the canonical repository federation transport without creating authority that CHLOM or the parent federation has not granted.

It does **not** replace the existing CrownThrive Federation, `institutional_federation` schema, repository registry or `repository-federation-bus`. Those remain canonical. PentaFederation sits above them as the Penta-facing institutional interface and below CHLOM/PentaFabric authority.

## Canonical topology

```text
D3 Founder / reserved human authority
        |
      CHLOM
        |
   PentaFabric
        |
 PentaFederation
   |     |      |       |        |
   |     |      |       |        +--> CrownLytics (least-data observation)
   |     |      |       +-----------> DAIL (append-only evidence)
   |     |      +-------------------> PentaMesh (routing)
   |     +--------------------------> PentaFramework Factory (candidate handoff)
   +--------------------------------> repository-federation-bus
                                         |
                              institutional_federation
                                         |
                       canonical parent + framework children
```

## Federation identity

- Parent federation identity: **CrownThrive Federation**.
- Canonical repository parent: **CrownThrive-OS**.
- Penta system ID: `ct.penta.federation.v1`.
- Gen-61 governor: `ct.agent.gen61.penta.federation`.
- Institutional DID: `did:chlom:agent:pentafederation_governor`.
- Authority ceiling: A2 / D2.
- Execution mode: `candidate_only`.
- Independent verification is required.

The parent federation and PentaFederation are not synonyms. CrownThrive Federation is the institutional parent topology; PentaFederation is the bounded Penta runtime/facade that participates in that topology.

## Runtime surfaces

PentaFederation is exposed through four governed surfaces:

1. `penta-federation-control` — dedicated JWT-protected control/read surface.
2. `penta-federation-mcp` — dedicated stateless MCP surface using protocol `2026-07-28`.
3. `penta-control-v1` — umbrella PentaFabric control surface with embedded federation actions.
4. `penta-mcp-v1` — umbrella Penta MCP surface with embedded federation tools.

The dedicated facade exposes `status`, `member_state` and `route_plan`. `route_plan` evaluates whether a route is currently permissible; it does not execute the provider or repository mutation.

## Canonical transport

Actual repository federation traffic remains on `repository-federation-bus`. That transport performs custom GitHub Actions OIDC verification and routes governed operations to the existing federation RPC layer. The Penta facade does not weaken or bypass that trust boundary.

The canonical federation operation family currently includes bootstrap, heartbeat, publish/pull, acknowledgement, reference registration, authority evaluation, bounded algorithm calls, child certification and agent-inventory synchronization. Each operation remains constrained by the repository's current lifecycle state and agent binding.

## Member lifecycle

Framework children may exist in states such as `pending_provisioning`, `provisioned_unlinked` and `linked_governed`. PentaFederation does not silently promote a child merely because the child is known to the registry.

Certification remains a governed parent action. Child repositories remain non-voting unless an independently governed future policy explicitly changes that rule. PentaFederation itself does not manufacture voting authority.

## Core bindings

The v1 core binds PentaFederation to:

- CHLOM — authority and policy preflight.
- `institutional_federation` — canonical federation state.
- `repository-federation-bus` — canonical repository transport.
- PentaFabric — orchestration parent.
- PentaMesh — bounded routing.
- PentaFramework Factory — candidate build/distribution handoff.
- DAIL — append-only evidence.
- CrownLytics — least-data observability.
- CrownThrive IO/MCP — registered interoperability gateway; endpoint contract verification remains required before treating that route as fully verified.

Additional Penta products may register participant bindings. Participant registration does not convert those products into federation-core dependencies and does not inherit provider-write authority.

## Hard guardrails

1. D3 remains human-reserved.
2. PentaFederation cannot manufacture authority.
3. Self-approval is prohibited.
4. Provider-write authority is not inherited from federation membership.
5. Money-movement authority is not inherited.
6. Rights/licensing authority is not inherited.
7. Child voting authority is not inherited.
8. Missing capability, invalid lifecycle state or an active parent lock fails closed.
9. Evidence and idempotency remain required for governed mutation paths.
10. Secrets are never part of the registry manifest, route result or public-safe documentation.

## Verification baseline — 2026-08-26

The deployed v1 verification established:

- dedicated control surface active;
- dedicated MCP surface active;
- umbrella Penta control and MCP surfaces include federation interfaces;
- canonical parent remained operational;
- CIE child remained `linked_governed`;
- CHLOM child remained `pending_provisioning` and was not silently promoted;
- Agent D certification route was permitted;
- Agent A certification route was denied as unauthorized;
- Governance Marshal agent-inventory synchronization route was permitted;
- provider write, money movement and rights grant remained non-inherited.

Canonical proof key: `ct.penta.federation.proof.runtime.v1.2026-08-26`  
Proof result: **PASS**  
SHA-256: `940fb8442dd3f99211c14e28eb9a08632a5bce6868ebbd009346122d664112b5`

## Promotion rule

A deployed Edge Function being `ACTIVE` is not equivalent to a federation production promotion. PentaFederation remains `CONTROLLED_TEST` while its parent PentaFabric/federation release state remains controlled test. Production promotion requires the governed parent release gate and independent verification; the facade does not promote itself.

## Trademark notice

**PentaFederation™** is used as a CrownThrive, LLC proprietary software and operating-system mark. The ™ notice does not represent federal registration unless a separate verified registration record establishes that status.
