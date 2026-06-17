# Withdrawals And Credits

This document is the integration flow spec for 6529Stream pull-payment
credits and withdrawal UX. It is for React, mobile, Electron, indexer,
operator UI, and backend integration teams that need to show withdrawable
balances, submit withdrawal transactions, reconcile owed accounting, and avoid
confusing user credits with protocol surplus.

The repository remains a pre-audit local baseline. It is not production-ready
and this document is not a security claim. Local evidence does not replace
fork/testnet/live evidence required for public beta or production release.

Use this with the fixed-price flow in
[`docs/integrations/contract-flows.md`](contract-flows.md), the auction flow in
[`docs/integrations/auction-flows.md`](auction-flows.md), the curator rewards
flow in [`docs/integrations/curator-rewards.md`](curator-rewards.md), the
event/indexer guide in
[`docs/integrations/events-and-indexing.md`](events-and-indexing.md), the
mobile guide in [`docs/integrations/mobile-walletconnect.md`](mobile-walletconnect.md),
and the Electron guide in
[`docs/integrations/electron-security-wallets.md`](electron-security-wallets.md).

## Maturity And Scope

This page documents current checked local contract behavior for pull-payment
credits, withdrawals, and surplus accounting.

It covers:

- fixed-price poster and protocol credits in `StreamDrops`;
- fixed-price curator reserve accounting in `StreamDrops`;
- auction bidder refund credits in `StreamAuctions`;
- auction poster, protocol, and curator proceeds credits in `StreamAuctions`;
- curator reward credits in `StreamCuratorsPool`;
- withdrawal-to-recipient UX;
- failed withdrawal, zero-recipient, no-credit, and wallet rejection states;
- read-after-event indexer reconstruction;
- pause and emergency-surplus boundaries;
- mobile and Electron wallet-security constraints.

It does not provide production payout recipient approvals, production
curator-distribution policy, production monitoring evidence, reviewed testnet
withdrawal evidence, or final mainnet readiness.

## Credit Families

6529Stream uses pull payments for user-facing and operator-facing ETH flows.
A successful mint, bid, settlement, or curator reward claim creates credit;
the credit owner later withdraws to themselves or to another payable
recipient.

| Family | Contract | Credit views | Withdrawal |
| --- | --- | --- | --- |
| Fixed-price poster | `StreamDrops` | `fixedPricePosterCredits(account)` | `withdrawFixedPriceCredit()` or `withdrawFixedPriceCreditTo(recipient)` |
| Fixed-price protocol | `StreamDrops` | `fixedPriceProtocolCredits(account)` | `withdrawFixedPriceCredit()` or `withdrawFixedPriceCreditTo(recipient)` |
| Fixed-price curator reserve | `StreamDrops` | `fixedPriceCuratorReserveCredits(curatorsPoolAddress)` | No direct user withdrawal in `StreamDrops`; show as reserved/owed accounting |
| Auction bidder refund | `StreamAuctions` | `auctionBidderCredits(account)` | `withdrawBidderCredit()` or `withdrawBidderCreditTo(recipient)` |
| Auction poster proceeds | `StreamAuctions` | `auctionPosterCredits(account)` | `withdrawAuctionProceedsCredit()` or `withdrawAuctionProceedsCreditTo(recipient)` |
| Auction protocol proceeds | `StreamAuctions` | `auctionProtocolCredits(account)` | `withdrawAuctionProceedsCredit()` or `withdrawAuctionProceedsCreditTo(recipient)` |
| Auction curator proceeds | `StreamAuctions` | `auctionCuratorCredits(account)` | `withdrawAuctionProceedsCredit()` or `withdrawAuctionProceedsCreditTo(recipient)` |
| Curator rewards | `StreamCuratorsPool` | `curatorCredits(account)` | `withdrawCuratorCredit()` or `withdrawCuratorCreditTo(recipient)` |

Do not collapse these into a single generic wallet balance. Indexer entities
should preserve contract, credit family, owner, recipient, token/drop
reference where available, and source event.

## Source Of Truth

Use tracked generated artifacts and checked docs, not hand-maintained copies.

