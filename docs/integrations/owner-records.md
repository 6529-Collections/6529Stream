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
| Name or replace a notice-only registrar with complete typed meaning | `recordStewardDesignation` or `recordStewardDesignationFor` |
| Find the current owner's designated notice recipient | `currentStewardDesignation(tokenId)` |

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

## Typed steward designations

Use the additive [steward interface](../../smart-contracts/interfaces/stream/metadata/IStreamOwnerStewardRecords.sol)
and the complete [JSON witness](owner-notice-json.md). The typed direct and relayed
calls write the original owner record, receipt and token/family chain, then update
the designation index atomically. The relayed call uses the same owner-record
digest, signature and unordered nonce as generic owner writes. A failed typed call
leaves both the original record lane and the designation index unchanged.

The exact `STEWARD_DESIGNATION` family with `STREAM_STEWARD_DESIGNATION_V1` schema
must use a typed call. Both generic paths reject this pair, including an empty
payload or a different canonicalization identifier. Other schemas retain generic
record behavior. This prevents an accepted canonical designation from silently
escaping the notice-recipient index.

The host requires byte-exact canonical JSON and the exact registered schema,
JSON profile and RFC8785 definition, reconstructed from the original ordered byte
chunks. Naming the expected profile hash is insufficient. Retirement of these
immutable definitions cannot lock the owner's records. All six supported outer
and nested hash algorithms remain available; opaque references are commitments,
and the retained payload always determines the interpreted designation.

The designation's `predecessor` names that author's latest typed designation for
the token, or zero for their first. This is separate from the all-author original
record chain. `stewardDesignationFor(tokenId, owner)` retains that author's latest
designation after transfers and burns. `currentStewardDesignation` reads actual
current custody and selects that owner's designation; it reverts for a burned or
unminted token. A transfer from A to B and back to A reactivates A's retained
designation. This is durable per-author selection, with no inferred ownership
epoch or claim that a new custody period required fresh registration.

A steward is an additional notice contact. A designation confers no owner signing,
record-writing, transfer or veto authority. Its identity and endpoint references
are attributed owner statements, not independent verification of an institution.

## Recovery responses and notices

Typed recovery responses now use the original owner authorization and retained
receipt history. Exact action/manifest responses enter the complete owner queue,
including records published before a notice opens. The TOKEN notice implementation
snapshots the original owner and steward contacts and starts its own 72-hour window.
Bounded preparation lets publishers retain every delivery claim before one atomic
opening. See [owner recovery notices](owner-recovery-notices.md) for queue processing,
permissionless finalization, actual companion evidence and remaining wider scopes.

For the exact semantics and event commitments, see the
[owner-record specification](../collection-metadata-contract.md#owner-records-and-the-object-dossier).

## Validation

The focused cohort covers current-owner checks and custody history, literal
signed commitments, nonce ordering/revocation, malformed signatures, low-gas
rollback and retry, maximum payloads, all six digest shapes, threshold Safe
calls and a 256-input property. The shared-reader cohort additionally exercises
the largest registered definition: 64 chunks, a 128-byte name and a 2,048-byte
registration URI. This evidence does not establish complete system acceptance.
The typed stewardship cohort adds actual threshold Safe calls across both new
write paths and both readers, exact registered definition bytes, per-author
supersession, transfer/reacquisition, burned history, generic bypass rejection,
signature mutation rollback and a cold 8,192-byte typed payload with a
2,048-byte record URI.
