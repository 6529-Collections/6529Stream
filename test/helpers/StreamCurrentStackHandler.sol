// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../smart-contracts/core/StreamCore.sol";
import { StreamMintManager } from "../../smart-contracts/domains/mint/StreamMintManager.sol";
import "../../smart-contracts/domains/mint/StreamFixedPriceSaleAdapter.sol";
import "../../smart-contracts/domains/mint/StreamERC20FixedPriceSaleAdapter.sol";
import "../../smart-contracts/domains/auctions/StreamEnglishAuctionHouse.sol";
import {
    StreamEntropyCoordinator
} from "../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";
import {
    StreamEntropyStatus
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyView.sol";
import { StreamRevenueEscrow } from "../../smart-contracts/domains/revenue/StreamRevenueEscrow.sol";
import "../../smart-contracts/interfaces/stream/revenue/IStreamSplitWallet.sol";
import "../mocks/MockStreamPaymentToken.sol";
import "./OfficialSafeFixture.sol";
import "../../smart-contracts/interfaces/stream/metadata/IStreamConservationFloor.sol";
import "../../smart-contracts/interfaces/stream/metadata/IStreamDirectPrimaryConservationFloor.sol";
import "../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";
import {
    StreamDirectPrimarySaleTypes as ModelDirect
} from "../../smart-contracts/interfaces/stream/revenue/StreamDirectPrimarySaleTypes.sol";

interface StatefulConservationGovernor {
    function statefulSetNativeSalePaused(bool value) external;
}

contract InvariantRejectingReceiver is IERC721Receiver {
    address private immutable controller = msg.sender;
    bool private accepting;

    function setAccepting(bool value) external {
        require(msg.sender == controller, "receiver controller");
        accepting = value;
    }

    function deliver(StreamCore core, uint256 tokenId, address recipient) external {
        require(msg.sender == controller, "receiver controller");
        core.transferFrom(address(this), recipient, tokenId);
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        view
        returns (bytes4)
    {
        require(accepting, "invariant receiver rejects");
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice Bounded real-product actions and an independent conservation/ownership model.
/// @dev Keys, ERC20 funding and time changes are test controls; no production policy is bypassed.
contract StreamCurrentStackHandler is CharacterizationTestBase, OfficialSafeFixture {
    struct Config {
        StreamCore core;
        StreamMintManager manager;
        StreamEntropyCoordinator entropy;
        StreamRevenueEscrow revenueEscrow;
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
        IStreamConservationFloor floor;
        StatefulConservationGovernor governorHost;
    }

    struct AuctionModel {
        uint256 tokenId;
        uint64 endTime;
        uint256 highestBid;
        address highestBidder;
        bool settled;
        bytes32 authorizationId;
    }
    uint256 private constant ARTIST_KEY = 0xA47157;
    uint256 private constant PLATFORM_KEY = 0x6529;
    uint256 private constant ACTOR_KEY = 0xC011EC70;
    uint256 private constant INITIAL_TOKENS = 1_000_000;
    uint256 private constant INITIAL_NATIVE = 1000 ether;
    bytes32 private constant NATIVE_PHASE = keccak256("current-stack fixed price");
    bytes32 private constant ERC20_PHASE = keccak256("stateful ERC20 phase");
    bytes32 private constant AUCTION_PHASE = keccak256("current-stack auction");
    bytes private constant DATA = "stateful current-stack artwork";
    Config private system;
    address[4] private actors;
    OfficialSafe private payerSafe;
    uint256[] private payerSafeKeys;
    uint256 private safeCalls;
    mapping(bytes32 => ModelDirect.Receipt) private expectedSales;
    mapping(bytes32 => bytes32) private originalNonces;
    mapping(bytes32 => address) private originalProducts;
    bytes32[] private payerIntentNonces;
    address[] private payerIntentAccounts;
    bool[] private payerIntentConsumed;
    address[] private receiptAdapters;
    bytes32[] private receiptIds;
    bytes32[] private floorTupleHashes;
    bytes32 private firstSaleTupleHash;
    bytes32 private firstSaleReceiptHash;
    uint256 public safeNativeBuys;
    uint256 public safeERC20Buys;
    uint256 public burned;
    uint256 public pauseRetries;
    uint256 public noBidSettlements;
    uint256 public erc20RollbackRetries;
    uint256 public randomizedSteps;
    mapping(uint256 => uint256) public actionCalls;
    bytes32 private constant WAIVED = keccak256("CONSERVATION_WAIVED");
    uint256 public constant OPENING_ACTIONS = 20;
    InvariantRejectingReceiver private rejector;
    AuctionModel[] private auctions;
    mapping(uint256 => address) private owners;
    mapping(address => uint256) private refunds;
    uint256[2] private nativeReleased;
    uint256[2] private erc20Released;
    uint256[4] private actorTokenSpent;
    mapping(address => uint256) private actorNativeSpent;
    mapping(address => uint256) private actorNativeRefunded;
    uint256[2] private beneficiaryNativeBefore;
    uint256[2] private beneficiaryTokensBefore;
    bytes32[] private consumedAuthorizations;
    bytes32[] private cancelledNativeNonces;
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
    uint256 public nativeRollbackRetries;
    uint256 public wrongCancellationChecks;
    uint256 public artistCancellationChecks;
    uint256 public nativeRevenue;
    uint256 public auctionRevenue;
    uint256 public erc20Revenue;
    uint256 public bidDeposits;
    uint256 public refundPayments;
    uint256 public minted;

    constructor(Config memory config) {
        system = config;
        rejector = new InvariantRejectingReceiver();
        SafeComponents memory components = deploySafeComponents("1.4.1");
        uint256[] memory keys = new uint256[](3);
        keys[0] = 0x57A7EF01;
        keys[1] = 0x57A7EF02;
        keys[2] = 0x57A7EF03;
        payerSafeKeys.push(keys[0]);
        payerSafeKeys.push(keys[1]);
        payerSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 0x57A7E);
        for (uint256 i; i < actors.length; ++i) {
            actors[i] = i == 3 ? address(payerSafe) : vm.addr(ACTOR_KEY + i);
            vm.deal(actors[i], INITIAL_NATIVE);
            config.token.mint(actors[i], INITIAL_TOKENS);
            if (i == 3) {
                _safeCall(
                    address(config.token),
                    0,
                    abi.encodeCall(
                        config.token.approve, (address(config.erc20Sale), type(uint256).max)
                    )
                );
            } else {
                vm.prank(actors[i]);
                config.token.approve(address(config.erc20Sale), type(uint256).max);
            }
        }
        beneficiaryNativeBefore[0] = config.artist.balance;
        beneficiaryNativeBefore[1] = config.protocol.balance;
        beneficiaryTokensBefore[0] = config.token.rawBalance(config.artist);
        beneficiaryTokensBefore[1] = config.token.rawBalance(config.protocol);
    }

    /// @dev Retains the original fifteen opening actions, then exercises five new transitions.
    ///      Later choices are randomized across all twenty. State-dependent alternatives perform a valid operation, never catch
    ///      an arbitrary revert. Replay/receiver failures are explicitly asserted below.
    function step(uint256 seed) external {
        uint256 progressBefore = _completedActions();
        uint256 action = steps < OPENING_ACTIONS ? steps : seed % OPENING_ACTIONS;
        if (steps >= OPENING_ACTIONS) ++randomizedSteps;
        ++steps;
        ++actionCalls[action];
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
        else if (action == 11) _rejectReceiver(seed);
        else if (action == 12) _nativeReceiverRetry(seed);
        else if (action == 13) _wrongCancellation(seed);
        else if (action == 14) _artistCancellation(seed);
        else if (action == 15) _safeNativeBuy(seed);
        else if (action == 16) _safeERC20Buy(seed);
        else if (action == 17) _burn(seed);
        else if (action == 18) _pauseAndRetry(seed);
        else _settleNoBid(seed);
        require(_completedActions() > progressBefore, "handler action made no checked progress");
        _assertFloorHistory();
    }

    function _completedActions() private view returns (uint256) {
        return nativeBuys + erc20Buys + auctionCreates + bids + refundWithdrawals + settlements
            + nativeReleases + erc20Releases + transfers + nativeReplayChecks + erc20ReplayChecks
            + rollbackChecks + nativeRollbackRetries + erc20RollbackRetries
            + wrongCancellationChecks + artistCancellationChecks + burned + pauseRetries
            + safeNativeBuys + safeERC20Buys;
    }

    function _primaryPolicyHash() private view returns (bytes32 hash) {
        (hash,,) = system.nativeSale.primaryPolicy(1);
    }

    function _sign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _recordMint(uint256 tokenId, address owner, bytes32 authorization) private {
        require(tokenId == minted + 1, "nonsequential mint identity");
        ++minted;
        owners[tokenId] = owner;
        consumedAuthorizations.push(authorization);
    }

    function _nativeBuy(uint256 seed) private {
        if (minted == system.supplyLimit) {
            _transfer(seed);
            return;
        }
        address payer = actors[seed % 3];
        uint256 price = 10_000 + (seed % 10_000) * 10;
        bytes32 nonce = bytes32(nextConsent++);
        bytes memory payload = _nativePayload(payer, payer, nonce, price);
        _submitNative(payer, payer, nonce, price, payload);
    }

    function _nativePayload(address payer, address recipient, bytes32 nonce, uint256 price)
        private
        returns (bytes memory)
    {
        (bytes32 primaryPolicy,,) = system.nativeSale.primaryPolicy(1);
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory auth =
            IStreamFixedPriceSaleAdapter.SaleAuthorization(
                1,
                NATIVE_PHASE,
                payer,
                recipient,
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
        originalNonces[_nativeAuthorization(nonce)] = nonce;
        _prepareReceipt(
            address(system.nativeSale),
            _nativeAuthorization(nonce),
            digest,
            NATIVE_PHASE,
            payer,
            recipient,
            recipient,
            auth.mintCommitment,
            primaryPolicy,
            address(0),
            price
        );
        return abi.encodeCall(
            system.nativeSale.buy,
            (auth, DATA, _sign(PLATFORM_KEY, digest), _sign(ARTIST_KEY, digest))
        );
    }

    function _submitNative(
        address payer,
        address recipient,
        bytes32 nonce,
        uint256 price,
        bytes memory payload
    ) private returns (uint256 tokenId) {
        bytes32 id = _nativeAuthorization(nonce);
        ModelDirect.Receipt storage expected = expectedSales[id];
        expected.createdAt = uint64(block.timestamp);
        expected.registryRevision = _registryRevision(address(system.nativeSale));
        bytes32 root;
        if (payer == address(payerSafe)) {
            _safeCall(address(system.nativeSale), price, payload);
            tokenId = minted + 1;
            root = expected.operationRoot;
        } else {
            vm.prank(payer);
            (bool ok, bytes memory returned) =
                address(system.nativeSale).call{ value: price }(payload);
            if (!ok) assembly ("memory-safe") { revert(add(returned, 32), mload(returned)) }
            (tokenId, root) = abi.decode(returned, (uint256, bytes32));
        }
        require(
            root == expected.operationRoot && system.manager.isOperationRootUsed(root),
            "native exact preview root consumed"
        );
        _recordMint(tokenId, recipient, id);
        _recordPaidReceipt(address(system.nativeSale), id);
        nativeRevenue += price;
        actorNativeSpent[payer] += price;
        ++nativeBuys;
        if (payer != address(payerSafe)) {
            nativeReplay = payload;
            nativeReplayPayer = payer;
            nativeReplayNonce = nonce;
            nativeReplayPrice = price;
        }
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
        originalNonces[_erc20Authorization(nonce)] = nonce;
        _prepareReceipt(
            address(system.erc20Sale),
            _erc20Authorization(nonce),
            digest,
            ERC20_PHASE,
            actors[actorIndex],
            recipient,
            recipient,
            auth.mintCommitment,
            record.config.expectedPrimaryPolicyHash,
            address(system.token),
            100
        );
        return abi.encodeCall(
            system.erc20Sale.buy,
            (
                auth,
                DATA,
                _sign(PLATFORM_KEY, digest),
                _sign(ARTIST_KEY, digest),
                intent,
                actorIndex == 3
                    ? bytes("")
                    : _sign(ACTOR_KEY + actorIndex, system.erc20Sale.paymentIntentDigest(intent))
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
        _submitERC20(index, actors[index], nonce, payload);
    }

    function _erc20Authorization(bytes32 nonce) private view returns (bytes32) {
        return _authorization(
            keccak256("6529STREAM_ERC20_SALE_NONCE_V1"), address(system.erc20Sale), nonce
        );
    }

    function _submitERC20(uint256 index, address recipient, bytes32 nonce, bytes memory payload)
        private
        returns (uint256 tokenId)
    {
        bytes32 id = _erc20Authorization(nonce);
        ModelDirect.Receipt storage expected = expectedSales[id];
        expected.createdAt = uint64(block.timestamp);
        expected.registryRevision = _registryRevision(address(system.erc20Sale));
        bytes32 root;
        if (index == 3) {
            // Empty payer proof is valid only because the actual payer Safe calls the puller.
            _safeCall(address(system.erc20Sale), 0, payload);
            tokenId = minted + 1;
            root = expected.operationRoot;
            require(
                !system.erc20Sale.isPaymentIntentNonceUsed(actors[index], nonce),
                "literal Safe caller exemption consumes no payer nonce"
            );
        } else {
            // The handler is the relayer; the EOA payer's separate intent is mandatory.
            (bool ok, bytes memory returned) = address(system.erc20Sale).call(payload);
            if (!ok) assembly ("memory-safe") { revert(add(returned, 32), mload(returned)) }
            (tokenId, root) = abi.decode(returned, (uint256, bytes32));
            require(
                system.erc20Sale.isPaymentIntentNonceUsed(actors[index], nonce),
                "relayed payer intent consumed"
            );
        }
        require(
            root == expected.operationRoot && system.manager.isOperationRootUsed(root),
            "ERC20 exact preview root consumed"
        );
        _recordMint(tokenId, recipient, id);
        payerIntentNonces.push(nonce);
        payerIntentAccounts.push(actors[index]);
        payerIntentConsumed.push(index != 3);
        _recordPaidReceipt(address(system.erc20Sale), id);
        erc20Revenue += 100;
        actorTokenSpent[index] += 100;
        ++erc20Buys;
        if (index != 3) {
            erc20Replay = payload;
            erc20ReplayPayer = actors[index];
            erc20ReplayNonce = nonce;
        }
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
        bytes32 id = _authorization(
            keccak256("6529STREAM_ENGLISH_AUCTION_NONCE_V1"), address(system.auction), nonce
        );
        originalNonces[id] = nonce;
        _prepareReceipt(
            address(system.auction),
            id,
            digest,
            AUCTION_PHASE,
            address(0),
            address(system.auction),
            system.artist,
            auth.mintCommitment,
            auth.expectedPrimaryPolicyHash,
            address(0),
            0
        );
        uint256 tokenId = system.auction
            .createAuction(auth, DATA, _sign(PLATFORM_KEY, digest), _sign(ARTIST_KEY, digest));
        _recordMint(
            tokenId,
            address(system.auction),
            _authorization(
                keccak256("6529STREAM_ENGLISH_AUCTION_NONCE_V1"), address(system.auction), nonce
            )
        );
        require(
            system.auction.auction(tokenId).operationRoot == expectedSales[id].operationRoot,
            "auction uses exact original creation root"
        );
        _assertNoPaidReceipt(address(system.auction), id);
        auctions.push(AuctionModel(tokenId, auth.endTime, 0, address(0), false, id));
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
        actorNativeSpent[bidder] += amount;
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
            actorNativeRefunded[account] += amount;
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
        if (item.highestBid != 0) {
            ModelDirect.Receipt storage expected = expectedSales[item.authorizationId];
            expected.payer = item.highestBidder;
            expected.beneficiary = item.highestBidder;
            expected.amount = item.highestBid;
            _recordPaidReceipt(address(system.auction), item.authorizationId);
        } else {
            _assertNoPaidReceipt(address(system.auction), item.authorizationId);
            ++noBidSettlements;
        }
        ++settlements;
    }

    function _release() private {
        uint256 releasesBefore = nativeReleases + erc20Releases;
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
        if (nativeReleases + erc20Releases == releasesBefore) _nativeBuy(steps);
    }

    function _transfer(uint256 seed) private {
        for (uint256 n; n < minted; ++n) {
            uint256 tokenId = (seed % minted + n) % minted + 1;
            address from = owners[tokenId];
            if (from == address(0) || from == address(system.auction)) continue;
            address to = actors[seed % 3];
            if (to == from) to = actors[(seed % 3 + 1) % 3];
            if (from == address(payerSafe)) {
                _safeCall(
                    address(system.core),
                    0,
                    abi.encodeCall(system.core.transferFrom, (from, to, tokenId))
                );
            } else {
                vm.prank(from);
                system.core.transferFrom(from, to, tokenId);
            }
            owners[tokenId] = to;
            ++transfers;
            return;
        }
        _replay(false);
    }

    function _authorization(bytes32 domain, address adapter, bytes32 nonce)
        private
        view
        returns (bytes32)
    {
        return keccak256(abi.encode(domain, block.chainid, adapter, system.artist, nonce));
    }

    function _nativeAuthorization(bytes32 nonce) private view returns (bytes32) {
        return _authorization(
            keccak256("6529STREAM_NATIVE_SALE_NONCE_V1"), address(system.nativeSale), nonce
        );
    }

    /// @dev Literal launch CONSTANT/PHASE keys; no Manager preview supplies the expected key.
    function _ledgerSupply(bytes32 phase) private view returns (uint64) {
        bytes32 counter = keccak256("supply");
        bytes32 subject = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                block.chainid,
                address(system.manager.mintLedger()),
                uint8(1),
                uint256(1),
                phase,
                counter
            )
        );
        bytes32 valueKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_VALUE_KEY_V1"),
                address(system.manager),
                uint256(1),
                phase,
                counter,
                subject
            )
        );
        return system.manager.mintLedger().counterValue(valueKey);
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
                system.erc20Sale.isPaymentIntentNonceUsed(payer, nonce),
                system.manager.mintLedger()
                    .isManagerAuthorizationUsed(
                        address(system.manager), _nativeAuthorization(nonce)
                    ),
                system.manager.mintLedger()
                    .isManagerAuthorizationUsed(
                        address(system.manager),
                        _authorization(
                            keccak256("6529STREAM_ERC20_SALE_NONCE_V1"),
                            address(system.erc20Sale),
                            nonce
                        )
                    )
            )
        );
        bytes32 downstreamState = keccak256(
            abi.encode(
                _ledgerSupply(NATIVE_PHASE),
                _ledgerSupply(ERC20_PHASE),
                _ledgerSupply(AUCTION_PHASE),
                system.entropy.tokenEntropyStatus(minted + 1),
                system.entropy.nonterminalTokenCount(1),
                system.entropy.pendingRequestCount(),
                system.revenueEscrow.totalOwed(address(0)),
                system.revenueEscrow.totalOwed(address(system.token))
            )
        );
        bytes32 history = keccak256(
            abi.encode(
                system.floor.firstSale(1),
                _paidEvidence(address(system.nativeSale), _nativeAuthorization(nonce)),
                _paidEvidence(address(system.erc20Sale), _erc20Authorization(nonce))
            )
        );
        return
            keccak256(abi.encode(mintState, paymentState, consentState, downstreamState, history));
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
        rejector.setAccepting(true);
        uint256 tokenId = _submitERC20(index, address(rejector), nonce, payload);
        require(system.core.ownerOf(tokenId) == address(rejector), "identical ERC20 retry delivers");
        rejector.deliver(system.core, tokenId, actors[index]);
        rejector.setAccepting(false);
        owners[tokenId] = actors[index];
        ++transfers;
        ++erc20RollbackRetries;
    }

    function _nativeReceiverRetry(uint256 seed) private {
        if (minted == system.supplyLimit) {
            _replay(false);
            return;
        }
        address payer = actors[seed % 3];
        bytes32 nonce = bytes32(nextConsent++);
        uint256 price = 2 + seed % 100_001;
        bytes memory payload = _nativePayload(payer, address(rejector), nonce, price);
        bytes32 beforeState = _fingerprint(payer, nonce);
        vm.prank(payer);
        (bool ok, bytes memory reason) = address(system.nativeSale).call{ value: price }(payload);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSignature("Error(string)", "invariant receiver rejects")
                    ),
            "native paid mint reaches actual late receiver rejection"
        );
        require(_fingerprint(payer, nonce) == beforeState, "late native failure leaves no residue");
        rejector.setAccepting(true);
        uint256 tokenId = _submitNative(payer, address(rejector), nonce, price, payload);
        require(
            system.core.ownerOf(tokenId) == address(rejector), "exact retry delivers to receiver"
        );
        // The real receiving contract transfers its own token; no contract-caller impersonation.
        rejector.deliver(system.core, tokenId, payer);
        rejector.setAccepting(false);
        owners[tokenId] = payer;
        ++transfers;
        ++nativeRollbackRetries;
    }

    function _wrongCancellation(uint256 seed) private {
        if (minted == system.supplyLimit) {
            _replay(false);
            return;
        }
        address payer = actors[seed % 3];
        address stranger = actors[(seed % 3 + 1) % 3];
        bytes32 nonce = bytes32(nextConsent++);
        uint256 price = 2 + seed % 100_001;
        bytes memory payload = _nativePayload(payer, payer, nonce, price);
        bytes32 beforeState = _fingerprint(payer, nonce);
        vm.prank(stranger);
        system.nativeSale.cancelAuthorization(nonce);
        require(
            system.nativeSale.authorizationUsed(stranger, nonce)
                && !system.nativeSale.authorizationUsed(system.artist, nonce)
                && _fingerprint(payer, nonce) == beforeState,
            "another caller cancels only its own authorization namespace"
        );
        _submitNative(payer, payer, nonce, price, payload);
        ++wrongCancellationChecks;
    }

    function _artistCancellation(uint256 seed) private {
        address payer = actors[seed % 3];
        bytes32 nonce = bytes32(nextConsent++);
        uint256 price = 2 + seed % 100_001;
        bytes memory payload = _nativePayload(payer, payer, nonce, price);
        vm.prank(system.artist);
        system.nativeSale.cancelAuthorization(nonce);
        cancelledNativeNonces.push(nonce);
        bytes32 beforeState = _fingerprint(payer, nonce);
        vm.prank(payer);
        (bool ok, bytes memory reason) = address(system.nativeSale).call{ value: price }(payload);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamFixedPriceSaleAdapter.SaleAlreadyConsumed.selector,
                            system.artist,
                            nonce
                        )
                    ) && _fingerprint(payer, nonce) == beforeState,
            "actual artist cancellation prevents mint without payment or replay residue"
        );
        ++artistCancellationChecks;
    }

    function _safeCall(address target, uint256 value, bytes memory data) private {
        uint256 beforeNonce = payerSafe.nonce();
        require(
            executeSafe(payerSafe, payerSafeKeys, target, value, data, 0),
            "actual payer Safe CALL succeeds"
        );
        ++safeCalls;
        require(payerSafe.nonce() == beforeNonce + 1, "one outer Safe CALL nonce");
    }

    function _safeNativeBuy(uint256 seed) private {
        if (minted == system.supplyLimit) {
            _replay(false);
            return;
        }
        bytes32 nonce = bytes32(nextConsent++);
        uint256 price = 1 + seed % 100_001;
        bytes memory payload = _nativePayload(address(payerSafe), address(payerSafe), nonce, price);
        bytes32 beforeState = _fingerprint(address(payerSafe), nonce);
        // An already funded EOA cannot replace the literal signed Safe payer.
        vm.prank(actors[0]);
        (bool ok, bytes memory reason) = address(system.nativeSale).call{ value: price }(payload);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamFixedPriceSaleAdapter.InvalidSaleAuthorization.selector
                        )
                    ),
            "relayer cannot impersonate signed Safe payer"
        );
        require(
            _fingerprint(address(payerSafe), nonce) == beforeState,
            "wrong Safe caller leaves no progress"
        );
        _submitNative(address(payerSafe), address(payerSafe), nonce, price, payload);
        ++safeNativeBuys;
    }

    function _safeERC20Buy(uint256 seed) private {
        if (minted == system.supplyLimit) {
            _replay(true);
            return;
        }
        bytes32 nonce = bytes32(nextConsent++);
        bytes memory payload = _erc20Payload(3, actors[seed % 3], nonce);
        bytes32 beforeState = _fingerprint(address(payerSafe), nonce);
        (bool ok, bytes memory reason) = address(system.erc20Sale).call(payload);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamPaymentIntentVerifier.InvalidPaymentSignature.selector,
                            address(payerSafe)
                        )
                    ),
            "empty payer proof cannot authorize handler relayer"
        );
        require(
            _fingerprint(address(payerSafe), nonce) == beforeState,
            "empty relayer proof leaves no progress"
        );
        _submitERC20(3, actors[seed % 3], nonce, payload);
        ++safeERC20Buys;
    }

    function _burn(uint256 seed) private {
        for (uint256 n; n < minted; ++n) {
            uint256 id = (seed % minted + n) % minted + 1;
            address owner = owners[id];
            if (owner == address(0) || owner == address(system.auction)) continue;
            if (owner == address(payerSafe)) {
                _safeCall(address(system.core), 0, abi.encodeCall(system.core.burn, (id)));
            } else {
                vm.prank(owner);
                system.core.burn(id);
            }
            owners[id] = address(0);
            ++burned;
            return;
        }
        _replay(false);
    }

    function _pauseAndRetry(uint256 seed) private {
        if (minted == system.supplyLimit) {
            _replay(false);
            return;
        }
        system.governorHost.statefulSetNativeSalePaused(true);
        _assertFloorHistory();
        address payer = actors[seed % 3];
        bytes32 nonce = bytes32(nextConsent++);
        uint256 price = 1 + seed % 100_001;
        // uint64.max is signed before both real governance delays; no clock rewind is used.
        bytes memory payload = _nativePayload(payer, payer, nonce, price);
        bytes32 beforeState = _fingerprint(payer, nonce);
        vm.prank(payer);
        (bool ok, bytes memory reason) = address(system.nativeSale).call{ value: price }(payload);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(IStreamFixedPriceSaleAdapter.SalesPaused.selector)
                    ),
            "actual pause blocks original buy"
        );
        require(_fingerprint(payer, nonce) == beforeState, "pause rejection leaves no progress");
        system.governorHost.statefulSetNativeSalePaused(false);
        require(_fingerprint(payer, nonce) == beforeState, "governed resume preserves sale state");
        _submitNative(payer, payer, nonce, price, payload);
        ++pauseRetries;
    }

    function _settleNoBid(uint256 seed) private {
        if (minted == system.supplyLimit) {
            _replay(false);
            return;
        }
        _createAuction(seed);
        uint256 index = auctions.length - 1;
        require(auctions[index].highestBid == 0, "new unpaid custody auction");
        bytes32 firstBefore = keccak256(abi.encode(system.floor.firstSale(1)));
        _settle(index);
        require(
            keccak256(abi.encode(system.floor.firstSale(1))) == firstBefore,
            "unpaid exit cannot create or overwrite first sale"
        );
    }

    function _registryRevision(address adapter) private view returns (uint64) {
        return IStreamModuleRegistry(address(system.manager.moduleRegistry()))
        .moduleRecord(adapter)
        .revision;
    }

    function _kind(address adapter) private view returns (bytes32) {
        if (adapter == address(system.nativeSale)) return ModelDirect.NATIVE_FIXED_PRICE;
        if (adapter == address(system.erc20Sale)) return ModelDirect.ERC20_FIXED_PRICE;
        require(adapter == address(system.auction), "modeled original adapter");
        return ModelDirect.ENGLISH_AUCTION;
    }

    function _bindings(address adapter) private view returns (ModelDirect.Bindings memory) {
        return ModelDirect.Bindings(
            address(system.core),
            address(system.core).codehash,
            address(system.manager),
            address(system.manager).codehash,
            block.chainid,
            _kind(adapter)
        );
    }

    function _directKey(address adapter, bytes32 id) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_DIRECT_PRIMARY_SALE_KEY_V1"),
                block.chainid,
                address(system.core),
                adapter,
                _kind(adapter),
                id
            )
        );
    }

    function _prepareReceipt(
        address adapter,
        bytes32 id,
        bytes32 digest,
        bytes32 phase,
        address payer,
        address recipient,
        address beneficiary,
        bytes32 commitment,
        bytes32 primaryPolicy,
        address asset,
        uint256 amount
    ) private {
        IStreamMintManager.MintBatch memory batch;
        batch.collectionId = 1;
        batch.phaseId = phase;
        batch.payer = payer;
        batch.initialRecipients = new address[](1);
        batch.beneficiaries = new address[](1);
        batch.tokenData = new bytes[](1);
        batch.mintCommitments = new bytes32[](1);
        batch.initialRecipients[0] = recipient;
        batch.beneficiaries[0] = beneficiary;
        batch.tokenData[0] = DATA;
        batch.mintCommitments[0] = commitment;
        batch.expectedPolicyHash = system.manager.phasePolicyHash(1, phase);
        batch.authorizationId = id;
        batch.contextHash = digest;
        // Preview is caller-bound to the actual original adapter, including Safe-origin buys.
        vm.prank(adapter);
        (bytes32 root, bytes32[] memory ids) =
            system.manager.previewSingleStepMintOperation(batch, "");
        bytes32 operation = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_TOKEN_OPERATION_ID_V1"),
                root,
                minted,
                uint256(0),
                keccak256(DATA),
                commitment
            )
        );
        require(
            root != 0 && ids.length == 1 && ids[0] == operation,
            "independent token operation identity"
        );
        ModelDirect.Receipt memory r;
        r.authorizationDigest = digest;
        r.collectionId = 1;
        r.tokenId = minted + 1;
        r.operationRoot = root;
        r.operationId = operation;
        r.boundMintPolicyHash = batch.expectedPolicyHash;
        r.expectedPrimaryPolicyHash = primaryPolicy;
        r.profileId = system.profile;
        r.wallet = system.wallet;
        r.createdAt = uint64(block.timestamp);
        r.payer = payer;
        r.registryRevision = _registryRevision(adapter);
        r.beneficiary = beneficiary;
        r.asset = asset;
        r.amount = amount;
        expectedSales[id] = r;
        originalProducts[id] = adapter;
    }

    function _recordPaidReceipt(address adapter, bytes32 id) private {
        ModelDirect.Receipt memory expected = expectedSales[id];
        require(expected.amount != 0, "only paid originals enter history model");
        IStreamDirectPrimarySaleReceipt product = IStreamDirectPrimarySaleReceipt(adapter);
        ModelDirect.Bindings memory bindings = _bindings(adapter);
        require(
            keccak256(abi.encode(product.directPrimaryBindings()))
                == keccak256(abi.encode(bindings)),
            "actual immutable original product binding"
        );
        require(
            keccak256(abi.encode(product.directPrimarySaleReceipt(id)))
                == keccak256(abi.encode(expected)),
            "sixteen independently assembled original receipt fields"
        );
        bytes32 originalHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_DIRECT_PRIMARY_SALE_RECEIPT_V1"),
                block.chainid,
                address(system.core),
                adapter,
                _kind(adapter),
                id,
                expected
            )
        );
        require(
            product.directPrimarySaleReceiptHash(id) == originalHash,
            "independent original receipt hash"
        );
        bytes32 key = _directKey(adapter, id);
        if (receiptIds.length == 0) {
            StreamConservationFloorTypes.FirstSaleReceipt memory first;
            first.collectionId = 1;
            first.effectiveTier = WAIVED;
            first.recorder = adapter;
            first.settlementKey = key;
            first.recordedAt = uint64(block.timestamp);
            first.sourceSetHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_CONSERVATION_FLOOR_SOURCES_V1"),
                    block.chainid,
                    address(system.core),
                    address(system.floor)
                )
            );
            // This actual WAIVED graph has no admitted documentary sources or invented facts.
            require(system.floor.sourceCount() == 0, "no fabricated documentary source");
            first.receiptHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_CONSERVATION_FIRST_SALE_V1"),
                    block.chainid,
                    address(system.core),
                    address(system.floor),
                    first
                )
            );
            firstSaleTupleHash = keccak256(abi.encode(first));
            firstSaleReceiptHash = first.receiptHash;
            require(
                keccak256(abi.encode(system.floor.firstSale(1))) == firstSaleTupleHash,
                "independently assembled complete first sale receipt"
            );
        }
        StreamDirectPrimaryConservationTypes.Receipt memory floorReceipt;
        floorReceipt.adapter = adapter;
        floorReceipt.adapterCodeHash = adapter.codehash;
        floorReceipt.directKey = key;
        floorReceipt.authorizationId = id;
        floorReceipt.originalReceiptHash = originalHash;
        floorReceipt.bindings = bindings;
        floorReceipt.sale = expected;
        floorReceipt.effectiveTier = WAIVED;
        floorReceipt.firstSaleReceiptHash = firstSaleReceiptHash;
        floorReceipt.recordedAt = uint64(block.timestamp);
        floorReceipt.receiptHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_DIRECT_RECEIPT_V1"),
                block.chainid,
                address(system.core),
                address(system.floor),
                floorReceipt
            )
        );
        bytes32 tupleHash = keccak256(abi.encode(floorReceipt));
        require(
            keccak256(
                abi.encode(
                    IStreamDirectPrimaryConservationFloor(address(system.floor))
                        .directPrimarySaleFloorReceipt(key)
                )
            ) == tupleHash,
            "independent complete DIRECT floor receipt"
        );
        receiptAdapters.push(adapter);
        receiptIds.push(id);
        floorTupleHashes.push(tupleHash);
    }

    function _paidEvidence(address adapter, bytes32 id) private view returns (bytes32) {
        IStreamDirectPrimarySaleReceipt product = IStreamDirectPrimarySaleReceipt(adapter);
        return keccak256(
            abi.encode(
                product.directPrimarySaleReceipt(id),
                product.directPrimarySaleReceiptHash(id),
                IStreamDirectPrimaryConservationFloor(address(system.floor))
                    .directPrimarySaleFloorReceipt(_directKey(adapter, id))
            )
        );
    }

    function _assertNoPaidReceipt(address adapter, bytes32 id) private view {
        ModelDirect.Receipt memory empty;
        StreamDirectPrimaryConservationTypes.Receipt memory emptyFloor;
        require(
            keccak256(
                    abi.encode(
                        IStreamDirectPrimarySaleReceipt(adapter).directPrimarySaleReceipt(id)
                    )
                ) == keccak256(abi.encode(empty))
                && IStreamDirectPrimarySaleReceipt(adapter).directPrimarySaleReceiptHash(id) == 0,
            "unpaid original has no paid receipt"
        );
        require(
            keccak256(
                abi.encode(
                    IStreamDirectPrimaryConservationFloor(address(system.floor))
                        .directPrimarySaleFloorReceipt(_directKey(adapter, id))
                )
            ) == keccak256(abi.encode(emptyFloor)),
            "unpaid original has no floor receipt"
        );
    }

    function _assertFloorHistory() private view {
        if (receiptIds.length == 0) {
            StreamConservationFloorTypes.FirstSaleReceipt memory emptyFirst;
            require(
                keccak256(abi.encode(system.floor.firstSale(1)))
                    == keccak256(abi.encode(emptyFirst)),
                "no first sale before a paid outcome"
            );
        } else {
            require(
                keccak256(abi.encode(system.floor.firstSale(1))) == firstSaleTupleHash,
                "first sale history is permanent"
            );
        }
        StreamConservationFloorTypes.ReleaseFloorReceipt memory emptyRelease;
        require(
            keccak256(abi.encode(system.floor.releaseFloorReceipt(bytes32(0))))
                == keccak256(abi.encode(emptyRelease)),
            "WAIVED never invents documentary release evidence"
        );
        StreamConservationFloorTypes.SettlementReceipt memory emptyUniversal;
        for (uint256 i; i < receiptIds.length; ++i) {
            address adapter = receiptAdapters[i];
            bytes32 id = receiptIds[i];
            bytes32 key = _directKey(adapter, id);
            require(
                keccak256(
                    abi.encode(
                        IStreamDirectPrimarySaleReceipt(adapter).directPrimarySaleReceipt(id)
                    )
                ) == keccak256(abi.encode(expectedSales[id])),
                "original paid history is permanent"
            );
            require(
                keccak256(
                    abi.encode(
                        IStreamDirectPrimaryConservationFloor(address(system.floor))
                            .directPrimarySaleFloorReceipt(key)
                    )
                ) == floorTupleHashes[i],
                "DIRECT floor history is permanent"
            );
            require(
                keccak256(abi.encode(system.floor.settlementReceipt(key)))
                    == keccak256(abi.encode(emptyUniversal)),
                "DIRECT history cannot appear as universal settlement"
            );
        }
    }

    function assertRandomizedActivity() external view {
        require(randomizedSteps > 0, "campaign stopped at deterministic opening");
    }

    function assertInvariants() external view {
        _assertFloorHistory();
        require(payerSafe.nonce() == safeCalls, "actual Safe CALL nonce model");
        require(
            system.core.totalSupply() == minted - burned
                && system.core.collectionMintedEver(1) == minted
                && system.core.lastAllocatedTokenId() == minted
                && system.core.totalSupplyOfCollection(1) == minted - burned,
            "supply conservation"
        );
        require(
            system.manager.nextOperationNonce() == minted && minted <= system.supplyLimit,
            "mint nonce or supply cap"
        );
        require(
            _ledgerSupply(NATIVE_PHASE) == nativeBuys && _ledgerSupply(ERC20_PHASE) == erc20Buys
                && _ledgerSupply(AUCTION_PHASE) == auctionCreates
                && nativeBuys + erc20Buys + auctionCreates == minted,
            "mandatory phase counters equal successful original operations"
        );
        require(consumedAuthorizations.length == minted, "one authorization per actual mint");
        for (uint256 id = 1; id <= minted; ++id) {
            bool expectedBurned = owners[id] == address(0);
            if (expectedBurned) {
                (bool readable,) =
                    address(system.core).staticcall(abi.encodeCall(system.core.ownerOf, (id)));
                require(!readable, "burned token has no owner");
            } else {
                require(system.core.ownerOf(id) == owners[id], "ownership model");
            }
            (bool exists, uint256 collection, uint256 serial, bool actualBurned) =
                system.core.tokenCollectionIdentity(id);
            require(
                exists && collection == 1 && serial == id && actualBurned == expectedBurned
                    && system.core.tokenLifecycle(id) == (expectedBurned ? 3 : 2),
                "lifetime token identity"
            );
            require(
                system.manager.mintLedger()
                    .isManagerAuthorizationUsed(
                        address(system.manager), consumedAuthorizations[id - 1]
                    ),
                "every accepted authorization remains consumed"
            );
            require(
                system.entropy.tokenEntropyStatus(id) == StreamEntropyStatus.REGISTERED,
                "each accepted mint retains actual entropy registration"
            );
        }
        for (uint256 i; i < consumedAuthorizations.length; ++i) {
            bytes32 id = consumedAuthorizations[i];
            require(
                system.manager.isOperationRootUsed(expectedSales[id].operationRoot),
                "every original operation root remains consumed"
            );
            require(
                IStreamFixedPriceSaleAdapter(originalProducts[id])
                    .authorizationUsed(system.artist, originalNonces[id]),
                "every original product nonce remains consumed"
            );
        }
        for (uint256 i; i < payerIntentNonces.length; ++i) {
            require(
                system.erc20Sale
                        .isPaymentIntentNonceUsed(payerIntentAccounts[i], payerIntentNonces[i])
                    == payerIntentConsumed[i],
                "original payer nonce or literal-caller exemption remains exact"
            );
        }
        for (uint256 i; i < cancelledNativeNonces.length; ++i) {
            bytes32 nonce = cancelledNativeNonces[i];
            require(
                system.nativeSale.authorizationUsed(system.artist, nonce)
                    && !system.manager.mintLedger()
                        .isManagerAuthorizationUsed(
                            address(system.manager), _nativeAuthorization(nonce)
                        ),
                "cancellation stays durable without a fictitious Ledger mint"
            );
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
            require(
                actors[i].balance
                    == INITIAL_NATIVE + actorNativeRefunded[actors[i]]
                        - actorNativeSpent[actors[i]],
                "intended native payer debit and refund"
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
                && system.token.rawBalance(address(system.erc20Sale)) == 0
                && system.revenueEscrow.totalOwed(address(0)) == 0
                && system.revenueEscrow.totalOwed(address(system.token)) == 0,
            "adapter retained proceeds"
        );
        require(
            system.entropy.tokenEntropyStatus(minted + 1) == StreamEntropyStatus.NONE
                && system.entropy.nonterminalTokenCount(1) == minted
                && system.entropy.pendingRequestCount() == 0,
            "no phantom mint or entropy request"
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
            require(
                account.balance == beneficiaryNativeBefore[i] + nativeReleased[i]
                    && system.token.rawBalance(account)
                        == beneficiaryTokensBefore[i] + erc20Released[i],
                "actual beneficiary receives exactly recorded releases"
            );
        }
    }

    function assertCampaignActivity() external view {
        require(
            steps >= OPENING_ACTIONS && nativeBuys > 0 && erc20Buys > 0 && auctionCreates > 0
                && bids >= 2 && refundWithdrawals > 0 && settlements > 0 && nativeReleases > 0
                && erc20Releases > 0 && transfers > 0 && nativeReplayChecks > 0
                && erc20ReplayChecks > 0 && rollbackChecks > 0 && nativeRollbackRetries > 0
                && wrongCancellationChecks > 0 && artistCancellationChecks > 0
                && erc20RollbackRetries > 0 && safeNativeBuys > 0 && safeERC20Buys > 0 && burned > 0
                && pauseRetries > 0 && noBidSettlements > 0,
            "campaign lacked required successful activity"
        );
    }
}
