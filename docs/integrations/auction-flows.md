# Auction Flows

This document is the integration flow spec for auction drops through
`StreamDrops.mintDrop`, `StreamMinter.mintAndAuction`, and `StreamAuctions`.
It is for React, mobile, Electron, backend signing service, and indexer teams
that need to submit, observe, or reconstruct auction lifecycle events.

The repository remains a pre-audit local baseline. It is not production-ready
and this document is not a security claim. Local evidence does not replace
fork/testnet/live evidence required for public beta or production release.

Use this together with the fixed-price flow spec in
[`docs/integrations/contract-flows.md`](contract-flows.md), the signing guide in
[`docs/drop-authorization-signing.md`](../drop-authorization-signing.md), the
custody model in [`docs/auction-custody.md`](../auction-custody.md), and the
release dashboard in [`docs/release-readiness.md`](../release-readiness.md).

## Maturity And Scope

This flow documents the current checked local contract behavior for auction
drops. It covers the submit path, EIP-712 authorization payload, contract
reads, canonical auction states, bid and settlement mechanics, credit
withdrawals, events, indexer reconstruction, frontend state transitions, pause
domains, and known integration gaps.

This document does not claim:

- reviewed production deployment addresses;
- reviewed external audit evidence;
- production signer custody;
- live indexer replay evidence;
- marketplace display evidence; or
- final React, mobile, or Electron reference implementation readiness.

The exact public beta and production blockers remain tracked by
[`release-artifacts/latest/risk-register.json`](../../release-artifacts/latest/risk-register.json),
[`release-artifacts/latest/public-beta-evidence.json`](../../release-artifacts/latest/public-beta-evidence.json),
[`docs/public-beta-evidence.md`](../public-beta-evidence.md), and
[`docs/non-local-release-evidence.md`](../non-local-release-evidence.md).

## Auction Mint Overview

The auction path is:

1. A backend signing service prepares a `DropAuthorization` for an auction drop
   with `saleMode = 2`.
2. The signer signs the typed data under the current EIP-712 domain, signer
   epoch, nonce, deadline, chain, and verifying contract.
3. A client submits `StreamDrops.mintDrop(authorization, tokenData, signature)`
   with `msg.value == 0`.
4. `StreamDrops` validates the drop, consumes `dropId`, calls
   `StreamMinter.mintAndAuction`, stores poster and reserve price reads, then
   calls `StreamAuctions.registerAuction`.
5. `StreamMinter` mints custody to the auction contract, and
   emits `MinterAuctionMinted` with the original custody target and minter
   end time. `StreamAuctions` records the auction, confirms custody, and emits
   the auction registration/status events.
6. Bidders call `StreamAuctions.participateToAuction(tokenId)` with ETH.
   Outbid bidders receive withdrawable bidder credit.
7. After the strict end condition `block.timestamp > auctionEndTime`, anyone
   may call `claimAuction(tokenId)`.
8. A with-bid settlement transfers the token to the highest bidder and records
   poster, protocol, and curator proceeds credits. A no-bid settlement either
   sends the token to the poster or records a poster-only no-bid claimant,
   depending on whether the poster can receive ERC-721 custody.

The integration surface is spread across
[`smart-contracts/StreamDrops.sol`](../../smart-contracts/StreamDrops.sol),
[`smart-contracts/StreamMinter.sol`](../../smart-contracts/StreamMinter.sol),
[`smart-contracts/AuctionContract.sol`](../../smart-contracts/AuctionContract.sol),
[`smart-contracts/IStreamAuctions.sol`](../../smart-contracts/IStreamAuctions.sol),
and [`smart-contracts/StreamPauseDomains.sol`](../../smart-contracts/StreamPauseDomains.sol).

## Source Of Truth

Use tracked generated artifacts and checked docs, not hand-maintained copies.

