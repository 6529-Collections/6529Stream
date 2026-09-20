# Scoped full-policy output evidence

`StreamScopedPolicyContentCheckpointV2` and
`StreamScopedPolicyOutputManifestV2` produce current STATIC output evidence for
canonical TOKEN, RELEASE and SEASON scopes. They use the actual
[scoped full-policy source factory](scoped-policy-source-factory-v2.md).
They do not publish an authoritative content root or finalize artwork.

## Scope and dependency identity

The checkpoint accepts only TOKEN `(collectionId, tokenId, 0)` and RELEASE or
SEASON `(collectionId, 0, membershipId)`. The collection and applicable token or
membership ID must be nonzero. RELEASE and SEASON remain different scopes even
when their numeric IDs match. COLLECTION and VIEW are refused. VIEW requires its
own adopted source and renderer profile.

Deploy the existing `StreamStaticSelectionCheckpoint` against the real Core,
Router and authoritative membership. Complete the Coordinator Inventory and
prepare a source set through `StreamFinalityScopedEntropyPolicySourceFactoryV2`.
Deploy `StreamTerminalEntropyReadiness` against that set, Core and Router. The
new output checkpoint uses those selection, source-set and readiness addresses.

Construction pins the source factory's runtime, distinct scoped capability and
`6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2` profile. It validates and
commits the exact 352-byte `StreamFinalityCoordinatorPolicyReadsV2.Dependencies`
tuple, including the same Core, generic Metadata and membership as selection.
Each current checkpoint read checks the unchanged tuple and factory runtime,
current inventory plan, factory-owned source-set address and runtime, the set's
own factory/plan identity, and the complete current scoped route. Selected
Metadata, original coordinator policy completeness and membership must remain
valid. Historical source facts alone cannot satisfy current admission.

## Current rendered output

Call `begin(selectionId, salt)`, then `append` with at most four exact ordered
payloads per call. The selection and policy set must agree on the complete scope,
membership hash and token count. The checkpoint reads every original
`coordinatorAtMint`, full frozen policy and actual current STATIC source.

Terminal DISABLED and ASYNC NOT_REQUIRED rows retain their true status, zero
seed and `finalized=false`. They require the separately admitted terminal
renderer profile through `StreamTerminalEntropyReadiness`. Randomized finalized
rows require actual native status 5, mode ASYNC_REQUIRED and the original seed.
Pending rows are refused; a frozen policy alone is insufficient.

The complete current Router JSON, HTML, inline image and token data determine
the original six-field content leaves. A separate ordered output chain also
commits full policy/readiness and source facts. Every current read re-renders
all completed rows. Changed source, lifecycle or displayed content invalidates
current admission while preserving historical checkpoint and output reads.

The distinct profile is
`keccak256("6529STREAM_SCOPED_POLICY_CURRENT_FULL_CONTENT_V2")`. Its new companion
interface exposes `scopedPolicyProfile`, `sourceFactory` and
`factoryDependenciesHash`; it does not advertise the original COLLECTION
checkpoint capability. Original products, domains and stored evidence are
unchanged.

## Preserved output manifest

The manifest companion accepts only the new checkpoint profile and capability.
Register the exact interpretation documents from `StreamScopedPolicyOutputSchemasV2`:

- Schema: `STREAM_SCOPED_POLICY_OUTPUT_MANIFEST_V2`.
- Canonicalization: `STREAM_ABI_SCOPED_POLICY_OUTPUT_MANIFEST_V2`.
- Content-leaf interpretation: `STREAM_SCOPED_POLICY_TOKEN_CONTENT_LEAF_V2`.

The manifest contains the complete scope, checkpoint state, actual source set,
full policy/inventory commitments and all ordered output rows. Its canonical
header is 576 bytes; each output row is 640 bytes. The verifier checks every word
against the checkpoint, exact array count and length, registered document bytes,
preserved SSTORE2 chunks and current two-family archive coverage. No substituted
offset, trailing bytes or COLLECTION/V1 schema is accepted. TOKEN evidence has
exactly one row. Completion and current reads revalidate the original checkpoint
and archive coverage; historical manifest records remain readable after drift.

The companion separately advertises `IStreamScopedPolicyOutputManifestV2` and
returns the new profile from both `outputProfile` and `scopedOutputProfile`.
Output hashes do not preserve complete rendered bytes by themselves; those
bytes still need their corresponding archival artifacts.

## Remaining finality assembly

This batch supplies output evidence only. Scoped full-policy snapshot and
reference publications, Router content-root admission, render-critical inventory,
bundle coverage, provider/profile discovery and the actual Artist/governance
ceremony remain separate work. Existing scoped V1 bindings cannot be repointed to
these V2 records. The publication order must remain acyclic: old scoped snapshots
precede their root, whereas COLLECTION V2 snapshots include a previously admitted
root. Complete TOKEN/RELEASE/SEASON finality acceptance requires a deliberate
joined profile with all of those real dependencies.

Source construction and ABI checks do not establish native execution, deployment
fit, gas capacity or readiness for deployment. The integrator owns combined
runtime and release validation.
