# Current native allowlist clearing calls

`current-native-allowlist-clearing.ts` prepares the additive Merkle-ceiling route
from source commit `2dc3ea7ee35d4e5d698a2245bed54fcb03665819`. It preserves the original
clearing configuration, authorization, EIP-712 domain, time windows, financial
legs, rebate entitlements, and refunds. The module returns unsigned calls and
read-only simulations. It does not sign, send, deploy, invoke internal callbacks,
or establish whole-stack or Safe runtime acceptance.

## Registration commitments

`prepareRegistration` pins one concrete block, current owner, observed runtime, nonce and
canonical sale ID, then simulates `registerAllowlistClearingSale` from that owner.
The caller supplies the expected primary-policy baseline because registration
captures it from the current resolver and the registration return contains only
the sale ID. The returned config hash therefore labels the baseline as
caller-supplied and remains unverified until the stored `saleRecord` can be read.
The returned runtime hash records the code observed at that block for caller
comparison. This module does not automatically compare it with another
observation or canonical deployment and does not establish implementation identity.

`inspectSale` reconstructs the stored sale ID, schedule hash, window hash,
original config hash and allowlist wrapper from the record's captured baseline.
The original config hash is:

```text
keccak256(abi.encode(
  keccak256("6529STREAM_NATIVE_CLEARING_CONFIG_V1"),
  saleId, config, scheduleHash, windowPolicyHash,
  expectedPrimaryPolicyHash, address(0)
))
```

The wrapper is
`keccak256(abi.encode(keccak256("6529STREAM_NATIVE_ALLOWLIST_CLEARING_CONFIG_V1"), originalHash, counterId))`.
The positive resting floor is immutable. Prices and step amounts are `uint96`,
schedule times are `uint64`, `stepSeconds` is `uint32`, and signed allowlist
ceilings retain the full `uint256` width.

## Same-leaf ceiling and purchase

Supply ordered, single-proof groups for every filtered Merkle counter. Counter
IDs are unchecked caller labels used only to identify the selected local group;
the payable simulation validates each positional witness against the Manager's
live counter order and roots. Only the selected counter may enable a price. Its
`hasPriceOverride` and full-width `priceOverride` must exactly equal the signed
authorization. A disabled override is `false/0`; an enabled override must be at
least the positive resting floor.

The charged amount is `min(current schedule price, signed ceiling)` when the
override is enabled, otherwise the schedule price. The original signed
`unitPrice` remains an additional maximum. The client never narrows or stores a
clamped ceiling. Later uniform clearing still uses
`min(global clearing price, original authenticated ceiling)`.

`preparePurchase` verifies the stored immutable hashes, purchase nonce, window
commitments, current schedule quote, token-data hash, original EIP-712 digest and
domain, and reveal fee. It encodes the same resolver bytes into
`purchaseWithAllowlist`, then performs a sender-aware payable `eth_call`. That
simulation is the check for live proof order/root, signatures, consent, policy,
mint admission, settlement and current payment behavior at the pinned block.
State can still change before inclusion.

`maximumPaymentAllowance + revealFeeAllowance` is sent as one fungible value.
The client separately requires the chosen reveal allowance to cover the pinned
fee, while the contract uses all remaining value after that live fee to cover
the charge. The rest becomes immediately claimable payer excess. The resting floor is
settled in the original purchase. Held overage remains refundable-class custody
for later clearing rebates and supplemental settlement.

## Financial calls and refunds

`fixClearingPrice`, `settlePurchaseSupplement`, and `synchronizeRebate` return
the original permissionless calls. Their time, pause, current-rights and
financial preconditions remain contract enforced. Synchronization emits rebate
evidence; it does not create the entitlement.

`readRefund` and `claimRefund` do not reapply new-sale admission. While open,
only separate excess is claimable. Once price is fixed, rebates are immediately
available even before synchronization or supplemental completion. Terminal
unlock retains settled floors and completed supplements. Only the credited payer
may send the claim and choose its nonzero recipient.

The shared fixture `test/fixtures/current-native-moving-price-abi.json` pins the
290-source compiler capture and selected ABI/source hashes. It is encoding
evidence, not live transaction or release evidence.
