# Token preservation V2 snapshots

This client targets source
`9381dd999075693a4f63092d9924856a0dd72834` and the
[shared ABI146 fixture](../test/fixtures/current-preservation-v2-abi.json).
It prepares `publishSnapshot` on the actual
`StreamPreservationPolicySnapshotPublicationV2` and
`StreamScopedPreservationPolicySnapshotPublicationV2` hosts.

The snapshot records the current admitted token preservation source state.
Its fixed family is `6529STREAM_TOKEN_PRESERVATION_FAMILY_V2`, building on the
[checkpoint and covered-output client](current-token-preservation-output-v2.md).
Collection and scoped snapshots retain distinct original publication, source
and hash definitions.

## Collection and scoped publications

| Property | COLLECTION | TOKEN, RELEASE or SEASON |
| --- | --- | --- |
| Publication | Includes `contentRootRecord`. | Uses the scoped publication without a root field. |
| Source | Includes the original current root record and its complete preservation binding. | Includes the source factory, runtime hash and dependency hash. |
| Source admission | Joins the genuine current Router root. | Joins the factory's current inventory, registered source set and current route. |
| Retained bytes | Payload plus chunk count/index getters. | Payload getter. |

Both hosts pin eleven dependencies: Core, Metadata, schemas, Store, Router,
scope membership, STATIC selection, preservation checkpoint, covered output
manifest, artifact coverage and entropy source set. Admission includes the
complete original membership, selection, content/output commitments, locked
Artist presentation and frozen coordinator policies.

VIEW has its own preservation publication model. A matching tuple or selector
does not establish admission to this token family.

## Publication authority

The actual publisher needs two independent family-writer grants on Metadata:
SNAPSHOT and IDENTITY (the `IDENTITY_DISPLAY_V1` family). Each lookup first
checks class 7 for the collection,
then class 8 globally. The receipt retains the class and grant revision for
each family. A Safe must hold the grants itself when it is the actual caller.

The candidate also needs the exact current head and revision, an unused
snapshot ID, a nonzero reason, a valid effective time and a valid manifest
URI. An existing snapshot lock prevents another publication. Reusing a
published snapshot ID rejects; publication is not an eventless retry.

## Preview, retain bytes and publish

The original `previewSnapshot` checks the candidate, publisher authority and
current sources. It returns the source hash and complete canonical bytes.
Preview permits a zero `expectedSourceHash` and does not require the canonical
chunks to have been uploaded to the Store.

Publication requires the exact nonzero expected source hash and available
Store chunks. Retain the preview's canonical bytes in the pinned Store, set
the publication's `expectedSourceHash` to the observed hash, and capture the
complete operation again before sending its ordinary zero-value CALL.

Use `previewTokenPreservationSnapshotV2` to obtain `readyPublication` and
`canonical`, then `tokenPreservationSnapshotV2Chunks` to plan the Store bytes.
`captureTokenPreservationSnapshotV2` checks the prepared publication and stored
chunks at an explicit block. Simulate with `simulateTokenPreservationSnapshotV2`
and submit `capture.prepared.call` through the intended wallet. Reconcile the
mined transaction with `reconcileTokenPreservationSnapshotV2Receipt`.

The deployment supplies the snapshot runtime pin, the complete reviewed
`linkedDependencies` roster for source admission, and a separate
`historyLinkedDependencies` roster for local history reads. Use the Safe
address as the publisher/caller when it will execute the publication.

The canonical payload clears the publication's `expectedSourceHash` to avoid
a circular commitment. It also uses the receipt before its record hash, chain
hash, manifest commitment and recorded time are populated. The final record
hash binds the original publication, actual manifest commitment and mined
timestamp; the chain hash binds the predecessor's chain and new revision.
Both V2 publication events carry schema version 2.

Receipt reconciliation checks the exact direct or Safe transaction, original
event, canonical retained bytes, mined record and lineage. Safe execution uses
ordinary CALL and the actual Safe transaction hash, with the original 1.3 or
1.4 execution-event encoding.

Reconciliation requires the captured facts to remain unchanged at the
preceding block and the exact end-block head and count. It reports
`currentEligibilityCheckedAtReceipt: false`; receipt authentication does not
establish current eligibility. A legal gas-budget change preserves history
and current commitments but requires a new publication capture.

## History and current admission

`currentSnapshot` is a head getter. Operative admission comes from
`requireCurrent`, which verifies the requested head and revision, recomputes
the source and canonical payload, and checks the retained bytes are intact.

Current admission reuses the receipt's recorded grant classes and revisions.
It does not require those grants to be active again. New publication performs
fresh grant lookups. Revocation therefore affects those two operations
differently.

Historical authentication checks the exact publication, receipt, payload and
chain commitments using the immutable host and required read helpers. It does
not establish current source admission. Scoped history compares the complete
scope coordinates: a TOKEN subject alone does not bind the collection ID.

Snapshot source and payload hashes exclude mutable gas budgets. Runtime,
membership, policy, output, root or source-factory changes still need the
original current admission checks.

## Bounds and evidence

The canonical payload is limited to 524,288 bytes and uses 8,192-byte Store
chunks. Source evidence admits at most 630 coordinator policies. The manifest
URI is limited to 2,048 UTF-8 bytes. The collection snapshot schema itself is
15,067 bytes, so definition reads must accommodate its complete original
content.

The workflow has additional client guards: transaction gas must be between
21,000 and 100,000,000; each linked-helper roster has at most 256 entries;
runtime reads are limited to 131,072 bytes; RPC bytes and aggregate receipt
log data are limited to 16 MiB, with at most 65,536 logs. The generic transport
accepts up to 2 MiB of inner calldata and an additional 16 KiB for its outer
envelope. These are client limits.

This publication client supplies typed preparation, source observations,
simulation and receipt authentication. Snapshot locks, governed gas changes,
root publication and reference publication have separate call flows. Native
contract execution, full rendered-object archival custody, the final Safe
integration matrix, gas/capacity and release acceptance remain separate
evidence.
