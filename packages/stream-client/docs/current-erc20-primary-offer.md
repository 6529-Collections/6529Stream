# ERC20 primary-offer workflow

`current-erc20-primary-offer.ts` prepares unsigned calls for the atomic,
one-token ERC20 `OFFER_SALE` carrier. It preserves the original full buyer
offer and seller authorization. Read the
[signing and selected-content guide](current-erc20-primary-offer-signing.md)
before preparing either signature.

The supported configuration has a positive ERC20 price, a collection PROFILE
primary assignment, `STRICT_MATCH` policy mode, and a zero declared native
reveal fee. The buyer is the payer, initial recipient, and final beneficiary.
Both Sales signatures use `finalizeBy = 0`. These helpers do not implement the
held native-fee allowance design.

## Prepare and check the sale

1. Use `prepareERC20PrimaryOfferSignerConfiguration` for the carrier's explicit
   collection signer. Kind `1` means ECDSA and kind `2` means ERC-1271; code
   presence does not choose the signature family.
2. Predict the original sale ID with `erc20PrimaryOfferSaleId`. Supply the flat
   immutable configuration and selected-work proof to
   `prepareERC20PrimaryOfferRegistration`. Collection-level offers have zero
   content fields and an empty proof.
3. Run `simulateERC20PrimaryOfferRegistration` at a concrete block. Its pinned
   reads check owner, next nonce, configuration hash, and signer revision.
   The exact registration simulation also checks phase, Artist association,
   current rights, active asset, module admission, and the zero native fee.
4. Prepare the original signatures and nested acceptance. Call
   `prepareERC20PrimaryOfferAcceptance(chainId, adapter, core, manager,
   recorder, caller, configuration, acceptance)`.
5. Call `inspectERC20PrimaryOfferAcceptance(provider, prepared, { blockTag })`.
   It reads the retained sale and deployment bindings, checks the original
   buyer and seller replay loci, and calls the carrier's `previewExecution`
   with the exact acceptance.

The preview performs the current on-chain checks, including live signer and
executor delegation, Artist consent, phase/gate/counter state, ACTIVE asset,
PROFILE rights and zero native fee. A valid phase-policy grace window may
make `currentPolicyHash` differ from `boundPolicyHash`; the client preserves
both values. A successful preview does not authorize a later changed state.

## Choose the payment route

Pass the prepared acceptance, returned candidate and one route to
`prepareERC20PrimaryOfferFunding`. Every route targets the configured
`StreamERC20PrimarySettlementAdapter`, contract 20, with native value zero.

| Route | Input | Actual contract-20 caller |
| --- | --- | --- |
| `payer` | `{ kind: "payer" }` | Buyer/payer |
| `intent` | `{ kind: "intent", intent, signature }` | Buyer or live buyer delegate |
| `eip2612` | `{ kind: "eip2612", permit: { deadline, v, r, s } }` | Buyer/payer |
| `permit2` | `{ kind: "permit2", permit: { nonce, deadline, signature } }` | Buyer/payer |

The intent route always validates the separate buyer-owned PaymentIntent,
including when the buyer calls it. Its original domain names the actual
contract-20 address, and it binds the buyer, asset, maximum price, original
sale ID, primary policy, nonce and deadline. An offer-signing delegate does
not gain allowance-spending authority. A nonpayer executor needs both live
buyer delegation and the buyer's PaymentIntent signature; a Safe buyer uses
its ERC-1271 signature for that intent.

`prepareERC20PrimaryOfferTokenApproval(asset, buyer, paymentAdapter, amount)`
prepares a buyer CALL approving the actual puller. The carrier never needs an
allowance. Permit capability, policy, deadline, exact funding and the pinned
Permit2 deployment remain checked by the contract-20 simulation.

Run `simulateERC20PrimaryOfferFunding` after funding prerequisites are present.
It repeats the pinned preview, compares the complete candidate, checks intent
digest and replay when applicable, and simulates the exact unsigned call from
the reviewed caller. It validates the complete 12-word settlement result.
No helper sends a transaction or signs a payload.

