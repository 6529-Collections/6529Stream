# Scoped full-policy checkpoint, output and snapshot publication

This additive client profile targets ABI129 source
`896899f7ca4130f86e066587f780a3b1f755a25d`, tree
`743efae1136e5742cb57c9e477080bd1c6aca5aa`. It continues the
[genuine scoped publication graph](current-scoped-policy-graph-v2.md) for TOKEN,
RELEASE and SEASON. The sequence is current rendered content, covered output,
then a root-free snapshot. Original Artist operation-17 root adoption and
downstream preservation/finality ceremonies follow separately.

## Original calls and authority

| Host | Call | Authority and effect |
| --- | --- | --- |
| Scoped content checkpoint | `begin(selectionId, salt)` | Permissionless; starts or returns the exact checkpoint for a completed genuine selection |
| Scoped content checkpoint | `append(id, payloads)` | Permissionless; appends one through four exact ordered payloads |
| Scoped output manifest | `beginManifest(checkpointHash, artifactHash, coverageHash, artistId)` | Permissionless; joins a complete checkpoint to actual covered output bytes |
| Scoped output manifest | `verifyNextOutputs(planHash, count)` | Permissionless; verifies one through sixteen remaining output rows |
| Scoped snapshot | `previewSnapshot(publication, publisher)` | Read only; checks the candidate, both writer grants and actual source before assembling bytes |
| Scoped snapshot | `publishSnapshot(publication)` | Both original SNAPSHOT and IDENTITY family grants; publishes the exact next snapshot |

Every write is a zero-value CALL. When a Safe executes it, the Safe is the
actual caller and must hold any required grants. The five write methods above
do not grant Artist consent, lock a snapshot or finalize artwork. The original
`lockSnapshot` and gas-parameter changes require their genuine governance
context and are outside these direct/Safe publication calls.

## Required preparation

Use the complete genuine seven-child publication graph and its reviewed
deployment/runtime/link pins. This client derives child hosts from that graph.
The underlying child contracts have their own admission rules; this profile
requires a complete current graph before every write.

The original STATIC Selection must already be complete for the exact scope.
Membership, original coordinators, frozen full policies and current source-set
identity must agree. A frozen policy does not make pending output renderable.
Complete the applicable renderer readiness before starting a content checkpoint.

The output archive must already exist as a genuine artifact with its exact
preserved chunks and current coverage from two distinct archive families.
`beginManifest` consumes that evidence. It does not upload or archive the output
bytes. The snapshot likewise needs a locked original ArtistPresentation and the
exact active snapshot schema, profile and canonicalization documents.

Runtime hashes must come from reviewed deployment and link evidence. A match to
a supplied hash establishes consistency with the pin, not its provenance or
completeness.

## Current content and ordered output

A checkpoint payload includes its actual token ID, animation bytes and image
bytes. Rows follow the completed original selection order. Capture reads the
actual Router JSON, HTML and token data, then binds their hashes and the supplied
image bytes. Simulation of the original `append` performs the exact JSON/data
pattern and inline-image admission checks. Capture alone does not establish
those checks; generic JSON normalization cannot substitute for the exact bytes.

Terminal DISABLED and ASYNC NOT_REQUIRED rows retain status 1 or 2, zero seed and
`finalized=false`. Their original terminal renderer admission is required.
Randomized rows use actual finalized status 5 and the original seed. Pending
rows cannot be relabeled as terminal or finalized.

The original six-field content leaf tree preserves order. An odd last node is
promoted unchanged; leaves and pairs are not sorted or duplicated. A separate
rolling output commitment includes each complete policy/readiness output row.
Current checkpoint reads rerender all retained rows, so cost grows with the
completed prefix and changed rendering can invalidate current eligibility.

The output manifest is exact Solidity ABI bytes: a 576-byte header including
the array count, followed by 640 bytes per ordered row. The array offset is 544.
Alternate offsets, extra rows and trailing bytes are refused. The original
64-by-8192-byte storage bound permits at most 818 rows for this layout. TOKEN
has exactly one row. These commitments do not themselves preserve the complete
rendered JSON, HTML, image or token-data artifacts.

