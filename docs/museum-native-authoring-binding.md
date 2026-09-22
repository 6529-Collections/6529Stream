# Native token authoring binding

This additive offline envelope links an unchanged later-documentation draft
to one exact token-scoped statement in a verified
[NativeAttribution dossier](museum-native-attribution.md). It retains the
complete original dossier and an externally pinned selection plan.

The draft keeps `recordBinding: null`. The new envelope carries the native
source binding separately; it does not extend the frozen V1 draft binding
union or make that draft independently valid through the old source validator.
The [portable authoring workflow](museum-source-bound-authoring.md) continues
to handle its existing recorded-account and OwnerRecords sources.

## Prepare the inputs

Use the same plain-language capture form and draft schema as the portable
workflow. For this adapter the draft has `purpose: later_documentation`, a
token root, and the exact canonical token citation as its `workId`.

The canonical JSON selection plan has these fields:

| Field | Required value |
| --- | --- |
| `version` | `"1"` |
| `kind` | `"native_attribution_dossier"` |
| `manifestHash` | The original attribution dossier's external manifest commitment |
| `semanticSourceSelector` | The exact complete original semantic record selector |
| `tokenId` | The canonical nonzero unsigned 256-bit token ID string |

Copy the selector from the retained semantic source occurrence. A title,
artist handle, entity IRI or address match is insufficient. The adapter
recomputes the token subject from its chain, Core and token ID, then checks
the exact original selector and draft citation. The source's collection
context remains separate evidence. This proves
correspondence to that declared subject; it does not prove that the token
exists or has been minted.

Collection-scoped and media-scoped statements cannot become token bindings
through this profile. Unsupported statements and changed payloads, receipts,
signatures or selectors fail concrete source admission.

## Bind and reopen

Use the [Museum Python environment](../tools/museum/README.md):

```powershell
python -m tools.museum.semantic_authoring_native_sources_v1 bind --draft <draft.json> --source <attribution-dossier> --source-manifest-hash <source-hash> --plan <plan.json> --plan-hash <plan-hash> --disclosure public --output <new-directory>
python -m tools.museum.semantic_authoring_native_sources_v1 verify <new-directory> --manifest-hash <envelope-package-hash>
python -m tools.museum.package_v2 verify <new-directory> --manifest-hash <envelope-package-hash>
```

The output must be new and outside the source. Public disclosure is checked
before reading input files. The package retains:

- `input/draft.json`: the exact original draft bytes.
- `input/source-plan.json`: the exact externally pinned plan.
- `authoring/native-binding-envelope.json`: draft and source commitments,
  original subject/record/receipt/signature correspondence and qualifications.
- `source/`: the complete original attribution dossier.
- `dependencies/`: the pinned local validation documents needed to replay it
  after moving the package away from the repository.
- `definitions/`, `report.json` and `manifest.json`: prospective local
  definitions, scope and file commitments.

Verification uses the retained dependency closure to replay the original
dossier and reconstruct the binding and entire package. Rehashing a changed
envelope does not make it valid.

## Meaning and limits

Historical publication authority and current qualification remain their
original, separate evidence. A disputed statement or a changed current Artist
identity does not become fresh authority. The draft's named source author is
not authenticated merely because the source package contains Artist history.
Source-version confirmation still concerns only the exact text confirmed.

This first native envelope binds one draft snapshot. It does not provide a
native revision-history workflow, authorize publication, sign or publish a
record, authenticate RPC origin, prove consensus/finality, or establish
institutional acceptance. General and canonical V4 authoring routes remain
separate future adapters.

## Focused validation

```powershell
python -m unittest tools.museum.test_semantic_authoring_native_sources_v1 -v
```
