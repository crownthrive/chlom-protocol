# CrownThrive Integration Mesh

## Status
ACTIVE_GOVERNED_BASELINE

## Purpose
The CrownThrive Integration Mesh is the governed control surface for external and internal APIs, MCP servers, webhooks, provider SDKs, automation endpoints, and machine-to-machine integrations used by CrownThrive systems.

## Institutional rule
When an integration is entered into the CrownThrive integration registry, it becomes a persistent governed binding. Persistent means the system continuously maintains observability, authentication readiness, contract awareness, and recoverability. It does **not** mean credentials are exposed publicly or that destructive privileges are permanently enabled.

Every registered integration MUST:

1. use vault-managed credentials or credential references;
2. expose a machine-readable capability manifest;
3. declare allowed operations separately for read, write, delete, admin, and credential rotation;
4. receive automated heartbeat and reachability checks;
5. record last-success, last-failure, latency, provider status, and contract/version evidence;
6. retry transient failures with bounded exponential backoff;
7. enter circuit-breaker or quarantine state on authentication, provenance, or contract anomalies;
8. generate auditable DAIL-compatible events for material state changes;
9. retain provider identity as an execution dependency, not as CrownThrive institutional truth;
10. remain replaceable without changing the canonical CrownThrive platform identity.

## Vault binding
Secret values MUST NOT be committed to Git. Repositories may store only secret names, vault paths, credential IDs, fingerprints, rotation metadata, and non-secret endpoint metadata.

A credential binding is healthy only when runtime readback proves that the referenced secret exists, is authorized for the declared integration, and passes a non-destructive authentication check. Missing, expired, mismatched, or unverified credentials fail closed.

## Capability semantics
Permissions are capability-specific rather than globally inherited.

- `read`: may be enabled automatically after endpoint and authentication certification.
- `write`: may be enabled when the integration contract explicitly requires it and the scope is bounded to the intended resource set.
- `delete`: requires explicit certification, rollback/restore coverage where technically possible, and evidence that deletion is part of the intended provider contract.
- `admin`: denied by default and must be separately justified.
- `credential_rotation`: occurs only through the vault/control plane.

No CrownThrive integration may interpret `known-good` as permission for public anonymous access, unrestricted mutation, unrestricted deletion, or permanent exemption from revalidation.

## Reachability doctrine
"Hardwired" means persistently declared, monitored, reconnectable, and governed. It does not mean an endpoint is forced open when the provider is unavailable, rate-limited, revoked, unsafe, or intentionally disabled.

Runtime states are:

- `BOUND`
- `HEALTHY`
- `DEGRADED`
- `AUTH_REQUIRED`
- `RATE_LIMITED`
- `CONTRACT_DRIFT`
- `QUARANTINED`
- `DISABLED_BY_GOVERNANCE`

The mesh should attempt automatic recovery for transient failures. It must not bypass provider authentication, provider rate limits, security controls, or governance holds.

## Automated tracking
The control plane records integration heartbeats and material changes. Repeated failure, authentication drift, schema/contract drift, or provenance mismatch must create an actionable machine event and may open a GitHub issue or downstream operations ticket.

## SDN/OFAC binding
The OFAC SDN monitor is a compliance-source integration in this mesh. A source update propagates as a compliance signal. Downstream screening services may consume that signal, but no automatic person/entity/transaction sanction determination is created without the screening policy and review controls required by the applicable workflow.

## Non-negotiable boundary
The mesh is designed to maximize availability and automation **without creating a universal superuser credential or unrestricted destructive plane**. Least privilege, explicit capability grants, auditability, reversibility, and credential isolation remain mandatory controls.
