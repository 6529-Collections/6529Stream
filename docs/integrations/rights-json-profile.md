# Interpret exact rights-record JSON

[StreamRightsRecordJson](../../smart-contracts/domains/records/StreamRightsRecordJson.sol)
reconstructs the complete supported `STREAM_RIGHTS_V1` payload from
[typed fields](../../smart-contracts/interfaces/stream/metadata/StreamRightsRecordTypes.sol).
`serialize` produces the bytes; `requireExact` compares their full length,
keccak256 and every byte with a supplied recorded payload. The field witness
is untrusted. Additional, omitted, duplicated or noncanonical JSON fields
cannot be silently discarded while satisfying this comparison.

The generated [semantic definition](../../schemas/records/STREAM_RIGHTS_V1.json)
and separate [interpretation profile](../../schemas/records/STREAM_RIGHTS_JSON_PROFILE_V1.json)
are proposed immutable registration inputs. Repository presence does not mean
that either document is registered onchain. The canonicalization name is
`RFC8785_JCS`; the closed objects have fixed ASCII key order, valid UTF-8,
canonical escapes and no Unicode normalization. Large identifiers remain
fixed-width lowercase hexadecimal strings. The only numeric literals in this
rights profile are version 1 and hash algorithm 1.

Every statement contains all six use classes: reproduction, publication,
exhibition, print, derivative and AI training. Each status is `granted`,
`granted_with_conditions`, `denied` or `unspecified`. All six explicitly
unspecified is valid. A conditional grant requires nonempty text or a complete
document reference. The optional `AI_TRAINING_PERMISSION` value must equal the
canonical AI-training grant; an absent field cannot hide a different value.

Licensors are explicitly artist IDs, named estates, named institutions or
accounts. Unused witness branches must be empty. The licensor's instrument
digest must match the declared instrument, or both must explicitly be absent.
Documents use a nonempty content URI, algorithm-1 keccak256, a nonzero 32-byte
digest and `RAW_BYTES` canonicalization. These are commitments to referenced
bytes; they do not establish availability or legal ownership.

Effective dates are exact Gregorian dates from year 0001 through 9999. In the
Solidity witness they use `YYYYMMDD`; the JSON uses `YYYY-MM-DD`. Closed ends
must be on or after the start. An open end is explicitly `null` and requires a
zero unused end-date witness. Approximate, BCE and inferred dates are outside
this profile. Declared dates remain distinct from generic record timestamps.

Text limits are UTF-8 byte limits, and the complete encoded payload may contain
at most 8,192 bytes, including JSON punctuation and escaped control characters.
The semantic schema marks cross-field and byte constraints with `x-stream-*`.
Generic JSON Schema validation alone does not enforce those constraints; the
serializer and eventual authenticated consumer must enforce them.

This library establishes interpretation only. It does not read a registry or
record host, authenticate the publisher, select the current record, validate
supersession, resolve artist identity or prove archival coverage. A consumer
must obtain the actual stored bytes, verify the exact registered definitions,
original RIGHTS-family receipt class 7/8 and scope, then separately check the
authorized current selection and referenced evidence. Passing caller-supplied
bytes to `requireExact` establishes none of those facts. The generic metadata
writer continues to accept opaque payloads; this is not typed write admission.

Regenerate or check the documents with
`python -m tools.metadata.rights_profile [--check]`. The Solidity tests compare
two independently generated literal fixtures, test every supported vocabulary
and branch, preserve Unicode and full-width values, and fuzz changed payload
bytes. The independent Python tests use the existing pinned museum runtime:
`python -m unittest tools.metadata.test_rights_profile -v`.
