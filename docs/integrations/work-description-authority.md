# Publish an artist or curatorial work description

`WORK_DESCRIPTION` uses the exact `STREAM_WORK_DESCRIPTION_V1` schema identity
and the existing CURATOR family. Admit this type with mask `0x010a` to support
artist class 1, curator class 3 and administrator class 8. This is a narrow
type-specific intersection; other CURATOR types still allow only classes 3/8.
The generic host rejects admission of WORK_DESCRIPTION under another family.

Use the [record host](metadata-records.md) and its normal governed type/grant
transitions. The admitted policy is immutable. A host on which this type was
already admitted with a smaller mask cannot silently gain the artist path;
its deployment/version migration must be explicit.

For artist publication, prepare the exact record and operation-24 publication
envelope. The subject classifier is 8, the attestation's `subjectStateHash` is
zero, and the required capability is `CAP_ATTEST` (1). The candidate hash inside
the envelope still binds the full record, original recorder, host, subject,
schema, payload, URI and effective timestamp. Obtain the actual artist
authorization, then call `recordArtistCollectionRecordWithPayload`. A relayer
may submit it once. An estate successor needs the attestation capability;
intent capability 64 alone does not authorize a work description.

For direct curatorial publication, use `recordCollectionRecordWithPayload`
with the applicable class-3 or class-8 CURATOR grant. Class 1 cannot be granted
through `setFamilyWriter`, and an artist signature does not grant access to this
direct path. A Safe remains the actual recorder when it makes the call.

Both paths enforce the exact work-description schema identity. Receipts retain
metadata class 1 or 3/8 and the original recorder. On the artist path, the
separate authorization backlink retains the artist registry's authority class
and binding. Artist successor class 3 and metadata curator class 3 are different
enums on different receipts; do not merge them. Stored payload pointers remain
in the CURATOR family, and history remains distinct for each author.

This authority increment accepts opaque generic payload bytes. It does not yet
validate the full tombstone or explicit-absence JSON forms. Typed semantic
validation, authorized current-record selection and the finality provider must
be composed separately. Do not interpret a valid schema name or receipt as
proof that every mandatory descriptive field exists.

The focused authority and envelope tests retain the generic fourteen-word
record hash, ABI and physical storage. They exercise incorrect schemas and
grants, separate authors, replay, failed-append rollback, threshold Safe calls
and fuzzed exact payloads. The actual artist publication tests exercise the
principal and estate paths; full Core/Executor/Finality integration remains
part of the [delivery ledger](../../ops/V1_DELIVERY.md).
