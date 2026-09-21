# Preserved Museum tools and offline replay

This additive path preserves the source, runtime and complete input vectors for
[acquisition V10 and object dossier V3](CANONICAL-COMPOSITION-V10.md). It can
regenerate those packages without a network connection, operator database,
dependency installation or access to the original Python installation.
Windows x86_64 and the declared Windows system libraries remain prerequisites.

The source archive uses the existing [preservation package format](../preservation/README.md):
deterministic ZIP, original file inventory, SHA-256 transport manifest and
ordered 512 KiB parts. New bounded admission wraps that format. Atomic output
publication reuses the Museum repository exchange implementation. This is not
a new archive transport or a registered packaging profile.

## Preserved inputs

| Input | Pin and checks | Scope |
| --- | --- | --- |
| Source package | External SHA-256 of exact `parts.json`; complete ZIP SHA-256 and Keccak; every original member; recomputed local import closure | Explicit full Git commit, schema resources, dependency lock inputs, instructions, all declared vectors, licenses and prerequisite declarations |
| Runtime package | External SHA-256 of exact `parts.json`, plus separate runtime recipe SHA-256 | Exact installed CPython 3.13.13 and sixteen pinned Museum distributions; original licenses and distribution records; PE import dependency closure |
| Vectors | Exact packet/dossier manifests and every original input member | Every declared case must regenerate; undeclared files or omitted cases are refused |
| Optional native release evidence | Separate original-evidence Keccak and source-block RPC/runtime pins | Current Core SystemManifest pointer, immutable bindings, complete selected-host publication history and exact `reconstructionClientHash` |
| Optional Archive evidence | Original artist-scoped Artifact or ExternalObject evidence and source-block getter results | Exact source ZIP and selected deployment payload are checked separately; release authority is not inferred |

The runtime recipe is explicit about locally observed bytes and external Windows
libraries. An installed package record or a supplied digest does not authenticate
a publisher. Prebuilt interpreter/extensions are preserved; their compiler builds
are not reproduced. The source package records instructions and dependency locks
without downloading or installing anything during verification or replay.

The old Burn Python 3.12 runtime cannot load these CPython 3.13 extension modules.
The runtime builder uses the actual standalone interpreter and named dependency
files. A virtual-environment launcher alone is refused as a portable runtime.

## Build and verify inputs

The Python APIs accept explicit inputs and do not discover a latest release:

```python
from pathlib import Path
from hashlib import sha256
from tools.museum import preserved_tool_runtime_v1 as runtime
from tools.museum import preserved_tool_source_v1 as source
from tools.museum import preserved_tool_replay_v1 as replay
from tools.preservation.reference_package import package_tree

# Explicit paths to the supported local CPython and Museum site-packages.
recipe = runtime.plan(python_base, museum_site_packages)
recipe_hash = sha256(recipe).hexdigest()
runtime.materialize(recipe, recipe_hash, Path("runtime-tree"))
package_tree(Path("runtime-tree"), Path("runtime-package"),
    {"profile": runtime.PROFILE, "recipeSha256": recipe_hash})

# Each case has id, kind (packet_v10 or dossier_v3), files and manifestHash.
vectors = replay.vector_inputs(cases)
source.build(repository, Path("source-package"),
    source_revision=reviewed_full_commit_sha, vectors=vectors,
    external_pins=external_pins, licenses=licenses, prerequisites=prerequisites)
source.verify(Path("source-package"), source_parts_sha256)
```

`external_pins` contains named `role`, `uri`, `sha256` and `bytes` commitments.
Prerequisites declare `name`, `version`, `platform`, `included: false`, their
named `pin`, and a qualification. The supported CPython prerequisite must be
explicit. Its pin must identify the exact runtime package's `parts.json`; the
runtime recipe must also have a matching declared runtime/system pin. Replay
joins those commitments and the exact CPython version before execution.
Other declarations are retained inputs, not automatically verified
external artifacts. The source builder checks exact Git blobs at the supplied
full commit; branch names and moving references are refused. Replay uses the
preserved bytes and never invokes Git. A standalone archive verifier does not
independently prove the claimed Git provenance.

All outputs must be new directories with existing parents. Existing outputs,
transport input/output overlap, links, aliases, missing parts, extra members, malformed
ZIPs, excessive expansion and mismatched external pins are refused.
The Git source builder may write under the repository's `out` directory because
its source is an immutable commit, not the working directory.

## Explicit replay

Only run source and native-runtime archives whose exact external pins you trust.
Archive inspection never executes retained code. The commands below explicitly
execute the reviewed source and runtime selected by their pins.

```powershell
python -m tools.museum.preserved_tool_replay_v1 `
  --source-package source-package --source-sha256 <parts-sha256> `
  --runtime-package runtime-package --runtime-sha256 <parts-sha256> `
  --runtime-recipe runtime-recipe.json --runtime-recipe-sha256 <recipe-sha256> `
  --output replay-result
```

The fixed child entrypoint admits only V10 packet and V3 dossier operations.
It runs with isolated Python paths, no user site, no bytecode writes and a
sanitized environment. A Python audit guard refuses network calls, child
processes and writes outside the result directory. This guard is not an OS
sandbox and does not make hostile Python/native code safe to execute.

Every case is reconstructed by its archived concrete source consumer. Every
output byte must equal the original package, including original observations,
nineteen packet groups and forty-nine dossier requirements. The receipt records
the fixed worker bytes, module origins/hashes, file reads, runtime recipe, all case results
and bounded stdout/stderr. Timeout or output-bound failures terminate only the
child created by this run and publish no successful result.

## Dossier supplement

```powershell
python -m tools.museum.preserved_tool_dossier_v1 assemble `
  --dossier original-v3-dossier --dossier-hash <manifest-keccak> `
  --source-package source-package --source-sha256 <parts-sha256> `
  --runtime-package runtime-package --runtime-sha256 <parts-sha256> `
  --runtime-recipe runtime-recipe.json --runtime-recipe-sha256 <recipe-sha256> `
  --disclosure public --output preserved-dossier

python -m tools.museum.preserved_tool_dossier_v1 inspect preserved-dossier `
  --manifest-hash <supplement-manifest-keccak>

python -m tools.museum.preserved_tool_dossier_v1 replay preserved-dossier `
  --manifest-hash <supplement-manifest-keccak> --output new-replay-result
```

Assembly requires the selected dossier to appear byte-for-byte among the
preserved vectors. It retains the complete original dossier, both transports,
the recipe and replay receipt. Optional `--release-evidence` admits the original
native release source and reconciles its observations with the dossier at the
same source state. A conflicting runtime, getter, event or anchor is refused.

`inspect` reconstructs byte and source semantics without executing archived
code. It cannot authenticate who produced a previous execution receipt.
`replay` executes the pinned archives again. A rehashed receipt cannot promote
genesis, source-authority or institutional claims or replace the fixed worker.

The original 19/49 acceptance assessments remain intact. The supplement reports
new concrete tool capabilities separately. Remaining work includes complete
genesis-to-source-state reconstruction, compiler build reproducibility, the
semantic/render scope, authenticated execution provenance and release authority.
New execution receipts also need their own archival correspondence; a source
ZIP's archival evidence does not archive subsequently produced receipts.

Synthetic acceptance vectors are labeled by their retained source provenance.
They do not establish a genuine deployed release selection, live chain capture,
current archive liveness, consensus, institutional ingest, an audit or readiness
for deployment.
