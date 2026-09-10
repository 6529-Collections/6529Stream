# Payments and withdrawals

This is the current sale, auction and immutable split-wallet model, **pre-audit and
not production-ready**. Earlier poster/protocol/curator credits belong to the
[legacy guide](../reference/legacy-stack/integrations/withdrawals-and-credits.md).

## Sale proceeds

`StreamFixedPriceSaleAdapter.buy` pays the signed split wallet atomically with
minting. It does not leave proceeds as withdrawable credits in the sale adapter.
`nativeProceeds(profileId)` and `totalNativeProceeds` record official settlements;
a split wallet may separately receive unsolicited funds.

`StreamSplitFactory.createProfile(entries, metadataURIHash)` creates or reuses a
canonical profile and wallet. Entries contain account, `sharePpm` and `labelId`;
shares sum to 1,000,000 parts per million. Read `SHARE_DENOMINATOR_PPM`, canonical
entries and aggregated account shares rather than assuming input order survives.
The profile is immutable. Changing a split requires a new profile and signatures
binding its ID.

## Release split funds

Resolve `factory.walletFor(profileId)` and check `splitWalletExists(profileId)`.
Use `address(0)` for native ETH:

```solidity
uint256 amount = wallet.releasable(address(0), account);
if (amount != 0) {
    wallet.release(address(0), account, payable(account));
}
```

Anyone can sponsor release **to the account itself**. Redirecting requires
`msg.sender == account`; an unrelated caller cannot choose a different destination.
Release accounting is consumed before payment and reverts if payment fails. A
contract account with a rejecting receiver can invoke release to another destination.

`releasable`, `observedReceived` and `roundingDust` describe accounting at that block.
Use integer calculations; rounding dust is not a UI-derived entitlement.
`NativeReleased` and `ERC20Released` confirm withdrawals. ERC-20 release also obeys
asset policy; it does not mean the native sale accepts ERC-20 payment.

## Auction escrow and refunds

The highest bid remains in `totalBidEscrow`. An outbid amount moves to
`refundCredit(bidder)` and `totalRefundOwed`. The bidder calls
`withdrawRefund(recipient)` for its own credit. Credit is zeroed before the call;
failed payment reverts and preserves credit. A new recipient can be used on retry.
Refund exits remain available while new auctions/bids are paused.

Successful settlement moves the winning amount to the signed split wallet; its
accounts then release as above. Refunds and split releases do not change NFT
ownership. `totalOwed()` is bid escrow plus refunds; `surplus()` is excess balance,
not an entitlement for arbitrary callers.

## Client reconciliation

Display amounts from pinned-block reads, simulate release, and confirm a successful
address-filtered receipt. Reconcile after reorgs or concurrent withdrawals. Failed
withdrawal is not lost balance; a stale UI amount does not promise success.

Source: [wallet](../../smart-contracts/interfaces/stream/revenue/IStreamSplitWallet.sol),
[factory](../../smart-contracts/interfaces/stream/revenue/IStreamSplitFactory.sol),
[auction](../../smart-contracts/interfaces/stream/auctions/IStreamEnglishAuctionHouse.sol).
See [events](events-and-indexing.md), [purchase](contract-flows.md),
[auctions](auction-flows.md) and [readiness](../release-readiness.md).
