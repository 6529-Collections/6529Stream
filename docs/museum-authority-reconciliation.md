# Museum authority reconciliation

Status: bounded candidate implementation guide

This guide describes V1. The separately versioned
[typed authority profile V2](museum-typed-authority-profile.md) adds recorded
`Type` support and explicit declaration continuation without changing V1.

`tools/museum/authority_snapshot.py` and `tools/museum/authority.py` implement a
finite, offline reconciliation boundary for `[MSM-AUTHORITIES]`. The recorded
package wrapper in `tools/museum/authority_package.py` applies that boundary to
an existing verified recorded-account source package. These modules do not
register the adopted museum profile, authenticate an authority publisher,
establish a named human identity, or grant Stream signing authority.

The implementation has three distinct levels:

1. **Snapshot parsing** verifies exact caller-retained RDF/JSON bytes and
   extracts bounded facts with JSON Pointer selectors.
2. **Draft reconciliation** evaluates candidate assertions but marks every
   draft candidate ineligible as `unreviewed_draft_suggestion`. It can never
   emit a Linked Art `equivalent` relationship.
3. **Recorded-account reconciliation** replays the existing verified original
   independent-account package and its exact selection policy. Mapped
   assertions require an explicitly selected, later, same-account `SELF`
   review of the exact assertion revision, profile and mapping rule.

The current recorded-account support does not establish the account holder's
human name or professional qualification. It does not support an independent
human reviewer. All positive reconciliation cases in the engine tests are
synthetic. The actual retained recorded-account fixture contains no authority
alignment and therefore exercises the honest unresolved path, rather than an
actual-current positive authority match.

## Canonical authority identities

`canonical_authority_iri(authority, identifier)` accepts only these issued
identifier forms:

| Authority | Identifier | Canonical IRI |
| --- | --- | --- |
| `GETTY_TGN` | nonzero canonical decimal | `http://vocab.getty.edu/tgn/{identifier}` |
| `GETTY_AAT` | nonzero canonical decimal | `http://vocab.getty.edu/aat/{identifier}` |
| `GETTY_ULAN` | nonzero canonical decimal | `http://vocab.getty.edu/ulan/{identifier}` |
| `VIAF` | nonzero canonical decimal | `http://viaf.org/viaf/{identifier}` |
| `WIKIDATA` | uppercase `Q` plus a nonzero canonical decimal | `http://www.wikidata.org/entity/{identifier}` |

The parser rejects leading zeroes, alternate schemes, document extensions,
trailing-slash aliases and other transformed identifiers. A secure documentary
endpoint may be recorded separately as `sourceUri`; it does not replace the
canonical identity and is not proof that the named authority issued the bytes.

