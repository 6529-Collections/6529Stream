# Current mint gate inputs

`current-mint-gates.ts` prepares exact inputs and hash commitments for the ticket,
delegate registry, and static Merkle allowlist gates. Ticket and delegate inputs
retain source `bba738e9a9af3f12fdccd2e9cbc825aa555adb08`; authenticated price fields
follow `f1745f33be3e601aca75a89ffe428f534a352615`. It does not sign, send, deploy,
read live eligibility, or prove that Manager, Ledger, registry, counter, replay, or
policy checks will accept a mint.

All integers are `bigint`. Producers reject unknown struct fields, malformed or
odd-length hex, rounded JavaScript numbers, inconsistent batch lengths, and
client inputs above the documented memory boundaries. Returned objects and
arrays are copied and frozen.

## Ticket gate

1. Build all four batch arrays. `mintBatchHashes` uses four distinct domain
   separators and hashes the entire `bytes[] tokenData` array. A single token's
   data hash is not the ticket's `tokenDataArrayHash`.
2. Set the batch `authorizer` to the configured ticket signer and call
   `mintTicketForBatch`. Payer, executor, signer, Manager, Ledger, collection,
   phase, policy, context, quantity, nonce, and deadline are all distinct fields.
3. Call `mintTicketTypedData(chainId, gate, ticket)`. The returned immutable
   `SigningPayload` includes the EIP-712 domain, exact `MintTicket` fields, and
   `digest`. Sign through the wallet policy selected by `authorizerKind`.
4. Derive `authorizationId` with `mintTicketAuthorizationId(digest)`, place it in
   the Manager batch, and use `mintTicketGateData(ticket, signature)` as gate data.

For an EOA signer, the signature is an EIP-712 signature over `digest`. For a
Safe configured as `ERC1271_712`, owners do not concatenate signatures over the
raw ticket digest. `mintTicketSafeMessageBytes(digest)` returns the exact
`abi.encode(bytes32 digest)` message bytes that the Safe wraps in its own
`SafeMessage(bytes)` EIP-712 envelope. Safe threshold assembly and acceptance
remain Safe operations outside this client.

The gate's `validateMintBatch` is a Manager callback. It is not an operator or
Safe transaction target.

## Delegate registry gate

`delegateGateConfigHash` and `delegateCollectionRights` reproduce the immutable
deployment and collection-rights preimages. `delegateGateData(vault, nonce)` is
exactly 64 bytes. `delegateMintRequest` requires every delivery recipient and
beneficiary to equal the vault, a nonzero payer/delegate that differs from the
vault, a nonzero executor, and a zero authorizer. The executor may equal the payer.

The retained `validateMint` ABI predates full batches. Its request commits to the
Manager, executor, routing, context, policy, and gate data, but deliberately does
not contain `tokenData` or `mintCommitments`. `delegateMintAuthorizationId`
therefore cannot be described as a full-batch commitment. Eligibility is a live
delegate.xyz registry read by the deployed gate, and registry eligibility is not
a signature. The gate returns a zero authorizer and `NONE` kind. Its validation
entrypoint must be called by the configured Manager.

## Static Merkle allowlist gate

`mintAllowlistLeaf` implements the protocol's double hash. The flat input binds
chain, Manager, collection, phase, counter, account, `uint64 maxCount`, and the
retained price fields. An enabled override authenticates a full-width `uint256`
price, including zero. A disabled override requires `priceOverride: 0n`.
Manager and the generic gate authenticate these fields without collecting
payment; the selected sale consumer must enforce its own charging rules.

`verifyMintAllowlistProof` uses sorted pairs. `mintAllowlistResolverData` ABI
encodes one proof group for each `MERKLE_STATIC` counter in phase counter order.
`mintAllowlistProofValuesHash` binds each counter ID and the ordered
`maxCount`/price values while intentionally omitting sibling nodes. The sibling
nodes remain encoded in `resolverData` and are checked against the configured
roots.

Use `mintAllowlistAuthorizationBinding` to combine the full batch array hashes
with the proof-values hash and exact Manager/Ledger/executor coordinates. The
Solidity field is named `tokenDataHash`, but its value is the full token-data
array hash. `mintAllowlistAuthorizationId` and `mintAllowlistNullifier` have
different preimages. `mintAllowlistGateData` is exactly `abi.encode(bytes32 nonce)`.
No signature is involved; the returned authorizer is zero and kind is `NONE`.

`previewAuthorizationId` is an externally readable on-chain preview that also
checks current Manager, Ledger, policy, counter, code, and proof state. This
module only prepares its deterministic inputs. `validateMintBatch` is a Manager
callback and must not be submitted directly by an operator or Safe.

## Boundaries and evidence

The client accepts at most 4,096 mint rows, at most 256 Merkle siblings per proof,
1 MiB per token-data item, and 4 MiB across token data or encoded resolver data.
These are client resource limits, not protocol capacity claims. A phase may have
stricter configured limits.

The committed fixture is locked to the exact 130-source successor-joined compiler
input/output capture for `bba738e9`. It proves selected ABI and source provenance.
Scoped runtime tests were completed later against separate test-only source; the
fixture does not claim that this earlier compiler capture passed native runtime,
nor that any live deployment or request is accepted.

The separate native allowlist price fixture binds the changed shared counter
policy and native consumer to the exact 159-source `f1745f33` compiler capture.
The retained gate ABI shapes and preimages are unchanged. This later source
qualification covers the enabled-price behavior; it does not relabel the older
ABI capture as a later runtime result.
