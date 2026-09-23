# ERC20 primary-offer signing and content

The current ERC20 offer helpers prepare one atomic primary mint with the buyer
as payer, initial recipient and final beneficiary. The configured token price
must be positive. The profile requires a collection PROFILE assignment,
`STRICT_MATCH` (`primaryPolicyMode = 0`) and a declared zero native reveal fee.
Current rights and the fee are live contract checks; a valid offline signing
packet does not establish them.

## Preserve the original signatures

`erc20PrimaryOfferSaleOfferPayload` keeps all 12 original `SaleOffer` fields.
`erc20PrimaryOfferSellerAuthorizationPayload` keeps all 24 original
`SaleAuthorization` fields. Both use `6529Stream Sales`, version `1`, the exact
chain ID and the ERC20 offer carrier as verifying contract. The asset is the
configured ERC20 address. `tokenId = 0`, `saleKind = 6`, quantity one,
`PRIMARY_SALE`, strict policy mode and both `finalizeBy = 0` are required.
The native offer helpers retain their native-asset restrictions.

`ERC20PrimaryOfferConfiguration` is the compiled flat 21-field tuple, including
`asset` and `paymentAdapter`. Its configuration hash uses
`6529STREAM_ERC20_PRIMARY_OFFER_CONFIG_V1`. `erc20PrimaryOfferSaleId` uses the
original `6529STREAM_SALE_V1` domain with kind 6. This atomic profile has no
separate escrow purchase ID.

```js
const packet = erc20PrimaryOfferSigningSnapshot(
  chainId, carrier, core, manager, configuration, saleId,
  fullBuyerOffer, fullSellerAuthorization, rawTokenData, mintCommitment,
);
```

The snapshot checks signed fields against the immutable configuration and
exact singleton batch arrays. `erc20PrimaryOfferBatchHashes` binds both
recipient arrays to the buyer. The seller also signs the actual executor, raw
token-data array and mint-commitment array. The seller deadline cannot exceed
the sale end; the buyer deadline may exceed it. Offline snapshots check window
compatibility, while live inspection checks the current time and state.

| Identity | Meaning |
| --- | --- |
| `offerPayload.digest` | Full original buyer Sales EIP-712 digest |
| `buyerAuthorizationId` | Original TICKET domain wrapping of that digest; Manager/Ledger replay key |
| `sellerReplayDigest` | Full original seller EIP-712 digest; carrier replay key |
| `configurationHash` | Immutable ERC20 offer terms and signer evidence |
| PaymentIntent `(payer, nonce)` | Independent token-payment replay authority in contract 20 |

## Content and canonical execution data

For a selected work, construct the complete manifest with `buildCuratedManifest`
and the kind-6 sale ID. The original content leaf and context domains remain
unchanged. `erc20PrimaryOfferGateConfigHash` and
`inspectERC20PrimaryOfferManifest` bind that original publication to the
dedicated `6529STREAM_ERC20_PRIMARY_OFFER_GATE_V1` capability, saved runtime
hashes and complete manifest bytes. The manifest reader requires a concrete
numeric block; it does not independently establish canonical deployment,
reorg safety or live phase/counter availability.

For a collection-level offer, the configured manifest root, content ID and
token-data hash are zero. Registration proof and acceptance `selection.content`
are wholly empty/zero. The phase gate must also be empty. Raw token data and
the nonzero mint commitment still enter the seller signature. The ordinary
batch context is the full seller digest; no selected-work identity is created.

`ERC20PrimaryOfferAcceptance` matches the complete compiled tuple:

- Full `offer` and explicit `buyerProof`.
- Full `authorization` and explicit `sellerProof`.
- `selection.content`, raw `tokenData`, `mintCommitment` and `executionNonce`.
- Independent `signerDelegation` and `executorDelegation` witnesses.

`normalizeERC20PrimaryOfferAcceptance` copies and freezes nested caller inputs,
checks exact fields and enforces resource bounds. It does not establish
signatures, live delegation, selected membership or configured signer authority.
The workflow checks content/proof/configuration agreement before preparing an
execution. Signature kind 1 explicitly means ECDSA; kind 2 explicitly means
ERC-1271. A supplied witness is not proof that a delegate remains authorized.

`encodeERC20PrimaryOfferAcceptance` returns exact `abi.encode(acceptance)`.
Pass those unchanged bytes to the selected contract-20 route after previewing
the same acceptance. The candidate's `saleExecutionHash` is the Keccak hash
of those bytes. Token data is bounded at 8,192 bytes by the carrier. The client
also limits proofs to 256 nodes and signatures to 65,536 bytes.

## Independent payer authorization

`erc20PrimaryOfferPaymentIntentPayload(chainId, configuration, saleId, intent)`
uses the original `StreamPaymentIntent` type under
`6529StreamPaymentIntentVerifier`, version `1`, and the configured **contract 20**
address. It binds the buyer as payer, the asset, a `maxAmount` covering the price,
the original sale ID and the expected primary-policy hash. The payer retains
its own nonce and deadline, including valid zero nonce values. Expiry, replay
and signature validity remain live checks.

The carrier does not pull tokens or receive allowances. Only the actual payer
calling contract 20 qualifies for its direct `ByPayer` route. `WithIntent`
always validates its own payer signature; a nonpayer executor must also be
the buyer's live delegate. An offer signed by a delegate does not authorize
spending the buyer's tokens. A Safe buyer can provide its ERC-1271 payment
signature. Existing EIP-2612 and Permit2 routes require the payer to call.
Every route is nonpayable and every Safe transaction uses ordinary CALL with
zero native value. See the [Safe workflow guide](current-erc20-primary-offer-safe.md)
for transport, approval and receipt preparation.

The original buyer `MintTicketRevocation` and historical seller
`SaleAuthorizationRevocation` payload helpers remain applicable with their
respective replay identifiers. PaymentIntent revocation uses its own original
`StreamPaymentIntentRevocation` domain at contract 20. None of these revocation
signatures substitutes for an offer, seller authorization or payment signature.

## Evidence boundary

The retained fixture pins the 2,098-source ABI capture at
`2e0fca1aef41a023d76a9717651a699bbd7db155`, including shared offer source
`1d4e7236d2f6712697d24f1dc60974d938a00c87` and carrier
`94eaedc3ddd17aa6866b00b668e5e511a2151c5d`. Tests compare full compiled tuples,
hash domains, both content branches, explicit kinds, high-bit integer values
and mutation boundaries. This is client and source evidence. Joined contract
runtime, Safe execution, gas, deployment and release acceptance remain separate
coordinator-owned checks.
