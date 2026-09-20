# Current collection and token RIGHTS evidence

The current RIGHTS reader and composer implement acquisition-packet item 7:
both native selected records, their original publication authority, and the six
effective grant statuses. They preserve the original `STREAM_RIGHTS_V1`,
`STREAM_RIGHTS_JSON_PROFILE_V1` and acquisition-packet schemas byte for byte.

This is a complete item-7 implementation within the declared source profile.
Its RPC source still requires external admission. Synthetic tests do not prove
actual chain execution, legal rights, institutional acceptance or completion of
the other acquisition requirements.

For public block heights beyond this original genesis-walk profile's limit,
use the separate [public-history RIGHTS capture](museum-public-history-capture.md).
It preserves native selection semantics and adds explicit provider log-completeness
trust, a distinct transcript/profile and standalone item-7 fragment output.

## Native source and absence

`CurrentRightsSource` starts at the pinned Core's installed Metadata Router.
The Router's original finality binding identifies the original native evidence
provider. That provider's constructor configuration identifies the RIGHTS
selector and Metadata host. The reader checks their exact runtime commitments
and reciprocal Core, Schema Registry and Chunk Store bindings. An arbitrary
self-consistent selector cannot establish the absence of selected RIGHTS.

The source captures both canonical subjects independently:

- `currentRights(collectionId, collectionSubjectId)`;
- `currentRights(collectionId, tokenSubjectId)`.

A completely zero 14-field head means **no selected record for that subject**.
It does not mean no historical RIGHTS publications exist. A missing getter,
unsupported definition, failed binding or incomplete capture fails the reader;
it never becomes an absent record.

For each nonzero head, the reader retains every selection revision from 1 to
the head, verifies the native selection hash, and checks its selected predecessor,
original Metadata index and nondecreasing selection time. It reads the original
record, receipt, payload and registered schema/profile/canonicalization bytes.
Historical publisher authority and selection authority remain distinct. Current
writer grants do not replace or revoke those historical facts in the export.
Each selection must also match its original `RightsRecordSelected` event in the
same receipt history. A selected event contradicts an empty head. Publication
must precede selection, including their order within a transaction.

The reader checks the complete bounded header/receipt stream to locate each
selected record's original `CollectionRecordRecorded` event. Its exact original
record, chain hash, recorder, authority class and schema version must match.
The event's block timestamp must equal the receipt's `recordedAt`.
`recordedBlock` comes from this event's block; neither `recordedAt` nor
`selectedAt` is a block number.

The packet schema calls the publishing account `signer`. For RIGHTS this field
retains the original Metadata recorder, authorized under class 7 or 8. The
native RIGHTS signature fields are zero; the export does not invent a separately
verified signature or a determination that the publisher legally owns the rights.

## Precedence and dates

All six use classes are explicit in each original RIGHTS record:
`ai_training`, `derivative`, `exhibition`, `print`, `publication` and
`reproduction`. A selected token record supplies every effective status,
including `unspecified`. A collection record supplies effective statuses when
the token has no selected record. Both original records remain in the package.

| Selected records and grant statuses | Completeness |
| --- | --- |
| Neither scope has a selected record | `absent` |
| All effective statuses are `unspecified` | `unspecified` |
| Some effective statuses are specified | `partially_specified` |
| All six effective statuses are specified | `specified` |

For example, collection reproduction `granted` and token reproduction
`unspecified` produce effective reproduction `unspecified`. They do not produce
a collection fallback. `denied` is a specified status.

Original `effectiveAt`, Gregorian `effectiveDates`, conditions, instruments and
licensor declarations are retained. The native selector does not filter by the
date interval. This source follows its stored selection without inventing an
assessment date, timezone, expiration fallback or legal enforcement rule.

## Offline composition

The input examination is either the unchanged
[source gather](museum-dossier-gather.md) or its
[mint/entropy extension](museum-mint-entropy-evidence.md). The RIGHTS input is
required and contains exactly `anchor.json`, `transcript.json` and
`snapshot.json`, with three external hashes and explicit source provenance.

```text
python -m tools.museum.dossier_rights build \
  --examination out/examination \
  --examination-hash 0x<external-examination-manifest-hash> \
  --rights out/current-rights-capture \
  --rights-anchor-hash 0x<external-anchor-hash> \
  --rights-transcript-hash 0x<external-transcript-hash> \
  --rights-snapshot-hash 0x<external-snapshot-hash> \
  --provenance trusted_rpc --disclosure public \
  --output out/rights-examination

python -m tools.museum.dossier_rights verify out/rights-examination \
  --manifest-hash 0x<external-result-manifest-hash>
```

Use the isolated Museum Python environment. The continuation characters above
use shell-style notation; in PowerShell run each command on one line.
No new network capture occurs during composition or verification. Output
publication is atomic and refuses an existing destination. Public disclosure
is checked before source reads.

The composer replays the original examination and concrete RIGHTS reader, then
joins exact chain/Core/token/collection/serial/lifecycle/burn state, source
block, timestamp, state root, deployment evidence, runtime hashes and repeated
RPC answers. A mint/entropy input preserves that evidence and includes its
observations in the same conflict checks.

| Output | Contents |
| --- | --- |
| `examination/` | Entire original examination, unchanged |
| `rights/source/` | Original externally pinned capture triplet |
| `rights/packet-fragment.json` | Exact existing acquisition-packet `rights` schema fragment |
| `rights/records/` | Selected original records, receipts, publication positions and exact payload bytes |
| `rights/definitions/` | Original registered interpretation bytes |
| `rights/records.json` | Record paths, dates and original publisher authority |
| `packet/fields.json` | All 19 requirements, with item 7 derived within the source profile |
| `packet/examination.md` | Human-readable requirement status |

The `selectionEvidence` reference commits the exact retained source snapshot.
The manifest commits every file. Verification rebuilds all derived output from
the original inputs; changing a derived field and updating its file hash does
not bypass replay. Retained tool text is inert provenance and is never executed.

## Bounds and remaining work

The reader accepts at most 64 selected revisions per subject, 8,192 bytes per
record payload, 4,096 blocks including genesis, an 8 MiB source snapshot and a
64 MiB transcript. Exceeding a bound fails capture. These are explicit reader
limits, not truncated histories or protocol limits. It does not claim the full
Metadata publication lane or complete finality-provider eligibility.
The reader requires active installed Router and Metadata pointers as a source
admission policy. This does not assert that every Core rendering path rejects
an inactive pointer in the same way.

The original full-packet completion command continues to refuse unresolved
requirements. Item 6, including canonical original attribution and the latest
notarized personhood join, remains separate: a native personhood declaration or
a generic C2PA head cannot supply an unrecorded authoritative notarization link.

Validation covers synthetic native-reader vectors, publication/event and
selection mutations, canonical precedence, shared-source conflicts and package
replay. A genuine current-source capture and combined native/release acceptance
remain pending the integrator's coordinated validation.
