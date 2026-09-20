# ERC20 primary offer Safe calls

The [ERC20 primary offer workflow](current-erc20-primary-offer.md) prepares
unsigned calls for the atomic kind-6 offer profile. Every supported call uses
zero native value. A Safe executes each action with ordinary `CALL`, operation
0. The client does not sign, submit, choose Safe owners, or infer threshold
approval from a successful target simulation.

## Caller and payment boundaries

Contract 20 is the sole token puller. A buyer Safe approves that payment adapter
and executes `settleERC20PrimarySaleByPayer` itself, or supplies its separate
ERC-1271 PaymentIntent to a live delegated executor while maintaining
sufficient token allowance to contract 20. The carrier receives no standing
token approval. The buyer remains the initial and final recipient.

Only the payer calling contract 20 directly receives its caller exemption.
An offer signer, relayer or carrier cannot inherit that exemption. EIP-2612 and
Permit2 routes also require the buyer/payer as their actual caller. WithIntent
checks the buyer's own signature even when the executor is also the buyer.
An offer-signing delegation never grants token-spending authority.

A Safe's ability to CALL a payment entry does not establish that the token
accepts a permit signed by that Safe. The EIP-2612 route forwards the token's
`permit(owner, spender, amount, deadline, v, r, s)` call; it does not translate
an ERC-1271 signature into a token permit. The retained token implementation
uses `ecrecover`, and the retained Safe test explicitly rejects that permit
route. Do not assume EIP-2612 support implies Safe signature support. Use
approval plus `ByPayer`, or an ERC-1271 PaymentIntent with sufficient allowance,
unless the exact token's permit behavior for the Safe has separate evidence.

The pinned Permit2 implementation has its own ERC-1271 verification path. A
retained universal-settlement test covers Safe 1.4.1 with a threshold signature
over the Safe-wrapped Permit2 digest, a prior token approval to Permit2 and a
sufficient governed whole-call gas budget. The test rejects raw owner
signatures that omit the Safe message wrapping.
The offer-specific Permit2 test uses an EOA payer; it does not establish a
joined Safe-plus-offer Permit2 execution. Check the pinned implementation,
asset permit policy, Safe signature encoding, allowance and gas budget before
using that route for a Safe.

The [signing guide](current-erc20-primary-offer-signing.md) keeps the original
Sales domain at the carrier separate from the original PaymentIntent domain at
contract 20. Preserve all fields and the independent buyer TICKET, seller digest
and payer-nonce replay identities. This atomic profile has no purchase ID.

## Complete user-call inventory

This inventory describes target entries and caller requirements. Inclusion
does not establish Safe compatibility with a token's permit signature scheme.

| Target | Calls | Actual authority |
| --- | --- | --- |
| Token | `approve` | Buyer/payer; spender is contract 20. |
| Carrier | `configureCollectionSigner`, `registerPrimaryOffer`, `cancelPrimaryOffer` | Current carrier owner. |
| Carrier | `expirePrimaryOffer`, `syncCollectionContest` | Permissionless calls whose state conditions still apply. |
| Carrier | `setPaused`, `setSalePaused` | Current pause/unpause role; the supplied caller must hold the applicable role. |
| Carrier | `raiseGasParameter` | Current governed gas authority. |
| Carrier | `transferOwnership`, `renounceOwnership` | Current owner; these change future owner authority. |
| Carrier | `revokeAuthorization` | Historical admitted seller, directly or through the original signed revocation. |
| Contract 20 | `settleERC20PrimarySaleByPayer` | Actual buyer/payer with sufficient token allowance to contract 20. |
| Contract 20 | `settleERC20PrimarySaleWithEIP2612Permit` | Actual buyer/payer and a valid token permit; Safe CALL capability alone is insufficient. |
| Contract 20 | `settleERC20PrimarySaleWithPermit2` | Actual buyer/payer, token approval to pinned Permit2 and its valid permit signature; Safe use has the evidence limits above. |
| Contract 20 | `settleERC20PrimarySaleWithIntent` | Buyer-signed intent; a nonpayer executor must additionally be a live buyer delegate. |
| Contract 20 | `revokePaymentIntent`, `revokePaymentIntentWithSignature` | Direct payer or original signed payer revocation. |
| Manager | `voidMintOffer` | Direct buyer or original signed MintTicketRevocation. |

The carrier's `executeERC20PreRevenueSingleStep` and contract 20's
`fundERC20PrimarySale` are restricted transport callbacks. They are omitted from
the user-call inventory and rejected by the Safe example. No Safe call bypasses
their active callback context.

## Review and simulate

The [offline example](../examples/current-erc20-primary-offer.mjs) takes exact
caller-supplied compiled ABIs and already-prepared actions. Its
`erc20PrimaryOfferSafeInventory` lists the 19 user-entry selectors.
`createERC20PrimaryOfferSafeReview` checks each action's actual caller, calldata,
nonpayable value and target ABI before returning an ordered review plan.

```js
const review = createERC20PrimaryOfferSafeReview({
  chainId,
  title: "Approve and fund one ERC20 primary offer",
  catalog, // exact sale/payment/manager/token ABIs for the intended deployment
  actions: [
    { kind: "token", safe: buyerSafe, intent: "Approve contract 20 for this price", prepared: approval },
    { kind: "payment", safe: buyerSafe, intent: "Fund and mint the reviewed offer", prepared: funding },
  ],
});
```

A plan records order; simulating one step does not execute earlier steps. Mine
and verify a necessary approval before simulating dependent funding. Re-read
the exact sale, policy, phase, signature replay, execution nonce and preview at
a concrete block. Funding uses the same canonical acceptance bytes as the
reviewed preview. A changed candidate requires renewed review.

On failure, retain the original bytes and inspect the failed dependency before
an explicit retry. On success, check the Safe's own execution event, the
carrier execution and original Recorder settlement result. An outer successful
receipt alone is insufficient. Historical seller and payment revocations
remain separate from live sale admission.

## Supported profile and evidence

This client supports positive ERC20 price, ACTIVE asset, PROFILE primary rights,
STRICT_MATCH mode, singleton mint and zero declared native reveal fee. Both
Sales signatures have `finalizeBy = 0`. It does not join the held native-fee
allowance design or convert ERC20 value into a reveal fee.

The compiled fixture pins root source `2e0fca1a` with shared implementation
`1d4e7236` and carrier `94eaedc3`. Source, ABI, signing and synthetic RPC checks
do not establish actual Safe execution, joined current-stack runtime, gas,
deployment, audit or release readiness.
