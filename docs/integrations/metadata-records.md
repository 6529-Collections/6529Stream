# Collection record bytes and attributed history

Use [IStreamCollectionMetadataV1](../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol)
with [StreamCollectionMetadataV1](../../smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol).
This is the developing full-byte record host. Its primary ERC165 ID is
`0x7e8260f8`; it does not support the earlier collection-metadata ID
`0x2c2422f4`. Check the selected deployment's inventory before calling it.

## Configure and publish

The constructor binds the Core, canonical governance Executor, schema registry,
shared chunk store and artist registry. It pins their runtime hashes and
registers two governed dependency-read gas allowances. Deployment requires a
valid nonempty module-manifest URI and hashes. Core selects the host through
its normal registered-module pointer mechanism; construction alone does not
select it.

The governance root prepares `recordTypeTransition` or
`familyWriterTransition`, then schedules the matching admission or grant in
the canonical Executor. Schedule the returned scope and exact old/new hashes.
The host checks the stored action proposer, current root revision and active
class-1 per-call context. Recompute after any root change. Grants are scoped
by collection, family, authorization class and account; collection zero means
that family across collections. There is no whole-module writer role.

| Class | Meaning |
| --- | --- |
| 1 | Artist signer, resolved by the artist registry |
| 2 | Token owner, reserved for the dedicated owner lane |
| 3 | Curator signer |
| 4 | Institution signer or the applicable configured verifier |
| 5 | Independent attestor, reserved for the permanent independent lane |
| 6 | Preservation administrator |
| 7 | Metadata administrator for the applicable family |
| 8 | Global administrator, still bounded by the family's allowed classes |

The family catalog controls which classes are allowed. Class 1 cannot be
granted by the host administrator. OWNER, INDEPENDENT and SNAPSHOT families
cannot be admitted to this generic host. Their authority and permanence rules
require their dedicated implementations.

For a direct record, call `recordCollectionRecordWithPayload`. The recorder
is `msg.sender`, including when it is a Safe. Supply a nonempty payload of at
most 8,192 bytes, algorithm 1, its exact keccak256 digest, active schema and
canonicalization IDs, a valid content URI and a nonzero effective timestamp.
The direct profile uses zero signature fields because the transaction is the
authorizing call. A declared schema identity is retained; arbitrary payload
meaning is not validated onchain by this generic API.

For an artist record, use the separate
[publication interface](../../smart-contracts/interfaces/stream/artist/IStreamArtistRecordPublication.sol)
to obtain authorization for the complete typed candidate, then submit
`recordArtistCollectionRecordWithPayload`. The registry validates the current
artist association and capability. The relay caller is recorded separately
from the artist recorder, and each authorization is consumed once. Its backlink
is stored outside the record's own hash to avoid a circular commitment.

Collection subjects use the canonical Core/collection domain. Before using a
token subject, call `registerTokenSubject(tokenId)`; it checks Core membership
and minted or burned lifecycle. This permissionless index call grants no
authority. Prepared tokens are rejected. Other typed scope publishers remain
in development.

## Recover exact records

`collectionRecord(hash)` returns the original record and its receipt.
`recordPayload(hash)` returns the accepted chunk pointer and exact bytes.
History is enumerated with `recordHashAt(collectionId, type, index)` and
`recordChainHash`. Receipts retain schema and canonicalization definition
hashes, so later retirement does not change historical interpretation.

Latest selection is per subject **and recorder**. Use
`latestCollectionRecordHashFor` for an explicit author; the convenience
`collectionRecordPayload` is scoped to its caller. A curator's new record
cannot silently replace another curator's latest record. `payloadPointerAt`
enumerates only accepted pointers, deduplicated by collection, family and
content hash; uploading a chunk directly never inserts it into this inventory.

The canonical event includes the full record, hash, chain hash, recorder,
authorization class and schema version. Its `bytes32` class is the
zero-extended numeric value in the table above. The fourteen-word record
preimage remains compatible with the shared preservation record tuple; the
new host's event and primary interface are explicitly versioned.

Historical bytes and receipts remain readable after pointer replacement,
schema retirement or artist rotation. New publication checks current authority
and host selection. These records do not themselves establish renderer input,
typed finality evidence or complete museum schema conformance. See
[ADR 0040](../adr/0040-current-metadata-record-host.md) and the
[delivery ledger](../../ops/V1_DELIVERY.md) for the composition boundary.
