# Complete metric evidence for PERCEPTUAL finality

The additive `IStreamReferenceMetricSupplement` interface binds complete metric
source bytes, a declared archived runtime and a retained restored-replay result
to one original `StreamReferenceModePublication` record. The original seven-field
Metric, report domain, V1 publication bytes and receipt identity do not change.
BYTE_EXACT and CURATED finality identities are unchanged.

Full PERCEPTUAL finality now requires this supplement. A historical V1 reference
can still be read and its original source proof checked, but its implementation
hash and report alone cannot satisfy the finality reader, the reference lock or
the complete mode inventory.

## Exact closed profile

Register the exact new documents
`schemas/records/STREAM_REFERENCE_METRIC_SUPPLEMENT_ABI_V1.json` and
`schemas/records/STREAM_REFERENCE_METRIC_SUPPLEMENT_PROFILE_V1.json`. Generate or
check their Solidity constants with
`python -m tools.preservation.reference_metric_profile --check`. These documents
do not replace any registered V1 mode document.

The implementation index is the sorted compact JSON mapping the original four
paths to lowercase raw-file SHA256 digests, without `0x` or a trailing newline.
Both its bytes and each full source file are retained. The index Keccak must
equal the original Metric implementation hash. Exact parameter bytes must match
the original parameter hash. No newline normalization is applied to source files.

The runtime declares the same original environment object and manifest. It must
contain exactly every original environment member beneath `metric/`, in its
original sorted order. Source, index and parameter member sizes and SHA256
digests are checked individually. The fixed entrypoint, interpreter, launcher,
source root and `-I -S -B metric/launch.py` invocation cannot be substituted.
The large runtime ZIP remains an original externally archived object; it is not
copied into EVM bytecode by this interface.

Replay inputs are reconstructed from the original context, environment hash,
threshold, evaluation time and capture-major image SHA256/dimensions. The replay
must bind those exact inputs, runtime and original report, report exit code zero,
and retain its original diagnostic bytes in the canonical
`6529STREAM_METRIC_TRANSCRIPT_V1` ABI envelope. All copied envelope fields must
match the replay receipt. A raw JSON transcript from the earlier tooling format
is rejected by this versioned profile.

The EVM authenticates the publisher's recorded execution claim and its byte
bindings. It does not execute Python or prove the honesty of a diagnostic JSON
document. The corresponding offline acceptance restores the same archive,
validates its complete declared members and OS prerequisites, executes its
isolated launcher, and compares the exact report. Declaration-only evidence is
not successful runtime reproduction. Names and platform declarations do not
establish institutional credentials, software licenses or archival ownership.

## Staged retention and final binding

1. Obtain the exact context from `modeContextHash(terms)` and run the retained
   tool against the exact environment and selected image bytes. Retain original
   runtime and replay artifacts, including independent local execution provenance.
2. Publish the original reference through its unchanged actual Metadata CURATOR
   class-3 or global class-8 grant. Historical source checks remain applicable.
3. Canonically encode the supplement. Preupload each ordered segment of at most
   8,192 bytes with the existing permissionless Store `publishChunk(bytes)`.
   Uploading bytes grants no publication authority. Chunks can be uploaded in
   separate bounded transactions and reused by exact content hash.
4. Call `publishMetricSupplement(referenceRecordHash,supplement)` through the
   actual current grant, before the reference lock. The original reference must
   still be current. The producer verifies every original byte and chunk and
   retains their immutable pointers; it does not deploy the full supplement in
   that final call. A missing chunk reverts the entire final binding. Each
   original record accepts one supplement only.
5. Retain the emitted schema-1 receipt. Its exact supplement hash enters the
   PERCEPTUAL finality input and the class-2 lock's old/new commitment. The same
   identity enters the locked component hash. `requireMetricSupplement` checks
   current original sources plus exact retained supplement bytes; the historical
   `metricSupplement` reader makes no present-source claim.

The complete PERCEPTUAL interpretation segment contains 22 items: its original
eight mode/definition items and fourteen supplement roles. These include both
new definitions, receipt, complete ABI payload, index, parameters, four source
files, runtime declaration, replay inputs, wrapped transcript and replay tuple.
Original environment inventory already carries every package and OS member.
Repeated bytes in distinct roles remain distinct inventory occurrences.

## Evidence and remaining acceptance

`StreamReferenceMetricSupplement.t.sol` uses the exact retained 219,264-byte
wrapped replay from B's isolated CPython capture and its original raw-transcript
negative. That capture has a synthetic image/context boundary; it does not prove
an actual mode publication, archive receipt or current-chain finality flow.
The frozen twenty-source proof capture passes seven cases, including 256
byte-order parity fuzz runs, ignored-padding controls and exact source/member/
replay substitutions. All eighteen compiled production products fit. Exact
field comparisons and masked lexicographic word comparisons reduce its actual
proof-call gas from 15,911,783 to 7,706,520; these are proof-call measurements,
not the publisher transaction envelope.

The separate `StreamReferenceMetricPublication.t.sol` joined recipe is being
completed in the acceptance batch; it is not part of this production/proof
handoff. Its source and exact replay fixture will be handed over together. It uses
the actual 299,707,890-byte combined browser/metric ZIP identity, 1,048 package
members, 102 explicit platform prerequisites and fresh repeated browser outputs.
Its Metadata, Schema, Store, archive records and threshold Safe are actual
contracts; inherited Core, Artist and network observations remain named typed
boundaries. The September fixture timestamps are test facts, not signed browser
timestamps or filesystem-mtime attestations.

Run `testExportExactCombinedMetricContext` first with write access only to the
capture's `metric-phase-one/` directory. It exports exact environment, coverage,
metric and context ABI, native input JSON and canonical environment bytes. Feed
those originals to the isolated replay tool. Retain its result as
`test/fixtures/preservation/reference-metric-combined-v1.abi`, then execute the
remaining cases against the same frozen contract/setup and compiled source.
The export test alone is not finality acceptance. The replay file is not
fabricated from a different context to make the later tests pass.

The authored joined cases cover missing-supplement admission, actual writer denial,
once-only binding, exact locked component identity, all supplement inventory
roles, missing-last-chunk Safe rollback and identical retry, and a final binding
call bounded by 16,777,216 gas including calldata intrinsic cost. Authored tests
and a high-gas setup do not establish this transaction envelope until executed.
The accounts/chunks explicitly cooled in the test are identified in its source;
there is no broad cold-current-graph claim.

The earlier `0a72dec4` two-suite capture failed Solidity code generation with a
Yul stack-layout error before any tests executed. Its production size preflight
passed. That failure is retained separately; it is not a runtime failure or a
passing acceptance result for this supplement.
