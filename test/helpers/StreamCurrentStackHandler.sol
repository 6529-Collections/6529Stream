// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../smart-contracts/core/StreamCore.sol";
import "../../smart-contracts/domains/mint/StreamMintManager.sol";
import "../../smart-contracts/domains/mint/StreamFixedPriceSaleAdapter.sol";
import "../../smart-contracts/domains/mint/StreamERC20FixedPriceSaleAdapter.sol";
import "../../smart-contracts/domains/auctions/StreamEnglishAuctionHouse.sol";
import "../../smart-contracts/interfaces/stream/revenue/IStreamSplitWallet.sol";
import "../mocks/MockStreamPaymentToken.sol";

contract InvariantRejectingReceiver is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        revert("invariant receiver rejects");
    }
}

/// @notice Bounded real-product actions and an independent conservation/ownership model.
/// @dev Keys, ERC20 funding and time changes are test controls; no production policy is bypassed.
contract StreamCurrentStackHandler is CharacterizationTestBase {
    struct Config {
        StreamCore core;
        StreamMintManager manager;
        StreamFixedPriceSaleAdapter nativeSale;
        StreamERC20FixedPriceSaleAdapter erc20Sale;
        StreamEnglishAuctionHouse auction;
        MockStreamPaymentToken token;
        address wallet;
        address artist;
        address protocol;
        bytes32 profile;
        bytes32 saleId;
        uint256 supplyLimit;
    }

    struct AuctionModel {
        uint256 tokenId;
        uint64 endTime;
        uint256 highestBid;
        address highestBidder;
        bool settled;
    }
    uint256 private constant ARTIST_KEY = 0xA47157;
    uint256 private constant PLATFORM_KEY = 0x6529;
    uint256 private constant ACTOR_KEY = 0xC011EC70;
    uint256 private constant INITIAL_TOKENS = 1_000_000;
    bytes32 private constant NATIVE_PHASE = keccak256("current-stack fixed price");
    bytes32 private constant AUCTION_PHASE = keccak256("current-stack auction");
    bytes private constant DATA = "stateful current-stack artwork";
    Config private system;
    address[3] private actors;
    InvariantRejectingReceiver private rejector;
    AuctionModel[] private auctions;
    mapping(uint256 => address) private owners;
    mapping(address => uint256) private refunds;
    uint256[2] private nativeReleased;
    uint256[2] private erc20Released;
    uint256[3] private actorTokenSpent;
    uint256 private nextConsent = 1;
    bytes private nativeReplay;
    address private nativeReplayPayer;
    bytes32 private nativeReplayNonce;
    uint256 private nativeReplayPrice;
    bytes private erc20Replay;
    address private erc20ReplayPayer;
    bytes32 private erc20ReplayNonce;

    uint256 public steps;
    uint256 public nativeBuys;
    uint256 public erc20Buys;
    uint256 public auctionCreates;
    uint256 public bids;
    uint256 public refundWithdrawals;
    uint256 public settlements;
    uint256 public nativeReleases;
    uint256 public erc20Releases;
    uint256 public transfers;
    uint256 public nativeReplayChecks;
    uint256 public erc20ReplayChecks;
    uint256 public rollbackChecks;
    uint256 public nativeRevenue;
    uint256 public auctionRevenue;
    uint256 public erc20Revenue;
    uint256 public bidDeposits;
    uint256 public refundPayments;
    uint256 public minted;

    constructor(Config memory config) {
        system = config;
        rejector = new InvariantRejectingReceiver();
        for (uint256 i; i < actors.length; ++i) {
            actors[i] = vm.addr(ACTOR_KEY + i);
            vm.deal(actors[i], 1000 ether);
            config.token.mint(actors[i], INITIAL_TOKENS);
            vm.prank(actors[i]);
            config.token.approve(address(config.erc20Sale), type(uint256).max);
        }
    }

    /// @dev The first twelve fuzzed inputs exercise each dependency in order. Later choices
    ///      are randomized. State-dependent alternatives perform a valid operation, never catch
    ///      an arbitrary revert. Replay/receiver failures are explicitly asserted below.
    function step(uint256 seed) external {
        uint256 action = steps < 12 ? steps : seed % 12;
        ++steps;
        if (action == 0) _nativeBuy(seed);
        else if (action == 1) _erc20Buy(seed);
        else if (action == 2) _createAuction(seed);
        else if (action == 3 || action == 4) _bid(seed);
        else if (action == 5) _refund(seed);
        else if (action == 6) _settle(seed);
        else if (action == 7) _release();
        else if (action == 8) _transfer(seed);
        else if (action == 9) _replay(false);
        else if (action == 10) _replay(true);
        else _rejectReceiver(seed);
    }

    function _primaryPolicyHash() private view returns (bytes32 hash) {
        (hash,,) = system.nativeSale.primaryPolicy(1);
    }

    function _sign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _recordMint(uint256 tokenId, address owner) private {
        require(tokenId == minted + 1, "nonsequential mint identity");
        ++minted;
        owners[tokenId] = owner;
    }

    function _nativeBuy(uint256 seed) private {
        if (minted == system.supplyLimit) {
            _transfer(seed);
            return;
        }
        address payer = actors[seed % 3];
        uint256 price = 10_000 + (seed % 10_000) * 10;
        bytes32 nonce = bytes32(nextConsent++);
        (bytes32 primaryPolicy,,) = system.nativeSale.primaryPolicy(1);
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory auth =
            IStreamFixedPriceSaleAdapter.SaleAuthorization(
                1,
                NATIVE_PHASE,
                payer,
                payer,
                system.artist,
                system.profile,
                primaryPolicy,
                keccak256(DATA),
                keccak256(abi.encode("native", nonce)),
                system.manager.phasePolicyHash(1, NATIVE_PHASE),
                price,
                nonce,
                type(uint64).max,
                system.nativeSale.signerEpoch()
            );
        bytes32 digest = system.nativeSale.authorizationDigest(auth);
        bytes memory payload = abi.encodeCall(
            system.nativeSale.buy,
            (auth, DATA, _sign(PLATFORM_KEY, digest), _sign(ARTIST_KEY, digest))
        );
        vm.prank(payer);
        (bool ok, bytes memory returned) = address(system.nativeSale).call{ value: price }(payload);
        if (!ok) assembly ("memory-safe") { revert(add(returned, 32), mload(returned)) }
        (uint256 tokenId, bytes32 root) = abi.decode(returned, (uint256, bytes32));
        require(system.manager.isOperationRootUsed(root), "native root not consumed");
        _recordMint(tokenId, payer);
        nativeRevenue += price;
        ++nativeBuys;
        nativeReplay = payload;
        nativeReplayPayer = payer;
        nativeReplayNonce = nonce;
        nativeReplayPrice = price;
    }

    function _erc20Payload(uint256 actorIndex, address recipient, bytes32 nonce)
        private
        returns (bytes memory)
    {
        IStreamERC20FixedPriceSaleAdapter.SaleRecord memory record =
            system.erc20Sale.saleRecord(system.saleId);
        IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory auth =
            IStreamERC20FixedPriceSaleAdapter.SaleAuthorization(
                system.saleId,
                record.configHash,
                actors[actorIndex],
                recipient,
                system.artist,
                keccak256(DATA),
                keccak256(abi.encode("erc20", nonce)),
                nonce,
                type(uint64).max,
                system.erc20Sale.signerEpoch()
            );
        IStreamPaymentIntentVerifier.PaymentIntent memory intent =
            IStreamPaymentIntentVerifier.PaymentIntent(
                actors[actorIndex],
                address(system.token),
                100,
                system.saleId,
                record.config.expectedPrimaryPolicyHash,
                nonce,
                type(uint64).max
            );
        bytes32 digest = system.erc20Sale.authorizationDigest(auth);
        return abi.encodeCall(
            system.erc20Sale.buy,
            (
                auth,
                DATA,
                _sign(PLATFORM_KEY, digest),
                _sign(ARTIST_KEY, digest),
                intent,
                _sign(ACTOR_KEY + actorIndex, system.erc20Sale.paymentIntentDigest(intent))
            )
        );
    }

    function _erc20Buy(uint256 seed) private {
        if (minted == system.supplyLimit) {
            _transfer(seed);
            return;
        }
        uint256 index = seed % 3;
        bytes32 nonce = bytes32(nextConsent++);
        bytes memory payload = _erc20Payload(index, actors[index], nonce);
        // The handler is the relayer; the payer's separate intent is mandatory.
        (bool ok, bytes memory returned) = address(system.erc20Sale).call(payload);
        if (!ok) assembly ("memory-safe") { revert(add(returned, 32), mload(returned)) }
        (uint256 tokenId, bytes32 root) = abi.decode(returned, (uint256, bytes32));
        require(system.manager.isOperationRootUsed(root), "ERC20 root not consumed");
        require(
            system.erc20Sale.isPaymentIntentNonceUsed(actors[index], nonce), "intent not consumed"
        );
        _recordMint(tokenId, actors[index]);
        erc20Revenue += 100;
        actorTokenSpent[index] += 100;
        ++erc20Buys;
        erc20Replay = payload;
        erc20ReplayPayer = actors[index];
        erc20ReplayNonce = nonce;
    }

    function _createAuction(uint256 seed) private {
        if (minted == system.supplyLimit) {
            _transfer(seed);
            return;
        }
        bytes32 nonce = bytes32(nextConsent++);
        IStreamEnglishAuctionHouse.AuctionAuthorization memory auth =
            IStreamEnglishAuctionHouse.AuctionAuthorization(
                1,
                AUCTION_PHASE,
                system.artist,
                system.profile,
                _primaryPolicyHash(),
                keccak256(DATA),
                keccak256(abi.encode("auction", nonce)),
                system.manager.phasePolicyHash(1, AUCTION_PHASE),
                10_000,
                uint64(block.timestamp),
                uint64(block.timestamp + 1 hours),
                0,
                1000,
                nonce,
                type(uint64).max,
                system.auction.signerEpoch()
            );
        bytes32 digest = system.auction.authorizationDigest(auth);
        uint256 tokenId = system.auction
            .createAuction(auth, DATA, _sign(PLATFORM_KEY, digest), _sign(ARTIST_KEY, digest));
        _recordMint(tokenId, address(system.auction));
        auctions.push(AuctionModel(tokenId, auth.endTime, 0, address(0), false));
        ++auctionCreates;
    }

    function _activeAuction(uint256 seed, bool includeEnded) private view returns (uint256) {
        if (auctions.length == 0) return type(uint256).max;
        for (uint256 n; n < auctions.length; ++n) {
            uint256 index = (seed % auctions.length + n) % auctions.length;
            if (
                !auctions[index].settled
                    && (includeEnded || block.timestamp < auctions[index].endTime)
            ) return index;
        }
        return type(uint256).max;
    }

    function _bid(uint256 seed) private {
        uint256 index = _activeAuction(seed, false);
        if (index == type(uint256).max) {
            if (minted == system.supplyLimit) {
                _transfer(seed);
                return;
            }
            _createAuction(seed);
            index = auctions.length - 1;
        }
        AuctionModel storage item = auctions[index];
        uint256 bidderIndex = seed % 3;
        if (actors[bidderIndex] == item.highestBidder) bidderIndex = (bidderIndex + 1) % 3;
        address bidder = actors[bidderIndex];
        uint256 amount =
            item.highestBid == 0 ? 10_000 : item.highestBid + (item.highestBid + 9) / 10;
        amount += (seed >> 16) % 101;
        vm.prank(bidder);
        system.auction.bid{ value: amount }(item.tokenId, bidder);
        if (item.highestBid != 0) refunds[item.highestBidder] += item.highestBid;
        item.highestBid = amount;
        item.highestBidder = bidder;
        bidDeposits += amount;
        ++bids;
    }

    function _refund(uint256 seed) private {
        for (uint256 n; n < actors.length; ++n) {
            address account = actors[(seed % 3 + n) % 3];
            uint256 amount = refunds[account];
            if (amount == 0) continue;
            uint256 beforeBalance = account.balance;
            vm.prank(account);
            system.auction.withdrawRefund(payable(account));
            require(account.balance == beforeBalance + amount, "refund amount");
            refunds[account] = 0;
            refundPayments += amount;
            ++refundWithdrawals;
            return;
        }
        _bid(seed);
    }

    function _settle(uint256 seed) private {
        uint256 index = _activeAuction(seed, true);
        if (index == type(uint256).max) {
            if (minted == system.supplyLimit) {
                _transfer(seed);
                return;
            }
            _createAuction(seed);
            index = auctions.length - 1;
        }
        AuctionModel storage item = auctions[index];
        if (block.timestamp < item.endTime) vm.warp(item.endTime);
        system.auction.settle(item.tokenId);
        item.settled = true;
        owners[item.tokenId] = item.highestBid == 0 ? system.artist : item.highestBidder;
        auctionRevenue += item.highestBid;
        ++settlements;
    }

    function _release() private {
        IStreamSplitWallet split = IStreamSplitWallet(system.wallet);
        for (uint256 i; i < 2; ++i) {
            address account = i == 0 ? system.artist : system.protocol;
            uint256 share = i == 0 ? 9 : 1;
            uint256 nativeDue = (nativeRevenue + auctionRevenue) * share / 10 - nativeReleased[i];
            if (nativeDue != 0) {
                uint256 beforeBalance = account.balance;
                split.release(address(0), account, payable(account));
                require(account.balance == beforeBalance + nativeDue, "native split payment");
                nativeReleased[i] += nativeDue;
                ++nativeReleases;
            }
            uint256 tokenDue = erc20Revenue * share / 10 - erc20Released[i];
            if (tokenDue != 0) {
                uint256 beforeBalance = system.token.rawBalance(account);
                split.release(address(system.token), account, payable(account));
                require(
                    system.token.rawBalance(account) == beforeBalance + tokenDue,
                    "ERC20 split payment"
                );
                erc20Released[i] += tokenDue;
                ++erc20Releases;
            }
        }
    }

    function _transfer(uint256 seed) private {
        for (uint256 n; n < minted; ++n) {
            uint256 tokenId = (seed % minted + n) % minted + 1;
            address from = owners[tokenId];
            if (from == address(system.auction)) continue;
            address to = actors[seed % 3];
            if (to == from) to = actors[(seed % 3 + 1) % 3];
            vm.prank(from);
            system.core.transferFrom(from, to, tokenId);
            owners[tokenId] = to;
            ++transfers;
            return;
        }
    }

    function _fingerprint(address payer, bytes32 nonce) private view returns (bytes32) {
        bytes32 mintState = keccak256(
            abi.encode(
                system.core.totalSupply(),
                system.core.lastAllocatedTokenId(),
                system.core.collectionMintedEver(1),
                system.manager.nextOperationNonce()
            )
        );
        bytes32 paymentState = keccak256(
            abi.encode(
                address(system.nativeSale).balance,
                system.wallet.balance,
                payer.balance,
                system.token.rawBalance(payer),
                system.token.rawBalance(system.wallet),
                system.token.rawBalance(address(system.erc20Sale)),
                system.token.transferCalls(),
                system.token.allowance(payer, address(system.erc20Sale)),
                system.nativeSale.totalNativeProceeds(),
                system.erc20Sale.totalProceeds(address(system.token))
            )
        );
        bytes32 consentState = keccak256(
            abi.encode(
                system.nativeSale.authorizationUsed(system.artist, nonce),
                system.erc20Sale.authorizationUsed(system.artist, nonce),
                system.erc20Sale.isPaymentIntentNonceUsed(payer, nonce)
            )
        );
        return keccak256(abi.encode(mintState, paymentState, consentState));
    }

    function _replay(bool erc20) private {
        bytes memory payload = erc20 ? erc20Replay : nativeReplay;
        if (payload.length == 0) {
            if (erc20) _erc20Buy(steps);
            else _nativeBuy(steps);
            return;
        }
        address payer = erc20 ? erc20ReplayPayer : nativeReplayPayer;
        bytes32 nonce = erc20 ? erc20ReplayNonce : nativeReplayNonce;
        bytes32 beforeState = _fingerprint(payer, nonce);
        bool ok;
        bytes memory reason;
        if (erc20) {
            (ok, reason) = address(system.erc20Sale).call(payload);
        } else {
            vm.prank(payer);
            (ok, reason) = address(system.nativeSale).call{ value: nativeReplayPrice }(payload);
        }
        bytes4 selector = erc20
            ? IStreamERC20FixedPriceSaleAdapter.SaleAuthorizationUsed.selector
            : IStreamFixedPriceSaleAdapter.SaleAlreadyConsumed.selector;
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSelector(selector, system.artist, nonce)),
            "replay reached wrong rejection"
        );
        require(_fingerprint(payer, nonce) == beforeState, "replay changed protocol/payment state");
        if (erc20) ++erc20ReplayChecks;
        else ++nativeReplayChecks;
    }

    function _rejectReceiver(uint256 seed) private {
        if (minted == system.supplyLimit) {
            _replay(true);
            return;
        }
        uint256 index = seed % 3;
        bytes32 nonce = bytes32(nextConsent++);
        bytes memory payload = _erc20Payload(index, address(rejector), nonce);
        bytes32 beforeState = _fingerprint(actors[index], nonce);
        (bool ok, bytes memory reason) = address(system.erc20Sale).call(payload);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSignature("Error(string)", "invariant receiver rejects")
                    ),
            "receiver rollback reached wrong rejection"
        );
        require(
            _fingerprint(actors[index], nonce) == beforeState,
            "receiver failure changed protocol/payment state"
        );
        ++rollbackChecks;
    }

    function assertInvariants() external view {
        require(
            system.core.totalSupply() == minted && system.core.collectionMintedEver(1) == minted
                && system.core.lastAllocatedTokenId() == minted
                && system.core.totalSupplyOfCollection(1) == minted,
            "supply conservation"
        );
        require(
            system.manager.nextOperationNonce() == minted && minted <= system.supplyLimit,
            "mint nonce or supply cap"
        );
        for (uint256 id = 1; id <= minted; ++id) {
            require(system.core.ownerOf(id) == owners[id], "ownership model");
        }
        uint256 escrow;
        for (uint256 i; i < auctions.length; ++i) {
            AuctionModel storage expected = auctions[i];
            IStreamEnglishAuctionHouse.Auction memory actual =
                system.auction.auction(expected.tokenId);
            require(
                actual.highestBid == expected.highestBid
                    && actual.highestBidder == expected.highestBidder
                    && actual.settled == expected.settled,
                "auction model"
            );
            if (!expected.settled) escrow += expected.highestBid;
        }
        uint256 refundTotal;
        uint256 actorTokens;
        for (uint256 i; i < actors.length; ++i) {
            refundTotal += refunds[actors[i]];
            uint256 actualActorTokens = system.token.rawBalance(actors[i]);
            require(
                actualActorTokens == INITIAL_TOKENS - actorTokenSpent[i], "intended payer debit"
            );
            actorTokens += actualActorTokens;
            require(system.auction.refundCredit(actors[i]) == refunds[actors[i]], "refund ledger");
        }
        require(
            system.auction.totalBidEscrow() == escrow
                && system.auction.totalRefundOwed() == refundTotal
                && address(system.auction).balance == escrow + refundTotal,
            "auction solvency"
        );
        require(
            bidDeposits == escrow + refundTotal + refundPayments + auctionRevenue,
            "bid conservation"
        );
        require(
            system.nativeSale.totalNativeProceeds() == nativeRevenue
                && system.auction.totalNativeProceeds() == auctionRevenue
                && system.erc20Sale.totalProceeds(address(system.token)) == erc20Revenue,
            "official proceeds model"
        );
        uint256 nReleased = nativeReleased[0] + nativeReleased[1];
        uint256 eReleased = erc20Released[0] + erc20Released[1];
        require(
            system.wallet.balance + nReleased == nativeRevenue + auctionRevenue,
            "native revenue conservation"
        );
        require(
            system.token.rawBalance(system.wallet) + eReleased == erc20Revenue,
            "ERC20 revenue conservation"
        );
        require(
            actorTokens + erc20Revenue == INITIAL_TOKENS * actors.length, "payer ERC20 conservation"
        );
        require(
            address(system.nativeSale).balance == 0
                && system.token.rawBalance(address(system.erc20Sale)) == 0,
            "adapter retained proceeds"
        );
        IStreamSplitWallet split = IStreamSplitWallet(system.wallet);
        require(
            split.totalReleased(address(0)) == nReleased
                && split.totalReleased(address(system.token)) == eReleased,
            "split totals"
        );
        for (uint256 i; i < 2; ++i) {
            address account = i == 0 ? system.artist : system.protocol;
            require(
                split.accountReleased(address(0), account) == nativeReleased[i]
                    && split.accountReleased(address(system.token), account) == erc20Released[i],
                "split account model"
            );
        }
    }

    function assertCampaignActivity() external view {
        require(
            steps >= 12 && nativeBuys > 0 && erc20Buys > 0 && auctionCreates > 0 && bids >= 2
                && refundWithdrawals > 0 && settlements > 0 && nativeReleases > 0
                && erc20Releases > 0 && transfers > 0 && nativeReplayChecks > 0
                && erc20ReplayChecks > 0 && rollbackChecks > 0,
            "campaign lacked required successful activity"
        );
    }
}
