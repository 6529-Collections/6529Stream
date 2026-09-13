# Owner records

`StreamOwnerRecords` gives the current NFT owner an append-only object dossier.
An institution can record an accession, condition report or loan without a
platform writer grant. Transferring the NFT preserves the previous owner's
records and gives the new owner authority to append their own records.

This implementation is on the developing full-v1 branch. It has focused tests
with the actual record host, schema registry, byte store and threshold Safe.
Its Core custody and governance counterparts in that cohort are fixtures;
complete deployment integration remains open.

## Choose a call

| Need | Interface call |
| --- | --- |
| Submit from the current owner, including a Safe transaction | `recordOwnerRecord(tokenId, record)` |
| Let another account relay an owner's signature | `recordOwnerRecordFor(tokenId, record, owner, nonce, deadline, signature)` |
| Cancel a nonce directly or by signature | `revokeOwnerRecordNonce` or `revokeOwnerRecordNonceFor` |
| Check replay protection for an explicit owner | `isOwnerRecordNonceUsed(owner, nonce)` |
| Read an original record and its receipt | `ownerRecord(recordHash)` |
| Enumerate a token's record family | `recordChainHash` and `recordHashAt` |
| Find one owner's latest statement | `latestOwnerRecordHashFor(tokenId, recordType, owner)` |

Use the [caller interface](../../smart-contracts/interfaces/stream/metadata/IStreamOwnerRecords.sol)
for complete argument and return types. The host derives the token subject with
`deriveOwnerSubject`. A burned or unminted token has no current owner who can
append a record; previously recorded history remains readable.

## Record bytes and signatures

Records reference immutable registered schema and canonicalization definitions.
Retiring a definition does not disable an owner's dossier. A metadata renderer
pointer change also does not grant or remove owner authority.

The host accepts up to 8,192 payload bytes and a 2,048-byte URI. Empty payloads
can identify externally retained material. Keccak-256 and SHA-256 verify
nonempty payload bytes onchain. The remaining supported hash algorithms retain
explicit commitments; the host does not compute their digests. All supplied
payload bytes remain part of a relayed signature, including those paired with
an opaque digest. Payloads and signature bundles use the immutable byte store.

Relayed writes use the exact `StreamOwnerRecord` EIP-712 type and the domain
`6529StreamOwnerRecords`, version `1`, with the live chain ID and host address.
Use `ownerRecordDigest` and `ownerRecordRevocationDigest` when constructing
signatures. EOAs support standard and compact signatures; contract owners use
ERC-1271. Nonces are unordered and keyed by owner. A failed write does not
consume its nonce. A direct Safe call needs no separate owner-record signature;
a relayed Safe write needs a signature its configured ERC-1271 handler accepts.

## Interpretation and recovery

The ten built-in record families are available for generic ingress, including
`STEWARD_DESIGNATION` and `RECOVERY_RESPONSE`. Accepting those family names does
not yet interpret a steward designation or count an acknowledgment or objection.
Typed recovery records, action-bound 72-hour notices and the owner-evidence
interface remain separate implementation work. A record is its owner's
statement; recording it does not independently establish the truth of its contents.

For the exact semantics and event commitments, see the
[owner-record specification](../collection-metadata-contract.md#owner-records-and-the-object-dossier).

## Validation

The focused cohort covers current-owner checks and custody history, literal
signed commitments, nonce ordering/revocation, malformed signatures, low-gas
rollback and retry, maximum payloads, all six digest shapes, threshold Safe
calls and a 256-input property. The shared-reader cohort additionally exercises
the largest registered definition: 64 chunks, a 128-byte name and a 2,048-byte
registration URI. This evidence does not establish complete system acceptance.
