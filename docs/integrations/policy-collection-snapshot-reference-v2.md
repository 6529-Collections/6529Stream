# COLLECTION V2 policy snapshots and reference observations

This additive profile retains current full output for collections containing
explicit terminal entropy policies. It preserves the original V1 snapshot,
reference, finality and historical renderer identities. A terminal token retains
its full policy commitment and status; zero seed and `finalized = false` do not
become fabricated finalized entropy.

## Original authority and canonical content

`StreamPolicySnapshotPublicationV2` pins Core, Metadata, Schema, Store, Router,
Membership, STATIC selection, V2 checkpoint, V2 output manifest, artifact coverage
and the complete V2 policy source set. Its publication names the exact current
canonical Router V2 CONTENT_ROOT record. It independently rehashes that record
and its full V2 binding, including actual manifest/checkpoint/policy addresses,
runtime hashes, complete output root and five admitted document identities.

Publication needs both original Metadata SNAPSHOT and IDENTITY grants: collection
class 7 or global class 8 independently for each family. These grants do not
replace the Artist's original op17 approval consumed by the canonical Router.
The snapshot carries complete collection membership, selected output and the
ordered frozen policy rows, including the full explicit policy record.

`StreamPolicyReferencePublicationV2` consumes that current snapshot and its exact
canonical payload. It requires the original CURATOR grant, collection class 3 or
global class 8. It records BYTE_EXACT first/last observations using actual
membership ordinals, original global token IDs and Core collection serials.
Every sample joins the original coordinator, exact V2 output row and current
policy readiness. Terminal samples require the distinct admitted STATIC profile;
finalized samples keep the finalized-status branch. Full current `tokenJSON` and
`tokenHTML`, raw token data, both repeated capture digests and the original
environment/archive identities are checked. Compact historical JSON is not the
sample's full-output source.

Sampling does not establish complete render-critical archival coverage. The
complete membership/output checkpoint and separate complete inventory and bundle
are still required. VIEW, TOKEN, RELEASE and SEASON are not accepted by these
COLLECTION-only publishers.

## Bytes, lineage and locks

Both publishers derive distinct V2 record, chain, payload and profile identities.
Caller-supplied source commitments are compared with freshly derived source facts.
They retain exact compiler-canonical bytes through the original Store's ordered
8,192-byte chunks, up to 524,288 bytes. Permissionless uploads and environment
preparation grant no publication authority.

The full payload getters remain available. `snapshotChunkCount` /
`snapshotChunkAt` and `referenceChunkCount` / `referenceChunkAt` expose each exact
ordered carrier, hash and logical length. A carrier pointer represents that chunk
only. Readers must reconcile all ordered bytes against the original full-payload
commitment.

Current reads recheck live source facts and retained byte integrity. Changed full
JSON/HTML, policy evidence, canonical root, selection, authority source or archive
observations can invalidate currentness while immutable historical payloads remain
readable. Class-2 locks commit the exact head and revision; a lock does not make a
later source change current. Late publication failure rolls back accepted heads,
IDs, history and all enclosing Safe state.

## Selected-provider join

`IStreamPolicyPublicationEvidenceBindingV2.Configuration` pins the two publisher
addresses and runtime hashes in the same combined provider that owns the original
COLLECTION and separate scoped profiles. The fixed
`StreamFinalityPolicySnapshotReadsV2` and
`StreamFinalityPolicyReferenceReadsV2` independently authenticate original V2
receipts, currentness and terminal locks.

These reader/getter bindings alone do not complete finality acceptance. The
combined provider must dispatch its statement, component, canonical snapshot,
complete inventory and bundle reads as one matched V2 profile when the actual
Router's current CONTENT_ROOT has the exact V2 binding. The original V1 path
retains its original readers and identities. The additive V2 complete inventory,
bundle and selected-provider join are the next implementation boundary; no V1
receipt casting or detached supplied statement is supported.

## Evidence limits

The first selected Solidity 0.8.19 via-IR / optimizer-200 / Paris capture measures
eight new host/worker products within the original runtime and initcode limits.
Snapshot and reference hosts measure 21,541 and 21,793 runtime bytes respectively.
The 10 snapshot and 12 reference recipes type-check. Runtime results are retained
with their exact frozen capture separately; authored tests alone are not a pass.

The focused fixture uses actual Metadata, Schema, Store, Membership, token
inventory, new publishers and threshold Safe. Core, Artist, canonical Router
root, output/policy producers, renderer admission, archive and governance action
facts are explicit typed boundaries. It does not prove browser execution, an
actual selected-provider ceremony, full current-stack acceptance or transaction
capacity. Earlier V2 output tests retain their separate scope and failures.

The owned fixtures load the two publishers from Forge's exact linked production
artifacts and execute ordinary zero-value CREATE at the fixture's original nonce.
They check the predicted address, complete runtime template, every compiler
immutable range and all constructor-bound getters. Captures must retain the
source/compiler/artifact pins and allow read access to `out/`; this does not
substitute mock code for either publisher. It avoids embedding their creation
code in each test contract again.

The reference fixture uses a 1,000,000-gas read allowance because the actual
Membership contract's own 500,000-gas forwarding cap requires 607,936 parent gas.
That allowance is a fixture parameter, not a production floor or whole-operation
capacity result. The retained initial run stopped at one-chunk schema setup;
the next run recorded 12 passes and 10 failures, diagnosed as a mis-scoped
authority expectation and that nested read allowance. Corrected results must be
reported against their own frozen capture; these earlier failures remain evidence.