| Need | Source of truth | Integration note |
| --- | --- | --- |
| Integration entrypoint | [`docs/integrations/README.md`](README.md) | Starts frontend, mobile, Electron, indexer, operator UI, and signing-service discovery |
| Fixed-price flow | [`docs/integrations/contract-flows.md`](contract-flows.md) | Fixed-price credit creation, withdrawal, and failure-state details |
| Auction flow | [`docs/integrations/auction-flows.md`](auction-flows.md) | Auction bidder/proceeds credit creation, settlement, and withdrawal details |
| Curator rewards flow | [`docs/integrations/curator-rewards.md`](curator-rewards.md) | Curator reward claim, delegated claim, credit, and withdrawal details |
| Event/indexer model | [`docs/integrations/events-and-indexing.md`](events-and-indexing.md) | Event subscriptions, read-after-event calls, reorg handling, and reconstruction guidance |
| Mobile wallet guide | [`docs/integrations/mobile-walletconnect.md`](mobile-walletconnect.md) | Mobile foreground wallet action and stale-credit constraints |
| Electron security guide | [`docs/integrations/electron-security-wallets.md`](electron-security-wallets.md) | Renderer/process isolation and no-secret wallet boundaries |
| Drops contract | [`smart-contracts/StreamDrops.sol`](../../smart-contracts/StreamDrops.sol) | Fixed-price credits, owed totals, surplus, and withdrawal functions |
| Auction contract | [`smart-contracts/AuctionContract.sol`](../../smart-contracts/AuctionContract.sol) | Bidder credits, proceeds credits, owed totals, surplus, and withdrawal functions |
| Curator pool contract | [`smart-contracts/StreamCuratorsPool.sol`](../../smart-contracts/StreamCuratorsPool.sol) | Curator reward credits, owed totals, surplus, and withdrawal functions |
| Minter bridge | [`smart-contracts/StreamMinter.sol`](../../smart-contracts/StreamMinter.sol) | Emergency-surplus boundary for minter-held ETH |
| Randomizer adapter | [`smart-contracts/RandomizerRNG.sol`](../../smart-contracts/RandomizerRNG.sol) | Randomizer reserved-balance boundary |
| Pause domains | [`smart-contracts/StreamPauseDomains.sol`](../../smart-contracts/StreamPauseDomains.sol) | Pause and emergency domain naming |
| Fixed-price payment tests | [`test/StreamFixedPricePayments.t.sol`](../../test/StreamFixedPricePayments.t.sol) | Fixed-price credit split, failed withdrawal, and surplus behavior |
| Auction payment tests | [`test/StreamAuctionPayments.t.sol`](../../test/StreamAuctionPayments.t.sol) | Outbid credit, proceeds credit, failed withdrawal, and surplus behavior |
| Curator pool tests | [`test/StreamCuratorsPool.t.sol`](../../test/StreamCuratorsPool.t.sol) | Curator credit, delegated claim, failed withdrawal, and surplus behavior |
| Payment invariant tests | [`test/StreamPaymentsInvariant.t.sol`](../../test/StreamPaymentsInvariant.t.sol) | Cross-contract owed/surplus invariant baseline |

## Credit Discovery Reads

Before showing a withdrawal button, read all relevant category balances for the
connected account and the selected address book.

For `StreamDrops`:

- `fixedPricePosterCredits(account)`;
- `fixedPriceProtocolCredits(account)`;
- `fixedPriceCuratorReserveCredits(curatorsPoolAddress)`;
- `totalFixedPricePosterOwed()`;
- `totalFixedPriceProtocolOwed()`;
- `totalFixedPriceCuratorReserveOwed()`;
- `totalFixedPriceOwed()`;
- `totalPosterOwed()`;
- `totalProtocolOwed()`;
- `totalCuratorReserved()`;
- `totalReserved()`;
- `totalOwed()`;
- `surplus()`;
- `emergencyWithdrawable()`.

For `StreamAuctions`:

- `auctionBidderCredits(account)`;
- `auctionPosterCredits(account)`;
- `auctionProtocolCredits(account)`;
- `auctionCuratorCredits(account)`;
- `totalBidderOwed()`;
- `totalPosterOwed()`;
- `totalProtocolOwed()`;
- `totalCuratorOwed()`;
- `totalProceedsOwed()`;
- `totalAuctionBidEscrow()`;
- `totalReserved()`;
- `totalOwed()`;
- `surplus()`;
- `emergencyWithdrawable()`.

For `StreamCuratorsPool`:

