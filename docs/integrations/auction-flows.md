# English auctions

This describes `StreamEnglishAuctionHouse` with the permanent Core. It is
**pre-audit and not production-ready**. Earlier APIs remain in the
[legacy guide](../reference/legacy-stack/integrations/auction-flows.md).

## Create and custody

Use the [auction interface](../../smart-contracts/interfaces/stream/auctions/IStreamEnglishAuctionHouse.sol)
and [signing schema](wallets-and-signatures.md#auction-typed-data).
`createAuction(authorization, tokenData, platformSignature, artistSignature)`
verifies both signatures, accepted artist attribution, nonce, deadline, phase
policy and existing split profile, then mints one token into auction custody.
Anyone may submit valid consent. The returned `tokenId` identifies the auction;
Core ownership and the manager's returned identity are checked before recording it.
No auction exists if creation reverts.

Preflight `paused`, `platformSigner`, `signerEpoch`, `authorizationUsed`, artist
attribution, manager phase policy/executor permission, and split wallet. Simulate
the exact call. `AuctionCreated` binds token, artist, authorization, operation root
and wallet; `AuctionTerms` records economic and time settings.

## Bid and recipient

Read `auction(tokenId)`, `auctionStatus(tokenId)` and `minimumBid(tokenId)`.
Call `bid(tokenId, recipient)` with native ETH while `startTime <= now < endTime`.
The recipient must be nonzero. The first minimum is reserve price, or one wei if
reserve is zero. Later minimums add the configured percentage rounded upward:
`highestBid + ceil(highestBid * minBidIncrementBps / 10000)`.

A successful bid moves the previous bid into `refundCredit(previousBidder)`.
It does not push a refund. If remaining time is less than `extensionWindow`, the
deadline becomes `now + extensionWindow`; index the updated `endTime` from
`AuctionBidPlaced`, not the original terms alone.

The highest bidder may call `setDeliveryRecipient` before settlement. With no bid,
the artist controls that recipient. A recipient change does not change who owns
refund credit or who is the highest bidder.

## Settle, cancel and claim

After the deadline anyone may call `settle(tokenId)`. With a bid, settlement consumes
escrow accounting, pays the immutable split wallet and safe-transfers the NFT.
Failed payment or receiver callback reverts all of it. The bidder can set a valid
recipient and retry after a delivery failure.

With no bids, a contract delivery recipient produces `NoBidAuctionNFTClaimPending`:
the artist must explicitly call `claimNoBidNFT(tokenId, recipient)`. This avoids an
arbitrary settlement caller triggering that receiver callback. The token remains
in custody until a claim succeeds. An EOA no-bid recipient can receive during
ordinary settlement.

The artist may `cancel(tokenId)` (after setting `setDeliveryRecipient` if needed) before the deadline only with no bids.
Transfer must succeed for cancellation to complete. Creation nonces can also be
cancelled before use through `cancelAuthorization(nonce)`.

`auctionStatus` derives None, Created, Active, EndedNoBid, EndedWithBid,
SettledNoBid, SettledWithBid or Cancelled from time and stored state. An elapsed
deadline does not mean settlement has completed.

## Escrow and refunds

`totalBidEscrow` covers live winning bids; `totalRefundOwed` covers outbid credits.
`totalOwed()` is their sum. `surplus()` is excess balance, not another withdrawal
entitlement. An outbid bidder calls `withdrawRefund(recipient)` for its own credit;
failed native transfer preserves credit. Pause blocks new exposure while leaving
refunds and settlement exits available. Read [payments](withdrawals-and-credits.md)
for split proceeds after settlement.

Index address-filtered [events](events-and-indexing.md), support reorg rollback,
and reread status/credit at a pinned block. The [current tests](../../test/current/)
include cross-contract receiver, refund and settlement failures. These are not a
substitute for external audit or chain-specific operating evidence; see
[readiness](../release-readiness.md).
