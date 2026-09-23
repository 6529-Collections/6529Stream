# Complete PREMIS authority-field accounting

The [V2 coverage adapter](../tools/museum/premis_authority_coverage.py) checks
every enumerated authority field in the original `STREAM_PREMIS_V3_PROFILE`:
13 event types, six outcomes, four agent classes, six rights bases and six
fixity algorithms. Its [prospective profile](../schemas/museum/premis-authority-coverage/profile.json)
preserves the original crosswalk and [V1 snapshot adapter](museum-premis-authority-snapshot.md)
bytes. It does not register replacements or change any of the 29 genesis schemas.

The implemented requirement is complete accounting for these 35 fields and
their explicitly selected vocabulary evidence. Agent roles have an authority
reference but no original enumeration; identifiers, object relationships,
format-registry resolution and the full PREMIS field crosswalk remain separate.
Complete accounting does not mean that every field has an external match.

## Explicit field selection

A request must provide every original JSON Pointer exactly once, in original
order. Missing, duplicated, reordered or unknown fields reject. Each field has
one disposition, a rationale and up to four explicit candidates:

| Disposition | Meaning |
| --- | --- |
| `authority` | A nonlocal field has one or more explicitly selected term snapshots |
| `profile_local` | The original profile itself marks the field local; its original close-match value is retained literally |
| `unresolved` | No candidate is selected; the reason stays explicit |

An `exact_label` candidate must use the original target label. Its own RDF
subject, code, English or untagged string label, concept type and membership
must support the exact field-specific scheme. Existing original value URIs
must agree. This produces a prospective `bound` field with `candidateValueUri`;
label agreement alone does not establish semantic equivalence or authority.

A `close_match` candidate names its own retained label and requires the field's
rationale. A supported candidate produces `proposed_close_match`, with
`reviewed: false` and no adopted value URI. An originally local term cannot
become an exact authority identity. Existing profile-local outcome links remain
original values; the adapter never silently redirects them to an external term.

Multiple candidates remain `ambiguous`, including two snapshots that appear to
agree. A conflicting label/code/type/scheme, deprecated or replaced term,
unsupported version/effective date, or stale observation remains explicit.
No latest source is selected automatically, and replacement links do not merge
identities. Unknown source facts remain retained in the parsed snapshot.

Six retained event records also declare the PREMIS v3 `Action` RDF type. V2
accepts that exact additional type only for event-type fields, while still
requiring `Authority` or `Concept`. This records vocabulary classification; it
does not establish that an action occurred. Other additional types remain
ambiguous, and V1 keeps its original type policy.

The `eventOutcome` path constrains any future supplied candidate; it does not
assert that LoC currently publishes that vocabulary. An unavailable response
does not establish absence. Original outcome labels remain unchanged when no
usable term record is supplied.

## Source and time boundaries

Each source contains the original bytes, an externally pinned descriptor and
an explicit provenance label. The V1 bounded N-Triples parser retains all triple
occurrences with original byte/line selectors. Its finite original `<dlc>`
exception remains opaque and reports invalid N-Triples; no URI is invented.

For `retained_http_observation`, the package also requires the original HTTP
observation: requested/final URI, status, content type, byte length, SHA-256 and
retrieval time must match the descriptor and raw bytes. These are consistency
checks on an observed retrieval, not a publisher signature or independently
authenticated current source. `synthetic_fixture` and `supplied_bytes` remain
separate provenance categories.

Every replay uses its original explicit `asOf` and maximum snapshot age.
Original version, effective-date and administrative-history facts retain their
lexical values. Administrative dates do not become effective dates or inferred
UTC timestamps. Missing values stay `not_supplied`.

## Offline package

```python
from tools.museum.premis_authority_coverage import build, verify

files = build(
    original_profile_bytes,
    request_bytes,
    {"selected_term": (
        descriptor_bytes, original_nt_bytes, descriptor_hash, provenance,
        retrieval_observation_bytes_or_none,
    )},
    original_profile_hash=original_profile_hash,
    request_hash=request_hash,
    profile_hash=adapter_profile_hash,
)
report = verify(files, external_manifest_hash)
```

The complete package retains the original profile, request, V2 definition,
descriptors, raw sources, retrieval observations, parsed snapshots and report.
Verification rebuilds every derived byte from original inputs. Rehashing an
altered report or snapshot cannot bypass reconstruction. Unselected snapshots
and extra package files reject. An entirely unresolved package is valid evidence
of explicit accounting; it cannot claim all fields bound or complete conformance.

Limits are 35 fields, four candidates per field, 64 snapshots, 1 MiB per raw
source, 128 KiB per descriptor/request/observation, 8 MiB total input and a
32 MiB/256-file package. The adapter never accesses the network.

```text
python -m tools.museum.premis_authority_coverage definitions --check
python -m tools.museum.premis_authority_coverage example --check
python -m unittest tools.museum.test_premis_authority_coverage
python -m tools.museum.premis_authority_coverage verify PACKAGE --manifest-hash HASH
```

Native admission, source authentication, accepted close-match review, all
crosswalk semantics and institutional conformance remain separate requirements.

## Retained source example

The [example pins](../schemas/museum/premis-authority-coverage/example/pins.json)
commit a fixed request, the exact inputs and a reproducible 73-file term package.
Seventeen term endpoints were successfully observed on 20 September 2026:
11 event types, three agent classes and three rights bases. Offline replay
reports **17 bound, eight profile-local and ten unresolved fields**. Every
successful source retains the original `<dlc>` exception and reports its RDF
qualification explicitly.

The [separate discovery report](../schemas/museum/premis-authority-coverage/example/expected/discovery.json)
replays four complete original scheme responses and four final HTTP 503
observations from their retained bodies and retrieval metadata. Scheme records
list creation, SHA-256 and SHA-512, but their term endpoints were unavailable
during the bounded capture. The outcome scheme response was also unavailable.
These observations establish neither present-day absence nor a usable term
snapshot. The other unresolved fields are the original preservation-service
agent class and the `public_domain`, `contract` and `unspecified` rights labels.

Discovery bytes are kept beside the term-package inputs and independently
committed by the example's input index and discovery hash. They do not enter
term binding or replace an unavailable term response. `example --check`
rebuilds both components from local bytes; `example_package()` returns the
term package for `verify`. No command recaptures a live URL.
