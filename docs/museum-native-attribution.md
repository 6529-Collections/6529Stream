# Native Artist and general attestation evidence

The additive [physical-production export](museum-recorded-physical-production-v1.md)
consumes this exact dossier and its selected original Artist statements. It maps
only explicit completed physical production, preserving source definitions and
keeping custody, title and accession separate.

`STREAM_MUSEUM_NATIVE_ATTRIBUTION_DOSSIER_V1` is a supplementary, source-preserving
attribution package. It joins original native Artist evidence to Metadata records,
optionally interprets an explicitly registered semantic profile, and optionally
includes the additive [general attestation producer](integrations/general-attestations.md).
It does not establish named people, institutions, legal identity, independent human
review, current signing permission or full Museum dossier conformance.

The implementation has synthetic positive and negative replay controls. Genuine
current deployment capture and coordinated contract execution remain separate
validation requirements. Previously published account, independent-attestation,
schema and dossier profiles retain their original bytes and meaning.

## Original Artist authority

`tools.museum.artist_attestation_source.ArtistAttestationSource` requires a
concrete, complete `MetadataCatalogSource`. Its scope is **every class-1 receipt
backlink in that supplied collection**, including statements outside the semantic
schema. It is not a complete global Artist history or a reader for every standalone
op24 attestation.

The reader checks the original publication receipt, native op24 record hash,
statement and signature bytes, immutable archive payload, binding, authority class,
consumed authorization and Metadata publication event. Authenticated delegation
retains its original grant and use even if the current grant is revoked. Original
registration documents and later operative documents remain separate. All values
are retained alongside their exact ABI bytes or original structured values.

The source revision is pinned in the read profile. Runtime pins cover the
registry, coordinator, archive, seven owners and all suite dependencies. A complete
bounded genesis-to-anchor header/receipt walk establishes publication order within
the admitted RPC history. The reader refuses oversized histories instead of
silently truncating them. A transcript proves replay consistency; it does not
prove Ethereum consensus or authenticate the RPC operator.

Current identity, binding, attribution, contest and attestation-status reads are
qualifications on the original evidence. They never replace its signer or grant a
new permission. Names are retained as original text; equal names do not merge
identities. Different Artist IDs or accounts do not establish different people.

## Explicit semantic profile and review

`NativeAttributionProfile` constructs prospective registration documents for
`STREAM_MUSEUM_NATIVE_ATTRIBUTION_PROFILE_V1`. It reuses the existing assertion,
profile and review-body schemas and pinned offline model resources, with a new
authority policy and crosswalk. `NativeAttributionSemanticSource` admits a
payload only when its original schema, canonicalization, registered definitions,
profile hash, subject and historical asserting account all agree exactly.

Every referenced record uses a complete original selector, and its publication
must precede the assertion. Evidence hashes and pointers must resolve into those
referenced original bytes. An `own_signed_statement` additionally needs the same
historical signer and a native class-1 Artist receipt. Other unsupported profiles
remain explicitly unsupported beside their original bytes. Malformed data
claiming this supported profile rejects the component.

Selection requires a separately pinned policy naming the exact source and reviewer
sets. Review literals retain the existing format and bind the original assertion
selector, revision, profile and mapping rule. A review must follow the original
publication. Same-Artist review remains SELF across signer rotation; same-account
review remains SELF across Artist IDs. SELF confirmation needs explicit opt-in.
Distinct protocol identities alone cannot satisfy independent human review.

Selected direct statements need no reviewer. A human mapping needs selected,
opted-in SELF confirmation under this limited profile. Unselected disputes do not
veto selected statements. Conflicting selected values have no recency winner.
Current identity disputes remain visible and do not silently rewrite historical
authorship or the selected original review disposition.

## General attestations and notarization

The additive [General semantic reader](museum-general-semantic-v1.md) interprets
explicitly profiled generic statements and joins exact earlier Metadata evidence.
It preserves General authority separately from Artist and Metadata classes;
physical/legal events and institutional identity are not inferred.

`GeneralAttestationSource` independently enumerates all four fixed producer lanes,
including empty lanes, per-recorder heads, signature bundles, native Artist proof,
payload pointers and original definition documents. It preserves these distinct
qualifications:

