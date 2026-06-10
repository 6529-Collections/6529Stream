# Tests

Foundry tests belong in this directory.

The initial characterization tests are intentionally self-contained and do not
depend on `forge-std`. They use small local assertion helpers, a minimal
cheatcode interface, fixtures, and mocks so `forge test -vvv` works from a
fresh checkout after the documented Foundry setup.

These tests lock current behavior before P0 rewrites and are converted into
target-state tests as individual roadmap fixes land. Some remaining asserted
behavior is known to be unsafe; those tests are regression tripwires and should
be updated only when the corresponding roadmap fix changes the intended
behavior.

Drop execution now has EIP-712 EOA target-state coverage in
`StreamDropsEIP712.t.sol` and ERC-1271 contract signer target-state coverage in
`StreamDropsERC1271.t.sol`.

Auction outbid refunds now have target-state coverage in
`StreamAuctionPayments.t.sol`: rejecting previous bidders cannot block higher
bids, previous bidders receive withdrawable credits, failed withdrawals preserve
credits, withdrawal reentrancy cannot overdraw credits, bid thresholds are
checked, and active bid escrow is protected from auction emergency surplus
withdrawals, including forced surplus withdrawal without draining owed balances.

Auction custody and settlement now have target-state coverage in
`StreamAuctionCustody.t.sol` and `StreamAuctionPayments.t.sol`: auction drops
mint custody to the auction contract, registered auctions expose status views,
no-bid settlement targets the signed poster, contract posters get a pending NFT
claim path, with-bid settlement atomically pairs final proceeds credits with
the NFT transfer, cancellation is pre-bid only, terminal auctions reject new
bids, and failed NFT transfers do not release escrow or create final proceeds
credits. Auction-local tests also cover no-bid pending-claim rollback to a
rejecting receiver, forced ETH surplus handling, and non-divisible proceeds
rounding.

Fixed-price payments now have target-state coverage in
`StreamFixedPricePayments.t.sol` and converted integration characterization
tests: paid fixed-price mints record poster, protocol, and curator-reserve
credits instead of pushing ETH during mint execution; rejecting poster, payout,
and curators-pool recipients cannot block minting; odd-wei and one-wei prices
account for every wei; free mints create no positive credits; failed poster or
protocol withdrawals preserve credits; withdrawal reentrancy cannot overdraw;
mint failure rolls back credits and consumed drop state; and forced ETH is
exposed only as `StreamDrops` surplus. Curator reserve remains accounted and
protected for later curator-claim work rather than ordinary recipient
withdrawal.

Curator reward claims now have target-state coverage in
`StreamCuratorsPool.t.sol`: valid Merkle claims create withdrawable curator
credits instead of pushing ETH to the reward address; duplicate and invalid
claims fail without increasing credit; delegated claims credit the delegator;
unfunded claims fail before consuming the Merkle claim;
rejecting reward recipients cannot block claim consumption; failed withdrawals
preserve credits; withdrawal reentrancy cannot overdraw; reward leaves use
`abi.encode`-based hashing; and curator pool emergency withdrawal can withdraw
only surplus over local curator credits owed, including forced surplus.

StreamMinter and randomizer emergency-withdrawal boundaries now have
target-state coverage in `StreamEmergencyWithdraw.t.sol`: `StreamMinter`
rejects ordinary ETH transfers, exposes `totalOwed() == 0`, reports forced ETH
as `emergencyWithdrawable()` surplus, and withdraws only that amount;
`NextGenRandomizerRNG` exposes its full balance as
`totalRandomnessReserved()`/`totalOwed()` and reports zero
emergency-withdrawable balance, including direct ETH, forced ETH, and
post-request remaining reserve.
