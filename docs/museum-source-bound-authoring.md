# Portable Museum authoring workflow

Capture plain-language source text, review structured enrichment and reopen later
documentation with its original evidence. The output is always `draft_preview`.
It is neither a published record nor a conformant Museum dossier.

The workflow reuses the unchanged [authoring draft schema](museum-semantic-authoring.md)
and existing source verifiers. It retains every revision, each preview and the
complete supplied source. Reopening a package replays those sources and validates
every revision transition before reconstructing all output bytes.

## Capture without ontology terms

The capture form asks for original text, title, creator credit, medium description,
place name and an account of events. Original text and title are required. The
other four fields may be `null` when not supplied; that does not assert absence.
Text is preserved exactly, including language, whitespace and Unicode spelling.
No Getty match, person identity, event, rights, medium classification or semantic
relationship is inferred from the prose.

An application supplies durable IDs and a timestamp explicitly. The tool generates
neither random identities nor export-time timestamps. The closed canonical JSON
form has these fields:

| Field | Value |
| --- | --- |
| `version` | `"1"` |
| `purpose` | `initial_submission` or `later_documentation` |
| `draftId`, `workId` | Explicit durable IRIs |
| `rootKind` | `abstract_work` for an initial submission; `token` for later documentation |
| `sourceAuthor` | Original draft actor: `entityId`, `kind` (`person` or `group`), language-tagged `names` |
| `sourceVersionIds` | One explicit ID for each supplied prose field; `null` for a field not supplied |
| `timestamp`, `language` | Explicit date-time and language tag |
| `originalText`, `title` | Exact nonempty source strings |
| `creatorCredit`, `mediumDescription`, `placeName`, `eventAccount` | Exact nonempty strings or `null` |

All six prose keys and all six corresponding ID keys are present. Supplied
strings become separate unconfirmed source versions. The title also becomes the
root's preferred draft name. Other fields remain source text for a mapper to
interpret explicitly. The source author is the initial declared mapper, with no
structured mapping yet. These actor declarations do not authenticate people.

Use the [Museum Python environment](../tools/museum/README.md):

```powershell
python -m tools.museum.semantic_authoring_package_v1 capture --form form.json --form-hash <form-keccak256> --disclosure public --output draft-v1
python -m tools.museum.semantic_authoring_package_v1 preview draft-v1 --manifest-hash <package-hash>
```

Existing complete V1 drafts may instead use `assemble --draft draft.json` with
the same disclosure and output arguments. This does not reinterpret their fields.

## Confirm text and review enrichment

Confirmation creates a new revision and covers exactly one original source
version. It does not approve other prose fields, mapped relationships or later
enrichment, and it is not an onchain signature.

```powershell
python -m tools.museum.semantic_authoring_package_v1 confirm --package draft-v1 --package-hash <hash> --version-id <source-version-id> --confirmed-by <source-author-id> --confirmed-at <date-time> --revised-at <date-time> --disclosure public --output draft-v2
```

Structured enrichment uses the existing draft fields for relationships, dates,
measurements, attachment descriptions and no-match authority decisions. Each
mapping names its source version and mapper. To append an edited draft, increment
its `revision`, set `previousRevisionHash` to the preceding exact draft's Keccak
hash and supply a nondecreasing `revisedAt`:

```powershell
python -m tools.museum.semantic_authoring_package_v1 revise --package draft-v2 --package-hash <hash> --draft enriched.json --disclosure public --output draft-v3
```

The `review` command accepts a canonical JSON request containing exactly
`reviewId`, `reviewer` (an actor declaration), `targetKind`, `targetId`, `status`,
`reviewedAt` and `rationale`. Target kinds are `relationship`, `date`,
`measurement` and `authority_decision`; status is explicitly `accepted` or
`changes_requested`. The tool snapshots and hashes that exact current target.

```powershell
python -m tools.museum.semantic_authoring_package_v1 review --package draft-v3 --package-hash <hash> --review review.json --review-hash <review-keccak256> --revised-at <date-time> --disclosure public --output draft-v4
```

The review records the declared reviewer; it does not authenticate them. Later
edits leave earlier reviews intact and label them `historical_target` when their
target changes. Confirmed source versions, prior reviews, stable entity/item IDs
and the recorded binding cannot be rewritten by a later revision.

