// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/AuctionContract.sol";
import "../smart-contracts/RandomizerRNG.sol";
import "../smart-contracts/StreamCuratorsPool.sol";
import "../smart-contracts/StreamMinter.sol";
import "./helpers/Assertions.sol";
import "./helpers/DropAuthTestHelper.sol";
import "./helpers/StreamFixture.sol";
import "./mocks/MockRandomizerCore.sol";

contract StreamPaymentsInvariantTest is DropAuthTestHelper, StreamFixture {
    uint256 private constant SEQUENCE_LENGTH = 24;

    PaymentsInvariantHandler private handler;

    function setUp() public {
        handler = new PaymentsInvariantHandler(signerAddress());
    }

    function testPaymentInvariantsHoldAcrossBoundedOperationSequences(
        uint256[SEQUENCE_LENGTH] memory actionSeeds,
        uint256[SEQUENCE_LENGTH] memory firstArgs,
        uint256[SEQUENCE_LENGTH] memory secondArgs
    ) public {
        _assertPaymentInvariants();
        for (uint256 i = 0; i < SEQUENCE_LENGTH; i++) {
            _runAction(actionSeeds[i], firstArgs[i], secondArgs[i]);
            _assertPaymentInvariants();
        }
    }

    function _runAction(uint256 actionSeed, uint256 firstArg, uint256 secondArg) private {
        uint256 action = actionSeed % 15;
        if (action == 0) {
            handler.mintFixedPrice(firstArg, secondArg);
        } else if (action == 1) {
            handler.withdrawFixedPriceCredit(firstArg);
        } else if (action == 2) {
            handler.forceDropsSurplus(firstArg);
        } else if (action == 3) {
            handler.mintAuction(firstArg, secondArg);
        } else if (action == 4) {
            uint256 bidSeed = uint256(keccak256(abi.encode(actionSeed, "bid")));
            handler.bidAuction(firstArg, secondArg, bidSeed);
        } else if (action == 5) {
            handler.settleAuction(firstArg);
        } else if (action == 6) {
            handler.withdrawAuctionCredit(firstArg);
        } else if (action == 7) {
            handler.forceAuctionSurplus(firstArg);
        } else if (action == 8) {
            handler.claimCuratorReward(firstArg, secondArg);
        } else if (action == 9) {
            handler.withdrawCuratorCredit(firstArg);
        } else if (action == 10) {
            handler.forceCuratorPoolSurplus(firstArg);
        } else if (action == 11) {
            handler.forceMinterSurplus(firstArg);
        } else if (action == 12) {
            handler.fundRandomizerReserve(firstArg);
        } else if (action == 13) {
            handler.requestRandomizerWords(firstArg, secondArg);
        } else {
            handler.emergencyWithdrawSurplus(firstArg);
        }
    }

    function _assertPaymentInvariants() private view {
        handler.assertPaymentCategoryTotalsMatchAccountCredits();
        handler.assertContractBalancesCoverOwedAndReservedFunds();
        handler.assertEmergencyWithdrawableIsOnlySurplus();
    }
}