The original nonfinal `verifyNextOutputs` checks pinned dependencies and exact
retained output bytes; its final batch additionally checks current documents,
the complete checkpoint and archive coverage. This client deliberately requires
current graph and source eligibility before every batch. A retained intermediate
batch that the original contract could admit after source drift is outside this
client profile.

## Snapshot grants, lineage and bytes

SNAPSHOT and IDENTITY are independent Metadata family grants. Each resolves an
enabled collection class-7 grant with nonzero revision first, then an enabled
global class-8 grant. A grant for one family cannot substitute for the other.
The receipt retains both actual authorization classes and grant revisions.

The publication binds the complete scope, a unique snapshot ID, actual current
head, expected revision, covered output record and coordinator inventory plan.
TOKEN's subject formula omits the collection ID; therefore full recorded scope
equality remains mandatory. RELEASE and SEASON remain distinct even when their
membership IDs match.

Preview may start with `expectedSourceHash=0`. The actual write requires the
nonzero hash of the complete current source. The snapshot source includes
membership, locked ArtistPresentation, selection, content, covered output,
genuine factory identity and the complete ordered policy evidence. It contains
no root whose admission depends on this same snapshot.

Canonical payload encoding sets `publication.expectedSourceHash` to zero and
clears receipt `recordHash`, `chainHash`, `manifestHash`, `manifestBytes` and
`recordedAt`. It retains the actual source hash and all other receipt facts.
The record hash instead uses the actual publication and mined recording time;
the chain extends the actual predecessor receipt. A simulated return value or
timestamp cannot stand in for the mined record.

Publish the exact canonical bytes to the original Store beforehand, in contiguous
8192-byte chunks with the final residual length. Snapshot publication retains
those existing bytes. It creates no chunk-upload receipt. The complete payload
is bounded at 524288 bytes; the original source reader bounds complete policy
evidence at 630 rows before allocation. The client's operational bounds may be
smaller because it also uses the graph workflow's finite source limits.

Snapshot publication is not idempotent. A consumed snapshot ID or changed
head/revision refuses replay. Checkpoint and output starts can return an existing
identity without a creation event while still checking their current prerequisites.
Completed append/verification operations retain their original remaining-count
rules; no invented completion or retry event is added.

## Client entry points and bounds

`ScopedPolicyPublicationV2Deployment` contains the reviewed `graph` deployment
and `linkedDependencies` runtime pins. Capture derives the checkpoint, output
and snapshot addresses from the complete current graph. The pure
`prepareScopedPolicyPublicationV2Call` encoder accepts those coordinates
explicitly; encoding alone does not check live eligibility.

```ts
import type { Provider } from "ethers";
import {
  captureScopedPolicyPublicationV2,
  simulateScopedPolicyPublicationV2,
  type Address,
  type ScopedPolicyGraphV2Scope,
  type ScopedPolicyPublicationV2Deployment,
  type ScopedPolicyPublicationV2Request
} from "@6529/stream-client";

async function prepare(
  reader: Provider,
  deployment: ScopedPolicyPublicationV2Deployment,
  scope: ScopedPolicyGraphV2Scope,
  caller: Address,
  request: ScopedPolicyPublicationV2Request,
  blockTag: number,
  gasLimit: bigint
) {
  const capture = await captureScopedPolicyPublicationV2(
    reader, deployment, scope, caller, request, { blockTag }
  );
  const simulation = await simulateScopedPolicyPublicationV2(
    reader, capture, { blockTag, gasLimit }
  );
  return { capture, simulation, call: capture.prepared.call };
}
```

Request kinds are `begin`, `append`, `beginManifest`, `verifyNextOutputs` and
`publishSnapshot`, with the original arguments shown above. Recapture after
each mined stage. Simulation authenticates the capture and rechecks current
facts at the requested concrete block; its result has `persisted: false`.
For a Safe operation, use the Safe address as `caller` before capture, then
compose the returned unsigned CALL with `createSafeCallPlan`.

