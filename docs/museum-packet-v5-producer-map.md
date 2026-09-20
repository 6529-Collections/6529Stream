# Museum packet V5 producer map

This map records the native producer surfaces that can support acquisition
packet requirements 6 and 13 and the preservation evidence adjacent to them.
The contract references are pinned to integration source
`905bbe2a3f33f5e7fca436a987d8cba532149e8e`. Later Museum adapters keep their
own source-review pins and do not change the meaning of this source.

The V5 packet is a supplied-data representation. A field becomes
source-covered only when a named offline capture below replays its exact native
producer. Schema validation alone does not authenticate a value or an absence.

The principal pinned source files are:

| Surface | Interface or implementation source |
| --- | --- |
| attribution state | `smart-contracts/interfaces/stream/artist/IStreamArtistAttributionState.sol`; `smart-contracts/domains/artist/StreamArtistSaleOperations.sol` |
| sanction record and archive | `smart-contracts/interfaces/stream/artist/IStreamArtistSanctionOwner.sol`; `smart-contracts/interfaces/stream/artist/StreamArtistSanctionTypes.sol`; `smart-contracts/domains/artist/StreamArtistSanctionHashes.sol` |
| attribution transition | `smart-contracts/domains/artist/StreamArtistAttributionAttestations.sol` |
| media masters | `smart-contracts/interfaces/stream/metadata/IStreamMediaMasterSelection.sol`; `smart-contracts/interfaces/stream/metadata/StreamMediaMasterTypes.sol`; `smart-contracts/domains/metadata/StreamMediaMasterSelection.sol` |
| archive coverage | `smart-contracts/interfaces/stream/preservation/IStreamBundleArchiveCoverage.sol`; `smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol`; `smart-contracts/domains/preservation/StreamBundleArchiveCoverage.sol` |
| post-mint reference | `smart-contracts/interfaces/stream/preservation/IStreamReferenceRenderPublication.sol`; `smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol` |
| pre-sale reference | `smart-contracts/interfaces/stream/preservation/IStreamProspectiveReferencePublication.sol`; `smart-contracts/domains/preservation/StreamProspectiveReferencePublication.sol` |
| conservation floor bindings | `smart-contracts/interfaces/stream/metadata/StreamConservationFloorTypes.sol`; `smart-contracts/domains/metadata/StreamNativeConservationFloorProvider.sol` |

## Requirement 6: attribution and personhood

### Current attribution state

`IStreamArtistAttributionState.collectionArtistState(uint256)` returns:

```text
(uint8 state,
 uint64 bindingGeneration,
 bytes32 artistId,
 uint8 authorityStatus,
 bytes32 bindingHash)
```

The attribution states have this exact mapping:

| Native code | Native state | Packet state |
| --- | --- | --- |
| 0 | none | unresolved without a separate platform declaration |
| 1 | claimed | `claimed` |
| 2 | artist accepted | `artist_accepted` |
| 3 | artist sanctioned | `artist_sanctioned` |
| 4 | disputed | `disputed` |
| 5 | revoked | `revoked` |

Code 0 does not mean platform works. `platform_works` requires the separate
authenticated platform declaration. A binding must also match the attribution
generation before its Artist ID can be combined with a nonzero state.

The existing conservation-selection capture retains the underlying binding:

```text
(bytes32 artistId,
 address artistAddress,
 bytes32 identityRecordHash,
 bytes32 bindingHash,
 uint64 generation,
 uint8 consentMode,
 uint8 saleConsentScope,
 uint8 registryImmutabilityElection,
 address proposer,
 bool accepted)
```

It also retains `(uint8 state,uint64 generation)` from
`attributionState(uint256)` and the association
`(artistId,bindingHash,generation,identityRecordHash)`. These observations can
bind packet state, Artist ID and generation. They do not by themselves prove
the authority status or a sanction record.

### Sanction evidence

The current Artist suite stores sanctions in owner 6. The native reads are:

- `sanctionForAssociation(bytes32,uint64,bytes32,uint8,uint256,uint256,bytes32)`;
- `sanctionRecord(bytes32)`;
- `sanctionArchiveBytes(bytes32)`; and
- `sanctionArchiveFacts(bytes32)`.

