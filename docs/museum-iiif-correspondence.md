# Offline IIIF Presentation 3 correspondence

This candidate profile produces one public synthetic Manifest from the same
selected source records as the Linked Art v2 and PREMIS file projections. It
does not authenticate chain state, register a profile, fetch media, or establish
viewer compatibility. The current contract-facing `STREAM_IIIF_P3_MIN_V1`
requirements remain a separate registration and actual-media integration gate.

The [profile](../schemas/museum/iiif/profile.json),
[local target schema](../schemas/museum/iiif/target.schema.json), and
[dependency inventory](../schemas/museum/iiif/dependency-index.json) are exact
offline inputs. The schema is a finite Stream evaluation profile derived from
the [Presentation 3 specification](https://iiif.io/api/presentation/3.0/), not an
official IIIF JSON Schema. Original specification, context, cookbook and URI
documentation bytes are retained in 8,192-byte chunks. No original is repaired
or reserialized.

The complete scoped JSON-LD closure contains eight original contexts. The
Presentation 3 and Image 3 contexts reference each other. These semantic
references are recorded separately from the acyclic hash inventory and checked
against the pinned documents. No fallback loader accesses the network.

The pinned specification and v3 audio example use `Sound`, while the served
Presentation 3 and Web Annotation contexts define `Audio` for the corresponding
Dublin Core class. The Manifest therefore visibly emits a two-entry `@context`
sequence: the official Presentation 3 URI followed by
`urn:6529stream:museum:iiif-p3:sound-context:v1`. The
[exact named supplement](../schemas/museum/iiif/sound-context.json) adds only
`Sound` → `http://purl.org/dc/dcmitype/Sound`. Its hash is bound by the profile.
The original contexts stay unchanged. An ordinary viewer without this local
document resolver cannot be assumed to resolve the supplement or the media.
The retained cookbook pages also describe version 4; this profile uses their
explicit version 3 examples and the Presentation 3 specification only.

Each explicitly selected digital file must already satisfy the PREMIS file
profile: file category, exact size, declared SHA-256, and a PRONOM PUID. New
ordinary semantic assertions supply the presentation type, MIME type, content
URI, applicable extent, attribution, file rights, and its relationship to the
selected abstract work. A separate `manifest-rights` assertion explicitly licenses
the generated Manifest JSON. An underlying-work rights assertion cannot supply
that fact and remains in the sidecar, including any disagreement. The plan selects file order and distinct Manifest,
Canvas, AnnotationPage and Annotation HTTP(S) identifiers. It cannot invent
media facts or merge a token, work, digital file, content object and Canvas.

| Source fact | Target meaning |
| --- | --- |
| Unspecified-language names on the selected declaration | Exact `label.none` values, in source order |
| Work summary and attribution | Escaped plaintext in `summary` and `requiredStatement` |
| Explicit `manifest-rights` assertion | Generated Manifest JSON rights only; no underlying-work license inference |
| Each file's attribution and rights | That file's own `requiredStatement` and `rights`; never inherited from the work |
| Declared Image, Text, Sound or Video plus MIME | Exact body type/format from the finite profile catalog |
| Image/Video pixel width and height | Full-file body and Canvas spatial extent |
| Sound/Video duration in seconds | Identical full-file body and Canvas duration |
| Text canvas layout width and height | Canvas units only; no invented text-file pixel dimensions |
| PREMIS digest, byte size and selected source evidence | Full-IRI typed values and `@json` provenance; no RDF node coercion of selectors |

Duration uses a separate deterministic target encoder that preserves decimal
lexicals such as `0.10000000000000001` and `220.000` without passing through
binary floating point. An explicit decimal point is required by this profile.
The encoder is not RFC 8785/JCS. Stream source integers and decimals retain
their original typed-string representation, including full uint256 values.
Offline expansion preserves `Decimal` values in memory; it does not claim an
RDF canonicalization or serialization of those values.

Plaintext in HTML-enabled fields is escaped inside a `span`. Carriage returns
use `&#13;`, so XML parsing recovers CR, LF, literal entities, punctuation and
Unicode exactly. XML 1.0-inexpressible controls reject without replacement.
Unspecified language maps to `none`; specified-language mapping is an explicit
remaining profile extension. HTML, scripts and interactive media are not
admitted by this first passive-media profile.

Painting bodies retain their original `ipfs://` or `ar://` content identifiers.
The initial IPFS subset is canonical lower-base32 CIDv1 with the raw codec and
SHA-256; its digest must match the selected PREMIS claim. Arweave transaction
identifiers are checked for canonical encoding but are not equated to raw media
digests. Neither check retrieves bytes or verifies preservation fixity. Painting URIs
must differ from admitted work, file, content and external entity IRIs. Repeated
painting URIs require consistent type, MIME, extent, digest, size, rights and
attribution, while file labels and source provenance may differ. Other
CID codecs/bases, directory paths, HTTP gateways, selectors, services, ranges,
choices and supplemental annotations require later explicit support. A text
file on its own Canvas is a painting body; this does not relabel a transcription
annotation about another Canvas, which requires `supplementing` semantics.

Use the [isolated Museum Python environment](../tools/museum/README.md):

```text
python -m tools.museum.iiif_model --check
python -m unittest tools.museum.test_iiif_numbers tools.museum.test_iiif_uri tools.museum.test_iiif -v
```

The library entrypoints are `project_iiif_fixture` and `verify_iiif_fixture` in
`tools.museum.iiif`. Callers provide the source state, exact selection/Linked Art/
PREMIS/IIIF plan bytes and their expected hashes, plus the pinned three format
validators. Verification recomputes every output from those trusted inputs;
schema-valid substitutions and self-rehashed output reports are insufficient.
Original source payloads, schemas and fixture-authority evidence remain in the
Linked Art sidecar. The coverage denominator is the entire source schema
inventory, with exact null/absent/container/array/value rows retained across all
three projections. Policy and plan wrapper reads use the existing
524,288-byte bound; generated PREMIS correspondence/provenance use the existing
64 MiB aggregate bound and are parsed once. Individual source record payloads
remain bounded to 24 KiB. Conflicts affect only fields used for the relevant
projection role; unrelated selected claims remain retained diagnostics.

The example describes four synthetic files and separate visual, linguistic,
nonlinguistic sound and multimedia content. Its digests, sizes, formats, rights
and availability are declarations, not preservation events or verified facts.
Full media-format coverage, LIDO, registered source adapters, archival packaging,
institutional ingest and all Museum gates remain required work.

Original documentation is retained under its upstream terms: IIIF pages carry
CC BY 4.0 attribution; the CID document includes Protocol Labs' CC BY 3.0 notice;
the multicodec table is MIT; the Arweave HTTP documentation is accompanied by its
GPL license. See the exact retained licenses in
[`schemas/museum/iiif/licenses`](../schemas/museum/iiif/licenses).
