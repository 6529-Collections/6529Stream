# Historical ABI129 scoped-policy finality

This client implements the original scoped-policy finality profile captured at
`896899f7ca4130f86e066587f780a3b1f755a25d` by ABI129. Its source, complete compiler
ABIs, interpretation documents and imported source closure are retained in the
[fixture](../test/fixtures/current-scoped-policy-finality-v2-abi.json).
The public module names retain the package's `current-` naming convention; this
guide's explicit historical source boundary controls their meaning.

The supported scope is TOKEN, RELEASE or SEASON with the original STATIC ONCHAIN
publication graph and source-locked Artist profile. The newer current-authority,
preservation and combined VIEW profiles require their own frozen interfaces and
clients. Equal selectors or same-shaped tuples do not establish compatibility.

## Four outer calls

| Stage | Actual target and method | Meaning |
| --- | --- | --- |
| Stage manifest | Registry `stageFinalityManifest(bytes)` | Store exact bytes by content hash. This is permissionless and grants no finality authority. |
| Publish payload | Executor `publishGovernanceCallData(bytes[])` | Retain the singleton target calldata in the original Executor's publication store. |
| Schedule | Executor `scheduleGovernanceBatch(...)` | Commit the reviewed singleton class-2 action, exact transition and execution window. |
| Execute | Executor `executeGovernanceBatch(...)` | Execute the previously scheduled action and its exact archived Registry finalization call. |

Every prepared outer call uses ordinary CALL with zero native value. The inner
target is the actual Registry's `finalizeArtworkScopeWithArchive`. Its calldata
is part of the Executor batch commitment. Sending that target call directly
from a wallet or Safe fails the Registry's Executor-only admission.

Provider and Discovery have no post-constructor mutators. The Registry's four
local schedule/veto/cancel/expiry methods and its old lifecycle getter are
retired. Legacy FinalityPreview methods are also retired. They do not provide a
second execution clock or an alternate preparation path.

## Original graph and source selection

Start with the [publication graph](current-scoped-policy-graph-v2.md),
[checkpoint and snapshot publication](current-scoped-policy-publication-v2.md),
[Router root](current-scoped-policy-root-v2.md),
[reference publication](current-scoped-policy-reference-v2.md), and
[inventory and archive evidence](current-scoped-policy-inventory-archive-v2.md).
Complete the original required locks, source evidence and sanction/archive work
before preparing terminal finalization. Client capture observes these facts; it
does not create missing evidence or grant authority.

An existing seven-child graph alone does not select this provider profile. The
actual Router head must retain the original V2 binding, which must identify that
genuine graph's output, checkpoint, entropy source set, source factory,
dependency hash and snapshot profile. The closed client rejects a missing head,
legacy fallback, partial binding, unknown profile or substituted producer.

The underlying historical provider retains three catalogue entries: native
COLLECTION, original scoped V1 and policy COLLECTION V2. Scoped policy V2 is
resolved through `finalitySourcesForScope`; it is not catalogue entry 3. The
provider's full 22-target configurations, six-word factory binding and source
configuration commitment remain distinct from Discovery's configuration.

Validate actual deployment code and reviewed links, reciprocal Core/Metadata/
Artist/Registry bindings, the selected Registry pointer, provider and discovery
identities, and the complete current graph. Caller-supplied runtime hashes are
pins to check, not independent proof of deployment provenance.

Discovery supplies nine independent component families and a tenth Artist
sanction family for this profile. Preserve the exact original family order and
all seven expectation fields: family, component, interface, runtime hash,
module version, manifest hash and data hash. Reading one indexed component is
partial evidence. Complete list/hash and genuine Registry admission checks
remain necessary.

The provider's prepared combined getters require the actual Registry caller
and runtime. The workflow uses the Registry's genuine
`finalityExecutionContextWithArchive` to obtain target-side admission. Nominal
library selectors are retained as compiler evidence, not exposed as alternate
RPC endpoints. Some of those libraries depend on `address(this)` or
`msg.sender`, so standalone calls would change their meaning.

## Canonical manifest and sanction

The independent manifest is the exact original Solidity ABI envelope:

```text
abi.encode(schemaId, canonicalizationId, chainId, Core, Metadata, Registry, Statement)
```

Its complete byte length is at most 8192. The Statement contains the full scope,
historical Core facts hash, content root and leaf count, root schema, snapshot
and reference manifests, all ten scope inputs, nine independent component
expectations and three policy bytes fixed to 1. TOKEN retains both collection
and token identities and has one leaf. RELEASE and SEASON have a nonzero scope
ID and positive leaf count. COLLECTION and VIEW are outside this profile.

The ten scope inputs retain this order:

1. Router root record
2. Snapshot record
3. Reference-render record
4. Intent record
5. Explicit intent-waiver record
6. Interview evidence
7. Rights statement record
8. Work description record
9. Render-critical inventory evidence
10. Bundle archive coverage

