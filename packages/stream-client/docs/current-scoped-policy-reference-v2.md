# Scoped full-policy reference publication

This additive client profile targets ABI129 source
`896899f7ca4130f86e066587f780a3b1f755a25d`, tree
`743efae1136e5742cb57c9e477080bd1c6aca5aa`. It follows the original
[scoped root and Artist consent](current-scoped-policy-root-v2.md) flow for
TOKEN, RELEASE and SEASON. It prepares the original reference environment and
file inventories, then publishes the original scoped V2 reference observation.
Render-critical inventory, complete bundle coverage and finality remain
separate ceremonies.

## Original calls

| Method | Purpose |
| --- | --- |
| `prepareFileInventory(rows, relative)` | Retain a complete original file inventory |
| `prepareFileInventoryPart(rows, relative)` | Retain one original inventory part |
| `prepareFileInventoryFromParts(rows, relative)` | Assemble the exact complete inventory from prepared parts |
| `prepareEnvironment(environment)` | Retain the complete original native environment |
| `previewReference(publication, recorder)` | Read the exact source hash and canonical publication bytes |
| `publishReference(publication)` | Publish the original scoped reference observation |

The five writes are zero-value CALLs. Preparation is permissionless. Publication
requires the original Metadata CURATOR grant: enabled collection class 3 with
nonzero revision first, then global class 8. The actual Safe address needs that
grant when a Safe is the caller. Observation does not create Artist authority.
Original reference locks and gas-parameter governance have separate authority.

## Seven original dependencies

The actual reference host retains seven ordered targets and runtime hashes:
Core, Metadata, Schema Registry, Store, Router, scoped Snapshot and External
Artifact Coverage. Its read, source, snapshot and archive gas budgets retain
their separate purposes. Use reviewed deployment and linked-library evidence
for these pins; matching caller-supplied hashes does not prove provenance.

External ZIP/PNG coverage is a different contract from the Finality Artifact
Coverage used for the earlier full output manifest. Neither coverage surface
substitutes for the other. The old reference environment and inventory pure
codecs preserve their interpretation, but their older workflow deployment shape
does not describe this seven-dependency host.

Publication requires the exact current scoped V2 snapshot and common Router
root. Their complete source, receipt, full recorded scope and 23-field root
binding must agree. The source reads the snapshot publication's actual output
manifest record key; an output content hash cannot replace that record key.
TOKEN's subject formula omits collection ID, so full scope equality remains
mandatory.

The three scoped reference documents and original environment, PNG, ZIP and
format-catalog definitions must have their exact active RAW_BYTES meanings.
The scoped schema alone is 26018 bytes. Preserve its exact bytes, including
the original file's newline convention.

## Prepare exact inventory and environment bytes

File rows retain their supplied order. Paths must be unique and strictly
ascending by UTF-8 bytes; the client must not silently sort them. Every row has
a nonzero SHA-256 digest and uint64 byte size, including valid zero-byte files.
Relative paths follow the original ASCII grammar and 1024-byte bound. Platform
prerequisite paths follow their separate 2048-byte bound.

An inventory part contains 1 through 64 rows. Assembly uses consecutive
64-row partitions and the original boundary-order checks. Complete monolithic
or assembled inventories can be empty. The environment requires both package
and platform inventories to be nonempty.

The original environment uses `operatingSystem="Windows"`,
`architecture="AMD64"`, `colorSpace="srgb"`, software rasterization,
device pixel ratio 1 and a viewport between 1 and 4096 in each dimension.
Engine and toolchain executables must be exact positive-size members of the
package inventory. Names, versions, paths, hashes, prerequisites, licenses and
capture profile remain part of the complete environment commitment.

Inventory and environment bytes follow their original JSON serialization
recipes. The surrounding reference publication is Solidity ABI. Reformatting
either representation changes its commitment. Retained bytes must fit the
original 524288-byte limit.

Prepare the exact 8192-byte Store chunks before requesting retention. The
original preparation functions read the fixed Store; they do not upload missing
chunks. Reusing a prepared identity verifies its retained bytes and is
eventless. Fresh monolithic inventory preparation is also eventless. Fresh
parts, assembly and environment preparation emit their respective original
events. A missing creation event alone cannot identify failure or a retry.

