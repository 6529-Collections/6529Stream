# Conservation record JSON

The three linked serializers produce complete, deterministic JSON for
`STREAM_ARTIST_INTENT_V1`, `STREAM_ARTIST_INTENT_WAIVER_V1` and
`STREAM_ARTIST_INTERVIEW_V1`. They implement the named fields in
[CMC-ARTIST-INTENT](../collection-metadata-contract.md#artist-intent-records-cmc-artist-intent)
and the interview requirements in CMC-GENESIS-SCHEMAS rule 5. This is a pure
interpretation. It does not publish records, establish artist authority, select
a current statement, prove archive coverage or make a finality decision.

Use `StreamConservationRecordTypes` as the complete witness. Each serializer
exports `serialize(witness) -> bytes` and `requireExact(witness, stored) ->
bytes32`. The latter compares the entire serialized and supplied payload,
including length and every byte. Every outer witness requires nonzero subject,
the exact generated profile hash and an explicit predecessor, where zero means
JSON `null`. The consumer must verify the actual original record and predecessor.

| Type | Complete meaning |
| --- | --- |
| `Intent` | Claimed artist association/origin, six separate display references for scale, timing, color, interaction, motion and frame rate; variability tolerances; dependency aging covering migration/emulation/reinterpretation; significant properties; mandatory interview entry. |
| `IntentWaiver` | Claimed artist association/origin, explicit waiver statement reference and a separate mandatory interview entry. An intent waiver does not imply an interview waiver. |
| `Interview` | VMQ or named derivative instrument/document, all participant roles/identity references, exact Gregorian date, all BCP47 language tags, required transcript and declared format, and every optional audio/video capture with its own content and format. Empty captures is explicit. |

An interview entry is either `present`, with a concrete chain/Core/host/original
record hash, the exact interview schema ID/profile hash, and a separate archived
payload reference; or `interview_waived`, with an explicit statement reference.
Every inactive Solidity field must be zero or empty. An omitted, all-zero or
mixed entry fails. The PRESENT profile pin establishes this interpretation's
expected version, not existence or truth of the referenced record.

The VMQ instrument has no derivative name; a named derivative requires one.
Named participant roles `artist` and `interviewer` have an empty custom label;
`other` requires its exact label. Participants and languages must be nonempty.
They are declarations, with no inferred identity, role eligibility or consent.
Ordered arrays preserve duplicates except that catalog entry IDs must be unique.
No eight-item limit or other arbitrary array count cap is imposed.

All references use the existing six HashRef algorithms. Algorithms 1, 2, 3 and
6 require exactly 32 digest bytes; algorithms 4 and 5 preserve 1–128 opaque
bytes. A nonzero canonicalization ID is required. All digest values of the proper
width, including zero bytes, remain possible commitments. URI values use the
existing nonempty `https://`, `ipfs://` or `ar://` lexical predicate and a 2,048
decoded UTF8 byte bound. This proves neither retrieval nor inner CID/multihash
validity, identity truth, format detection or a preservation fixity event.

PRONOM format IDs are Keccak-256 of the exact UTF8 `PRONOM:` plus PUID;
the supported PUID grammar is `fmt/` or `x-fmt/` followed by a positive decimal
without leading zeros, within 32 bytes. Catalog formats supply a complete
`Catalog`, including all unselected entries. `catalogDocument` validates every
entry, unique IDs, original order and complete bytes before constructing the
selected mapping and document commitment. Its registration name is exact ASCII
`[A-Za-z0-9_.-]`, 1–128 bytes; the document ID is Keccak-256 of that name.
Selection must identify exactly one entry. The catalog's own content contains
only ordered entries and version, avoiding a self-commitment.

The separately named `STREAM_CONSERVATION_FORMAT_CATALOG_V1` and its JSON
profile describe this supported catalog interpretation. They do not change an
existing catalog or claim that every possible registered catalog is supported.
An authenticated consumer must compare the entire reconstructed catalog to the
actual registered schema, profile and content. Python `validate` likewise
requires exact external catalog bytes for every referenced catalog, rejects
unused witnesses, and checks the selected ID/mapping against the complete
document. A selected-entry hash alone is insufficient.

The complete payload and each complete catalog are limited to 8,192 encoded
bytes. Fixed ASCII object keys use RFC8785 order. Protocol integers are exact
decimal strings except small version/algorithm numbers. Hashes/accounts are
lowercase fixed-width hex; dates are exact proleptic Gregorian dates in years
0001–9999. Strings retain original valid UTF8 with no normalization, trimming,
case rewriting or floating-point conversion. Unknown JSON fields, duplicate
keys, ambiguous numbers and inactive unions are rejected by the closed Python
validator. Named text/URI bounds and total bytes apply together.

## Language validation

`StreamConservationLanguage.requireWellFormed` implements RFC5646 ABNF,
including all 26 grandfathered forms, private use and extensions, plus
case-insensitive duplicate variant and singleton rejection. `arrayJSON`
validates every tag in one linked call and emits its original ASCII bytes;
accepted ALNUM/hyphen characters cannot require JSON escaping. Original tag
case/order and repeated language entries remain unchanged.

This contract check establishes well-formed syntax. The offline validator also
checks RFC5646 section 2.2.9 validity against the exact IANA registry with
File-Date **2026-08-08**, including its private-use ranges. It does not require
recommended Prefix suitability, substitute Preferred-Value tags or validate
extension-specific semantics. It never infers which language a participant
speaks. A syntax-valid unregistered tag such as `zzzz` can serialize onchain and
fails the dated offline validity check; callers must keep these guarantees
distinct.

The original [RFC5646](https://www.rfc-editor.org/rfc/rfc5646.txt) and
[IANA registry](https://www.iana.org/assignments/language-subtag-registry/language-subtag-registry)
are stored as lossless gzip transports under
`schemas/records/standards/conservation/`. The manifest records original URLs,
lengths and whole hashes. Decompression preserves original copyright text and
whitespace. The 731,799-byte registry is an offline dependency; no single
onchain schema-document registration is claimed for it.

## Definitions and verification

Run these from the repository root in the isolated Python environment described
in [Museum tooling](../../tools/museum/README.md). This module uses the existing
locked `jsonschema`, `rfc8785` and `pycryptodome` dependencies and Python's
standard library; it adds no dependency package.

```powershell
python -m tools.metadata.conservation_profile --check
python -m unittest tools.metadata.test_conservation_profile -v
forge test --match-contract '^StreamConservation.*Test$' -vvv
```

The generator owns eight schema/profile JSON documents, seven complete example
objects and `StreamConservationDefinitions.sol`. Interview profile commits its
schema; intent and waiver schemas can then pin that interview profile. Profiles
never embed their own hashes in their committed documents. Original standards
bytes are pinned independently and are not regenerated from interpreted data.

Tests compare independent Python canonical examples to Solidity bytes and cover
closed unions, full catalog mutation, all six references, exact dates/Unicode,
full-width quantities, large arrays, whole-payload boundaries and grammar versus
dated validity. The test harness exceeds EIP170; all linked production libraries
must be measured separately. The named 8,192-byte/1,000-tag cold library probe is
a pure serializer capacity check, excluding transaction intrinsic gas and actual
host authority/storage/receipt/archive work. It is not a universal gas guarantee.

Authenticated consumption remains separate. It must establish original carrier
authority and subject/binding context, actual registered schema/profile/JCS and
catalog bytes, exact interview record/payload correspondence, and dual-family
coverage for every referenced payload. `artist_intent` and `estate_statement`
are untrusted source classifications until corroborated. An estate statement
cannot become retroactive living artist intent, satisfy an artist-signed waiver
by its label, or imply supersession after lock/estate. Current selection,
historical eligibility, the missing/waived-interview warning and finality gates
remain with the authenticated consumer. The examples are public synthetic
fixtures, not registered or current-chain evidence.
