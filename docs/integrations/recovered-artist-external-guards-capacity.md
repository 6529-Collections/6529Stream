# Recovered Artist external guard capacity

This repair keeps the original recovered-authority external observations and
snapshot schema. It changes the fixed library transport, not the authority,
replay, payment, recovery, or destination write rules.

`StreamArtistRecoveredExternalGuards.collect` retains its named provenance and
Identity bundle arguments and original ABI. Its arguments are now calldata.
The original provenance validation, action and finding limits, point checks,
full consumed ActionRow/FindingRow copies, journal membership checks, and loop
order remain unchanged. The four private finality/entropy observation methods
forward to two fixed typed libraries. Those libraries retain the original
runtime pins, canonical return shapes, external read limits, record comparisons,
terminal statuses, and exact error order. They execute in the original host
context and do not write storage or select a caller-supplied delegate target.

The canonical producer boundary is required. The original Identity owner forwards
its closed raw export to `StreamArtistRecoveredIdentityTransport`, which returns
`abi.encode(bundle)` from its fixed export worker. The original
`StreamArtistRecoveredIdentityHydrationSource.collect` validates the pinned source,
complete typed return, current snapshot, records, structural provenance, and source
auxiliary facts. The unchanged Prepared worker receives that complete memory
bundle and calls `External.collect(c.provenance, identity)`, generating the
original canonical Solidity calldata. Source transport, Prepared, Identity owner,
records, and delegation validation are unchanged by this repair.

A direct malformed call to this stateless library that corrupts an unused,
unrelated Identity bundle field is outside the compatibility claim: calldata
access does not eagerly decode every unrelated field. Every consumed field and
explicit predicate remains checked. This is not a new route to import or accept
caller-authored Identity state. The snapshot, action/finding identities, and all
original authorization and commitment domains are unchanged.

On base `2669c6ecfa45be2e5f01efba99be3d8585a3f229`, the selected Solidity 0.8.19,
via-IR, 200-run, Paris, no-CBOR capture measures:

| Product | Runtime bytes | Creation bytes |
| --- | ---: | ---: |
| ExternalGuards | 20,665 | 20,697 |
| RecoveredFinalityGuards | 8,640 | 8,672 |
| RecoveredEntropyGuards | 5,589 | 5,621 |

The original matching ExternalGuards was 37,491 runtime bytes. The final selected
closure has 64 sources; a separate 210-source ABI check includes the unchanged
Prepared caller and original external-guard test suite. All six original library
ABI entries are identical, storage remains empty, and the original unmoved
function bodies are exact. Moved bodies differ only in fixed names and type/error
qualification. The source evidence records the canonical producer files and their
unchanged hashes.

No native test or cold call-budget claim is made by this capacity capture. The
existing typed external-guard controls and full recovered-authority operation
remain distinct runtime validation scopes. Added call-frame overhead still needs
that integration evidence; fitting these three products does not establish the
capacity of all other recovered-authority dependencies.
