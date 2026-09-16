# Current native allowlist prices

`current-native-allowlist-price.ts` prepares and inspects the additive native
allowlist price-program calls introduced at source commit `f1745f33`. It keeps
the original native price-program EIP-712 authorization and adds proof-bearing
registration, preview and execution calls. The module never sends a
transaction.

## Registration

`prepareNativeAllowlistPriceRegistration` returns the exact owner call plus
the sale ID, original price-program hash and final wrapped allowlist hash. The
sale ID includes `nextSaleNonce`; the returned
`expectedNonceMustBeLiveChecked` marker is deliberate. Run
`inspectNativeAllowlistPriceRegistration` at a concrete block before review or
`simulateNativeAllowlistPriceRegistration` before submission. A later owner
registration can consume that nonce.

The policy selects one nonzero counter and declares whether a zero fixed/open
leaf is allowed. `allowFree` must remain false for zero-price and pay-what-you-
want kinds. The client rejects coercible numbers, booleans and unknown object
properties before ABI encoding.

## Price rules

- Fixed and open edition programs retain their original signed public price.
  An enabled selected leaf replaces the charging band exactly, including a
  price above the original public price. Zero requires `allowFree`.
- Kind 12 signs, chooses and proves zero; `allowFree` remains false.
- Kind 13 uses `max(config.minUnitPrice, selected leaf price)` when the leaf is
  enabled, or `max(config.minUnitPrice, signed unitPrice)` otherwise. Its
  configured maximum remains the ceiling.

`nativeAllowlistPriceMatrix` reproduces these bounds without RPC access.

## Proof ordering and purchase

`prepareNativeAllowlistPricePurchase` accepts one proof per caller-described
group, up to the protocol limit of 16. The groups must be supplied in the
Manager phase's filtered `MERKLE_STATIC` order. Only the selected group may
enable a price. The `counterId` labels help the caller select that group, but
they are not encoded and are not authenticated as labels.

The exact `AllowlistProof[][]` bytes enter `executeAllowlistPriceProgram`, the
sale execution commitment and the Manager `MintBatch`. A pinned canonical
preview is the validation boundary for positional proof order, current roots,
counter configuration, phase policy, both retained signatures and price.

The caller is the authorization payer and executor. CALL value is the chosen
price plus the explicit reveal-fee allowance. The contract credits unused
allowance to the payer; the inspector only requires that the allowance cover
the pinned quote. It does not invent a sale ID, signature, payment credit or
new signed field.

## Inspection limits

Inspection uses a concrete numeric block and strictly decodes canonical ABI
returns. It checks the stored record and policy, sale ID, digest, reveal quote
and canonical preview. `simulateNativeAllowlistPricePurchase` additionally
executes the exact payable CALL from the payer at that same block.

Numeric pins have no reorg hash check. The client does not establish target or
dependency bytecode identity, Safe threshold authority, future state, or
transaction inclusion. The compiler fixture is selected ABI and source-
encoding evidence only; it is not runtime acceptance.