## Reference samples

The observation captures authoritative first and last membership ordinals:
one capture when the scope has one token, otherwise exactly two in order.
Core supplies the original collection serial and coordinator at mint. Burned
endpoints remain supported by the original lifecycle rules. The source checks
the retained registered STATIC renderer and its current output.

The samples bind exact full Router JSON, HTML and token-data bytes. Original
bounds are 65536 bytes for JSON, 1 through 40960 for HTML and 16384 for token
data. Capture timestamps must be positive and no later than execution.

The repeated PNG capture SHA-256 values must be equal and nonzero, and match
the genuine PNG archive coverage. The HTML source SHA-256 has a different
purpose and must not be substituted for an image hash. Every capture uses the
same environment manifest commitment.

Terminal DISABLED and ASYNC NOT_REQUIRED retain zero seed and
`finalized=false`, with their original terminal STATIC admission. Randomized
samples require actual finalized status 5 and the original seed; that seed can
itself be zero. INSTANT is not an additional terminal branch.

Repeated first/last samples do not prove all-token rendering conformance or
complete artifact availability. This client consumes supplied observations
and coverage; it does not execute a native renderer or independently capture
the images.

## Publication bytes and lineage

A new publication requires a unique nonzero reference ID, nonzero reason hash,
positive effective time no later than execution, exact head and revision, and
an unlocked scope. Its manifest URI follows the original safe UTF-8 rules
within 2048 bytes; an empty URI is valid in this reference profile.

The source commitment includes the seven dependency pins and complete source
facts. Canonical payload encoding clears
`publication.observation.expectedSourcesHash` and receipt observation fields
`recordHash`, `recordChainHash`, `payloadHash`, `payloadBytes` and `recordedAt`.
The receipt's actual `sourcesHash` remains populated. The record hash instead
binds the submitted publication and completed payload/timestamp fields while
clearing only receipt record and chain hashes.

Both the canonical payload and `abi.encode(submittedScopedPublication)` must
fit 524288 bytes and already have their exact Store chunks. One retained byte
stream does not cover the other. Publication rechecks the grant and lineage
after retention. It consumes the reference ID and advances the head; it has no
idempotent publication retry.

## Fresh coverage, currentness and history

Fresh publication authenticates the supplied original ZIP/PNG coverage through
the original `requireCoverage` path, including its recorded fixity facts.
Current revalidation preserves the immutable coverage in the source commitment
and checks `currentReceiptPair` for the same two original receipt hashes.
Later passing fixities can preserve existing reference currentness without
rewriting its source hash. They can also make stale coverage unsuitable for a
new publication. A newer coverage head is not a replacement for the original
receipt pair.

Historical publication, payload and source records remain readable independently
of today's snapshot or root head. An unknown historical record refuses; an
empty current getter returns its original zero receipt. The stricter current
inspection workflow requires a published reference and refuses an empty head.
Historical hash authentication and current producer admission remain separate.
Current reference admission does not establish finality.

## Client entrypoints

Import these functions from `@6529/stream-client`:

| Function | Result |
| --- | --- |
| `prepareScopedPolicyReferenceV2Call` | Exact unsigned preparation or publication CALL, with `factsVerified=false` |
| `prepareScopedPolicyReferenceV2Read` | Exact original getter or preview CALL |
| `previewScopedPolicyReferenceV2` | Pinned original preview, source facts and canonical bytes; Store availability remains unchecked |
| `captureScopedPolicyReferenceV2` | Reviewed call, dependency observations, prerequisites and required Store carriers |
| `simulateScopedPolicyReferenceV2` | Reconstructed inner CALL simulation, with `persisted=false` |
| `inspectScopedPolicyReferenceV2History` | Authenticated immutable publication, receipt, payload and source; `currentnessChecked=false` |
| `inspectScopedPolicyReferenceV2Current` | Original current admission plus authenticated history; `currentnessChecked=true` |
| `reconcileScopedPolicyReferenceV2Receipt` | Exact transaction, event and preceding/end-block observations |
| `observeScopedPolicyReferenceV2Refusal` | Classified execution revert or RPC failure, with `rollbackProven=false` |