Getty uses `foaf:focus` to distinguish a vocabulary concept from its real-world
focus. The parser preserves both IRIs and rejects a self-focus or competing
focus values. It does not interpret `skos:focus`. See the
[Getty semantic representation documentation](https://vocab.getty.edu/doc/)
and the [Linked Art Place endpoint](https://linked.art/api/1.0/endpoint/place/).

## Exact offline RDF/JSON snapshots

Each snapshot has two retained inputs:

- a closed version-1 descriptor containing authority, identifier, canonical
  IRI, documentary `sourceUri`, UTC retrieval time, raw-byte `HashRef`, byte
  length, `application/rdf+json` media type, attribution and reuse terms; and
- the exact RDF/JSON bytes named by that descriptor.

The `HashRef` uses the registered `RAW_BYTES` canonicalization ID and either
algorithm `1` (Keccak-256) or `2` (SHA-256). The parser checks the exact digest
and byte length before reading RDF/JSON. It accepts noncanonical JSON
serialization because the raw bytes, rather than a rewritten form, are the
evidence. Duplicate keys, invalid UTF-8, floating-point values, invalid RFC
3986 URIs and unsupported RDF term shapes fail closed.

Parsing is limited to 1 MiB, 4,096 subjects and 16,384 RDF terms. It performs no
network resolution. The returned complete triple list retains every accepted
predicate and term with an escaped JSON Pointer into the original graph.
Derived label, type, hierarchy and revision facts cite those same exact term
pointers. The caller must retain the original descriptor and raw bytes; the
derived fact list is not a replacement archive.

The finite type allowlist is:

| Authority | Local kind | Accepted exact authority types |
| --- | --- | --- |
| Getty TGN | `Place` | GVP `PhysPlaceConcept`, `AdminPlaceConcept`, `PhysAdminPlaceConcept` |
| Getty AAT | `Type` | SKOS `Concept`, GVP `Concept` |
| Getty ULAN | `Person` | GVP `PersonConcept` |
| Getty ULAN | `Group` | GVP `GroupConcept` |
| VIAF | `Person` | FOAF or Schema.org `Person` |
| VIAF | `Group` | FOAF `Organization` or Schema.org `Organization` |
| Wikidata | `Person` | `P31` value `Q5` |
| Wikidata | `Group` | `P31` value `Q43229` or `Q4830453` |
| Wikidata | `Place` | `P31` value `Q515`, `Q6256` or `Q23442` |

Getty ULAN `UnknownPersonConcept` is intentionally not accepted as an
identified individual. The reconciler performs no superclass inference and
does not infer a type from labels, coordinates, search rank or prose.
Conflicting recognized focus types, unsupported Getty focus identities and
explicit obsolete, deprecated or replaced record markers withhold projection.
Replacement links are retained; the reconciler never follows them as an identity
redirect. Earlier exports continue to consume their own unchanged snapshots.

The existing base semantic entity schema cannot declare the `type` entity kind.
Consequently, Getty AAT `Type` is an engine-level synthetic positive only; an
original recorded AAT `Type` assertion cannot qualify until a new registered
schema/profile version adds that declaration without reinterpreting old
profiles.

Authority hierarchy facts provide catalog context for a review. A Getty
broader relation does not become an unqualified statement of physical
containment, administrative control, or sovereignty. Place alignments require
explicit context checks whose local statement, conclusion and rationale remain
in the assertion body.

## Draft API

The pure draft entrypoint is:

```python
from tools.museum.authority import PROFILE_HASH, reconcile_draft

files = reconcile_draft(
    request_bytes,
    assertions_bytes,
    snapshots,
    request_hash=request_hash,
    assertions_hash=assertions_hash,
    profile_hash=PROFILE_HASH,
)
```

`request_bytes` and `assertions_bytes` are canonical JSON and must match their
external pins. `snapshots` maps each assertion's snapshot path to
`(descriptor_bytes, raw_rdf_json_bytes, descriptor_hash)`. Every supplied
snapshot must be referenced. A request with no candidate remains valid and is
reported `unresolved`; an external match is optional.

The draft output retains every candidate in `authority/sidecar.json`. Because
the draft has no authenticated recorded review, it produces no
`authority/resources/*` equivalence. `close_match` and `related_reference`
always remain in the sidecar. The reconciler never substitutes `owl:sameAs` or
`skos:exactMatch` for Linked Art's
[`equivalent`](https://linked.art/ns/terms/equivalent).

`authority/coverage.json` accounts for every field in each original candidate
assertion, including its exact literal bytes, nulls and empty collections.
The provenance index identifies emitted equivalence claims, original selectors,
reviews and snapshot pointers. The smaller Linked Art resource does not replace
the full attributed statement or archived authority evidence.

If multiple eligible current assertions identify different authority entities
for the same local entity and authority, the result is `ambiguous` and no
equivalence is emitted. Labels, coordinates, rank and recency are never truth
tie-breakers.

## Recorded-account package

The recorded wrapper starts with the existing verified original account
package rather than accepting copied selector objects or a Boolean "verified"
flag. It replays the package's original capture, publication,
interpretation/profile and selection bytes against their external hashes. The
selection must explicitly opt into account `SELF` review. Cross-account review
and an independent-human-review claim are rejected by the current account
profile.

Each candidate retains its exact original entity declaration, selector and
hash. An existing dossier identity can receive an alignment only from its same
selected declaration. A new record's same-kind or same-account declaration is
insufficient to establish reuse. External references cannot be redeclared as
local identities, and competing eligible new declarations of one IRI withhold
projection. Explicit continuation of declarations remains a future policy;
unselected collisions do not veto a qualifying original declaration.

The snapshot index is canonical JSON. It is a dictionary whose key is the
logical snapshot path used by the alignment and whose value is exactly:

```json
{
  "descriptorPath": "snapshots/tgn-7002327.descriptor.json",
  "rawPath": "snapshots/tgn-7002327.rdf.json",
  "descriptorHash": "0x..."
}
```

Both paths are relative to and remain beneath the index file's parent
directory. Absolute paths, traversal and case-insensitive path collisions are
rejected. Every indexed item must be referenced and is retained exactly in the
produced package. Missing requested snapshots produce unresolved candidates.
The descriptor hash and its raw-byte
`HashRef` are rechecked during reconstruction.

The Python package entrypoints are:

```python
from tools.museum.authority_package import (
    build_authority_package,
    verify_authority_package,
)

package = build_authority_package(
    source_directory,
    source_manifest_hash,
    request_bytes,
    selection_bytes,
    snapshots,
    request_hash=request_hash,
    selection_hash=selection_hash,
    profile_hash=profile_hash,
    disclosure="public",
)

verified = verify_authority_package(output_directory, package.manifest_hash)
```

The command-line build form is:

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.authority_package build SOURCE REQUESTS SELECTION SNAPSHOT_INDEX OUTPUT `
  --source-manifest-hash HASH --request-hash HASH --selection-hash HASH `
  --profile-hash HASH --disclosure public

.\.venv-museum\Scripts\python.exe -m tools.museum.authority_package verify OUTPUT `
  --manifest-hash OUTPUT_MANIFEST_HASH
```

`SOURCE` is the input directory for the existing recorded-account package,
`REQUESTS` and `SELECTION` are exact canonical JSON inputs, `SNAPSHOT_INDEX`
names the canonical snapshot index, and `OUTPUT` is a new package directory.
All hashes are lowercase `0x`-prefixed 32-byte values. Only explicit `public`
disclosure is supported; restricted-source redaction is not implemented by
this wrapper.

This package is bounded recorded-account authority support. It is not yet the
full `STREAM_SEMANTIC_EXPORT_V1` object-dossier package and does not create an
`ARCHIVE_SEMANTIC_EXPORT` record. Artist, curator, institution and qualified
external-review lanes still require their adopted registered authorization and
selection adapters.

## Reconciliation history

A rename, merge, split, deprecation, hierarchy change or correction is a new
assertion. Its change body must cite the exact prior assertion ID and hash plus
the prior snapshot reference. The selected predecessor must exist, precede the
new assertion in authenticated publication order, have the same asserting
account and retain the same local entity and authority scope. A non-correction
disposition must use a different snapshot commitment.

The prior assertion and snapshot remain in the sidecar and package. This is
same-issuer lineage, not authority to rewrite another recorder's assertion.
An unresolved predecessor leaves the new candidate ineligible.

## Candidate schemas and coverage

`tools/museum.authority` writes these candidate files:

- `schemas/museum/authority/STREAM_MUSEUM_AUTHORITY_ALIGNMENT_BODY_V1.json`
- `schemas/museum/authority/profile.json`

Generate them with the module and verify checked-in bytes with:

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.authority --check
```

The files are explicitly `candidate_unregistered`. They are a derivative
bounded reconciliation profile and do not alter earlier registered account
profiles or silently widen their meaning. Any change to authority meaning,
type allowlists, mapping, dependencies or selection policy needs a new profile
version and explicit supersession lineage.

The canonical machine-readable requirement map is
[`schemas/museum/authority/coverage.json`](../schemas/museum/authority/coverage.json).
Every mapped requirement remains `partial` until the full adopted profile and
schemas are registered, all required authorization/reviewer lanes exist, a
real current positive is recorded for the supported authorities, and authority
components are composed into the complete archival semantic export.
