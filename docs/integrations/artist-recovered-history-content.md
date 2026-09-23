# Recovered content across accepted and disputed Artist history

The additive operation-60 `HISTORY_CONTENT` profile retains original content,
royalty freeze, content freeze and ratification records alongside complete
accepted/corrected binding, dispute, repudiation and sanction/confirmation history.
It supports one recovered living Artist and one collection. Earlier generations
remain addressable under their own original keys; importing history does not
reauthorize an old signature or make a revoked or exhausted grant usable.

The governing requirements remain [Artist authority and migration](../stream-artist-authority.md),
including complete original history, signature domains, replay and atomic import.
This profile extends the supported combinations documented in the
[sanction-history guide](artist-recovered-sanction-history.md).

## Selection and exact transport

The existing `RH.Request`, `hydrateRecoveredArtistAuthority` and
`hydrateRecoveredArtistAuthorityWithConsents` interfaces are unchanged. Royalty
terms use the latter's existing exhaustive operation-20 witness array. Source
history selects the new profile when operations 17, 20, 21 or 52 coexist with
sanctions, the complete dispute profile or multiple accepted generations. Earlier
supported profiles retain their original tags, encodings and branch behavior.

Every owner advertises the separate `HISTORY_CONTENT` bit, 32768. The complete
seven-owner headers retain `DISPUTE_HISTORY`, plus `SANCTION_HISTORY` only when
the actual source contains it. `CONTENT_CONSENTS` and `RATIFICATIONS` likewise
follow actual retained rows. Caller-supplied capability or witness lists cannot
select a partial history or downgrade to an older codec.

Owner 6 uses exactly:

```solidity
abi.encode(
    keccak256("6529STREAM_ARTIST_RECOVERED_HISTORY_CONTENT_V1"),
    uint16(1),
    bundle
)
```

The bundle holds the preceding base-consent history and complete original Binding
rows, original content/royalty/freeze rows, original three-word ratification rows,
and the complete sanction inventory when present. Owner 0, owner 3 and owner 4
keep the already supported dispute/sanction encodings. No signing domain, native
record, request selector, owner storage layout or original producer is changed.

## Historical facts and completeness

The complete Binding source proves which generations were actually accepted.
Operations 15, 16, 17, 20 and 21 retain the generations that their original records
attest. A royalty witness is matched against those authenticated generations and
must identify exactly its original native record in complete journal order.
Missing, extra, duplicate or foreign witnesses refuse before import.

Original policy and operation-52 records do not carry a generation/signer/nonce/
time preimage. This transport preserves their exact original fields, signatures
and authenticated source positions; it does not assign a later generation or
invent those missing facts. An empty direct/Safe signature is still one required
retained signature row. The global operation-52 head remains global.

The full ordered owner-6 journal accounts for operations 12, 14, 15, 16, 17, 20,
21 and 52. Original operation 13 remains a separate zero-native occurrence with
its own authenticated Archive evidence and independent owner-4/owner-6 revision
points. Every era's revisions, replay cells and native counts are reconciled.
The original Archive catalogue is rechecked after writes when sanctions are
present. No cross-owner chronology is inferred from unrelated revision numbers.

Historical grants retain their original association, epoch, use count and
revocation state. The single complete Identity inventory reconciles policy,
economics, sale, dispute/repudiation and royalty uses together. Current grant
replacement or liveness never substitutes for a recorded authorization.

## Import and bounds

The original owner operation-60 guards run before fixed typed import workers.
Base consent and optional sanction records are retained first, then original
content/royalty/freeze maps use each row's authenticated historical generation,
followed by the original ratification records/head. The preceding source checks,
seven-owner commit and Archive append stay atomic. Any failure rolls back semantic
maps, replay/nonce state and the enclosing Safe nonce.

The profile retains the existing bounded provenance and catalogue limits. Each
content family and each policy/economics/sale witness list has at most 128 rows;
the complete original Binding inventory has at most 128 generations. These are
transport refusal bounds, not new rules invalidating longer original histories.
Evidence pages remain limited to 24,575 bytes and deployment/gas limits remain
unchanged. Exhaustive reads and the complete typed envelope still need separate
runtime and maximum-capacity measurements.

## Evidence and remaining work

Thirteen authored cases use actual Artist producers/owners, Safe signatures, Archive
and recovered operation 60. They cover multiple accepted generations, confirmed
and open-dispute states, A-to-B-to-C transport, signed and empty operation-52
evidence, mixed grant-use conservation and fresh successor authority, malformed
witnesses/heads/tags/flags/replay, and two counted Archive attempts across late
failure and identical Safe-byte retry. Literal record, encoding and Archive/event
preimages remain independent assertions.

Core, governance execution, metadata and documentary coverage remain explicit
inherited typed boundaries. Executed Finality facts are typed historical responses;
the fixture does not execute the Finality governance transaction. Source/ABI and
selected bytecode results do not establish native execution or a full-current
transaction-capacity acceptance.

The final focused ABI capture covers 1,271 sources with no errors. Comparison
against the preceding profile retains all 717 original affected ABI entries,
selectors and recursive storage layouts. Selected production captures fit all
23 new, changed or paired nonempty products. The complete facts worker is 24,565
runtime bytes, leaving only 11 bytes of headroom. Consent is 22,336 runtime bytes
and 48,852 initcode bytes including its five constructor arguments; the reduction
changes only twelve terminal-return declarations, with their original bodies and
constructor unchanged. Earlier over-limit captures remain part of the evidence.

Platform declarations/continuations, native attestation 24 and multiple Artists
or collections remain required following compositions. Unsupported histories
continue to refuse before import rather than disappear from the inventory.
