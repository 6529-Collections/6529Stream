# Token preservation V2 reference publication

This client targets source
`9381dd999075693a4f63092d9924856a0dd72834` and the
[shared ABI146 fixture](../test/fixtures/current-preservation-v2-abi.json).
It prepares the five operational writes on the actual
`StreamPreservationPolicyReferencePublicationV2` and
`StreamScopedPreservationPolicyReferencePublicationV2` hosts.

The reference records a prepared rendering environment, bounded first/last
captures, and their archive coverage against a current
[token preservation V2 snapshot](current-token-preservation-snapshot-v2.md).
Each capture authenticates the saved producer binding and its complete
Registry admission. The supported original and current-Artist producer
profiles retain their own identity inside the fixed token preservation family.

## Calls and authority

| Write | Purpose |
| --- | --- |
| `prepareFileInventory` | Retain a complete ordered file inventory. |
| `prepareFileInventoryPart` | Retain one inventory part. |
| `prepareFileInventoryFromParts` | Assemble a complete inventory from its prepared parts. |
| `prepareEnvironment` | Retain the exact native environment description. |
| `publishReference` | Publish the observation and advance the reference history. |

All five writes use zero-value CALL. Preparation is permissionless. Publication
requires the actual recorder's Metadata CURATOR grant: enabled collection
class 3 with nonzero revision first, then global class 8. A Safe must hold the
grant itself when it executes the call. Publication rechecks that grant and
the candidate after retaining both byte streams.

The candidate needs a unique nonzero reference ID, nonzero reason, positive
effective time no later than execution, exact head and revision, and an
unlocked scope. Its manifest URI can be empty and is limited to 2,048 UTF-8
bytes. Publication consumes the ID and has no idempotent retry.

## Current snapshot, root and producer evidence

The reference host pins seven ordered dependencies: Core, Metadata, schemas,
Store, Router, snapshot and external artifact coverage. The snapshot supplies
its eleven original dependency bindings. The first five bindings must agree
between the two hosts. Read, source, snapshot and archive gas budgets have
separate roles; mutable gas budgets are excluded from the source commitment.

| Scope | Root evidence |
| --- | --- |
| COLLECTION | The current root named by the snapshot, its original record and complete preservation binding. |
| TOKEN, RELEASE or SEASON | The current scoped root adopted after the root-free snapshot, including the complete snapshot, factory, output and producer-profile binding. |

Source admission calls the genuine current snapshot boundary and authenticates
its original publication, receipt and canonical source. The scoped root joins
the snapshot's actual output-manifest record key. A payload hash cannot replace
that key. Full scope coordinates remain necessary even when two TOKEN scopes
would share a subject hash.

There is one capture for a one-token scope, otherwise exactly two captures at
the first and last membership ordinals. Each sample joins the exact STATIC
selection, checkpoint output, entropy readiness, producer binding and all
seven Registry admission words. The Registry must still admit that producer
and profile. Retained burned-token identity remains part of the original
lifecycle checks.

Samples bind exact producer JSON, HTML and token-data bytes. JSON is limited
to 65,536 bytes, HTML to 1 through 40,960 bytes, and token data to 16,384 bytes.
Capture times must be positive and no later than execution. Repeated PNG
capture SHA-256 digests must be equal and nonzero and match the supplied PNG
coverage. The source HTML SHA-256 is a separate commitment. Every capture
uses the same environment manifest.

Terminal DISABLED and ASYNC NOT_REQUIRED samples retain zero seed and
`finalized=false` with their original terminal admission. Randomized samples
need finalized status 5; a finalized seed can itself be zero. First/last
observations do not establish all-token rendering conformance.

## Prepare the environment and Store bytes

File inventory paths retain their supplied order and must be unique and
strictly ascending by UTF-8 bytes. Rows carry a nonzero SHA-256 digest and a
uint64 byte size; a zero-byte file is valid. Parts contain 1 through 64 rows.
Assembly follows the original consecutive partitions and boundary checks.
Complete inventories may be empty, but the environment requires nonempty
package and platform inventories.

The original native environment uses Windows, AMD64, sRGB, software
rasterization and device pixel ratio 1. Viewport dimensions are each 1 through
4,096. Engine and toolchain executables must be exact positive-size members
of the package inventory. Paths, versions, prerequisites, licenses and capture
profile remain part of the complete environment commitment.

Inventory and environment bytes use their original JSON recipes. Publication
uses Solidity ABI encoding. Reformatting either changes its commitment.
Each retained byte stream is limited to 524,288 bytes and uses 8,192-byte Store
chunks. Upload those chunks before requesting retention; preparation reads
the fixed Store and does not upload missing bytes.

Prepared identity reuse checks the retained bytes and is eventless. A fresh
monolithic inventory preparation is also eventless. Fresh parts, assembled
inventories and environments emit their respective original events. Receipt
interpretation therefore needs the captured prior state as well as logs.

