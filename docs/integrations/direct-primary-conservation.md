# Original direct-sale conservation receipts

The original `StreamFixedPriceSaleAdapter`, `StreamERC20FixedPriceSaleAdapter`
and `StreamEnglishAuctionHouse` retain their purchase, authorization and payment
APIs. Their successful paid operations now retain a typed DIRECT receipt and
call the permanent Core-bound conservation floor in the same transaction.
This source batch does not establish runtime acceptance or the 500,000-gas
collector ceiling.

## Deployment and admission

Register each product in the Core's canonical module registry with:

| Field | Value |
| --- | --- |
| Module type | `keccak256("DIRECT_PRIMARY_SALE_ADAPTER")` |
| Module version | `keccak256("6529STREAM_DIRECT_PRIMARY_SALE_V1")` |
| Served interface | `IStreamDirectPrimarySaleReceipt` |
| Runtime hash | The actual deployed product's code hash |

Use the genuine constructor/bootstrap or governed registration path. Product
constructors pin their Core, Manager and Manager's canonical registry; live
operations authenticate that deployment against Core's registry selection.
The extra receipt interface does not change the original product interface IDs.

Bind the actual conservation ledger through Core's original governance
transition before a paid purchase or auction settlement. A missing binding,
wrong runtime, failed floor call or malformed return reverts the paid operation.
The floor call uses the ledger's existing governed
`CONSERVATION_FLOOR_CALL_GAS` parameter. Its allowance and caller return reserve
are separate from measured gas consumption and the collector ceiling.

Native and ERC-20 purchases require an ACTIVE product. Auction creation also
requires ACTIVE admission and retains its actual creation time and registry
revision. An already-created auction may settle after DEPRECATED status only
when both retained values strictly precede the deprecation boundary. Unknown
or INCIDENT_REVOKED products cannot settle a paid receipt. Existing auction
rights and mint identities remain those authenticated at creation; settlement
does not require a new mint or reactivate its old mint phase.

## Actual outcome and immutable history

[The typed receipt](../../smart-contracts/interfaces/stream/revenue/StreamDirectPrimarySaleTypes.sol)
retains the original signed authorization digest, collection and token,
checked Manager operation root and exact operation ID, bound mint policy,
original primary policy, split profile and wallet, admission time/revision,
actual payer and beneficiary, asset, amount and direct-versus-escrow outcome.
The original nonce-derived authorization ID remains its lookup key.

The receipt hash has its own DIRECT domain and binds the deployment chain,
Core, actual product address, product kind, original authorization ID and
entire typed receipt. The native, ERC-20 and auction product kinds are distinct.
No universal settlement candidate, result or consumed key is invented.

The product writes the receipt only after its original funding and
callback-sensitive mint/transfer checks. The floor independently reads that
stored receipt during the same call. A later failure rolls back the receipt,
floor history, funds, escrow credits, commercial authorization and mint effects
together. Historical product receipt getters read immutable local storage;
they do not need a current provider or a fresh resolver selection.

Core retains completed token identity and lifecycle. It does not expose a
completed token-to-operation receipt. The operation join uses the actual
product's checked Manager return vector, its retained original mint witness,
and the pinned Manager's consumed operation-root and authorization reads.

An ERC-721 receiver can transfer the token onward during its mint callback.
Core still rejects burning during that callback with `MintExecutionInProgress`.
Auction delivery happens after its earlier custody mint, so an authorized
receiver can burn at delivery when the collection permits burns. The paid
receipt retains the original beneficiary and permanent completed token identity;
it does not promise that the beneficiary remains the current owner.

For a Safe relayer, a failed inner purchase can still consume the outer Safe
transaction nonce and emit `ExecutionFailure`. The product's authorization,
payer payment-intent nonce and payment/mint state remain unchanged. Retry the
same signed purchase using a newly authorized Safe transaction.

## Which operations record a paid receipt

| Operation | Receipt point |
| --- | --- |
| Positive-price native fixed purchase | After funding and successful mint |
| ERC-20 fixed purchase | After exact payment and successful mint |
| Original English auction with a winning bid | After funding and successful custody transfer |
| Native signed zero-price mint | No paid receipt |
| Auction creation or bids | No paid receipt |
| No-bid return, cancellation, refund or withdrawal | No paid receipt |

No separate preparation transaction is required. The floor's documentary and
semantic-release requirements remain those of the actual declared tier; absent
evidence does not imply a waiver. The floor's
[`directPrimarySaleFloorReceipt`](../../smart-contracts/interfaces/stream/metadata/IStreamDirectPrimaryConservationFloor.sol)
getter and `ConservationDirectPrimarySaleRecorded` event retain the complete
original receipt and bindings with their first-sale and release evidence links.
A DIRECT key returns a zero universal `settlementReceipt` and cannot authorize
an original universal supplemental-payment join.
