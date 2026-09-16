# Museum semantic authoring drafts

Status: bounded offline implementation guide

`tools/museum/semantic_authoring.py` implements the application boundary in
`[MSM-AUTHORING]` without publishing a Stream record. It provides one closed,
bounded canonical JSON shape for initial submissions and later documentation,
plus revision and preview functions. The output mode is always
`draft_preview`.

This module is an intake boundary. It does not mint an entity ID, sign a
statement, upload a file, scan an attachment, execute a transaction, or claim
that a draft is a recorded Stream dossier.

## Stable identities and exact source versions

The caller assigns `draftId`, `workId`, every actor and entity IRI, every source
version IRI, and every relationship, date, measurement, attachment, decision,
and review IRI. Absolute IRIs are required. A caller may use a durable external
IRI or a once-assigned canonical lowercase `urn:uuid:` IRI. The tool never
generates an exporter-run identifier.

`sourceAuthor`, `mappers`, and `reviewers` are separate attribution roles. The
same person may fill more than one role, including author-confirmed mapping, but
the complete actor declaration for a reused IRI must be byte-for-byte the same.
Conflicting person/group or name declarations reject. A mapping or review is
therefore still separately attributed and cannot silently become part of the
source author's confirmed wording. The source author's exact `originalText`
and language tag are stored in a `sourceVersions` entry. No trimming, Unicode
normalization, line-ending conversion, translation, or summary replaces that
text.

For a confirmed source version, calculate:

```python
from tools.museum.semantic_authoring import source_version_hash

version["versionHash"] = source_version_hash(version)
```

The hash commits to exactly `versionId`, `authorId`, `originalText`, and
`language` in canonical JSON. Its confirmation scope is fixed to
`exact_source_version_only`; the basis explicitly says that it is a platform
draft confirmation rather than an onchain signature. Relationships, dates,
measurements, authority decisions, and reviews remain separately attributed
enrichment. A later revision cannot alter or remove a confirmed source version.

## Typed capture

The schema supports:

- language-tagged preferred, alternate, historical, and identifier names;
- repeated, independently identified typed relationships and roles;
- dates whose expression, precision, calendar, timezone, and optional bounds
  remain separate;
- measurements scoped to a declared entity, with an exact integer, decimal, or
  unreduced rational lexical value, unit, precision, source version, and mapper;
- documentary attachments with a typed role and description; and
- an explicit `no_match` decision for Getty TGN, AAT, ULAN, VIAF, or Wikidata.

JSON numbers are not accepted for measurements. Integers and rational parts use
canonical unsigned decimal strings bounded to `uint256`. Decimals require a
plain nonnegative lexical form such as `40.00`; exponent notation and implicit
integer-to-decimal conversion are rejected. The tool preserves trailing zeros
and does not reduce rationals or convert units.

Measurement types have closed unit sets: pixel dimensions use `px`, file size
uses `B`, duration uses `s` or `ms`, and sheet/image-area dimensions use `mm`,
`cm`, or `m`. A syntactically valid unit on the wrong measurement type fails.

Every review retains `targetSnapshot` and commits to `targetHash`, the
Keccak-256 hash of that exact canonical relationship, date, measurement, or
authority-decision object. An existing review is immutable across draft
revisions. When the current target changes, preview labels the prior approval
`historical_target`; it does not apply the approval to the edited value.
Recomputing the old review's hash or snapshot in the mapper's revision cannot
impersonate a fresh reviewer approval. A reviewer can append a new review of
the corrected current target.

Attachment descriptors have only `described_only` status. Their closed shape
has no upload URL, storage address, checksum, receipt, scan result, or ingest
status. Supplying any such field fails validation. Actual file receipt and
preservation evidence belong to their recorded source families and archival
workflows.

## Initial submission

An `initial_submission` has `recordBinding: null`. Canonical bytes can be fully
validated and previewed offline:

```python
from tools.museum.canonical import dumps
from tools.museum.semantic_authoring import validate_draft, preview_bytes

raw = dumps(value)
validate_draft(raw)
preview_json = preview_bytes(raw)
```

