# Current refund purchase record verification

`current-refund-purchase-record.ts` verifies the immutable stored commitment for
one captured allowlist refund-window purchase from source commit
`90e68ebfc62e63eb46c6f23b23c32f3ccf2957a8`. It performs pinned, read-only RPC
calls. It prepares no transaction and does not reapply current sale, Artist,
policy, provider, fee or Merkle-root admission.

## Expected coordinates

Call `verifyCurrentRefundPurchaseRecord` with the expected chain, adapter,
purchase ID, sale ID and payer. The verifier reads a concrete block, records its
hash and the observed adapter code hash, and rechecks the block hash after all
reads. The code hash is evidence of what that RPC returned at that block. It is
not compared with a canonical deployment hash.

The purchase ID is independently reconstructed from the original domain,
chain, adapter, sale, payer and full-width purchase nonce. The stored 15-field
authorization is passed through the shared original refund signing producer.
Both its local EIP-712 digest and the adapter digest getter must equal the saved
authorization digest. The saved token bytes must hash to the original signed
`tokenDataHash`.

## Immutable purchase hash

The original record hash is reconstructed exactly as:

```text
keccak256(abi.encode(
  keccak256("6529STREAM_REFUND_PURCHASE_RECORD_V1"),
  chainId, adapter, purchaseId, authorization, authorizationDigest,
  PurchaseCapture(savedRevealFee, artistId, bindingGeneration,
                  bindingHash, referencedGate),
  purchasedAt, pauseBaseline, nominalRefundDeadline, nominalFinalizeBy
))
```

For an allowlist capture, the stored final hash is:

```text
keccak256(abi.encode(
  keccak256("6529STREAM_REFUND_ALLOWLIST_PURCHASE_RECORD_V1"),
  originalPurchaseRecordHash, chargedPrice, keccak256(resolverData)
))
```

`status` and `terminalToll` are mutable lifecycle facts and are intentionally
excluded. The verifier accepts pending, finalized, refunded and unlocked records
(`1..4`) while requiring all immutable capture fields to reproduce the hash.

## Saved allowlist proof and price

Resolver bytes are bounded to 4 MiB before decoding. They must be the exact
canonical ABI encoding of 1 through 16 ordered `AllowlistProof[][]` groups, with
exactly one proof per group and at most 256 sibling nodes per proof. Counts are
positive `uint64`, flags are actual booleans, prices retain full `uint256` width,
and a disabled price is exactly `false/0`. The verifier never sorts, removes or
rewrites groups or siblings.

Every raw RPC response is also bounded before ABI decoding, with 64 KiB of tuple
overhead above the 4 MiB content boundary.

At most one saved proof may enable a price. When one does, its exact saved price
must equal `refundPurchasePriceFacts.chargedPrice`. With no enabled price, the
saved charge must equal the original authorization's positive public `price`.
The signed public price is never rewritten or replaced in the authorization.
The resolver bytes must hash to the separately stored resolver hash, and the
allowlist wrapper must match the stored purchase record hash.

These checks establish internal readback and commitment consistency. They do
not prove which historical Merkle root admitted the proof, historical signatures
or callbacks, canonical deployed-code identity, present finalization eligibility,
refund payment, or complete current-stack execution.
