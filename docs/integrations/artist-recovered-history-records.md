# Original op24 records across recovered Artist history

`HISTORY_RECORDS` adds complete original Artist attestation history to the
existing recovered binding, dispute, sanction, Platform and content histories.
This batch supports one living Artist and one collection with a current accepted
binding. It preserves each historical record's original registry, signer,
authority class, generation, signature and statement bytes. It does not authorize
new records with a historical signature or restore an unavailable delegation.

## Selection and transport

The existing operation-60 request and both original recovered-hydration entry
points are unchanged. Ordered op24 preimages use the existing
`records.witnesses[].attestations` array. Complete source journals select the
additive bit `HISTORY_RECORDS = 131072` when op24 occurs with the complete
binding/dispute/sanction/Platform history route. Old supported operation-24 and
history codecs retain their original tags and behavior.

Owner 4 receives the following exact canonical tuple:

```solidity
abi.encode(
    keccak256("6529STREAM_ARTIST_RECOVERED_HISTORY_RECORDS_V1"),
    uint16(1),
    bytes[5]([
        abi.encode(completeDisputeHistory),
        abi.encode(completeSanctionInventory),
        abi.encode(completePlatformHistory),
        abi.encode(completeBindingCorrections),
        abi.encode(completeOriginalAttestationBundle)
    ])
)
```

Each member retains its original nominal struct. The complete Platform member
may contain no Platform declaration or native Platform rows; its authenticated
Archive binding clocks are still required. No zero-Artist association is invented
for an op24 record. The original collection-only zero-Artist exception remains
limited to Platform operations 8, 9, 10, 11 and 53.

Owner 0 uses the separate tag
`6529STREAM_ARTIST_RECOVERED_HISTORY_RECORD_BINDINGS_V1`, version 1, and the full
original correction bundle. Owner 3 keeps its original acceptance codec. Owner 6
keeps the existing complete base, sanction or HISTORY_CONTENT codec, selected by
actual retained rows. No new signing domain, producer, facade selector, owner
storage field or write authority is introduced.

## Complete history and exact generations

The validator enumerates every op24 occurrence in the unfiltered native owner-4
journal. Missing, extra, duplicate, foreign or out-of-order witnesses refuse.
Every row joins the original attestation record, authenticated subject association,
statement, publication evidence where applicable, signature and exact native
source position.

Generation is not part of the original attestation record hash. The new profile
therefore proves more than hash equality: the saved generation must be an actually
accepted Binding row, and the op24 owner-4 position must follow that generation's
original acceptance completion and precede the next owner-4 proposal. It never
compares unrelated owner-0 and owner-4 revision counters or relabels a record with
the current binding. Original full Archive catalogues establish the independent
clocks and are rechecked after all owner writes.

One complete Identity proof conserves original nonce cells, signature rows,
authorization digests and delegation uses across policy/sale/economics,
dispute/repudiation, royalty and op24 families. Imported revoked, expired,
exhausted or replaced grants remain historical and cannot authorize fresh writes.
The original op52 three-word records retain their actual fields; no generation is
invented for them.

## C2PA, personhood and publication

C2PA rows retain their complete ordered previous-head chain and exact original
credential/key-history bytes. Each imported C2PA head uses its saved binding and
original registry. Personhood heads remain independent of later credential-only
updates. Sparse documentary summaries retain the original native record,
operative identity, source registry, immutable pins and exact summary hash.
Historical opaque evidence stays unresolved and an explicit waiver retains its
original meaning; a resolved summary is documentary evidence, not a claim of
legal personhood.

Publication rows retain the existing original subject-kind 7/8 evidence and
consumption fields. This transport does not recreate publication authority or
call a newer metadata producer to replace the saved preimage.

All destination empty-map checks run before the first semantic write. The fixed
workers then retain the original Attribution/dispute/Platform order followed by
original record, credential and authenticated personhood-summary imports.
Original operation-60 guards, seven-owner commit, late source recheck and Archive
append remain atomic.

## Evidence and limits

Sixteen authored actual-owner/Safe scenarios cover mixed Platform and op24,
accepted generations, content/freeze/52 and confirmation, two successive imports,
original documentary and credential domains, separate exhausted-unrevoked and revoked-under-limit live refusals and fresh
authority, omitted/malformed/foreign witnesses, and a counted two-call late Archive
failure followed by identical saved Safe-byte retry. The documentary notary uses
actual General/schema/Store receipt production with explicitly synthetic fixture
instruments. Core, eligibility and other inherited external boundaries remain
typed. These tests are typechecked; no new EVM, full-current or maximum-capacity
acceptance is claimed here.

The original bounded journals, 128-row witness/generation limits, 24,575-byte
evidence pages, EIP-170/EIP-3860 limits and governed gas caps are unchanged. Fixed
canonical-byte workers reduce repeated compiler encoding code without omitting a
member, field or validation. The original and record-aware Platform wrappers link
to five fixed shared libraries: `StreamArtistRecoveredPlatformDisputeRowsKernel`,
`StreamArtistRecoveredPlatformDisputeSourceKernel`,
`StreamArtistRecoveredPlatformTimelineKernel`,
`StreamArtistRecoveredPlatformCompletionProofKernel` and
`StreamArtistRecoveredPlatformProposalProofKernel`. They receive the complete
original typed arguments; their public pure/view entries retain the exact original
shared body and validation order. Fixed library delegation preserves the caller
and storage context. The additional ABI boundary affects gas and has no mutable
target or write authority. Wrapper error declarations preserve the original ABI
entries for errors bubbled by these helpers.

The retained selected captures measure the five wrapper/kernel pairs at at most
21,392 runtime bytes and 21,424 creation bytes, and Preparation at 23,295 runtime
bytes. These captures precede a recorded formatter-only source bridge and the
wrapper error declarations; the final 1,345-source type check is clean. Earlier
oversized selected products remain retained as failed evidence. Complete native
execution, current-source deployment and maximum-workload gas acceptance remain
pending.

Complete multiple-Artist/multiple-collection composition and wholly unbound
Platform histories remain required following batches. They are not inferred from
this one-Artist/collection profile. The original collaborator, terminal/advanced
history and explicitly unsupported configuration families remain subject to their
separate supported-profile rules.
