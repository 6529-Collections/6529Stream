# General institutional and curatorial assertion reader

The General semantic reader reconstructs explicitly profiled assertions from
native institutional, estate and curatorial GeneralAttestations records. It
joins their documentary evidence to exact earlier Metadata records and exports
qualified statements with a complete offline reconstruction package.

This closes a source-reader gap. The existing
[General V2 reader](museum-native-attribution.md#general-attestations-and-notarization)
already checks original receipts, signature envelopes, schema definitions, complete
payload chunks, four record lanes and recorder heads. Its generic payloads were
otherwise opaque text. The new adapter interprets their original assertions
without borrowing Artist-op24 or independent class-5 authority.

The implementation uses the unchanged `STREAM_SEMANTIC_ASSERTION_V1`, profile
and review schemas, existing native General V2 APIs and pinned Linked Art model.
`GeneralSemanticProfileV1` constructs a distinct prospective interpretation
profile using the existing Registry/Store mechanisms. It does not register
documents, alter existing profile bytes or add a governance gate.

## Exact authority and source bindings

| Original route | Authenticated source account | Retained limitation |
| --- | --- | --- |
| `INSTITUTIONAL_VERIFICATION` or `ESTATE_VERIFICATION` | Original `SIGNER_VERIFIED` recorder equals the attester. | Account authorization does not establish institutional standing, legal identity or truth. |
| `CURATORIAL_STATEMENT` | Original `OPERATOR_ASSERTED` recorder and exact historical CURATOR/class-3 grant. | The separately asserted attester and DID are unsigned claim fields. |
| Native `ARTIST_STATEMENT` or typed identity notarization | Their existing native reader still verifies and retains their distinct evidence. | This generic semantic profile does not reinterpret them. |

The outer General occurrence selector retains `verificationClass`,
`authorityQualification`, recorder, original host/record/index/chain hashes and
schema/canonicalization identity. Its authority sidecar retains the original
signature and grant fields. These are not recast as Metadata
`INSTITUTION_SIGNER` or `CURATOR_SIGNER` selector classes.

`GeneralSemanticSourceV1` requires concrete `GeneralAttestationSourceV2` and
`MetadataCatalogSource` inputs with identical chain, Core, collection, block
number/hash, timestamp, state root, environment and shared configured
dependencies. Intersecting runtime pins and repeated observed reads must agree.
Host-specific deployment-evidence commitments remain separate. Provenance is
externally admitted; transcript consistency is not consensus or authentication
of the provider.

For a supported original payload, the adapter verifies:

- Exact original assertion schema, canonical RFC8785 bytes and schema/profile
  subject identity, including collection, token or media subject scope.
- The original payload's profile hash against the new interpretation profile
  and every immutable registered definition and stored chunk in its closure.
- `assertingAgent` and `declaringAgent` against the actual authenticated General
  recorder's account IRI. An account IRI cannot be declared as another entity.
- Every internal top-level and entity `sourceRecords` selector against the
  original Metadata record, payload and receipt.
- Every documentary evidence hash and whole-document or JSON-pointer selector
  against a referenced original payload.

The generic General receipt's `profileDefinitionHash` remains **zero**. The
adapter checks interpretation documents separately against the original signed
or operator-recorded payload's `profileHash`; it does not invent a receipt field
commitment. Other profiles, families and schema/canonicalization combinations
remain explicitly unsupported alongside their complete originals. Malformed
payloads claiming the supported interpretation fail capture.

An empty or unsupported-only catalogue does not need the new interpretation
profile registered merely to retain its originals. Its report explicitly marks
the registered-definition check as not performed; local candidate definitions
remain available for reconstruction. A supported original requires the complete
registered definition check before interpretation.

## Documentary evidence and chronology

Documentary evidence uses the original Metadata payload's Keccak-256 digest and
canonicalization ID. Its exact bytes are already retained in the complete
Metadata source. A source selector or evidence pointer cannot substitute a
different record, recorder, host, schema, hash or missing field. The URI remains
original text; it is not fetched or used as a substitute for bytes.

Every referenced Metadata receipt must have a **strictly earlier recorded
timestamp** than the General receipt. The current General reader does not retain
a cross-host transaction/receipt-position walk. An equal timestamp therefore
fails this profile even if the records might have been ordered within one block.
This is a documented reader limit, not evidence that such a native record is
invalid. `effectiveAt` and assertion `createdAt` are not publication-order proof.

Only `documentary_evidence` with `whole_document` or `json_pointer` selectors is
supported. `own_signed_statement`, page and media-time selectors reject a payload
claiming this profile. The Metadata catalogue alone cannot establish every
possible original signature or the meaning of a page/time selector.

Reference bytes do not establish the instrument's legal validity, its author's
identity or its account's institutional capacity. A typed identity notarization
still retains its four separate external references; this reader does not fetch
their targets or promote them into physical title/custody evidence.

## Selection and qualified export

An externally pinned JCS selection has exactly these fields:

```text
profile                 STREAM_MUSEUM_GENERAL_SEMANTIC_DOSSIER_V1
sourceSnapshotHash      Keccak-256 of the exact semantic snapshot
sourceAuthoritySet      Exact outer General selectors with /assertions/N pointers
singleValuedRelations   Explicit relation IRIs whose conflicting values are withheld
```

Selection admits direct statements that are neither disputed nor withdrawn.
Mapping and review fields remain original source values; this version does not
authenticate reviews or accept a SELF-review shortcut. Conflicting selected
single-valued claims are withheld within their original anchor subject,
assertion subject and relation. There is no recency winner. Unselected statements
cannot veto a selected original, and an original historical statement is not
silently replaced by its recorder's latest head.

Each selected assertion becomes an occurrence-qualified `LinguisticObject`
containing its exact JCS assertion. The stable statement resource ID commits to
the full outer General selector. Original declaration and assertion IRIs remain
in the sidecar; reuse of an IRI does not merge separate accounts or records.

Explicit physical production, custody, title and accession language remains
attributed source content. This reader does not emit a `Person`, `Group`,
`Acquisition`, `TransferOfCustody`, ownership or completed physical event. A later
finite mapping must use an explicit source body and corresponding evidence.
The existing [token accession/title adapters](museum-acquisition-title-v5.md)
and [Artist physical-production export](museum-recorded-physical-production-v1.md)
retain their separate scope. MSM-RELATIONS5, institutional acceptance, and the
nineteen packet groups and forty-nine dossier assessments are not completed by
this prerequisite.

## Offline package and API

The package includes complete native General and Metadata inputs, all original
supported and unsupported records, semantic definition capture, original
selection, statement/declaration sidecars, every original statement leaf,
per-leaf graph provenance and exact offline model dependencies. Source pointer
bases are explicit in `source/locations.json`. Verification replays both native
sources and the semantic definition reads, then regenerates every output byte.
Editing a graph, authority field, source snapshot or coverage row and recomputing
the manifest is insufficient to pass verification.

```python
source = GeneralSemanticSourceV1(metadata_source, general_v2_source, transport)
snapshot = source.snapshot()
result = general_semantic_dossier_v1.build(
    source, selection_bytes, selection_hash, disclosure="public")
checked = general_semantic_dossier_v1.verify(dict(result.files), result.manifest_hash)
```

The transport supplies the separately captured definition reads. The CLI accepts
offline inputs through a pinned replay plan, with exactly `profile`,
`provenance`, `metadataAnchor`, `metadataTranscript`, `generalAnchor`,
`generalTranscript`, `semanticTranscript` and `selection`. Each of the six input
references has exactly `path` and `hash`, relative to the plan directory.
`profile` is the dossier profile above; `provenance` is `synthetic_fixture` or
`trusted_rpc` and must preserve the input's admitted origin.

Public disclosure is required before reads. Output must be a new directory
outside the replay-plan input directory. No command fetches external resources,
executes contracts or publishes a record.

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.general_semantic_dossier_v1 profiles

.\.venv-museum\Scripts\python.exe -m tools.museum.general_semantic_dossier_v1 replay `
  capture/plan.json general-semantic-export --plan-hash $planHash --disclosure public

.\.venv-museum\Scripts\python.exe -m tools.museum.general_semantic_dossier_v1 verify `
  general-semantic-export --manifest-hash $manifestHash

.\.venv-museum\Scripts\python.exe -m unittest tools.museum.test_general_semantic_v1
```

Synthetic fixtures exercise concrete source, definition, signature-preimage and
chunk reconstruction. They do not establish deployed acceptance, independent
institutional review, legal effect or observed physical custody.
