# General and V4 authoring histories

This portable offline workflow binds a later-documentation history to one
exact token-scoped original in a verified
[General semantic dossier](museum-general-semantic-v1.md) or
[canonical dossier V4](museum-unified-dossier-v4.md). It supports plain-language
capture, revision, source-text confirmation, review and reopening.

Every retained draft uses the unchanged V1 authoring schema with
`purpose: later_documentation` and `recordBinding: null`. The package holds
the immutable native binding separately. The existing
[portable authoring workflow](museum-source-bound-authoring.md) and
[NativeAttribution single-draft envelope](museum-native-authoring-binding.md)
retain their own source scopes and profiles.

## Prepare an exact source plan

The canonical JSON plan has these closed fields:

| Field | Value |
| --- | --- |
| `version` | `"2"` |
| `kind` | `"general_semantic_dossier"` or `"canonical_object_dossier_v4"` |
| `manifestHash` | External commitment to the original source manifest |
| `occurrenceId` | `null` for General; the exact derived source-field inventory occurrence ID for V4 |
| `selector` | Exact complete original whole-record selector |
| `tokenId` | Canonical positive unsigned 256-bit integer string |

For General, copy the supported statement's `source` selector from
`semantics/snapshot.json`; its `pointer` must be empty. For V4, use the
occurrence ID and selector from the complete
[source-field inventory](museum-field-correspondence.md). This is the derived
inventory ID, not a title, entity IRI or the older canonical row ID.

Admission replays the concrete original package and checks the native token
subject against chain, Core and token ID. The draft's `workId` must equal that
canonical token citation. Collection remains original context; it is not part
of the token subject digest. This correspondence does not prove minting or
token existence.

Only supported, interpreted token originals qualify. Collection/media records,
opaque or schema-shape-only originals, documentary metadata and conservation
rows cannot become bindings through this adapter. Historical, unselected,
disputed or withdrawn evidence retains its original qualification; selecting
it for documentation does not endorse it or restore authority.

## Capture, bind and reopen

Use the same plain-language form as the
[portable authoring workflow](museum-source-bound-authoring.md), with a token
root and the exact work citation. Use the
[Museum Python environment](../tools/museum/README.md):

```powershell
python -m tools.museum.semantic_authoring_history_v2 capture --form <form.json> --form-hash <form-hash> --source <source-package> --source-hash <source-manifest-hash> --plan <plan.json> --plan-hash <plan-hash> --disclosure public --output <history-directory>
python -m tools.museum.semantic_authoring_history_v2 bind --draft <revision-one.json> --source <source-package> --source-hash <source-manifest-hash> --plan <plan.json> --plan-hash <plan-hash> --disclosure public --output <history-directory>
python -m tools.museum.semantic_authoring_history_v2 verify <history-directory> --manifest-hash <history-manifest-hash>
python -m tools.museum.package_v2 verify <history-directory> --manifest-hash <history-manifest-hash>
```

Choose `capture` to retain the original form and verify that it reproduces
revision one exactly. Choose `bind` for an existing revision-one draft.
Outputs must be new, outside the inputs, with an existing parent. Public
disclosure is checked before reads; the workflow supplies no redaction policy.

## Append revisions, confirmations and reviews

```powershell
python -m tools.museum.semantic_authoring_history_v2 revise --package <history-directory> --package-hash <history-hash> --draft <next-draft.json> --disclosure public --output <next-history-directory>
python -m tools.museum.semantic_authoring_history_v2 confirm --package <history-directory> --package-hash <history-hash> --version-id <source-version-id> --confirmed-by <source-author-id> --confirmed-at <timestamp> --revised-at <timestamp> --disclosure public --output <next-history-directory>
python -m tools.museum.semantic_authoring_history_v2 review --package <history-directory> --package-hash <history-hash> --review <review.json> --review-hash <review-hash> --revised-at <timestamp> --disclosure public --output <next-history-directory>
```

Each revision retains all preceding draft bytes. Up to 32 contiguous revisions
are supported, beginning at one and linked by exact previous-draft hashes.
The source package, source plan, work citation, draft identity, source author
and creation time remain fixed. Confirmed source versions and completed review
snapshots cannot be changed or removed. Stable relationship, date, measurement,
attachment and authority-decision identities cannot be retargeted.

Confirmation covers the exact source-version text. It does not authenticate
the declared source author or confirm a mapper's interpretation. Reviews keep
their original target snapshots and hashes. A later permitted edit makes the
old review historical when its target no longer matches; it does not silently
approve the edited target.

## Retained package

| Path | Contents |
| --- | --- |
| `source/` | Complete original source, including its retained validation dependencies |
| `inputs/source-plan.json` | Exact externally pinned selection plan |
| `inputs/capture-form.json` | Optional original form, carried unchanged through history |
| `drafts/revision-NNNN.json` | Exact original bytes of every draft |
| `previews/revision-NNNN.json` | Source versions, counts and current/historical review dispositions |
| `authoring/revision-index.json` | Ordered contiguous history and draft commitments |
| `authoring/source-binding.json` | Separate exact source evidence, subject and qualifications |
| `definitions/` | Unchanged draft schema and additive local profiles |

Reopening replays the original source, checks every transition and rebuilds the
whole package using retained evidence. Rehashing an edited binding, preview or
history does not bypass those checks. Source receipts do not authenticate draft
actors or grant publication permission. These tools neither publish records
nor establish current ownership, legal title, finality or institutional
acceptance.

## Focused validation

```powershell
python -m unittest tools.museum.test_semantic_authoring_current_sources_v2 tools.museum.test_semantic_authoring_history_v2 -v
```
