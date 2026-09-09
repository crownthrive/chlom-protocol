# PentaBooks v1

PentaBooks is the governed CrownThrive / Virality Music book-production operating system.

## Production truth

- Service: `ct.pentabooks.control.v1`
- Public read surface: `ct.pentabooks.public.v1`
- Runtime: ThriveBase (Supabase)
- Governance: CHLOM
- Version: `1.0.0`
- State: operational
- Control function: `penta-books-control` (JWT required)
- Public function: `penta-books-public` (GET-only)

## Canonical source order

1. `https://virality-music.crownthrive.chatgpt.site`
2. Approved ChatGPT Work production artifacts
3. PentaBooks project sources
4. PentaBooks project chats

A newer explicit project directive may correct an older source, but PentaBooks preserves the earlier edition/version and appends the correction. It never silently rewrites historical truth.

## Core responsibilities

PentaBooks owns governed book registration, edition lineage, source provenance, fixed/open/sealed/disputed canon facts, illustration and asset records, VM-BOOK-001 and VM-BOOK-002 quality gates, rights and accessibility readiness, checksums, release preflight, durable lifecycle events, and downstream routing for analytics, operations, notifications, rights/licensing, and publication.

## Production tables

- `penta_book_system_state`
- `penta_books`
- `penta_book_editions`
- `penta_book_assets`
- `penta_book_sources`
- `penta_canon_facts`
- `penta_book_standards`
- `penta_book_qa_runs`
- `penta_book_bindings`
- `penta_book_events`

RLS is enabled. Client roles are deny-by-default; production control runs through service-role-backed Edge Functions. Public catalog access is mediated through a read-only Edge Function rather than direct table grants.

## Control actions

`book.register`, `edition.register`, `canon.append`, `qa.record`, `source.register`, `release.preflight`, `event.append`, `health`.

Release preflight is fail-closed. It requires the edition's mandatory VM-BOOK gates, cleared rights, completed accessibility review, a source URI, and a SHA-256 checksum before `release_ready=true`.

## Mesh bindings

PentaBooks is registered with CHLOM, ThriveBase, Virality Music, ChatGPT Work, CrownLytics, CrownPulse, ThrivePush, and the GSO Rights Desk. The durable `penta_book_events` outbox is the cross-service handoff boundary; provider-specific writes remain bounded by their own certified adapters and authority.

## Governing rules

- Preserve old editions and correction history.
- Do not invent canon to fill an open file.
- Do not unseal protected material.
- Do not publish without mandatory gates.
- Do not conflate purchase rights with adaptation/licensing rights.
- VM-BOOK-002 extends rather than replaces VM-BOOK-001.
- Fine-press scarcity must be a manufacturing fact, not a marketing claim.