| Need | Source of truth | Integration note |
| --- | --- | --- |
| Integration entrypoint | [`docs/integrations/README.md`](README.md) | Starts frontend, mobile, Electron, indexer, operator UI, and signing-service discovery |
| Fixed-price flow contrast | [`docs/integrations/contract-flows.md`](contract-flows.md) | Fixed-price uses `saleMode = 1`; auctions use `saleMode = 2` and `msg.value == 0` on submit |
| Auction custody model | [`docs/auction-custody.md`](../auction-custody.md) | Explains token custody and no-bid settlement boundaries |
| Custody ADR | [`docs/adr/0002-auction-custody.md`](../adr/0002-auction-custody.md) | Design decision record for custody |
| Payment ADR | [`docs/adr/0003-payment-accounting.md`](../adr/0003-payment-accounting.md) | Design decision record for credits and owed balances |
| Signing guide | [`docs/drop-authorization-signing.md`](../drop-authorization-signing.md) | EIP-712 and ERC-1271 local guidance |
| Release readiness | [`docs/release-readiness.md`](../release-readiness.md) | Current launch blocker dashboard |
| Non-local evidence boundary | [`docs/non-local-release-evidence.md`](../non-local-release-evidence.md) | Retained fork/testnet/live evidence requirements |
| Public beta evidence | [`docs/public-beta-evidence.md`](../public-beta-evidence.md) | Public beta gate evidence |
| Risk register | [`release-artifacts/latest/risk-register.json`](../../release-artifacts/latest/risk-register.json) | Generated blocker and risk source |
| Release manifest | [`release-artifacts/latest/release-manifest.json`](../../release-artifacts/latest/release-manifest.json) | Generated source-of-truth manifest |
| ABI review surface | [`release-artifacts/baselines/v0.1.0/abi-surface.json`](../../release-artifacts/baselines/v0.1.0/abi-surface.json) | Tracked ABI baseline |
| ABI checksums | [`release-artifacts/latest/abi-checksums.json`](../../release-artifacts/latest/abi-checksums.json) | Integrator checksum source |
| Event topic catalog | [`release-artifacts/latest/event-topic-catalog.json`](../../release-artifacts/latest/event-topic-catalog.json) | Indexer event signature source |
| Interface IDs | [`release-artifacts/latest/interface-ids.json`](../../release-artifacts/latest/interface-ids.json) | Interface lookup source |
| Local address book | [`deployments/address-books/anvil-6529stream-v0.1.0-001.json`](../../deployments/address-books/anvil-6529stream-v0.1.0-001.json) | Local development addresses |
| Fork-mainnet address book | [`deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json`](../../deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json) | Retained fork rehearsal addresses |
| Auction contract | [`smart-contracts/AuctionContract.sol`](../../smart-contracts/AuctionContract.sol) | Bid, settlement, credit, and pause logic |
| Drops contract | [`smart-contracts/StreamDrops.sol`](../../smart-contracts/StreamDrops.sol) | Authorization validation and auction registration bridge |
| Minter contract | [`smart-contracts/StreamMinter.sol`](../../smart-contracts/StreamMinter.sol) | NFT mint and auction custody transfer bridge |
| Auction interface | [`smart-contracts/IStreamAuctions.sol`](../../smart-contracts/IStreamAuctions.sol) | Integration-facing auction calls |
| Pause domains | [`smart-contracts/StreamPauseDomains.sol`](../../smart-contracts/StreamPauseDomains.sol) | `AUCTION_BID` and `AUCTION_SETTLEMENT` keys |
| Auction custody tests | [`test/StreamAuctionCustody.t.sol`](../../test/StreamAuctionCustody.t.sol) | Custody and no-bid characterization |
| Auction payment tests | [`test/StreamAuctionPayments.t.sol`](../../test/StreamAuctionPayments.t.sol) | Bidder/proceeds credit behavior |
| Auction invariant tests | [`test/StreamAuctionInvariant.t.sol`](../../test/StreamAuctionInvariant.t.sol) | Auction accounting invariant baseline |
| Payment invariant tests | [`test/StreamPaymentsInvariant.t.sol`](../../test/StreamPaymentsInvariant.t.sol) | Cross-payment owed/surplus invariants |
| Protocol state-machine tests | [`test/StreamProtocolStateMachine.t.sol`](../../test/StreamProtocolStateMachine.t.sol) | End-to-end deterministic protocol flows |
| Pause tests | [`test/StreamPauseControls.t.sol`](../../test/StreamPauseControls.t.sol) | Pause-domain expectations |
| Auction signature fixture | [`test/fixtures/drop-authorization/auction-eoa.json`](../../test/fixtures/drop-authorization/auction-eoa.json) | Signed local EOA auction payload |
| Unsigned auction payload | [`test/fixtures/drop-authorization/payload-generator/auction-output.json`](../../test/fixtures/drop-authorization/payload-generator/auction-output.json) | Deterministic payload-generator output |
| Payload generator | [`scripts/generate_drop_authorization_payload.py`](../../scripts/generate_drop_authorization_payload.py) | No-secret typed-data payload generator |

