# Native immediate-sale reveal and refunds

`StreamNativeFixedPriceSaleAdapter` supports fixed-price, open-edition,
zero-price-claim and pay-what-you-want mints through its original `purchase` and
`executePriceProgram` signatures. Its additive
[`IStreamImmediateSaleReveal`](../smart-contracts/interfaces/stream/mint/IStreamImmediateSaleReveal.sol)
interface exposes the live coordinator policy, reveal SLO and payer refunds.
Signing domains and sale-price commitments are unchanged.

Send the signed sale amount plus a reveal-fee allowance. For a 1,000 wei price
and 20 wei allowance, a live 12 wei fee sends 1,000 to the official recorder,
12 to the coordinator's collection escrow, and credits 8 to the payer. A live
fee of 3 instead credits 17. An allowance below the current declared fee reverts
before payment, mint or replay consumption. Free claims use the same fee rule,
with no official revenue record.

The adapter captures the selected coordinator, code hash and policy before
payment. It checks the exact escrow funding delta after mint. `AT_MINT` makes
one zero-value `requestEntropy` attempt after Manager returns; `OWNER_WINDOW`
only funds escrow. Provider failure, gas exhaustion and malformed return data
produce a bounded failure event while retaining the minted token and escrow
funding for later ordinary requesting. The adapter never requests fresh entropy.
Selected dependency and sale authority checks still protect the transaction.
The parent transaction must also have gas for settlement, the mint, the full
request stipend and post-call checks/refund accounting. The local EIP-150
precheck is not a measurement of that complete transaction budget.

Unused allowance belongs to the payer at `refundableBalance(saleId, payer)`.
The payer calls `claimRefund(saleId, recipient)`, including through a Safe CALL,
with zero value. A rejected destination preserves the credit for another
attempt. Claims remain callable while the adapter is paused or retired.
`refundAccountCount` and `refundAccountAt` enumerate historical credit accounts
for state discovery; `refundLiability` reports the current total owed.

Deployment now supplies a fifth constructor argument: the explicit
`REVEAL_ATTEMPT_GAS_LIMIT` gas configuration. The host derives its governance
authority from the existing split factory and uses the standard delayed,
raise-only gas parameter rules. The tests' 2,000,000 gas value and 50,000 floor
are planning inputs, not measured release limits. The production deployment
planner must include this parameter and requester/role admission in its final
inventory.

The source batch includes ten focused revenue/provider/refund cases and two
current-stack Safe scenarios for immediate successful request and deferred retry.
ABI/type compilation passes; native runtime, transaction gas, final contract
size, generated client inventory and the complete deployment join remain
pending the combined validation pass. ERC-20 immediate-fee consumption remains
separate implementation work.

The normative fee and attempt rules remain in
[SSA-REVEAL](stream-sales-and-auctions.md#reveal-fees-and-post-mint-entropy) and
[ADR 0013, U6/U7](adr/0013-world-class-pass-round-4.md#u6-sales-and-mint-seam-repairs).
