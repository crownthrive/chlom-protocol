# PentaFramework Factory™ — Canonical Production Architecture v1

**Owner:** CrownThrive, LLC  
**Canonical product name:** PentaFramework Factory™  
**Product contract:** `ct.pentaframework-factory.v1`  
**Canonical system ID:** `ct.system.pentaframework-factory.v1`  
**Runtime control plane:** ThriveBase  
**Governance plane:** CHLOM™  
**Cultural/framework alignment:** Cultural Imprint Engine (CIE)  
**State:** production runtime active; individual provider writes remain subject to adapter certification and governance gates.

## Purpose

PentaFramework Factory is CrownThrive's governed framework and software-production system. It converts an accepted framework or software objective into a deterministic, testable, rights-aware, packageable and provider-routable production artifact without granting itself authority that CHLOM has not supplied.

It is the canonical successor name to **Framework Factory™** and the product identity used for the CrownThrive autonomous software-factory runtime. Existing `framework-factory-v2`, `ct-factory-*`, `ct.factory.v4`, database RPC, queue, artifact and provider identifiers remain compatibility identifiers where changing them would break a proven production route.

## Five-stage production model

PentaFramework Factory exposes five canonical stages while preserving the existing eight internal execution lanes.

| Stage | Canonical stage | Internal lanes | Primary responsibility |
|---|---|---|---|
| 1 | Plan | `discover`, `architect` | Resolve project state, bindings, requirements and a structured blueprint. |
| 2 | Build | `generate` | Compile the blueprint and generate bounded source/assets/contracts. |
| 3 | Verify | `security`, `test` | Enforce security baselines and deterministic tests before packaging. |
| 4 | Package | `package` | Produce one governed production package with evidence, rights metadata and digest. |
| 5 | Release | `deploy`, `assurance` | Route through certified provider adapters, read back implementation evidence and fail closed if required targets are not implemented. |

The five-stage abstraction is a product/control model. The eight-lane execution contract remains authoritative for current runtime workers.

## Production invariants

1. One production package is emitted per successful build run.
2. Provider writes are bounded by registered deployment targets and certified adapters.
3. Test and security work precede production deployment.
4. Rollback evidence is required for production implementation.
5. Secrets are not emitted into generated artifacts.
6. Arbitrary shell, arbitrary SQL and unbounded provider mutation are not manufacturing capabilities.
7. Missing authority, failed tests, failed readback or an unsatisfied required target produces a hold/failure rather than invented success.
8. CHLOM governance and rights state outrank factory throughput.
9. CIE constraints can shape generated framework/package outputs but do not create deployment or licensing authority.
10. ThriveBase remains the institutional state and queue/control plane for the current runtime.

## Runtime composition

The current production composition includes the following compatibility services:

- `framework-factory-v2` — legacy-compatible API surface.
- `pentaframework-factory` — canonical API/status surface.
- `ct-software-factory-worker` — governed work-unit worker.
- `ct-factory-blueprint-planner` — structured planning.
- `ct-factory-compiler` — bounded compiler subsystem.
- `ct-factory-generator` — source/package generation.
- `ct-factory-test-runner` — test execution and evidence.
- `ct-factory-deployer` — deployment routing.
- `ct-factory-property-binder` — CrownThrive property binding.
- `ct-factory-github-bridge` — provider-native GitHub bridge.
- provider adapters for ThriveBase, Sites, cPanel, Vercel, external surfaces and Google Cloud Functions as individually certified.

These names are implementation identifiers, not separate products.

## Identity and compatibility rule

New public-safe documentation, package manifests, status surfaces and provider receipts SHOULD identify the system as **PentaFramework Factory™** and include `ct.pentaframework-factory.v1` where a product contract is appropriate.

Existing identifiers MAY remain unchanged when they are referenced by scheduled jobs, RPCs, provider audiences, database constraints, OIDC trust, artifact URIs or other production integrations. Compatibility retention is not brand drift; it is a non-breaking migration policy.

## Evidence model

A successful release requires evidence for source, compiler output, tests, security, rights/authority, deployment, rollback and SHA-256 integrity. Provider completion is not accepted merely because a dispatch was attempted: required targets must reach the implemented state and readback/assurance must close the run.

## Trademark notice

**PentaFramework Factory™** is used as a CrownThrive, LLC proprietary software and operating-system mark. The ™ notice does not represent federal registration unless a separate verified registration record establishes that status.
