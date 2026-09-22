# Preservation checkpoint and manifest capacity

The collection and scoped preservation checkpoints share one engine across
their original V1 and V2 profiles. The output manifests likewise share an engine.
Their public functions, complete error/event ABIs, constructor inputs, storage
layouts and original gas-parameter IDs remain unchanged.

`StreamPreservationContentAdmissionV1` is a fixed linked library. It performs
the complete original producer-binding and selected Registry admission checks,
then separately validates the complete selected configuration and raw source.
The first entry returns the original Binding and Admission; the second returns
only the authenticated image URI. Original read order, exact request calldata,
canonical framing, all source hashes and each live registered gas lookup remain.
Delegate calls preserve the checkpoint as the caller seen by dependencies.

The checkpoint retains entropy validation, complete JSON/HTML/data reads,
hash preimages, every-row reobservation, all writes and rollback. No sampled
freshness or replacement source assertion is introduced. In particular, a
changed non-image source field still invalidates the full raw-source hash.

`StreamPreservationOutputDocumentsV1` returns the exact existing V1/V2 canonical
document bytes. All document-registry reads, framing checks, expected hashes,
currentness, governed read caps and manifest writes remain in the host. The
original document definitions are unchanged.

## Focused evidence

The Solidity 0.8.19/via-IR/optimizer-200/Paris capture uses the original no-CBOR
and no-bytecode-hash settings. Its input SHA-256 is
`5e5b4ac83157f42e708b2477de50fc4538e3ba2efa772dfd73c4f0b61f28a83a`.

| Product | Runtime bytes | Full initialization bytes |
| --- | ---: | ---: |
| Collection checkpoint V1 and V2 | 22,475 | 26,810 |
| Scoped checkpoint V1 and V2 | 22,475 | 26,988 |
| Admission/source-image library | 7,648 | 7,680 |
| Output manifest V1 | 14,293 | 17,553 |
| Output manifest V2 | 14,293 | 17,612 |
| Canonical document library | 13,674 | 13,706 |

All eight products fit the original 24,576-byte runtime and 49,152-byte full
initialization limits. Checkpoint constructor arguments add 576 bytes;
manifest arguments add 352 using the original gas-parameter names. Static
placeholder values establish lengths only, not valid deployment calldata or
successful CREATE. The six wrappers retain identical full ABIs, selectors and
recursive storage layouts.

Nineteen focused tests execute the actual admission/source-image library with
explicit synthetic producer, Registry and Router boundaries. They include two
256-input fuzz properties; exact caller and original calldata checks; both
supported producer profiles and wrong-profile refusal; every admission field;
changed source pins; complete configuration/raw-source hashes; canonical
framing; complete image bytes; read bounds; current gas revisions; overflow
and finite parent-headroom refusals; and identical retry after restoration.

This evidence does not establish full checkpoint/manifest flows, all-call Safe
integration, full-flow gas or current-stack acceptance. Added library frames
change gas consumption; original dependency caps and parent-reserve formulas
remain. Existing full-flow suites and the matching release/testnet rehearsal
remain required. Earlier failed size captures are preserved separately.
