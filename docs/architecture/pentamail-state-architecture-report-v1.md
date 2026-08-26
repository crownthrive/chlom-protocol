# PentaMail™ + State Architecture Report v1

**Institutional phase:** Phase 3 — Execute  
**Runtime version:** 1.0.0  
**Canonical runtime:** ThriveBase  
**Delivery provider:** Mailgun (`relay.crownthrive.com`)  
**Public-safe status:** Production internal notification plane

## Purpose

PentaMail is CrownThrive's governed system-email and owner-notification control plane. The State Architecture Report is its hourly institutional state product: a comprehensive, evidence-backed snapshot of CrownThrive's current Phase 3 architecture, operating health, governance boundaries, provider-certification state, software-factory activity, subsystem state, releases, incidents, and changes since the preceding report.

The report exists because a previously true state must never be silently repeated as current state. Every report recompiles from current ThriveBase evidence and carries its own report ID, time window, severity, SHA-256 digest, canonical machine snapshot, and provider delivery receipt.

## State model

The report differentiates core runtime availability from degraded execution planes. A typical classification is one of:

- `PRODUCTION_HEALTHY` — core runtime and observed execution planes are healthy under the report contract.
- `PRODUCTION_DEGRADED_CERTIFICATION` — CrownThrive remains operational, but provider certification/build evidence contains failed or blocked work that remains fail-closed.
- `CRITICAL` — a required scheduler gap, unrecovered required-job failure, authority-manufacture guardrail violation, or loss of production state is observed.

A degraded certification plane does not imply that CrownThrive OS is offline. Conversely, a production core state does not permit an incomplete provider lane to be described as certified.

## Hourly State Architecture Report

The canonical report compiles at minimum:

1. Executive institutional state and Phase 3 status.
2. PentaSELF, PentaFabric, PentaMesh and topology state.
3. Required scheduler health and outage indicators.
4. Complete PENTA system-registry snapshot and maturity counts.
5. CHLOM mesh bindings, heartbeat and site-mesh topology.
6. Complete provider-adapter certification queue.
7. PentaBuild/PentaCertify task state and unresolved evidence.
8. Software-factory build requests, runs and release-package activity.
9. Governance and security guardrails, including D3 human reservation.
10. PentaPR/PentaMerge/PentaCloser lifecycle state.
11. PentaOFAC source freshness and errors.
12. PentaGreen, PentaNurture, PentaBooks, PentaGeneration, PentaFederation, PentaMedia, PentaStudios and PentaSuite summary state where available.
13. Current CHLOM and CrownThrive Support release readback.
14. Changes since the prior report: PENTA registry, provider certification, factory work and release changes.
15. Owner-attention / incident summary.
16. Evidence and continuity metadata.

The email representation is human-readable. The full machine snapshot is retained in ThriveBase and is authoritative for the report ID.

## PentaMail notification plane

PentaMail also provides a priority outbox for system notifications such as:

- outages and recoveries;
- scheduler failures;
- certification-plane degradation;
- security or authority-boundary alerts;
- releases and production transitions;
- governance holds requiring owner visibility;
- other system events explicitly routed to PentaMail.

Outage monitoring is transition/fingerprint aware. It does not blindly email on every watcher cycle. New conditions, changed fingerprints and periodic unresolved-condition reminders may generate notifications; recovery produces a separate recovery event.

## Scheduling

Production schedules are held in ThriveBase/pg_cron:

- `penta-mail-state-architecture-hourly-v1` — `0 * * * *`
- `penta-mail-outage-watch-v1` — `*/5 * * * *`
- `penta-mail-outbox-dispatch-v1` — `*/5 * * * *`

The hourly report is therefore a permanent institutional clock. Faster outage checks do not imply unrestricted execution authority.

## Delivery and evidence

PentaMail routes through the existing governed Mailgun relay rather than creating a second email provider path. Delivery is restricted to private allowlisted recipients. Raw credentials are resolved only at runtime from Vault-backed custody and are never included in report bodies, repository state, or provider receipts.

Each State Architecture Report records:

- report UUID;
- report version;
- report window;
- overall state and severity;
- full JSON snapshot;
- change summary;
- rendered email body;
- SHA-256 digest;
- delivery state;
- Mailgun HTTP/provider status;
- provider message ID;
- send timestamp and error state.

## Authority boundary

PentaMail and the State Architecture Report are observation/communication systems. They do **not**:

- manufacture CrownThrive authority;
- promote a provider to certified state;
- create provider-wide write authority from a narrow operation certificate;
- expose or invent credentials;
- move money;
- enable universal delete;
- self-approve D3 authority;
- overwrite or erase historical evidence.

Their job is to make institutional truth visible and durable while preserving CHLOM and PENTA governance.

## Initial production proof

The initial production report was generated on 2026-08-26 under Phase 3 and successfully traversed:

`State compiler → ThriveBase report ledger → PentaMail → governed Mailgun relay → Mailgun HTTP 200 queue acknowledgement`.

A separate HIGH certification-plane incident was subsequently generated by the outage watcher, dispatched through the PentaMail priority outbox, and independently received a Mailgun HTTP 200 queue acknowledgement.

Private recipient identifiers and provider message IDs remain in ThriveBase evidence rather than this public-safe document.
