# Candidate semantic resource projection

`tools.museum.projection` builds deterministic Linked Art resource bytes from
explicitly selected canonical semantic records in a synthetic source snapshot.
It composes canonical review/selection, declaration identity, the schema-derived
inventory, finite vocabulary checks and the pinned offline Linked Art validator.
The output is an intermediate projection with original-source sidecars. It is
not a registered `STREAM_SEMANTIC_EXPORT_V1` manifest or an authenticated chain
export. It makes no full Museum conformance or Linked Art HTTP API claim.

The three existing top-level schema definitions are unchanged. The candidate
[crosswalk](../schemas/museum/projection/crosswalk.json) is a separate definition
document. It binds the exact assertion schema ID and bytes, selectors, kind,
target, cardinality, transformation, authority rule, uncertainty/reverse policy
and named test pairs. It has no final parent `profileHash` field. An execution's
projection plan binds an already selected profile hash without introducing a
definition-document hash cycle.

## Inputs and authority

`project_fixture` takes immutable source state, canonical selection-policy bytes,
canonical projection-plan bytes and the expected hashes of both. The plan binds
the source-state commitment, profile, selection policy and exact crosswalk. Its
`entityAuthoritySet` contains complete eleven-field declaration selectors. Each
selected declaration must match the enclosing record's schema, subject and
fixture issuer facts. Its `declaringAgent` must equal that issuer. Same-IRI
selected declarations are ambiguous and reject even when their kinds agree.
Selection order does not confer authority or resolve a collision.

Only `FixtureSourceAdapter` input is supported here. Its source commitment binds
the bytes and supplied fixture authority facts; these facts do not establish
actual catalog membership, signatures, accepted onchain records or finality.
Root's real source adapter remains a separate requirement. Declared external
entities are explicit `{id, kind}` plan entries; their IRIs and kinds are not
inferred from URI spelling, a title, a wallet or a Getty identifier.

The function invokes canonical assertion selection internally. Merely supplying
a review record, a reviewer name or `reviewStatus` does not select it. Reviewed
mappings retain their exact admitted review backlinks and source authorship.
Ineligible and conflicted claims remain in the sidecar, and conflicting eligible
single-valued claims do not produce that resource property. Direct statements
retain their different admission basis. Neither basis asserts universal truth.

## Current resource rules

The explicit kinds `visual_content`, `digital_object`, `physical_object`,
`person`, `group`, `place` and `set` produce, respectively, VisualItem,
DigitalObject, HumanMadeObject, Person, Group, Place and Set resources. Every
resource is independently shape-validated and expanded using the accepted
versioned interpretation policy and pinned original context. Its expanded class
must equal the crosswalk's exact CRM/CRMdig/Linked Art class.

Generic information, token, realization, event and statement entities remain
typed Stream extensions. Where the source kind supports it, the extension also
states E73 Information Object or E5 Event. Generic sound/software is not converted
to visual or linguistic content, and a generic event is not assumed to be an
Activity. These are temporary limits of the current executable rules; the full
adopted media/event crosswalk remains required.

`abstract_work` currently remains a typed extension with E89 Propositional Object.
The pinned context defines PropositionalObject, but the retained thirteen-schema
upstream root contains no abstract-work shape. The first projection attempt
failed that validator. The extension makes no upstream shape-validation claim.
A separately versioned [v2 supplement and resource rule](museum-abstract-nonvisual-projection.md)
now provides that representation and explicit linguistic-content specialization.
Selecting it requires new crosswalk and validation-policy hashes; v1 output is
unchanged. Substituting a carrier or Set would change the source meaning.

For compatible selected resources, four exact entity predicates are currently
copied: `digitally_shows`, CRM P65 `shows`, P138 `represents`, and P129 `about`.
The finite vocabulary checks their explicit domain/range constraints before
emission; the actual Linked Art validator then checks their shape. A recognized
predicate with an incompatible supported target rejects. A relationship involving
an extension kind remains a precise typed assertion in the sidecar. Depiction
does not create a `took_place_at` event location. No production, capture, receipt,
custody, title, authorship or geographic match is invented.

Names retain source order, duplicates and exact content. The `identifier` kind
becomes Identifier; the other name kinds become Name. Preferred/alternate/
historical distinctions and language remain in the original sidecar unless an
explicit later controlled-term rule projects them. `_label` is only a display
aid: it uses the first supplied name, or the exact stable identifier when names
are absent. It is not a newly authored statement. A decimal-looking title and a
uint256-sized identifier remain exact strings.

## Coverage and provenance

The declaration, source-assertion and reviewer policy sets determine the complete
record inventory scope. Each such record's entire canonical payload validates
before its inventory is counted. The denominator includes actual structures,
array positions, nulls and applicable absent fields. Every row is classified as
`mapped` or `retained_stream_only`, with its exact bytes and a rule/reason.
`mapped` means the source field contributes to the declared transformation; it
does not imply that the Linked Art field alone preserves every source nuance.

Every emitted source-derived path carries the exact source record/declaration
selector, source pointer, mapping rule and admission basis. Reference types also
cite the selected target declaration, or the exact external-kind plan. Context
paths separately cite the pinned interpretation policy. All original public
payload/schema bytes and authority evidence remain in the sidecar; selected and
withheld assertions retain their original bodies and review evidence.

Entire unselected public records remain opaque sidecar bytes with diagnostics.
An unselected malformed declaration cannot veto a valid selected resource.
Selecting a record requires its complete canonical payload to validate; malformed
unselected entries inside that same selected payload are not separately admitted.
Restricted records' identifiers and content are omitted from all public outputs.
This intermediate object does not yet provide a complete disclosed-scope chain
proof, package dependency copies, BagIt/dossier manifest or OCFL history.

Resources, source rows, coverage and provenance have deterministic ordering.
Different exact plan/source identities still produce different report hashes
even when the resource graph is equal. The report commits to each resource and
expansion, the sidecar, coverage, provenance and pinned interpretation identities.
It does not include its own hash or a subsequently published export record.

## Running and remaining work

Use the isolated environment and pinned installation instructions in
[the tooling README](../tools/museum/README.md). From the repository root:

```text
python -m unittest tools.museum.test_projection -v
python -m tools.museum.projection --check
```

The module command checks the definition crosswalk. Its Python API returns
immutable resources and intermediate report bytes; a filesystem package/export
entrypoint is subsequent work. The profile currently bounds source records,
selected declarations and external entities to 512 each, total public input
bytes to 16 MiB and encoded output to 64 MiB. Individual resources remain subject
to the validator's 24,576-byte input limit. These implementation bounds fail
explicitly and do not establish a wall-clock complexity guarantee.

The complete source-family crosswalk, abstract-work supplement, linguistic and
activity specializations, dates, exact measurements, technical/media history,
rights/accession/custody, authority snapshots and complete package reconstruction
remain required. All twelve adopted Museum gates and all eight complete scenario
obligations remain open beyond the evidence supplied by these focused tests.
