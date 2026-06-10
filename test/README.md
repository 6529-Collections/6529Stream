# Tests

Foundry tests belong in this directory.

The initial characterization tests are intentionally self-contained and do not
depend on `forge-std`. They use small local assertion helpers, a minimal
cheatcode interface, fixtures, and mocks so `forge test -vvv` works from a
fresh checkout after the documented Foundry setup.

These tests lock current behavior before P0 rewrites and are converted into
target-state tests as individual roadmap fixes land. Some remaining asserted
behavior is known to be unsafe, such as synchronous fixed-price payouts; those
tests are regression tripwires and should be updated only when the corresponding
roadmap fix changes the intended behavior.

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
credits.
