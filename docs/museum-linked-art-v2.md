# Versioned Abstract Work validation profile

The candidate v2 interpretation admits the separately published Abstract Work
shape, with PropositionalObject / CRM E89 as its own class. It preserves the
accepted v1 original documents, interpretation policy and derived hashes.
Selecting v2 requires its different policy hash and dependency closure; a newer
website response cannot change v1 verification.

The source lock is Linked Art commit
`bcbff1761e65f44eeaeb92b4b2b83da2783539f8`. It contains fourteen JSON schemas,
including the upstream abstract-work schema, plus the unchanged 79,235-byte
context. The schema dialects now use `$defs`; the older thirteen-document v1
closure remains separate. Context equality does not imply shape-policy equality.
The [candidate v2 policy](../schemas/museum/linked-art-v2/validation-policy.json)
pins every original schema and the supporting endpoint text by content hash.
Its index retains original bytes in bounded chunks, provenance and license.

The official [Abstract Work endpoint](https://linked.art/api/1.0/endpoint/abstract_work/)
identifies conceptual works separately from their manifestations. Its property
table treats `equivalent` as identifiers for the current work. This supports two
narrow, explicit interpretation repairs:

1. The published aggregate `linked_art.json` omits the separately published
   abstract-work schema. V2 appends its exact reference to `/anyOf` only when the
   whole original source hash and exact prior eleven-element array match. An
   existing entry, changed ordering, wrong pointer or arbitrary branch rejects.
2. The abstract-work schema's equivalent-item reference points to the linguistic
   class, although the same source closure supplies `AbstractWorkRef`. V2 replaces
   only `/properties/equivalent/allOf/1/items/$ref`, requiring its exact original
   value and source hash. Same-work PropositionalObject references become valid;
   LinguisticObject, Person, carriers and Set do not become interchangeable.

Original source text and its copied linguistic-description annotation remain
unchanged in the retained original. The derived interpretation and repair policy
are separately hashed. No generic alias or whole-schema text substitution is
applied. The v1 interpreter does not enable the new root-append operation merely
because a caller supplies it in a v1 policy.

The same pinned `object.json` also contains two ordered `used_for` members at
`/properties/used_for`: one references `core.json#/$defs/used_forProp`, and the
other declares an Activity array inline. Ordinary strict JSON parsing rejects
this source. V2 has one separate schema-only interpretation rule. It reads raw
ordered member pairs, verifies the entire original document hash, exact pointer
and exactly two expected values in order, then derives `allOf` containing both
constraints and annotations. It never chooses a first or last value. A third,
swapped, missing or changed member, another duplicate anywhere in the document,
or a different source hash rejects. Original records, contexts and ordinary
dependencies keep their strict duplicate-key rejection. This interpretation
does not assert that the original ambiguous document was valid JSON Schema.

Construction checks the complete local reference closure, including definitions
unused by examples: all 837 references in the fourteen derived schemas resolve.
Validation still uses the exact single context URI, a fresh
PyLD context resolver per operation, explicit URI/date-time formats and no remote
loader. The established no-leap-second and exact-number limitations remain
explicit. The pinned endpoint support document is checked as a dependency; it is
not a live URL consulted during validation.

This is a shape/expansion capability. It does not establish that a declared work
exists, that an equivalence is true, or that the issuer is authorized. Canonical
source selection and any required review still precede projection. The separate
[v2 content crosswalk](museum-abstract-nonvisual-projection.md) selects this policy
to turn an explicitly declared abstract work into a resource. Historical v1
packages continue to reproduce their original extension output.

Run the focused checks in the pinned environment:

```text
python -m unittest tools.museum.test_linked_art_v2 -v
```

This archival profile permits stable URNs under the adopted Stream identity
rules. It makes no Linked Art HTTP API claim. The complete Museum source-family
crosswalk, package disclosure proofs, remaining media/history scenarios and
institutional acceptance remain required.
