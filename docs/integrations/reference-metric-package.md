# Retained metric source and runtime supplement

The additive metric supplement retains the exact SSIM implementation and
parameters, joins its runtime to the original reference publication's environment
archive, and records an attributed replay from restored bytes. It preserves the
original seven-field `Metric`, `6529STREAM_PERCEPTUAL_REPORT_V1` preimage and all
V1 interpretation documents. The onchain supplement/profile is a separate
producer. This tool does not establish a publication grant, chain inclusion,
browser execution, institutional acceptance or dual-family receipt validity.

Use the repository's existing museum Python environment. No package command
downloads dependencies or changes an installed interpreter. The closed runtime
profile currently targets Windows AMD64 CPython and the integer RGB8 SSIM tool.

## Build the complete environment

First prepare the actual browser/capture environment tree using the original
reference package workflow. Add the metric **before** creating the environment
object, recording coverage and publishing the reference. An existing immutable
environment that omitted these bytes cannot be repaired by attaching unrelated
files with the same human-readable names.

```powershell
python -B -m tools.preservation.reference_metric_package stage --environment-tree retained-tree --python-root C:/path/to/actual/python --distribution-root C:/path/to/museum/Lib/site-packages --material metric-material.json
python -B -m tools.preservation.reference_metric_package pack --environment-tree retained-tree --archive complete-environment.zip --inventory complete-inventory.json
```

`stage` refuses to overwrite an existing `metric/` subtree. It copies the four
original source files without normalizing line endings, their imported repository
modules, a complete standard-library ZIP, interpreter/native DLLs and these exact
installed distributions: attrs, jsonschema, jsonschema-specifications,
pycryptodome, referencing, rfc8785, rpds-py and typing-extensions. Distribution
metadata and license files are retained; caches and unused console wrappers are
excluded. The library ABI must match the interpreter. A mismatched or incomplete
runtime fails the actual replay rather than using the host installation.

The original `implementationHash` is Keccak of the sorted, compact ASCII JSON
map from each of the four original repository paths to its lowercase SHA256
digest without `0x`. The index itself, all four byte strings and exact canonical
parameter JSON are retained. The supplement independently checks the hashes;
a code hash or a tool/version label alone is insufficient.

The runtime declaration contains the original environment object/manifest
hashes, `metric/source`, the exact metric entrypoint, `metric/python/python.exe`,
`metric/launch.py`, the fixed arguments `-I -S -B metric/launch.py`, and every
`metric/` member of the original environment's ordered package inventory.
`runtimeHash` uses `keccak256(abi.encode(keccak256("6529STREAM_METRIC_RUNTIME_V1"), runtime))`.
Members carry original paths, byte lengths and SHA256 digests. Missing, extra,
aliased, substituted and cross-environment members are rejected.

## Bind, verify and replay

The context JSON is a caller-supplied, externally authenticated observation with:

- `environment`: the original object/coverage/manifest hashes, numeric
  `packageFiles` rows and explicit `platformPrerequisites` rows;
- `environmentBytes`: lowercase `0x` bytes of the original canonical environment
  JSON, whose decimal-string file rows must agree exactly with those typed rows;
- `metric`: the original registered seven-field tuple;
- `coverage`: original `objectHash`, `coverageHash`, `byteSize`, `sha256Digest`,
  `contentHash` and `arweaveDataRoot` of the complete ZIP;
- `inputs`: the original metric input manifest with context/environment hashes,
  threshold, evaluation time and ordered capture-pair SHA256/dimensions;
- `expectedReportHash`: the exact original attributed report hash.

Context authentication and receipt verification belong to the existing native
source/coverage readers. Supplying a self-consistent local context is not proof
that it was published. Integers in this context and the new supplement JSON are
numeric; bytes are lowercase `0x` hex. Canonical JSON has sorted keys, compact
separators and no final newline.

```powershell
python -B -m tools.preservation.reference_metric_package bind --context context.json --material metric-material.json --output bound.json
python -B -m tools.preservation.reference_metric_package verify --context context.json --supplement bound.json --archive complete-environment.zip
python -B -m tools.preservation.reference_metric_package replay --context context.json --supplement bound.json --archive complete-environment.zip --pair first-a.png first-b.png --pair last-a.png last-b.png --output replay-output
```

`verify` never executes archive contents. It verifies every ZIP member and the
whole ZIP's SHA256, Keccak and Arweave data root. `replay` is explicit: it restores
the verified ZIP to a fresh directory and runs only the retained closed launcher
using the retained interpreter. It replaces Python's import paths with archive
paths, disables site and bytecode writes, clears inherited Python/PATH settings,
denies Python network/process audit events, and checks every loaded Python module
and native image. Negative network/process probes must fail. Every loaded
external Windows DLL must already match an explicit platform prerequisite's
path, size and SHA256. The OS is not represented as contained in the archive.

This is an isolation recipe for a known, pinned metric and its native libraries,
not a security sandbox for arbitrary hostile executable archives. Native code
and the operating system remain trusted execution substrates. No claim of
network isolation against malicious native code follows from Python audit hooks.

The final report must reproduce the original Metric tuple, input and report hash.
The replay transcript retains runtime/context/report/input hashes, time, exit
code, import/native footprint, OS prerequisite hashes and measured output.
Outputs are `supplement.json`, exact `supplement.abi`, and `transcript.json`.
The `chunks/` directory also contains the exact ordered 8,192-byte segments,
their Keccak hashes and zero-value `publishChunk(bytes)` calldata. Send those
calls separately to the reference producer's original pinned
`StreamSchemaDocumentStore`; then publish the supplement through its actual
authorized entrypoint. Uploading bytes grants no publication authority.
Existing Store chunks are content-addressed and repeated uploads are idempotent.
To derive the upload files from an already retained ABI payload without replay:

```powershell
python -B -m tools.preservation.reference_metric_package chunks --payload replay-output/supplement.abi --output upload-chunks
```

The transcript is limited to 65,536 bytes; total encoded supplement to 524,288.
The onchain producer can validate byte identities and the attributed replay
record; it cannot prove that Python or the browser executed.
The `verify` command also checks any supplied final replay receipt and transcript
against the original input/report, runtime identity and declared import footprint.
It does not treat a consistent execution assertion as proof of execution.

## Focused checks and acceptance limits

```powershell
python -B -m unittest tools.preservation.test_reference_metric_package.MetricPackageTests -v
$env:STREAM_METRIC_RUNTIME_TEST='1'
python -B -m unittest tools.preservation.test_reference_metric_package.RestoredMetricRuntimeTests -v
```

The ordinary controls use explicit byte-only fixtures for missing/changed source,
parameters, archive members, canonical encodings and same-environment joins.
The opt-in Windows test copies an actual interpreter and dependencies, restores
the ZIP and reproduces the original report with network/process fallback probes.
Its input PNG and publication context are synthetic; it does not stand in for
an actual browser capture, authenticated publication, receipt coverage or full
onchain finality composition. It observes Windows prerequisites during preparation
and then requires their exact hashes in the final replay. Production users must
capture and retain those platform facts before the immutable environment is
published. Other operating systems and metric families need explicit profiles.
