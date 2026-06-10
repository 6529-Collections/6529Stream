# ADR 0002: Auction Custody

## Status

Accepted.

## Metadata

| Field | Value |
| --- | --- |
| Date | 2026-06-10 |
| Issue | [P0-AUCT-ADR](https://github.com/6529-Collections/6529Stream/issues/21) |
| Blocks | [P0-AUCT-001](https://github.com/6529-Collections/6529Stream/issues/22), [P0-AUCT-002](https://github.com/6529-Collections/6529Stream/issues/12) |
| Related issues | [P0-PAY-008](https://github.com/6529-Collections/6529Stream/issues/8) |
| Affected contracts | `smart-contracts/AuctionContract.sol`, `smart-contracts/StreamDrops.sol`, `smart-contracts/StreamMinter.sol`, `smart-contracts/StreamCore.sol` |
| Work type | `DESIGN` |

## Problem

Auction drops need a custody and settlement model that is explicit enough to
implement, test, index, audit, and explain to external contributors. The
current implementation starts auctions without a reliable custody invariant and
settles by combining NFT transfer, ETH payout, and terminal state updates in a
single value-moving flow.

Before any public beta auction path is enabled, the protocol needs to decide:

- who owns or controls the auctioned NFT during the auction
- who may settle the auction after it ends
- who receives the NFT when there is no bid
- how outbid refunds and final proceeds are accounted for
- when auction state becomes terminal
- how cancellation and emergency handling work

## Current Behavior

Current source references:

- `smart-contracts/StreamDrops.sol#L72-L110`: `mintDrop` creates fixed-price
  or auction drops and stores drop metadata.
- `smart-contracts/StreamDrops.sol#L97-L100`: auction drops call
  `mintAndAuction(payOutAddress, ...)`, then store poster and reserve price
  data.
- `smart-contracts/StreamDrops.sol#L108`: the stored execution address is
  `tx.origin`.
- `smart-contracts/StreamMinter.sol#L90-L102`: `mintAndAuction` records the
  auction end time/status and mints the token to the supplied recipient.
- `smart-contracts/AuctionContract.sol#L54-L61`: auction state is split across
  highest-bid, highest-bidder, and claimed mappings.
- `smart-contracts/AuctionContract.sol#L64-L88`: bidding refunds the previous
  highest bidder with an external `call` before updating the highest bid and
  highest bidder.
- `smart-contracts/AuctionContract.sol#L91-L108`: settlement marks the token
  claimed, pushes ETH to poster, payout, and curators, then transfers the NFT
  from `ownerOf(tokenId)` to the winning bidder.
- `smart-contracts/AuctionContract.sol#L146-L153`: emergency withdrawal sends
  the full auction-contract ETH balance to the admin owner.
- `ops/SLITHER_BASELINE.md`: high-impact `reentrancy-eth` and
  `arbitrary-send-eth` findings are tracked for auction bidding and emergency
  withdrawals.

Current characterization tests intentionally pin the known-unsafe auction
creation path as a migration tripwire:

- `test/StreamDropsCharacterization.t.sol`
- `test/StreamDropsIntegrationCharacterization.t.sol`

## Decision

6529Stream will use explicit escrow custody for public-beta auctions.

The public-beta target design is:

1. Auctioned tokens are minted or transferred into protocol-controlled escrow
   during auction creation. The default escrow is the auction contract itself,
   renamed or refactored as needed. A dedicated custody contract may be
   introduced only if it preserves the same invariants and has its own tests.
2. `payOutAddress` is not NFT custody. It is only a payment recipient or
   accounting identity.
3. Auction token custody must be known at all times through on-chain state and
   tests.
4. The auction system must be able to receive ERC-721 tokens safely. If the
   custody address is a contract, it must implement the required receiver hook
   or use a transfer path that is safe for the chosen ERC-721 implementation.
5. Auction status is represented by the canonical state model in this ADR.
6. Bidding is allowed only while an auction is active and before the auction end
   time.
7. Settlement is permissionless after the auction ends unless a future
   admin/governance ADR defines a pause that temporarily blocks settlement.
8. A no-bid auction settles the NFT to the signed poster from ADR 0001. It must
   not use `tx.origin`. If the product later needs a separate no-bid recipient,
   that requires a signed-schema version bump or a later ADR.
9. A with-bid auction settles the NFT to the highest bidder.
10. Settlement is idempotent: repeated settlement attempts must not duplicate
    token transfers, credits, state changes, or events. The implementation may
    return the terminal status or revert with a custom already-settled error,
    but the behavior must be documented and tested.
11. A failed NFT transfer must not mark the auction settled and must not credit
    or release final auction proceeds.
12. Outbid refunds and final proceeds must use pull-payment accounting. No P0
    auction implementation may keep synchronous push refunds or synchronous
    final payout calls in the bid or settlement path.
13. `auctionClaim[tokenId]` is not enough terminal state. It must be replaced or
    wrapped by an explicit status model.
14. Cancellation exists only before the first valid bid and before the auction
    end time. It may be triggered by the poster or by an authorized auction
    admin once the admin/governance ADR finalizes roles. After the first valid
    bid, cancellation is out of scope for the P0 path; emergency handling must
    pause new actions and preserve bidder credits instead of confiscating funds.
15. Emergency withdrawals must not withdraw owed bidder, poster, curator, or
    protocol balances. The payment accounting ADR owns the exact surplus and
    emergency-withdrawal model, but this ADR rejects any auction design that
    can drain active bid escrow or owed credits through a blanket withdrawal.

## Auction State Machine

The implementation must expose an auction status view that maps each token or
auction ID into one of these canonical states:

| State | Meaning | Allowed next states |
| --- | --- | --- |
| `None` | No auction record exists. | `Created` |
| `Created` | Auction record exists and custody assignment is expected but bidding is not active yet. | `Active`, `Cancelled` |
| `Active` | Custody is held by the auction system and bids may be accepted until the end time. | `EndedNoBid`, `EndedWithBid`, `Cancelled` |
| `EndedNoBid` | End time passed and there is no valid highest bidder. | `SettledNoBid` |
| `EndedWithBid` | End time passed and there is a valid highest bidder. | `SettledWithBid` |
| `SettledNoBid` | Terminal no-bid settlement completed. | None |
| `SettledWithBid` | Terminal with-bid settlement completed. | None |
| `Cancelled` | Terminal pre-bid cancellation completed. | None |

The implementation may derive `EndedNoBid` and `EndedWithBid` from
`block.timestamp`, end time, and bid state instead of storing them eagerly.
Terminal states must be stored so repeated settlement or cancellation cannot
repeat side effects.

`Created -> Active` fires only when custody is confirmed. The implementation
must expose this distinction through `custody != address(0)` if the custody
field is written only after receipt, or through an explicit `custodyConfirmed`
field if the intended custody address is written before receipt. When minting
and custody confirmation happen atomically in one transaction, the auction may
be created and activated in that transaction, but events and views must still
make the custody-confirmed state observable.

The implementation should keep the current auction-extension product behavior
only if it can be expressed inside this state model and covered by tests. An
extension must emit an event and must not move an already-ended auction back to
`Active` unless the rule is explicitly documented.

## Intended Storage Shape

Exact Solidity names may change, but the implementation should preserve this
record shape:

```solidity
enum AuctionStatus {
    None,
    Created,
    Active,
    EndedNoBid,
    EndedWithBid,
    SettledNoBid,
    SettledWithBid,
    Cancelled
}

struct AuctionRecord {
    bytes32 dropId;
    uint256 tokenId;
    uint256 collectionId;
    address poster;
    address custody;
    address highestBidder;
    uint256 reservePrice;
    uint256 highestBid;
    uint256 endTime;
    bool custodyConfirmed;
    AuctionStatus terminalStatus;
}
```

Derived status views may compute active and ended states from `terminalStatus`,
`custody`, `custodyConfirmed`, `endTime`, and highest-bid fields. The stored
record must still be sufficient to prove custody, recipient, reserve, and
settlement behavior.

## Payment And External Interaction Policy

ADR 0003 will define the complete pull-payment ledger. Auction custody
implementation must be compatible with that ledger.

Required payment behavior for auction PRs:

- Previous highest bidders become bidder-credit creditors when they are outbid.
- Final with-bid settlement creates withdrawable credits for poster, curator,
  and protocol recipients instead of pushing ETH.
- The bid path updates highest-bid state before any value accounting that can be
  observed externally.
- Failed withdrawals do not erase credits.
- Owed balances cannot be withdrawn through emergency surplus controls.
- Direct or forced ETH cannot corrupt owed-balance accounting.

The exact credit categories, surplus calculation, and withdrawal API are owned
by ADR 0003, but auction implementation must not merge unless it satisfies the
invariants above.

## Events

The P0 implementation must emit events for external state transitions. Event
names may change during implementation, but the event catalog must include:

- auction creation
- custody receipt or custody assignment
- bid placement
- outbid credit creation
- auction extension, if extension remains supported
- cancellation
- no-bid settlement
- with-bid settlement
- final payment credit creation

Events must include stable IDs and indexed fields useful to indexers:

- `auctionId` or `tokenId`
- `dropId`
- `collectionId`
- `poster`
- `bidder` or `highestBidder` when applicable
- previous and new status when applicable

## Cancellation And Pause Interaction

Cancellation is intentionally narrow in the P0 auction model:

- allowed only before the first valid bid
- allowed only before auction end
- terminal once completed
- emits a cancellation event
- returns or releases custody according to the no-bid/poster ownership rule

Pause and emergency controls are owned by the admin/governance ADR, but this
ADR requires the auction implementation to be pause-ready:

- mint or auction creation pause
- bid pause
- settlement pause policy
- withdrawal pause policy from ADR 0003
- events for pause changes
- documentation of who can pause and unpause

Pause must not be used as an accounting shortcut. Paused auctions still need
auditable custody and owed-balance state.

## Alternatives

### Keep Payout Address Custody

Rejected. `payOutAddress` is a payment role, not a custody role. Keeping the
NFT at that address makes ownership and authorization depend on an external
wallet or contract that is not guaranteed to approve auction settlement.

### Approval-Based Seller Custody

Rejected for the P0 public-beta path. Approval-based custody can be revoked or
become stale, creating settlement griefing and ambiguous failure handling. It
may be reconsidered later only with explicit revocation tests, indexer-visible
state, and user-facing documentation.

### Dedicated Custody Contract

Allowed as an implementation detail, but not required by this ADR. A dedicated
custody contract must expose the same state machine and must not create a new
upgrade, ownership, or emergency-withdrawal risk.

### Push Refunds And Push Final Payouts

Rejected. Push payments in bid and settlement paths create denial-of-service and
reentrancy risk. Pull credits are mandatory for P0 auction safety.

### Admin-Only Settlement

Rejected. Permissionless settlement is simpler for users, indexers, and
recovery. Admins may pause settlement only if the admin/governance ADR
explicitly defines that authority and its monitoring requirements.

## Security Impact

This ADR removes the highest-risk auction ambiguity before implementation:

- custody is explicit instead of inferred from `ownerOf(tokenId)`
- no-bid recipient logic is not based on `tx.origin`
- settlement cannot pay proceeds before the NFT transfer succeeds
- outbid refunds move to pull credits
- emergency withdrawals cannot drain owed auction funds
- terminal state replaces the single claimed boolean
- indexers can reconstruct state from events and views

## Migration Impact

The repository is still pre-public-beta, so the P0 implementation may make
breaking contract changes. Existing characterization tests should remain until
new tests prove the replacement behavior.

Any deployed or rehearsal auction records created by the legacy flow should be
treated as non-production test data unless a later migration plan explicitly
documents otherwise.

## Test Plan

Implementation PRs must add or update tests for:

- auction creation and custody assignment
- `Created -> Active` transition and custody-confirmed status views
- bids rejected before custody is confirmed
- escrow receiver behavior
- active bidding before the end time
- bid below reserve rejection
- bid increment rejection and acceptance
- outbid credit creation
- reverting previous bidder cannot block a new bid
- no-bid settlement to poster
- with-bid settlement to highest bidder
- failed NFT transfer leaves auction unsettled and does not create final
  payment credits
- repeated settlement attempt creates no duplicate effects
- cancellation before first bid
- cancellation after first bid rejected
- post-settlement bid rejected
- post-cancellation bid rejected
- event assertions for every state transition
- emergency withdrawal cannot withdraw bid escrow or owed credits
- forced ETH does not corrupt owed/surplus views

Characterization tests for the legacy auction creation path should be kept until
the replacement tests prove the new custody model.

## Rollout Plan

1. Merge this ADR and link it from the roadmap.
2. Implement ADR 0003 for payment accounting before or alongside value-moving
   auction changes.
3. Implement `P0-AUCT-001` custody and state-machine changes.
4. Implement `P0-AUCT-002` bid-path reentrancy and outbid-credit changes.
5. Add the event catalog and external auction docs.
6. Run local and CI gates, including `make check`, Windows check wrapper, and
   targeted auction tests.
7. Include auction creation, bid, no-bid settlement, with-bid settlement, and
   cancellation in deployment rehearsal before public beta.

## Non-Goals

- Defining the full payment ledger API. That belongs to ADR 0003.
- Defining all admin roles, multisig setup, or pause ownership. That belongs to
  ADR 0004.
- Supporting batch auction drops in P0.
- Supporting seller-custody or approval-based auctions in P0.
- Supporting cancellation after the first valid bid in P0.
- Migrating production auctions from the legacy flow.

## Accepted Risks

- The exact withdrawal API remains open until ADR 0003.
- The exact admin actor for cancellation and pause remains open until ADR 0004.
- The implementation may need to rename or split the current auction contract.
- Gas costs for explicit auction records may be higher than the legacy mapping
  layout, but the added auditability is required for public beta.
- Auction-extension edge cases require implementation-specific tests once the
  final bid increment and extension rules are coded.
