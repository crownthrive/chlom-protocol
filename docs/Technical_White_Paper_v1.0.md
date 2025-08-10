# CHLOM™ Technical White Paper — Protocol, Cryptography, Economics & Verification (v1.0)

## Purpose

This document translates the BlackPaper’s proofs into implementable protocols. It defines the system architecture, on‑chain and off‑chain components, cryptographic primitives, data structures and APIs. It also covers incentive design, governance processes, interoperability and performance considerations.

## System Architecture

CHLOM consists of a set of on‑chain contracts, off‑chain oracles and governance functions. The core modules are:

- **CHLOM-SmartLicense**: ERC‑compatible contract that manages license state (Draft, Active, Suspended, Revoked, Expired), usage counters, caps and nonces. It exposes functions to initialize a license, increment usage, suspend, revoke and expire.
- **CHLOM-Splitter**: Distributes payments to licensors according to a weight vector `w`. Weighted shares are represented in fixed‑point arithmetic.
- **CHLOM-OverrideTree**: Encodes a hierarchical override structure where upstream licensors receive a fraction of downstream sales. Rates are stored on edges and enforced during payout.
- **CHLOM-Treasury**: Collects base fees, holds stake deposits, and disburses payments. Implements residual handling for rounding errors.
- **CHLOM-DIDRegistry**: Maps public keys to decentralised identifiers and tracks authorization roles.
- **CHLOM-Governance (DLA)**: Processes enforcement events based on oracle reports and zero‑knowledge proofs. It manages slashing, stake unlocking and parameter updates.

### Off‑Chain Components

- **Violation Oracle (V)**: Detects misuse of licensed content and submits signed evidence with a deposit.
- **Analytics/Attestation Oracle (A)**: Provides attestations or usage analytics that trigger payouts.
- **ZK Prover**: Generates zero‑knowledge proofs of compliance. Holders prove that private data x satisfies the policy predicate C(x) without revealing x.
- **Light Client** (optional): Verifies finality proofs for cross‑chain settlement.

## Data Structures

Licenses, splitters and override trees are stored in mappings keyed by a unique identifier. Each license record contains:

```solidity
struct License {
    enum State { Draft, Active, Suspended, Revoked, Expired }
    State state;
    uint256 used;
    uint256 cap;
    uint256 nonce;
    address splitterId;
    address overrideTreeId;
    // Additional metadata (URI, hashes)
}
```

Splitters store arrays of accounts and weights; override trees store parent pointers and edge rates. Registries map DIDs to authorized keys and roles.

## Cryptography & Identity

CHLOM relies on the following cryptographic primitives:

- **Collision‑resistant hash**: used to derive DIDs (`did = H(pk || salt)`), compute commitment roots and build Merkle proofs.
- **Digital signatures**: transactions must include signatures from an authorized key associated with the DID.
- **Zero‑knowledge proofs**: compliance predicates are encoded in circuits. The prover constructs π attesting that there exists x such that C(x) holds. The verifier (precompiled) checks π against a verification key and returns true/false.

All cryptographic parameters (hash function, signature scheme, proof system) can be upgraded via governance under timelock.

## Usage Flow

1. A creator deploys a license L with cap and optional splitter and override tree. The license is in Draft.
2. Governance activates the license upon verifying an initial proof of compliance.
3. Each usage of the licensed asset calls `incrementUsage(licenseId, amount, proof)`:
   - Verify that the license is Active and `used + amount ≤ cap`.
   - Verify the zero‑knowledge proof `π` that asserts the policy predicate holds.
   - Update `used` and increment `nonce`.
   - Transfer base payment to the treasury.
4. On scheduled intervals, the treasury settles payouts:
   - Compute base amounts per transaction and apply splitter weights.
   - Traverse the override tree to compute ancestor shares.
   - Send residual rounding units to a deterministic sink.
   - Emit events for audit.
5. If a violation oracle submits a valid report, governance may suspend or revoke the license and slash the violator’s stake.

## Incentives & Economics

Stake deposits S and slashing factors s are calibrated so that the expected cost of deviation exceeds the illicit gain. The economics module maintains:

- **Stake Ledger**: tracks deposits per actor and their locked status.
- **Slashing**: on misreport or violation, slash `s·S`.
- **Rewards**: honest oracles are rewarded with a fee, while violators lose deposits.
- **Rounding Sink**: residual units are assigned to the creator or rotated among stakeholders.

Parameter defaults (see appendices) specify detection probabilities, slashing multipliers, cap sizes and reward percentages.

## Governance & Upgradability

The Decentralized Licensing Authority (DLA) governs upgrades and parameter changes:

- **Proposal & Voting**: Stakeholders propose changes; a quorum and majority of stake must approve.
- **Timelock**: Approved proposals are queued with a delay to allow audits.
- **Parameter Registry**: Stores current parameters (thresholds, windows, slash factors).
- **Emergency Brake**: Allows suspending the protocol in case of critical bug; requires multi‑sig.

## Security Considerations

- **Replay protection**: Nonces prevent replaying transactions.
- **State consistency**: All checks operate on finalized blocks; eventual finality ensures no double‑use.
- **Oracle accountability**: Deposits and slashing discourage false reports; collusion thresholds ensure resilience.
- **Circuit soundness**: Circuits are audited to prevent constraint bugs; verification keys are versioned.
- **Resilience to MEV**: Batch‑order invariance ensures that transaction ordering does not affect total payouts.

## Performance & Gas

Fixed‑point arithmetic is used for weights to avoid fractional rounding issues. Gas costs scale linearly with the number of recipients in a splitter and the depth of the override tree. Appendices provide gas envelopes and storage layout strategies.

## Interoperability

CHLOM is chain‑agnostic; it can be deployed on EVM‑compatible chains, rollups or app‑chains. Cross‑chain settlements use light‑client proofs of finality. Off‑chain oracles and ZK proving can run anywhere.

## Ecosystem Fit

The CHLOM protocol powers CrownThrive’s ecosystem, enabling fair and auditable licensing across platforms such as FindCliques, CrownThrive IO, CrownLytics, CrownPulse, ThrivePush, ThriveTickets, Thrive AI Studio, ThriveTools, Kamora360, Go‑Flipbooks, Collab Portal, CrownRewards, CrownFluence, Crown Affiliates/Ambassadors, AdLuxe Network, The Mane Experience, Locticians, Locticians TV, Melanin Magic, CrownThriveU, The Tame Gallery, The Artful Mane Gallery, Wearable Art, MVP on Roku, Melanated Voices TV and more. Each platform integrates the licensing primitives while preserving privacy and encouraging community participation.

---

For gas budgets, ZK circuit templates and operational playbooks, see the Extended Appendices. For the formal proofs, see the BlackPaper.
