# PentaBooks v1 Architecture

## Purpose

PentaBooks is the book-production subsystem for CrownThrive and Virality Music. It converts governed story sources into versioned, testable, publishable, monetizable and adaptation-ready literary IP without allowing convenience to overwrite canon, provenance, rights, privacy or edition history.

## Source-of-truth lattice

PentaBooks resolves source material in this order:

1. Virality Music production property: `https://virality-music.crownthrive.chatgpt.site`
2. Approved artifacts produced in ChatGPT Work
3. PentaBooks project sources and directives
4. PentaBooks project chats and explicit corrections

This is not a destructive priority stack. When a later source corrects an earlier one, the old edition is preserved and the correction is appended with source provenance.

## Data plane

ThriveBase stores book identities, edition states, asset references, source records, canon facts, publishing standards, QA receipts, integration bindings, and a durable event outbox. Every protected table has RLS enabled and client access is deny-by-default.

The canon ledger represents facts as `fixed`, `open`, `sealed`, `disputed`, or `superseded`. An open question is not evidence for an invented answer. A sealed item is not made public merely because another edition references its existence.

## Control plane

`penta-books-control` is JWT-protected and exposes bounded administrative actions for registration, canon append, QA, source intake, release preflight, and lifecycle events.

`penta-books-public` is a separate GET-only surface for sanitized system health, catalog and standard metadata. The public surface does not expose protected canon, private assets, raw evidence, service credentials, or mutation authority.

## Publishing gates

VM-BOOK-001 is the baseline release standard. VM-BOOK-002 extends it for premium and fine-press collector editions. PentaBooks treats both as machine-readable gate contracts.

Release preflight fails closed when mandatory gates are missing or nonpassing, rights are not cleared, accessibility is incomplete, or the source artifact/checksum is missing.

## CHLOM relationship

CHLOM governs authority, rights, restrictions, correction history, licensing and protected evidence. PentaBooks does not grant itself publishing, rights-transfer, adaptation, unsealing or destructive authority beyond those policies.

## Ecosystem routing

PentaBooks emits durable book lifecycle events for CrownLytics, CrownPulse, ThrivePush, GSO Rights Desk, Virality Music publication and other certified consumers. Delivery adapters may be added independently without changing PentaBooks canon logic.

## Versioning doctrine

PentaBooks follows append-and-supersede semantics:

- old editions remain addressable;
- correction notices remain visible;
- source checksums bind released files to edition records;
- public listings can point to the current edition without deleting historical state;
- adaptation and licensing references target a specific governed edition/version.

## Initial production baseline

The v1 runtime is production-deployed in ThriveBase and seeded with the current public V4 masters surfaced by Virality Music. Those observations are catalog state, not an automatic substitute for rights, accessibility or checksum certification; PentaBooks still requires release evidence before marking an edition release-ready internally.
