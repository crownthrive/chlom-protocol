# Phase 3 Service Boundaries

Phase 2 defines contracts for Phase 3 implementation:

- `orchestrator/` — classify objectives/events, route work, request approvals and track dependencies.
- `event-gateway/` — normalize inbound/outbound events and enforce idempotency.
- `approval-service/` — create approval requests, enforce gates and record decisions.
- `audit-log/` — append DAIL events, corrections and evidence references.
- `rights-registry/` — assets, versions, claims, authority and permissions.
- `policy-registry/` — rules, policy packs, eligibility and review requirements.
- `role-registry/` — tenants, organizations, people, credentials and delegated authority.
- `revenue-registry/` — offers, allocations, royalties, holds, settlements and reconciliation.
- `remedy-service/` — cases, holds, corrections, appeals, reinstatement and closure.

No Phase 3 service may bypass approval gates by writing directly around the approval or audit layers.
