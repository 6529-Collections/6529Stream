# ADR 0003: Payment Accounting

## Status

Accepted.

Implementation status: P0-AUCT-002 converts auction outbid refunds to bidder
credits and removes the bid-path push refund. Remaining ADR work includes
fixed-price payment credits, with-bid settlement credits, curator reward
credits, protocol-wide ledger views, failed-withdrawal coverage for every
payment category, and emergency surplus boundaries.

## Metadata

| Field | Value |
| --- | --- |
| Date | 2026-06-10 |
| Issue | [P0-PAY-ADR](https://github.com/6529-Collections/6529Stream/issues/24) |
| Blocks | [P0-PAY-001](https://github.com/6529-Collections/6529Stream/issues/25), [P0-PAY-002](https://github.com/6529-Collections/6529Stream/issues/26), [P0-PAY-003](https://github.com/6529-Collections/6529Stream/issues/27), [P0-PAY-004](https://github.com/6529-Collections/6529Stream/issues/28), [P0-PAY-005](https://github.com/6529-Collections/6529Stream/issues/29), [P0-PAY-006](https://github.com/6529-Collections/6529Stream/issues/30), [P0-PAY-007](https://github.com/6529-Collections/6529Stream/issues/31), [P0-PAY-008](https://github.com/6529-Collections/6529Stream/issues/8) |
| Related issues | [P0-PAY-008](https://github.com/6529-Collections/6529Stream/issues/8), [P0-AUCT-002](https://github.com/6529-Collections/6529Stream/issues/12), [P0-AUCT-001](https://github.com/6529-Collections/6529Stream/issues/22) |
| Related ADRs | [ADR 0001](0001-drop-authorization.md), [ADR 0002](0002-auction-custody.md) |
| Affected contracts | `smart-contracts/StreamDrops.sol`, `smart-contracts/AuctionContract.sol`, `smart-contracts/StreamCuratorsPool.sol`, `smart-contracts/StreamMinter.sol`, `smart-contracts/RandomizerRNG.sol` |
| Work type | `DESIGN` |

## Problem

6529Stream needs a protocol-wide accounting model before any P0 payment-moving
rewrite. The current implementation mixes protocol state changes with
synchronous ETH transfers, which creates denial-of-service, reentrancy, and
emergency-withdrawal risks.

Before public beta, the protocol needs to decide:

- which balances are owed to posters, bidders, curators, and protocol
  recipients
- how owed balances are separated from protocol surplus
- how outbid refunds and final auction proceeds become durable credits
- how curator reward claims become durable credits
- how withdrawals behave when recipients revert or attempt reentrancy
- how direct and forced ETH affect surplus and invariants
- how emergency withdrawals are bounded so owed funds cannot be swept

## Current Behavior

Current source references:

- `smart-contracts/StreamDrops.sol#L72-L110`: `mintDrop` mints fixed-price or
  auction drops and stores drop metadata.
- `smart-contracts/StreamDrops.sol#L90-L92`: fixed-price minting pushes ETH to
  the poster, payout address, and curators pool with low-level `call`.
- `smart-contracts/AuctionContract.sol#L88-L139`: auction bidding credits the
  previous highest bidder, tracks active highest-bid escrow, and exposes bidder
  credit withdrawals.
- `smart-contracts/AuctionContract.sol#L142-L170`: auction settlement marks the
  token claimed, decrements active highest-bid escrow for with-bid settlement,
  pushes final proceeds to poster, payout, and curators, then transfers the NFT.
- `smart-contracts/StreamCuratorsPool.sol#L55-L73`: curator reward claims mark a
  Merkle leaf claimed and push ETH to the reward address.
- `smart-contracts/AuctionContract.sol#L231-L254`: auction emergency withdrawal
  is bounded by auction-local bidder credits and active bid escrow.
- `smart-contracts/StreamMinter.sol#L124-L130`,
  `smart-contracts/StreamCuratorsPool.sol#L84-L90`, and
  `smart-contracts/RandomizerRNG.sol#L78-L84`: emergency withdrawals send the
  full contract balance to the admin without an owed-balance or reserved-balance
  boundary.
- `ops/SLITHER_BASELINE.md`: the auction bid-path `reentrancy-eth` row and
  auction emergency `arbitrary-send-eth` row are fixed by P0-AUCT-002; remaining
  high-impact emergency-withdrawal rows track the cross-contract payment
  surfaces.

Current characterization tests intentionally pin some unsafe behavior as
migration tripwires, but they are not target-state payment tests:

- `test/StreamDropsCharacterization.t.sol`
- `test/StreamDropsIntegrationCharacterization.t.sol`

## Decision

6529Stream will use pull-payment accounting for public-beta payment flows.

The public-beta target design is:

1. Minting, bidding, settlement, curator claiming, and emergency controls must
   not push user-owed ETH as part of their main state transition.
2. ETH owed to posters, bidders, curators, curator reserves, and protocol
   recipients must be represented as withdrawable credits.
3. Owed balances must be tracked separately from protocol surplus.
4. Every value-holding contract must expose enough views to prove its owed,
   reserved, surplus, and emergency-withdrawable balances.
5. Withdrawals are the only user-facing path that transfers owed ETH out of the
   ledger.
6. Failed withdrawals must not erase credits.
7. Emergency withdrawals may withdraw only surplus. They must not withdraw
   poster credits, bidder credits, curator credits, curator reserves, protocol
   credits, active bid escrow, randomness fee reserves, or any other
   contract-defined reserved balance.
8. Direct ETH and forced ETH must not create user credits automatically and must
   not corrupt owed-balance accounting.
9. State-changing payment events must include stable IDs and indexed fields so
   indexers can reconstruct credits, withdrawals, and surplus movement.
10. Payment-accounting implementation PRs must include targeted regression
    tests and invariants before Gate C can close.

## Ledger Model

The implementation may choose exact Solidity names, but it should implement a
shared ledger module, base contract, or tightly consistent local ledgers with
the same external semantics.

The preferred P0 implementation is a reusable internal payment ledger used by
the payment-moving contracts. A separate dedicated ledger contract is allowed
only if the implementation proves that custody, ownership, emergency controls,
and upgrade/redeployment risks are not increased.

Required credit and reserve categories:

| Category | Meaning | Example source |
| --- | --- | --- |
| `Poster` | Sale or auction proceeds owed to a poster. | Fixed-price mint split, with-bid auction settlement |
| `Bidder` | Refunds owed to bidders. | Previous highest bidder after an outbid, cancelled pre-bid auction refund if applicable |
| `Curator` | Rewards owed to individual curator reward addresses. | Valid Merkle reward claim |
| `CuratorReserve` | Funds reserved for future curator reward claims before an individual reward address is credited. This may be accountless aggregate storage or keyed to the curators pool identity, but it is not withdrawable except through the curator claim process. | Curators-pool share of mint or auction proceeds |
| `Protocol` | Amounts owed to the configured payout, treasury, or protocol recipient. | Payout share of mint or auction proceeds |
| `AuctionBidEscrow` | Active highest-bid funds held before outbid, cancellation, or settlement. This is reserved balance, not a withdrawable bidder credit. | Highest bid while an auction is active or ended but unsettled |
| `RandomnessReserve` | Funds reserved for randomness provider requests or callbacks. This is contract-specific reserved balance, not protocol surplus. | `RandomizerRNG` balance needed for arRNG-style requests |

The implementation may encode categories as an enum, separate mappings, or
separate storage structs, but it must preserve these views or equivalents:

```solidity
function creditOf(uint8 category, address account) external view returns (uint256);
function totalPosterOwed() external view returns (uint256);
function totalBidderOwed() external view returns (uint256);
function totalCuratorOwed() external view returns (uint256);
function totalCuratorReserved() external view returns (uint256);
function totalProtocolOwed() external view returns (uint256);
function totalAuctionBidEscrow() external view returns (uint256);
function totalRandomnessReserved() external view returns (uint256);
function totalOwed() external view returns (uint256);
function totalReserved() external view returns (uint256);
function surplus() external view returns (uint256);
function emergencyWithdrawable() external view returns (uint256);
```

`totalOwed` and `totalReserved` must include every withdrawable or reserved
amount that must not be swept by emergency withdrawal. If a contract needs
non-payment reserves, those reserves must be included in `totalReserved` and
excluded from `emergencyWithdrawable`.

## Accounting Rules

### Fixed-Price Minting

Fixed-price minting must record credits instead of pushing ETH.

The received payment must equal the validated fixed-price amount before credits
are recorded.

For the current 50 / 25 / 25 economics:

- poster credit is `msg.value / 2`
- curator reserve credit is `msg.value / 4`
- protocol credit is `msg.value - posterCredit - curatorReserveCredit`

The protocol share receives the remainder so the split accounts for every wei.
Implementation PRs may change the economics only if a later ADR or roadmap
issue accepts the change and tests the new rounding policy.

Fixed-price execution must remain consistent with ADR 0001:

- payable fixed-price execution requires the signed `payer` to match the
  execution policy from ADR 0001
- free fixed-price execution must not create positive payment credits
- zero-address credit recipients are rejected unless a later ADR defines a burn
  or donation policy

### Auction Bidding

Auction bidding must be compatible with ADR 0002's escrow custody model.

Required behavior:

- A valid bid records the bidder and bid amount without external refund calls.
- The current highest bid is active auction escrow, not a withdrawable credit
  for the current highest bidder.
- When a new highest bid replaces a previous highest bid, the previous bidder
  becomes a `Bidder` creditor for the previous bid amount and active auction
  escrow moves to the new highest bid.
- A reverting previous bidder cannot block the new bid.
- Bid state and credit state must be updated before any external interaction
  that can observe the transaction.
- Bidder credits must remain withdrawable even if the auction is later settled,
  cancelled, paused, or emergency-handled.

### Auction Settlement

With-bid settlement must create credits instead of pushing final proceeds.

For the current 50 / 25 / 25 economics:

- poster credit is `highestBid / 2`
- curator reserve credit is `highestBid / 4`
- protocol credit is `highestBid - posterCredit - curatorReserveCredit`

No-bid settlement must not create final payment credits unless the
implementation records an explicit fee or refund rule in a later ADR.

Settlement must be idempotent. Repeated settlement attempts must not duplicate
credits, duplicate NFT transfers, or emit misleading duplicate terminal events.

A failed NFT transfer must not mark the auction settled and must not create
final payment credits. If ADR 0002's no-bid NFT claim fallback is used, payment
credits remain separate from NFT claim state.

### Curator Reward Claims

Curator reward claims must separate Merkle authorization from ETH transfer.

Required behavior:

- Validate the Merkle proof and claim policy.
- Mark the claim consumed before any withdrawal transfer is possible.
- Credit the reward address in the `Curator` category.
- Decrease `CuratorReserve` by the credited amount if the reserve is held in the
  same contract.
- Reject duplicate claims.
- Reject ambiguous or malformed leaves according to the Merkle encoding policy
  in the roadmap.
- Let the reward address withdraw through the standard withdrawal path.

### Direct And Forced ETH

Direct ETH and forced ETH are surplus unless a protocol action records a credit
or reserve in the same transaction.

Required behavior:

- `receive` or `fallback` ETH must not credit `msg.sender` automatically.
- Forced ETH must not change credits, owed totals, or reserves.
- Direct or forced ETH may increase `surplus`.
- Direct or forced ETH must not mutate credits, reserves, or owed totals; if
  the contract balance rises above `totalOwed`, the excess is surplus.
- Tests must include a force-send helper contract so the invariant suite covers
  ETH received outside normal payable entrypoints.

### Randomness Reserves

`RandomizerRNG` and any future randomness adapter must distinguish provider
funding from surplus.

Required behavior:

- ETH reserved for randomness requests is included in `totalReserved`.
- Emergency withdrawal cannot withdraw randomness fee reserves.
- Direct ETH is not automatically randomness reserve unless a funded request or
  explicit reserve action records it as such.
- Spending reserve on a randomness provider must reduce
  `totalRandomnessReserved` or the equivalent reserved-balance view.
- If an adapter holds no provider reserve, it must document that its full
  balance is surplus and prove that with tests.

## Withdrawal Semantics

The implementation may expose category-specific withdrawals or a batched
withdrawal API, but it must preserve this behavior:

1. Only the credit owner can withdraw the owner's credits unless a later ADR
   defines delegated withdrawal.
2. Withdrawing to `msg.sender` is required.
3. Withdrawing to a non-zero recipient address is allowed only if the
   implementation records both the credit owner and recipient in events.
4. Withdrawals must use checks-effects-interactions and reentrancy protection.
5. Credits and aggregate owed totals are decremented before the external call
   and restored or reverted if the call fails.
6. A failed withdrawal must preserve the caller's credit.
7. A failed withdrawal may either revert atomically with a custom error or
   restore state and return a failure result. The chosen behavior must be
   documented and tested.
8. No withdrawal may reduce another account's credit or another category's
   aggregate total.
9. Withdrawal pause policy from this ADR is limited to payment safety:
   withdrawal pause, if implemented, may only pause transfers temporarily; it
   must not alter credits, totals, reserves, or emergency-withdrawable surplus.
   ADR 0004 owns who can pause and unpause.

Recommended custom errors:

```solidity
error PaymentZeroAddress();
error PaymentZeroAmount();
error PaymentNoCredit();
error PaymentTransferFailed(address account, address recipient, uint256 amount);
error PaymentInsufficientSurplus(uint256 requested, uint256 available);
```

## Emergency Withdrawal Policy

Emergency withdrawal is a surplus-withdrawal function, not an owed-funds sweep.

Required formula:

```solidity
totalOwed =
    totalPosterOwed +
    totalBidderOwed +
    totalCuratorOwed +
    totalCuratorReserved +
    totalProtocolOwed +
    totalAuctionBidEscrow +
    totalRandomnessReserved +
    otherContractSpecificReserved;

surplus =
    address(this).balance > totalOwed
        ? address(this).balance - totalOwed
        : 0;

emergencyWithdrawable = surplus;
```

Required behavior:

- `emergencyWithdraw(amount, recipient)` or equivalent must require
  `amount <= emergencyWithdrawable`.
- The recipient must be non-zero.
- The function must emit an event with the amount and remaining surplus.
- If `address(this).balance < totalOwed`, emergency withdrawal must revert or
  expose zero withdrawable surplus until the deficit is resolved.
- Blanket full-balance emergency withdrawal is rejected for all contracts that
  can hold owed or reserved funds.
- Contracts that claim to hold no owed or reserved funds must document why their
  full balance is surplus and must still expose tests proving that assumption.

## Invariants

Implementation PRs must make these invariants executable:

- `totalOwed == totalPosterOwed + totalBidderOwed + totalCuratorOwed +
  totalCuratorReserved + totalProtocolOwed + totalAuctionBidEscrow +
  totalRandomnessReserved + otherContractSpecificReserved`.
- Category totals equal the sum of tracked account credits. If Solidity cannot
  iterate accounts directly, invariant tests must maintain ghost accounting.
- `address(this).balance >= totalOwed` after every normal value-moving
  transaction.
- `emergencyWithdrawable == address(this).balance - totalOwed` when
  `address(this).balance >= totalOwed`.
- `emergencyWithdrawable == 0` when `address(this).balance < totalOwed`.
- Failed withdrawal does not reduce credit or category totals.
- Reentrant withdrawal cannot drain more than the caller's available credit.
- Outbid refunds are credits, not push payments.
- Auction settlement credits are created at most once.
- Direct and forced ETH do not change credits or owed totals.
- Emergency withdrawal cannot withdraw owed or reserved funds.

## Events

The P0 implementation must emit events for every external payment state
transition. Event names may change during implementation, but the event catalog
must include:

- credit recorded
- credit consumed by withdrawal
- withdrawal succeeded
- withdrawal failed, if the implementation uses a non-reverting failure path
- direct surplus received, if the contract accepts direct ETH
- emergency surplus withdrawal
- reserve increased
- reserve decreased

Events should include stable IDs and indexed query fields where useful:

- indexed `account`
- indexed `recipient`
- indexed `category`
- indexed `dropId`, `auctionId`, `tokenId`, or `collectionId` when applicable
- `amount`
- `newAccountCredit`
- `newCategoryTotal`
- `totalOwed`
- `surplus`
- source operation or reason

Forced ETH cannot reliably emit an event at receipt time. The implementation may
expose a reconciliation event if an explicit function observes and records the
new surplus, but credits and owed totals must remain correct without that event.

## Alternatives Considered

### Keep Push Payments

Rejected. Push payments let reverting recipients block minting, bidding,
settlement, or claims, and they expand reentrancy risk in already complex state
transitions.

### Push Refunds But Pull Final Proceeds

Rejected. The auction bid path is one of the highest-risk value flows. Outbid
refunds must become bidder credits so malicious previous bidders cannot block
valid bids.

### Ad Hoc Per-Feature Ledgers

Rejected as the default. Per-feature ledgers are easy to make inconsistent and
hard to audit. P0 should use a shared ledger module or identical category and
view semantics wherever separate storage is unavoidable.

### Admin Full-Balance Emergency Sweep

Rejected. A full-balance sweep can confiscate owed bidder, poster, curator, or
protocol credits and makes the accounting model unverifiable.

### Auto-Credit Direct ETH Senders

Rejected. Direct ETH and forced ETH cannot safely prove business intent. Only
protocol actions that validate the relevant drop, auction, or claim state may
record credits.

### Ignore Forced ETH In Tests

Rejected. Forced ETH can change `address(this).balance` without calling a
payable function, so the surplus and emergency-withdrawal model must explicitly
handle it.

## Security Impact

This ADR addresses:

- push-payment denial of service
- outbid refund reentrancy and recipient griefing
- auction settlement payout duplication
- curator claim transfer failure behavior
- emergency withdrawals that can drain owed balances
- direct and forced ETH accounting ambiguity
- missing total-owed and surplus views

This ADR does not by itself fix drop authorization, auction custody, admin role
selection, randomness callbacks, metadata finalization, or Merkle leaf
encoding. It defines payment rules that those implementation PRs must satisfy.

## Migration Impact

This is a breaking payment behavior change before public beta.

Expected migration consequences:

- recipients must withdraw instead of receiving ETH synchronously
- frontends and indexers must read credit, owed, and withdrawal events
- emergency withdrawal scripts must request surplus amounts instead of sweeping
  full balances
- existing characterization tests that assert push-payment behavior must be
  replaced or converted into target-state tests when implementation lands
- deployment runbooks must include surplus and owed-balance checks before any
  emergency action

No production migration is promised while the repository remains pre-audit and
not production-ready.

## Test Plan

P0 implementation must add tests for:

- fixed-price mint records poster, curator reserve, and protocol credits
- fixed-price mint odd-wei rounding credits exactly `msg.value`
- zero-address credit recipient rejection
- free fixed-price mint creates no positive payment credits
- auction outbid records previous bidder credit without calling the previous
  bidder
- active highest bid remains reserved auction escrow until outbid, cancellation,
  refund, or settlement
- reverting previous bidder cannot block a new highest bid
- with-bid settlement records poster, curator reserve, and protocol credits
- repeated settlement cannot duplicate credits
- failed NFT transfer does not create final payment credits
- curator claim validates Merkle proof and records curator credit
- duplicate curator claim fails
- curator reserve decreases when individual curator credit is recorded
- successful withdrawal decreases account credit and category totals exactly
  once
- failed withdrawal preserves credit and category totals
- reentrant withdrawal cannot withdraw more than available credit
- withdrawal-to-recipient records account and recipient
- direct ETH increases surplus without changing credits
- forced ETH increases surplus without changing credits
- randomness provider reserves cannot be withdrawn as surplus
- emergency withdrawal succeeds only up to surplus
- emergency withdrawal cannot withdraw owed or reserved funds
- deficit state, if reachable only by test harness, exposes zero
  emergency-withdrawable surplus
- events are emitted for credit creation, withdrawal, reserve movement, and
  emergency surplus withdrawal

Intended test files:

- `test/StreamPayments.t.sol`
- `test/StreamDropsPayments.t.sol`
- `test/StreamPaymentsInvariant.t.sol`
- `test/StreamAuctionPayments.t.sol`
- `test/StreamCuratorsPool.t.sol`
- `test/StreamRandomizerPayments.t.sol`
- `test/StreamEmergencyWithdraw.t.sol`

Existing characterization tests must remain useful as pre-refactor evidence but
must not be treated as target-state tests after the implementation lands.

## Rollout Plan

1. Merge this ADR and link it from the roadmap.
2. Implement shared payment ledger storage, views, events, custom errors, and
   withdrawal behavior.
3. Convert fixed-price mint payouts to credits.
4. Convert auction outbid refunds and final settlement proceeds to credits.
5. Convert curator reward claims to credits.
6. Bound emergency withdrawals by surplus in each affected contract.
7. Add payment regression tests, invariant tests, and forced-ETH tests.
8. Update user, integrator, deployment, and security docs.
9. Include payment credit creation, withdrawal, failed withdrawal, and emergency
   surplus checks in deployment rehearsal.

## Non-Goals

- Defining the final admin actor for pause or emergency controls. That belongs
  to ADR 0004.
- Defining auction custody or NFT settlement mechanics. Those belong to ADR
  0002.
- Defining relayer reimbursement. Open relaying remains out of scope for P0.
- Changing current sale or auction fee percentages.
- Adding ERC-20 payments.
- Defining production migration for legacy deployed balances.

## Accepted Risks

- Pull payments add an extra user action for recipients. This is accepted
  because it removes push-payment denial-of-service and reentrancy risk.
- Category totals require careful storage updates and invariant tests. This is
  accepted because the totals are needed for emergency-withdrawable views and
  auditability.
- A shared ledger module may require contract refactoring. This is accepted
  because inconsistent local accounting would be harder to audit.
- If a withdrawal recipient always reverts, that account's ETH may remain
  credited until the account chooses a working recipient path. This is accepted
  as long as credits remain visible and cannot be swept as surplus.
- Exact pause behavior for withdrawals depends on the admin/governance ADR.
  This ADR requires balances to remain preserved regardless of pause policy.