The preview retains the exact source versions and reports only counts and
negative capability claims. It never inserts a chain ID, signature, receipt,
finality result, media location, authority match, or accession event.

## Later documentation and exact work binding

A `later_documentation` draft is rooted in an existing Stream token. Its
`workId` is the stable canonical original-token citation
`eip155:<chainId>/erc721:<lowercase-core>/<tokenId>`, and its entity declaration
has kind `token`. Conceptual or visual work/content entities retain separate
caller-assigned IRIs and explicit relationships; the binding does not collapse
them into the token or authenticate their real-world identities.

The token root must bind to existing evidence through one of the
following concrete sources:

1. a `RecordedSemanticSource` whose frozen `BoundSourceState` commitment,
   original capture, publication, interpretation, anchor, and whole public
   token-subject record selector all match externally supplied pins; or
2. a trusted `OwnerRecordSource` whose original anchor and transcript are
   replayed and whose complete snapshot hash and selected historical receipt
   match an externally supplied pin.

Use `bind_later_documentation` to add the evidence descriptor:

```python
# unbound_raw already declares the expected canonical token citation as
# workId and declares that root entity with kind "token".
bound = bind_later_documentation(
    unbound_raw,
    recorded_source,
    complete_record_selector,
    source_hash=recorded_source.state.commitment,
)
validate_draft(
    bound,
    source=recorded_source,
    source_hash=recorded_source.state.commitment,
)
```

For an owner source, pass the exact selected record hash instead of a selector.
The functions reconstruct evidence from the original anchor/transcript or from
the frozen recorded state, recompute the token subject hash, and require the
derived citation to equal `workId`. They do not trust mutable convenience maps.
A collection/media subject, title, filename, artist handle, account label, or
copied “verified” boolean can never create a later-documentation binding.

This bounded version intentionally rejects a later draft rooted directly in an
`abstract_work`. Such support needs a separately verified semantic-entity
adapter. Initial submissions may still use an `abstract_work` root before any
chain identifier exists.

Serialized binding data is a portable evidence descriptor, not self-proving
authority. Every full later-documentation validation requires the concrete
source and external pin again. The command-line tool therefore refuses to call
a later draft fully valid because a CLI path alone cannot reconstruct those
objects.

## Revisions

`revise_draft(previous_raw, revised_raw, ...)` requires:

- an increment of exactly one in `revision`;
- `previousRevisionHash` equal to the Keccak-256 hash of the exact previous
  canonical bytes;
- unchanged draft, work, purpose, creator, source-author, and recorded binding;
- every confirmed source-version object unchanged and still present; and
- every prior entity and typed item identity still present without changing its
  entity kind or relationship/date/measurement/attachment scope.

`revisedAt` must be equal to or later than the prior revision's `revisedAt`.

New source versions and enrichment may be appended. Existing mapped details may
be corrected while the prior revision remains hash-linked, but stable IDs cannot
be repurposed for a different entity or relationship.

## Command line

Use the repository museum environment:

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.semantic_authoring validate draft.json
.\.venv-museum\Scripts\python.exe -m tools.museum.semantic_authoring preview draft.json
.\.venv-museum\Scripts\python.exe -m tools.museum.semantic_authoring schema
```

`validate` checks canonical bytes, the closed schema, identity boundaries,
confirmation hashes, references, dates, exact numbers, and role attribution for
an initial draft. `preview` emits the explicit `draft_preview` JSON. `schema`
prints the exact candidate schema. For later documentation, use the Python API
with concrete pinned source evidence.

The CLI checks the file size before reading it. Drafts may exceed the onchain
record-payload limit because they are offline working data, but are capped at
512 KiB. This does not increase any Core or registered-record byte limit.

The implementation remains prospective application tooling. It does not
register `STREAM_MUSEUM_SEMANTIC_PROFILE_V1`, publish
`STREAM_SEMANTIC_ASSERTION_V1`, satisfy the recorded export gates, or claim
institutional conformance.
