# CHLOM™ Technical White Paper — Extended Appendices (v1.1)

This appendix provides operational guidance, benchmarking parameters and additional material to accompany the main Technical White Paper. It covers gas‑cost estimates, storage layout strategies, zero‑knowledge circuit guidelines, MEV mitigation, cross‑chain bridging, security analysis, economic calibration methods, test harnesses and operational runbooks.

## Gas‑Cost Budgets & Complexity

- `incrementUsage()`: O(m + d) where m is the number of splitter recipients and d the depth of the override tree. Gas usage scales linearly.
- `settlePayouts()`: loops over batches and computes shares; expect ~20k gas per recipient.
- Circuits verification: verifying a Groth16 proof costs ~200k gas; PlonK requires ~400k gas.
- Appendices include a gas report from Foundry (see artifacts).

## Storage Layout & Slot Packing

- Pack booleans and enums in the same storage slot to minimize costs.
- Use `uint96` for weights and rates to allow fixed‑point arithmetic with 1e18 denominator.
- Keep arrays of recipients in sequential storage and index them via offsets rather than nested mappings.
- See the storage schema in Appendix J for field names, types and gas notes.

## ZK Circuit Specs & SRS Rotation

- Policy predicates should be compiled into circuits using a universal setup (PLONKish). The proving key and verification key are versioned.
- Rotate the structured reference string (SRS) periodically under governance.
- Provide sample Circom and Noir templates for age‑based, geo‑based and risk‑based policies.
- Use range checks and hash commitments to limit input size.

## MEV & Order Analysis

- Batch‑order invariance (Theorem T10) ensures that total payouts are independent of transaction ordering.
- Use receipts per transaction to prevent micro‑level disputes.
- Consider auction mechanisms for block inclusion to reduce MEV extraction.

## Cross‑Chain Bridging

- For bridging value to another chain, mint mirrored tokens on chain Y only upon verification of a light‑client proof of finality from chain X.
- Maintain a bridge contract that locks tokens on X and mints on Y.
- Appendices detail optional configurations for L1, rollups and app‑chains.

## Security Model & Attack Trees

- Identify adversary goals: stealing funds, violating caps, replaying transactions, censoring reports, forging proofs.
- Model attack paths and apply slashing or reorg requirements as countermeasures.
- Ensure BFT assumptions hold and update stake requirements based on network conditions.

## Monte Carlo EV Calibration

- Simulate adversary behaviour across varying detection probability p, slashing factor s and illicit gains G.
- Compute the expected utility E[G − p·s·S] and adjust S accordingly.
- Calibrate coalition thresholds for censorship and safety breaks.

## Test Vectors & Property Mapping

- Provide sample events and expected contract states for each invariant I1–I9.
- Use TLA+ property mapping to verify liveness and safety.
- Include fuzz harnesses and unit tests (Foundry) with assertions on totals, caps and nonces.

## Operational Runbooks

- **Oracle Disputes**: Step‑by‑step procedure to challenge a false report; includes evidence submission and stake resolution.
- **Subtree Revokes**: How to revoke a subtree and notify stakeholders; ensure no further payouts.
- **Upgrade Process**: How to propose and activate a new parameter or contract version via governance.
- **Emergency Response**: Freeze functions and call emergency brake; coordinate with multisig.

## Upgradeability Controls & Timelocks

- Use proxy contracts for upgradability; admin keys held by governance.
- Parameter changes go through a timelock with a minimum delay (e.g., 7 days).
- Provide version numbers and migration scripts.

## Network‑Specific Overlays

- L1: High gas costs; batch settlements weekly; large slashing deposits.
- L2/Rollups: Lower gas; faster finality; smaller deposits.
- App‑Chains: Customizable consensus; integrate directly with the treasury.

## Asymptotics & Benchmark Plan

- Provide O() complexity per function.
- Benchmark with Foundry's gas profiler and capture baseline numbers.
- Use dashboards to track gas regressions.

## Compliance Pack Examples & DA Strategy

- List example policies: age ≥ 18, geo whitelist, model risk ≤ threshold.
- Outline data availability (DA) options: store logs on chain, broadcast via event and replicate to off‑chain analytics.

## Privacy Enhancements

- Recommend per‑user salts for DID hashes.
- Use mixnets or off‑chain enclaves for additional anonymity.
- Encourage periodic key rotation.

## Notation & Symbols

- Summarize notation used across documents (P1–P13, I1–I9, T1–T15, state variables, parameters).
- Provide glossary for acronyms (ZK, SRS, MEV, DA, DLA, etc.)

---

This concludes the extended appendices (v1.1). For protocol details see the Technical White Paper; for proofs see the BlackPaper. Gas reports, circuit skeletons and build scripts are available in the artifacts directory.
