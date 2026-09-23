# Recovered Platform Works history

The additive operation-60 `HISTORY_PLATFORM` profile retains original Platform
Works declarations, claims, contests, correction approvals and subsequent binding
continuations alongside the supported living Artist history. It supports one
Artist and one currently accepted collection binding. The original Artist and
Platform producers, signing domains, twenty-word `PW.State`, original hashes,
replay cells and existing hydration encodings remain unchanged.

This implements another composition required by
[Artist authority and migration](../stream-artist-authority.md). It builds on
[complete content history](artist-recovered-history-content.md) and
[sanction history](artist-recovered-sanction-history.md). Unbound Platform-only
collections, multiple Artists/collections and native operation-24 combinations
remain required subsequent implementation; this profile does not claim them.

## Selection and transport

The existing `RH.Request`, `hydrateRecoveredArtistAuthority` and
`hydrateRecoveredArtistAuthorityWithConsents` entry points are unchanged. Complete
authenticated owner-4 journals select `HISTORY_PLATFORM`, bit 65536, for original
operations 8, 9, 10, 11 or 53. These original receipts have a zero Artist ID and
the actual collection ID. Admission includes them only in that collection's lane
and full journal. It never assigns the current Artist to an old declaration or
allegation. Every other zero-Artist operation remains outside this exception.

Owner 0 uses the explicit `PLATFORM_BINDINGS_V1` tag with the complete original
`CB.Bundle`. Owner 3 retains the original acceptance codec. Owner 6 retains the
existing complete base, sanction or `HISTORY_CONTENT` codec as selected by the
actual original rows, including the existing exhaustive royalty witness array.
Owner 4 uses this closed canonical envelope:

```solidity
bytes[4] memory parts = [
    abi.encode(bundle.original), // complete D.Bundle
    abi.encode(bundle.sanctions), // complete H.Inventory
    abi.encode(bundle.platform), // complete Platform and Archive facts
    abi.encode(bundle.bindings) // complete CB.Bundle
];
abi.encode(
    keccak256("6529STREAM_ARTIST_RECOVERED_PLATFORM_HISTORY_V1"),
    uint16(1),
    parts
);
```

Every member and the outer envelope must re-encode exactly. Splitting the new
envelope avoids a giant generated Solidity tuple decoder; it does not project or
omit fields. Complete validation precedes all import writes. The existing owner
operation-60 checks and original seven-owner/Archive atomic commit remain the
only write authority.

## Original records and independent clocks

The profile reconstructs all declaration, claim, contest and correction hashes
in their original source environment. Fields absent from a native record hash,
such as a claim's proposed Artist, are joined to the exact immutable original
Archive payload. It retains both claim families, their separate subject guards,
the combined display head and every consumed governance action.

Original owner-4 proposal, acceptance, refusal and withdrawal commits have no
native receipt. The profile therefore reconstructs the complete original Archive
catalogue, bounded by 16,384 entries and 64 MiB, with all seven owners' exact era
cutoffs. It uses the paired before/after snapshots of each actual operation;
unrelated owners' revision numbers are never treated as interchangeable clocks.
Original catalogue/runtime/configuration and semantic source checks repeat in
the same call and again after the seven owner imports, before the final Archive
append.

The first correction's consumed generation and original acceptance flag remain
historical facts. Later continuations retain the complete fresh class-2 approval,
wrapped original terminal cause, prior lineage, new binding and original
acceptance record. Supplemental effective acceptance is distinct from the old
flag. Import never resets a consumed approval, promotes an allegation to
authority, reauthorizes a historic signature or makes a revoked grant usable.

## Evidence and limits

The new tests use actual Platform and Artist producers, original owners,
Coordinator, Store, Archive and threshold Safe. Core, governance eligibility and
documentary coverage retain the inherited explicit typed boundaries. The test
setup adds one default-no-op hook before the original initial proposal so the
Platform declaration and approval are produced in their genuine order.

Authored cases cover refused, withdrawn and previously accepted corrections;
fresh continuation and repudiation causes; repeated A-to-B-to-C import; both claim
heads; content/freeze/52 and confirmed-state-3 composition; missing/altered Archive
evidence, wrapped-cause substitution and source drift; retained replay refusal;
and counted late-Archive rollback with the identical Safe request retry. A
separate bound-collection case covers allegations without a Platform declaration
and compares the original owner-6 codec bytes.

ABI checks and selected compiler size captures are development evidence. These
authored cases are not native execution, maximum-carrier capacity or full current
stack acceptance. Original per-call budgets, carrier limits and deployment limits
are unchanged.
