# Native price programs

`IStreamNativePricePrograms` adds explicit signed price programs to
`StreamNativeFixedPriceSaleAdapter`. Each execution mints one ERC721 token.
The existing `registerSale` / `purchase` interface, fixed authorization digest,
commercial nonce and execution replay rules remain supported unchanged.

The new program uses `registerPriceProgram`, `priceProgramRecord`,
`priceProgramIdFor`, `priceProgramAuthorizationDigest`, `previewPriceProgram`,
`executePriceProgram`, and terminal `closePriceProgram`. These are distinct
methods, not overloads of the existing fixed-sale methods.

## Explicit kinds and close rules

| Kind | Price rule | Per-sale quantity |
| --- | --- | --- |
| `FIXED_PRICE` (`0`) | Equal positive min/max; signed price and chosen price equal it | Positive cap |
| `OPEN_EDITION` (`1`) | Equal positive min/max; signed price and chosen price equal it | Explicit zero cap means no per-sale bound |
| `ZERO_PRICE_CLAIM` (`12`) | Min/max, signed price and chosen price all zero | Positive cap |
| `PAY_WHAT_YOU_WANT` (`13`) | Chosen price inside immutable min/max and at least the signed minimum; maximum is positive | Positive cap |

A free-only record also has zero `primaryAssignmentHash`. Other kinds pin the
actual current collection primary assignment when registered. An absent record
has no registration nonce and always rejects; an all-zero configuration is
never interpreted as a free sale. Unsupported kind values reject.

`closeRule = 1` requires an end after the start and accepts execution through
that end timestamp. `closeRule = 2` requires `endsAt = 0` and an explicit manual
close. The owner, including a Safe owner, can close either program permanently.
There is no reopen method. Pausing the consumer blocks execution; it does not
close a program or reset its successful-mint count.

Only successful executions count toward `maxSaleQuantity`. The count is
reserved before external calls and rolls back with a failed mint. Open edition
removes only the sale's cap: current collection supply, phase policy, gates and
manager/ledger counters still bind every mint. This API does not implement batch
quantity purchases or configure per-wallet fairness counters.

## Signing and checkout

The new EIP712 domain is `(6529StreamNativePricePrograms, 1, chainId,
consumerAddress)`. Sign the exact `PriceProgramAuthorization` tuple in the
interface; its type name is `NativePriceProgramAuthorization`. The old
`NativeSaleAuthorization` domain/type is not reused. Both the platform and
current accepted artist authorize the new tuple, including configuration hash,
payer/executor/recipient, token data hash, mint commitment, nonces, deadline,
concrete primary policy and signed unit price.

For PWYW, `unitPrice` is the minimum accepted by the authorization. The buyer
passes `chosenUnitPrice` separately. The effective floor is the larger of the
record minimum and signed minimum. The record maximum remains binding. A Safe
can sign through its actual ERC1271 handler and execute payable checkout.
Native payer and executor are both the actual caller; there is no relayed
native payment path.

`msg.value` must equal the chosen price exactly. This first program profile
carries no reveal-fee line item. The complete chosen price, including any amount
above the signed minimum, is official primary revenue when it is positive.
The canonical candidate commitment and execution-data hash bind that amount.
The authenticated `(saleId, executionNonce)` is consumed once, independently of
the artist-scoped commercial nonce, so another price choice cannot reopen an
execution. The manager authorization ID continues to be the ticket-domain hash
of the full EIP712 digest.

`previewPriceProgram` validates the same signatures, record, price, admission
and manager preview as execution. Its `PriceProgramResult` has an explicit
`revenueOutcome`: `1` is FREE and `2` is PAID. A preview has no token ID or
settlement key. It is a quote for the current state, not a reservation.

## Free and paid execution

FREE calls the manager without calling the official recorder, materializing a
profile, depositing to a wallet, or creating revenue escrow. It has no official
settlement key, result, total or revenue event. Its typed result has charged
amount and settlement key zero and `escrowed = false`; its own
`NativePriceProgramFreeMint` event identifies the actual minted token and
manager operation. Existing passive consumer/recorder/escrow balances remain
unchanged.

A PWYW authorization with minimum zero can choose zero even if its unused
signed concrete payout policy is stale. A positive choice must match the current
concrete policy and pinned assignment. Both outcomes consume the same replay
lanes. The adapter's free branch skips payout/profile derivation; this does not
bypass the real manager's artist mint consent, economics eligibility, gates,
ledger or Core checks.

PAID follows the [native shared settlement path](native-primary-settlement.md),
including actual PROFILE or current COLLECTION_ARTIST materialization, bounded
wallet funding, exact escrow fallback and full result validation. A later
recipient callback cannot redirect already materialized proceeds. The new
`NativePriceProgramPaidMint` event records the exact charged amount, official
key and escrow flag in addition to the unchanged four canonical recorder events.
Any failure rolls back money, registration, counts, replay and mint effects;
the same valid authorization can then be retried.

Configuration events contain the full configuration, nonce, hash and captured
module lifecycle, so those terms can be reconstructed. FREE/PAID completion and
terminal-close events expose the resulting successful count. All new events
carry `uint16 schemaVersion = 1`.

## Deployment and current limits

Link `StreamNativePriceProgram` in addition to the native admission/support
libraries. Its preparation functions are read-only. The consumer invokes its exact recorder call and
completion-event functions through compiler-generated library links; direct
state-changing CALL rejects. Another contract can delegatecall the library in
its own context, which does not grant the consumer's identity or permissions. The consumer supplies its
immutable recorder. There is no arbitrary call or delegatecall API, new owner,
or official accounting store in the library. Recorder 9, contract 20 and the
permit implementation are unchanged by this increment.

The focused proof uses the real module registry and revenue contracts, official
Safe 1.4.1, and explicit Core/manager/artist domain doubles. Payout-read failures
are injected only to prove that the zero branch does not enter those reads;
positive-price controls prove the same boundary is enforced. Full current-Core
composition and fully cold gas limits require separate integration evidence.

Public purchases without per-buyer signatures and allowlist price overrides
remain required subsequent work, dependent on canonical artist sale-parameter
consent and signer-set facts. Phase/economics consent is not substituted for
that authority. Reveal-fee allowance handling, pause-window tolling and batch
purchases are also outside this profile. Refund-window sales follow as a
separate deferred purchase/escrow/finalize/refund/unlock lifecycle: buying does
not mint or create official revenue, and a dead finalization path must always
unlock a permanent pull refund. The immediate program does not implement or
weaken those obligations.

The normative requirements are [SSA-FIXED, SSA-ZERO, SSA-PWYW and SSA-REFUND](../stream-sales-and-auctions.md),
with [the revenue orchestration boundary](../revenue-splits-and-royalties.md).
