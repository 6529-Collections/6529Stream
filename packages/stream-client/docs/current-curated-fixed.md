# Current curated fixed-price sales

`current-curated-fixed.ts` prepares the FIXED carrier's PUBLIC and
COMMIT_REVEAL calls from the final 128-source compiler capture at joined source
commit `5605d019`. It uses the shared content types and Merkle helpers in
`current-curated-content.ts`. The module does not broadcast transactions.

## Immutable registration

`prepareCuratedFixedRegistration` derives the original sale ID with kind `0`,
the expected live sale nonce and the complete fixed configuration hash. The
hash covers chain, carrier and the nested sale, selection mode, disclosure
flags and windows. It does not contain the sale ID.

PUBLIC requires STRICT_MATCH primary policy mode `0`, no differentiated
content, an explicit public-selection disclosure and five zero window fields.
COMMIT_REVEAL requires ALLOW_CURRENT mode `1`, no public disclosure,
`commitOpen == startsAt`, `revealClose == endsAt`, half-open non-overlapping
windows and a finite escape at or after reveal close. Both registrations must
be simulated at a pinned block whose timestamp is strictly before `startsAt`.

Registration inspection checks the chain, owner, next nonce, `saleIdFor`, the
carrier's configuration hash and configured dependency addresses. Simulation
checks the returned original sale ID. After mining,
`inspectRegisteredCuratedFixedSale` compares the complete fixed configuration,
common sale record, kind, nonce, configuration hash and active status.

## PUBLIC purchase

`prepareCuratedPublicPurchase` verifies the selected leaf against the immutable
manifest root and preserves the raw token data, commitment, final recipient and
purchase nonce. The exact CALL value is:

```text
positive fixed price + revealFeeAllowance
```

Inspection checks the stored sale, original purchase ID, next payer nonce,
current reveal quote and the half-open `startsAt <= timestamp < endsAt` window.
The payable simulation runs from the actual buyer at the same numeric block and
validates the returned content and settlement record. The original purchase ID
is the recorder replay identity; it is distinct from the returned prepared-mint
operation ID.

## COMMIT_REVEAL

`prepareCuratedSelectionCommit` derives the selected leaf and domained
commitment from buyer, sale, leaf and salt. Content ID zero, empty token data
and a zero salt are valid when the manifest and token-data hash say so. The
commit CALL attaches exactly the positive fixed price. It has no reveal-fee
allowance. Inspection uses the carrier's effective `selectionWindows` view and
the live payer purchase nonce; simulation verifies the returned purchase ID.

`prepareCuratedSelectionReveal` reconstructs the same commitment and purchase
ID from the full selection. Inspection requires a pending deposit with the
exact saved price and nonce, a strictly earlier committed block, a live
effective reveal window, and the current reveal quote. The reveal CALL attaches
only `revealFeeAllowance`; the price remains escrowed in the saved commitment.
Any fee excess becomes the buyer's separate excess credit.

The effective windows include bounded tolling from global, collection and sale
stops. The nominal schedule alone is not current admission evidence.

## Refunds and recovery calls

`prepareCuratedMaturityUnlock` encodes the provider-free local maturity,
cancellation or absolute-escape unlock. It does not call external admission
providers. `prepareCuratedReasonUnlock` reconstructs the selected commitment
and supports typed reasons `1` through `5`: ended phase, exhausted supply or
counter, policy beyond grace, stopped Artist attribution, or incident-revoked
module. The contract proves the requested fact.

Selection-deposit refunds and reveal-fee excess are separate liabilities:

- `readCuratedSelectionRefundCredit` and
  `prepareCuratedSelectionRefundClaim` use the selection credit;
- `readCuratedExcessRefundCredit` and `prepareCuratedExcessRefundClaim` use the
  ordinary excess credit;
- delegated variants always pay the original buyer, regardless of the
  delegate caller.

Claims and maturity unlock do not reapply current sale, Artist, gate, entropy or
phase admission. `prepareCuratedFixedCancel` and `prepareCuratedContestSync`
encode the original owner cancellation and permissionless contest sync calls;
the contract enforces their authority and state rules.

## Safe calls

Pass a prepared packet's `call` to `toSafeCall`, using the packet's required
`caller` as the executing Safe. Registration, commitment and reveal are separate
transactions; a review plan does not advance their state or bypass the
strictly-later-block reveal rule. Build ordered plans from the exact carrier ABI
with `createSafeCallPlan`, then simulate each step only after its prerequisites
exist. Follow the [Safe CALL guide](safe-call-plans.md) for receipt checks and
failure/retry handling. A commitment's private salt belongs in the retained
reveal packet, not in a published commitment review artifact.

## Evidence boundary

All read workflows reconstruct prepared input before RPC use and require a
concrete numeric block. A numeric pin has no block-hash reorg check. Read-only
inspection cannot establish consent, signatures, runtime code identity, gate
state, proof authority or current Manager admission. Exact payable simulation
is the validation boundary for those execution checks, but it does not prove
Safe authority, transaction inclusion or future-state acceptance.

The fixture proves ABI and source encoding against the final carrier capture.
Actual-current native runtime and full-stack acceptance remain pending.
