# Current native allowlist refund-window sales

`current-native-allowlist-refund.ts` prepares the additive proof-bearing
refund-window calls introduced at source commit `90e68ebf`. It retains the
original refund configuration, authorization, EIP-712 domain, replay lanes and
pull-credit ownership. The module does not broadcast transactions.

## Registration and signing facts

`prepareNativeAllowlistRefundRegistration` produces the owner CALL and exact
sale ID, window policy, original configuration and wrapped allowlist
configuration hashes. The original configuration captures the live primary
policy baseline. The preparer accepts that hash as an expectation because the
registration entrypoint does not return it.

Before registration, `inspectNativeAllowlistRefundRegistration` checks the
owner, live `nextSaleNonce`, chain and configured dependency addresses at one
concrete block. Simulation checks the returned sale ID. Neither operation
attests the expected primary policy baseline. After mining, run
`inspectRegisteredNativeAllowlistRefundSale` to compare the stored config,
nonce, baseline, window hash, wrapped hash and allowlist policy. Complete this
readback before requesting the platform and Artist signatures.

`nativeRefundPurchaseAuthorizationPayload` preserves all 15 original signed
fields. In particular, signed `price` remains the positive public config price.
The additive proof never changes the signed field. A zero bytes32 commercial
`nonce` is valid; the numeric payer `purchaseNonce` remains positive and
sequential.

## Exact allowlist price and funding

An enabled selected proof replaces the public price with its full uint256
`priceOverride`. It can be above the public price. A disabled proof falls back
to the public price. An enabled zero price requires the immutable `allowFree`
registration flag.

Purchase input contains one proof per caller-described Merkle group, with a
maximum of 16 groups. Supply them in the phase's filtered `MERKLE_STATIC`
order. Only the selected group may enable a price. The `counterId` labels are
local metadata used to select the price proof; the labels are not encoded in
resolver data. Exact payable simulation validates witness positions against
the live Manager state.

`priceFundingMaximum + revealFeeAllowance` is the exact CALL value. Funding is
fungible: after the live reveal fee is captured, the remaining value must
cover the selected charge. The client checks the declared fee allowance and
the combined value at inspection. Unused native value becomes payer-owned pull
credit.

## Pinned inspection and simulation

`inspectNativeAllowlistRefundPurchase` reconstructs the immutable prepared
packet before RPC access. At a concrete numeric block it checks the chain,
stored sale record and policy, authorization digest, payer purchase nonce,
declared reveal policy, attached funding and configured Core, Manager and
entropy addresses.

Read-only inspection does not establish signatures, Artist consent, phase
timing, proof validity, live admission or dependency runtime code identity.
`simulateNativeAllowlistRefundPurchase` performs the exact payable call from
the payer and checks the returned purchase ID. A numeric block pin has no reorg
hash check. Simulation does not prove Safe authority, inclusion-time state or
future acceptance.

The saved purchase record and saved resolver proof are verified separately by
`current-refund-purchase-record.ts`. Finalization always uses those captured
facts and does not reprice the purchase.

## Existing-purchase lifecycle

The module produces zero-value calls for:

- permissionless `finalizeRefundWindow` when the contract's deadline and pause
  rules allow it;
- payer-owned `refundPurchase` before the effective refund deadline;
- `unlockRefund` with an explicit protocol reason;
- permissionless `synchronizePurchaseWindow`;
- payer-owned `claimRefund` to a chosen nonzero recipient other than the
  adapter.

These helpers encode calls only. The contract enforces time, pause, status and
dependency eligibility. `readNativeRefundCredit` reads the payer's per-sale
credit at a concrete block. Refunds, unconditional time escape and pull claims
do not reapply current sale admission, Artist consent or allowlist proofs.

The compiler fixture is source and ABI encoding evidence. Full runtime and
current-stack acceptance remain separate validation work.
