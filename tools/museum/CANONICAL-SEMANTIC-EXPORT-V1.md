# Native semantic export

This export interprets native WORK, original owner ACCESSION/DEACCESSION and
condition statements from an exact [canonical object dossier V3](CANONICAL-COMPOSITION-V10.md).
It derives a complete inventory of those retained source families before
applying a selection policy. Selected statements expand into validated Linked
Art resources; every original occurrence remains in the attributed sidecars
and coverage report.

This version maps attributed documentary statements and their payload carriers.
The statement carries its exact interpreted JSON content. Family-specific fields
remain in typed sidecars; it does not claim a complete field-by-field museum
crosswalk or create unconditional work, person, activity or legal-title facts.

## Source and authority

The public entrypoint replays the original V3 package, including its V10 packet
and optional conservation V2 family. It does not admit caller-authored inventory
or report flags as native evidence. Source pointers include their original
package path, byte hash, JSON pointer and encoding.

WORK revision selection, explicit original accession selection and
receipt-ordered condition selection retain their separate meanings. The raw
WORK selected head does not prove current authority eligibility. Unsupported
or malformed unselected payloads remain opaque, with their exact original
bytes. An unresolved selected condition does not make an earlier statement
current. A missing condition source remains missing.

An owner statement does not become an Artist or institution assertion. Named
parties, title instruments and examination results retain their original
attribution. Conflicting titles and creators remain alternatives. Matching
names do not merge work, token, statement or payload identities. Source-local
coverage does not establish a global host or record inventory.

The optional conservation graph stays under its original package path and is
referenced as a separately verified family. Its Artist and estate authorities,
source qualifications, field inventory and model validation remain intact.

## Prepare, build and verify

Use the existing Museum Python environment. Output directories must be new,
with existing parents. The source and export must be explicitly classified as
public; this profile does not implement a restricted-source or redacted export.

First derive a default selection from the replayed source:

```powershell
python -m tools.museum.canonical_semantic_export_v1 prepare-selection `
  --dossier DOSSIER --dossier-hash DOSSIER_HASH `
  --disclosure public --output POLICY
```

The command writes `POLICY/selection.json` and prints its Keccak commitment.
The policy binds the original dossier, source state and complete occurrence
inventory. Review that exact policy before use. An explicit historical selection
must retain each source's currentness and attribution; it cannot relabel an old
statement as current or shrink the inventory denominator.
WORK records outside the dossier's exact collection and token subject IDs remain
in the inventory as `other_subject` and cannot be selected. An unfamiliar subject
hash does not establish which token or other subject it names.

```powershell
python -m tools.museum.canonical_semantic_export_v1 build `
  --dossier DOSSIER --dossier-hash DOSSIER_HASH `
  --selection POLICY/selection.json --selection-hash SELECTION_HASH `
  --disclosure public --output EXPORT
python -m tools.museum.canonical_semantic_export_v1 verify EXPORT `
  --manifest-hash EXPORT_HASH
```

Verification uses the retained model closure, replays the original source,
reconstructs the full inventory and repeats selection and JSON-LD expansion.
It compares every output byte. Rehashing a changed source pointer, reduced
coverage report, substituted model or invented authority does not bypass that
reconstruction. No URI is fetched and no retained tool source is executed.

The Python API is:

```python
selection = prepare_selection(dossier_files, dossier_hash, disclosure="public")
result = build(dossier_files, dossier_hash, selection, keccak256(selection),
               disclosure="public")
checked = verify(dict(result.files), result.manifest_hash)
```

Import `prepare_selection`, `build` and `verify` from
`tools.museum.canonical_semantic_export_v1`, and `keccak256` from
`tools.museum.canonical`.

## Outputs and commitments

- `input/` retains every original V3 package member without modification.
- `inputs/` retains the full derived source inventory and exact selection.
- `semantic/` contains resource and expanded-resource files, attribution,
  alternatives, field coverage, source state, provenance and validation reports.
- `semantic/source-locations.json` resolves inventory and provenance source paths
  relative to `input/`, with the hash of every original source file.
- `dependencies/` retains the pinned offline Linked Art model and vocabulary
  closure. `semantic/dependency-lock.json` commits to those exact bytes.
- `semantic/export-manifest.json` commits to semantic children and the earlier
  source dossier. The outer `manifest.json` commits to the complete package.

Children never commit to their enclosing export or package manifest. Later
publication records are not part of the source being exported. This preserves
an acyclic commitment structure.

All 49 original dossier requirements and their assessments survive unchanged.
This new source-family export does not register a profile, authenticate RPC
origin or consensus, prove legal title, preserve a runnable tool archive,
complete all canonical dossier obligations or perform institutional acceptance.