## Identities and replay

The canonical execution bytes are exactly `abi.encode(Acceptance)`.
`saleExecutionHash` hashes those bytes. The original order-one execution,
candidate commitment and settlement key use their unchanged contract domains:

| Identity | Helper or owner |
| --- | --- |
| Buyer offer TICKET authorization ID | `erc20PrimaryOfferBuyerAuthorizationId`; Manager/Ledger replay |
| Full seller authorization digest | Signing snapshot; carrier replay |
| Payer PaymentIntent nonce | Contract 20's `(payer, nonce)` replay |
| Execution ID | `erc20PrimaryOfferExecutionId` |
| Candidate commitment | `erc20PrimaryOfferCandidateCommitment` |
| Official settlement key | `erc20PrimaryOfferSettlementKey` |

The atomic ERC20 path has no escrow-holding purchase record or alternate
`purchaseId`. Execution nonce belongs to `(saleId, buyer)`. Failed transactions
revert payment, permit, mint and replay changes together. A failed simulation
leaves the immutable reviewed call available for retry; rerun live checks
after repairing the dependency.

## Completion and revocation

`inspectCompletedERC20PrimaryOffer` reads the completed sale, exact execution
record, original replay stores and official recorder result at one concrete
block. It also checks the retained 96-byte
`primaryOfferSettlementBinding(saleId)` of sale nonce, poster and configuration
hash. `readERC20PrimaryOfferSettlementBinding` remains useful after terminal
sale states, without claiming current sale availability.

`inspectERC20PrimaryOfferFundingReceipt` accepts a transaction hash and execution
mode `direct` or `safe`. It checks the successful mined transaction, exact
direct caller or single Safe `execTransaction` CALL envelope, canonical carrier
execution event, stored completed execution and recorder receipt at that block.
It checks the block hash before and after those reads. Arbitrary Safe modules
and nested batch envelopes require their own caller verification.

The three revocation families remain independent:

- `prepareERC20PrimaryOfferBuyerRevocation` calls Manager's full-payload
  `voidMintOffer` using the original MintTicketRevocation family or direct buyer.
- `prepareERC20PrimaryOfferSellerRevocation` uses the historical admitted seller
  and original SaleAuthorizationRevocation family. Its inspection does not
  depend on live phase, Artist, payment, reveal or current signer availability.
- `prepareERC20PrimaryOfferPaymentRevocation` prepares direct payer revocation,
  or the current tuple-based `revokePaymentIntentWithSignature` selector.

Use the corresponding simulation functions before submitting revocations.
Ordinary offer and authorization signatures do not substitute for revocation
signatures.

## Safe and operator calls

The module also prepares cancel, expire, adapter/sale pause, collection contest
sync, governed gas raise, ownership transfer and ownership renunciation calls.
`simulateERC20PrimaryOfferAction` checks those exact calls from the selected
actor. Preparation does not establish the actor's current authority.

Every prepared write can use `toSafeCall`, preserving target, zero value and
ordinary CALL (`operation = 0`). A Safe direct payer must be the actual
contract-20 caller. The carrier's internal execution callback and contract 20's
funding callback are transport internals and are not user actions. See the
[Safe execution guide](current-erc20-primary-offer-safe.md) for transaction-level review.

## Evidence boundary

The retained compiled fixture pins root source
`2e0fca1aef41a023d76a9717651a699bbd7db155`, carrier
`94eaedc3ddd17aa6866b00b668e5e511a2151c5d`, and shared source
`1d4e7236d2f6712697d24f1dc60974d938a00c87`. Tests verify exact compiled tuples,
hash domains, funding routes, bounded canonical RPC decoding, mutable-input
snapshots, original replay boundaries, retry and mined direct/Safe receipt
validation. These client tests do not establish current-stack runtime, gas,
deployment, audit or release acceptance.
