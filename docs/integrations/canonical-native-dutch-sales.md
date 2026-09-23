# Canonical native Dutch sales

`StreamNativeDutchSales` implements signed and public standard Dutch purchases
using the original `6529Stream Sales` version `1` authorization domain. Each
purchase mints one token through the Manager and Ledger. Positive prices settle
through the existing native recorder; a declared free outcome creates no
official-revenue or conservation settlement receipt.

## Configuration and setup

| Setting | Accepted values |
| --- | --- |
| Sale kind | DUTCH_AUCTION (`3`), with no clearing rebates |
| Authority | SIGNED (`1`) or PUBLIC (`2`) |
| Payment | Native; caller, payer and executor are the same account |
| Supply | Positive immutable cap; one token per purchase |
| Mint phase | Existing, authorized, single-step capable and ungated |
| Paid rights | Collection PROFILE or static TEMPLATE, STRICT (`0`) |
| Allowlist | Original Manager Merkle price counter, or none |
| Closing | Timed, or manual with `endsAt = 0` |

`Configuration` contains the original immediate-sale configuration as `sale`,
an immutable `DutchPriceSchedule` and a `declaredFree` flag. The existing
`IStreamNativeImmediateSales.Purchase` tuple is used directly.

Register before `schedule.startTime`. Set `sale.startsAt` to that time and
`sale.unitPrice` to `schedule.startPrice`. A timed sale must close at or after
the schedule ends. Both decay kinds require a positive starting price, a
resting price no greater than the starting price, and an end after the start.
LINEAR (`0`) requires zero step fields; STEPPED (`1`) requires positive step
seconds and amount. A zero resting price requires `declaredFree` at creation.

The complete configuration, including the free declaration, is bound into its
family-specific configuration hash. `saleRecord` exposes the schedule and its
original `6529STREAM_DUTCH_SCHEDULE_V1` hash, bound to chain, adapter and sale ID.
These facts cannot be edited after registration.

Use the [canonical immediate-sale setup](native-immediate-sales.md) for
deployment dependencies, governed signer membership, native module admission,
phase authorization, Artist consent and reveal parameters. Artist consent
binds this complete registered Dutch configuration. The Manager enforces its
own phase, counter, royalty and replay policies.

## Price and payment

`schedulePrice(saleId)` reads the committed curve at `block.timestamp`.
Linear prices round upward between endpoints. Stepped prices subtract each
completed step, and both curves reach the resting price at the schedule end.
Pauses extend the closing window by their union duration; the price continues
decaying during a pause. Signature deadlines and Manager phase end times
retain their independent hard limits.

For a signed purchase without a proven override, the original signed
`unitPrice` is a maximum on the current price. An authenticated leaf with
`hasPriceOverride` replaces that signed word's pricing role:

```text
charge = min(current schedule price, proven override)
buyer maximum = msg.value - captured reveal fee
buyer maximum >= charge
pull refund = buyer maximum - charge
```

For example, schedule price 1000 and a proven ceiling of 600 charge 600 even
if the unchanged signed maximum is 599. The adapter and Manager verify the
same original proof bytes, payer and beneficiary. Without an enabled override,
the signed maximum still applies. A public purchase uses the schedule directly
unless its proven leaf sets a ceiling.

The host captures the live reveal quote once. If native value cannot fund that
fee, it rejects with `SaleRevealFeeBelowRequired`. If the remainder is below
the price, it rejects with `DutchPaymentBelowPrice`. Every excess becomes payer
pull credit, including DISABLED/INSTANT entropy, an undeclared policy or a zero
fee. There is no redundant calldata maximum or exact-payment requirement.

An enabled zero override requires `declaredFree`; otherwise it rejects with
`SalePriceOverrideZeroUndeclared`. A permitted zero still consumes Manager
authorization and mint operation identities, mints and follows the reveal
policy. The execution emits `FreeDutchExecuted`, has a zero settlement key,
and never creates a paid public witness or calls the recorder. A later paid
mint still needs the genuine conservation floor; free minting grants no
exemption. Declare any intended WAIVED tier before the first mint.

## Authorization, receipts and rollback

SIGNED mode recomputes the original full authorization: chain, adapter,
Manager, sale, phase, kind, explicit parties, tagged singleton array hashes,
mint and primary policy hashes, quantity, nonce and deadline. Native asset,
STRICT mode, selected-content hash and finalize-by are zero. The original
signed price and digest remain unchanged when a Merkle ceiling applies.
Manager's full-payload historical revocation supports kind `3` through the
same immutable seven-field binding, including after signer disablement or
sale closure.

PUBLIC mode retains a zero Sales digest. Its Manager replay ID uses
`6529STREAM_NATIVE_PUBLIC_DUTCH_MINT_AUTHORIZATION_V1`, binding chain, adapter,
Manager, configuration and the complete nonce-bearing purchase request.

Positive purchases settle the charged amount before minting. The host records
pending execution state before interactions and checks retained admission,
Artist facts, mint policy and paid rights afterward. A failed receiver,
floor, funding or retained-state check reverts receipts, transfers, counters
and replay consumption together. Refund claims remain available after stops
or closure; refunds belong to the payer, including a Safe payer.

## Validation boundary

The dedicated source suite uses actual Core, Manager, Ledger, native recorder
and conservation-floor contracts with explicit Artist and entropy test
boundaries. Source checks and selected bytecode measurements do not establish
runtime acceptance. Scoped native execution, actual-current composition,
complete production link/size and gas checks, release evidence and audit
acceptance remain separate requirements.
