# Collection view declarations

`StreamCollectionViews` is the current companion for retained alternative
collection presentations. It implements the six fields of CMC “Multiple
Canonical Views”: `viewId`, `schemaId`, `uri`, `contentHash`, `mimeType`, and
`defaultForView`. A collection can enumerate its declared view IDs and read the
selected revision, original author, full history, and all document bytes.

This is an explicit declaration product. It does not install a renderer, change
`StreamCore.tokenURI()`, select the marketplace view, confer rights, or create
Artist consent. `defaultForView` is the publisher's original Boolean declaration
for that named view; it cannot change the default view of another system. The
future renderer consumer must independently enforce the actual Artist content
veto, locks, current attribution, and finality before adopting render-affecting
inputs. An admin's `ARCHIVE` or `PRINT` declaration is not evidence of permission
to exhibit or print a work.

## Deployment, discovery, and authority

Deploy with the actual Core, MetadataV1, and its original Executor. The constructor
pins Metadata's Core/schema/store/Executor relationships and runtime code hashes.
It requires the existing `METADATA_DEPENDENCY_READ_GAS` configuration on this new
host. Those bounds are host-owned Governed Gas Parameters; the original delayed
raise machinery applies. No gas-conformance result is inferred from type checking.

Register the new module through the current ModuleRegistry as
`keccak256("COLLECTION_VIEWS")`, with its advertised interface ID, exact runtime,
version, and module/deployment manifest commitments. The system manifest identifies
this companion address and the source relationships. Core has no COLLECTION_VIEWS
pointer type; the host does not pretend otherwise. Each mutation authenticates
Core's current MODULE_REGISTRY and that registry's original eligibility reads
for both this companion and its Metadata source, plus the exact current
COLLECTION_METADATA pointer. Metadata replacement or view
host retirement stops new writes. Historical records remain readable directly.
Registering multiple eligible hosts does not elect a global latest host: clients
must pin the explicit host from their selected system manifest.

Writers come from the original selected Metadata host's
`6529STREAM_RECORD_FAMILY_IDENTITY_DISPLAY_V1` grants. Only numeric class 7
(metadata admin) and class 8 (global admin) are accepted. Existing collection
scope and global scope zero retain their meanings. The original Metadata
`familyWriterTransition` / `setFamilyWriter` and exact delayed class-1 Executor
context govern those grants. This companion has no duplicate admin or grant
ledger. A receipt retains the actual class, selected grant scope, and revision;
revocation never rewrites the old receipt. Rights, curator, institution, Artist,
owner, and unrelated collection grants do not authorize these writes.

## Two separate byte commitments

Register the exact `viewSchema()` definition under
`STREAM_COLLECTION_VIEW_MANIFEST_ABI_V1`, as a SCHEMA using the original active
RAW_BYTES canonicalizer. The source definition is in
[the schema file](../../schemas/metadata/STREAM_COLLECTION_VIEW_MANIFEST_ABI_V1.json).
The host checks its full registered content hash, kind, canonicalization and
active status. The view document's own `manifest.schemaId` must identify another
actual active schema (it is not substituted for the carrier schema).

The canonical state carrier is exactly:

```solidity
abi.encode(collectionId, uint64(revision), previousRecordHash, manifest)
```

The generic record retains the original fourteen-word collection-record domain,
`DISPLAY_VIEW_MANIFEST` type, canonical VIEW subject, RAW_BYTES hash reference,
and complete original `CollectionRecordRecorded` event. `effectiveAt` is zero;
actual publication time is the separate receipt's `recordedAt`. The per-collection
record chain uses the original `6529STREAM_RECORD_CHAIN_V1` recipe. Revision and
previous record are inside the carrier, so even A → B → A in one block has three
distinct historical records. The companion's full typed event also carries the
manifest and original grant receipt.

`manifest.contentHash` separately commits `keccak256` over the referenced view
document. The host retains those exact bytes too, rather than trusting an external
URI. Documents can be up to 65,536 bytes, split into eight original 8,192-byte
SSTORE2 chunks. `viewChunkCount` and `viewChunk` recover their exact logical order;
`viewPayload` assembles and verifies the entire hash. Its returned pointer is the
first physical chunk, not a claimed monolithic 65,536-byte blob. Physical pointer
inventory deduplicates identical chunks within each payload family; logical
repetitions and all manifest carriers remain recoverable from state.

`schemaId` records the publisher's selected interpretation. Onchain admission
checks bytes and registered identity, not arbitrary JSON-schema validity, MIME
truth, browser behavior, or external availability. Consumers validate that meaning
offchain against the exact recorded definitions. The URI is a bounded HTTPS,
IPFS, or Arweave locator, or empty for a document retrieved entirely from this
host. MIME is a bounded `type/subtype` token without parameters. All IDs are
explicit; the host does not infer that a named view has any special privileges.

## Publication and reads

Use `setCollectionViewManifestWithPayload` for an atomic upload and publication.
Pass the exact `selectedViewRecord` hash as `expectedPrevious`; zero creates a
new view. A stale edit reverts. The original three-argument
`setCollectionViewManifest` is also available for an exact document already in
the original chunk store (up to its 8,192-byte single-chunk limit). Uploading bytes
alone never creates a selected view, authority, or accepted pointer row. Larger
initial documents use the payload-carrying setter. There is no URI-only path.

Both setters reject identical selected manifests. At most 128 distinct view IDs
are admitted per collection in this bounded host. Every successful revision is
preserved; selecting new bytes never deletes prior state. `lockCollectionView`
permanently seals a selected view and requires the original class-8 global-admin
grant; a class-7 metadata writer alone cannot freeze it. Core collection freeze also blocks new
canonical declarations. Neither rule blocks historical reads or mutates any
owner/independent/preservation record lane. All attempted partial publications
and SSTORE2 writes roll back atomically on failure.

Use `collectionViewManifest` for the historical host's selected declaration,
`viewRecord` for its complete record and receipt, `manifestPayload` for the
canonical carrier, and paged/full document reads for its referenced bytes.
These reads do not silently resolve another host or promote an old declaration
to the current renderer state. Unknown records and out-of-range indexes reject;
an undeclared selected view returns an empty manifest.

## Validation boundary

Nine focused recipes in `StreamCollectionViews.t.sol` cover the independent
original record/hash/event preimages, full-size paged retention, grant scope and
revocation, schema retirement, metadata/registry changes, exact revision history,
locks, permissionless uploads, and an actual Safe 1.4.1 failed transaction followed
by the identical successful retry. The late failure occurs at the manifest blob
write after referenced bytes were written; the original store and host state must
both roll back. The test uses actual MetadataV1, SchemaRegistry, SSTORE2 store and
Safe, with explicit typed Core, Executor, Artist-constructor and module-registry
boundaries. It does not claim the entire deployed current graph was executed.

The 92-source ABI/type check is clean; all nine cases are authored. Native tests,
selected bytecode size, full current Core/Executor deployment/admission, and the
aggregate metadata function-count/audit-scope gate remain pending. No historical
release evidence or mandatory selectable STATIC renderer completion is implied.
