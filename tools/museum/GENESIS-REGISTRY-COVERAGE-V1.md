# Genesis Registry coverage

This reader compares all **29 canonical genesis schemas and 22 supporting
definitions** with the Registry selected by the current Core metadata graph.
It preserves a result for every required name, including missing documents,
conflicting definitions and retired definitions. It performs no registration.

The expected bytes come from the existing
[genesis catalog](../../schemas/museum/genesis/catalog.json) and
[admission plan](../../schemas/museum/genesis/admission-plan.json). The new
reader pins those original files and all 51 document meanings. Their original
prospective status and source provenance remain intact. Verification does not
regenerate them from the current checkout. A different expected catalog needs
an explicitly versioned consumer; changing an external package hash cannot
reduce this reader's denominator.
Exact version-local copies of the two prospective input files live under
`tools/museum/fixtures/genesis-registry-plan-v1/`, so later regeneration of the
source catalog's provenance cannot silently change this consumer.

## Native checks

The graph starts at the current Core `COLLECTION_METADATA` pointer, follows
the selected Metadata host's `schemaRegistry()`, and reads that Registry's
`chunkStore()` and governance binding. Runtime commitments, the selected
pointer and original native bindings must agree at the supplied source block.
The reader uses the admission registry recorded in the Metadata pointer; a
later Core ModuleRegistry replacement does not replace that original reference.
The caller must explicitly admit those runtime commitments; a code hash alone
does not prove an implementation's semantics.
The anchor's `runtimeAdmission` retains the source-review checkpoint and an
external artifact commitment. This reader does not verify compilation or that
artifact's contents. Capture owners must retain their separate runtime/source
correspondence evidence when using a newer deployment build.

Every required document keeps its expected and actual specification, status,
declaration hash, full payload and ordered chunk occurrences. The native
declaration hash uses the original ABI specification and chunk array. Whole
document hashing remains separate. Store bytes and STOP-prefixed carrier
runtime must reconstruct the same original payload. Matching retired bytes
remain readable historical evidence and do not count as active admission.
For a native-maximum document whose aggregate response exceeds the transport
limit, all ordered chunks reconstruct the full bytes and the omitted aggregate
getter is reported explicitly. The shared ABI reader supports UTF-8 URI strings;
native URI byte strings with invalid UTF-8 remain outside its availability.

The reader checks the fixed named set. It does not enumerate unrelated
Registry entries, earlier Registry instances, publication transactions or
governance events. A missing document is a result of its exact pinned getter;
omitting a getter from the transcript is a verification failure.

## Prepare and replay

Use the existing Museum Python environment. All output directories must be new
and have existing parents. Preparation copies the pinned prospective inputs:

```powershell
python -m tools.museum.genesis_registry_coverage_v1 prepare-plan --output PLAN
```

The command prints the plan manifest hash. Capture owners use the read-only
`GenesisRegistrySource` API with the final common source anchor and an explicitly
admitted transport. Preserve its original anchor, `snapshot()` and
`transcript()` bytes. Synthetic fixtures remain synthetic; a retained transcript
does not authenticate its own origin.

```python
from tools.museum.genesis_registry_source_v1 import GenesisRegistrySource

source = GenesisRegistrySource(
    anchor_bytes, transport, plan_files=plan_files, plan_hash=plan_hash,
    provenance="trusted_rpc",
)
snapshot_bytes = source.snapshot()
transcript_bytes = source.transcript()
```

The closed anchor includes `profile`, `chainId`, `core`, `blockHash`,
`blockNumber`, `timestamp`, `stateRoot`, `environment`,
`deploymentEvidenceHash`, `coreRuntimeHash`, `codePins` and `runtimeAdmission`.
The six original role pins cover Core, the selected Metadata host, its admission
ModuleRegistry, SchemaRegistry, document Store and governance authority.
`runtimeAdmission` has `sourceCommit`, `kind` and `artifactHash`; the reader
exposes its fixed source-review checkpoint as `SOURCE_REVISION`. Use
`externally_admitted_runtime` only with an actual external runtime admission;
synthetic sources use `synthetic_fixture`. Generated carrier hashes are derived
from their exact observed STOP-prefixed bytes, separately from those role pins.

Once those original inputs and their external Keccak commitments are available:

```powershell
python -m tools.museum.genesis_registry_coverage_v1 assemble `
  --plan PLAN --plan-hash PLAN_HASH `
  --anchor ANCHOR.json --anchor-hash ANCHOR_HASH `
  --transcript TRANSCRIPT.json --transcript-hash TRANSCRIPT_HASH `
  --provenance trusted_rpc --disclosure public --output COVERAGE
python -m tools.museum.genesis_registry_coverage_v1 verify COVERAGE `
  --manifest-hash COVERAGE_HASH
```

Use `--provenance synthetic_fixture` for synthetic inputs. The package retains
every original plan file under `plan/`, the source bytes under `source/`, and
the concrete native coverage report. Verification consumes every retained RPC
call and deterministically rebuilds every package member without network reads.
Rehashing a changed report, upgraded claim, omitted definition or changed
source observation does not bypass that replay.

## Acceptance limits

Complete active correspondence means that the entire fixed registration plan
matches the selected Registry at the admitted block. It does not prove the
registration transactions, full semantic dependency closure, complete object
dossier, consensus, public-chain execution, release readiness or institutional
acceptance. It leaves the existing 19 packet and 49 dossier requirements
unchanged. Actual captures and their provenance remain separately required.