An environment cache is optional for publication. The original reader uses
an intact cached environment when present; otherwise it reconstructs the
environment from the two exact prepared file inventories. A cache hit does
not require rereading those inventory entries.

## Preview and publish

The original preview checks the candidate, recorder and current sources,
including the cached or reconstructed environment. It returns the exact
source hash and canonical payload without requiring that payload's Store chunks. Preview
allows a zero expected source hash. Publication requires its exact nonzero
value and available chunks for two distinct streams:

1. The preview's canonical payload.
2. `abi.encode` of the submitted publication, with its actual expected source hash.

The canonical payload clears `observation.expectedSourcesHash` and the
receipt's record hash, chain hash, payload hash, payload size and recorded
time. It retains the actual source hash. The final record binds the submitted
publication, completed receipt fields and mined timestamp; the chain binds
the predecessor. Both V2 publication events use schema version 2.

The three exact reference definitions and the original environment, PNG, ZIP
and format-catalog definitions must be active RAW_BYTES declarations. The
collection reference schema is 29,589 bytes and the scoped schema is 28,358
bytes. Their complete original bytes matter.

## Fresh coverage, currentness and history

Preview and publication use the original fresh `requireCoverage` path for
the supplied ZIP/PNG coverage. Current revalidation preserves that immutable
coverage and checks `currentReceiptPair` for the same original receipt hashes.
Later passing fixities can preserve currentness without rewriting the source
commitment. A newer coverage head cannot substitute for the original pair.

Both fresh and current paths still require the actual current snapshot, root
and producer admission. Current reference admission reuses the recorded
CURATOR grant; a new publication checks fresh authority.

Historical authentication checks the retained publication, payload, source,
record and chain commitments independently of today's upstream admission.
The head getter, historical authentication and operative `requireCurrent`
have separate meanings. A matching historical hash does not establish
currentness or finality.

## Client entrypoints

The workflow deployment supplies `chainId`, `scopeKind`, Core, Metadata and
reference-host code pins, plus separate `linkedDependencies.preparation`,
`.source` and `.history` rosters. Source admission includes the complete
snapshot graph and its reviewed linked libraries. Obtain those rosters from
reviewed deployment evidence.

Use `captureTokenPreservationReferenceV2` for any of the five writes and
`simulateTokenPreservationReferenceV2` with an explicit block and gas limit.
Capture returns the unsigned call at `capture.prepared.call`. Simulation
returns `persisted: false`.

For publication, preview a complete draft at a concrete block, set its exact
source hash, and plan both Store streams:

```ts
const preview = await previewTokenPreservationReferenceV2(
  provider, deployment, caller, draft, { blockTag },
);
const publication = {
  ...draft,
  observation: { ...draft.observation, expectedSourcesHash: preview.sourceHash },
};
const payloadChunks = tokenPreservationReferenceV2Chunks(preview.canonical);
const publicationChunks = tokenPreservationReferenceV2Chunks(
  encodeTokenPreservationReferenceV2Publication(publication),
);
```

After those chunks exist in the fixed Store, capture
`{ kind: "publishReference", publication }` at a concrete block, simulate,
and submit the prepared call through the intended wallet. Use the Safe
address as `caller` when it will execute the call.

`inspectTokenPreservationReferenceV2History` takes the smaller history
deployment: Core and Metadata addresses, the reference code pin, chain and
scope kind, and a single history-linked pin list. It authenticates immutable
history without today's full source graph. The full-deployment
`inspectTokenPreservationReferenceV2Current` calls original current admission
and refuses an empty head.

`reconcileTokenPreservationReferenceV2Receipt` checks exact direct or Safe
execution, captured preceding-block facts, original events, retained bytes
and end-block state. Receipts must follow the captured block. Safe options
require the independently verified Safe transaction hash and ordinary CALL.
The result does not establish finality. `observeTokenPreservationReferenceV2Refusal`
distinguishes an execution revert from an RPC failure; unchanged observations
do not prove a mined rollback.

## Client resource guards

Additional client limits include 2 MiB of inner calldata, another 16 KiB for
the outer envelope, 16 MiB per RPC result and aggregate receipt log data,
65,536 logs, four topics per log, 131,072 runtime bytes and 256 pins per linked
roster. Structural array codecs allow at most 8,192 rows. Workflow gas inputs must
be positive and at most 100,000,000; full-source dependency gas budgets also
use that client ceiling. These limits do not establish transaction capacity
or expand the original protocol bounds.

## Evidence boundary

The client prepares calls and verifies observations supplied through RPC.
Native rendering, independent image capture, actual Safe execution,
gas/capacity, complete archival custody and release acceptance require their
own evidence. Reference locks, governed gas changes, root publication and
finality have separate authority and call flows.