The workflow deployment supplies `chainId`, Core, Metadata and reference host
code pins, plus separate `linkedDependencies.preparation`, `.source` and
`.history` arrays. Obtain complete linked-runtime lists from reviewed deployment
evidence. The host supplies its actual seven dependency bindings. Preparation
checks the fixed Store and applicable local prerequisites; it does not require
a complete publication graph. Immutable history needs the pinned reference host,
its history libraries and the original Core/Metadata addresses, without requiring
every upstream product to be live today.

For an already prepared environment, use an explicit recorder and concrete block
number. `draft` is a complete original publication with
`observation.expectedSourcesHash` set to zero:

```ts
import {
  previewScopedPolicyReferenceV2,
  scopedPolicyReferenceV2Chunks,
  encodeScopedPolicyReferenceV2Publication,
  captureScopedPolicyReferenceV2,
  simulateScopedPolicyReferenceV2,
} from "@6529/stream-client";

const preview = await previewScopedPolicyReferenceV2(
  provider, reviewedDeployment, caller, draft, { blockTag: reviewedBlock },
);
const publication = {
  ...draft,
  observation: { ...draft.observation, expectedSourcesHash: preview.sourceHash },
};
const requiredChunks = {
  payload: scopedPolicyReferenceV2Chunks(preview.canonical),
  publication: scopedPolicyReferenceV2Chunks(
    encodeScopedPolicyReferenceV2Publication(publication),
  ),
};
```

Each chunk includes its exact bytes, content hash, STOP-prefixed runtime and
runtime hash. Arrange and verify their Store upload separately. Once those
carriers exist, capture at a concrete block and simulate the reviewed call:

```ts
const captured = await captureScopedPolicyReferenceV2(
  provider, reviewedDeployment, caller,
  { kind: "publishReference", publication },
  { blockTag: blockWithUploadedChunks },
);
const simulation = await simulateScopedPolicyReferenceV2(provider, captured, {
  blockTag: blockWithUploadedChunks,
  gasLimit: reviewedGasLimit,
});
```

Capture repeats source and original preview checks. A changed source commitment
requires a new preview and review. Simulation repeats the original capture and
checks the selected execution block; it neither submits a transaction nor
executes an outer Safe envelope. Prepared identities and saved captures are
reconstructed before reuse, and pinned block hashes are checked again.

## Receipts, refusal and finite bounds

Receipt reconciliation takes `{execution: "direct"}` or
`{execution: "safe", expectedSafeTxHash}`. The actual Safe must be the captured
caller. The Safe envelope must carry the exact zero-value inner CALL and a
matching success event after the protocol event, when that event is required.
The workflow verifies transaction/receipt/log identities and order, canonical
calldata/events, mined timestamps, retained bytes and history lineage.
The mined receipt block must be strictly later than the captured block.

Attribution uses the block immediately before execution and the end of the
receipt block. Later same-block head progress can require separate review.
Receipt reconciliation returns `finalityEstablished=false`. Refusal observation
distinguishes `execution-reverted` from `rpc-failed`; unchanged reads around an
RPC call do not prove mined rollback.

Client allocation limits include 2097152 bytes per RPC result or inner calldata,
131072 runtime bytes, 256 pins per linked-dependency list and 8192 array rows
in structural codecs. Workflow gas inputs are positive and at most 100000000;
that bound is not a transaction-capacity claim. Candidate admission limits the
history count to 65536. Receipts allow 4096 logs, four topics per log, 65536 data
bytes per log and 1048576 aggregate log-data bytes. Outer calldata allows
2097152 plus 16384 bytes for the Safe envelope. Original profile limits still apply;
a larger client transport limit does not expand them.

## Evidence boundary

The fixture retains complete ordinary compiler ABIs, unchanged raw nominal
library witnesses, imported source closure and exact interpretation documents
from the same frozen commit. Internal library functions are not wallet
endpoints.

Client and mocked RPC/Safe checks establish their stated consistency boundaries.
Actual native rendering, actual Safe execution, rollback, gas/capacity,
deployment and finality need their own evidence. The integrator's newer
preservation architecture remains separate from this original profile.