- `curatorCredits(account)`;
- `totalCuratorOwed()`;
- `totalReserved()`;
- `totalOwed()`;
- `surplus()`;
- `emergencyWithdrawable()`.

For `StreamMinter` and `RandomizerRNG`, user withdrawal UX should not expose
ordinary user-credit buttons. Operator UI may show `totalOwed()`, `surplus()`,
and `emergencyWithdrawable()` as emergency-surplus diagnostics.

## Withdrawal Transactions

Withdrawal functions always use `msg.sender` as the credit owner. The
`recipient` can differ from the owner only in the `...To(recipient)` variants.
In other words, the recipient can differ from the owner, but the credit owner
is always the transaction sender.

| Credit | Function | Owner | Recipient |
| --- | --- | --- | --- |
| Fixed-price poster/protocol | `StreamDrops.withdrawFixedPriceCredit()` | `msg.sender` | `msg.sender` |
| Fixed-price poster/protocol | `StreamDrops.withdrawFixedPriceCreditTo(recipient)` | `msg.sender` | `recipient` |
| Auction bidder refund | `StreamAuctions.withdrawBidderCredit()` | `msg.sender` | `msg.sender` |
| Auction bidder refund | `StreamAuctions.withdrawBidderCreditTo(recipient)` | `msg.sender` | `recipient` |
| Auction poster/protocol/curator proceeds | `StreamAuctions.withdrawAuctionProceedsCredit()` | `msg.sender` | `msg.sender` |
| Auction poster/protocol/curator proceeds | `StreamAuctions.withdrawAuctionProceedsCreditTo(recipient)` | `msg.sender` | `recipient` |
| Curator reward | `StreamCuratorsPool.withdrawCuratorCredit()` | `msg.sender` | `msg.sender` |
| Curator reward | `StreamCuratorsPool.withdrawCuratorCreditTo(recipient)` | `msg.sender` | `recipient` |

Validate before submitting:

- the connected account owns non-zero credit in the target family;
- `recipient` is non-zero for `...To(recipient)`;
- the wallet is on the selected chain ID;
- the selected address book matches the connected chain;
- the app has refreshed the credit read after the latest relevant event;
- mobile and Electron clients are in a foreground wallet action with no private
  keys or RPC secrets in renderer-local state.

## Failure States

Treat withdrawal failures as retryable unless a fresh read shows the credit is
gone.

| Failure | UX handling |
| --- | --- |
| Wallet rejection | Keep local credit visible; let user retry |
| Zero recipient | Disable submit and show input validation |
| No credit | Hide or disable submit after a fresh read |
| ETH transfer failed | Credit should remain retryable; re-read before showing final state |
| Network/reorg uncertainty | Wait for configured confirmations and re-read |
| Wrong chain/address book | Block submit until chain/address book match |
| Stale indexer state | Prefer direct RPC read before submit |

The Solidity paths clear credit and decrement owed totals before the ETH call,
then revert if the call fails. Because a revert rolls back state, failed
withdrawals preserve credit and owed totals. The UI should not mark withdrawal
complete until the receipt is confirmed and the relevant credit read is zero.

## Event And Indexer Reconstruction

Indexers should combine events with read-after-event calls. Events alone are
not enough for surplus, forced ETH, or reorg-safe finality.

Credit creation events:

- `FixedPriceCreditCreated(account, dropId, creditType, funds)`;
- `OutbidCreditCreated(account, tokenid, credit)`;
- `AuctionProceedsCreditCreated(account, tokenid, creditType, funds)`;
- `CuratorCreditCreated(account, collectionID, funds)`;
- `Reward(account, collectionID, amount)`.

Withdrawal events:

- `FixedPriceCreditWithdrawn(account, recipient, creditType, funds)`;
- `BidderCreditWithdrawn(account, recipient, funds)`;
- `ProceedsCreditWithdrawn(account, recipient, funds)`;
- `CuratorCreditWithdrawn(account, recipient, funds)`.

Emergency events:

- `EmergencyWithdrawal(admin, recipient, domain, funds, resultingSurplus)`;
- legacy `Withdraw(account, status, funds)`.

After each event, re-read the category credit, category owed total,
`totalOwed()`, `totalReserved()`, `surplus()`, and `emergencyWithdrawable()`
for that contract. Reorg handling should be idempotent: replayed logs must not
double-count credit creation or withdrawal.

