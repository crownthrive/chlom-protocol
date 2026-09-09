# Repository boundaries and collaboration model

## Purpose

CrownThrive uses more than one repository because executable governance and public documentation have different security, lifecycle, and publishing requirements. The repositories must collaborate without becoming interchangeable.

## Canonical source

`crownthrive/chlom-protocol` is the canonical public-safe operating source for CHLOM machine-readable registries, schemas, source lineage, agent contracts, workflows, architecture decisions, and Phase 3 implementation boundaries.

Changes to CHLOM meaning, status, registry identifiers, permissions, workflows, or executable contracts originate here.

## Documentation projection

`crownthrive1/CrownThrive-OS` is the Mintlify/help-center projection repository. It may render approved CHLOM material for human readers, support workflows, onboarding, public runbooks, and ecosystem navigation.

It is not the source of truth for CHLOM registry state merely because Mintlify deploys from it.

## Collaboration requirement

The CrownThrive GitHub identity and/or GitHub App used for CHLOM automation requires write access to `crownthrive1/CrownThrive-OS` before automated projection can be enabled. Until that permission exists, the projection repository must be treated as read-only from CHLOM automation.

## Safe synchronization contract

1. Update and validate canonical CHLOM source in `chlom-protocol`.
2. Merge to `main` after required approvals and CI.
3. Generate or manually prepare the public-safe documentation projection.
4. Record the exact upstream repository and commit in the projection metadata.
5. Open a pull request against `CrownThrive-OS`.
6. Validate Mintlify navigation/build before merge.
7. Publish only after the projection passes review.

## Outage behavior

If GitHub ↔ Mintlify synchronization fails:

- Do not change source authority.
- Do not recreate canonical records by hand in Mintlify.
- Mark documentation as drifted or pending synchronization.
- Preserve the upstream commit that should be projected.
- Resume projection once connectivity returns.

## Security boundary

Never project production secrets, webhook signing secrets, raw evidence, customer records, private contracts, confidential unit economics, Fingerprint implementation, restricted policy logic, unreleased source assets, or protected-person data into the public documentation repository.

## Long-term consolidation

The preferred ownership model is one CrownThrive-controlled GitHub organization/account with clearly separated repositories and shared collaborators/teams. Repository consolidation means coordinated ownership, permissions, source contracts, and automation—not placing every system into one monorepo.