## Artifact Inputs

An app needs these inputs before showing an auction action:

- contract addresses for `StreamDrops`, `StreamMinter`, `StreamAuctions`,
  `StreamCore`, and `Delegation`;
- the current chain ID and verifying contract for the EIP-712 domain;
- the signer address or accepted ERC-1271 contract signer from governance;
- current signer epoch and deadline policy from the backend signing service;
- the generated ABI surface or locally built ABIs;
- auction event topics from `event-topic-catalog.json`;
- pause-domain keys for `AUCTION_BID` and `AUCTION_SETTLEMENT`;
- collection ID, token data, token data hash, reserve price, auction end time,
  salt, nonce, and deadline;
- the expected poster, zero recipient, zero payer, zero fixed price, quantity,
  and `saleMode = 2`; and
- the release evidence boundary from the current public beta and production
  blocker docs.

Raw ABIs under ignored `out/` are local build products. For committed review,
use `release-artifacts/baselines/v0.1.0/abi-surface.json`,
`release-artifacts/latest/abi-checksums.json`,
`release-artifacts/latest/event-topic-catalog.json`, and
`release-artifacts/latest/interface-ids.json`.

## Preflight Reads

Before accepting an auction payload or enabling an auction action, a client
should read or derive:

- `StreamDrops.domainSeparator()` or equivalent EIP-712 domain data from the
  ABI and chain context;
- signer status, signer epoch, consumed/cancelled drop state, and deadline
  freshness through the signing-service policy;
- `StreamDrops.auctionContract()` to confirm the target auction contract;
- `StreamDrops.retrieveAuctionPoster(tokenId)` and
  `StreamDrops.retrieveAuctionPrice(tokenId)` after minting;
- `StreamAuctions.auctionRecords(tokenId)`;
- `StreamAuctions.retrieveAuctionStatus(tokenId)`;
- `StreamAuctions.retrieveAuctionEndTime(tokenId)`;
- `StreamAuctions.retrieveNoBidAuctionClaimant(tokenId)`;
- `StreamAuctions.auctionHighestBid(tokenId)`;
- `StreamAuctions.auctionHighestBidder(tokenId)`;
- `StreamAuctions.auctionBidderCredits(account)`;
- `StreamAuctions.auctionPosterCredits(account)`;
- `StreamAuctions.auctionProtocolCredits(account)`;
- `StreamAuctions.auctionCuratorCredits(account)`;
- `StreamAuctions.totalAuctionBidEscrow()`;
- `StreamAuctions.totalBidderOwed()`;
- `StreamAuctions.totalProceedsOwed()`;
- `StreamAuctions.totalOwed()`;
- `StreamAuctions.totalReserved()`;
- `StreamAuctions.surplus()`;
- `StreamAuctions.emergencyWithdrawable()`;
- `StreamMinter.getAuctionStatus(tokenId)` only as a legacy mint bridge flag;
  and
- `StreamMinter.getAuctionEndTime(tokenId)` only as the original minter value,
  not the authoritative extended auction end time.

`StreamAuctions.retrieveAuctionEndTime(tokenId)` is authoritative after a late
bid extension. `StreamMinter.getAuctionEndTime(tokenId)` can be stale after
`AuctionExtended`.

## Authorization Payload