## Owed, Reserved, And Surplus

Use the accounting views to explain why contract ETH balance is not the same as
user-withdrawable balance.

| Contract | Owed model | Reserved model | Surplus model |
| --- | --- | --- | --- |
| `StreamDrops` | poster + protocol + curator reserve fixed-price owed | curator reserve | balance above `totalOwed()` |
| `StreamAuctions` | bidder credits + active bid escrow + proceeds credits | active bid escrow | balance above `totalOwed()` |
| `StreamCuratorsPool` | curator credits | zero | balance above `totalOwed()` |
| `StreamMinter` | zero | zero | balance above `totalOwed()` |
| `RandomizerRNG` | randomizer request reserves | randomizer request reserves | currently zero emergency-withdrawable under the conservative adapter model |

Emergency withdrawal is surplus-only. Operator UI must never suggest that owed
poster, bidder, protocol, curator, curator-reserve, or randomizer-reserve funds
are emergency-withdrawable.

## Frontend State Machine

Recommended frontend states:

| State | Meaning |
| --- | --- |
| `loading-credits` | Reads are in flight |
| `no-credit` | Fresh category credit reads are zero |
| `credit-available` | At least one withdrawable category is non-zero |
| `recipient-editing` | User is choosing an alternate recipient |
| `simulation-failed` | `eth_call` or wallet simulation failed |
| `withdraw-submitted` | Transaction was submitted |
| `confirming` | Receipt observed; waiting configured confirmations |
| `withdrawn` | Confirmed receipt and fresh read shows credit zero |
| `failed-retryable` | Wallet rejection, network error, or reverted withdrawal with credit preserved |
| `stale-indexer` | Indexer and direct RPC reads disagree |

Keep mint, bid, settlement, claim, and withdrawal state independent. A paused
mint or bid path should not hide already owed withdrawal credit unless the
contract itself rejects the withdrawal path.

## Mobile And Electron Boundaries

Mobile and Electron surfaces should follow the same no-secret and foreground
wallet-action rules as the broader wallet guides.

- Do not store private keys, signing-service secrets, or RPC provider secrets
  in React state, local storage, Electron renderer state, or mobile webview
  storage.
- Re-read credit balances when the wallet reconnects, chain changes, app
  resumes from background, or the indexer catches up after a reorg.
- Treat stale credit state as informational only; use direct RPC reads before
  constructing withdrawal transactions.
- Do not auto-submit withdrawals after reconnect or deep-link return.
- In Electron, keep withdrawal transaction construction behind the same IPC
  allowlist and context-isolated wallet boundary as mint, bid, and settlement
  actions.

## Operator And Emergency Boundaries

Operator dashboards should show:

- category owed totals;
- contract ETH balance;
- total reserved funds;
- surplus;
- emergency-withdrawable balance;
- emergency recipient;
- last emergency withdrawal event;
- last user withdrawal event per credit family.

Emergency withdrawal actions should require explicit operator confirmation that
owed and reserved funds remain covered. If `emergencyWithdrawable() == 0`, the
action should be disabled.

## Validation Commands

Run:

```sh
python scripts/test_withdrawals_credits_flow.py
python scripts/check_withdrawals_credits_flow.py
python scripts/test_integrations_readme.py
python scripts/check_integrations_readme.py
python scripts/test_events_and_indexing.py
python scripts/check_events_and_indexing.py
python scripts/test_release_readiness.py
python scripts/check_release_readiness.py
python scripts/check_changelog.py
forge test --match-path test/StreamFixedPricePayments.t.sol
forge test --match-path test/StreamAuctionPayments.t.sol
forge test --match-path test/StreamCuratorsPool.t.sol
forge test --match-path test/StreamPaymentsInvariant.t.sol
python scripts/generate_release_manifest.py --check
python scripts/generate_bytecode_release_proof.py --check
python scripts/generate_release_checksums.py --check
```

## Maintenance

Update this guide and its checker whenever:

- a credit mapping, owed-total view, withdrawal function, event, or credit split
  changes;
- fixed-price, auction, curator, randomizer, minter, pause, emergency, mobile,
  Electron, or indexer docs change withdrawal assumptions;
- a new frontend package or SDK starts exporting withdrawal helpers;
- testnet/live evidence changes the readiness boundary.
