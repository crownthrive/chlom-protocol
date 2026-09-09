# CHLOM Cryptographic Substrate v1

## Canonical objective

CHLOM is the **Compliance Hybrid Licensing and Ownership Model**. It is the CrownThrive authority, rights, licensing, ownership, provenance, entitlement, obligation, settlement, remedy, and verification fabric.

The reconciled rule is:

> Rights before tokens. Rights inside tokens. Rights survive tokens.

Ownership, licensing, token possession, copyright, commercial permissions, royalties, credentials, entitlements, and governance authority are separate state machines. Every material state change appends a version or event. No token or mutable Web2 row silently creates rights not present in the governing instrument.

## Production architecture

### Operational control plane

The production `chlom_protocol` schema provides append-only, DAIL-backed records for:

- corpus and requirement traceability;
- canonical asset/fingerprint bindings;
- ownership interests;
- rights instruments;
- Dynamic Licensing Assets;
- LEX offers and agreements;
- entitlements and obligations;
- balanced revenue policies and settlement previews;
- token classes, tokenized-object candidates, and provider receipts;
- oracle signals and governed review cases;
- chain adapters, DAIL proof bindings, interoperability, monthly reviews, canaries, and release certifications.

Contractual ownership and operative rights require D3 evidence. Settlement previews cannot move funds. Oracle signals cannot autonomously create legal effect. Production mint confirmation requires a production-certified adapter, provider receipt, and public legal approval for the token class.

### DAIL cryptographic proof plane

DAIL v4 uses the latest signed v2 epoch as an immutable base and extends it with bounded ordered-event segments. Each segment records:

- actual ordered event count and numeric sequence span;
- permitted database identity-sequence gaps;
- first/last event hashes and predecessor boundary;
- payload-hash, predecessor-link, and event-hash failure counts;
- Merkle root;
- previous segment root;
- canonical payload hash and institutional signature reference;
- resumable cursor and anchor intent.

Routine global assurance validates the compact checkpoint chain instead of rescanning millions of events. Per-event inclusion proofs are generated against the exact segment root. Raw private event payloads are never placed in public anchor intents.

### Native FRAME candidate

The `substrate/chlom-l1` workspace materializes the native pallets required by the historical CHLOM papers:

1. Authority — D0-D3 role versions and structural authority boundaries.
2. Identity — DIDs/Fingerprint IDs, controller and settlement-route commitments, identity-bound credentials.
3. Rights — ownership interests and rights instruments with explicit legal effect.
4. Licensing — DLA, license status/revocation, LEX offers, and entitlements.
5. Settlement — balanced basis-point policies and deterministic no-money-movement previews.
6. Tokenization — token classes, candidates, chain adapters, mint/transfer provider receipts, and rights semantics.
7. Oracle — risk signals and review cases without autonomous legal effect.
8. Checkpoint — signed roots, chain-portable anchor intents, and exact provider receipts.

The source is pinned to `paritytech/polkadot-sdk@polkadot-stable2506-7` and composed in one mock runtime for cross-pallet tests.

## Explicit external-network boundary

The control plane and compact DAIL verifier are production services. The standalone Layer-1 remains a **production candidate**, not a live-network claim. A source tree is not a validator network. Activation requires reproducible Wasm custody, generated weights, genesis ratification, validator keys and recovery, networking/provider readback, security audit, governance ratification, legal/economic approval, and restart/fork/recovery certification.

No CHLOM Coin, CHM token, public NFT, external settlement, public-chain root, or validator network is represented as issued or operational by this release.
