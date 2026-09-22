# Link script and dependency evidence to a Museum dossier

This offline tool connects a verified [collection script/dependency
package](../tools/museum/COLLECTION-SCRIPT-DEPENDENCY-V1.md) to a verified
[canonical dossier V4](museum-unified-dossier-v4.md). It retains both complete
packages and adds original occurrence references for two existing requirements:
`OD-SCRIPT-MANIFEST` and `OD-DEPENDENCY-MANIFEST`.

The nineteen packet groups, forty-nine assessment rows and all original
assessment bytes remain unchanged. The new ledger records supporting evidence;
it does not mark either requirement accepted or complete.

## Assemble and verify

Use the [Museum Python environment](../tools/museum/README.md). Supply both
complete input directories and their separately retained manifest commitments:

```powershell
python -m tools.museum.canonical_dossier_script_links_v1 assemble --dossier <v4-directory> --dossier-hash <v4-manifest-hash> --scripts <script-package-directory> --scripts-hash <script-manifest-hash> --disclosure public --output <new-output-directory>
python -m tools.museum.canonical_dossier_script_links_v1 verify <output-directory> --manifest-hash <output-manifest-hash>
python -m tools.museum.package_v2 verify <output-directory> --manifest-hash <output-manifest-hash>
```

The output directory must be new, have an existing parent and remain outside
both inputs. Publication stages and reads the resulting files before publishing.
Restricted disclosure is unsupported and fails before source reads.

Python callers use `compose(dossier_files, dossier_hash, script_files,
script_hash, disclosure="public")` and `verify(files, manifest_hash)`. Both
concrete child verifiers replay their complete sources before the join reads
their reports. Verification then reconstructs every derived output byte. A
freshly computed hash of received input detects later changes; it does not
authenticate the input's origin.

## Read the output

| Path | Content |
| --- | --- |
| `dossier/` | Exact complete V4 input, including original assessments and every retained child |
| `scripts/` | Exact complete script package, including anchor, ordered transcript, runtime bridge, source snapshot and available payloads |
| `evidence/script-requirement-links.json` | Two supplemental requirement rows with exact original assessment, manifest, interpretation, wire-report and payload references |
| `evidence/source-observations.json` | Source join status, positive-observation comparison, original transcript indices and unavailable outcomes |
| `definitions/` | Exact local join and observation profiles; this retention does not register them |

Each interpretation remains an occurrence in the original order, including
current and saved references to the same bytes. Its JSON pointer locates the
original entry in `scripts/source/snapshot.json`; its file reference commits
the complete snapshot. Available script/library bytes have separate exact
payload references. Byte availability and completeness of a native wire
observation are separate from acceptance of a dossier requirement.

## Source and availability boundaries

- A current manifest is current at its original script source state. A raw
  saved bundle keeps its original host and does not become a current selection.
- A verified wire-empty dependency applies to that particular interpretation.
  It does not establish a complete global dependency inventory.
- Zero selection, unmanifested inline script, empty serving source and
  unavailable calls remain distinct. Inline or empty source creates no invented
  manifest occurrence. Missing bytes do not become an empty payload.
- The comparison includes positive original runtime, getter and block
  observations. Conflicts at the same chain/block fail even if a source has a
  different configuration or provenance label. Different source states remain
  explicitly unjoined.
- Every unavailable script call retains its original transcript index and
  sanitized outcome. These failures are excluded only from positive fact
  comparison; they are neither absence evidence nor invented successful calls.
- The script source declares collection scope. The join does not invent a
  token identifier, infer token authority, or fill undeclared schema/Artist
  Registry configuration fields. Host deployment evidence stays separate.

The existing script package retains an externally admitted runtime bridge as
opaque bytes. This tool does not authenticate that bridge, register an
interpretation, execute JavaScript, fetch URIs, prove selection history,
construct an authoritative render inventory, or establish institutional
acceptance. All other dossier requirements remain in their original state.

## Validation

```powershell
python -m unittest tools.museum.test_canonical_script_observations_v1 tools.museum.test_canonical_dossier_script_links_v1 -v
```

Fixtures use concrete source replay over synthetic responses. They do not
claim an executed native capture or deployed-chain acceptance. Native execution,
registered profiles, complete media/render joins and institutional evidence
remain separate work.
