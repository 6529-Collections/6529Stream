# ADR 0043: Deferred auction clocks and unpaid endings

Status: Accepted for autonomous full-v1 implementation, 14 September 2026.
Implementation and runtime acceptance remain open under issue 743. This decision
applies to the new versioned native auction; it does not reinterpret the deployed
RC1 auction, existing V2 signatures, or permanent mint operation hashes.

## Problem and scope

The [sales specification](../stream-sales-and-auctions.md) requires first-bid
clocks, bounded anti-snipe extensions, deferred minting, pause tolling and buyer
finalization envelopes. Three combinations need explicit behavior before the
new auction is implemented. The existing custody auction mints on creation and
has no deferred auction identity. Adding flags to its old signed tuple would
change what existing signatures authorize.

Keep that interface intact. The new auction has its own versioned interface,
sale configuration and pre-mint auction identity. Its deferred paid path must
prepare through the actual Mint Manager, record through the official settlement
boundary, and complete the original prepared token atomically. Direct adapter
funding followed by an unrelated prepared mint is insufficient. All remaining
sales, authorization, refund, reveal-fee, pause and delivery requirements apply.

## First accepted bid initializes the clock once

For `startOnFirstBid`, validate the required zero initial end, positive reserve
and bounded duration. The first reserve-valid bid at or after `startTime` sets
both the current end and original end to `block.timestamp + firstBidDuration`.
It emits one clock-start `AuctionExtended` event with previous end zero.

That transaction does not also apply an anti-snipe extension, even when the
configured anti-snipe window or extension exceeds the first-bid duration. The
special clock-start rule determines its exact end. Anti-snipe rules apply to
subsequent accepted bids, with the original end retained as the extension-budget
anchor. Pause tolling remains separate from that budget. Failed bids cannot
start the clock, consume auction authority or change escrow credits.

## A buyer-signed deadline remains an absolute ceiling

Store a participating buyer signature's original `finalizeBy` unchanged.
Track operational auction and finalization deadlines separately. Pause tolling
extends those operational clocks, including the elapsed portion of an ongoing
pause; it does not authorize settlement beyond the buyer's signed ceiling.

For a signed deferred leg, the effective settlement deadline is the earlier of
the tolled operational deadline and that original signed ceiling. Deadline
unlock becomes available strictly after the effective deadline; settlement is
allowed through it, subject to the other admission rules. Permissionless unlock
and all existing claims remain callable during pause. A terminal unlock cannot
be undone by unpausing, later bids, another signature or another settlement root.

If tolling moves the auction's bidding end beyond the winning buyer's signed
ceiling, that buyer's escrow can therefore unlock before the auction otherwise
ends. The affected deferred auction terminates without minting and returns the
full bid and saved reveal fee as pull credits. A replacement bid cannot reopen
it after terminal expiry; bid admission must check the expired winning envelope.

This explicitly qualifies [SSA-PAUSE] rule 3 where it overlaps an absolute
buyer-signed envelope: operational clocks toll, while [SSA-ENVELOPE] rules 2-5
continue to bound the buyer's authorization. Extending a signature by governance
or treating a paused auction as permanently unrefundable is not permitted.

A public bid with caller equal to payer and no per-buyer signature has no
separate signed ceiling. It binds the published finalization window and tolling
policy by construction, as required by [SSA-ENVELOPE] rule 6. The auction read
surface must expose the original signed ceiling, when present, and the effective
deadline separately. Neither is silently substituted in a signed preimage.

## A deferred auction with no bids creates no token

A preset-window deferred auction can end without ever receiving a valid bid.
Permissionless completion records a terminal no-mint outcome with explicit
`NO_BIDS` reason. It creates no token, revenue, buyer refund liability or NFT
claim. Repeated completion has no additional effect. Creation-time artist
approval is not authority for a free poster mint.

This qualifies [SSA-ENGLISH] rule 10 for the deferred branch, whose token does
not yet exist. The ordinary custody branch still delivers its existing token
to the poster or records the required pull claim. An unstarted first-bid auction
continues to have no expiry and remains cancellable under rule 14.

## Validation and rollout

Tests must cover the first-bid/long-anti-snipe combination, failed-bid rollback,
subsequent capped extensions, signed and public clocks, pause over each deadline,
expiry before the tolled bidding end, terminal replay, no-bid completion in both
custody modes, and full bid-plus-fee refunds. Use actual current contracts and
Safe callers where those accounts may hold the relevant role.

The paid prepared-mint increment must also prove atomic preparation, official
payment recording and completion, including callback and receiver failure,
reentrancy, exact replay identities and identical signed retries after repair.
Separate source and test evidence must establish that behavior before it is
marked implemented. No new numbered genesis role or artist operation is added.

These are bounded specification reconciliations. They do not close SALE-04,
complete the new auction interface, refresh release artifacts, or authorize a
new release candidate. The immutable RC1 release and deployment evidence remain
unchanged.