| Original class | What the receipt establishes | What it does not establish |
| --- | --- | --- |
| `SIGNER_VERIFIED` institutional or estate claim | The original account authorized the exact general-domain request | Institutional status, legal identity or factual truth |
| `OPERATOR_ASSERTED` curatorial claim | The authenticated recorder had the exact collection/family/class grant | A signature or agreement from the separately asserted attester |
| `SIGNER_VERIFIED` Artist history | A new general signature and exact retained native op24 provenance | A new Artist op24 record, current authority, render permission or floor satisfaction |
| Typed identity notarization | The signed payload bound the operative identity record read at publication | Current identity after later rotation, document authenticity or personhood |

Identity references retain all six supported hash forms and exact URI bytes.
The tooling does not fetch their targets. A source package must share the Artist
package's chain, Core, collection, block, state root and configured dependencies.
Conflicting answers to the same read across transcripts reject assembly.
For typed notarizations, the reader also retains the exact historical operative
identity document from the pinned native registry, together with separate current
identity/status and operative-document observations. Later rotation or dispute
cannot replace the document named by the original signed receipt.

`GeneralAttestationSourceV2` selects the explicit
`STREAM_MUSEUM_GENERAL_ATTESTATION_SOURCE_V2` anchor profile and version-2 native
producer. It retains the full payload getter's bytes and checks them against the
complete ordered chunk descriptors, immutable chunk code and full content hash.
The getter's pointer denotes the first chunk; it is not a single-carrier proof
of a larger payload. Every repeated chunk position remains in the record while
the global pointer inventory contains deduplicated real chunk hashes.

Generic institutional, estate and curatorial statements may contain up to
24,576 bytes. Typed identity notarizations and native Artist statements retain
their separate 8,192-byte bounds; native Artist capacity remains pending its
original producer extension. Signature and bundle limits are unchanged. V1 source
and profile bytes remain frozen for existing 8,192-byte producers and packages.
Version selection is explicit, with no failed-read fallback. Existing transcript,
snapshot and package aggregate limits still apply; per-record capacity does not
promise that every maximum-sized catalogue fits one package.
V2 derived textual resources allow up to 155,648 JSON bytes to accommodate the
24,576-byte original, worst-case JSON escaping and resource metadata. The pinned
schema/context validation policy and the validator's default limit are unchanged.

## Package and replay

Python composition:

```python
artist = ArtistAttestationSource(metadata_catalogue, artist_transport)
semantic = NativeAttributionSemanticSource(artist, semantic_transport)
result = write(artist, new_output_directory, semantic=semantic,
    general=general_source, selection_raw=policy_bytes, selection_hash=policy_hash)
```

`write` is in `tools.museum.attribution_dossier`. Semantic interpretation, selection
and the general source are optional; their absence is explicit in the package.
Selection requires semantic interpretation. A general source is a concrete
`GeneralAttestationSource` or `GeneralAttestationSourceV2`, not a caller-written
summary. The anchor selects one supported profile; its exact profile bytes are
retained and committed by the package manifest. Existing V1 package output and
offline replay remain unchanged.

The package retains source anchors, snapshots, transcripts, all original identities
and statements, interpretation documents, selection, coverage and provenance.
UTF-8 statement bytes become Linked Art `LinguisticObject` resources under the
existing pinned offline validator. Binary originals retain complete field coverage
without fabricated textual resources. No Person, Group, legal act or institutional
approval is inferred from the payload or its display names.

Read-only capture takes a canonical JSON plan with exactly `profile`, `metadata`,
`semantics` and `general`. Set `profile` to the dossier name above; `semantics` is a
boolean; `metadata` is a pinned original source object; `general` is another source
object or null. Source objects use the seven external path/hash/provenance fields
documented in [owner notice capture](museum-owner-notice-adapters.md). Existing
source packages replay before additional Artist/semantic RPC reads.

```powershell
python -m tools.museum.attribution_dossier capture --plan <plan.json> --plan-hash <external-keccak256> --rpc-env STREAM_MUSEUM_RPC --output <new-directory>
python -m tools.museum.attribution_dossier verify <directory> --manifest-hash <external-manifest-hash>
```

Keep the returned manifest commitment outside the package. Offline verification
checks the closed inventory and reconstructs every derived byte from concrete
source replay. Rehashing a changed identity, authority, profile, coverage row or
projection cannot bypass reconstruction. Synthetic provenance remains synthetic.
