# PentaMail™ + State Architecture Report v1

**Institutional phase:** Phase 3 — Execute  
**Runtime version:** 1.1.0  
**Canonical runtime:** ThriveBase  
**Delivery provider:** Mailgun (`relay.crownthrive.com`)  
**Public-safe status:** Production internal notification and institutional-observability plane

## Purpose

PentaMail is CrownThrive's governed system-email and owner-notification plane. The State Architecture Report is its hourly evidence-backed institutional state product.

Every report recompiles from current CrownThrive OS/ThriveBase/CHLOM/provider evidence. A previously true state is not silently repeated as current state. Each report carries its own report ID, observation window, state/severity, full machine snapshot, change cursor, SHA-256 digest and provider delivery receipt.

## v1.1.0

State Architecture Report v1.1.0 integrates the PentaHelp Metaprotocol as a first-class architecture input and separates actual runtime/execution failures from legitimate governed holds.

It adds:

- PentaHelper and PentaLiaison production state;
- Help request state/type counts;
- TTL and TTYL dependency routes;
- signed Help receipts;
- current non-production Pentas and their exact evidence routes;
- provider/factory backlog by current route rather than raw historical job count alone;
- current versus historical certification-failure semantics;
- a distinct `PRODUCTION_HEALTHY_GOVERNED_HOLDS` class;
- sender-lane-aware internal Mailgun rate control while retaining the same allowlisted recipient, provider budget and Vault-backed secret model.

The full Help ledger remains private in ThriveBase. Public documentation describes architecture and evidence semantics only.

## State model

v1.1.0 classifies state as:

- `PRODUCTION_HEALTHY` — core runtime and observed execution planes are healthy and no material governed dependency is currently open.
- `PRODUCTION_HEALTHY_GOVERNED_HOLDS` — the core is healthy, but legitimate provider/human/evidence dependencies remain fail-closed and actively routed.
- `PRODUCTION_DEGRADED_EXECUTION` — a real current execution/certification/runtime failure is present while the core remains substantially available.
- `CRITICAL` — production loss, required scheduler gaps, unrecovered required-job failures, authority-manufacture evidence, or another critical machine condition is observed.

An expected D3/provider/historical hold is therefore not misreported as a runtime outage. Conversely, a healthy core cannot promote incomplete provider work.

## Hourly State Architecture Report

The canonical report compiles at minimum:

1. Phase 3 and executive operating state.
2. PentaSELF, PentaFabric, PentaMesh and topology state.
3. Required scheduler health and recent operational exceptions.
4. Complete PENTA system registry and maturity counts.
5. PentaHelper/PentaLiaison state, request classes, TTL/TTYL and signed receipts.
6. Current non-production systems and their exact convergence routes.
7. CHLOM mesh/control state.
8. Complete provider-adapter certification queue and current/historical task semantics.
9. PentaBuild/PentaFactory activity and provider/source-custody backlog.
10. Governance/security guardrails including D3 human reservation.
11. PentaPR/PentaMerge/PentaCloser lifecycle state.
12. PentaOFAC freshness and errors.
13. PentaGreen, PentaNurture, PentaBooks, PentaGeneration, PentaFederation, PentaMedia, PentaStudios and PentaSuite summary state.
14. Current CHLOM/CrownThrive OS release readback.
15. Changes since the prior report.
16. Active incidents, human/provider dependencies and owner attention.
17. Evidence and continuity metadata.

The human-readable email is a projection. The full machine snapshot retained in ThriveBase is authoritative for the report ID.

## PentaHelp integration

The report enforces the Phase 3 self-help rule:

> No generic idle `WAITING`: test it, build it, reconcile credentials, route the dependency, reserve it for human authority, retire it as history, or resolve it with evidence.

PentaHelper may produce bounded evidence or software; PentaCertify remains the independent evaluator. PentaLiaison provides exact provider/repository/package/human routes when autonomy cannot close the dependency itself.

## PentaMail notification plane

PentaMail provides a priority outbox for:

- outages and recoveries;
- scheduler/job failure;
- actual certification/execution degradation;
- PentaGreen execution faults/recoveries;
- security/authority-boundary alerts;
- releases and production transitions;
- governance/human routes requiring owner visibility;
- PentaHelp escalations and dependency notifications;
- other explicitly registered institutional events.

Outage monitoring is fingerprint/transition aware rather than blindly emailing every watcher cycle.

## Scheduling

Production clocks are held in ThriveBase/pg_cron:

- `penta-mail-state-architecture-hourly-v1` — `0 * * * *`
- `penta-mail-outage-watch-v1` — `*/5 * * * *`
- `penta-mail-outbox-dispatch-v1` — `*/5 * * * *`

PentaHelper has its own one-minute production clock; its state is consumed by the hourly report.

## Delivery and rate control

PentaMail routes through the existing governed Mailgun relay. It does not create a second mail provider path.

- recipients remain private and allowlisted;
- credentials remain Vault-backed and runtime-only;
- the canonical provider service remains `mailgun_relay`;
- internal sender lanes use separate audit/rate identities;
- the PentaMail telemetry lane has a bounded higher local rate ceiling than ordinary relay senders so system reporting/alerts do not block each other;
- provider/monthly budgets and Mailgun controls still apply.

Raw credentials are never included in report bodies or repository state.

## Evidence

Each State Architecture Report records:

- report UUID/version/window;
- state and severity;
- full JSON snapshot and change summary;
- rendered email body;
- SHA-256 body digest;
- delivery state;
- Mailgun HTTP/provider result;
- provider message ID in private evidence;
- send timestamp/error state.

A verified v1.1.0 commissioning report traversed the full production path and received Mailgun HTTP 200 queue acknowledgement. Private recipient/provider identifiers remain in ThriveBase rather than this public-safe document.

## Authority boundary

PentaMail/State Architecture Report observe, report and communicate. They do not manufacture authority, certify providers, create provider-wide mutation rights, invent credentials, move money, enable universal delete, approve D3, or rewrite historical evidence.
