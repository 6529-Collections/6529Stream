# ERC20 paid burn-to-mint with a Safe

The [paid burn client](current-erc20-burn-mint.md) prepares unsigned calls for
the dedicated kind-8 carrier and gate. Each user action uses ordinary Safe
`CALL`, operation 0, with zero native value. Payer, source-token owner,
executor and output recipient can be different accounts. Review each role
before approving a transaction.

## Independent permissions

The signed executor is the account that calls contract 20. It must own every
source NFT or have the owner's token-specific or operator approval. The gate
separately needs approval to call Core's burn entry. An ERC20 allowance or
PaymentIntent grants neither of those NFT permissions.

If the owner is also the executor, it can approve the gate for each reviewed
source token. If the executor is a separate account, one token-specific ERC721
approval cannot simultaneously name both executor and gate. Use a deliberate
combination of token-specific and operator approvals, and inspect both roles
again before execution. An operator approval applies to all that owner's Core
tokens; disclose that scope in the Safe plan.

Contract 20 is the token puller. The payer approves that payment adapter and
calls the `ByPayer` route itself, or supplies its original signed PaymentIntent
to the executor with sufficient allowance. A Safe payer can use its ERC-1271
signature for that intent. The carrier and gate need no ERC20 allowance.

EIP-2612 token support does not by itself establish support for a Safe's
ERC-1271 signature. That route forwards the token's `v/r/s` permit call.
Permit2 has separate contract-wallet signature, prior token approval, policy
and gas requirements. That prior token approval names the reviewed Permit2
deployment as spender. The typed asset approval action requires an explicit
`spender` and `amount` for either payment path.
The [permit evidence discussion](current-erc20-primary-offer-safe.md#caller-and-payment-boundaries)
describes the retained Safe evidence; it does not establish joined Safe
execution of this new burn carrier. Both permit routes still require the
actual payer as caller at contract 20.

## Complete user CALL inventory

The [offline example](../examples/current-erc20-burn-mint.mjs) exposes
`erc20BurnMintSafeInventory`, selecting 20 user-entry selectors from the exact
compiled ABIs. Inclusion describes a callable entry, not proof of authority or
signature acceptance.

| Target | User actions | Actual authority |
| --- | --- | --- |
| Carrier | `registerSale`, `cancelSale`, `setPaused` | Current carrier owner |
| Carrier | `cancelAuthorization` | The Artist whose original nonce is cancelled |
| Carrier and gate | `raiseGasParameter` | Applicable governed gas authority |
| Carrier and gate | `transferOwnership`, `renounceOwnership` | Current owner |
| Gate | `configureProgram` | Current gate owner; immutable original program per target |
| Core | `approve` | NFT owner or its existing operator; inspect executor and gate authority separately |
| Core | `setApprovalForAll` | Grants authority only over tokens owned by the caller |
| ERC20 | `approve` | Payer; exact intended spender and amount |
| Contract 20 | Four `settleERC20PrimarySale*` routes | Original payer/caller or signed intent requirements |
| Contract 20 | `revokePaymentIntent`, `revokePaymentIntentWithSignature` | Direct payer or original signed payer revocation |

`previewExecution` is nonpayable because it temporarily installs a guarded
prospective proof. Simulate it with RPC `eth_call`; the Safe plan does not
submit it as an action. The gate's `previewERC20Burn` and `executeERC20Burn`,
the carrier's `previewBurnExecution`, `executeBurnMint` and
`executeERC20PreRevenueSingleStep`, and contract 20's `fundERC20PrimarySale`
are transport callbacks. Their fixed caller/context conditions cannot be
bypassed by a Safe. The plan rejects these selectors.

## Review and execution order

```js
const review = createERC20BurnMintSafeReview({
  chainId,
  title: "Approve the reviewed burn sources and fund one ERC20 mint",
  catalog, // exact sale/gate/payment/core/token compiled ABIs
  actions: [
    { kind: "core", safe: sourceOwnerSafe, intent: "Approve the gate for this source token", prepared: sourceApproval },
    { kind: "token", safe: payerSafe, intent: "Approve contract 20 for the signed price", prepared: tokenApproval },
    { kind: "payment", safe: executorSafe, intent: "Burn the ordered sources, pay and mint", prepared: funding },
  ],
});
```

Add an explicit executor approval when the source owner differs from the
executor. The plan preserves order and identifies each actual Safe caller.
One call simulation does not execute an earlier approval. Mine and verify
required approvals before refreshing the pinned program, sale, source
authority and guarded preview, then simulate the funding call from its actual
caller. A changed candidate requires renewed review.

After submission, verify the Safe's execution event, the original per-source
burn evidence, singleton mint, universal execution and official settlement,
then read their retained state at the receipt block. An outer successful
receipt alone is insufficient. The exact ordered sources are part of the
committed execution bytes; replacing a source requires a fresh preview.

The client and Safe plan do not sign, submit or automatically retry calls.
Source and synthetic RPC tests remain separate from joined current-stack,
real Safe governance, gas and deployment acceptance.