Auction submissions use the same `DropAuthorization` typed-data schema as
fixed-price minting, but the payload must satisfy the auction-specific field
contract:

| Field | Required auction value |
| --- | --- |
| `saleMode` | `saleMode = 2` |
| `recipient` | `recipient = address(0)` |
| `payer` | `payer = address(0)` |
| `price` | `price = 0` |
| `quantity` | Current contract path mints one auction token |
| `auctionReservePrice` | Non-zero or zero reserve allowed by policy, used as first-bid floor |
| `auctionEndTime` | Future timestamp; `StreamMinter` enforces a 10-minute minimum |
| `poster` | Final no-bid claimant or proceeds recipient |
| `tokenDataHash` | Hash of the exact token data sent with `mintDrop` |
| `salt`, `nonce`, `deadline`, `signerEpoch` | Replay, cancellation, expiry, and signer-rotation controls |

The submit transaction must use `msg.value == 0`. Auction value enters through
`StreamAuctions.participateToAuction`, not through `mintDrop`.

The EIP-712 domain must bind the current name, version, chain ID, and verifying
contract. EIP-712 is an encoding and signing scheme, not replay protection by
itself; replay safety depends on `deriveDropId`, `consumedDropIds`,
`cancelledDropIds`, nonce/salt/deadline policy, signer epoch storage, and the
consumed-state write before the auction bridge.

EOA signatures and ERC-1271 signatures should follow the same acceptance
boundary documented in the signing guide. Wrong signer, wrong chain, wrong
domain, expired, cancelled, consumed, replayed, malformed, and stale signer
epoch payloads should be treated as terminal client errors, not retryable
wallet failures.

## Submit Auction Drop

Submit:

```solidity
StreamDrops.mintDrop(authorization, tokenData, signature)
```

with:

- `authorization.saleMode = 2`;
- `authorization.recipient = address(0)`;
- `authorization.payer = address(0)`;
- `authorization.price = 0`;
- `authorization.auctionReservePrice` set to the intended reserve;
- `authorization.auctionEndTime` in the future and at least the minter minimum;
- `msg.value == 0`; and
- `tokenData` matching `authorization.tokenDataHash`.

The submit path emits drop-side and auction-side events:

- `DropAuthorizationConsumed`;
- `MinterAuctionMinted`;
- `AuctionRegistered`;
- `AuctionCustodyConfirmed`;
- `AuctionStatusChanged` with `Active`; and
- the ERC-721 `Transfer` events emitted by the mint/custody path.

If submit reverts after `dropId` consumption because downstream minting or
auction registration fails, the entire transaction reverts and the consumed
write is rolled back.

## Auction State Machine

The canonical auction states are:

| State | Meaning for clients and indexers |
| --- | --- |
| `None` | No auction record exists for the token |
| `Created` | Reserved enum state; current `registerAuction` path starts at `Active` |
| `Active` | Auction exists, custody is expected at `StreamAuctions`, bids may be accepted if `AUCTION_BID` is not paused |
| `EndedNoBid` | `block.timestamp > endTime`, no highest bid, settlement available |
| `EndedWithBid` | `block.timestamp > endTime`, highest bid exists, settlement available |
| `SettledNoBid` | No-bid settlement is complete or a no-bid token claimant is recorded |
| `SettledWithBid` | With-bid settlement transferred the token to the winning bidder and recorded proceeds credits |
| `Cancelled` | Active no-bid auction was cancelled by poster or admin |

State transitions:

