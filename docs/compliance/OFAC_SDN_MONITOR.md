# OFAC SDN Feed Monitor

CHLOM maintains an automated watch on the U.S. Treasury Office of Foreign Assets Control (OFAC) Specially Designated Nationals (SDN) Advanced XML dataset.

## Source of truth

The monitor uses OFAC's Sanctions List Service publication endpoint:

`https://sanctionslistservice.ofac.treas.gov/api/PublicationPreview/exports/SDN_ADVANCED.XML`

OFAC states that its Sanctions List Service is the primary delivery service for sanctions-list files and that the advanced XML product is updated with live list data. The monitor therefore treats OFAC as the authoritative external source and does not mirror the full dataset into this repository.

## Automation

`.github/workflows/ofac-sdn-monitor.yml` runs every six hours and can also be started manually.

Each run:

1. Downloads the SDN Advanced XML feed with an explicit User-Agent.
2. Parses the response as XML and fails closed if the payload is not valid XML.
3. Computes a SHA-256 content hash.
4. Compares the hash with the previous recorded state.
5. Records the latest hash, publication date, source, and check timestamp in `registry/ofac_sdn_feed_state.json` when a change is detected.
6. Opens a GitHub issue to create a human-review signal whenever the feed changes.

## Governance boundary

A feed change is **not** itself a sanctions match, legal conclusion, blocking decision, or transaction disposition. Downstream screening systems must apply their own matching logic, false-positive controls, applicable sanctions programs, escalation rules, and human review.

This monitor is an authoritative-data-change detector. It does not autonomously designate a person, entity, transaction, asset, or customer as sanctioned.

## Operational note

OFAC's SLS infrastructure requires an explicit HTTP User-Agent for automated requests. The monitor supplies one accordingly.
