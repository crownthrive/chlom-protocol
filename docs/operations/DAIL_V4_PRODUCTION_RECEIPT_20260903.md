# DAIL v4 Production Scaling Receipt — 2026-09-03

## Defect

The prior checkpoint worker processed 20,000 events per batch by inserting per-event membership rows, rewriting checkpoint references on immutable DAIL rows, and calculating an exact anti-join count across multi-million-row tables. Jobs took approximately 80–150 seconds and repeatedly exceeded the statement budget. The prior full-chain compatibility verifier also rescanned the entire post-checkpoint tail.

## Repair

DAIL v4 replaced that hot path with:

- bounded batches of actual ordered events;
- one compact signed segment per range;
- no mass update of `dail_events`;
- no per-event membership insert;
- no exact anti-join count;
- persisted cursor and fencing lock;
- predecessor-boundary, payload-hash, event-hash, and link verification;
- Merkle inclusion proofs generated on demand;
- linked segment roots and gated external anchor intents;
- v3 compatibility functions delegated to v4.

PostgreSQL identity sequences are monotonic but not gapless. A rejected segment exposed missing sequence values `2152455`, `2152462`, and `2154491` while all cryptographic checks were zero-failure. The rejected segment remains immutable evidence. An append-only algorithm correction distinguishes sequence allocation gaps from chain-integrity failures; batching now selects actual ordered events.

## Evidence

- v2 immutable base checkpoint: `dfb2018c-7dba-4200-b8af-16951efd4cc8`
- base end sequence: `2146689`
- base root: `d148f7de54d83013990fdafa4dabbe613fdd806ceb14377cd62df7ca416638fe`
- first scaling canary: `69e8ee65-5990-4ede-b909-41fa785fa139`, PASS
- first canary evidence SHA-256: `28d7954185f926df28798aaecf6cd720cc85a85787ac88a71e4dc44cb66a0351`
- gap-tolerant canary: `ccdeb673-648d-4e99-8e32-ae4c2bab2f4b`, PASS
- gap-tolerant evidence SHA-256: `982ecac076f0d60222f39daba185c79760bdd8d075673b821ac2e6d6c954b084`
- rejected algorithm segment preserved: `cfcf6326-ac82-40f4-a0e6-eaf4557ea82b`
- 100,000-event catch-up completed in approximately 47 seconds
- a subsequent 18-event tail certified in approximately 232 ms with lag zero
- recurring worker: `chlom-dail-compact-catchup-v4`, every two minutes, four batches of up to 5,000 actual events

## Production disposition

`PASS` for the compact verifier and continuous catch-up path. External public-chain anchoring remains provider- and authority-gated. Assurance is based on signed base checkpoint plus linked v4 segments, not a manufactured claim that one monolithic SQL statement rescanned all history.
