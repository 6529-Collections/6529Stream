# Metric supplement publication and recovery

The metric supplement adds retained source, runtime and replay evidence to one
original PERCEPTUAL reference. Its original V1 publication, seven-field Metric,
context and report identities remain unchanged. BYTE_EXACT and CURATED records
keep their original identities.

Use the [metric codec](current-reference-metric.md) to validate supplied bytes
and the workflow module to prepare unsigned calls, inspect stored facts and
simulate publication. The client accepts caller-supplied artifacts; it does not
download archives or execute a declared interpreter, launcher or diagnostic.

## Roles and identities

| Item | Meaning |
| --- | --- |
| Original reference record hash | Permanent reference to which the supplement is attached. |
| Payload hash | Keccak of the complete canonical supplement ABI bytes. |
| Runtime hash | Original runtime-domain hash of the complete declared metric runtime. |
| Replay hash | Original replay-domain hash of the retained replay tuple. |
| Supplement hash | Receipt-domain hash binding chain, producer, Core, Metadata, original reference, payload, authority and recording time. |
| Chunk uploader | Any account; uploading bytes grants no publication authority. |
| Supplement recorder | Current collection CURATOR writer, class 3, or global class 8 writer. |

The actual collection class-3 grant takes precedence when both grants exist.
The receipt records the selected class and grant revision. Ownership of the
producer or a chunk pointer does not substitute for that grant.

## 1. Preserve the original evidence

Supply the exact original reference/context IDs, environment identities and
complete package member list, capture-major image hashes and dimensions, metric
implementation/parameter hashes, threshold, evaluation time and report hash.
Keep these originals with the full supplement and archived runtime evidence.

The four source files retain their raw bytes. The index is compact ordered JSON
with lowercase raw-file SHA256 digests and no trailing newline. The runtime must
retain every original `metric/` member in byte order, the fixed entrypoint and
launch invocation, and exact source/index/parameter members. The replay uses
the original source-derived input JSON and a canonical transcript ABI envelope.

Local validation authenticates these relationships against the supplied
originals. The publication inspection also binds them to the producer's stored
original reference, context and mode evidence. Neither step executes the metric
or establishes that a publisher's diagnostic account is truthful.

## 2. Prepare the complete upload plan

`prepareReferenceMetricSupplementPlan` snapshots all input bytes and coordinates.
It returns the complete canonical artifact, ordered chunk calls and one final
`publishMetricSupplement` call. All calls carry zero native value.

The complete payload is at most 524,288 bytes. Retention always divides it into
8,192-byte segments with one final remainder. Keep every segment in its original
position, including repeated identical segments. An uploaded content hash may
be reused; a different segmentation cannot satisfy the final Store reads.

Each Store `publishChunk` call is permissionless and independently executable.
Simulation returns the expected chunk hash and pointer. Publishing already
stored bytes can return the existing pointer without another `ChunkPublished`
event. Retain the content identity rather than requiring a new event on reuse.

## 3. Mine and verify the chunks

Submit each required upload, then run `inspectReferenceMetricChunkAvailability`
at a concrete block. It checks Store rows and each pointer's exact STOP-prefixed
code bytes, length and content hash. An upload plan or a successful simulation
does not establish that the chunks have been mined.

The client never turns a staged upload into authority to publish the reference.
The uploader and final writer may be different accounts.

## 4. Inspect and simulate final publication

`inspectReferenceMetricSupplementPublication` checks the network, producer
dependencies, original record/current head, context, PERCEPTUAL mode, unlocked
state, actual writer grant and complete chunk availability at a concrete block.
`simulateReferenceMetricSupplementPublication` calls the exact final publication
from its prepared writer. It checks the returned receipt-derived supplement hash.

The original reference must still be current and unlocked. A missing chunk,
changed source, invalid authority or prior supplement can make the final call
revert. A prior upload remains usable after a reverted publication. Reinspect
the relevant state before retrying the same reviewed call.

Recording time is part of the supplement identity. A hash predicted by
simulation belongs to that simulated block; the mined receipt must be checked
using its actual block timestamp.

## 5. Validate the receipt and read back

`inspectReferenceMetricPublicationReceipt` accepts
`{ transactionHash, execution: "direct" | "safe" }`. Direct mode checks the
writer's exact call to the producer. Safe mode checks a single canonical
`execTransaction` envelope targeting the writer Safe, with an operation-0 call
to the producer and the exact publication bytes. The outer relayer differs from
the Safe recorder. Both modes require zero value and bind the schema-1 event to
the recording block and timestamp. They reconstruct the supplement hash from
the complete canonical payload, runtime/replay hashes, original reference,
recorder and event-attributed grant. Safe mode supports this single-call path;
review the Safe's own execution evidence separately.

The client bounds the complete Safe envelope to 589,824 bytes before decoding.
This is a local parser limit, not a Safe protocol limit.

Use `inspectHistoricalReferenceMetricSupplement` to verify retained bytes and
receipt identity. This makes no claim that the original reference or its sources
remain current. `inspectCurrentReferenceMetricSupplement` additionally checks
the current original reference and the producer's `requireMetricSupplement`
result. Historical integrity and present eligibility are different questions.

The supplement is attached once to the original reference. It does not change
that reference's V1 ID, rewrite its original report or automatically lock the
reference. Later PERCEPTUAL lock/finality consumers include the exact supplement
identity in their own commitments.

## Safe CALL planning

Build an ordered `createSafeCallPlan` using the caller's compiled Store ABI for
uploads and publication ABI for the final call. Every step uses `operation: 0`
and value zero. Assign upload steps to the selected uploader Safe and the final
step to the actual writer Safe. Verify each step's required caller.

These are separate calls. Simulating a later step does not execute earlier
uploads. Mine uploads, read back their chunks, then simulate the final writer
call. Review the Safe's own execution result and validate the protocol receipt
after mining. The [Safe guide](safe-call-plans.md) explains this boundary.

The [metric example](../examples/current-reference-metric.mjs) accepts explicit
deployment coordinates, artifacts and compiled ABIs. `prepareMetricSafeExample`
returns separate uploader/writer plans plus their ordered review calls. The
inspection and readback functions take an explicit provider and block; importing
the example performs no RPC, download, execution, signing or submission.

## Acceptance boundary

The compiled fixture pins integration source `7d5ba35c` containing the frozen
metric implementation `7ca6a2df`. Its retained 219,264-byte replay fixture has a
synthetic original image/context boundary. Source, encoding and synthetic RPC
tests do not establish joined publisher runtime, transaction gas, actual Safe
execution, full finality, deployment or release acceptance.

Reads use explicit block numbers. Follow the workflow return values' evidence
limits and apply a reorg policy before relying on a transaction result. Current
source checks can change after an inspection or simulation.
