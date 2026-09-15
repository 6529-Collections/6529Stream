# Museum offline Linked Art validation boundary

The candidate validation policy pins the exact Linked Art context, thirteen
original JSON Schema documents, the PyLD 3.3.0 processor, an explicit format
profile, and three exact schema interpretation repairs. Original bytes remain in finite local chunks with whole
hashes and upstream provenance. The context is the 79,235-byte document from
Linked Art commit `a3b57fae50f9be9b0c15d4c7d5d61eb65a3596e8`; schema documents are
from that same commit. Each schema keeps its declared `$id` and exact source
path, including the upstream root filename `linked_art.json` whose `$id` uses
`linked-art.json`. Schema references resolve by declared identity, not filenames.

The first defect in those upstream bytes is in `core.json`, which
declares draft 2020-12 while
`/definitions/ContextStringOrArray/anyOf/1/items` is a legacy tuple-schema array.
The candidate policy translates that exact `items` field to `prefixItems` in a
derived in-memory schema. It requires the pinned whole source hash, exact
pointer, exact old array `[{"type":"string","format":"uri"}]`, and absent
`prefixItems`. Missing, changed, duplicate or unapplied repairs reject. The
derived schema has its own canonical hash and the policy records the repair;
it never replaces the original document or claims unmodified upstream validation.

This translation retains tuple semantics: only the first array item is
URI-constrained, while subsequent items keep the original default allowance.
The current generated-document profile independently permits only the single
exact pinned context URI. It rejects context arrays and document-local context
overrides before expansion. That restriction is distinct from the interpretation
repair and is not used to excuse a broken schema validator.

Two additional repairs apply only at
`/definitions/RightAcquisition/properties/establishes/items/$ref` and
`/definitions/RightAcquisition/properties/invalidates/items/$ref` in the pinned
`provenance.json`. Their exact original value is
`core.json#/definitions/LegalRight`, but the pinned core defines only `Right`
with class `crm:E30_Right` and type constant `Right`. The
[published rights model](https://linked.art/model/provenance/rights/) also uses
`Right` in these relations. The candidate interpretation replaces those two
exact values with `core.json#/definitions/Right`. Each rule is guarded by the
whole original source hash, exact pointer and old value. There is no general
`LegalRight` alias or modification of original source bytes.

At construction the validator checks each declared dialect and every reference
in every derived schema, including definitions no current example uses. A
missing document, absent pointer or nonschema target rejects the whole profile.
This interpretation supports root schema IDs and local-document JSON-pointer
references; nested IDs, named anchors and dynamic references reject. Reference
cycles between semantic definitions are permitted and checked without recursive
target expansion. They are distinct from the acyclic document-hash dependency
graph. Every reference and target location is retained for inspection.

Document shape uses explicit URI and date-time validators, independent of
optional packages elsewhere on the host. Both consume the exact input, rejecting
trailing newlines and whitespace without trimming. The pinned date-time validator
supports ordinary RFC 3339 calendar instants, including lowercase `t`/`z`, but
does not support leap seconds. Leap-second and uncertain source dates remain
unchanged in original evidence; a faithful projection needs a separate policy.
PyLD expands the accepted document using a per-operation context resolver/cache
and the already-pinned context bytes. No global URL cache or network fallback can
substitute another profile's context. A later same-URI/different-hash synthetic
context is tested independently; the original profile continues to produce its
original expanded bytes.

The first supported derived documents use exact strings and safe integers.
Floating-point values and unsafe JSON integers reject before processing. Exact
source numeric bytes are retained separately and are never coerced into this
profile. A faithful numeric projection adapter remains necessary for dimensions
and other fractional values; passing these relation tests does not close that
requirement. Uncertain dates likewise cannot be coerced into RFC 3339 timestamps.

The executable controls cover actual digital Creation and asserted place,
physical Production, distinct physical/digital visual-content relations, unknown
properties, relative identifiers, context overrides, complete reference closure,
hash changes, all repair preimages, document ordering, and `RightAcquisition`
establishing and invalidating distinct synthetic rights. They do not prove
authorship, custody, receipt, authority matches, source coverage or institutional
acceptance. Class/domain/range checking is a separate candidate vocabulary step;
the complete exporter will compose both with exact selected assertions and
coverage records. All twelve museum gates and eight complete scenarios remain.

The developer setup and exact dependency commands are in
[the tooling README](../tools/museum/README.md). Primary sources are the
[Linked Art schemas](https://linked.art/api/1.0/schema/),
[JSON-LD 1.1 processing specification](https://www.w3.org/TR/json-ld11-api/),
[JSON Schema 2020-12](https://json-schema.org/draft/2020-12), and
[PyLD](https://github.com/digitalbazaar/pyld). The explicit repair and restricted
current document profile are Stream implementation choices.
