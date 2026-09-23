# Scoped full-policy snapshot and root publication

The additive V2 path publishes the complete frozen entropy policies and current
outputs for one canonical TOKEN, RELEASE or SEASON scope. Its dependency order is
covered scoped-policy output, root-free snapshot, then Router root adoption.
Reference, preservation inventory and finality provider consumers follow that
root. A snapshot does not depend on the root it will later support.

## Snapshot sources

`StreamScopedPolicySnapshotPublicationV2` fixes eleven dependencies: Core,
Metadata, schema registry, Store, Router, membership, selection checkpoint,
scoped-policy content checkpoint, scoped-policy output manifest, artifact
coverage and the complete original policy source set. The checkpoint and source
set belong to one actual scope. A matching finality provider therefore selects
the V2 snapshot by scope, using the separate
`IStreamScopedPolicyContentRootEvidenceBindingV2` capability.

Every publication and current read checks the real factory, its runtime and
dependency tuple, its current inventory plan, the saved child/runtime and current
scope route. Membership, selection, completed content checkpoint, output roots
and full ordered frozen policy records must agree. The original covered output
producer re-renders the complete checkpoint. Terminal DISABLED and ASYNC
NOT_REQUIRED outcomes retain zero seed and `finalized=false`; actual finalized
outcomes retain their original status and seed.

The snapshot needs independent Metadata SNAPSHOT and IDENTITY grants. Each uses
class 7 at the collection or class 8 globally, with class 7 taking precedence.
The exact registered snapshot schema, profile and canonicalization documents
must be active. Snapshot IDs, revisions and predecessor checks are scope-bound.
The canonical payload is retained in the Store in 8192-byte chunks and is bounded
at 524288 bytes. An exact class-2 governance action locks its current head.

## Original Router authority and history

`IStreamScopedPolicyContentRootPublicationV2` adds three Router methods:

- `previewScopedPolicyContentRootPublication(publication, publisher)` returns
  the exact next CONTENT_ROOT family state for Artist approval.
- `publishScopedPolicyContentRootPublication(publication)` consumes the
  original operation-17 consent and publishes the root.
- `scopedPolicyContentRootBinding(recordHash)` returns its V2 interpretation,
  output/checkpoint/source/factory pins and document hashes.

The publication tuple remains `IStreamScopedContentRootPublication.Publication`.
The selected, runtime-pinned finality provider supplies the snapshot route and
validation budget for that exact scope. The writer cannot nominate a different
snapshot host. Source, grant, Artist binding and freeze eligibility are checked
before approval consumption; the source and next family state are checked again
before the write completes.

V1 and V2 use the same scoped head, record history and collection aggregate. A
publication after either version must name that actual predecessor. V2 stores an
append-only binding in a separate namespace. The existing scoped append,
CONTENT_ROOT family, serving-state, consent and ratification formulas remain
unchanged. V2 state and record hashes use their distinct domains and include the
complete binding. The schema-2 root event retains the historical aggregate; the
companion event retains the binding. Historical consent verification must use
that aggregate, never a later current aggregate.

The shared record getter retains both record shapes. The token-root getter
returns the V2 leaf schema only for the exact V2 profile tag. Zero selects V1;
unknown nonzero tags fail closed. All original COLLECTION and scoped V1
definitions and decoders keep their original meaning. A V2 snapshot is never
passed to a V1 decoder.

## Evidence boundary

These contracts provide snapshot publication and root adoption. They do not by
themselves preserve every rendered byte, prove reference acceptance, supply a
complete preservation inventory or complete a finality ceremony. The later
scope-specific reference, inventory, bundle, provider and discovery graph must
use the matching V2 types and historical authority proof.

Focused cases distinguish actual factory/output computation from named
Artist-presentation, archive-receipt and finality boundaries. ABI compilation is
source/type evidence. Native execution, contract size, transaction gas, combined
current-stack acceptance and release evidence remain separate requirements.

See [scoped policy output](scoped-policy-output-v2.md) and
[ADR 0041](../adr/0041-typed-finality-evidence-provider.md).
