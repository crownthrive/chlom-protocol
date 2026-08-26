# PentaHelp Metaprotocol v1

**Institutional phase:** Phase 3 — Execute  
**Canonical runtime:** ThriveBase  
**Public-safe state:** Production  
**Primary systems:** PentaHelper™, PentaLiaison™, PentaSELF, PentaBuild, PentaCertify, PentaCredentials, PentaRoute and PentaMail

## Purpose

PentaHelp is CrownThrive's always-available self-help metaprotocol. Its purpose is to prevent unresolved work from remaining in an unowned generic `WAITING` state.

Every CrownThrive/Penta subsystem may ask for help. A raised condition is converted into an explicit bounded action or route:

`ASK → TRIAGE → HELP → TEST / BUILD / RECONCILE → INDEPENDENT CERTIFY → LIAISE → RESOLVE / ESCALATE`

The metaprotocol does not bypass a hold. It attempts to eliminate the cause of the hold and preserves the original evidence if the cause cannot yet be resolved.

## PentaHelper

PentaHelper is the production execution coordinator for self-help work. It scans and accepts conditions including:

- missing or stale readback evidence;
- missing bounded write-canary, rollback or compensation evidence;
- missing provider adapter/runtime software;
- credential-readiness uncertainty;
- active scheduled-job failure;
- factory/provider job backlog or stale claim;
- implementation maturity lacking executable production evidence;
- product/economic HOLD dimensions whose cause can be tested or built;
- explicit help requests raised by any Penta.

PentaHelper converts these into typed work rather than treating them as generic failure.

### Evidence work

For a read-only/readback requirement, PentaHelper may execute the registered non-mutating provider certifier immediately and preserve the resulting provider evidence.

For a mutation canary, PentaHelper may execute only when the exact operation has an explicit bounded, reversible canary/readback/compensation route. If that route does not exist, PentaHelper asks PentaBuild to produce the missing certification software first.

### Software work

If a Penta is implemented but lacks executable production evidence, PentaHelper may create a deterministic PentaFactory build request. The generic productionization path targets CrownThrive OS source custody and ThriveBase runtime/evidence. Website/public projection is explicitly deferred and is not required for the current Phase 3 source-of-truth path.

Production promotion requires functional/runtime evidence; a generated package or version label is not sufficient by itself.

### Credential work

PentaHelper may reconcile existing PentaCredentials custody/readiness records. It may never invent, reconstruct, expose or manufacture credential material.

### Repair work

PentaHelper may call existing bounded self-healing functions within their registered risk ceilings. It does not turn a D1/D2 repair function into D3 authority.

## PentaLiaison

PentaLiaison provides the dependency-routing half of the metaprotocol. When autonomous work cannot complete the dependency itself, PentaLiaison builds a dedicated route to the exact destination:

- another Penta subsystem;
- PentaBuild/PentaFactory;
- PentaCertify;
- PentaCredentials;
- a certified provider worker;
- a package/plan/entitlement route;
- a repository/workflow;
- or human-reserved governance.

A dependency therefore remains active and attributable instead of silently idle.

## TTL and TTYL

Every help request has:

- a **TTL** — maximum bounded lifetime for the current help request;
- a **TTYL** — time-to-liaison, the point at which unresolved autonomous work must acquire an explicit dependency/escalation route;
- next-action time;
- attempt budget;
- lease/worker ownership;
- authority/risk classification;
- resolution receipt.

TTYL does not mean failure. It means the dependency can no longer remain unowned.

## Separation of duties and self-certification

CrownThrive may self-certify through institutional separation of duties. It may not self-approve in one trust role.

- **PentaHelper / PentaTest** may generate or execute evidence.
- **PentaBuild / PentaFactory** may generate software, tests, adapters and bounded canary/rollback contracts.
- **PentaCertify** independently evaluates the resulting evidence/contract.
- **PentaLiaison** routes dependencies and human/provider requirements.
- **CHLOM/DAIL** preserve authority/evidence lineage.

A component cannot simply generate favorable evidence and declare itself `PASS` in the same role.

## D3 and reserved authority

D3/new sovereign authority remains human-reserved. PentaHelper does not auto-approve:

- sovereign/governance changes;
- human-reserved economic authority;
- money movement without independent authority;
- credential creation or disclosure;
- unrestricted provider mutation;
- universal delete;
- rights/license grants outside existing authority.

A D3 help request is routed by PentaLiaison to the human-governance destination and remains fail-closed until the governing record exists.

## Backpressure and bounded execution

PentaHelper runs on an always-on production clock but is intentionally bounded:

- per-cycle execution batch is capped;
- stale worker leases are recovered;
- database connection utilization can trigger backpressure instead of spawning more work;
- provider/factory backlog is aggregated by route rather than generating one operator ticket for every durable job;
- superseded, deferred and historical jobs are preserved as explicit HOLD evidence rather than deleted.

This lets the institution help itself without making the help plane a new source of load or authority.

## Provider and factory backlog reconciliation

The metaprotocol distinguishes runnable current work from history:

- stale claims can be released for retry;
- older duplicate provider jobs can be marked `HOLD / SUPERSEDED_BY_NEWER_FACTORY_RUN`;
- website/public-projection work can be explicitly held for the later projection wave;
- terminal parent requests cannot retain runnable provider jobs;
- current provider routes receive one aggregated PentaLiaison dependency path;
- resolved/retired Help requests terminalize their liaison threads.

No historical provider job or build record is silently deleted.

## Production evidence receipts

PentaHelp uses append-only SHA-256 evidence receipts. Production promotion requires system-specific semantic evidence, for example:

- durable database operation and readback;
- provider mutation plus exact provider readback;
- functional D0-D2 institutional behavior with D3 blocked;
- backup provider readback plus restore-path verification and a dry-run restore plan;
- positive and fail-closed federation routing tests.

A generic health endpoint alone does not prove a system's named job.

## Current convergence state at institutionalization

At the v1 institutionalization pass, PentaHelp moved previously implemented Penta systems through functional/provider evidence rather than renaming their maturity. PentaFlagger, PentaReports, PentaHarvestor, PentaFlush, PentaBackup, PentaRestore, PentaNotifs, PentaTagger, PentaPR, PentaAlumni, PentaAssure, PentaHybrid, PentaInstitute, PentaSignal, PentaMation and PentaFederation obtained production evidence through their actual bounded roles.

PentaMerge and PentaCloser remained `TESTING_ROUTED` because their exact terminal GitHub mutation/readback receipts had not yet occurred. Their algorithms/workflows exist, but the metaprotocol deliberately does not manufacture terminal provider evidence.

## State Architecture Report integration

PentaHelp is a first-class input to State Architecture Report v1.1.0. The hourly report includes:

- PentaHelper/PentaLiaison state;
- request counts by state/type;
- TTL/TTYL routes;
- current non-production Pentas;
- signed Help receipts;
- provider/factory backlog by current route;
- human/provider dependencies;
- current core health versus governed holds.

This enables a distinct `PRODUCTION_HEALTHY_GOVERNED_HOLDS` state: CrownThrive can be operationally healthy while legitimate external/human evidence remains unresolved.

## Authority boundary

PentaHelp may optimize and repair within authority. It may never manufacture authority.