contract PaymentsInvariantHandler is DropAuthTestHelper, StreamFixture {
    using Assertions for uint256;

    address private constant POSTER = address(0x1001);
    address private constant SECOND_POSTER = address(0x1002);
    address private constant RECIPIENT = address(0x2001);
    address private constant PAYOUT = address(0x3001);
    address private constant CURATORS_POOL = address(0x4001);
    address private constant FIRST_BIDDER = address(0x5001);
    address private constant SECOND_BIDDER = address(0x5002);
    address private constant CURATOR = address(0x6001);
    address private constant SECOND_CURATOR = address(0x6002);
    address private constant WITHDRAW_RECIPIENT = address(0x7001);
    uint256 private constant MAX_PROTOCOL_MINTS = 8;
    uint256 private constant MAX_AUCTIONS = 3;
    uint256 private constant MAX_CURATOR_CLAIMS = 8;
    uint256 private constant MAX_PAYMENT = 8 ether;

    DeployedStream private deployed;
    StreamAuctions private auctions;
    StreamCuratorsPool private curatorsPool;
    StreamMinter private surplusMinter;
    NextGenRandomizerRNG private randomizer;

    uint256 private nonce = 1;
    uint256 private mintedDrops;
    uint256 private mintedAuctions;
    uint256 private curatorClaims;
    uint256 private randomizerRequests;
    uint256[MAX_AUCTIONS] private auctionTokenIds;
    mapping(uint256 => uint256) private auctionReserveByTokenId;
    mapping(uint256 => bool) private randomizerTokenRequested;

    constructor(address signer) {
        deployed = deployStreamWithSigner(PAYOUT, CURATORS_POOL, signer);
        deployed.admins.updateEmergencyRecipient(WITHDRAW_RECIPIENT);
        auctions = new StreamAuctions(
            address(deployed.minter),
            address(deployed.core),
            address(deployed.admins),
            address(deployed.drops),
            PAYOUT,
            CURATORS_POOL
        );
        deployed.drops.updateAuctionContract(address(auctions));

        InvariantDelegation delegation = new InvariantDelegation();
        curatorsPool = new StreamCuratorsPool(address(deployed.admins), address(delegation));
        surplusMinter =
            new StreamMinter(address(deployed.core), address(deployed.admins), address(this));

        MockRandomizerCore randomizerCore = new MockRandomizerCore();
        InvariantArrngController controller = new InvariantArrngController();
        randomizer = new NextGenRandomizerRNG(
            address(randomizerCore), address(deployed.admins), address(controller)
        );
        randomizerCore.setRandomizer(1, address(randomizer), 1);
    }

    function mintFixedPrice(uint256 rawPrice, uint256 posterSeed) external {
        if (mintedDrops >= MAX_PROTOCOL_MINTS) {
            return;
        }
        uint256 currentNonce = nonce;
        nonce++;
        mintedDrops++;

        uint256 price = _boundedAmount(rawPrice);
        address poster = _poster(posterSeed);
        string memory tokenData = _tokenData(currentNonce);

        StreamDrops.DropAuthorization memory authorization = buildFixedPriceAuthorization(
            deployed.drops,
            poster,
            RECIPIENT,
            price == 0 ? address(0) : address(this),
            tokenData,
            1,
            price,
            currentNonce,
            currentNonce,
            block.timestamp + 1 days
        );
        bytes memory signature = signAuthorization(deployed.drops, authorization);

        vm.deal(address(this), address(this).balance + price);
        // The handler intentionally pays the contract under test; payment safety
        // is asserted after each generated action, not in the harness transfer.
        // slither-disable-next-line arbitrary-send-eth
        deployed.drops.mintDrop{ value: price }(authorization, tokenData, signature);
    }

    function withdrawFixedPriceCredit(uint256 accountSeed) external {
        address account = _fixedPriceWithdrawAccount(accountSeed);
        if (
            deployed.drops.fixedPricePosterCredits(account)
                    + deployed.drops.fixedPriceProtocolCredits(account) == 0
        ) {
            return;
        }
        vm.prank(account);
        deployed.drops.withdrawFixedPriceCreditTo(payable(WITHDRAW_RECIPIENT));
    }

    function forceDropsSurplus(uint256 rawAmount) external {
        _forceBalance(address(deployed.drops), rawAmount);
    }

    function mintAuction(uint256 rawReserve, uint256 posterSeed) external {
        if (mintedDrops >= MAX_PROTOCOL_MINTS || mintedAuctions >= MAX_AUCTIONS) {
            return;
        }
        uint256 currentNonce = nonce;
        nonce++;
        mintedDrops++;
        uint256 auctionIndex = mintedAuctions;
        mintedAuctions++;

        uint256 reserve = _boundedAmount(rawReserve);
        if (reserve == 0) {
            reserve = 1 wei;
        }
        address poster = _poster(posterSeed);
        string memory tokenData = _tokenData(currentNonce);

        StreamDrops.DropAuthorization memory authorization = buildAuctionAuthorization(
            deployed.drops,
            poster,
            address(0),
            tokenData,
            1,
            reserve,
            block.timestamp + 1 days,
            currentNonce,
            currentNonce,
            block.timestamp + 1 days
        );
        bytes memory signature = signAuthorization(deployed.drops, authorization);

        // The handler records generated-sequence state around calls into
        // contracts under test; any revert rolls all harness bookkeeping back.
        // slither-disable-start reentrancy-no-eth
        deployed.drops.mintDrop(authorization, tokenData, signature);
        uint256 tokenId = deployed.drops.retrieveTokenID(authorization.dropId);
        auctionTokenIds[auctionIndex] = tokenId;
        auctionReserveByTokenId[tokenId] = reserve;
        // slither-disable-end reentrancy-no-eth
    }

    function bidAuction(uint256 auctionSeed, uint256 bidderSeed, uint256 rawBid) external {
        if (mintedAuctions == 0) {
            return;
        }
        uint256 tokenId = auctionTokenIds[auctionSeed % mintedAuctions];
        if (auctions.retrieveAuctionStatus(tokenId) != StreamAuctions.AuctionStatus.Active) {
            return;
        }

        uint256 minimumBid = _minimumBid(tokenId);
        uint256 bid = _boundedAmount(rawBid);
        if (bid < minimumBid) {
            bid = minimumBid;
        }
        if (bid > MAX_PAYMENT) {
            return;
        }

        address bidder = _bidder(bidderSeed);
        vm.deal(bidder, bid);
        vm.prank(bidder);
        // The handler intentionally pays the contract under test; payment safety
        // is asserted after each generated action, not in the harness transfer.
        // slither-disable-next-line arbitrary-send-eth
        auctions.participateToAuction{ value: bid }(tokenId);
    }

    function settleAuction(uint256 auctionSeed) external {
        if (mintedAuctions == 0) {
            return;
        }
        uint256 tokenId = auctionTokenIds[auctionSeed % mintedAuctions];
        uint256 endTime = auctions.retrieveAuctionEndTime(tokenId);
        if (block.timestamp <= endTime) {
            vm.warp(endTime + 1);
        }

        try auctions.claimAuction(tokenId) { } catch { }
    }

    function withdrawAuctionCredit(uint256 accountSeed) external {
        address account = _auctionWithdrawAccount(accountSeed);
        uint256 bidderCredit = auctions.auctionBidderCredits(account);
        uint256 proceedsCredit = auctions.auctionPosterCredits(account)
            + auctions.auctionProtocolCredits(account) + auctions.auctionCuratorCredits(account);

        if (bidderCredit != 0) {
            vm.prank(account);
            auctions.withdrawBidderCreditTo(payable(WITHDRAW_RECIPIENT));
        }
        if (proceedsCredit != 0) {
            vm.prank(account);
            auctions.withdrawAuctionProceedsCreditTo(payable(WITHDRAW_RECIPIENT));
        }
    }

    function forceAuctionSurplus(uint256 rawAmount) external {
        _forceBalance(address(auctions), rawAmount);
    }

    function claimCuratorReward(uint256 rawAmount, uint256 curatorSeed) external {
        if (curatorClaims >= MAX_CURATOR_CLAIMS) {
            return;
        }
        uint256 collectionId = 1_000 + curatorClaims;
        curatorClaims++;

        uint256 amount = _boundedAmount(rawAmount);
        if (amount == 0) {
            amount = 1 wei;
        }
        address curator = _curator(curatorSeed);
        bytes32 leaf = curatorsPool.hashRewardLeaf(curator, collectionId, amount);
        bytes32[] memory proof = new bytes32[](0);

        curatorsPool.setMerkleRoot(collectionId, leaf);
        vm.deal(address(curatorsPool), address(curatorsPool).balance + amount);
        vm.prank(curator);
        curatorsPool.claimRewards(collectionId, amount, proof, address(0));
    }

    function withdrawCuratorCredit(uint256 curatorSeed) external {
        address curator = _curator(curatorSeed);
        if (curatorsPool.curatorCredits(curator) == 0) {
            return;
        }
        vm.prank(curator);
        curatorsPool.withdrawCuratorCreditTo(payable(WITHDRAW_RECIPIENT));
    }

    function forceCuratorPoolSurplus(uint256 rawAmount) external {
        _forceBalance(address(curatorsPool), rawAmount);
    }

    function forceMinterSurplus(uint256 rawAmount) external {
        _forceBalance(address(surplusMinter), rawAmount);
    }

    function fundRandomizerReserve(uint256 rawAmount) external {
        uint256 amount = _boundedAmount(rawAmount);
        if (amount == 0) {
            amount = 1 wei;
        }
        vm.deal(address(this), address(this).balance + amount);
        // The handler intentionally funds the adapter under test; reserve safety
        // is asserted after each generated action, not in the harness transfer.
        // slither-disable-next-line arbitrary-send-eth
        (bool success,) = address(randomizer).call{ value: amount }("");
        require(success, "randomizer funding failed");
    }

    function requestRandomizerWords(uint256 rawCost, uint256 tokenSeed) external {
        if (randomizerRequests >= MAX_PROTOCOL_MINTS) {
            return;
        }
        uint256 cost = _boundedAmount(rawCost);
        if (cost == 0 || randomizer.totalRandomnessReserved() < cost) {
            return;
        }
        uint256 tokenId = 900_000 + (tokenSeed % 10_000);
        if (randomizerTokenRequested[tokenId]) {
            return;
        }
        randomizerRequests++;
        randomizerTokenRequested[tokenId] = true;
        randomizer.updateRNGCost(cost);
        vm.prank(address(randomizer.gencoreContract()));
        randomizer.calculateTokenHash(1, tokenId, 0);
    }

    function emergencyWithdrawSurplus(uint256 targetSeed) external {
        uint256 target = targetSeed % 4;
        if (target == 0) {
            auctions.emergencyWithdraw();
        } else if (target == 1) {
            curatorsPool.emergencyWithdraw();
        } else if (target == 2) {
            surplusMinter.emergencyWithdraw();
        } else {
            randomizer.emergencyWithdraw();
        }
    }

    function assertPaymentCategoryTotalsMatchAccountCredits() external view {
        _assertDropsTotals();
        _assertAuctionTotals();
        _assertCuratorTotals();
        surplusMinter.totalOwed().assertEq(0, "minter owed");
        randomizer.totalOwed().assertEq(randomizer.totalRandomnessReserved(), "randomizer owed");
    }

    function assertContractBalancesCoverOwedAndReservedFunds() external view {
        _assertBalanceCoversOwed(address(deployed.drops), deployed.drops.totalOwed(), "drops");
        _assertBalanceCoversOwed(address(auctions), auctions.totalOwed(), "auction");
        _assertBalanceCoversOwed(address(curatorsPool), curatorsPool.totalOwed(), "curator");
        _assertBalanceCoversOwed(address(surplusMinter), surplusMinter.totalOwed(), "minter");
        _assertBalanceCoversOwed(address(randomizer), randomizer.totalOwed(), "randomizer");
    }

    function assertEmergencyWithdrawableIsOnlySurplus() external view {
        deployed.drops.emergencyWithdrawable()
            .assertEq(
                _surplus(address(deployed.drops), deployed.drops.totalOwed()), "drops surplus"
            );
        auctions.emergencyWithdrawable()
            .assertEq(_surplus(address(auctions), auctions.totalOwed()), "auction surplus");
        curatorsPool.emergencyWithdrawable()
            .assertEq(_surplus(address(curatorsPool), curatorsPool.totalOwed()), "curator surplus");
        surplusMinter.emergencyWithdrawable()
            .assertEq(_surplus(address(surplusMinter), surplusMinter.totalOwed()), "minter surplus");
        randomizer.emergencyWithdrawable().assertEq(0, "randomizer surplus");
    }

    function _assertDropsTotals() private view {
        uint256 posterCredits = deployed.drops.fixedPricePosterCredits(POSTER)
            + deployed.drops.fixedPricePosterCredits(SECOND_POSTER);
        uint256 protocolCredits = deployed.drops.fixedPriceProtocolCredits(PAYOUT);
        uint256 curatorReserveCredits =
            deployed.drops.fixedPriceCuratorReserveCredits(CURATORS_POOL);

        posterCredits.assertEq(deployed.drops.totalFixedPricePosterOwed(), "fixed poster total");
        protocolCredits.assertEq(
            deployed.drops.totalFixedPriceProtocolOwed(), "fixed protocol total"
        );
        curatorReserveCredits.assertEq(
            deployed.drops.totalFixedPriceCuratorReserveOwed(), "fixed curator reserve total"
        );
        (posterCredits + protocolCredits + curatorReserveCredits)
        .assertEq(deployed.drops.totalFixedPriceOwed(), "fixed price total");
        deployed.drops.totalFixedPriceOwed().assertEq(deployed.drops.totalOwed(), "drops total");
    }

    function _assertAuctionTotals() private view {
        uint256 bidderCredits = auctions.auctionBidderCredits(FIRST_BIDDER)
            + auctions.auctionBidderCredits(SECOND_BIDDER);
        uint256 posterCredits =
            auctions.auctionPosterCredits(POSTER) + auctions.auctionPosterCredits(SECOND_POSTER);
        uint256 protocolCredits = auctions.auctionProtocolCredits(PAYOUT);
        uint256 curatorCredits = auctions.auctionCuratorCredits(CURATORS_POOL);

        bidderCredits.assertEq(auctions.totalBidderOwed(), "auction bidder total");
        posterCredits.assertEq(auctions.totalPosterOwed(), "auction poster total");
        protocolCredits.assertEq(auctions.totalProtocolOwed(), "auction protocol total");
        curatorCredits.assertEq(auctions.totalCuratorOwed(), "auction curator total");
        (posterCredits + protocolCredits + curatorCredits)
        .assertEq(auctions.totalProceedsOwed(), "auction proceeds total");
        (bidderCredits + auctions.totalAuctionBidEscrow() + auctions.totalProceedsOwed())
        .assertEq(auctions.totalOwed(), "auction total");
    }

    function _assertCuratorTotals() private view {
        uint256 curatorCredits =
            curatorsPool.curatorCredits(CURATOR) + curatorsPool.curatorCredits(SECOND_CURATOR);
        curatorCredits.assertEq(curatorsPool.totalCuratorOwed(), "curator total");
        curatorsPool.totalCuratorOwed().assertEq(curatorsPool.totalOwed(), "pool total");
    }

    function _assertBalanceCoversOwed(address target, uint256 owed, string memory message)
        private
        view
    {
        require(target.balance >= owed, message);
    }

    function _surplus(address target, uint256 owed) private view returns (uint256) {
        if (target.balance <= owed) {
            return 0;
        }
        return target.balance - owed;
    }

    function _boundedAmount(uint256 rawAmount) private pure returns (uint256) {
        return rawAmount % (MAX_PAYMENT + 1);
    }

    function _minimumBid(uint256 tokenId) private view returns (uint256) {
        uint256 previousBid = auctions.auctionHighestBid(tokenId);
        if (previousBid > 0) {
            return previousBid + (previousBid * auctions.incPercent() / 100);
        }
        return auctionReserveByTokenId[tokenId];
    }

    function _poster(uint256 seed) private pure returns (address) {
        return seed % 2 == 0 ? POSTER : SECOND_POSTER;
    }

    function _bidder(uint256 seed) private pure returns (address) {
        return seed % 2 == 0 ? FIRST_BIDDER : SECOND_BIDDER;
    }

    function _curator(uint256 seed) private pure returns (address) {
        return seed % 2 == 0 ? CURATOR : SECOND_CURATOR;
    }

    function _fixedPriceWithdrawAccount(uint256 seed) private pure returns (address) {
        uint256 account = seed % 3;
        if (account == 0) {
            return POSTER;
        }
        if (account == 1) {
            return SECOND_POSTER;
        }
        return PAYOUT;
    }

    function _auctionWithdrawAccount(uint256 seed) private pure returns (address) {
        uint256 account = seed % 5;
        if (account == 0) {
            return FIRST_BIDDER;
        }
        if (account == 1) {
            return SECOND_BIDDER;
        }
        if (account == 2) {
            return POSTER;
        }
        if (account == 3) {
            return SECOND_POSTER;
        }
        return PAYOUT;
    }

    function _forceBalance(address target, uint256 rawAmount) private {
        uint256 amount = _boundedAmount(rawAmount);
        if (amount == 0) {
            return;
        }
        // Scenario tests cover selfdestructed ETH; the sequence handler uses
        // vm.deal to deterministically model the same surplus accounting state.
        vm.deal(target, target.balance + amount);
    }

    function _tokenData(uint256 id) private pure returns (string memory) {
        if (id % 3 == 0) {
            return "alpha";
        }
        if (id % 3 == 1) {
            return "beta";
        }
        return "gamma";
    }
}

contract InvariantDelegation {
    function retrieveGlobalStatusOfDelegation(address, address, address, uint256)
        external
        pure
        returns (bool)
    {
        return false;
    }
}

// The invariant controller is a test-only payable provider mock. Retained ETH is
// part of the reserve simulation; production reserve withdrawal is asserted on
// the randomizer adapter under test.
// slither-disable-start locked-ether
contract InvariantArrngController {
    uint256 public nextRequestId = 1;

    function requestRandomWords(uint256, address) external payable returns (uint256 requestId) {
        requestId = nextRequestId;
        nextRequestId++;
    }
}
// slither-disable-end locked-ether