`previewScopedPolicyPublicationV2Snapshot(reader, deployment, publication,
publisher, { blockTag })` returns the original `canonical` bytes, actual
`sourceHash` and `readyPublication` containing that hash. It returns
`storeAvailabilityChecked: false`: arrange publication of the exact chunks to
the original Store before capturing `publishSnapshot`. Write capture checks
each existing chunk's length and exact STOP-prefixed runtime.

| Client limit | Bound |
| --- | --- |
| Workflow tokens and inherited graph policy rows | 256 each |
| Pure output archive rows / full policy rows | 818 / 630 |
| Canonical manifest or snapshot payload | 524288 bytes |
| Original animation / image / token-data payload | 16777216 / 2048 / 16384 bytes |
| Pure encoded CALL | 67125248 bytes |
| Workflow RPC result, rendered JSON/HTML or inner calldata | 2097152 bytes each |
| Receipt outer calldata, including Safe envelope | 2113536 bytes |
| Pinned runtime / linked dependency entries | 131072 bytes / 256 |
| Receipt logs / topics per log | 4096 / 4 |
| Log data per log / aggregate log data | 65536 / 1048576 bytes |
| Explicit simulation gas allowance | Positive, at most 100000000 |

These finite operational bounds can refuse inputs supported by the underlying
contracts. They do not establish gas affordability or normative capacity.

## Receipts and history

Receipt evidence must join the actual caller, target, zero value, calldata,
transaction and block to the original event sequence and recorded state. Safe
evidence additionally needs the independently obtained Safe transaction hash
and successful inner CALL. A successful outer transaction alone is insufficient.

`reconcileScopedPolicyPublicationV2Receipt(reader, capture, transactionHash,
options)` accepts `{ execution: "direct" }` or
`{ execution: "safe", expectedSafeTxHash }`. The receipt block must follow the
capture block. Reconciliation reconstructs the reviewed prestate at the
preceding block, checks the exact original event sequence, and joins it to
end-of-block progress. It refuses concurrent graph, source or progress changes
that prevent attribution. An eventless start retry still needs the matching
successful transaction and retained state. The Safe path supports direct
`execTransaction` with operation CALL and both supported execution-event
layouts; module and MultiSend envelopes need separate support.

Historical checkpoint, manifest and snapshot records remain distinct from
current validation. Retained records can remain readable after source, schema,
grant or rendering changes. Their stored hashes and lineage must still match;
historical evidence cannot be described as current publication eligibility.

`inspectScopedPolicyPublicationV2History` accepts the separate history
deployment with chain, Core, Metadata, three host runtime pins and linked
dependencies. Its request selects `checkpoint`, `manifestPlan`,
`manifestRecord` or `snapshotRecord`. It verifies retained commitments without
requiring current graph/source admission and returns `currentnessChecked: false`.
`inspectScopedPolicyPublicationV2Current` takes the full graph deployment and
scope, then selects `checkpoint`, `manifest` or `snapshot` for current producer
admission. It returns `currentnessChecked: true`. Both keep
`finalityEstablished: false`.

`observeScopedPolicyPublicationV2Refusal` distinguishes an execution revert from
an RPC failure and compares retained getters. Its `rollbackProven: false`
qualification remains even when those observations are unchanged.

## Evidence boundary

The fixture preserves complete ordinary compiler ABIs, separate unchanged nominal
library ABIs, their source import closure and original interpretation documents.
The raw snapshot-source library tuple is a type witness; its public library
methods are not wallet endpoints. Every one of the 3262 input literals matches
its frozen Git blob without source line-ending normalization.

Source/ABI checks and mocked RPC/Safe-envelope tests qualify client behavior.
Native execution, actual Safe behavior, complete rollback, deployed size and
gas, joined Artist root/preservation ceremonies and finality/release acceptance
require their own evidence. The integrator's sanction/render-finality review is
separate from these bounded publication calls.
