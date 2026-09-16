# Current sale conservation campaign

`test/current/StreamCurrentStackInvariant.t.sol:StreamCurrentStackInvariantTest`
uses the existing sealed current-stack fixture and targets only
`StreamCurrentStackHandler.step`. Core, Manager, Ledger, Artist, governance,
split wallet, escrow and entropy coordinator are actual contracts. The payment
token and external entropy service are explicit test substitutes.

The supported products in this campaign are `StreamFixedPriceSaleAdapter`,
`StreamERC20FixedPriceSaleAdapter` and `StreamEnglishAuctionHouse`. Inputs drive
an independent record of successful purchases, bids, credits, withdrawals,
releases and NFT owners. Expected balances do not come from production balance
or liability getters.

## Sequence and required activity

Every campaign begins with fifteen ordered actions, then chooses among those
same actions from fuzzed inputs. Existing campaign budgets are documented in
[tooling](../tooling.md#reproducible-fuzz-and-invariant-campaigns).

| Opening step | Action |
| --- | --- |
| 0–1 | Native purchase, then separately authorized ERC-20 purchase |
| 2–6 | Auction creation, two different bidders, outbid-credit withdrawal and settlement |
| 7–8 | Native/ERC-20 beneficiary releases, then NFT ownership transfer |
| 9–10 | Reject already-used native and ERC-20 purchase authorizations |
| 11 | Reject an ERC-20 purchase at the actual ERC-721 receiver callback |
| 12 | Reject a funded native purchase at that callback, enable the receiver and retry identical signed sale bytes/value/payer; the receiving contract then transfers its own NFT |
| 13 | A different caller cancels only its own nonce namespace; the Artist's already-signed purchase still succeeds |
| 14 | The actual Artist cancels a fresh signed purchase; later execution rejects without consuming a Ledger mint authorization |

After each sequence, activity assertions require every operation class to have
run. Expected negative paths check their exact rejection and state preservation;
unexpected positive-path failures propagate with `fail_on_revert=true`.

## Independent conservation checks

- Literal launch CONSTANT/PHASE counter keys identify the three Ledger supply
  counters. Their values equal successful purchases or auction creations, and
  their sum equals Core lifetime supply and Manager operation nonce.
- Every actual token retains its original collection/serial, modeled owner and
  entropy registration. The next unallocated token has no registration;
  nonterminal registrations equal minted tokens and pending requests remain zero.
- Every accepted sale/auction authorization remains consumed in Ledger.
  Artist-cancelled native nonces stay cancelled in the adapter without a
  fictitious Ledger mint receipt.
- Each native payer retains initial funding plus withdrawn refunds minus all
  successful sale payments and submitted bids. An outbid credit is not counted
  as returned cash before withdrawal. ERC-20 balances follow separate payer
  debits; no aggregate-only check can hide a charge to the wrong payer.
- Auction active escrow, refund credits, withdrawn refunds and settled revenue
  conserve all bid deposits. Split balances and actual beneficiary receipts
  conserve native and ERC-20 revenue, including integer-rounding dust.
- Failed mints and replays preserve counter values, authorizations, payment
  intents, proceeds, payer/wallet balances, escrow liabilities, Core allocation,
  Manager nonce and entropy registration/counts.

Two model-sensitivity tests move one unit between payers while preserving their
aggregate balance, then require the model to reject the wrong individual debit.

## Evidence boundary

The expanded driver and fifteen-action smoke case are source-authored and
ABI/type checked. Native execution is pending the coordinator's frozen graph;
this is not a passing campaign, size result or transaction-capacity measurement.
The external entropy service is not requested or fulfilled by this campaign.
Safe batch behavior has its own [actual Safe cases](../integrations/current-safe-batches.md).
