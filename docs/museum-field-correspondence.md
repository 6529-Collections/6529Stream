# Museum source-field and format correspondence

This offline package retains one complete original source package and rebuilds
its field inventory. It keeps selection separate from the inventory, so an
unselected or conflicting public record still contributes to the denominator.

Two source routes have distinct scopes:

| Route | Source | Output |
| --- | --- | --- |
| `canonical_v4` | A verified [canonical dossier V4](museum-unified-dossier-v4.md) | Original native semantic occurrences, exact values and applicable schema fields, including structural and absent fields |
| `account_formats_v2` | A verified synthetic or recorded-account [multiformat package](museum-multiformat-package.md) | Original assertion fields and format-local Linked Art, PREMIS, IIIF and LIDO correspondence |

The routes do not join different accounts or source packages by artwork title,
entity IRI, chain, Core address or collection. Canonical V4 does not contain
equivalent four-format outputs for every native source. Its format cells report
unsupported adapter applicability and retain the original values. They do not
claim a successful comparison or mark those values semantically irrelevant.

The additive [native WORK-to-LIDO package](museum-native-work-lido.md) now maps
selected original WORK occurrences to actual XML with exact field provenance.
It retains this complete native inventory without changing the frozen
correspondence profile or claiming mappings for other native families/formats.
The [native four-format package](museum-native-multiformat.md) adds bounded
Linked Art, PREMIS and IIIF native adapters, family coverage and same-field
comparisons under a separate profile.

## Assemble and verify

Use the [Museum Python environment](../tools/museum/README.md) and the original
package's separately retained manifest commitment:

```powershell
python -m tools.museum.semantic_field_correspondence_v1 assemble --source <original-package> --source-hash <original-manifest-hash> --source-kind canonical_v4 --disclosure public --output <new-directory>
python -m tools.museum.semantic_field_correspondence_v1 verify <new-directory> --manifest-hash <correspondence-manifest-hash>
python -m tools.museum.package_v2 verify <new-directory> --manifest-hash <correspondence-manifest-hash>
```

Choose `account_formats_v2` for an original account-format package. The source
kind must match its concrete verifier. The output must be a new directory with
an existing parent, outside the input. Public disclosure is checked before
reading source files; this tool supplies no restricted-record redaction flow.

Python callers use `compose(source_files, source_hash, source_kind=...,
disclosure="public")` and `verify(files, manifest_hash)`. Reopening replays the
original source, rebuilds the inventory and comparisons, and compares every
output byte. Rehashing an edited ledger does not bypass reconstruction.

## Inspect the package

| Path | Contents |
| --- | --- |
| `source/` | Complete original package, including its original manifest and retained definitions/dependencies |
| `conformance/source-field-inventory.json` | Original occurrence selectors, exact field values and schema applicability before selection |
| `conformance/format-field-ledger.json` | Per-field format evidence or explicit unsupported/retained status |
| `conformance/shared-identity.json` | Supported format identity relationships with distinct entity roles |
| `conformance/cross-format-comparisons.json` | Exact-source comparisons and unsupported or non-comparable cases |
| `conformance/adapter-report.json` | Concrete adapter scope, counts and limitations |
| `definitions/` | Exact prospective local profile bytes |

Source references inside adapter artifacts include the `source/` prefix and
are relative to the outer package. The outer report commits each artifact. Original selectors
and source paths distinguish repeated identical values and occurrences from
different original packages. Null, absent, empty, repeated and ordered values
remain distinct. Unsupported original schemas retain their payload bytes;
the tool does not invent a schema to make the field count appear complete.

## Read the format evidence

The existing format exporters carry cumulative coverage forward. A PREMIS
coverage row can therefore inherit an earlier Linked Art mapping. This ledger
requires that format's own provenance and resolves its target pointer or XPath
against the actual output bytes. An inherited disposition alone supplies no
format-local evidence.

Comparisons retain exact original record selectors and source fields. Target
identities retain their roles: a work, token, file, content URI, Canvas and
Manifest are not interchangeable identifiers. Unsupported date, rights or
media mappings remain explicit. Different target representations are reported
with their transformations and qualifications; authoritative source values
are not rewritten to force agreement.

`mapped` means the particular field has supported local target evidence.
`retained_stream_only` means its original bytes remain available without that
mapping. `not_applicable` is used for applicable optional schema fields that are
absent. Missing public evidence and missing adapters are not policy exclusions;
this public profile does not emit `withheld_by_source_policy`.

## Scope and acceptance

Canonical native inventories include the source families actually retained by
the admitted V4 package. They do not assert that all possible records have been
captured. Qualified owner or account declarations remain declarations, and
opaque records do not acquire an invented interpretation.

Synthetic account-format positives remain synthetic. Recorded packages retain
their original captured mode and unsupported outputs, including absent LIDO
when the original selected evidence cannot produce it. Original canonical
nineteen packet groups and forty-nine requirement decisions remain unchanged.

This package makes field omissions and format scope inspectable. It does not
close full Museum mapping, provider-origin authentication, current authority,
institutional reconstruction or repository/practitioner acceptance. Those
remain subject to the [adopted semantic specification](museum-semantic-mapping.md).

## Focused validation

```powershell
python -m unittest tools.museum.test_canonical_field_inventory_v1 tools.museum.test_same_source_format_ledger_v1 tools.museum.test_semantic_field_correspondence_v1 -v
```
