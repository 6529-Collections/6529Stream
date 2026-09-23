# Token preservation V2 checkpoint and covered output

This client targets source
`9381dd999075693a4f63092d9924856a0dd72834` and the
[shared ABI146 fixture](../test/fixtures/current-preservation-v2-abi.json).
It supports these actual contracts:

- `StreamPreservationPolicyContentCheckpointV2` for COLLECTION.
- `StreamScopedPreservationPolicyContentCheckpointV2` for TOKEN, RELEASE or SEASON.
- `StreamPreservationPolicyOutputManifestV2` for the selected checkpoint.

These wrappers retain the original nominal V1 tuple definitions. Their V2
family, checkpoint profiles and output schema meanings are separately fixed
by the concrete deployments. Equal selectors do not establish compatibility
with a historical V1 consumer or a VIEW producer.

## Four ordinary write methods

| Target and method | Purpose |
| --- | --- |
| Checkpoint `begin(selectionId,salt)` | Capture a complete current selection and its original policy source commitments. |
| Checkpoint `append(id,payloads)` | Append one to four current preservation outputs in the selection's token order. |
| Output `beginManifest(checkpointHash,artifactHash,coverageHash,artistId)` | Admit the exact covered output archive for a completed current checkpoint. |
| Output `verifyNextOutputs(planHash,count)` | Compare one to sixteen archived rows with retained checkpoint outputs; finish with currentness checks. |

These calls are permissionless and use ordinary CALL with zero native value.
Direct and Safe caller paths retain the exact intended transaction and receipt
evidence. Governance gas changes, locks, Registry registration, Artist consent,
root adoption, snapshot/reference publication and finality are separate
operations.

## Client workflow

Start with reviewed runtime pins for the checkpoint, output host and their
complete linked helper roster. The workflow reads the hosts' immutable Core,
Router, selection, source-set, readiness, coverage and schema dependencies.
For scoped checkpoints it also checks the original source factory and route.

1. Call `captureTokenPreservationOutputV2` with the deployment, actual caller,
   operation, explicit block number and gas limit. Use the Safe address as the
   caller when a Safe will execute the transaction.
2. Call `simulateTokenPreservationOutputV2` at the intended block. It checks
   the saved source and progress again and simulates the original call.
3. Submit `capture.prepared.call` through the intended wallet. Safe execution
   must preserve that target, zero value and calldata with operation CALL.
4. Call `reconcileTokenPreservationOutputV2Receipt` with the transaction hash
   and either direct execution or Safe execution plus the expected Safe
   transaction hash. Reconciliation checks the preceding block, exact mined
   state, original events and transaction envelope.

Changed source facts or progress require a fresh capture. Receipt attribution
uses unchanged preceding-block state and exact end-of-block state; it does not
infer intermediate transaction state from an event alone.

Use `inspectTokenPreservationOutputV2History` for retained commitments and
`inspectTokenPreservationOutputV2Current` for operative admission.
`observeTokenPreservationOutputV2Refusal` distinguishes an execution revert
from an RPC failure and reports the observed local state before and after.

## Exact producer and Registry admission

The checkpoint's family is fixed to
`6529STREAM_TOKEN_PRESERVATION_FAMILY_V2`. Each row retains its actual
producer profile:

- `6529STREAM_PRESERVATION_RENDER_V1`
- `6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1`

Rows can use different admitted producers and Registry versions. The family
marker does not replace either producer profile. VIEW and unknown producer
profiles are outside this token family.

Every row joins the complete nine-word producer binding to the seven-word
admission returned by the token's selected original Registry and version.
The binding pins the producer, Core, Router, selected live renderer and
attribution companion. Admission retains the Registry/runtime, version,
registration, read-set, analysis and golden-vector hashes. A producer's own
capability claim cannot replace this governed admission.

Append reobserves the original frozen ONCHAIN selection, current policy source,
terminal or finalized entropy, retained token data, admitted producer and exact
preservation JSON/HTML. The caller supplies the animation bytes and image bytes
needed by the original predicates. Burned tokens use retained identity; this
flow does not require current ERC721 ownership.

Preservation rendering follows ADR0054: it omits only the defined sanction
lookup and derived sanction display. A client must not filter a live JSON
string or substitute an earlier rendering to produce that interpretation.

## Progress and currentness

A `begin` retry may return the existing plan without emitting another start
event. It rechecks the original complete selection and source-set commitments.
It does not rerender preservation rows already appended to that plan.

`append` revalidates the plan and rerenders every previously appended row
before adding new rows. It rechecks the complete selection after the batch.
The final append emits the content-tree root and rolling output commitment.
Checkpoint events retain schema version 1; V2 output-manifest events use
schema version 2.

Intermediate `verifyNextOutputs` calls compare retained output bytes with the
covered artifact under the original runtime pins. The final verification
additionally requires the complete checkpoint and current archive coverage.
This distinction permits bounded progress without treating a partial check
as a current completed publication.

Stored checkpoint/output records remain distinct from operative current
reads. Exact historical commitments can survive producer or source drift.
The genuine current getter rerenders the saved rows and can reject that drift.
Neither history nor a successful client-side hash calculation establishes
today's source admission.

## Canonical covered archive

The output archive has a 640-byte prefix and one 1,152-byte row per token.
Its dynamic-array offset is exactly 608 bytes. Each row retains the original
six-field token-content leaf, selection/source facts, entropy and terminal
admission, plus the complete producer binding and Registry admission.
Encodings with alternate offsets, dirty fields or trailing bytes are refused.

Coverage comes from the original `StreamFinalityArtifactCoverage`. It must
join the artifact, Artist identity and two distinct permanent archive-family
records. Chunks use 8,192-byte payloads with exact STOP-prefixed carrier code,
runtime hashes and lengths. The original schema documents must remain ACTIVE
and match their complete canonical bytes.

The covered archive limit is 524,288 bytes, which permits at most 454 complete
rows under this format. A checkpoint itself has a `uint64` token count;
the covered-archive limit does not redefine that count.

## Resource and evidence boundaries

The contract accepts at most four append payloads, each with up to 16,777,216
animation bytes and 2,048 image bytes. A maximal four-row append encodes to
67,118,052 calldata bytes. A maximum-size producer string return occupies
16,777,280 ABI bytes. The client uses bounded transport for these sizes
without changing the historical clients' smaller transport limits.

Full checkpoint collection in the workflow has an explicit client allocation
ceiling of 16,384 rows. This is an operational client limit, not a protocol
token-count limit. Larger checkpoints require a separate bounded read strategy.
Metadata token data has its own original limit of 16,384 bytes.

The workflow also applies client transport guards: gas limits and observed
configured gas values must be between 21,000 and 100,000,000; the supplied
linked helper roster has at most 256 entries; runtime reads have a 131,072-byte
ceiling; receipts have at most 65,536 logs and 16 MiB of aggregate log data.
These guards do not redefine the contracts' admissible values.

The original read/render preflight requires strictly more than
`cap + cap / 63 + 100000` gas before each dependency call. This is a necessary
forwarding check, not a gas estimate for the complete operation. The client
must simulate the actual original call with the intended caller and budget.
Mocked responses do not execute the original JSON/image predicates or prove
native gas capacity.

Typed encoding, direct/Safe receipt checks and source-bound client regressions
do not establish native execution, full rendered-object archival custody,
rollback, release readiness or deployment acceptance. Those remain separate
integration evidence.
