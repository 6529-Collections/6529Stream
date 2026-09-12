# Candidate offline resource package

`tools.museum.package` writes and reconstructs the current semantic resource
projection from its exact inputs and copied interpretation dependencies. The
package is wholly synthetic and public. Its manifest explicitly disclaims
registered records, authenticated chain state, full Museum conformance, an
archived implementation, BagIt and OCFL. The real disclosed-state adapter,
implementation/source archive and complete dossier formats remain required.

The package contains:

- The immutable fixture source state and exact selection/projection policies.
- The candidate crosswalk and all original context, schema and vocabulary chunks,
  indexes, interpretation policies and retained Linked Art licenses.
- One canonical JSON-LD resource and one deterministic expansion for each
  supported resource entity, plus an index resolving typed extension entities to
  their sidecar. Stable IRIs do not depend on filenames or directory location.
- The source sidecar, field coverage, source provenance and projection report.
- A manifest committing to each child's path, exact length, SHA-256 and Keccak-256.

The manifest does not hash itself. Its Keccak hash is supplied externally when
verifying. The semantic package manifest can later be a child of an enclosing
dossier manifest; it does not depend on that parent or a subsequently published
record. This candidate format is not the onchain export payload schema.

## Verification

Verification first checks the externally supplied manifest hash and canonical
manifest bytes. It checks every child, rejects missing/extra files, duplicate
case-insensitive names, path traversal and Windows device names. It then rebuilds
the fixture state, reloads the copied immutable dependency closure, reruns source
selection, entity projection, coverage and real offline JSON-LD validation, and
compares every regenerated file and manifest byte. Rehashing a forged `_label`
in the manifest therefore fails semantic reconstruction. Rehashing a changed
ontology/context chunk still fails its original dependency pin.

No network loader, RPC whole-document read, mutable database or external website
is involved. The 434,213-byte CRM source retains one logical identity and all
54 ordered original chunks. The package copies raw bytes, including original
line endings and license whitespace. Verification works after moving the package
to another directory. This establishes reproducibility under the installed
supported implementation, not archival availability of that implementation.

`write_package` requires a new output directory and writes `manifest.json` last.
It does not overwrite an existing package. If a write fails, an incomplete
directory is left without a completed manifest; callers must not treat that as
a verified package. The current file ceiling is 8,192, child bytes total at most
96 MiB, and the manifest at most 2 MiB. Projection and dependency-specific bounds
also apply. These finite implementation limits are not wall-clock guarantees.

Restricted source records are rejected by this package builder. The projection
API can withhold them, but this package format cannot yet reconstruct a hidden
source commitment without copying its identifying inputs. It fails explicitly
until an authenticated disclosed-scope proof is implemented, rather than
copying private identifiers or claiming complete reconstruction of omitted data.

## Reproduce the example

Install the pinned environment from [the tooling README](../tools/museum/README.md).
The [example inputs](../schemas/museum/projection/package-example/source-state.json)
are synthetic statements and fake family/record identifiers. They exercise four
ordinary resources plus one typed abstract-work extension. They are not the
complete still-photograph/history fixture required by the Museum specification.

From the repository root, run this single command into a new directory:

```text
python -m tools.museum.package build-fixture schemas/museum/projection/package-example/source-state.json schemas/museum/projection/package-example/selection-policy.json schemas/museum/projection/package-example/projection-plan.json museum-example --profile-hash 0x1111111111111111111111111111111111111111111111111111111111111111 --selection-hash 0x20be17d87c97ef131edf981a0b1f9d1de257e2a68f1d3cd2f830b29dbb81277b --plan-hash 0x269f21d549b4142c90e8f0cbf86811a64f9208a41a2aea895dc2746f7bb164c1 --validation-hash 0xb0fa483a5e25eda775095980c7b677c252568774b3d6b8944c6294cff3a1f54e --vocabulary-hash 0xd56f4d9fdb72ea1eddcb6542c2fe0a52761d6837914f11b3bf0876ec2bd64faf
```

For these exact inputs and implementation, the expected package has 114 children
and this external manifest hash:

```text
python -m tools.museum.package verify museum-example --manifest-hash 0x800429d529bdd21731c30de891398a11a506855f0a5943ae1656d7c82a64e8a0
```

Keep the manifest hash through a trusted channel; computing a hash from an
untrusted archive only checks that same archive against itself. The fixture
profile hash is deliberately synthetic and is not a claimed registered profile.
`python -m unittest tools.museum.test_package -v` checks the example byte identity,
both CLI operations, offline reconstruction, source/child/manifest tampering,
path and disclosure limits and original dependency-byte preservation.

The full source-family crosswalk, abstract-work shape supplement, attributed
specializations, exact dates/measurements and the remaining eight complete
Museum scenarios continue beyond this candidate package. LIDO, PREMIS, IIIF,
dossier/BagIt/OCFL integration and institutional review are not waived by this
bounded reconstruction proof.
