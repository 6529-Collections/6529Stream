# LIDO work and media correspondence

This bounded offline profile projects one explicitly described abstract work and
its four selected media resources from the same public synthetic source used by
[Linked Art](museum-abstract-nonvisual-projection.md),
[PREMIS](museum-premis-file-projection.md) and
[IIIF](museum-iiif-correspondence.md). It validates the result against the original
LIDO 1.1 XML Schema. It is a candidate interpretation of ordinary semantic
assertions, not a registered `STREAM_WORK_DESCRIPTION_V1` or `STREAM_LIDO_PROFILE_V1`
record, a chain adapter, or institutional acceptance.

The exact [LIDO 1.1 schema](https://lido-schema.org/schema/v1.1/lido-v1.1.xsd)
and [dated official primer](https://lido-schema.org/documents/primer/2024-09-11/lido-primer.html)
are retained locally. The complete 35-document XSD closure includes original
GML 3.1.1, SMIL, XML and XLink schemas. The 36 documents occupy 166 ordered chunks;
their whole hashes, original URLs and ordered schema references are pinned in
[`dependency-index.json`](../schemas/museum/lido/dependency-index.json).
The immutable file inventory is acyclic; the separate actual schema include graph
contains cycles and is checked without changing it. Validation never fetches a
schema, DTD, media file or terminology service.

The original LIDO schema imports the older `2001/03/xml.xsd` first. libxml2
therefore skips two later imports of the same XML namespace from `2001/xml.xsd`;
the report retains both warnings. All 35 original schema documents and every
declared reference are still checked, including the skipped document. This does
not claim both XML namespace definitions were simultaneously applied. The old
schema retains its original DOCTYPE with DTD loading disabled. Untrusted instance
XML cannot contain a DTD, entity, comment or processing instruction.

| Selected source | LIDO meaning |
| --- | --- |
| Abstract-work identity and ordered names | `objectPublishedID` and exact title values |
| Explicit work-type, medium and edition strings | Work type, display materials/technique and edition text |
| Exact work summary and credit line | Work description and credit; credit must agree with the same IIIF work attribution |
| Work→creation-event→creator assertions | Identified creation event and identified Person/Group creator; never the record issuer by default |
| Explicit creation-display string | `displayDate` verbatim, without invented earliest/latest dates |
| Original selected record and fixture issuer | Derived `recordID` and distinct `recordSource`; not a custodian or creator claim |
| Same IIIF/PREMIS file identity | `resourceID`, retaining work/token/file/content/Canvas distinctions |
| Original content URI, declared MIME and applicable extent | Link and exact file measurements; text Canvas layout is not a text-file dimension |
| Each file's own rights and credit | `rightsResource`; no inheritance from work or Manifest rights |

`urn:6529stream:museum:lido-work:v1:` identifies the finite assertion mapping.
All required role-specific facts must be explicitly selected. Their relations
must be in the selected policy's single-valued set; contradictory eligible
claims are withheld with their original evidence. Claims about an unrelated
subject and unselected records remain diagnostics and cannot veto this export.
The fixed `creation`, `creator` and `item` terms are part of this candidate
profile, not a claim that an external controlled-vocabulary admission occurred.
Generic source events remain generic in the independently retained Linked Art
sidecar; the LIDO creation role comes from its explicit selected assertion.

The original schema requires `xml:lang` on both metadata wrappers and rejects
an empty value. This first profile therefore requires a separate selected
`document-language` assertion with the exact value `und`. That assertion covers
every emitted language-bearing text in both wrappers. Missing, null, differently
qualified or contradictory language is never defaulted or inferred. Any
separately specified source name language must agree; the earlier IIIF profile
still independently rejects specified-language work/file labels. Original
`name.language=null` remains unchanged in source bytes and inventory. The
statement describes this export's text, not the language of the work or artist.

UTF-8 XML 1.0 serialization preserves CR/LF, literal entities, punctuation and
astral Unicode. Unrepresentable controls reject without stripping or replacement.
Decimal and uint256 source strings stay exact: a duration such as `220.000` is
text in a LIDO measurement, and uncertain source dates remain display text.
The 4 MiB XML, depth 64 and 32,768-element bounds are explicit implementation limits;
source records remain 24 KiB, plans/policy 524,288 bytes and generated JSON 64 MiB.

The exporter requires an explicit LIDO record URI distinct from admitted source
entities and IIIF target/content identities. Original record IDs use the prefix
`urn:6529stream:museum:lido-work:v1:source-record:` followed by the Keccak hash of
the canonical object `{selector, payloadHash, authorityEvidenceHash}`. `selector`
is the complete original snake_case `RecordSelector`; the evidence hash binds
exact immutable fixture-authority bytes. This identifies an exact source record
without pretending to reproduce an onchain record-hash preimage. The full selector
and issuer remain in the correspondence report.

`project_lido_fixture` and `verify_lido_fixture` in `tools.museum.lido` take the
same immutable source plus selection/Linked Art/PREMIS/IIIF/LIDO plans and their
expected hashes. The four pinned validators are supplied explicitly. Verification
rebuilds every output from these inputs; schema-valid substitutions or a
self-rehashed report cannot replace that check. Every mapped value has original
selector, pointer, issuer and final XML XPath provenance. Paths are resolved
after the complete sibling set exists. The entire prior source inventory,
including nulls, absent fields, array positions and unmapped claims, is retained.

Use the [isolated Python environment](../tools/museum/README.md):

```text
python -m tools.museum.lido_model --check
python -m unittest tools.museum.test_lido_model tools.museum.test_lido -v
```

The [public example inputs](../schemas/museum/lido/example/source-state.json)
contain declarations rather than real media, chain or ownership evidence.
Creator truth, copyright authority, media retrieval, actual fixity verification,
indexed dates, additional languages, complete work-description/absence rules,
registered profiles, institutional ingest and all remaining Museum gates stay
required work. No LIDO record license is inferred from an IIIF Manifest license.

Original LIDO notices identify CC BY 4.0. GML/SMIL/XML/XLink retain their original
copyright notices inside the exact schema chunks. The full applicable OGC and
W3C notices are retained in [licenses](../schemas/museum/lido/licenses).
The OGC notice is a complete text extraction with explicit provenance; original
schema documents are unmodified.
