# Current ERC20 paid burn-to-mint client

The dedicated kind-8 carrier and gate burn an ordered set of native Stream
tokens, pay a positive ERC20 price through contract 20 and the official
recorder, and mint one new token. The client prepares unsigned calls and checks
source authority, candidate commitments and retained execution evidence.
The [Safe guide](current-erc20-burn-mint-safe.md) covers its 20 user/configuration
selectors and separates RPC simulation from submitted calls.

## Supported configuration

Use the exact `StreamERC20BurnMintSale` and `StreamERC20BurnMintGate`
deployments. The carrier is deployed first; the gate pins that carrier's
address and code hash. This is a distinct gate with no free burn entry.
The existing [free/native client](current-burn-mint.md) keeps its own routes.

The program uses the original `ProgramConfig` tuple, with `prepared = false`
and `nativeSaleAdapter = address(0)`. Source collection IDs are sorted and
unique, and the source-token count equals `sourcesPerMint` (at most 16).
Configure a singleton mint phase with this gate and its exact program hash,
authorize the carrier as executor, and obtain normal Artist policy and sale
configuration consent.

The sale uses the original nine-field `SaleConfig`: payment adapter, target
collection, phase, asset, positive price, start/end times, mint-policy hash and
expected primary-policy hash. The supported payment profile is order-one
`PRE_REVENUE_SINGLE_STEP`, ACTIVE ERC20 asset, collection PROFILE primary
rights and STRICT_MATCH policy. The coordinator must declare zero native
reveal fee. No native reveal allowance is added to a funding call.

## Original signing and distinct roles

The [signing helpers](current-erc20-burn-mint-signing.md) preserve the original
`UniversalSaleAuthorization` fields and domain name
`6529StreamUniversalFixedPriceSaleAdapter`, version `1`. The verifying contract
is the actual burn carrier. Platform and Artist signatures remain separate
from the token payer's original PaymentIntent, whose verifier is contract 20.

Build `Execution` as `{ sale, sourceTokenIds }`, where `sale` contains the
original authorization, token data, platform signature and Artist signature.
The original authorization has no source-token array field. The complete
execution bytes, ordered sources and gate proof bind the settlement candidate.
Changing sources requires a new preview; the client never invents a new
signing type or custody purchase ID.

The signed executor calls contract 20. It needs source-owner or approved
operator authority, and the gate independently needs burn approval. The payer
and signed output recipient may differ from the executor and each source
owner. The universal burn candidate's poster is zero. These rules differ from
the atomic primary-offer client; its buyer-equals-recipient checks do not apply.

## Prepare, inspect and fund

```js
const prepared = prepareERC20BurnMintExecution(deployment, configuration, execution);
const capture = await inspectERC20BurnMintExecution(provider, prepared, {
  blockTag: blockNumber,
});
const funding = prepareERC20BurnMintFunding(capture, {
  kind: "intent",
  intent: payerIntent,
  signature: payerSignature,
});
await simulateERC20BurnMintFunding(provider, funding, { blockTag: blockNumber });
```

The deployment supplies the chain and exact address/runtime hash pins for
carrier, gate, Core, module registry, Manager, Ledger, payment adapter,
recorder and asset. Keep these with the prepared inputs and returned capture.
Inspection joins the sale, immutable program, source ownership, separate
approvals and original replay identities at a concrete block.

The carrier's `previewExecution` is nonpayable because it temporarily installs
a guarded prospective proof in the gate. Invoke it through `eth_call`, with
zero value. A naked Manager preview lacks that proof and cannot substitute
for the carrier preview. The call does not burn, pay, mint or reserve a nonce.

Funding supports the four original contract-20 routes: `payer`, `intent`,
`eip2612` and `permit2`. Payer and both permit routes require the signed
executor to be the payer. The intent route permits a distinct executor with
the payer's valid original signature and the independent NFT permissions.
The same execution bytes go into the guarded preview and funding request.
Current and bound mint-policy hashes may legitimately differ under allowed
phase grace; preserve both values from the candidate.

Use `prepareERC20BurnMintAction` for public carrier/gate configuration and
administration, original payer revocations, Core source approvals and ERC20
approval. It returns a named caller and unsigned zero-value call. Encoding
does not establish owner or governance authority. The exact Safe inventory
excludes fixed callbacks and the RPC-only preview.

ERC20 approval requires an explicit `spender` and `amount`. Select contract 20
for payer/intent funding, or the reviewed Permit2 deployment when preparing its
required prior token allowance; the helper never substitutes a spender.

`inspectERC20BurnMintActionReceipt` verifies `registerSale` and
`configureProgram`: the exact direct or ordinary Safe call, canonical
configuration event, expected sale/program identity and receipt-block stored
record must agree. Other administration and approval actions support unsigned
preparation and actual-caller simulation; this helper does not claim a
dedicated historical receipt verifier for every administrative selector.

Refresh inspection after approvals or any relevant state change. Simulating
the final funding call does not apply earlier approvals. A stale phase,
source owner, nonce, consent, asset policy or runtime dependency may invalidate
the candidate or make the transaction revert.

## Verify the result

`inspectERC20BurnMintFundingReceipt` accepts the exact funding plan and a
transaction hash, with direct or ordinary Safe execution selected explicitly.
Check the original Core burn/transfer and gate source/batch events, singleton
Manager/Ledger mint, universal execution and official recorder settlement.
Universal execution emits status 1 followed by completed status 2. Original
source owners come from burn evidence; the signed executor is the gate event's
redeemer, while the Manager executor and recorder settlement caller are the
carrier.

Retained native identity, nullifiers, authorization/execution replay and
settlement readback establish the recorded result at its block. A recipient
contract may transfer the minted NFT during its receiver callback, so its
later owner need not equal the signed original recipient. Bind the original
mint recipient using the mint event rather than replacing that evidence with
a current-owner assumption.

The client bounds raw token data to 8,192 bytes and each supplied signature to
65,536 bytes. Receipt inspection accepts at most 512 logs and 524,288 bytes of
transaction calldata, with a 16,384-byte bound per RPC result or event body.
Exceeding these inspection limits requires a separate reviewed verifier and
does not prove that an onchain call is invalid.

## Evidence boundary

The [fixture generator](../scripts/generate-current-erc20-burn-mint-fixture.mjs)
pins compiler capture `c717a3e1`, tree `604224dd42310e747eb329c88e4eb76f1cfed1d5`,
and feature source `83c67868`. All 2,108 literal source inputs match that commit;
203 selected complete ABI entries cover the client and receipt interfaces.

Client encoding, synthetic RPC and Safe-plan tests do not establish joined
current-stack execution, real Safe execution, gas limits, deployment or release
acceptance. The [burn/finality warning helper](current-burn-finality.md) accepts
this dedicated gate through `erc20BurnMintDeployments`, with its own discovery
range and a separate code pin for the immutable ERC20 sale carrier. Include it
when reviewing source or target collection closure; omitted deployments remain
outside the report's explicitly incomplete inventory.
