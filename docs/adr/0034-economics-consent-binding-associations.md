# ADR 0034: Economics consent binding associations

Status: accepted implementation decision; source and runtime acceptance remain separate.

## Context

The original economics store indexes the complete `EconomicsConsent` payload `p`.
Its immutable first record and single-use `consent_key` do not include the artist,
binding generation, or binding hash. Corrective rebinding must require the new
artist's full consent chain (AA-PLATFORM8), while fresh consent to the same
economics hash must remain possible. Authority rotation, estate succession, and
payout revisions within an unchanged binding must preserve existing consent.

## Decision

Preserve the permanent signature and economics record preimages, the first raw
`economicsRecord(p)`, and its consumed replay cell. Append immutable association
evidence to each new record: `(artistId, bindingGeneration, bindingHash,
payloadHash, originalRecord)`, where `payloadHash = keccak256(abi.encode(p))`.
For the first record, `originalRecord` is that record itself.

The association lookup key is:

```text
keccak256(abi.encode(
  keccak256("6529STREAM_ARTIST_ECONOMICS_BINDING_ASSOCIATION_V1"),
  p, artistId, bindingGeneration, bindingHash))
```

The first association consumes the original `consent_key(payloadHash)` lane.
When the actual current binding has a later generation, its fresh authorization
consumes the same named `consent_finality.replay.consent_key` surface with scope:

```text
keccak256(abi.encode(
  keccak256("6529STREAM_ARTIST_ECONOMICS_BINDING_CONTINUATION_V1"),
  originalRecord, p, artistId, bindingGeneration, bindingHash))
```

Admission requires the original evidence to identify the immutable raw record
and exact payload hash. Missing old evidence fails closed; no migration facts
are inferred. Repeating the first association reaches its original consumed
scope; repeating a continuation reaches its exact continuation scope. Original
cells and records are never reset or overwritten. A third generation uses a new
association scope anchored to the same first record.

The Coordinator obtains the actual accepted binding and snapshots its owner
before invoking the Consent owner. The owner validates the typed authority and
records the association in its same guarded commit. Archive operation 15 retains
the canonical payload fields and adds candidate and association evidence. An
additive association event exposes the exact immutable join.

Every operative economics read must obtain the actual current binding and
select its exact association. The historical raw getter remains available and
does not assert current applicability. Authority address/class and payout
revision are deliberately absent from the join. This preserves lawful rotation,
succession, static payout history, and previously authorized obligations.

## Scope and evidence

The connected primary scope increment keeps an exact-key clear result of zero
separate from the nonzero token/collection/default assignment selected afterward
(ADR 0021). Default signatures do not sign the admitting collection: one actual
collection context is checked and archived, and the proof's nonce is consumed
once. A default consent is never automatically reused for another collection.

Required evidence includes original and later generations with identical terms,
third-generation continuation, exact replay scopes, wrong association rejection,
nonce/callback/Archive rollback, and same-association payout/rotation/estate
continuity. Corrective rebinding ingress remains separately scoped; a test
boundary supplying binding facts is not proof of that ingress. Royalty token
support and broader assignment freeze modes remain separate delivery work.
