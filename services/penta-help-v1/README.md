# PentaHelp v1 Service Contract

PentaHelp is the Phase 3 self-help control surface spanning PentaHelper and PentaLiaison.

## Runtime

- PentaHelper: `edge:penta-helper`
- PentaLiaison: `edge:penta-liaison`
- canonical private ledger: ThriveBase `penta_help` schema
- always-on helper clock: `* * * * *`
- authority ceiling: D2 autonomous; D3 human-reserved

## Machine interfaces

Public-safe interface names include:

- `penta_ask_for_help_v1`
- `penta_helper_status_v1`
- `penta_liaison_status_v1`
- `penta_help_report_snapshot_v1`

Private runtime functions additionally manage scanning, leasing, evidence receipts, dependency routing, provider/factory backlog reconciliation and production-readiness evidence.

## Execution semantics

A help request must become one of the following typed actions instead of remaining generic idle work:

- bounded evidence/readback test;
- software/adapter/runtime build;
- credential-readiness reconciliation;
- bounded self-repair;
- provider/repository route;
- human-governance route;
- retired/history disposition;
- resolved receipt.

Every request has TTL and TTYL. The worker uses bounded leases and database-load backpressure.

## Certification semantics

PentaHelper does not certify its own output. Evidence/software is passed to the appropriate independent certification path. A production promotion requires semantic evidence for the system's named function, not only a package, health endpoint or version label.

## Private/public boundary

The public repository intentionally excludes:

- private recipient identities;
- Vault material;
- provider credentials;
- secret dispatcher tokens;
- full private help payloads where they contain restricted provider or institutional detail.

Those remain in the canonical ThriveBase evidence plane.

## Guardrails

- no authority manufacture;
- no automatic D3 approval;
- no credential invention;
- no universal delete;
- no unauthorized money movement;
- no provider-wide mutation inferred from an operation-level certificate;
- no deletion of historical provider/factory evidence;
- website/public projection remains deferred for the current OS-first convergence lane.
