# Native Linked Art, PREMIS, IIIF and LIDO exports

This portable offline package runs four native adapters over one verified
[canonical dossier V4](museum-unified-dossier-v4.md). It retains the complete
original source, inventories its fields before selection, and resolves actual
output values back to exact native fields. It also compares representations
when two or more formats map the same original field.

## Supported source and format scope

| Format | Native source scope | Meaning of the output |
| --- | --- | --- |
| Linked Art | Interpreted WORK, condition, ten typed Owner families, and supported General/Artist statements | Model-validated and expanded record statements and payload carriers; exact declared string values with field attribution |
| PREMIS | Retained original payload bytes, including opaque payloads where available; complete retained conservation Reference material | File objects with explicit byte roles, measured retained-byte size/digests and supported original schema, format, digest and locator declarations |
| IIIF | Interpreted full WORK descriptions | Manifest title, medium summary and credit statement; an empty-painting Canvas when explicit WORK extents can be represented exactly |
| LIDO | Interpreted native WORK | Original WORK declarations and separately attributed export metadata, through the existing [native LIDO adapter](museum-native-work-lido.md) |

Linked Art Names represent declared WORK titles inside attributed record
statements. Owner, General and Artist declarations retain their original
authority and source context. The exporter does not turn named parties into
authenticated people or institutions, or declared activities into performed
events. Unsupported and residual fields remain in the original inventory.

PREMIS distinguishes a source-record payload from conservation material and
from artwork media. A digest computed over retained bytes describes those
specific bytes. It does not establish a historical fixity event or retrieval
from an original URI. Conservation material requires complete retained Archive
correspondence; missing material remains a diagnostic. No file object is
created merely because a public reference names it. No agent, rights or
preservation-event assertion is invented.

IIIF uses exact explicit pixel dimensions and representable duration values.
A rational duration is converted only when it has a finite exact decimal
representation. The exporter does not round it. Canvas painting lists stay
empty: collection media, VIEW or prospective-render evidence does not by itself
prove a paintable relationship to this token's WORK. A WORK with no usable
extent produces a Manifest with an empty item list. Source render/media scope
remains visible in the IIIF report.

## Prepare the four plans

The canonical JSON export plan has exactly these fields:

```json
{
  "version": "1",
  "sourceManifestHash": "<original V4 manifest hash>",
  "adapters": {
    "linked-art": {},
    "premis": {},
    "iiif": {},
    "lido": {}
  }
}
```

Replace each empty object with that adapter's complete plan. All four must
name the same original V4 manifest hash. Each uses `version: "1"`, its `kind`,
`sourceManifestHash` and an ordered `selected` array, with at most 64 entries.
An empty selection is allowed; it does not remove original fields from coverage.

| Adapter | `kind` | Selection entry |
| --- | --- | --- |
| Linked Art | `native_linked_art` | Exact derived field-inventory `occurrenceId` and complete `selector` |
| PREMIS | `native_premis` | Exact derived field-inventory `occurrenceId` and complete `selector` |
| IIIF | `native_iiif` | Exact derived field-inventory `occurrenceId`, complete `selector` and explicit export `context` |
| LIDO | `native_work_lido` | Original canonical `occurrenceId`, complete WORK `selector` and explicit export `context` |

The first three use IDs from the complete
[source-field inventory](museum-field-correspondence.md). The existing LIDO
profile uses IDs from the original `canonical/inputs/source-inventory.json`.
The wrapper resolves that original ID to its exact derived occurrence for
comparison. Neither an equal title nor a shared entity URI is a join key.

