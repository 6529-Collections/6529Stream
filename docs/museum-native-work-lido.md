# Native WORK to LIDO

This offline exporter maps selected native WORK statements from a verified
[canonical dossier V4](museum-unified-dossier-v4.md) into LIDO 1.1 XML. It
validates the XML against the retained, pinned LIDO schema and records the
exact original field and output XPath for each mapped value.

All WORK occurrences remain inventoried before export selection, including
opaque and unselected records. The portable package also retains the complete
[native source-field inventory](museum-field-correspondence.md), covering the
other source families in the original V4 package. Those families have no LIDO
mapping through this profile. Linked Art, PREMIS and IIIF are explicitly
unevaluated here; this is not a four-format comparison.

## Select exact original records

Supply a canonical JSON plan with these closed fields:

| Field | Value |
| --- | --- |
| `version` | `"1"` |
| `kind` | `"native_work_lido"` |
| `sourceManifestHash` | External commitment to the original V4 manifest |
| `selected` | Ordered array of up to 64 selections; an empty array is allowed |

Each selection has `occurrenceId`, `selector` and `context`. Copy both the
occurrence ID and the complete `native_metadata_work` selector from the same
WORK row in the original `canonical/inputs/source-inventory.json`. This is the
original canonical occurrence ID, not the separately qualified ID in the
derived source-field inventory. Opaque records cannot be selected for XML.

LIDO requires some export metadata that WORK does not supply. Each context
statement has a `declaredBy` URI identifying its declaring operator:

| Context statement | Required fields and use |
| --- | --- |
| `documentLanguage` | `value`, `declaredBy`; export document language |
| `objectWorkType` | `value`, `language`, `declaredBy`; operator classification |
| `exportPublisher` | `id`, `name`, `language`, `declaredBy`; export publisher |
| `artistName` | Required only for `creator.kind: artist`; `value`, `language`, `declaredBy`, exact original `artistId` and `association` |
| `workLabel` | Required only for `form: description_absent`; `value`, `language`, `declaredBy` |

The `association` contains the original `bindingHash` and `bindingGeneration`.
Unused artist names or work labels are rejected. Operator statements are
unsigned declarations, separately attributed in provenance. They do not count
as mapped native source fields or establish institutional authority.

## Assemble and reopen

Use the [Museum Python environment](../tools/museum/README.md):

```powershell
python -m tools.museum.native_work_lido_package_v1 assemble --source <v4-directory> --source-hash <v4-manifest-hash> --plan <plan.json> --plan-hash <plan-hash> --disclosure public --output <new-directory>
python -m tools.museum.native_work_lido_package_v1 verify <new-directory> --manifest-hash <export-manifest-hash>
python -m tools.museum.package_v2 verify <new-directory> --manifest-hash <export-manifest-hash>
```

The output must be new and outside the inputs, with an existing parent. Public
disclosure is required before input reads; there is no automatic redaction.
Verification replays the original V4 package, uses the retained validation
dependencies, rebuilds every artifact and compares every byte. Changing XML,
provenance or a ledger and rehashing the outer manifest cannot bypass replay.

## Inspect the result

| Path | Contents |
| --- | --- |
| `source/` | Complete original V4 package, unchanged |
| `inputs/plan.json` | Exact externally pinned operator plan |
| `lido/records/<occurrence-id>.xml` | One validated XML record per selected original occurrence |
| `lido/inventory.json` | All original WORK occurrences, authority/currentness and both canonical and export selection |
| `lido/provenance.json` | Exact original or operator field references, values and resolved output XPaths |
| `lido/coverage.json` | WORK, catalog and operator field dispositions |
| `conformance/source-field-inventory.json` | Complete original V4 semantic field denominator |
| `conformance/native-format-field-ledger.json` | Actual LIDO evidence per original field; explicit scope for other formats |
| `dependencies/`, `definitions/` | Retained validation closure and prospective local profiles |

The export-record identifier, native subject identifier and native record
identifier retain distinct roles. Equal titles or descriptions do not merge
different occurrences. Titles, creator credits, dates, media descriptions and
dimensions remain qualified source statements. A credit line does not become
a license; a format description does not establish detected MIME, media
availability or fixity. An absent description gains no invented creator.

The original nineteen packet groups and forty-nine assessments remain
unchanged. Successful export is software validation, not institutional ingest,
creator authentication, current authority, live capture or acceptance of the
full [semantic mapping specification](museum-semantic-mapping.md).

## Focused validation

```powershell
python -m unittest tools.museum.test_native_work_lido_v1 tools.museum.test_native_work_lido_package_v1 -v
```
