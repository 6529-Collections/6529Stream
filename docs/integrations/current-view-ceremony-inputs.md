# Local inputs for the actual VIEW ceremony

The [current VIEW ceremony](current-view-preservation-ceremony.md) has an
explicit file transport for actual producer bytes and supplied browser
observations. This transport is a local fixture interface. It does not establish
RPC provenance, browser execution, independent archive retrieval, onchain
authority, or transaction capacity.

## Freeze the source before observing it

Use the exact compiled
[`StreamCurrentFullPreservationPolicyViewFinalityTest`](../../test/current/StreamCurrentFullPreservationPolicyViewFinality.t.sol)
host and its authenticated current-graph artifacts. The
[graph preparation procedure](../tooling.md#current-graph-fixture-preparation)
requires native compiler output, build information and matching source bytes.
An ABI-only compiler check cannot supply those artifacts.

Select this concrete host with `prepare_current_graph --host` and retain the
matching native product selection. In addition to the base graph products,
this recipe reads artifacts for `StreamFinalityFullPreservationPolicyEvidenceProviderV1`,
`StreamFinalityFullPreservationPolicyDiscoveryV1`,
`StreamPreservationPolicyPublicationFactoryV1` and
`StreamScopedPreservationPolicyPublicationFactoryV1`, through its separate
`StreamCurrentFullPreservationPolicyCreation` library. The base 68-product list
does not include these four. A native owner must prepare the matching augmented
`--products` selection and authenticated creation context; another host's
cached projection is not evidence for this recipe.

Call `exportViewFinalitySource(outputDirectory, sourceRevision)` with a fresh
directory under `artifacts/native-assembly`. The current Foundry profile already
permits writes there. The explicit `bytes20` revision is the caller's recorded
Git provenance; the fixture does not infer or authenticate a Git checkout. Retain
the source tree and compiler/artifact identity separately. The actual fixture
host runtime and complete reconstructed graph/source bytes are checked on load.

The exporter constructs the actual VIEW publication before any reference
observation or sanction. It retains:

- The fixture host/runtime, chain, initial block and timestamp, and deployment
  identity; capture these before delayed-governance time changes.
- The exact VIEW scope and ordered graph target/runtime identities.
- Publication record identifiers and full original canonical ABI bytes for the
  adoption, checkpoint, output manifest, snapshot and both provider bindings.
- Every ordered member's full 992-byte `outputReturn`, Core `tokenData`, original
  preservation JSON and HTML, with length, Keccak-256 and SHA-256 commitments.

The source manifest is `source.json`; its closed wire format is the
[export schema](../../test/fixtures/preservation-view/ceremony-source-export-v1.schema.json).
Each member uses `member-<20-digit zero-padded index>` with `.output.abi`,
`.token-data.bin`, `.json` and `.html` suffixes. Token identifiers and collection
serials are decimal strings, preserving all 256 bits. VIEW `scopeId` and `viewId`
are distinct identifiers and must retain their original meanings.

Files are read back byte-for-byte and `source.json` is written last. Existing
export directories are refused. Its `sourceHash` is Keccak-256 of the exact
compact UTF-8 manifest, in emitted field order, with the final `sourceHash`
property and its preceding comma omitted. It is not a hash of itself or a
general JSON canonicalization rule. Pin the SHA-256 of the entire final
`source.json` independently when passing it to the loader.

This pre-reference export is not the Museum's complete preserved inventory.
That later packet also needs completed reference/preservation histories and
events, part/index carriers, registered-document and runtime bytes, typed
Metadata/Artist evidence, and recorded inventory reads. A later adapter must
retain those additional facts and the Museum's own canonicalization rules.

## Retain a fresh runtime and repeated captures

The native profile fixes Windows, AMD64, sRGB, device-pixel ratio 1, software
rasterization and `STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1` capture behavior.
It does not fix Chrome to the old 152 observation. A different Chrome version
requires fresh runtime bytes, executable identity, environment inventory and
captures. Declare the exact observed version; changing a version label does not
update an earlier package or observation.

The existing [native package tool](../../tools/preservation/reference_package.py)
pins the official Python 3.12.10 embedded Windows archive and websockets 15.0.1.
Use the exact existing [tool requirements](../../tools/preservation/requirements.txt)
in an isolated environment. Package the explicit installed Chrome version with
`reference_package native`, then restore it with `reference_package restore`
and the independently retained SHA-256 of `parts.json`.

Run the retained `tool/reference_capture.py` using that restored package's
`python/python.exe` and `engine/chrome.exe`. Supply the actual exported HTML for
the first and last ordered VIEW members, in separate fresh output directories.
Use the fixture's actual 64 by 64 canvas viewport. The runner retains
`original.html`, two PNGs, two process reports and `repeat.json`; both independent
processes must produce identical PNG bytes. Its bounded canvas-only profile
rejects unsupported resource use. The full exported HTML must also fit its
65,536-byte input bound.

The environment's complete package inventory includes the generated
`PACKAGE.json` ZIP member. The outer `parts.json` file list omits that member
and cannot be substituted unchanged. Retain every exact loaded dependency as
either a package member or an external Windows platform prerequisite. The
package does not contain Windows itself. Capture reports are retained
observations; their contents are not cryptographic proof that an OS or browser
executed them.

## Literal fixture input contracts

`environment.json` has an `environmentABI` hex field containing the canonical
`abi.encode(StreamReferenceRenderTypes.Environment)` tuple. Its first four
fields, `objectHash`, `coverageHash`, `manifestHash` and `manifestBytes`, must all
be zero. The actual ceremony derives those values from its archive and coverage
records. The remaining fields describe the exact engine, tool, complete sorted
package/platform inventories and capture profile.

`browser.json` describes the complete retained runtime ZIP object with
`byteSize`, `contentHash`, `sha256Digest`, `arweaveDataRoot`, `firstDataPath`,
`lastDataPath`, `firstChunkRaw` and `lastChunkRaw`. The raw endpoint chunks are
the exact native archive-tree intervals, including any rebalanced final
interval; arbitrary fixed-size file slices are not equivalent witnesses.

`captures.json` contains `capture1` and `capture2` for the first and last actual
ordered members. Each includes the same PNG object endpoint fields, lossless
`tokenId` and `collectionSerial`, exact hex `html` and `metadataJSON`, and both
repeat PNG SHA-256 values. Full member export checks still cover every member;
the two captures do not replace inventory coverage.

Package member endpoint inputs use the existing
[`inventory_package_objects`](../../tools/preservation/inventory_package_objects.py)
producer's `member-<20-digit zero-padded package index>.json` names. These files
are separate from the VIEW source member JSON in the export directory. The
loader requires each endpoint's `packageIndex`, path, size, digests and native
chunk proofs to match the selected complete package inventory row. There is no
fallback to an unpadded filename or another index.

## Assemble and check the files offline

The [input tool](../../tools/preservation/view_ceremony_inputs.py) accepts an
explicit `environment-fields.json` declaration with all 24 original Environment
fields. Its integer fields, including inventory sizes, are canonical decimal
strings; `softwareRasterization` is the Boolean `true`. Derive inventory rows
from the actual fresh ZIP and retained loaded-module reports, and supply the
exact engine/tool identity, version, operating-system version and license note.
There are no historical environment defaults.

Individual environment and object transports can be generated as follows:

```text
python -B -m tools.preservation.view_ceremony_inputs environment --input environment-fields.json --output environment.json
python -B -m tools.preservation.view_ceremony_inputs object --input runtime.zip --output browser.json
```

After retaining both first/last capture directories and generating the package
member endpoint manifest, use the complete assembler. Paths below are examples;
replace both external pins with the recorded final source SHA-256 (64 lowercase
hex digits without `0x`) and source revision (`0x` followed by 40 hex digits).

```text
python -B -m tools.preservation.view_ceremony_inputs assemble --export artifacts/native-assembly/view-source --expected-source-sha256 SHA256_HEX --expected-source-revision 0xGIT_REVISION --capture-directory artifacts/native-assembly/capture-first --capture-directory artifacts/native-assembly/capture-last --environment environment-fields.json --runtime-zip runtime.zip --runtime-root restored-runtime --member-manifest endpoints/manifest.json --output-directory artifacts/native-assembly/view-inputs
```

The assembler streams every original ZIP member, checks every nonempty member's
indexed endpoint transport, validates all exported member bytes, and joins the
actual first/last HTML and JSON to both repeated PNGs and process reports. It
then emits `environment.json`, `browser.json`, `captures.json` and a separate
qualified `audit.json` into a new directory. Missing or crossed members, chunk
proofs, reports, source pins or environment fields fail; existing output files
are not overwritten. The audit records local byte consistency and explicitly
leaves independent browser execution and onchain acceptance unestablished.

Focused offline checks run without a Solidity build or browser:

```text
python -B -m unittest tools.preservation.test_view_ceremony_inputs -v
```

## Replay the exact prepared source

Call the same compiled host's
`runSuppliedViewFinalityObservationFiles(sourceExportFile, expectedExportSHA256,
expectedSourceRevision, environmentFile, browserFile, capturesFile,
packageMembersDirectory, measuredArtistReadGas)` with explicit paths and pins.
Use the same host CREATE coordinates, linked artifacts, chain, initial block,
initial timestamp and fixture configuration as the export. The loader
reconstructs the actual pre-observation publication, requires exact complete
manifest equality, and rereads every exported member file before continuing
the existing supplied-observation ceremony.

The original `runSuppliedViewFinalityObservation` entry remains available and
takes JSON contents rather than filenames. Neither entry invents missing
browser evidence or measures `measuredArtistReadGas`. Any governed Artist read
budget must come from separately retained measurement.

The inherited 40m component, 48m source/manifest and 56m registry fixture caps
are diagnostic construction settings. They do not establish acceptance under
the 16,777,216 transaction limit. Native source execution, complete genuine
browser observations, measured capacity and release evidence remain separate
requirements.
