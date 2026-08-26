# PentaMail v1 Production Service Contract

PentaMail is a Phase 3 internal CrownThrive communications service deployed in ThriveBase. Its first institutional product is the hourly State Architecture Report.

## Runtime surfaces

- `edge:penta-mail`
- governed provider relay: `mailgun-relay-control`
- canonical report ledger: `public.penta_state_architecture_reports_v1`
- priority outbox: `public.penta_mail_outbox_v1`
- incident transition state: `public.penta_mail_incident_state_v1`

Private implementation details, Vault references, recipient identifiers, and provider message IDs are not committed to this public repository.

## Actions

### `state_architecture_report`

Compiles current Phase 3 state, compares it with the prior report window, persists the full machine snapshot and human-readable report, then routes the report through the governed Mailgun internal relay. Delivery outcome is written back to the report ledger.

### `process_outbox`

Claims queued PentaMail messages, dispatches them through the same governed Mailgun relay, records provider status/message IDs, and applies bounded retry/backoff. Failed messages eventually become dead-letter records rather than being silently discarded.

### `health`

Returns public-safe service state without returning private recipient or credential material.

## Change ingestion

Every State Architecture Report uses the previous report's `window_end` as its next change cursor. The compiler includes current state plus changes in:

- PENTA system registry;
- provider certification queue;
- PentaBuild/PentaCertify task state;
- factory build requests and runs;
- release packages;
- subsystem snapshots and provider evidence exposed by their governed status surfaces.

The initial report uses a one-hour baseline window.

## Outage model

The five-minute outage watcher currently recognizes owner-visible conditions including:

- required scheduler gaps;
- unrecovered required-job failures;
- authority-manufacture guardrail violations;
- provider-certification-plane degradation.

Incident state is fingerprinted. Notifications are generated on activation, material fingerprint change, bounded reminder interval, and recovery. This prevents an unhealthy condition from producing unlimited duplicate mail.

## Delivery model

PentaMail does not hold the Mailgun secret. It calls the existing governed Mailgun relay, which resolves provider credentials at runtime under Vault custody. The relay remains recipient-allowlisted and rate-limited.

The State Architecture Report email may be large because it includes the complete PENTA registry and provider-certification queue. If the internal transport representation ever reaches its bounded ceiling, the canonical full JSON snapshot remains in ThriveBase and the email explicitly marks truncation.

## Evidence contract

A successful State Architecture Report delivery requires all of:

1. a persisted report row;
2. a SHA-256 digest of the rendered report;
3. a Mailgun provider success status;
4. a provider message ID;
5. a `sent_at` timestamp;
6. no raw secret exposure.

A scheduler dispatch without these artifacts is not counted as successful report delivery.

## Authority

PentaMail is a notification and observability plane. It cannot certify a provider, grant permissions, create D3 authority, move money, enable universal delete, or convert an incomplete execution lane into production authority. It reports those states; CHLOM/PENTA governance controls them.