Exactly one intent or intent-waiver reference is present. Other required
evidence cannot be replaced by zero values. The manifest excludes its own
content hash, finality record, final sanction record and signature; this keeps
preparation acyclic.

Fresh admission requires identical complete manifest bytes in both the original
Schema Store and Registry staging, plus the two exact registered manifest
definition documents under their original ACTIVE, RAW_BYTES, single-chunk
profile. Registry staging by itself accepts a broader 1–32768-byte range and
does not prove any of those semantic checks. A repeat stage with identical
retained bytes is an authenticated eventless retry.

The manifest URI is committed as `keccak256(bytes(uri))`; use its exact original
bytes. A URI convention cannot substitute for the content hash, schema,
canonicalization or stored payload.

The workflow consumes an existing actual Artist sanction and archival proof.
It does not sign or create an Artist sanction. The selected proof retains
`sanctionRecordHash`, `artifactHash` and `completionHash`, with the original
sanction/ceremony/signature bytes, schema interpretation and qualifying archive
evidence. Current archive health is checked separately from the immutable
original proof. Healthy fixity refresh cannot replace the original receipt or
family identities.

The full component list adds exactly one actual Artist sanction to the nine
independent manifest rows. This source-bound Artist profile requires archive
evidence; the unarchived Registry finalizer is not an alternate completion path.

## Canonical Executor authority and time

The original Executor owns the action lifecycle. Scheduling requires its owner
or an admitted proposer. The recorded proposer must still hold
`ROLE_COLLECTION_FINALITY_ADMIN` when the Registry executes, with the actual
RoleRegistry's nonzero mutation hash and revision. The transaction submitter,
Safe owner or Executor address does not replace that proposer role. Execution
submission itself is permissionless within the admitted action's window.

The workflow requires a bound original Executor for payload publication and an
ordinary sealed Executor for scheduling and execution. Genesis and pre-seal
governance flows are outside this client profile.

Class 2 retains a minimum 72-hour delay, minimum seven-day open window and
maximum 365-day lifetime. Original execution endpoints are inclusive. The
catalog, guardian commitment, target-scope membership, runtime/profile and
action-state checks remain mandatory; a locally valid timestamp pair is only
one input to admission.

The original catalog has no public entry getter. Capture checks its observed
state and bindings; exact entry admission remains part of the actual original
schedule/execute simulation. Capture alone does not claim to reconstruct every
catalog policy decision.

The singleton governance call commits the actual Registry, zero value,
finalizer selector, calldata hash and the target's scope/old/new hashes. The
Executor derives separate aggregate transition hashes and its action ID from
the complete call list, nonce, window, reason and manifest commitment.

During nested execution, Registry validates the actual Executor's nonzero
class-2 `currentAction()` against the target's per-call hashes. Aggregate batch
hashes are not interchangeable with those target hashes. Archived finalization
uses the original archived-new-state domain, which additionally commits the
selected sanction archive evidence. The permanent finality record preimage
remains separate from that execution transition.

## Workflows and receipts

The pure module prepares immutable typed values and unsigned calls. Its hashes
and plans are derived from supplied facts and do not claim those facts were
observed on-chain. Workflow capture checks the selected facts at a concrete
block; simulation repeats the relevant checks and simulates the actual outer
Registry or Executor call. Neither operation broadcasts a transaction.

Import these entrypoints from `@6529/stream-client`:

| Entrypoint | Purpose |
| --- | --- |
| `scopedPolicyFinalityV2ManifestBytes` | Encode the canonical manifest from supplied coordinates and Statement. |
| `prepareScopedPolicyFinalityV2Finalization` | Join manifest, ten components and archive proof into the inner Registry call and its execution commitments. |
| `scopedPolicyFinalityV2GovernanceBatch` | Bind that call to the original Executor nonce and class-2 window. |
| `prepareScopedPolicyFinalityV2Call` | Select one of the four outer wallet calls. |
| `prepareScopedPolicyFinalityV2Read` | Prepare a supported typed read and identify Registry-only provider reads. |
| `inspectScopedPolicyFinalityV2Route` | Observe the complete selected source and original Registry admission context. |
| `captureScopedPolicyFinalityV2` / `simulateScopedPolicyFinalityV2` | Capture a stage at a concrete block, then recheck and simulate its actual call. |
| `reconcileScopedPolicyFinalityV2Receipt` | Authenticate a subsequent direct or Safe receipt and retained result. |
| `observeScopedPolicyFinalityV2Refusal` | Record an actual execution refusal and selected unchanged state. |
| `inspectScopedPolicyFinalityV2History` / `inspectScopedPolicyFinalityV2Current` | Read immutable evidence or run a separate current diagnostic. |