## Bind later documentation to original evidence

Later documentation starts with the explicit canonical token citation
`eip155:<chainId>/erc721:<lowercase-core>/<tokenId>` and a token root. A title,
artist handle, matching name or serialized binding alone is insufficient.

Supply a source directory and an externally pinned canonical source plan. There
are two exact routes:

| Plan kind | Original source and plan fields |
| --- | --- |
| `owner_record_source` | Directory contains exactly `anchor.json`, `transcript.json`, `snapshot.json`. Plan: `version: "1"`, `kind`, `provenance: "trusted_rpc"`, `anchorHash`, `transcriptHash`, `snapshotHash`. |
| `recorded_account_package` | Complete original recorded-account V2 package, including its manifest, definitions and dependencies. Plan: `version: "1"`, `kind`, `manifestHash`, `sourceStateHash`. |

The owner route reconstructs `OwnerRecordSource` and requires byte-identical
snapshot output. It covers selected historical receipts, not a whole catalogue
or current ownership. `trusted_rpc` is an external admission of the observations;
it does not prove provider origin or consensus. A synthetic-mode snapshot cannot
be relabeled by this adapter.

The recorded route first verifies the complete recorded-account package, then
reconstructs `RecordedSemanticSource` from its retained dependencies and original
inputs. The original environment and registered interpretation evidence remain
intact. A local-EVM fixture is not promoted to public-chain acceptance.

The selection file is canonical JSON: an exact record-hash string for OwnerRecords
or the whole original recorded-account selector with `pointer: ""`. Supply its
external Keccak hash. Collection and media subjects cannot become token bindings.

```powershell
python -m tools.museum.semantic_authoring_package_v1 bind --draft later-draft.json --source source-directory --source-plan source-plan.json --source-plan-hash <plan-hash> --selection selection.json --selection-hash <selection-hash> --disclosure public --output later-v1
```

The same source and selection options work with `capture` for a later-documentation
form. Subsequent `revise`, `confirm` and `review` commands use the exact source
retained inside the preceding package; they cannot swap its binding.

## Verify and inspect

```powershell
python -m tools.museum.semantic_authoring_package_v1 verify later-v1 --manifest-hash <hash>
python -m tools.museum.package_v2 verify later-v1 --manifest-hash <hash>
```

- `drafts/revision-NNNN.json` and `previews/revision-NNNN.json` retain each revision.
- `authoring/revision-index.json` commits their order and exact bytes.
- `authoring/source-binding.json` reports the original binding and source limits.
- `source/` retains the complete original evidence; `inputs/source-plan.json`
  retains its pinned plan. These paths are absent for an initial submission.
- `inputs/capture-form.json`, when present, preserves the exact original form.
- `definitions/` retains the unchanged draft schema and local workflow profiles.

Creation requires public disclosure before input reads. Every output is a new
directory outside its inputs, with an existing parent; publication stages and
reads back the exact files before renaming. At most 32 revisions are retained,
each within the existing 512-KiB draft limit. The source adapter and enclosing
package also enforce their declared file and aggregate byte limits. Rehashing a
changed preview, schema or source report cannot bypass full reconstruction.

Python callers use `start`, `compose`, `revise` and `verify` from
`semantic_authoring_package_v1`. `start` accepts an explicit `selection` plus
`source_files`, `source_plan_raw` and `source_plan_hash` for a later draft.
`compose` accepts the complete ordered revision list. All creation calls require
`disclosure="public"`.

## Remaining acceptance

These local workflow profiles and the authoring draft schema are prospective;
retaining a registered source schema does not register an authoring package.
Current NativeAttribution, General and canonical V4 packages are not cast into
the two supported binding types. Their additional adapters remain separate work.

Complete source-family mapping and same-original cross-format correspondence
remain open. This workflow does not create genuine OwnerRecords publication/RPC
capture evidence, publish an `ARCHIVE_SEMANTIC_EXPORT`, activate registry documents
or establish repository ingest/practitioner acceptance. Existing archive-export
tools retain their original typed-account scope; drafts are not substituted for
their required records. No mint, signing, transaction or media-ingest operation
is performed.
