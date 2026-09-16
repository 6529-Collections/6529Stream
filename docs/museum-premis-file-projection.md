# PREMIS file/fixity correspondence

This candidate adds a bounded PREMIS 3 XML representation beside the accepted
Linked Art v2 projection. Both are recomputed from one immutable public fixture
state, exact selection policy and entity plan. It implements a first executable
part of MUSEUM-04 and MSM-INTEROP; it is not the complete registered
`STREAM_PREMIS_V3_PROFILE` or a recorded-state adapter.

The broader contract still requires the complete preservation-object, event,
agent, rights and fixity-check crosswalk, LIDO work descriptions, IIIF manifests,
shared field comparisons and institutional reconstruction. Existing v1 and v2
projection/package behavior is unchanged. This increment adds no contract or
dependency and does not imply schema registration or chain authentication.

## Selected source and identity

The input uses the existing `STREAM_SEMANTIC_ASSERTION_V1` candidate wire and
`FixtureSourceAdapter`. A separate hash-bound PREMIS plan selects existing
digital entity IRIs from the exact Linked Art v2 plan. Each selected entity must
have four admitted single-valued assertions under
`urn:6529stream:museum:premis-file:v1:`:

| Relation suffix | Exact literal | PREMIS target |
| --- | --- | --- |
| `category` | Unqualified `xsd:string`, exactly `file` | `object/@xsi:type` |
| `byte-size` | Unqualified `xsd:nonNegativeInteger`, canonical decimal string | `objectCharacteristics/size` |
| `sha256` | Unqualified `xsd:string`, 64 lowercase hexadecimal characters | `objectCharacteristics/fixity/messageDigest` |
| `pronom-puid` | Unqualified `xsd:string`, `fmt/N` or `x-fmt/N` | `objectCharacteristics/format/formatRegistry` |

“Unqualified” means language, unit and precision are explicitly null. Values are
never trimmed, coerced or normalized. The named profile pins `SHA-256`, `PRONOM`
and the identifier scheme `URI`. Its original assertion relation fixes which
algorithm and registry these literals describe. PRONOM identifiers are checked
for syntax; this increment does not resolve a catalog, detect a file format or
assert that a file conforms to it. It copies a declared checksum without reading
the file, so it does not report a verified fixity check or generate an event.

The PREMIS object identifier equals the selected supplemental digital IRI and
the Linked Art DigitalObject ID. A token/collection subject is recorded separately
as the declaration's anchor; it is not another identifier for that file. No
`6529STREAM_SUBJECT` object identifier is fabricated from the anchor. The future
canonical `PreservationObjectRef` adapter must establish its actual object-subject
derivation. Work, content, physical carrier and file identities remain distinct.
The correspondence preserves both supported Linked Art content relationships and
original selected entity relations retained only in the sidecar.

The existing selector, issuer, review and conflict rules apply before emission.
Missing, disputed or unreviewed required facts cannot be replaced by filename or
DigitalObject inference. Selected conflicting facts reject this selected-file
export with their exact original selectors and values. Unselected claims and
unrelated declarations retain the existing non-veto behavior. Equivalent admitted
facts preserve every contributing source evidence row. Source claimants stay in
provenance; being a claimant does not confer a PREMIS preservation-agent role.

## Exact schema and validation

The dependency index retains the original Library of Congress schema from
[the PREMIS schema endpoint](https://www.loc.gov/standards/premis/premis.xsd).
Its header identifies version 3.0, January 18, 2016. The 52,845 original bytes are
stored in seven ordered chunks, with whole SHA-256
`03b8a77a20b32b882ad799e12262671d07ad18210c60233f4e613a1289491cba`.
The original schema contains no imports, includes or redefines; the complete
validation closure is that one document. Original comments and whitespace remain
inside the exact retained bytes. No interpretation repair is applied.

The already pinned `lxml==6.1.3` validates generated XML against that exact XSD.
No parser can resolve an external resource. Instance parsing rejects DTDs,
entities, processing instructions, comments, non-UTF-8 encodings, oversized
documents and excessive depth/node counts. The application emits deterministic
UTF-8 XML; it does not call this W3C XML canonicalization.

PREMIS's actual `size` type is `xs:long`, not an unbounded integer. The source
is first checked as an exact uint256 decimal; values greater than 2^63−1 fail
this XML profile. They are neither rounded nor truncated, and original source
bytes remain unchanged. Other full-width values outside this mapped field stay
in complete source accounting. This explicit limitation leaves a wider-size
serialization/profile decision open.

XSD validity is only the first check. `verify_premis_fixture` regenerates the
Linked Art and PREMIS projections from the caller's trusted exact state and
policy, then compares XML, correspondence, original provenance, source coverage
and reports. An XSD-valid substituted ID, digest, size, registry or attribution
fails even if its purported output hashes were updated. This strict generated
profile does not accept every semantically equivalent third-party PREMIS XML
serialization or establish institution-level ingest compatibility.

## Source accounting and use

All schema-derived source inventory rows are carried forward from the Linked Art
projection, including containers, repeated positions, null and absent values.
Additional PREMIS mappings change only applicable dispositions; original exact
values and inventory extent are unchanged. Unsupported title/creator, dates,
measurements, rights and technical details remain in the original source,
Linked Art output or typed sidecar, with their prior accounting. They are not
silently copied into unrelated PREMIS fields. Complete format comparisons for
those categories remain required work.

The implementation is [premis.py](../tools/museum/premis.py), with the candidate
definition in [profile.json](../schemas/museum/premis/profile.json). Use the
[isolated Museum environment](../tools/museum/README.md); no new install step is
needed:

```text
python -m tools.museum.premis --check
python -m unittest tools.museum.test_premis -v
```

The Python entrypoint generates or verifies the versioned profile document.
`project_premis_fixture` produces XML plus correspondence, combined coverage,
provenance and report bytes alongside the complete Linked Art result.
`verify_premis_fixture` takes the same trusted source/profile inputs and an
output value to verify. These are public-fixture operations; no chain adapter,
external API, registration, media retrieval or institutional receipt is used.
