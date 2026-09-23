# Museum schema and offline source boundary

Implementation decision for MUSEUM-01 and MUSEUM-03, under ADR 0036. The complete
twelve MSM gates and eight required media/history scenarios remain the delivery
scope. This first executable increment is a schema, source-adapter and verifier
foundation. It is not a schema registration, recorded dossier, institutional
ingest, or completed Linked Art conversion.

The three documents are named exactly `STREAM_MUSEUM_SEMANTIC_PROFILE_V1`,
`STREAM_SEMANTIC_ASSERTION_V1`, and `STREAM_SEMANTIC_EXPORT_V1`. Their protocol
IDs are keccak256 of those UTF-8 names. Documents use JSON Schema 2020-12 and
RFC 8785 canonical bytes. The profile document carries machine-readable
`x-stream-profile` annotations committing to bounded crosswalk, vocabulary,
selection and validation documents. `profileHash` is the keccak256 of this
registered profile schema document; the document does not contain its own hash.
Assertion and export documents are self-contained and do not fetch schemas.
Changing interpretation requires a new version; no registration is fabricated.

Dependency documents are addressed by exact byte hash and a package-relative
path, with original URI, media type, retrieval time, upstream version/commit and
reuse attribution. An index binds the complete ordered list of chunks for each
logical document, its total length and whole-document hash. Raw chunks are at
most 8,192 bytes, including the final short chunk. The proposed JSON chunk carrier
also checks the complete encoded payload against the current SSTORE2 data bound
of 24,575 bytes (the STOP byte occupies the remaining EIP-170 byte), accounting for
hex expansion and metadata. The record-level 24,576 cap is a separate check.
Root must bind the actual existing onchain carrier;
raw chunk arithmetic alone is not payload admission. Initial operational limits are
512 logical documents, 4,096 chunks, 16 MiB aggregate bytes, 8 dependency edges
of reference depth, and 64 JSON nesting levels. The captured Linked Art context
is 79,235 bytes and needs ten raw chunks under this operational partition. No alteration or truncation is
permitted. These aggregate limits are separate from onchain admission.

Root's selected native document interface uses `DocumentSpec` (exact name, kind,
content hash, canonicalization definition ID, predecessor ID, URI and byte count)
plus ordered chunk hashes. Its approved per-document bound is 64 raw chunks,
524,288 bytes, with exact 8,192-byte nonfinal segments. The 434,213-byte CRM
dependency therefore retains one document identity and original hash across 54
chunks (the last contains 37 bytes). The publication planner only creates
prospective, unregistered metadata. Root owns actual Executor registration,
canonicalization admission and upper-bound execution measurements. Permissionless
chunk upload grants no document authority or accepted-inventory status.

The profile schema and referenced document commitments form an acyclic DAG.
Committed crosswalk, lock and validation documents use schema ID/version and
must not contain their parent's final profileHash. Runtime assertions/reviews
and export manifests pin the already-established profileHash separately.

The standards baseline is CIDOC CRM 7.1.3, Linked Art Model 1.0.0 and JSON-LD 1.1.
The exact context, scoped contexts, selected class/property definitions,
validation schemas and term catalogs must be retained. Source URLs do not imply
live resolution: verification has no network loader. Full JSON-LD expansion and
Linked Art model validation are separate checks, never inferred from JSON shape
or canonicalization. Archival URNs do not imply Linked Art API conformance.

The Python source adapter exposes frozen typed values for a source-state
binding, record identity, immutable canonical payload bytes, schema bytes and
hash, accepted recorder/family authority evidence, record-chain position and
disclosure decision. Protocol integers remain canonical decimal strings until
checked conversion to arbitrary-precision integers; addresses and byte strings
use exact lowercase hex. CMC token/media/scope/collection subject and record-chain
preimages retain their existing ABI widths and domains. Existing payload bytes
are checked independently; they are never rewritten into the new encoding.

There are distinct input routes. Fixture snapshots are explicitly synthetic and
cannot claim authenticated chain state. Draft previews have stable entity IDs
but no fabricated chain/signature/finality fields. A future recorded-state
adapter must independently establish exact host/pointer/payload, family
authority and complete lane heads at one block. A JSON `verified: true` field
cannot promote either earlier route. Root owns that onchain adapter and five
record allocations; this increment writes no contract state.

Projection selection is committed with the source-state identity and exact
record/field selectors. Eligible direct statements may project. Mappings need a
separately authenticated review of the exact assertion revision, profile and
rule. The reviewer comes from their own accepted evidence, not a name in the
mapping payload. Author-confirmed self-review is explicit; independent review
requires another authenticated agent. Eligible competing single-valued claims
withhold the affected triple. Unselected disputes and hostile IRI declarations
remain attributed diagnostics but cannot erase an eligible artist claim. No
address list grants authority beyond the source adapter's accepted family scope.

Coverage is computed from the pinned source schema plus complete source bytes,
before projection. It includes object/array structure, repeated entries, array
order, optional absence versus null, and exact values. Every in-scope path must
have an explicit mapped/retained/not-applicable disposition with rule/reason;
missing public source bytes are errors. Disclosure filtering precedes all
component generation; withheld markers carry no restricted values or hidden
identifiers. Extra or missing coverage rows fail. Schema shapes unsupported by
the inventory engine fail closed instead of shrinking the denominator.

The fixture ledger contains all eight required scenarios from MSM-CONFORMANCE:
photograph/carriers/two prints; written interview; AV interview; software or
interactive work; historical/disputed geography; incomplete/conflicting
documentation; independent curator/artist accounts; offline archive/profile
revision. Early tests exercise adapter/coverage/selection mechanics against
explicit synthetic source schemas. They do not declare existing CMC family
schemas registered or complete. Faithful projection, all source-family schemas,
cross-format output and external institutional evidence remain necessary.

Primary sources read: [Linked Art model](https://linked.art/model/),
[digital resources](https://linked.art/model/digital/),
[attributed assertions](https://linked.art/model/assertion/),
[JSON-LD serialization](https://linked.art/api/1.0/json-ld/),
[CRM 7.1.3](https://cidoc-crm.org/Version/version-7.1.3),
[JSON-LD 1.1](https://www.w3.org/TR/json-ld11/), and
[RFC 8785](https://www.rfc-editor.org/rfc/rfc8785).
The finite limits, source-adapter trust split and schema annotation layout above
are Stream implementation choices, not claims those standards prescribe them.
