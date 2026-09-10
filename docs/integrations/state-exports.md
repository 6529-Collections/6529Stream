# Discover and publish state exports

State exports give reconstruction clients a durable onchain reference to an
offchain snapshot. The current publisher is hosted on the actual governance
Executor. Its storage is append-only; the linked implementation preserves the
Executor as the address emitting events and checking the caller's role.

## Discover the active publisher

Read Core's `getSatellitePointer(keccak256("STATE_EXPORT_PUBLISHER"))`. For the
governance-hosted publisher, the target is the Executor and its module type is
`GOVERNANCE_LAYER`. Check its recorded code hash and the canonical read interface
`0x77faad4f`. Import
[IStreamStateExportPublisher](../../smart-contracts/interfaces/stream/governance/IStreamStateExportPublisher.sol)
for `latestStateExport()`, which returns the block number/hash, export hash,
manifest hash and manifest URI. All fields are zero or empty before publication.

The [history interface](../../smart-contracts/interfaces/stream/governance/IStreamStateExportHistory.sol)
provides the count, hash at each zero-based index, immutable records, supersession
links and challenge-existence checks. A record's sequence starts at one; an
unknown hash returns a zero record. Indexers should also retain the three
canonical events, emitted with schema version 1 from the Executor:

- `StateExportPublished`: indexed block number, export hash and manifest hash;
  data includes the block hash and manifest URI.
- `StateExportChallenged`: indexed export hash, challenge hash and challenger;
  data includes the challenge URI.
- `StateExportSuperseded`: indexed old hash, new hash and reason hash;
  data includes the reason URI.

## Publish a snapshot claim

Use the separate
[operations interface](../../smart-contracts/interfaces/stream/governance/IStreamStateExportOperations.sol).
The transaction sender must currently hold `ROLE_EXPORT_PUBLISHER` in the bound
RoleRegistry. Ownership, proposing/cancelling authority and RoleManager status
alone do not grant publication rights. Operational roles can be granted and
revoked through the existing governance/RoleManager rules.

Call `publishStateExport(blockNumber, blockHash, exportHash, manifestHash, manifestURI)`
directly from that holder. The anchor must be a nonzero past block within the
EVM's 256-block hash window and must match `blockhash(blockNumber)`. Choose an
anchor that remains in that window when the transaction is included. Export and
manifest hashes must be nonzero, and each export hash may be published once.
Manifest hashes may repeat; the contract does not inspect their offchain content.

Publication heights increase. An equal-height publication is allowed only when
the canonical block hash differs from the previous publication's anchor, enabling
an append-only reorg correction. A correction of content on the same canonical
fork uses a newer anchor. Manifest, challenge and reason URIs must contain
1–2,048 bytes of valid UTF-8.

All writers reject calls during an executing governance batch and after Core's
publisher pointer has moved away from this Executor. Governance changes the role
or pointer; a separate operational transaction publishes the snapshot.

## Challenge and supersede

Anyone can call `challengeStateExport(exportHash, challengeHash, challengeURI)`
for a known export, including one already superseded. The challenge hash must be
nonzero. The pair `(exportHash, challengeHash)` is recorded once, regardless of
caller; it does not change the latest publication or decide whether a claim is
correct. Indexers can inspect the event's challenger and retrieve the evidence.

A live publisher may call
`supersedeStateExport(oldExportHash, newExportHash, reasonHash, reasonURI)`.
Both exports must already exist on this publisher, and the target must have a
higher publication sequence. Each old export receives at most one forward link.
This prevents cycles and preserves the original record. The latest read continues
to identify the most recently published claim; a challenge or supersession does
not roll it back.

When governance installs a different publisher, historical reads on the old
Executor remain available. There is no implicit import or trust of the previous
publisher's records. Follow Core pointer-update events across that handoff and
validate each publisher's history separately.

Publication is a hash-bound claim. Reconstruction, canonical export encoding,
archival availability, receipts, cadence and the correctness of the exported
state require their own evidence. An onchain publication does not complete the
full genesis profile, an audit, or production readiness.

The [current-stack suite](../../test/current/StreamCurrentStateExport.t.sol)
exercises real Core/ModuleRegistry installation, live role changes, transaction
context, reorg boundaries, receipts, lineage and governed pointer replacement.
