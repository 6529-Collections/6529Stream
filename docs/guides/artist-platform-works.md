# Platform works declaration and corrective attribution

This source batch implements the AA-PLATFORM declaration, public claims,
governed contests and corrective binding using original operations 8, 9, 11
and 53. Existing Artist interface IDs and signature domains stay unchanged.
The additive `IStreamArtistPlatformWorks` interface provides immutable records
and the four normative summary getters. The contest vocabulary is 0 NONE,
1 CONTESTED, 2 CONTEST_DISMISSED and 3 CONTEST_SUSTAINED.

A Registry admin can declare a collection only before any successful Manager
phase policy registration and before any Artist binding generation. Manager's
`hasRegisteredPhasePolicy` is monotonic. A failed registration rolls it back;
disabling an executor cannot erase it. Mode 3 registration authenticates the
new capability and uses the exact declaration hash as evidence, without an
Artist signature. Open or sustained contests stop further minting. A public
claim alone does not stop minting or grant its claimant authority.

## Evidence publication

Publish the canonical binary `StreamArtistPlatformTypes.Evidence` bytes in
the selected collection metadata host's `StreamSchemaDocumentStore`. Its
five words are schema version 1, collection ID, proposed Artist address,
claim record hash, and a nonzero narrative commitment. An initial claim uses
a zero claim reference and may leave the proposed Artist address zero.
Resolution and correction documents name the exact original claim; the
approved correction names the author adjudicated by the sustaining action.
The document is a published allegation or decision, not self-authenticating
truth. The claim operation places its exact document and proof references in
the actual Artist Archive and immutable Attribution-owned claim history.

Both evidenceHash and reasonHash require published, byte-exact documents and
current dual-family archival coverage. They may reference the same document.
Use `recordCollectionEnvelope` with the actual collection ID, artistId zero,
schema `6529STREAM_PLATFORM_WORKS_EVIDENCE_V1`, `BINARY_EXACT_V1`, algorithm 2,
the SHA-256 digest and exact size. Record the original independent family
receipts, native checkpoint and fixities, then `recordCoverage`. The envelope
hash explicitly binds Core and collection. Artist-only coverage reads reject
these records. `selectCollectionCoverage` can select a freshly valid proof
without changing any immutable envelope, receipt or coverage record.

## Governance and correction

Use `platformWorksContext` to construct exact scope/old/new commitments. The
canonical Executor must execute with an actual Arbiter proposer: class 1 for
contest transitions and class 2 TERMINAL_FREEZE for correction. An unrelated
permissionless claim does not invalidate a scheduled context. A claim cannot
be silently substituted, a sustained contest cannot be dismissed away, and
the two contest actions cannot reuse one action for the same collection.
Action replay is collection-scoped so one governed batch may operate on
different collections.

Correction approval permits exactly one original `proposeArtistBinding`
generation naming the adjudicated author. It creates no signature and grants
no global economics mutation authority. The original Artist acceptance and
collaborator completion rules apply. Refusal or withdrawal consumes this
one-generation opportunity permanently. Completed acceptance changes the
operative consent mode to the binding's signed-policy mode. Further minting
requires that binding's policy and economics consents, operative payout,
first-release content ratification, deployment and personhood attestations.

The declaration, claims, sustaining action and correction remain readable.
Consumers use `platformWorksState` to display permanent contested and corrected
attribution. Existing settlements and token royalties are not rewritten.
An already executed scope whose saved component was the declaration retains
that exact finality component. A corrected scope finalized later with an
Artist sanction retains its sanction; a mere finalized flag does not relabel
it as a declaration. The original sanction-confirmation reader still rejects
a saved declaration as an Artist sanction.

## Validation boundary

The focused test file is
`test/unit/artist/StreamArtistPlatformWorks.t.sol`. Its source covers actual
Artist owners, Coordinator, Archive, threshold Safe, Manager and preservation
contracts, including native single-leaf checkpoint proofs. Core, selected
metadata-host getters and governance action contexts are explicit unit
boundaries. The byte store, receipt/fixity checks and dual-family proofs are
actual contracts; synthetic observer statements do not prove a network upload.

Only ABI/type checking has been run for this batch. Runtime, complete linked
product sizes, isolated transaction gas, paid platform commerce and the full
current graph remain consolidated validation obligations. No independent C
source review was performed; C is implementing the recorded-media batch.

The pending focused command uses the existing aggregate unit fixture:

```powershell
python scripts/dev.py test --suite unit --match-path test/unit/artist/StreamArtistPlatformWorks.t.sol --via-ir --code-size-limit 2000000 --gas-limit 1000000000 --memory-limit 1073741824
```

The fixture's intra-transaction CREATE predictions require that aggregate
mode. This command is not an individual deployment-transaction capacity test.
