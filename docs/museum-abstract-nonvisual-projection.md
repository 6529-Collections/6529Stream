# Abstract works and nonvisual content

`ProjectionProfileV2` adds faithful abstract-work and explicit content rules to
the public-fixture projection. It uses a distinct [crosswalk](../schemas/museum/projection/crosswalk-v2.json)
and [pinned validation interpretation](museum-linked-art-v2.md). The adopted
profile's distinction between works, content and carriers controls these rules.
This increment does not change any of the three top-level Museum schemas,
source authority, signing or record mechanisms. It does not register a profile,
authenticate chain state, or implement a new package format.

An `abstract_work` declaration now produces an independently shape-validated
PropositionalObject / CRM E89 resource. A DigitalObject remains a different
entity. The projector never invents a conception for every file or substitutes
a carrier, Set, event or visual work for an explicitly declared conception.
Names and `about` relationships retain their exact source provenance; an
`about` statement does not become an event location or a statement of production.

The existing entity vocabulary deliberately has no blanket linguistic kind.
A generic `statement` or `information_object` therefore stays generic unless an
eligible, selected assertion explicitly specializes it. The versioned relation
`urn:6529stream:museum:content-kind:v1` uses the ordinary assertion literal with
datatype `http://www.w3.org/2001/XMLSchema#string` and null language, unit and
precision. Its exact lexical values have these meanings:

| Value | Eligible declared kind | Output |
| --- | --- | --- |
| `linguistic` | `statement` or `information_object` | LinguisticObject / CRM E33 resource |
| `nonlinguistic_sound` | `information_object` | Explicit E73 extension in the source sidecar |
| `software` | `information_object` | Explicit E73 extension in the source sidecar |
| `structured_multimedia` | `information_object` | Explicit E73 extension in the source sidecar |

Unknown values, noncanonical qualifiers and incompatible selected declarations
reject. These are authored semantic assertions, not guesses based on names,
MIME types, code readability, a wallet, or an identifier. The projection does
not independently certify their truth. A human or automated mapping still needs
its selected review under the existing policy; supplying a content-kind literal
does not bypass that admission.

Every v2 selection policy must include both the content-kind relation and CRM
`P190_has_symbolic_content` among its single-valued relations. Conflicting
eligible kinds withhold the specialization while preserving both exact claims;
the generic entity remains in the sidecar. Conflicting eligible text withholds
the `content` field while retaining an independently admitted linguistic class.
Equivalent declarations may contribute multiple provenance rows. Input ordering
does not choose one of two meanings. Unselected hostile records remain opaque
diagnostic inputs and cannot veto an otherwise valid projection.

For an explicitly linguistic resource, an eligible P190 literal with exact
`xsd:string` and null qualifiers maps its `lexicalValue` to `content`. Unicode
composition, newlines, decimal-looking writing and uint256-sized strings remain
unchanged. Non-null language, precision or units are meaningful: this finite
plain-string path retains such assertions in the sidecar instead of dropping
their qualifiers. A future qualified-text rule requires its own explicit mapping.

`digitally_carries` and CRM P128 `carries` may reference explicitly linguistic
content, after the pinned vocabulary and shape checks. A nonlinguistic E73
reference remains the precise original typed assertion with
`retained_stream_only`; it is never forced through the upstream textual-carrier
shape. A composite may have separate visual, linguistic and E73 content
identities. No inferred equivalence merges them. Duration, execution-environment,
technical-description and byte-derivation facts remain exact sidecar values
where this finite crosswalk has no faithful standard path.

Source accounting still inventories the entire selected canonical record before
projection: structures, ordered array entries, nullable and absent fields and
every exact scalar remain present. Every projected source field has a complete
record selector, pointer and rule. Specialized resource types and carrier
reference types also cite their admitted content-kind evidence. The sidecar
retains original source/schema/authority bytes, selected and withheld assertions,
and the source evidence of every E73 specialization. Shape success does not
turn fixture authority facts into recorded-chain evidence.

The [public example](../schemas/museum/projection/nonvisual-example/assertion.json)
contains a conceptual work, transcript, recording, physical paper, software
content and project carrier with distinct identities. Its readable assertion
bytes equal the payload retained in the adjacent `source-state.json`.
`selection-policy.json` and `projection-plan.json` bind the exact fixture state
and new crosswalk. These are synthetic, unregistered examples, with no private
institutional source or actual accession/authority claim.

Use the [pinned environment](../tools/museum/README.md):

```text
python -m tools.museum.projection_v2 --check
python -m unittest tools.museum.test_linked_art_v2 tools.museum.test_projection_v2 -v
```

The Python `project_fixture` API accepts `ProjectionProfileV2` with the exact new
crosswalk, validation and vocabulary hashes; its plan version is `2`. The
existing package CLI remains explicitly v1. Historical v1 crosswalk, schema,
context and package bytes continue to verify, including the accepted package
example's external manifest commitment. No new dependency package is required.

This increment completes these bounded projection rules, not the full source
family crosswalk, technical-media mappings, recorded-state adapter, BagIt/OCFL/
dossier formats, or institutional acceptance. All twelve Museum gates and all
eight full media/history scenarios remain required by the adopted delivery scope.