`StreamArtistSanctionTypes.Record` is:

```text
(bytes32 recordHash,
 bytes32 artistId,
 address signer,
 uint8 authorityClass,
 Terms terms,
 uint256 nonce,
 uint64 signedAt,
 uint64 deadline,
 uint64 bindingGeneration,
 bytes32 bindingHash,
 bytes32 digest)
```

`Terms` is
`(uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId,bytes32 sanctionSubjectHash,bytes32 statementHash)`.
Archive facts are
`(recordHash,artistId,schemaId,canonicalizationId,contentHash,uint64 byteLength)`.
The archive schema and canonicalization IDs are respectively
`keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_V1")` and
`keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_ABI_V1")`.

`ArtistSanctionRecorded` retains the original collection, subject, signer,
scope, record hash, authority class, statement hash, nonce and signing time.
The record hash is:

```text
keccak256(bytes.concat(
  abi.encode(
    keccak256("6529STREAM_ARTIST_SANCTION_RECORD_V1"),
    chainId, artistRegistry, artistId, signer, authorityClass, scopeType),
  abi.encode(
    collectionId, tokenId, scopeId, sanctionSubjectHash,
    statementHash, nonce, signedAt)))
```

The latest association sanction and the sanction that moved attribution from
accepted to sanctioned are different facts. The latter is identified by the
generation-specific `ArtistAttributionStateChanged` transition with old state
2 and new state 3. Its `recordHash` is the confirmed sanction and its
`reasonHash` is the finality record. A later sanction can replace
`sanctionForAssociation`; a dispute resolution can later restore state 3.
Readers therefore retain the complete state history, the original 2-to-3
transition, and the current association sanction separately. A difference is
reported, never resolved by recency alone.

### Existing personhood evidence

`STREAM_MUSEUM_PUBLIC_PERSONHOOD_SOURCE_V1` retains the current binding and
operative identity, the native personhood selection, the original operation-24
record and summary, and the complete joined General attestation evidence where
available. The standalone `STREAM_ACQUISITION_PERSONHOOD_V1` fragment is safe
to embed byte for byte. Its General record may use an independently scoped
notary collection ID; that scope is retained and is not rewritten to the
acquisition packet's collection.

This capture does not supply the missing sanction owner or turn a native
personhood observation into legal-person proof.

## Requirement 13: tier, intent and interview

The tier capture retains the Core declaration, the undeclared Lite default,
all allocated token identities and completed mint chronology. The
conservation-selection capture retains each selected Artist intent (kind 0) or
intent waiver (kind 1), interview status, original interview record where
present, publication authority class, predecessors, revisions and current
head. Historical selected rows remain distinct from later current heads.

Those two captures can populate requirement 13 now. The DIRECT composition
also compares the latest pre-first-sale selection with the facts saved by the
original floor. Missing or superseded documentary correspondence remains a
qualification; it does not become a current-head substitution.

## Preservation master source

`IStreamMediaMasterSelection` exposes a finite three-slot denominator:

- `collectionMediaContext(uint256)` returns
  `(bytes32 subjectId,bytes32 manifestHash,bytes32 inventoryHash,uint8 occupiedMask)`;
- `currentMaster(uint256,bytes32,uint8)` returns `Selection`;
- `masterSelectionAt(uint256,bytes32,uint8,uint64)` returns a historical
  `Selection`;
- `MediaMasterSelected` emits the complete selected row; and
- `requireCollectionMasters(uint256,bytes32)` returns the producer evidence
  hash.

`Selection` contains status (`absent`, `present` or `waived`), subject,
manifest, slot, display hash, object ID, original record evidence, Artist
association, master object and coverage hashes, role, predecessor, revision
and selection hash. Historical manifest bytes remain available through
Metadata `recordedMediaManifest(bytes32)`.