Pure coordinates contain `chainId`, `core`, `metadata`, `registry`, `executor`,
`artist` and `artifactCoverage`. Workflow deployment input supplies runtime pins
for those contracts and `roles`, the reviewed graph Provider/Discovery deployment
under `source`, and `linkedDependencies`. A code pin is `{address, codeHash}`.
History needs only the coordinates and original Registry pin. Current diagnostics
also need the reviewed links used by the Registry's original verifier.

After both manifest stores and the Executor payload publication are ready,
prepare a scheduling capture from reviewed evidence and the observed nonce:

```ts
import {
  prepareScopedPolicyFinalityV2Finalization,
  scopedPolicyFinalityV2GovernanceBatch,
  prepareScopedPolicyFinalityV2Call,
  captureScopedPolicyFinalityV2,
  simulateScopedPolicyFinalityV2,
} from "@6529/stream-client";

const plan = prepareScopedPolicyFinalityV2Finalization(coordinates, {
  manifestBytes, manifestURI, components, proof,
});
const batch = scopedPolicyFinalityV2GovernanceBatch(plan, observedNonce, {
  notBefore, expiresAfter, reasonHash, reasonURI, manifestHash,
});
const prepared = prepareScopedPolicyFinalityV2Call(coordinates, caller, {
  kind: "scheduleGovernanceBatch", batch,
});
const options = { blockTag: reviewedBlock, gasLimit: reviewedGasLimit };
const capture = await captureScopedPolicyFinalityV2(
  provider, reviewedDeployment, prepared, options,
);
const simulation = await simulateScopedPolicyFinalityV2(provider, capture, options);
```

Retain the exact batch after scheduling. Prepare its `executeGovernanceBatch`
stage at an admitted execution block with a fresh capture; changing the nonce,
window, reason or inner calldata creates a different action. Manifest staging
uses `{kind: "stageFinalityManifest", manifestBytes}`. Payload publication uses
`{kind: "publishGovernanceCallData", batch}` and grants no execution authority.

Use the actual Safe as caller when preparing a Safe transaction. Reconciliation
checks the exact direct transaction or supported Safe CALL envelope and an
independently supplied expected Safe transaction hash. It authenticates copied
transaction/log data, original event ordering and relevant state before and at
the end of the mined block. Runtime and reviewed link pins are checked at the
receipt block as well as capture. Conflicting same-block changes require
separate review.

The receipt block must be strictly later than the capture block. Reconciliation
requires the captured facts to match the block immediately before the receipt,
then checks the retained result at the end of the receipt block.

Successful archived finalization emits the Registry's scope-finalized,
manifest-pointer, terminal-freeze, execution-witness and sanction-archive-witness
events in that order. Executor completion/policy events follow the target;
outer Safe success follows the inner execution. Original class-2 membership
pruning may occur before the target events. Finalization does not publish a
Schema Store chunk.

Refusal observation retains the original execution error and distinguishes it
from a transport/RPC failure. Equality of selected states around a failed
simulation does not prove an actual mined transaction's complete rollback.

## Immutable history and current checks

History authenticates the original Registry's stored record, complete component
array, canonical manifest bytes, execution witness and archive witness.
The local record getter does not contain `coreFactsHash`, but the retained
canonical Statement does. Join that historical value and its nine independent
rows to the ten stored components to recompute the original permanent record
without consulting today's Core state.

Historical interpretation uses the known original manifest profile and exact
stored bytes. It does not reauthorize through today's Provider, Discovery,
Artist, roles, schema status or archive health. Current route/coverage checks
are separate. A current diagnostic mismatch can describe later drift while the
historical receipt and stored record retain their original meaning.

## Client allocation limits

The canonical manifest limit is 8192 bytes, and the inner Registry call limit
is 32768 bytes. The closed plan contains nine independent component families
plus one Artist family. Structural component hashing accepts at most 32 rows;
generic tuple codecs cap dynamic arrays at 4096 rows and encoded values, byte
strings and UTF-8 text at 262144 bytes. Outer calldata uses that same 262144-byte
client bound. Original fixed arrays retain their exact lengths.

Typed component ranges accept at most 32 rows; current workflow diagnostics
require a positive range limit. Original provider catalogue indexes are 0–2.
Guardian reconstruction accepts at most 16 holders per role. Membership reads
also enforce the original Executor's reported cap within a 256-row client ceiling.

The shared transport caps an RPC result or aggregate receipt log data at
16777216 bytes, runtime code at 131072 bytes, each linked dependency list at 256
pins, and a receipt at 65536 logs with at most four topics each. Transaction
data has a 2097152-byte transport limit plus 16384 bytes for a Safe envelope;
the narrower finality call limits still apply. Workflow gas inputs range from
21000 through 100000000. These client bounds do not prove transaction capacity
or gas acceptance.

This batch provides source-qualified client and mocked-RPC evidence. Actual
native and Safe execution, nested gas/capacity, rollback, deployment provenance,
comprehensive integration and release acceptance require their own evidence.