| Transition | Trigger | Required observations |
| --- | --- | --- |
| `None -> Active` | `mintDrop` calls `registerAuction` | `AuctionRegistered`, `AuctionCustodyConfirmed`, `AuctionStatusChanged(Active)` |
| `Active -> Active` | Valid bid or outbid | `Participate`, optional `OutbidCreditCreated`, optional `AuctionExtended` |
| `Active -> EndedNoBid` | Time passes with no bid | View-only derived state; no event until settlement |
| `Active -> EndedWithBid` | Time passes with a bid | View-only derived state; no event until settlement |
| `EndedNoBid -> SettledNoBid` | `claimAuction` or `claimNoBidAuctionToken` | `NoBidSettlementPending` when poster cannot receive, then `NoBidTokenClaimed`; otherwise `AuctionStatusChanged`, `ClaimAuction`, and ERC-721 `Transfer` |
| `EndedWithBid -> SettledWithBid` | `claimAuction` | `AuctionProceedsCreditCreated`, `AuctionStatusChanged`, `ClaimAuction`, and ERC-721 `Transfer` |
| `Active -> Cancelled` | `cancelAuction` before bids | `AuctionCancelled`, `AuctionStatusChanged(Cancelled)`, and ERC-721 `Transfer` |

The current implementation has no path that emits `AuctionStatusChanged` with
`Created`; `Created` is reserved for a future non-atomic custody flow.

`EndedNoBid` and `EndedWithBid` are derived by
`retrieveAuctionStatus(tokenId)` using a strict timestamp check:
`block.timestamp > endTime`. A bid exactly at `endTime` is still active and can
extend the auction.

## Bidding

Bid with:

```solidity
StreamAuctions.participateToAuction(tokenId)
```

with ETH sent as `msg.value`.

Current bid rules:

- bidding is blocked when `AUCTION_BID` / `AuctionBid` is paused;
- the auction must be `Active`;
- the first bid must be greater than or equal to the reserve price;
- later bids must satisfy the contract's minimum increment over
  `auctionHighestBid(tokenId)`;
- a valid outbid moves the previous highest bid into
  `auctionBidderCredits(previousBidder)`;
- `totalAuctionBidEscrow` is replaced by the new highest bid value for the
  token;
- `Participate` is emitted for each bid;
- `OutbidCreditCreated` is emitted when previous bidder credit is created; and
- `AuctionExtended` is emitted when a late bid extends the end time.

There is no dedicated `minimumNextBid(tokenId)` view in the current ABI.
Frontends must compute the next minimum bid from the current reserve/highest
bid rules until a future `CON-003` integration-read-view issue adds a
contract-level helper.

## Settlement

Settle with:

```solidity
StreamAuctions.claimAuction(tokenId)
```

Settlement is blocked when `AUCTION_SETTLEMENT` / `AuctionSettlement` is
paused. It is available only after `retrieveAuctionStatus(tokenId)` returns
`EndedNoBid` or `EndedWithBid`.

With-bid settlement:

- reads `auctionHighestBid(tokenId)` and `auctionHighestBidder(tokenId)`;
- marks terminal status `SettledWithBid`;
- sets `auctionClaim(tokenId)`;
- subtracts the highest bid from `totalAuctionBidEscrow`;
- records poster, protocol, and curator credits;
- transfers the token from `StreamAuctions` to the highest bidder;
- emits three `AuctionProceedsCreditCreated` events;
- emits `AuctionStatusChanged(tokenId, SettledWithBid)`; and
- emits `ClaimAuction(tokenId, highestBid)`.

Credit math for a settled with-bid auction is:

- poster credit: `highestBid / 2`;
- protocol credit: `highestBid / 4`; and
- curator credit: `highestBid - posterCredit - protocolCredit`.

The integer remainder goes to the curator credit in the current auction
contract. This differs from fixed-price minting, where the integer remainder
goes to protocol credit; app copy and accounting views must not reuse the
fixed-price ratio labels blindly.

Settlement is idempotent from an integration perspective: after terminal status
and `auctionClaim(tokenId)` are set, repeating settlement should fail without
creating duplicate credits or moving the token again.

## No-Bid Claims

No-bid settlement has two paths:

- If the poster can receive the ERC-721, `claimAuction(tokenId)` transfers the
  token to the poster and emits `AuctionStatusChanged` and `ClaimAuction`.
- If the poster cannot receive the token, settlement records
  `pendingNoBidNftClaimant`, emits `NoBidSettlementPending`, and leaves the
  token in auction custody until the claimant calls
  `claimNoBidAuctionToken(tokenId, recipient)`.

For the pending-claim path:

