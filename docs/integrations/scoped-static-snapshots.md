# Scoped STATIC source snapshots

`StreamScopedSnapshotPublication` publishes an immutable, versioned source
snapshot for a TOKEN, RELEASE or SEASON. It gives those scopes their own
subject, revision chain, complete source binding and class-2 snapshot lock.
The original COLLECTION snapshot producer, domains and encoded bytes are
unchanged.

This is an additive source-publication component of the all-scopes finality
work. It does not publish an Artist-authorized CONTENT_ROOT, preserve complete
rendered output bytes, decide a reference acceptance mode, or complete a
finality ceremony. Those consumers must explicitly join this new profile.
VIEW requires a separate profile binding the actual selected view payload,
Artist adoption and renderer authority; this producer rejects VIEW.

## Sources and admission

The constructor records eleven address/runtime pairs in this exact order:
Core, selected Metadata, SchemaRegistry, Store, selected Router, authoritative
ScopeMembership, StaticSelectionCheckpoint, StaticContentCheckpoint,
StaticOutputManifest, ArtifactCoverage and FinalityCoordinatorInventory.
Every admission and currentness read rechecks the fixed runtimes, reciprocal
bindings and current Metadata/Router selections.

The complete scope comes from `requireScopeMembership`. The manifest producer
must return its current, covered output-row manifest for the Router's original
locked Artist presentation. That producer re-renders the complete checkpoint
and checks current archive coverage. The snapshot then matches its retained
content and selection plans by their full ABI hashes, scope, membership,
counts, completion and roots. It also reads every original coordinator from
the authenticated complete inventory and requires every policy to be frozen.
A caller's token list, claimed completeness flag or current coordinator pointer
cannot replace these sources.

Output-row archive coverage authenticates the recorded output hashes; it does
not establish retention of every complete output component. Likewise, the
snapshot writer's grant does not confer Artist publication authority.

Publication requires both original Metadata family grants: SNAPSHOT and
IDENTITY_DISPLAY. Each grant is either collection class 7 or global class 8,
with the actual class and grant revision retained independently in the receipt.
The publisher cannot choose either authority class. Currentness retains these
historical admission facts without promoting them into a fresh writer grant.

## Write and read sequence

1. Complete the actual scope membership, STATIC selection/content checkpoint,
   covered output manifest and original-coordinator inventory.
2. Register the exact `STREAM_SCOPED_STATIC_SNAPSHOT_ABI_V1` and
   `STREAM_SCOPED_STATIC_SNAPSHOT_PROFILE_V1` documents, and the original
   `STREAM_SOLIDITY_ABI_V1` canonicalization document. The producer verifies
   their active status, kind, full bytes, hash and length.
3. Call `previewSnapshot(publication, actualPublisher)`. Retain its canonical
   bytes and set the returned `expectedSourceHash` in the publication.
4. Preupload those exact bytes in ordered Store segments of at most 8,192
   bytes. This permissionless retention grants no publication authority.
5. Call `publishSnapshot` from the admitted writer or its threshold Safe.
   Missing bytes or any changed source reverts before history/head advancement.
6. Use `requireCurrent(scope, recordHash, revision)` for an operative source
   check. `snapshotRecord`, `snapshotPayload` and the scope history remain
   historical reads after source changes.

`snapshotId` is unique within the exact scope. The expected head and revision
must match the current scope lane. A lock is an exact current class-2 Executor
action over the scope, head and revision; it cannot lock a stale snapshot.
The immutable lock stops later publications in that lane. It does not freeze
the external dependencies: a later source change still makes `requireCurrent`
fail while all original records and bytes remain readable.

## Encodings and budgets

The standalone schema contains the complete nested ABI, including explicit
scope enum values. The payload domain is
`6529STREAM_SCOPED_SNAPSHOT_PAYLOAD_V1`; source, record, chain and lock domains
are distinct. All bind the deployment chain and actual publisher host. The
payload carries the original full Publication, normalized receipt fields and
full source facts. Only `expectedSourceHash` is normalized to zero in the
payload; its actual source hash is already present in the receipt/source. The
record commitment also retains the actual publication input.

READ, SOURCE and INVENTORY gas parameters use the existing governed parameter
host and terminal full-budget read admission. No budget is silently clamped.
The canonical payload is explicitly bounded at 524,288 bytes; all bytes must
be present before the writer call. Supported onchain scope size still depends
on the measured complete revalidation cost. A small typed test is not evidence
that arbitrary large scopes fit the transaction gas envelope.

## Validation boundary

The focused fixture uses actual Metadata, SchemaRegistry, Store, token
inventory, authoritative scope membership, original-coordinator inventory,
this producer and the official threshold Safe. Core/Artist/Executor and the
render/output/archive/entropy-policy reads are explicitly named typed test
boundaries. It covers TOKEN/RELEASE/SEASON, exact bytes and revisions, separate
family grants, original entropy policy, changed source/invalid token lifecycle, scope rejection,
missing-byte Safe rollback with identical retry, and exact lock commitments.
ABI/type checking and authored tests do not by themselves establish an actual
current-stack render/archive/finality integration. That joined capture and
consumer wiring remain separate acceptance work.
