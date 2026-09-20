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
replay substitutions. All thirteen nonempty production runtimes fit; the size
report also contains five zero-byte interfaces. Exact
field comparisons and masked lexicographic word comparisons reduce its actual
proof-call gas from 15,911,783 to 7,706,520; these are proof-call measurements,
not the publisher transaction envelope.

The separate `StreamReferenceMetricPublication.t.sol` joined recipe has a frozen
source and context-export capture. Its exact restored replay passed against the
exported context, and its 219,744-byte ABI is retained with the test. It uses
the actual 299,707,890-byte combined browser/metric ZIP identity, 1,048 package
members, 102 explicit platform prerequisites and fresh repeated browser outputs.
Its Metadata, Schema, Store, archive records and threshold Safe are actual
contracts; inherited Core, Artist, governed-action authority and network
observations remain named typed boundaries. The lock test exercises the actual
producer and finality reader against an explicitly supplied class-2 action; it
does not demonstrate a complete governance proposal and execution ceremony.
The September fixture timestamps are test facts, not signed browser
timestamps or filesystem-mtime attestations.

Byte-identical repeated PNGs retain their original immutable archive object
identity. The joined recipe checks all declared object fields before reuse and
records fresh signed checkpoint, receipt and fixity evidence for the later
observation. Earlier receipts remain readable. Registering that same object a
second time still reverts; a new environment does not make identical image
bytes a new object or erase their prior evidence.

Run `testExportExactCombinedMetricContext` first with write access only to the
capture's `metric-phase-one/` directory. It exports exact environment, coverage,
metric and context ABI, native input JSON and canonical environment bytes. Feed
those originals to the isolated replay tool. Retain its result as
`test/fixtures/preservation/reference-metric-combined-v1.abi`, then execute the
remaining cases against the same frozen contract/setup and compiled source.
The export test alone is not finality acceptance. The replay file is not
fabricated from a different context to make the later tests pass.

The frozen 351-source capture passes four cases: the exact context export,
matching original-anchor read, mismatched locked-anchor refusal, and repeated
PNG object retention with fresh coverage and duplicate-registration refusal.
All eight affected production products fit. Its 106,947,518-gas export case is
a high-gas fixture serialization operation, not a publishable transaction or a
successful publisher-budget test. Earlier failed setup captures are retained;
their provider admission, original-anchor and duplicate-object failures do not
count as executed acceptance cases.

The same cached setup trace measures the 1,048-member package's
`prepareFileInventory` call at 38,710,093 gas before calldata intrinsic cost.
That preparation exceeds the 16,777,216 transaction cap. The 102-member platform
preparation uses 4,630,128 gas. The fixture therefore does not establish a usable
transaction sequence for this complete combined environment. The subsequent
[staged inventory companion](reference-inventory-preparation.md) preserves the
original full inventory identity and measures bounded parts and finalization
against the real 1,048-row corpus; its guarded probe remains separate from this
whole publisher acceptance run. Final-binding measurements below
cannot close that separate preparation-capacity limitation, and no production
gas cap has been raised to hide it.

The cached joined run passes the same four source/export cases and fails four
publication cases before supplement admission. Each fails in the original
reference publication's bounded call with
`RouterEvidenceGas(6179424,6195238)`: the nested source read cannot receive its
complete configured budget after the preceding work. The unchanged cached
artifacts and replay bytes are retained; the guard and transaction envelope
have not been relaxed. The archived metric execution itself reproduced the
exported context and report, both scores of 1,000,000,000, and exit status zero
at its actual observed time, 20 September 2026 00:36:24 UTC. This does not turn
the unsuccessful onchain publication into finality acceptance.

The authored joined cases cover missing-supplement admission, actual writer denial,
once-only binding, exact locked component identity, all supplement inventory
roles, missing-last-chunk Safe rollback and identical retry, and a final binding
call bounded by 16,777,216 gas including calldata intrinsic cost. Authored tests
and a high-gas setup do not establish this transaction envelope. These four
cases have executed but their later supplement, Safe retry, lock and inventory
assertions were not reached because original reference publication failed.
The accounts/chunks explicitly cooled in the test are identified in its source;
there is no broad cold-current-graph claim.

The earlier `0a72dec4` two-suite capture failed Solidity code generation with a
Yul stack-layout error before any tests executed. Its production size preflight
passed. That failure is retained separately; it is not a runtime failure or a
passing acceptance result for this supplement.

The subsequent publication transport repair keeps the original request in
calldata until the fixed preparation worker decodes the complete publication
and evidence pair once. The host's candidate check transports only its seven
original fields; receipt construction, current-source checks, record and chain
preimages, retained bytes and mutation order remain unchanged. A focused
31-source capture passes three transport tests, including 256 fuzz cases and
the exact original record and pair encodings over the 1,048-row package and
102-row platform declarations. The candidate probe measures 1,873,517 gas for
the original full-tuple path and 6,123 for the projected header. These are
sequential probe measurements, not a cold publisher transaction. All three
changed production products fit; whole-publication gas acceptance remains
pending. Malformed nested ABI rejection is still required before writes, but
this transport capture does not claim identical error precedence between
malformed nested data and an invalid header.

### Joined staged-preparation capture

The retained `reference-metric-publication-native8` successor compiles only the
changed test recipe against the frozen 354-source cached graph. All 12 selected
production products fit. Five of nine test bodies pass: exact combined context
export, both original-anchor controls, repeated-PNG object/coverage identity, and
the actual host's staged preparation envelopes. Measured calls including calldata
intrinsic cost are 2,431,458 gas for the largest 64-row part, 12,820,216 for the
complete inventory, and 13,942,210 for deterministic environment preparation.
These close the named preparation calls for this corpus, not whole publication.

The four publication/Safe/lock/inventory cases still fail before reference
publication completes. The retained cached trace measures actual preview at
35,360,587 gas, its preparation worker at 29,773,494, and the payload worker at
6,560,150. The bounded write exhausts memory-expansion gas after reading the
179,418-byte retained environment, before dispatching the large payload tuple.
The later supplement binding, Safe retry, component lock and inventory assertions
are therefore still unexecuted. No production cap or admission guard was relaxed.

The earlier native7 failures are also retained. Its original aggregate setup
exhausted a one-billion-gas test harness. A cached three-billion-gas harness retry
reached a separate snapshot defect: in installed Forge 1.7.1
(`4072e48705af9d93e3c0f6e29e93b5e9a40caed8`), a three-source probe observed that
creating an actual Store carrier, cooling it with `vm.cool` in `setUp`, and then
reading it in a test body lost its code across the setup snapshot. Untouched
carriers and carriers created/cooled inside the same test body passed. This is
the retained probe's scope, not a production Store failure.

The native8 recipe accordingly performs the actual preuploads, staged calls and
cooling inside the relevant test bodies. It retains every explicit 16,777,216
per-call envelope, calldata intrinsic calculation and result check. The larger
aggregate harness is only infrastructure for multiple transactions in one test.
Named accounts/chunks are cooled; there is no claim that all transitive accounts
and storage slots are cold, or that this typed fixture is a live RPC anchor.