- only the recorded claimant can claim;
- the recipient must not be zero;
- `claimNoBidAuctionToken` sets terminal status `SettledNoBid`;
- `NoBidTokenClaimed` records the claimant and final recipient; and
- the ERC-721 `Transfer` event records the final token recipient.

Indexers should treat `NoBidSettlementPending` as a non-terminal user-facing
state even though the auction is no longer bid-capable.

## Cancellation

`cancelAuction(tokenId)` can cancel only an active auction with no bids.

Valid callers are:

- the poster recorded in the auction record; or
- a global/function admin authorized for `cancelAuction`.

Cancellation:

- sets terminal status `Cancelled`;
- sets `auctionClaim(tokenId)`;
- transfers the token from the auction contract back to the poster;
- emits `AuctionCancelled`; and
- emits `AuctionStatusChanged(tokenId, Cancelled)`.

Cancellation is not the same as drop cancellation before submit. Drop
authorization cancellation is tracked by `cancelledDropIds` in `StreamDrops`.
Auction cancellation happens after an auction token exists.

## Credits And Withdrawals

Auction accounting uses four balance families:

- bidder credits from outbid refunds: `auctionBidderCredits`;
- poster proceeds credits: `auctionPosterCredits`;
- protocol proceeds credits: `auctionProtocolCredits`;
- curator proceeds credits: `auctionCuratorCredits`;

Owed and reserve views:

- `totalAuctionBidEscrow` tracks active winning bids still held for unsettled
  auctions;
- `totalBidderOwed` tracks outbid refund credits;
- `totalProceedsOwed` tracks poster, protocol, and curator proceeds credits;
- `totalOwed` equals bidder credits, active bid escrow, and proceeds credits;
- `totalReserved` returns the amount reserved against the contract balance;
- `surplus` returns ETH above reserved obligations; and
- `emergencyWithdrawable` is the surplus-only emergency amount.

Payment invariants for app and indexer reconciliation:

- bidder owed plus proceeds owed plus active bid escrow equals `totalOwed`;
- contract balance must cover `totalReserved`;
- failed bidder withdrawal must not erase `auctionBidderCredits`;
- failed proceeds withdrawal must not erase `auctionPosterCredits`,
  `auctionProtocolCredits`, or `auctionCuratorCredits`;
- emergency withdrawal cannot withdraw owed bidder, poster, protocol, curator,
  or active-bid funds; and
- previous bidder refund becomes withdrawable credit instead of a synchronous
  push payment.

Withdraw:

```solidity
StreamAuctions.withdrawBidderCreditTo(recipient)
StreamAuctions.withdrawAuctionProceedsCreditTo(recipient)
```

Credits belong to `msg.sender`; the `recipient` only receives the ETH. A
frontend should show credit owner and recipient separately.

## Events And Indexing

Indexers should ingest the generated topics in
[`release-artifacts/latest/event-topic-catalog.json`](../../release-artifacts/latest/event-topic-catalog.json)
and reconstruct auction state from both events and reads.

Core auction events:

- `AuctionRegistered`;
- `AuctionCustodyConfirmed`;
- `AuctionStatusChanged`;
- `AuctionExtended`;
- `AuctionCancelled`;
- `NoBidSettlementPending`;
- `NoBidTokenClaimed`;
- `Participate`;
- `OutbidCreditCreated`;
- `BidderCreditWithdrawn`;
- `AuctionProceedsCreditCreated`;
- `ProceedsCreditWithdrawn`;
- `ClaimAuction`; and
- `EmergencyWithdrawal`.

Drop-side and token-side events needed for full reconstruction:

- `DropAuthorizationConsumed`;
- `AuctionContractChanged`;
- `MinterAuctionMinted`;
- `MinterAuctionEndTimeUpdated`;
- ERC-721 `Transfer`; and
- admin pause events emitted by the admin contract for `AUCTION_BID` and
  `AUCTION_SETTLEMENT`.

Indexer notes:

- `AuctionRegistered` includes `dropId`, `tokenId`, `collectionId`, `poster`,
  custody, reserve price, and end time.
