# Aggregate original sanction history

The generation (G), multiple-dispute (MD), and PRIMARY_ONLY collaborator (PC)
recovery profiles can compose original sanction operations 12 and confirmation
operations 13 with their existing Consent families, including original
ratifications (52). These profiles retain their existing same-Artist binding
restrictions. CompleteHistory uses separate adapters for histories whose
principal changes between generations.

## Original records and clocks

The collector reads the original Archive catalogue once and assigns every
operation 12/13 to exactly one collection and its exact historical binding.
Current collection selectors do not replace the Artist in an archived binding.
The complete `SanctionHistoryTypes.Inventory`, source catalogue indices, source
owner checkpoints, record hashes, signatures, and archive bytes remain intact.

Operation 12 commits Identity and Consent. Consent publishes native operation
12; Identity retains the original principal nonce and consumed-digest evidence.
Identity commits with a zero record, but living activity can also publish an
original notice-cancellation receipt (42) at that same Identity revision. That
receipt is checked separately from the unchanged owner record-chain tip.

Operation 13 commits Consent and Attribution at independent revisions. It has
no native operation-13 receipt. Its saved Finality record, ceremony target,
sanction, replay key, and original state transitions are checked using the
original confirmation proof. Confirmation adds one Consent replay cell and no
Attribution replay cell. Both owners account for the real mutation in their
complete revision census.

Attribution state 3 requires the original confirmation. The MD path preserves
the confirmed restoration state through original dispute withdrawals and
upheld resolutions. Confirmation cannot occupy a binding, dispute, resolution,
repudiation, or native-record revision, and cannot be moved into a later binding
interval. The G/PC path preserves confirmed state before its supported final
revocation and correction sequence.

## Additive transport

The shared Consent supplement is defined by
`StreamArtistAggregateConsentSupplementTypes.Bundle`:

```text
G.Consents original
T.RatificationRecord[] ratifications
bytes sanctionInventory
```

The bytes field is exactly canonical `abi.encode(H.Inventory)`. A sanction
inventory occurs only in row zero, once for the whole aggregate. Row zero is
its carrier; that collection does not own the global catalogue. The other rows
keep their previous original or ratification-only encoding. Empty supplements
keep the exact previous `G.Consents` encoding.

Owner4 uses a separate additive first-row carrier around its original
Attribution tuple and the same complete sanction inventory. The original G,
MD, PC, and singleton tuple definitions are unchanged. Each owner independently
checks the original immutable evidence and its own full provenance. The
Coordinator retains the complete seven-owner proof and checks source
currentness again after all writes.

## Owner integration

The fixed `StreamArtistRecoveredAggregateConsentSupplementImport.applyState`
receives the existing sanction state and the two existing ratification maps.
It runs inside the owner's existing operation-60 guard, before the existing
aggregate Consent import. It does not return early from the owner operation.
The following import validates and installs all base and content rows in the
same transaction; any later failure rolls back supplement writes too.

The integration uses only the existing `SANCTION_HISTORY` feature bit (16384)
and the existing `RATIFICATIONS` bit (1024). Original entry points without the
supplement remain strict. The integrator owns the small owner-hook and allowed
feature-mask patch, as well as the final Consent initcode-size check.

Original sanctions do not consume delegation grants, so they add no grant-use
increments. The complete nonce inventory and the one global grant-use equality
remain the responsibility of the enclosing profile.

## Validation scope

This batch includes focused source, transport, clock, Identity, storage, and
current-stack regression cases. ABI/type checking is separate from runtime
evidence. Native compilation, the combined runtime cohort, bytecode capacity,
gas checks, and release evidence remain pending integration.

These imports preserve already-executed original confirmation history. They do
not extend the original destination writer to confirm an imported sanction
whose record was signed in another registry domain. They also do not change
the original confirmation writer's accepted sanction authority classes.
