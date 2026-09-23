# ADR 0045: Native reveal fees for token sales

Status: Local implementation applied on 20 September 2026 following review of
the exact source artifact, under the owner's adopted full-v1 implementation
authority. ABI/type, recursive storage and selected size checks pass. The
focused native cohort at source `5df9808e` passes all 93 cases without failures
or skips. Consolidated current-stack and production gas-capacity validation
remain pending. This decision does not authorize a live governance, deployment
or funds operation.

## Mixed payment units

[SSA-REVEAL rule 2](../stream-sales-and-auctions.md) names the coordinator's
`revealFeePerTokenWei`, but previously placed that fee inside
`PaymentIntent.maxAmount` for ERC-20 sales.
[RSR-PAYMENT-INTENT](../revenue-splits-and-royalties.md) defines that maximum
and the exact allowance pull in units of the signed ERC-20 asset.
[EC-REVEAL](../stream-entropy-coordinator.md) funds the collection escrow with
native wei through payable `fundRevealFeeEscrow`. No accepted conversion,
exchange rate, token-denominated coordinator escrow, or pricing oracle joins
those two units. Adding them would change both the buyer's authorization and
the funding denomination.

## Separate native allowance

An ERC-20 immediate-sale transaction carries two independent amounts:

- The signed sale amount, `PaymentIntent.maxAmount`, and EIP-2612/Permit2
  authorization remain in units of the selected ERC-20 asset. The original
  payer, nonce, deadline, sale reference, policy hash, allowance semantics,
  exact token deltas, and official token-revenue accounting remain unchanged.
- The authenticated transaction executor supplies `msg.value` as its maximum
  native reveal-fee allowance. It may be a different account from the ERC-20
  payer. Existing entrypoint selectors and signing domains/types remain
  unchanged; the implementation widens the relevant entrypoints and
  authenticated sale callback to payable.

The sale adapter captures the actual selected coordinator's declared policy
in the transaction before settlement or mint effects. It rejects an allowance
below the captured live wei fee, forwards exactly that fee to the coordinator
escrow in the mint transaction, and credits unused wei to the authenticated
executor. Only that credited account may direct its pull refund. ERC-20 payer
status, possession of a token allowance, or an ERC-20 PaymentIntent does not
confer authority over another executor's native refund.

A Safe CALL authorizes its attached native value. A relayed ERC-20
PaymentIntent authorizes only the token pull; the relayer/executor supplies
and owns the separate native allowance. No signature-field extension,
conversion, rate oracle, token surcharge, or wei/token addition is introduced.
The token verifier forwards native allowance only through the existing
candidate-bound sale callback and retains no native fee custody afterward.
The sale adapter owns any excess native refund liability.

A zero declared fee remains valid for the operator-funded provider posture.
Any supplied native allowance is then entirely refundable to its funder.
Changing the fee between an offchain quote and inclusion charges the captured
live value within the supplied allowance; it does not change the token price
or consume more token allowance. The remaining reveal rules still apply:
funding is excluded from official revenue, the `AT_MINT` request follows the
actual Manager return, and bounded provider failure cannot undo a successful
purchase. A settlement or mint failure rolls back both payment legs, consumed
intent/permit state, and any newly created native credit.

This decision resolves denomination and refund ownership. It does not claim
that every deferred ERC-20 sale kind has implemented its existing rule-7 fee
escrow/reconciliation timing, and it does not alter that timing.

## Required implementation evidence

The focused implementation tests must cover zero fee, fee drift, exact token
and native deltas, separate Safe payer and executor, unchanged PaymentIntent
and Permit2 limits, underfunded allowance, byte-identical Safe retry after a
repaired failure, provider failure isolation, callback reentry, and funder-only
pull refunds. The original public selector and EIP-712 field/domain comparison
must remain explicit. Passing those checks and consolidated runtime validation
are future evidence, not supplied by this prose decision.