- `AuctionStatusChanged` currently includes `tokenId` and new status but not
  previous status, `dropId`, or `collectionId`; join it to `AuctionRegistered`.
- `ClaimAuction` currently includes `tokenId` and bid but not winner; for
  with-bid settlement, join `auctionHighestBidder(tokenId)` before settlement
  or infer final recipient from the ERC-721 `Transfer` from auction custody.
- Direct no-bid settlement has no dedicated recipient event beyond ERC-721
  `Transfer`, `AuctionStatusChanged`, and `ClaimAuction`.
- `AuctionExtended` means the authoritative end time is
  `StreamAuctions.retrieveAuctionEndTime(tokenId)`.
- `MinterAuctionMinted` records the original auction custody address and
  minter bridge end time at mint.
- `MinterAuctionEndTimeUpdated` records minter-side end-time edits, but
  `StreamAuctions.retrieveAuctionEndTime(tokenId)` remains authoritative once
  the auction contract is registered and can extend late bids.
- The view-derived `EndedNoBid` and `EndedWithBid` states do not emit events
  when time crosses the boundary.

These event/read gaps are tracked for follow-up under the integration read-view
backlog, including `CON-003` and `INT-005`.

## Pause And Emergency Boundaries

Auction bid pause:

- domain key: `AUCTION_BID`;
- human label: `AuctionBid`;
- blocks `participateToAuction`;
- does not block claim, cancellation, or withdrawals.

Auction settlement pause:

- domain key: `AUCTION_SETTLEMENT`;
- human label: `AuctionSettlement`;
- blocks `claimAuction`;
- does not block bidding, cancellation, bidder-credit withdrawal, or proceeds
  withdrawal.

Emergency behavior:

- `emergencyWithdrawable` is surplus only;
- owed bidder/proceeds credits and active bid escrow must remain reserved;
- emergency withdrawal should emit `EmergencyWithdrawal`; and
- operators should monitor `totalOwed`, `totalReserved`, `surplus`, and
  `emergencyWithdrawable` before and after any incident response action.

## Failure States

| Failure | Client classification |
| --- | --- |
| Wrong chain or wrong domain | Terminal signing/domain error |
| Expired authorization | Terminal; request a fresh signature |
| Cancelled authorization | Terminal governance/backend state |
| Consumed authorization or replay | Terminal duplicate submission |
| Wrong signer or stale signer epoch | Terminal signer policy error |
| Non-zero auction recipient | Terminal payload error |
| Non-zero auction payer | Terminal payload error |
| Non-zero auction price | Terminal payload error |
| Non-zero `msg.value` on submit | Terminal transaction construction error |
| Missing auction contract | Operator configuration error |
| Auction end too soon | Payload policy error; minter enforces at least 10 minutes |
| Bid below reserve | User input error |
| Bid below increment | User input error |
| Bid after strict end boundary | Time-state error |
| Bid paused | Retry after operator unpauses |
| Settlement paused | Retry after operator unpauses |
| Settlement before end | Time-state error |
| Claim after terminal status | Terminal duplicate settlement |
| No-bid claimant mismatch | Wallet/account mismatch |
| Withdrawal with no credit | Terminal no-balance state |
| Failed ETH withdrawal | Retry with a payable recipient; credit must remain |

Use `eth_call` simulation for submission, bid, settlement, and withdrawal
buttons, but do not treat successful simulation as release approval.

## Frontend State Machine

Suggested frontend states:

| UI state | Contract source |
| --- | --- |
| Draft authorization | Backend payload before signature |
| Ready to submit | Signature present, deadline fresh, chain/domain verified |
| Submitting auction drop | Wallet transaction for `mintDrop` pending |
| Active, no bid | `retrieveAuctionStatus` is `Active` and `auctionHighestBid` is zero |
| Active, leading bid | `retrieveAuctionStatus` is `Active` and `auctionHighestBid` is non-zero |
| Bid paused | Admin pause for `AUCTION_BID` is active |
| Needs settlement | `EndedNoBid` or `EndedWithBid` |
| Settlement paused | Admin pause for `AUCTION_SETTLEMENT` is active |
| Awaiting no-bid claimant | `retrieveNoBidAuctionClaimant` is non-zero |
| Settled with bid | `retrieveAuctionStatus` is `SettledWithBid` |
| Settled no bid | `retrieveAuctionStatus` is `SettledNoBid` |
| Cancelled | `retrieveAuctionStatus` is `Cancelled` |
| Credit available | Any auction bidder/proceeds credit read is non-zero |

