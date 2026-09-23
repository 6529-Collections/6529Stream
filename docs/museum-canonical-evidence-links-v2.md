# Canonical Museum evidence links

This offline extension links five evidence families to an unchanged
[canonical dossier V4](museum-unified-dossier-v4.md). It preserves all nineteen
packet groups and forty-nine original assessment rows. Its supplemental ledger
does not promote a requirement to accepted or complete.

| Requirement slot | Supporting source |
| --- | --- |
| `OD-SCRIPT-MANIFEST` | Optional verified collection-script package, with original current and saved occurrences |
| `OD-DEPENDENCY-MANIFEST` | The same package's original dependency observations and available payloads |
| `OD-MEDIA-MANIFEST` | Native media-master capture already retained in V4 |
| `OD-RENDER-INVENTORY` | Prospective named-simulation records already retained in V4 |
| `OD-SIGNIFICANT-PROPERTIES` | Retained conservation reference occurrences and optional typed preservation-object declarations |

The media and prospective-reference packages remain at their original nested
paths. The extension verifies V4 and each supplied optional child, then compares
all original positive observations together. Conflicts between two optional
sources are checked even when V4 does not observe that particular getter.

## Assemble and verify

Use the [Museum Python environment](../tools/museum/README.md). The V4 directory
and its external manifest commitment are required. Each optional directory must
be supplied with its own separately retained manifest commitment.

```powershell
python -m tools.museum.canonical_dossier_evidence_links_v2 assemble --dossier <v4-directory> --dossier-hash <v4-hash> --scripts <script-package-directory> --scripts-hash <script-hash> --properties <retained-premis-directory> --properties-hash <premis-hash> --disclosure public --output <new-output-directory>
python -m tools.museum.canonical_dossier_evidence_links_v2 verify <output-directory> --manifest-hash <output-hash>
python -m tools.museum.package_v2 verify <output-directory> --manifest-hash <output-hash>
```

Omit either optional directory/hash pair when unavailable. Missing packages
remain explicitly missing evidence. Restricted disclosure fails before source
reads. The output must be a new directory with an existing parent, outside all
inputs. Publication stages and reads back exact bytes before the final rename.

Python callers use `compose(dossier_files, dossier_hash, script_files=...,
script_hash=..., properties_files=..., properties_hash=..., disclosure="public")`
and `verify(files, manifest_hash)`. The properties input is a complete
`premis_retained` package, including its original native catalogue, selection
plan, local byte comparisons and retained files.

## Inspect the evidence

- `dossier/`, `scripts/` and `properties/` retain complete original packages.
  Optional prefixes are present only for supplied children.
- `evidence/requirement-links.json` contains five fixed supplemental rows with
  exact original assessment references, source occurrences and qualifications.
- `evidence/source-observations.json` retains joined/unjoined source status,
  original anchors, explicit comparison derivations, unavailable script calls
  and one combined positive-observation comparison.
- `definitions/` records the exact local extension and internal adapter
  profiles. Keeping these bytes does not register the profiles.

References commit the original file and locate its original occurrence. Typed
properties decoded from a retained record identify the original hex payload and
the decoding step; they are not presented as direct JSON pointers into hex text.
Distinct records and objects remain distinct even when their bytes are equal.

## Interpret the limits

Media slot occupancy, recorded `PRESENT`/`WAIVED`/`ABSENT` status, historical
selection and current eligibility answer different questions. A zero occupied
mask has its original narrow meaning. URI declarations do not prove byte
availability or archive delivery.

Prospective captures describe pre-sale named simulations. Their original script,
HTML, environment and execution declarations retain their source scope. They
do not establish post-mint render execution, browser performance or a complete
authoritative render inventory. Capture PNG hashes remain declarations; these
links do not claim receipt of the PNG bytes. Native policy/finality and retrieval evidence
remain retained in the dossier where supplied; this version does not create
additional render links for those distinct profiles.

Typed significant properties are selected original preservation-object
declarations. An empty property array means that declaration lists no
properties. An empty selection does not establish that no applicable properties
exist. Missing or mismatched local files retain their diagnostics and do not
erase the original declarations. A conservation significant-properties reference
does not authenticate or interpret the document at its URI.

Collection or media scope does not confer token authority. Different source
states remain unjoined; contradictory positive observations at the same block
fail. Unavailable script calls preserve their original sanitized outcome and
index. No missing package, byte payload or call becomes evidence of absence.

The tool does not execute scripts, fetch URIs, authenticate opaque runtime
bridges or provider origin, prove consensus, establish current authority,
complete the dossier or confer institutional acceptance. Previously published
script-links V1 packages keep their existing profile and verification route.

## Focused validation

```powershell
python -m unittest tools.museum.test_canonical_evidence_observations_v2 tools.museum.test_canonical_evidence_occurrences_v2 tools.museum.test_canonical_dossier_evidence_links_v2 -v
```

Synthetic fixture replay tests software reconstruction and stated source
boundaries. Native runtime and deployed-chain acceptance remain separate.
