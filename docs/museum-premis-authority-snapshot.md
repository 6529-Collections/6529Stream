# Retained LoC PREMIS authority terms

The [offline source adapter](../tools/museum/premis_authority_snapshot.py)
addresses the missing term-record snapshot boundary in
[CMC-PREMIS-PROFILE rule 1](collection-metadata-contract.md#premis-data-dictionary-mapping-cmc-premis-profile).
It binds explicit Library of Congress preservation-event term records to
selected fields in the unchanged `STREAM_PREMIS_V3_PROFILE` definition.

The [new adapter profile](../schemas/museum/premis-authority-snapshot/profile.json)
and binding report are prospective derivatives. They preserve the old profile's
exact bytes and historical status language. They do not register new meanings,
rewrite an existing value URI, or turn label agreement into semantic equivalence.
The Getty/VIAF/Wikidata reconciliation modules and identity rules are unchanged.

## Original bytes and source observations

Each snapshot consists of original UTF-8 line-triple bytes and an externally
pinned canonical descriptor. The descriptor retains the original term URI,
scheme URI, documentary endpoint, retrieval timestamp, byte length, RAW_BYTES
hash, representation, attribution, reuse terms and caller-admitted provenance.
The canonical HTTP term URI stays distinct from an HTTPS `.nt` endpoint.

Supported provenance labels are `synthetic_fixture`, `supplied_bytes` and
`retained_http_observation`. The descriptor and external call argument must
agree. These labels describe supplied evidence; they do not authenticate the
publisher or prove retrieval, currentness, identity or authority.

The parser uses the repository's existing pinned PyLD dependency, one line at
a time. It retains every accepted triple occurrence with its original line
number, byte offset, byte length and raw-line hash. Duplicate triples remain
separate occurrences. Literal escapes are validated and decoded exactly once.
Named graphs, escaped IRIs, unsupported syntax and non-absolute RDF IRIs reject.
No contexts, linked terms, replacement links or document URIs are fetched.

### The retained ingestion source

The example retains the exact response from
[LoC's ingestion term](https://id.loc.gov/vocabulary/preservation/eventType/ing.nt):
13,418 bytes, retrieved at `2026-09-20T04:05:36.065427Z`, with SHA-256
`b8877ee1a5da2db67f920b91013166f1ffbf44a281ef4b675171a77d6d10dd0f`.
Its [retrieval observation](../schemas/museum/premis-authority-snapshot/example/input/retrieval.json)
records HTTP 200 and the returned `text/plain; charset=UTF-8` content type.
That local observation is not a publisher signature or consensus proof.
Reuse terms were not supplied in the response; no license is inferred.

The response contains eight `<dlc>` relative references in blank-node
`RecordInfo#recordContentSource` and `changeset#creatorName` statements.
[N-Triples requires absolute IRIs](https://www.w3.org/TR/n-triples/#sec-iri).
A finite source-specific exception retains these exact lines as opaque,
unresolved relative references. They never become RDF facts or invented
absolute URIs. The snapshot explicitly reports `validNTriples: false`.
All other invalid lines reject. The report supports a bounded term-field
binding, not complete RDF conformance.

## Exact term binding and time

An explicit request supplies the original event-type JSON Pointer, selected
snapshot, candidate term URI, `asOf`, maximum snapshot age and optional required
version/effective-date lexical values. The adapter checks:

- Exact original profile bytes and external profile/request commitments.
- Original term subject, MADS/SKOS concept type, scheme membership, code and
  English or untagged string label supporting the profile's exact target label.
- The original profile's value URI when already present.
- Conflicting labels, codes, types or scheme memberships; deprecated or
  replaced terms; and multiple selected snapshots for one field.
- The caller's explicit freshness window and required source values.

It emits `bound`, `unresolved`, `ambiguous` or `stale` for each selection.
Only `bound` rows expose a candidate value URI. Competing snapshots are retained;
the adapter never chooses the newest one automatically. Profile-local terms
need separate review, and replacement links never redirect identity.

Source version and `dcterms:valid` facts retain their original lexical forms.
Absent values remain `not_supplied`. All linked administrative history remains
available with original selectors. The example contains historical change dates
without timezones; these are neither release versions nor effective dates and
are never converted to UTC. The freshness policy compares only the declared
retrieval time with the explicit request time, allowing at most six fractional
digits. Replaying an old request uses its original time policy, not today's clock.

## Offline package API

```python
from tools.museum.premis_authority_snapshot import build, verify

files = build(
    original_profile_bytes,
    request_bytes,
    {"ing": (descriptor_bytes, original_nt_bytes, descriptor_hash, provenance)},
    original_profile_hash=original_profile_hash,
    request_hash=request_hash,
    profile_hash=adapter_profile_hash,
)
report = verify(files, external_manifest_hash)
```

The package retains the exact original profile, request, adapter definition,
descriptors and raw responses alongside parsed snapshots and the binding report.
Verification checks the external manifest, complete inventory and full
reconstruction. Rehashing an altered report cannot bypass source parsing and
binding checks. A package can retain unresolved or stale results without
promoting them to accepted mappings.

Inputs are bounded to 16 snapshots, 1 MiB per response, 8 MiB in aggregate,
64 KiB per descriptor/request and 8,192 lines per response. Packages are bounded
to 128 files and 32 MiB. No network API is provided.

```text
python -m tools.museum.premis_authority_snapshot definitions --check
python -m tools.museum.premis_authority_snapshot example --check
python -m unittest tools.museum.test_premis_authority_snapshot
python -m tools.museum.premis_authority_snapshot verify PACKAGE --manifest-hash HASH
```

The [example pins](../schemas/museum/premis-authority-snapshot/example/pins.json)
bind the raw source, descriptor, retrieval observation, fixed request, derived
snapshot/report and reconstructed package. The example commands regenerate only
derived files from retained inputs; they never recapture the live source.

This increment covers one actual retained LoC event-term response plus hostile
synthetic controls. Broader authority-term capture, profile-local close-match
review, full vocabulary admission, current publisher authentication and
institutional acceptance remain separate work.
