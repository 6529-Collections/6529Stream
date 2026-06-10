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

Admin permission tests now include P0-ADMIN-001 target-state coverage in
`StreamAdminSelectors.t.sol` and `StreamAdmins.t.sol`: function-admin grants are
scoped by account, target contract, and selector; wrong selectors and same
selectors on another target do not authorize mutation; revoked grants fail;
owner/root role management does not make the owner an implicit operational
admin; unsupported collection-admin lookups return false; and global-admin
bypass remains explicit.

Pause and emergency-control tests now include P0-ADMIN-002 target-state
coverage in `StreamPauseControls.t.sol` and `StreamEmergencyWithdraw.t.sol`:
pause guardians can pause but cannot unpause, unpause admins can unpause but
cannot pause, drop execution, minting, auction bids, auction settlement,
metadata mutation, and randomness requests each have domain-specific pause
guards, operational pauses do not block user credit withdrawals, and emergency
withdrawals use the explicit `StreamAdmins.emergencyRecipient()` while keeping
the existing surplus/reserve boundaries intact. The pause suite also covers the
current signer-compromise response path by pausing drop execution, incrementing
the signer epoch, cancelling the exposed drop ID, unpausing, and proving the
stale payload cannot mint.

Randomizer request lifecycle and callback validation now have P0-RAND-001
target-state coverage in `StreamRandomizerLifecycle.t.sol`: VRF and arRNG
requests record collection, token, provider, provider request ID, epoch,
timestamps, and state; request records and states are viewable by request ID and
token ID; token-level views expose empty, pending, fulfilled, and stale state;
valid callbacks write exactly one derived seed and one canonical raw-output hash;
unknown, empty, duplicate, wrong-collection, stale-provider, and stale-epoch
callbacks fail closed; zero arRNG request IDs fail before lifecycle state is
recorded; post-request token-data mutation does not affect the stored seed or
raw-output hash; manual stale marking is observable; failed deterministic core
post-processing records `FailedPostProcessing`, stores the derived seed,
raw-output hash, and failure-data hash, clears pending counts, emits a failure
event with provider, epoch, seed, and raw-output hash context, fulfillment
events include the same provider and epoch context, VRF and arRNG adapters both
emit provider-specific raw-word fulfillment events, lifecycle interface views
expose request records and raw-output hashes, stale requests keep a zero
raw-output hash, and duplicate callbacks are rejected for both VRF and arRNG
adapters; randomness-request pauses do not block valid fulfillment; a reentrant
arRNG controller cannot fulfill during request submission; and ordinary
randomizer migration is blocked while VRF or arRNG adapters report pending
requests, then allowed after fulfillment or explicit stale marking.
`RandomizerNXT` cannot be configured as a production randomizer, and the
concrete weak `XRandoms` helper contract has been removed from production
source while tests retain only an inline mock helper for the legacy boundary.

Randomizer deterministic retry now has P0-RAND-006 target-state coverage in
`StreamRandomizerRetry.t.sol`: failed VRF and arRNG post-processing can be
manually retried by an authorized admin using the stored derived seed and
raw-output hash, successful retry emits retry and fulfillment events while
refreshing fulfillment timing, retry success's fulfillment event is documented as
a retry confirmation rather than a second provider callback, retry failure emits
only the retry-specific failure event, repeated deterministic failures remain bounded by
`MAX_RANDOMNESS_POST_PROCESSING_RETRIES`, unauthorized retry fails, terminal
fulfillment cannot be retried, and changed token-to-collection, provider, or
epoch bindings fail before retry state changes in both adapters.

Dependency script encoding now has P0-META-001 target-state coverage in
`StreamMetadataEncoding.t.sol`: ambiguous chunk boundaries that render the same
dependency JavaScript produce distinct typed content hashes, chunk hashes include
the chunk index and byte length, zero-chunk dependency hashes are deterministic,
and the existing rendered generative script output remains
compatibility-preserving.

Mint-accounting state now has P0-CORE-001 target-state coverage in
`StreamMintAccounting.t.sol`: never-written public/allowlist mint counters were
removed from `StreamCore`, while the retained airdrop counter starts at zero,
increments on authorized minter calls, and remains unchanged after an
unauthorized mint attempt.

Explicit local initialization now has P0-INIT-001 target-state coverage in
`StreamInitialization.t.sol`: Bytes32 character counts, missing and matching
delegation status lookups, subdelegation register/revoke gates, empty-script
generative rendering, and multi-recipient minter return indexes cover the former
first-party production `uninitialized-local` rows.

Vendored library provenance now has P0-LIB-001 coverage in
`StreamVendoredLibraries.t.sol`: Base64 golden vectors, binary padding,
`Math.mulDiv` full-precision boundaries, rounding-up behavior, overflow, and
zero-denominator reverts cover the OpenZeppelin utility-library rows documented
as false positives in `docs/vendored-libraries.md` and `ops/SLITHER_BASELINE.md`.
