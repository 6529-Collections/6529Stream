# Auction Custody And Settlement

Baseline record — not a specification. This document describes as-built
or operational state; the normative target is the specification set
indexed in [`docs/spec-policy.md`](spec-policy.md), and where this
document conflicts with a specification home, the specification wins. For
target sale and auction behavior this document is superseded by
[`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md).

6529Stream auction drops use explicit protocol escrow custody.

This document describes the current target-state implementation for
`P0-AUCT-001` and ADR 0002. It is not a production-readiness claim; broader
payment accounting, pause controls, randomizer hardening, deployment rehearsal,
and audit work remain open roadmap items.

## Custody Model

- `StreamDrops` stores an admin-configured `auctionContract`.
- Auction drops cannot mint until that auction contract is configured.
- Auction NFTs are minted to the auction contract, not to `payOutAddress`.
- `payOutAddress` is a payment/accounting recipient, not NFT custody.
- `StreamAuctions` implements `IERC721Receiver` and only accepts ERC-721
  callbacks from the configured `StreamCore` contract.
- After minting, `StreamDrops` calls `StreamAuctions.registerAuction(...)`.
- Registration requires `ownerOf(tokenId) == address(StreamAuctions)`.

This makes custody observable immediately after drop execution and removes the
legacy dependency on payout-wallet approvals.

## Auction State

`StreamAuctions.retrieveAuctionStatus(tokenId)` returns the canonical ADR 0002
state:

| State | Meaning |
| --- | --- |
| `None` | No registered auction record exists. |
| `Created` | A record exists but custody is not confirmed. |
| `Active` | Custody is confirmed and bidding is open. |
| `EndedNoBid` | The end time passed with no valid bid. |
| `EndedWithBid` | The end time passed with a valid highest bid. |
| `SettledNoBid` | No-bid settlement completed and the NFT left escrow. |
| `SettledWithBid` | With-bid settlement completed and the NFT left escrow. |
| `Cancelled` | Pre-bid cancellation completed. |

The current drop path mints to the auction contract and registers custody in
one transaction, so normal auction drops enter `Active` directly. `Created` is
retained as an explicit state for any future non-atomic custody flow.

Ended states are derived from time and bid state. Terminal states are stored so
repeated settlement or cancellation cannot duplicate token transfers, credits,
or events.

## Bidding

- Bids are accepted only while status is `Active`.
- The first bid must meet or exceed the signed reserve price.
- Later bids must satisfy the configured increment percentage.
- Outbid bidders receive withdrawable bidder credits.
- The active highest bid remains in auction escrow until settlement.
- Bids near the end extend the auction record and emit `AuctionExtended`.
- After an extension, `retrieveAuctionEndTime(tokenId)` is the authoritative
  auction end-time view. The legacy minter end-time view can still show the
  original signed end time.

## Settlement

Settlement is permissionless after the auction ends.

No-bid settlement:

- If the poster is an EOA, the NFT is safely transferred from auction escrow
  to the signed poster.
- If the poster is a contract, settlement records `pendingNoBidNftClaimant`
  and keeps the NFT in escrow until the poster chooses a receiving address.
- The poster can complete the claim with
  `claimNoBidAuctionToken(tokenId, recipient)`.
- `SettledNoBid` is reached only after the NFT leaves escrow.

With-bid settlement:

- Settlement atomically transfers the NFT from auction escrow to the highest
  bidder and moves active bid escrow into final proceeds credits.
- If the NFT transfer reverts, the terminal state and final proceeds credits
  revert with it.
- Poster, protocol, and curator proceeds are withdrawable pull credits.
- The poster/protocol split uses integer division; any remainder accrues to the
  curator credit so every wei of the highest bid remains owed.
- A failed NFT transfer leaves the auction in `EndedWithBid`, keeps active bid
  escrow intact, and creates no proceeds credits.

## Pause And Emergency Boundaries

Pause controls are domain-scoped:

- `AuctionBid` pause blocks new bids, but it does not change the current highest
  bid, current highest bidder, active bid escrow, outbid bidder credits, token
  custody, or user withdrawal availability.
- `AuctionSettlement` pause blocks ended-auction settlement and no-bid claims,
  but it does not move escrowed NFTs, erase active bid escrow, create proceeds,
  or change owed balances.
- Contract-poster no-bid auctions remain in escrow while settlement is paused.
  After unpause, settlement can record the poster as the pending claimant; a
  later claim is also blocked by settlement pause until unpaused again.
- User withdrawals are intentionally outside the operational pause domains.
  Bidder credits and settled proceeds remain withdrawable unless a future ADR
  explicitly accepts a bounded withdrawal pause.
- Emergency withdrawal is surplus-only. It cannot withdraw bidder credits,
  active highest-bid escrow, or settled poster/protocol/curator proceeds while
  bid or settlement domains are paused. Forced surplus may be withdrawn during
  a pause, but the post-withdrawal contract balance must still cover owed
  balances.
- Repeated settlement after a terminal state is rejected and cannot duplicate
  proceeds after a pause/unpause sequence.

## Cancellation

Cancellation is intentionally narrow:

- allowed only before the first valid bid
- allowed only while the auction is active
- callable by the signed poster or an authorized auction admin
- transfers custody back to the poster
- stores terminal `Cancelled`

Cancellation after a bid, after the end time, or after settlement is rejected.

## Accounting Scope

This implementation includes auction-local accounting needed for ADR 0002:

- bidder credits
- active highest-bid escrow
- poster proceeds credits
- protocol proceeds credits
- curator proceeds credits
- `totalOwed()`
- `emergencyWithdrawable()`

Full protocol-wide payment accounting is owned by ADR 0003 and the `P0-PAY-*`
roadmap items. The current local baseline includes fixed-price pull payments,
curator reward accounting, randomizer reserve accounting, and cross-contract
payment invariants in the payment-focused test suite. Fork/testnet/live
evidence remains separate release-gate work.

## Key Events

- `AuctionRegistered`
- `AuctionCustodyConfirmed`
- `AuctionStatusChanged`
- `AuctionExtended`
- `Participate`
- `OutbidCreditCreated`
- `AuctionCancelled`
- `NoBidSettlementPending`
- `NoBidTokenClaimed`
- `AuctionProceedsCreditCreated`
- `BidderCreditWithdrawn`
- `ProceedsCreditWithdrawn`
- `ClaimAuction`

Indexers should use `tokenId` plus `dropId` from the registration event and
`retrieveAuctionStatus(tokenId)` for current state. The ERC-721 receiver hook is
currently read-only and only validates that the incoming NFT is from the core
contract; any future receiver-side effects should be treated as a deliberate
interface change.