The original floor's `ReleaseFacts.mediaEvidenceHash` is exactly the
`requireCollectionMasters` result. It commits the producer/profile bindings,
the manifest and inventory, all three slot display hashes and the Artist
association, then folds each occupied slot's selection hash and archive hash.
For a waiver that archive hash is zero. For a present master it is
`keccak256(abi.encode(ObjectIdentity,Coverage))` from the external-artifact
coverage producer.

The provider capture currently preserves target 6 and its runtime hash but
does not interpret it. A new master capture can reconstruct the historical
sale hash from native history and the saved floor receipt without replacing it
with current master state.

## Archive coverage source

`StreamBundleArchiveCoverage` exposes:

- `dependencies()`;
- `bundleEvidence(bytes32)`;
- `progress(bytes32)` and `refresh(bytes32)`;
- `admittedItem(bytes32,uint64)`;
- `requireCoverage(bytes32,bytes32)`; and
- `requireFullCurrentCoverage(bytes32)`.

Its dependencies are
`(address[6] targets,bytes32[6] codeHashes,uint256 chainId,uint256 readGas,uint256 archiveGas)`.
`BundleEvidence` is
`(inventoryPlan,renderCriticalEvidenceHash,uint64 itemCount,evidenceChainHash,bundleCoverageHash)`.
Started, item-admitted, completed and refresh events provide the historical
coordinates.

The existing native render-inventory capture proves the producer's complete
inventory and retains the original reference receipt and source commitments.
It explicitly does not prove object bytes, archival coverage or reference
authority. A bundle-coverage capture may join that exact plan, but current
coverage must remain distinct from the immutable original admission.

## Reference-render sources

Post-mint reference records use `IStreamReferenceRenderPublication`:

- `currentReference`, `referenceRecord`, `referencePayload`,
  `referenceCount`, `referenceAt`, `requireCurrent` and `referenceLock`;
- `ReferenceRenderPublished`; and
- `ReferenceRenderLocked`.

The conservation floor uses a different, pre-sale producer at provider target
9: `IStreamProspectiveReferencePublication`. It exposes `dependencies`,
`currentSource`, `currentProspectiveReference`, `prospectiveRecord`,
`prospectivePayload`, `prospectiveCount`, `prospectiveAt` and
`requireProspectiveCollectionReference`, with
`ProspectiveReferencePublished` as its complete discovery event.

The saved floor `referenceEvidenceHash` is:

```text
keccak256(abi.encode(
  keccak256("6529STREAM_PROSPECTIVE_COLLECTION_REFERENCE_EVIDENCE_V1"),
  chainId, prospectiveHost, core, conservationFloor,
  collectionId, subject, membershipHash, receipt))
```

The provider capture preserves target 9 and its runtime hash but does not
capture these records. A post-mint reference receipt from the render-inventory
capture cannot substitute for this pre-sale evidence.

## Implementation order and source limits

The next bounded producer joins are:

1. current attribution plus sanction history, joined to the existing
   personhood fragment, to close the largest source gap in requirement 6;
2. historical media-master selection and external coverage, compared with the
   saved first-sale `mediaEvidenceHash`;
3. prospective pre-sale reference history for Full script floors; and
4. bundle archive admission and current refresh evidence where current archive
   liveness is required.

Existing captures safely supply current binding/state/generation, typed
personhood, requirement-13 tier and documentary history, current Rights, the
DIRECT floor receipts, and the complete native render-inventory producer.
They do not supply a sanction archive, master-selection history, archive
refresh proof or pre-sale reference history. Runtime pins and matching hashes
are necessary joins; they are not substitutes for those missing producer
records.

The current specialized capture reviews are pinned independently: conservation
selection `dffb8daa315114a7b26b4cff67df5747834f7ff9`, personhood
`68498f8d8fc95d9a96324426bf7c1e50976b8405`, provider configuration
`36c871f44636837bdc5504e6aaeafe54e14dcb98`, DIRECT floor
`8bb6dfe2957542f641b0d558e1cfd48e1b39ae98`, and tier/Core
`f7a05e0734b95f1e2ff1a038b73511c0d94b6f81` /
`ff372f80b830b45a6afb30583780414f3abcc4cc`. A composition preserves those
source qualifications rather than replacing them with the broader audit pin.