IIIF export context contains `manifestId`, nullable `manifestRights`,
`attributionLabel`, `canvasLabel` and `declaredBy`. The Manifest
ID and labels are operator declarations, and the rights identifier applies to
the exported Manifest only. Supply explicit values under the pinned plan
schema; the tool does not infer them from the native recorder. A null rights
value omits the property. Text uses an unspecified language with exact plain
text escaping; no language is invented for the original statement. LIDO's context
uses its [existing explicit context schema](museum-native-work-lido.md).
Exact schemas and profile commitments are retained in every output package.
The additive IIIF target schema allows empty Manifest/Canvas item lists and
optional rights, preserving the earlier painting-specific profile unchanged.

## Assemble and reopen

Use the [Museum Python environment](../tools/museum/README.md):

```powershell
python -m tools.museum.native_multiformat_package_v1 assemble --source <v4-directory> --source-hash <v4-manifest-hash> --plan <export-plan.json> --plan-hash <export-plan-hash> --disclosure public --output <new-directory>
python -m tools.museum.native_multiformat_package_v1 verify <new-directory> --manifest-hash <export-manifest-hash>
python -m tools.museum.package_v2 verify <new-directory> --manifest-hash <export-manifest-hash>
python -m tools.museum.native_multiformat_package_v1 profiles
```

Public disclosure is checked before input reads. Output must be new, outside
the inputs, with an existing parent. No URI or live context is fetched.
Reopening uses retained validation dependencies, replays V4, rebuilds every
adapter and comparison, and checks every byte. Rehashing an altered ledger,
source plan or output does not bypass reconstruction.

## Inspect field and family coverage

| Path | Contents |
| --- | --- |
| `source/` | Complete unchanged original V4 |
| `inputs/export-plan.json` | Exact externally pinned four-adapter plan |
| `inputs/linked-art-plan.json`, `inputs/premis-plan.json`, `inputs/iiif-plan.json` | Exact canonical subplans |
| `inputs/plan.json` | LIDO subplan at its original profile's immutable reference path |
| `linked-art/`, `premis/`, `iiif/`, `lido/` | Actual outputs, format-local provenance, inventories, coverage and scope reports |
| `conformance/source-field-inventory.json` | Complete original semantic field denominator |
| `conformance/native-format-field-ledger.json` | Each original field's disposition and actual target evidence in all four formats |
| `conformance/same-field-comparisons.json` | Actual representations of fields mapped in two or more formats |
| `conformance/source-family-coverage.json` | Original occurrence/field counts and mapped counts by family and format |
| `dependencies/`, `definitions/` | Exact retained validation closure and local profiles |

`mapped` requires exact original occurrence, domain, field pointer and value
bytes, plus a resolved target scalar and its transformation rule.
`retained_stream_only` preserves fields without that mapping. Applicable
optional fields that are absent are `not_applicable`. Missing adapters or
public evidence are not withheld-by-policy cases.

Operator context, generated identifiers and computed retained-byte measurements
have separate provenance domains and do not inflate native mapped-field counts.
Comparisons report equal or different target representations and retain their
rules. Different values are never rewritten to force agreement. Numeric and
string representations remain distinct, and exact numeric lexicals avoid
floating-point rounding. Equality proves neither source truth nor complete
semantic equivalence.

## Remaining acceptance and software work

These are finite native adapters, not complete mappings of every family and
field into every format. Native artwork-media painting joins, broader PREMIS
events/agents/rights, richer semantic relationships, other-family LIDO mappings
and their exact evidence remain work. Coverage reports expose those limits.

The original nineteen packet groups and forty-nine assessments are unchanged.
Offline tests using synthetic wire fixtures are software evidence. Family
tests using verified conservation packages retain that narrower scope; they
do not establish a combined live V4 capture. Institutional repository ingest,
practitioner review, live-source acceptance and the full
[semantic specification](museum-semantic-mapping.md) gates remain separate.

## Focused validation

```powershell
python -m unittest tools.museum.test_native_linked_art_v1 tools.museum.test_native_premis_v1 tools.museum.test_native_iiif_v1 tools.museum.test_native_multiformat_ledger_v1 tools.museum.test_native_multiformat_package_v1 -v
```
