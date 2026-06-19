// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/AuctionContract.sol";
import "../smart-contracts/RandomizerRNG.sol";
import "../smart-contracts/StreamCore.sol";
import "../smart-contracts/StreamDrops.sol";
import "../smart-contracts/StreamPauseDomains.sol";
import "../smart-contracts/StreamRandomizerLifecycle.sol";
import "./helpers/Assertions.sol";
import "./helpers/DropAuthTestHelper.sol";
import "./helpers/StreamFixture.sol";
import "./mocks/MockRandomizer.sol";

contract StreamAuctionRandomizerCompositionTest is DropAuthTestHelper, StreamFixture {
    using Assertions for address;
    using Assertions for bool;
    using Assertions for bytes32;
    using Assertions for uint256;

    uint256 private constant COLLECTION_ID = 1;
    uint256 private constant RESERVE_PRICE = 5 ether;
    uint256 private constant SECOND_BID = 6 ether;
    address private constant POSTER = address(0x1001);
    address private constant PAYOUT = address(0x2001);
    address private constant CURATORS_POOL = address(0x3001);
    address private constant FIRST_BIDDER = address(0x4001);
    address private constant SECOND_BIDDER = address(0x4002);
    address private constant EMERGENCY_RECIPIENT = address(0x5001);
    bytes32 private constant PAUSE_REASON = keccak256("auction-randomizer-composition");
    bytes32 private constant RANDOMNESS_SEED_TYPEHASH = keccak256(
        "6529StreamRandomnessSeed(address provider,uint256 requestId,uint256 collectionId,uint256 tokenId,uint256 randomizerEpoch,bytes32 rawOutputHash)"
    );

    struct CompositionSetup {
        DeployedStream deployed;
        StreamAuctions auctions;
        NextGenRandomizerRNG randomizer;
        CompositionArrngController controller;
    }

    struct AuctionSnapshot {
        uint256 status;
        address owner;
        uint256 highestBid;
        address highestBidder;
        uint256 totalBidderOwed;
        uint256 totalAuctionBidEscrow;
        uint256 totalProceedsOwed;
        uint256 totalOwed;
        uint256 balance;
        uint256 pendingRequests;
        uint256 randomizerEpoch;
        address collectionRandomizer;
        uint256 tokenRequest;
    }

    struct AuctionAccountingSnapshot {
        uint256 bidderCredit;
        uint256 posterCredit;
        uint256 protocolCredit;
        uint256 curatorCredit;
        uint256 totalOwed;
        uint256 balance;
    }

    function testPausedRandomnessRequestRejectsAuctionDropWithoutConsumingAuthorization() public {
        CompositionSetup memory setup = _deployComposition();
        uint256 nextTokenId = setup.deployed.core.viewTokensIndexMin(COLLECTION_ID)
            + setup.deployed.core.viewCirSupply(COLLECTION_ID);
        uint256 supplyBefore = setup.deployed.core.totalSupply();
        uint256 circulationBefore = setup.deployed.core.viewCirSupply(COLLECTION_ID);
        uint256 dropCountBefore = setup.deployed.drops.retrieveDrops().length;

        (StreamDrops.DropAuthorization memory authorization, bytes memory signature) = _buildSignedAuctionAuthorization(
            setup, "paused-randomness-auction-drop", 1, block.timestamp + 1 days
        );

        _setPaused(setup, StreamPauseDomains.RANDOMNESS_REQUEST, true);
        (bool success, bytes memory returnData) =
            _callMintDrop(setup, authorization, "paused-randomness-auction-drop", signature);
        _assertRevertedWithMessage(success, returnData, "Randomness paused");

        setup.deployed.drops.isDropConsumed(authorization.dropId)
            .assertFalse("paused request consumed drop");
        setup.deployed.drops.retrieveTokenID(authorization.dropId).assertEq(0, "paused token id");
        setup.deployed.core.totalSupply().assertEq(supplyBefore, "paused supply");
        setup.deployed.core.viewCirSupply(COLLECTION_ID)
            .assertEq(circulationBefore, "paused circulation");
        setup.deployed.drops.retrieveDrops().length.assertEq(dropCountBefore, "paused drop count");
        setup.randomizer.pendingRandomnessRequests(COLLECTION_ID).assertEq(0, "paused pending");
        uint256(setup.auctions.retrieveAuctionStatus(nextTokenId))
            .assertEq(uint256(StreamAuctions.AuctionStatus.None), "paused auction status");

        _setPaused(setup, StreamPauseDomains.RANDOMNESS_REQUEST, false);
        setup.deployed.drops.mintDrop(authorization, "paused-randomness-auction-drop", signature);
        uint256 tokenId = setup.deployed.drops.retrieveTokenID(authorization.dropId);
        tokenId.assertEq(nextTokenId, "token id after retry");
        setup.deployed.drops.isDropConsumed(authorization.dropId)
            .assertTrue("retried drop not consumed");
        setup.randomizer.pendingRandomnessRequests(COLLECTION_ID).assertEq(1, "retried pending");
        setup.randomizer.tokenToRequest(tokenId).assertEq(1, "retried request id");
        setup.deployed.core.ownerOf(tokenId).assertEq(address(setup.auctions), "retried custody");
        uint256(setup.auctions.retrieveAuctionStatus(tokenId))
            .assertEq(uint256(StreamAuctions.AuctionStatus.Active), "retried auction");
    }

    function testAuctionDropPendingArrngRequestBlocksRandomizerMigrationWithoutAuctionDrift()
        public
    {
        CompositionSetup memory setup = _deployComposition();
        (, uint256 tokenId,) = _mintAuctionDrop(setup, "pending-request-migration-auction", 11);
        _bid(setup.auctions, tokenId, FIRST_BIDDER, RESERVE_PRICE);
        AuctionSnapshot memory beforeMigration = _snapshot(setup, tokenId);
        NoopRandomizer replacement = new NoopRandomizer();

        vm.expectRevert(
            abi.encodeWithSelector(
                StreamCore.PendingRandomnessRequests.selector,
                COLLECTION_ID,
                address(setup.randomizer),
                uint256(1)
            )
        );
        setup.deployed.core.addRandomizer(COLLECTION_ID, address(replacement));

        _assertSnapshot(setup, tokenId, beforeMigration, "migration");
        setup.deployed.core.viewCollectionRandomizerContract(COLLECTION_ID)
            .assertEq(address(setup.randomizer), "provider changed");
        setup.deployed.core.viewRandomizerEpoch(COLLECTION_ID)
            .assertEq(beforeMigration.randomizerEpoch, "epoch changed");
    }

    function testAuctionSettlementBeforeArrngFulfillmentPreservesWinnerCreditsAndRequestBinding()
        public
    {
        CompositionSetup memory setup = _deployComposition();
        (, uint256 tokenId, uint256 auctionEndTime) =
            _mintAuctionDrop(setup, "settle-before-arrng-fulfillment", 21);
        uint256 requestId = setup.randomizer.tokenToRequest(tokenId);

        _bid(setup.auctions, tokenId, FIRST_BIDDER, RESERVE_PRICE);
        _bid(setup.auctions, tokenId, SECOND_BIDDER, SECOND_BID);
        vm.warp(auctionEndTime + 1);
        setup.auctions.claimAuction(tokenId);

        setup.deployed.core.ownerOf(tokenId).assertEq(SECOND_BIDDER, "winner custody");
        uint256(setup.auctions.retrieveAuctionStatus(tokenId))
            .assertEq(uint256(StreamAuctions.AuctionStatus.SettledWithBid), "settled");
        setup.randomizer.pendingRandomnessRequests(COLLECTION_ID)
            .assertEq(1, "pending after settlement");
        setup.deployed.core.retrieveTokenHash(tokenId).assertEq(bytes32(0), "pre-fulfillment hash");

        AuctionAccountingSnapshot memory beforeFulfillment = _snapshotAuctionAccounting(setup);
        _fulfillRandomnessAndAssertBinding(setup, tokenId, requestId, 999);

        setup.deployed.core.ownerOf(tokenId).assertEq(SECOND_BIDDER, "post-fulfillment owner");
        uint256(setup.auctions.retrieveAuctionStatus(tokenId))
            .assertEq(uint256(StreamAuctions.AuctionStatus.SettledWithBid), "status drift");
        _assertAuctionAccountingSnapshot(setup, beforeFulfillment, "fulfillment");
    }

    function testPostExecutionSignerEpochCannotReplayCancelOrBreakAuctionLifecycle() public {
        CompositionSetup memory setup = _deployComposition();
        (
            StreamDrops.DropAuthorization memory authorization,
            bytes memory signature,
            uint256 tokenId,
            uint256 auctionEndTime
        ) = _mintAuctionDropWithSignature(setup, "post-execution-epoch-auction", 31);
        _bid(setup.auctions, tokenId, FIRST_BIDDER, RESERVE_PRICE);
        AuctionSnapshot memory beforeControls = _snapshot(setup, tokenId);
        uint256 signerEpochBefore = setup.deployed.drops.signerEpoch();

        setup.deployed.drops.incrementSignerEpoch();
        setup.deployed.drops.signerEpoch().assertEq(signerEpochBefore + 1, "signer epoch");

        (bool replaySuccess, bytes memory replayReturnData) =
            _callMintDrop(setup, authorization, "post-execution-epoch-auction", signature);
        _assertRevertedWithMessage(replaySuccess, replayReturnData, "Bad epoch");
        _assertSnapshot(setup, tokenId, beforeControls, "epoch replay");

        (bool cancelSuccess, bytes memory cancelReturnData) =
            _callCancelDrop(setup, authorization.dropId);
        _assertRevertedWithMessage(cancelSuccess, cancelReturnData, "Drop consumed");
        _assertSnapshot(setup, tokenId, beforeControls, "epoch cancel");
        setup.deployed.drops.isDropConsumed(authorization.dropId).assertTrue("consumed drop");
        setup.deployed.drops.isDropCancelled(authorization.dropId)
            .assertFalse("cancelled consumed drop");

        _bid(setup.auctions, tokenId, SECOND_BIDDER, SECOND_BID);
        vm.warp(auctionEndTime + 1);
        setup.auctions.claimAuction(tokenId);
        setup.deployed.core.ownerOf(tokenId).assertEq(SECOND_BIDDER, "winner after epoch");
        uint256(setup.auctions.retrieveAuctionStatus(tokenId))
            .assertEq(uint256(StreamAuctions.AuctionStatus.SettledWithBid), "settled");

        AuctionAccountingSnapshot memory beforeFulfillment = _snapshotAuctionAccounting(setup);
        _fulfillRandomnessAndAssertBinding(
            setup, tokenId, setup.randomizer.tokenToRequest(tokenId), 1234
        );
        _assertAuctionAccountingSnapshot(setup, beforeFulfillment, "epoch fulfillment");
    }

    function testSignerRotationAndDropPauseAfterAuctionDropDoNotBlockExistingLifecycle() public {
        CompositionSetup memory setup = _deployComposition();
        (
            StreamDrops.DropAuthorization memory authorization,
            bytes memory signature,
            uint256 tokenId,
            uint256 auctionEndTime
        ) = _mintAuctionDropWithSignature(setup, "post-execution-rotation-auction", 41);
        AuctionSnapshot memory beforeRotation = _snapshot(setup, tokenId);

        setup.deployed.drops.updateTDHsigner(otherSignerAddress());
        (bool replaySuccess, bytes memory replayReturnData) =
            _callMintDrop(setup, authorization, "post-execution-rotation-auction", signature);
        _assertRevertedWithMessage(replaySuccess, replayReturnData, "Wrong signer");
        _assertSnapshot(setup, tokenId, beforeRotation, "rotation replay");

        _setPaused(setup, StreamPauseDomains.DROP_EXECUTION, true);
        (bool pausedReplaySuccess, bytes memory pausedReplayReturnData) =
            _callMintDrop(setup, authorization, "post-execution-rotation-auction", signature);
        _assertRevertedWithMessage(pausedReplaySuccess, pausedReplayReturnData, "Drop paused");
        _assertSnapshot(setup, tokenId, beforeRotation, "drop pause replay");

        _bid(setup.auctions, tokenId, FIRST_BIDDER, RESERVE_PRICE);
        _bid(setup.auctions, tokenId, SECOND_BIDDER, SECOND_BID);
        vm.warp(auctionEndTime + 1);
        setup.auctions.claimAuction(tokenId);

        setup.deployed.core.ownerOf(tokenId).assertEq(SECOND_BIDDER, "winner after rotation");
        uint256(setup.auctions.retrieveAuctionStatus(tokenId))
            .assertEq(uint256(StreamAuctions.AuctionStatus.SettledWithBid), "settled");

        AuctionAccountingSnapshot memory beforeFulfillment = _snapshotAuctionAccounting(setup);
        _fulfillRandomnessAndAssertBinding(
            setup, tokenId, setup.randomizer.tokenToRequest(tokenId), 5678
        );
        setup.deployed.admins.isPaused(StreamPauseDomains.DROP_EXECUTION)
            .assertTrue("drop pause cleared");
        _assertAuctionAccountingSnapshot(setup, beforeFulfillment, "rotation fulfillment");
    }

    function _deployComposition() private returns (CompositionSetup memory setup) {
        setup.deployed = deployStreamWithSigner(PAYOUT, CURATORS_POOL, signerAddress());
        setup.deployed.admins.updateEmergencyRecipient(EMERGENCY_RECIPIENT);
        setup.controller = new CompositionArrngController();
        setup.randomizer = new NextGenRandomizerRNG(
            address(setup.deployed.core), address(setup.deployed.admins), address(setup.controller)
        );
        setup.deployed.core.addRandomizer(COLLECTION_ID, address(setup.randomizer));
        setup.auctions = new StreamAuctions(
            address(setup.deployed.minter),
            address(setup.deployed.core),
            address(setup.deployed.admins),
            address(setup.deployed.drops),
            PAYOUT,
            CURATORS_POOL
        );
        setup.deployed.drops.updateAuctionContract(address(setup.auctions));
    }

    function _mintAuctionDrop(CompositionSetup memory setup, string memory tokenData, uint256 nonce)
        private
        returns (
            StreamDrops.DropAuthorization memory authorization,
            uint256 tokenId,
            uint256 auctionEndTime
        )
    {
        (authorization,, tokenId, auctionEndTime) =
            _mintAuctionDropWithSignature(setup, tokenData, nonce);
    }

    function _mintAuctionDropWithSignature(
        CompositionSetup memory setup,
        string memory tokenData,
        uint256 nonce
    )
        private
        returns (
            StreamDrops.DropAuthorization memory authorization,
            bytes memory signature,
            uint256 tokenId,
            uint256 auctionEndTime
        )
    {
        (authorization, signature) = _buildSignedAuctionAuthorization(
            setup, tokenData, nonce, block.timestamp + 1 days
        );
        setup.deployed.drops.mintDrop(authorization, tokenData, signature);
        tokenId = setup.deployed.drops.retrieveTokenID(authorization.dropId);
        auctionEndTime = authorization.auctionEndTime;

        setup.deployed.core.ownerOf(tokenId).assertEq(address(setup.auctions), "auction custody");
        uint256(setup.auctions.retrieveAuctionStatus(tokenId))
            .assertEq(uint256(StreamAuctions.AuctionStatus.Active), "auction active");
        setup.randomizer.tokenToRequest(tokenId).assertEq(1, "request id");
        setup.randomizer.pendingRandomnessRequests(COLLECTION_ID).assertEq(1, "pending request");
    }

    function _buildSignedAuctionAuthorization(
        CompositionSetup memory setup,
        string memory tokenData,
        uint256 nonce,
        uint256 auctionEndTime
    ) private returns (StreamDrops.DropAuthorization memory authorization, bytes memory signature) {
        authorization = buildAuctionAuthorization(
            setup.deployed.drops,
            POSTER,
            address(0),
            tokenData,
            COLLECTION_ID,
            RESERVE_PRICE,
            auctionEndTime,
            nonce,
            nonce,
            block.timestamp + 2 days
        );
        signature = signAuthorization(setup.deployed.drops, authorization);
    }

    function _bid(StreamAuctions auctions, uint256 tokenId, address bidder, uint256 amount)
        private
    {
        vm.deal(bidder, amount);
        vm.prank(bidder);
        // This test intentionally funds the auction contract through the public
        // bid path while asserting payment invariants after the call.
        // slither-disable-next-line arbitrary-send-eth
        auctions.participateToAuction{ value: amount }(tokenId);
    }

    function _setPaused(CompositionSetup memory setup, bytes32 domain, bool paused) private {
        setup.deployed.admins.setPaused(domain, paused, PAUSE_REASON);
        if (paused) {
            setup.deployed.admins.isPaused(domain).assertTrue("paused domain");
        } else {
            setup.deployed.admins.isPaused(domain).assertFalse("unpaused domain");
        }
    }

    function _snapshot(CompositionSetup memory setup, uint256 tokenId)
        private
        view
        returns (AuctionSnapshot memory snapshot)
    {
        snapshot = AuctionSnapshot({
            status: uint256(setup.auctions.retrieveAuctionStatus(tokenId)),
            owner: setup.deployed.core.ownerOf(tokenId),
            highestBid: setup.auctions.auctionHighestBid(tokenId),
            highestBidder: setup.auctions.auctionHighestBidder(tokenId),
            totalBidderOwed: setup.auctions.totalBidderOwed(),
            totalAuctionBidEscrow: setup.auctions.totalAuctionBidEscrow(),
            totalProceedsOwed: setup.auctions.totalProceedsOwed(),
            totalOwed: setup.auctions.totalOwed(),
            balance: address(setup.auctions).balance,
            pendingRequests: setup.randomizer.pendingRandomnessRequests(COLLECTION_ID),
            randomizerEpoch: setup.deployed.core.viewRandomizerEpoch(COLLECTION_ID),
            collectionRandomizer: setup.deployed.core
            .viewCollectionRandomizerContract(COLLECTION_ID),
            tokenRequest: setup.randomizer.tokenToRequest(tokenId)
        });
    }

    function _snapshotAuctionAccounting(CompositionSetup memory setup)
        private
        view
        returns (AuctionAccountingSnapshot memory snapshot)
    {
        snapshot = AuctionAccountingSnapshot({
            bidderCredit: setup.auctions.auctionBidderCredits(FIRST_BIDDER),
            posterCredit: setup.auctions.auctionPosterCredits(POSTER),
            protocolCredit: setup.auctions.auctionProtocolCredits(PAYOUT),
            curatorCredit: setup.auctions.auctionCuratorCredits(CURATORS_POOL),
            totalOwed: setup.auctions.totalOwed(),
            balance: address(setup.auctions).balance
        });
    }

    function _fulfillRandomnessAndAssertBinding(
        CompositionSetup memory setup,
        uint256 tokenId,
        uint256 requestId,
        uint256 word
    ) private {
        uint256[] memory words = _words(word);
        uint256 randomizerEpoch = setup.deployed.core.viewRandomizerEpoch(COLLECTION_ID);
        bytes32 expectedSeed =
            _expectedSeed(address(setup.randomizer), requestId, tokenId, randomizerEpoch, words);
        bytes32 rawOutputHash = keccak256(abi.encode(words));
        setup.controller.fulfill(setup.randomizer, requestId, words);

        setup.deployed.core.retrieveTokenHash(tokenId).assertEq(expectedSeed, "fulfilled hash");
        uint256(setup.randomizer.randomnessRequestState(requestId))
            .assertEq(
                uint256(StreamRandomizerLifecycle.RandomnessRequestState.Fulfilled), "fulfilled"
            );
        StreamRandomizerLifecycle.RandomnessRequest memory request =
            setup.randomizer.retrieveRandomnessRequest(requestId);
        request.collectionId.assertEq(COLLECTION_ID, "request collection");
        request.tokenId.assertEq(tokenId, "request token");
        request.provider.assertEq(address(setup.randomizer), "request provider");
        request.randomizerEpoch.assertEq(randomizerEpoch, "request epoch");
        request.derivedSeed.assertEq(expectedSeed, "request seed");
        request.rawOutputHash.assertEq(rawOutputHash, "request raw hash");
        setup.randomizer.pendingRandomnessRequests(COLLECTION_ID).assertEq(0, "pending cleared");
    }

    function _assertAuctionAccountingSnapshot(
        CompositionSetup memory setup,
        AuctionAccountingSnapshot memory snapshot,
        string memory label
    ) private view {
        setup.auctions.auctionBidderCredits(FIRST_BIDDER).assertEq(snapshot.bidderCredit, label);
        setup.auctions.auctionPosterCredits(POSTER).assertEq(snapshot.posterCredit, label);
        setup.auctions.auctionProtocolCredits(PAYOUT).assertEq(snapshot.protocolCredit, label);
        setup.auctions.auctionCuratorCredits(CURATORS_POOL).assertEq(snapshot.curatorCredit, label);
        setup.auctions.totalOwed().assertEq(snapshot.totalOwed, label);
        address(setup.auctions).balance.assertEq(snapshot.balance, label);
    }

    function _assertSnapshot(
        CompositionSetup memory setup,
        uint256 tokenId,
        AuctionSnapshot memory beforeSnapshot,
        string memory label
    ) private view {
        uint256(setup.auctions.retrieveAuctionStatus(tokenId))
            .assertEq(beforeSnapshot.status, label);
        setup.deployed.core.ownerOf(tokenId).assertEq(beforeSnapshot.owner, label);
        setup.auctions.auctionHighestBid(tokenId).assertEq(beforeSnapshot.highestBid, label);
        setup.auctions.auctionHighestBidder(tokenId).assertEq(beforeSnapshot.highestBidder, label);
        setup.auctions.totalBidderOwed().assertEq(beforeSnapshot.totalBidderOwed, label);
        setup.auctions.totalAuctionBidEscrow().assertEq(beforeSnapshot.totalAuctionBidEscrow, label);
        setup.auctions.totalProceedsOwed().assertEq(beforeSnapshot.totalProceedsOwed, label);
        setup.auctions.totalOwed().assertEq(beforeSnapshot.totalOwed, label);
        address(setup.auctions).balance.assertEq(beforeSnapshot.balance, label);
        setup.randomizer.pendingRandomnessRequests(COLLECTION_ID)
            .assertEq(beforeSnapshot.pendingRequests, label);
        setup.deployed.core.viewRandomizerEpoch(COLLECTION_ID)
            .assertEq(beforeSnapshot.randomizerEpoch, label);
        setup.deployed.core.viewCollectionRandomizerContract(COLLECTION_ID)
            .assertEq(beforeSnapshot.collectionRandomizer, label);
        setup.randomizer.tokenToRequest(tokenId).assertEq(beforeSnapshot.tokenRequest, label);
    }

    function _callMintDrop(
        CompositionSetup memory setup,
        StreamDrops.DropAuthorization memory authorization,
        string memory tokenData,
        bytes memory signature
    ) private returns (bool success, bytes memory returnData) {
        (success, returnData) = address(setup.deployed.drops)
            .call(
                abi.encodeWithSelector(
                    setup.deployed.drops.mintDrop.selector, authorization, tokenData, signature
                )
            );
    }

    function _callCancelDrop(CompositionSetup memory setup, bytes32 dropId)
        private
        returns (bool success, bytes memory returnData)
    {
        (success, returnData) = address(setup.deployed.drops)
            .call(abi.encodeWithSelector(setup.deployed.drops.cancelDrop.selector, dropId));
    }

    function _assertRevertedWithMessage(
        bool success,
        bytes memory returnData,
        string memory expectedMessage
    ) private pure {
        success.assertFalse("call unexpectedly succeeded");
        // Pin the current nested Error(string) revert surface. If the production
        // path moves to custom errors, update these low-level assertions.
        keccak256(returnData)
            .assertEq(
                keccak256(abi.encodeWithSignature("Error(string)", expectedMessage)),
                "unexpected revert"
            );
    }

    function _words(uint256 word) private pure returns (uint256[] memory words) {
        words = new uint256[](1);
        words[0] = word;
    }

    function _expectedSeed(
        address provider,
        uint256 requestId,
        uint256 tokenId,
        uint256 randomizerEpoch,
        uint256[] memory words
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                RANDOMNESS_SEED_TYPEHASH,
                provider,
                requestId,
                COLLECTION_ID,
                tokenId,
                randomizerEpoch,
                keccak256(abi.encode(words))
            )
        );
    }
}

contract CompositionArrngController {
    uint256 public nextRequestId = 1;

    function requestRandomWords(uint256, address) external payable returns (uint256 requestId) {
        requestId = nextRequestId;
        nextRequestId++;
    }

    function fulfill(NextGenRandomizerRNG randomizer, uint256 requestId, uint256[] memory words)
        external
    {
        randomizer.receiveRandomness(requestId, words);
    }
}
