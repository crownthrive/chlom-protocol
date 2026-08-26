# PentaOFAC

**PentaOFAC** is CrownThrive's Phase 3 sanctions-data acquisition, integrity, change-detection, screening-orchestration, and evidence-preservation subsystem.

## PENTA contract

PentaOFAC follows the institutional loop:

**Discover → Govern → Execute → Verify → Preserve**

- **Discover** — retrieve current sanctions-list data from the U.S. Treasury Office of Foreign Assets Control Sanctions List Service.
- **Govern** — bind source authority, data scope, downstream screening authority, false-positive handling, and mutation boundaries through CHLOM.
- **Execute** — fetch, validate, fingerprint, compare, and route sanctions-data signals into approved CrownThrive compliance consumers.
- **Verify** — validate HTTP status, XML structure/namespace, content length, SHA-256 fingerprint, source identity, and change state.
- **Preserve** — retain immutable snapshot metadata, change events, timestamps, prior fingerprints, and execution evidence in ThriveBase.

## Authoritative sources

PentaOFAC consumes both Advanced XML families through OFAC's Sanctions List Service:

1. **SDN Advanced XML** — Specially Designated Nationals and Blocked Persons data.
2. **Consolidated Advanced XML** — consolidated non-SDN sanctions-list data.

The source endpoints are hardwired in the PentaOFAC registry and are not caller-selectable URLs.

## Runtime

The production runtime is `penta-ofac` in ThriveBase. Source-specific refreshes are staggered every fifteen minutes to prevent the large SDN file from starving the consolidated feed. Each successful acquisition records a SHA-256 fingerprint and validation receipt.

The public-safe status surface is:

`https://tzajnzshmtzjenqulehq.supabase.co/functions/v1/penta-ofac?action=status`

## Compliance boundary

A changed OFAC source is a **compliance signal**, not a final legal determination about a CrownThrive customer, creator, partner, vendor, payment, asset, or counterparty.

PentaOFAC may discover and route potential screening implications. It may not manufacture legal authority, seize/block funds, reject counterparties, or convert a fuzzy/potential match into a final designation without an authorized downstream policy and evidence path.

This distinction is mandatory because sanctions-list acquisition and sanctions adjudication are separate functions.

## Evidence plane

ThriveBase stores the canonical operational evidence in:

- `public.penta_ofac_sources`
- `public.penta_ofac_snapshots`
- `public.penta_ofac_change_events`
- `public.penta_ofac_system_state`
- `public.penta_ofac_status_v1()`

## Integration

PentaOFAC is part of the PENTA execution fabric and interoperates with PentaFetch/PentaGet for bounded acquisition, PentaBeata for liveness, PentaAudit for evidence, PentaRoute for governed routing, PentaEvent/PentaHook for downstream signals, PentaQueue/PentaDispatch for screening work, and PentaGeneration/PentaDocs for long-horizon preservation and institutional readability.

The legacy `ct.integration.ofac.sdn` integration remains valid historical/current-source lineage. PentaOFAC is the higher-level institutional subsystem that now owns the complete OFAC monitoring lifecycle.