Countdowns should use `retrieveAuctionEndTime`, not the stale minter end-time
view. The end-state transition should wait for `block.timestamp > endTime`.
Buttons should keep bid, settlement, and withdrawal states independent because
the pause domains are independent.

## Indexer Reconstruction

Minimum persisted auction projection fields:

- `dropId`;
- `tokenId`;
- `collectionId`;
- `poster`;
- `custody`;
- `reservePrice`;
- `auctionEndTime`;
- `status`;
- `highestBid`;
- `highestBidder`;
- `pendingNoBidNftClaimant`;
- `bidderCredits`;
- `posterCredits`;
- `protocolCredits`;
- `curatorCredits`;
- `totalAuctionBidEscrow`;
- `totalBidderOwed`;
- `totalProceedsOwed`;
- `totalOwed`;
- `totalReserved`;
- `surplus`;
- `emergencyWithdrawable`; and
- pause status for `AuctionBid` and `AuctionSettlement`.

Recommended reconstruction order:

1. Ingest address books and deployment manifests for the target environment.
2. Ingest event topic catalog and ABI checksums for the release.
3. Process `DropAuthorizationConsumed` to mark auction drop submission.
4. Process `AuctionRegistered` as the primary auction creation record.
5. Process ERC-721 `Transfer` into auction custody and verify custody address.
6. Process `Participate`, `OutbidCreditCreated`, and `AuctionExtended`.
7. Recompute view-derived `EndedNoBid` and `EndedWithBid` from block time and
   `retrieveAuctionStatus`.
8. Process settlement, no-bid, cancellation, withdrawal, and emergency events.
9. Periodically reconcile read views against projected totals.
10. Retain reorg-safe confirmation depth according to the deployment network
    policy.

For reorg safety, backend signing and indexers should treat drop signing,
submission, and event replay as confirmation-depth-aware workflows. Signed
payload invalidation under reorgs remains a production operations concern, not
a local-only script guarantee.

## Validation Commands

Run the focused auction-flow checks after changing this document:

```sh
python scripts/test_auction_flows.py
python scripts/check_auction_flows.py
python scripts/test_integrations_readme.py
python scripts/check_integrations_readme.py
python scripts/test_release_readiness.py
python scripts/check_release_readiness.py
python scripts/check_changelog.py
```

Useful focused Solidity coverage for auction integration behavior:

```sh
forge test --match-path test/StreamAuctionCustody.t.sol
forge test --match-path test/StreamAuctionPayments.t.sol
forge test --match-path test/StreamAuctionInvariant.t.sol
forge test --match-path test/StreamPaymentsInvariant.t.sol
forge test --match-path test/StreamPauseControls.t.sol
forge test --match-path test/StreamProtocolStateMachine.t.sol
forge test --match-path test/StreamMinterEvents.t.sol
```

For release artifact drift after doc/checker updates:

```sh
python scripts/generate_release_manifest.py --check
python scripts/generate_bytecode_release_proof.py --check
python scripts/generate_release_checksums.py --check
```

## Maintenance

Refresh this document and `scripts/check_auction_flows.py` whenever:

- auction ABI, event, revert, pause, or credit behavior changes;
- `AuctionStatus` enum values change;
- new frontend or indexer read views are added;
- event topic catalog or ABI artifact names move;
- `docs/auction-custody.md` or ADR 0002/0003 changes the model;
- release evidence graduates from local baseline to reviewed fork, testnet, or
  live evidence; or
- INT-005 adds a more complete event replay and indexer reconstruction spec.

Keep this document conservative. It should help builders ship against the
current local baseline without weakening the repo's not-production-ready
boundary.
