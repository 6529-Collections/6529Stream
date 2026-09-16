# Museum geography projection

Status: prospective, unregistered draft-preview implementation guide

This guide covers the museum-only geography projector in
`tools/museum/geography.py`. It implements a bounded, deterministic projection
for the place and authority semantics in [MSM-PLACES and
MSM-AUTHORITIES](museum-semantic-mapping.md). It does not register a schema or
profile, authenticate an owner record, retrieve Getty data, or establish that a
historical statement is true. Recorded-source and package adapters must perform
those joins before using this output as authenticated evidence.

## Input contract

`project(source_bytes, linked_art)` accepts canonical JSON bytes and a pinned
offline Linked Art validator. The top-level value contains `version`, `places`
and `associations`. The implementation exports canonical `SCHEMA_BYTES`,
`SCHEMA_HASH`, `PROFILE_BYTES` and `PROFILE_HASH` so an adapter can pin the
exact prospective interpretation it used.
`python -m tools.museum.geography` writes these candidate documents beneath
`schemas/museum/geography`; add `--check` to verify their exact bytes.
Neither operation registers documents or changes existing profile versions.

Every place contains:

- a stable local IRI, a preferred name and one or more human-readable context
  statements;
- a closed nature of `real`, `fictional` or `unidentified`;
- an intentional public precision of `named_place`, `broad_region` or
  `geometry_as_supplied`;
- alternate or historical names whose language, applicable dates and exact
  source selector remain attached;
- one or more classifications from the finite profile-local place catalog;
- archived source-document commitments;
- optional typed hierarchy assertions, public geometry and Getty TGN
  alignments.

Source references include the complete record selector, a JSON pointer within
the source and an optional assertion IRI. Their presence is evidence
correspondence, not authentication. The projector rejects a zero record hash,
unsafe archive path or empty document commitment, but the supplying adapter is
responsible for proving those selectors and bytes against recorded state.

Geometry is public input. It must contain the exact representation, coordinate
reference system IRI, precision statement, uncertainty statement, source and
applicable date. A place with geometry must explicitly choose
`geometry_as_supplied`; a broad or named-only place cannot hide precise
geometry in this input. The module does not accept private material and never
constructs a point, centroid or more precise place from a name.

## Place-role projection

The role catalog is closed. Custom roles require a later registered profile
version.

| Source role | Required subject type | Projected property |
| --- | --- | --- |
| `capture_location` | `Activity` | `took_place_at` |
| `creation_location` | `Creation` or exact source `Activity` | `took_place_at` |
| `depicted_place` | `VisualItem` | `represents` |
| `subject_place` | `LinguisticObject` | `about` |
| `production_location` | `Production` or exact source `Activity` | `took_place_at` |
| `interview_location` | `Activity` | `took_place_at` |
| `exhibition_location` | `Activity` | `took_place_at` |
| `custody_location` | `Activity` | `took_place_at` |
| `publication_location` | `Activity` | `took_place_at` |

Association output is a typed fragment for joining to an entity already owned
by the wider semantic graph. It does not redeclare that entity or infer that a
capture event, depicted coast and editing studio are the same place.
Local place IDs cannot use the known authority/account namespaces; associations
cannot reuse an existing Place or classification ID under a different kind.
`subject_place` is limited to the pinned baseline's supported
`LinguisticObject` aboutness form; other subject classes fail closed as
typed `retained_stream_only` relations with an explicit reason and no invented
property. Creation and production retain their specific event classes or an
exact source `Activity` instead of being relabeled.

## History, hierarchy and uncertainty

The projector keeps three hierarchy meanings separate:

| Hierarchy kind | Treatment |
| --- | --- |
| `spatial_containment` | Emits qualified Linked Art `part_of` when both local places are present. |
| `catalog_hierarchy` | Remains `retained_stream_only` with exact source, context and applicable date. |
| `political_affiliation` | Remains `retained_stream_only` and never becomes an unqualified modern-sovereignty claim. |

Each hierarchy graph must be acyclic and every parent must be declared in the
same bounded input. Fictional and unidentified places retain local Place
resources and descriptions. They cannot carry Getty TGN matches or real-world
geometry. Broad places remain broad because geometry is absent and the source
statement remains available unchanged.

Names and context are copied as exact text into the Linked Art Place resource.
Language, applicable-date precision and all source selectors remain in the
canonical source and coverage sidecars. The projection qualification states
that historical accuracy, place identity, exact position and reviewer identity
are not independently established.

## Getty TGN alignments

An alignment retains the Stream entity, Getty identifier, canonical vocabulary
IRI, optional real-world focus IRI, match kind, archived snapshot commitment,
retrieval instant, authority revision, label reviewed, snapshot values and the
complete review basis. Snapshot values include the labels, types, hierarchy
values, attribution and reuse terms actually used. The module makes no network
request.

For Getty TGN, the canonical vocabulary IRI must be exactly
`http://vocab.getty.edu/tgn/{identifier}`. A supplied focus IRI must be exactly
that IRI plus `-place`. The two identities remain distinct.

Every authority alignment remains `retained_stream_only` in this pure draft
preview. A caller-supplied `reviewed` status, reviewer IRI and check booleans do
not authenticate the reviewer or prove that the archived snapshot bytes match
their commitment. This layer therefore never emits Linked Art `equivalent`,
including for a self-declared active equivalent match. A separate recorded
source and authority adapter must validate eligibility, load and hash the exact
snapshot bytes, and apply the registered selection policy before producing any
identity edge.

Automated suggestions must start `unreviewed`. Close matches, related
references, disputed or superseded assertions, and every authority snapshot
remain typed in the source sidecar without promotion to identity. A later
alignment can cite the assertion it supersedes, preserving the old identifier,
snapshot and review basis.

## Outputs and coverage

The function returns canonical bytes under `geography/`:

- `source.json` is the admitted source value retained in full;
- `resources/` and `expanded/` contain pinned-validator-checked Place and Type
  resources and their offline JSON-LD expansions;
- `relations.json` contains the nine-role typed join fragments;
- `provenance.json` connects every emitted resource leaf to source paths,
  selectors, mapping rules and the qualification;
- `coverage.json` assigns every source scalar, null and empty collection exactly
  one `mapped` or `retained_stream_only` disposition;
- `sidecar.json` retains geometry, non-spatial hierarchy and weaker or historical
  authority assertions that have no faithful emitted graph property;
- `index.json` and `report.json` identify the output as a `draft_preview`, then
  summarize deterministic resources, bounds, profile identity, counts and
  uniformly false independent-proof claims.

The projector validates and expands through the repository's pinned offline
Linked Art graph validator. It performs no live context or authority lookup.
Running it twice with the same canonical source and pinned dependencies yields
the same bytes.

## Finite limits

The profile bounds input to 524,288 bytes, 64 places and 256 associations.
Per-place limits are 32 alternate names, 32 context statements, 16
classifications, 32 hierarchy assertions, 16 alignments and 32 source
documents. Authority evidence is bounded to 16 review selectors, 32 labels, 32
type values, 64 hierarchy values and 64 other retained values. Strings and JSON
depth inherit the closed schema and canonical JSON limits.

Run the focused suite with:

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.test_geography
```

The tests use synthetic selectors and Getty-shaped snapshots only. They verify
mapping and rejection behavior; they are not evidence of a real authority
review or historical fact.
