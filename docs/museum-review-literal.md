# Museum semantic review literal

This versioned interpretation defines an authenticated review statement inside
the existing `STREAM_SEMANTIC_ASSERTION_V1` structure. It adds a subordinate
validation document, not a fifth assertion lane or a fourth top-level Museum
payload. Registration authority for this interpretation does not confer review
authority. The first executable resolver uses synthetic fixture evidence; actual
record-family authentication and publication ordering remain adapter obligations.

The proposed normative join for MSM-ASSERTIONS is:

> A semantic review statement must use relation
> `urn:6529stream:semantic-review:v1` and a typed literal with datatype
> `urn:6529stream:datatype:semantic-review:v1`. Its exact canonical lexical body
> must bind the complete original assertion record selector, including its field
> pointer, the hash of that assertion revision, the selected profile hash, mapping
> rule and review disposition. The review's subject must be the original assertion
> IRI. The reviewer's identity and time are the enclosing authenticated assertion's
> asserting agent and creation time. Its origin is `direct_statement`; establishing
> that the reviewer made this statement must not recursively require a review of
> the review. The enclosing review record's selector is resolved externally after
> publication and must never appear as a self-record commitment in its own body.
> A later `reviewEvidence` backlink must match that exact authenticated review
> record and its original target. Self-review is derived from the authenticated
> original and reviewer identities; the backlink's Boolean must agree. Eligibility
> and effect still require the selected profile's source/reviewer authority policy.
> Unselected review statements remain attributed diagnostics and cannot veto the
> default projection.

The body validation document is `STREAM_SEMANTIC_REVIEW_BODY_V1`. Its exact fields
are `assertionRecord`, `assertionRevisionHash`, `profileHash`, `mappingRule` and
`disposition` (`reviewed` or `rejected`). The original selector uses the same
eleven fields as the existing canonical schema. The original revision hash is
keccak256 of the exact canonical assertion object, while the record selector
retains the separate original record hash and payload/schema history. A body
does not contain its own `reviewRecord`, reviewer name or `selfReview` flag.
Language, unit and precision of this structural JSON literal must be null.
The enclosing assertion uses mapping rule
`urn:6529stream:museum:mapping:review-statement-v1`.

The top-level assertion schema remains byte-identical. The resolver validates
both complete source assertion payloads against those exact bytes, then the
subordinate body and existing canonical `reviewEvidence` shape. The later
backlink's reviewer and time must agree with the authenticated enclosing review
assertion. Merely supplying those fields in a different record is insufficient.
Changing the original selector, revision, profile or mapping rule prevents reuse,
including a later record carrying identical assertion text.

The original assertion must already have been published. Synthetic tests supply
explicit block/transaction/log positions through their fixture adapter evidence
and require the original position to precede the review. These values are not
derived from payload timestamps or compared across unrelated per-lane counters.
The real chain adapter must authenticate the positions and enclosing family
authority at the bound source state. An opaque `recorded_state` mode value is
rejected by the fixture resolver.

Resolution returns the body's disposition and derived self-review status; it
does not independently admit a reviewer to a selected authority set or convert
a rejection into approval. Restricted records are
unavailable to this public resolver, and no unavailable-record identifiers are
included in its error output.

`semantic_selection.select_canonical_fixture` composes this resolver with an
explicit policy instance. The policy binds the source-state commitment, profile,
exact source/reviewer selector sets, single-valued relations and whether review
must be independent. The instance is hash-pinned separately from the reusable
selection definition. The fixture state commitment is reconstructed from its
immutable record tuples before use, so replacing records while retaining an old
state hash fails.

Non-withdrawn direct statements need no review. Mappings require an approving
review from the selected reviewer set. Author-confirmed self-review can qualify
when that policy allows it and keeps that explicit label. Selected conflicting
review dispositions withhold the mapping; an unselected rejection has no effect.
Competing eligible values for a policy-declared single-valued relation withhold
the affected claims without choosing the later author. Results retain complete
original selectors and assertion bytes, including multiple sources with equal
text, rather than reducing provenance to an assertion-byte hash.

Unselected public records are not interpreted for eligibility and remain opaque
sidecar inputs with diagnostics. Their malformed or hostile claims cannot veto
selected statements. Restricted records are omitted from public diagnostics.
This boundary validates the complete canonical payload of each selected record;
it does not independently admit a malformed unselected assertion within that
same selected payload. Such a selected-record validation failure remains an
explicit input error.
This is still fixture authority and publication evidence, not verification of
the actual catalog's four assertion lanes. The real adapter must establish that
admission before it can drive the same policy semantics. The resource/sidecar
package builder remains a separate composition step.

Run `python -m tools.museum.review --check` to check the exact subordinate schema,
or omit `--check` to regenerate it. No command registers a schema or appends a
review record. The top-level schemas and existing fixture selection engine remain
unchanged.

The profile commits to the relation/datatype and validation document. Those
definition documents contain no final parent profile hash. Individual review
instances refer to an already selected profile and original assertion. Later
backlinks refer to the published review, preserving an acyclic commitment graph.
The full projection, actual-chain authority proof and Museum conformance gates
remain separate from these payload-resolution tests.
