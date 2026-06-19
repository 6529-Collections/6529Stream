// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/RandomizerRNG.sol";
import "../smart-contracts/StreamCore.sol";
import "../smart-contracts/StreamDrops.sol";
import "../smart-contracts/StreamPauseDomains.sol";
import "../smart-contracts/StreamRandomizerLifecycle.sol";
import "./helpers/Assertions.sol";
import "./helpers/DropAuthTestHelper.sol";
import "./helpers/StreamFixture.sol";

contract StreamFixedPriceRandomizerCompositionTest is DropAuthTestHelper, StreamFixture {
    using Assertions for address;
    using Assertions for bool;
    using Assertions for bytes32;
    using Assertions for string;
    using Assertions for uint256;

    uint256 private constant COLLECTION_ID = 1;
    uint256 private constant PRICE = 4 ether;
    address private constant POSTER = address(0x1001);
    address private constant RECIPIENT = address(0x5005);
    address private constant PAYOUT = address(0x2001);
    address private constant CURATORS_POOL = address(0x3001);
    address private constant WITHDRAW_RECIPIENT = address(0x6001);
    bytes32 private constant PAUSE_REASON = keccak256("fixed-price-randomizer-composition");
    bytes32 private constant RANDOMNESS_SEED_TYPEHASH = keccak256(
        "6529StreamRandomnessSeed(address provider,uint256 requestId,uint256 collectionId,uint256 tokenId,uint256 randomizerEpoch,bytes32 rawOutputHash)"
    );
    bytes4 private constant ERROR_STRING_SELECTOR = bytes4(keccak256("Error(string)"));

    struct CompositionSetup {
        DeployedStream deployed;
        NextGenRandomizerRNG randomizer;
        FixedPriceArrngController controller;
    }

    struct FixedPriceSnapshot {
        address owner;
        uint256 posterCredit;
        uint256 protocolCredit;
        uint256 curatorCredit;
        uint256 totalPosterOwed;
        uint256 totalProtocolOwed;
        uint256 totalCuratorOwed;
        uint256 totalOwed;
        uint256 balance;
        uint256 pendingRequests;
        uint256 randomizerEpoch;
        address collectionRandomizer;
        uint256 tokenRequest;
        bytes32 tokenHash;
    }

    function testPausedRandomnessRequestRejectsPaidFixedPriceDropWithoutConsumingOrCrediting()
        public
    {
        CompositionSetup memory setup = _deployComposition();
        uint256 nextTokenId = setup.deployed.core.viewTokensIndexMin(COLLECTION_ID)
            + setup.deployed.core.viewCirSupply(COLLECTION_ID);
        uint256 supplyBefore = setup.deployed.core.totalSupply();
        uint256 circulationBefore = setup.deployed.core.viewCirSupply(COLLECTION_ID);
        uint256 dropCountBefore = setup.deployed.drops.retrieveDrops().length;
        (StreamDrops.DropAuthorization memory authorization, bytes memory signature) =
            _buildSignedFixedPriceAuthorization(setup, "paused-fixed-price-arrng", 1);
        vm.deal(address(this), 20 ether);

        _setPaused(setup, StreamPauseDomains.RANDOMNESS_REQUEST, true);
        (bool success, bytes memory returnData) =
            _callMintDropWithValue(setup, authorization, "paused-fixed-price-arrng", signature);
        _assertRevertedWithMessage(success, returnData, "Randomness paused");

        setup.deployed.drops.isDropConsumed(authorization.dropId)
            .assertFalse("paused request consumed drop");
        setup.deployed.drops.retrieveTokenID(authorization.dropId).assertEq(0, "paused token id");
        setup.deployed.core.totalSupply().assertEq(supplyBefore, "paused supply");
        setup.deployed.core.viewCirSupply(COLLECTION_ID)
            .assertEq(circulationBefore, "paused circulation");
        setup.deployed.drops.retrieveDrops().length.assertEq(dropCountBefore, "paused drop count");
        setup.randomizer.pendingRandomnessRequests(COLLECTION_ID).assertEq(0, "paused pending");
        _assertNoFixedPriceAccounting(setup, "paused rollback");

        _setPaused(setup, StreamPauseDomains.RANDOMNESS_REQUEST, false);
        setup.deployed.drops.mintDrop{ value: PRICE }(
            authorization, "paused-fixed-price-arrng", signature
        );
        _assertSuccessfulFixedPriceMint(setup, authorization, nextTokenId, "retried");
    }

    function testPostExecutionSignerLifecycleDoesNotDisturbCreditsOrPendingRequest() public {
        CompositionSetup memory setup = _deployComposition();
        (
            StreamDrops.DropAuthorization memory authorization,
            bytes memory signature,
            uint256 tokenId
        ) = _mintFixedPriceDropWithSignature(setup, "post-execution-fixed-price", 11);
        FixedPriceSnapshot memory beforeControls = _snapshot(setup, tokenId);
        uint256 signerEpochBefore = setup.deployed.drops.signerEpoch();
        vm.deal(address(this), 20 ether);

        setup.deployed.drops.incrementSignerEpoch();
        setup.deployed.drops.signerEpoch().assertEq(signerEpochBefore + 1, "signer epoch");
        (bool replaySuccess, bytes memory replayReturnData) =
            _callMintDropWithValue(setup, authorization, "post-execution-fixed-price", signature);
        _assertRevertedWithMessage(replaySuccess, replayReturnData, "Bad epoch");
        _assertSnapshot(setup, tokenId, beforeControls, "epoch replay");

        setup.deployed.drops.updateTDHsigner(otherSignerAddress());
        (bool rotationReplaySuccess, bytes memory rotationReplayReturnData) =
            _callMintDropWithValue(setup, authorization, "post-execution-fixed-price", signature);
        _assertRevertedWithMessage(rotationReplaySuccess, rotationReplayReturnData, "Wrong signer");
        _assertSnapshot(setup, tokenId, beforeControls, "rotation replay");

        (bool cancelSuccess, bytes memory cancelReturnData) =
            _callCancelDrop(setup, authorization.dropId);
        _assertRevertedWithMessage(cancelSuccess, cancelReturnData, "Drop consumed");
        _assertSnapshot(setup, tokenId, beforeControls, "consumed cancel");
        setup.deployed.drops.isDropConsumed(authorization.dropId).assertTrue("consumed drop");
        setup.deployed.drops.isDropCancelled(authorization.dropId)
            .assertFalse("cancelled consumed drop");

        _fulfillRandomnessAndAssertBinding(
            setup, tokenId, setup.randomizer.tokenToRequest(tokenId), 1234
        );
        _assertFixedPriceAccountingSnapshot(setup, beforeControls, "post-fulfillment credits");
    }

    function testFixedPriceCreditWithdrawalsBeforeFulfillmentPreserveRequestBinding() public {
        CompositionSetup memory setup = _deployComposition();
        (,, uint256 tokenId) =
            _mintFixedPriceDropWithSignature(setup, "withdraw-before-fulfillment", 21);
        uint256 requestId = setup.randomizer.tokenToRequest(tokenId);
        uint256 recipientBalanceBefore = WITHDRAW_RECIPIENT.balance;

        vm.prank(POSTER);
        setup.deployed.drops.withdrawFixedPriceCreditTo(payable(WITHDRAW_RECIPIENT));
        vm.prank(PAYOUT);
        setup.deployed.drops.withdrawFixedPriceCreditTo(payable(WITHDRAW_RECIPIENT));

        WITHDRAW_RECIPIENT.balance.assertEq(recipientBalanceBefore + 3 ether, "withdraw recipient");
        setup.deployed.drops.fixedPricePosterCredits(POSTER).assertEq(0, "poster credit");
        setup.deployed.drops.fixedPriceProtocolCredits(PAYOUT).assertEq(0, "protocol credit");
        setup.deployed.drops.fixedPriceCuratorReserveCredits(CURATORS_POOL)
            .assertEq(1 ether, "curator reserve credit");
        setup.deployed.drops.totalFixedPricePosterOwed().assertEq(0, "poster owed");
        setup.deployed.drops.totalFixedPriceProtocolOwed().assertEq(0, "protocol owed");
        setup.deployed.drops.totalFixedPriceCuratorReserveOwed().assertEq(1 ether, "curator owed");
        setup.deployed.drops.totalOwed().assertEq(1 ether, "remaining owed");
        address(setup.deployed.drops).balance.assertEq(1 ether, "remaining balance");
        setup.randomizer.tokenToRequest(tokenId).assertEq(requestId, "request binding");
        setup.randomizer.pendingRandomnessRequests(COLLECTION_ID)
            .assertEq(1, "pending before fulfillment");

        FixedPriceSnapshot memory beforeFulfillment = _snapshot(setup, tokenId);
        _fulfillRandomnessAndAssertBinding(setup, tokenId, requestId, 5678);
        _assertFixedPriceAccountingSnapshot(setup, beforeFulfillment, "withdraw fulfillment");
    }

    function _deployComposition() private returns (CompositionSetup memory setup) {
        setup.deployed = deployStreamWithSigner(PAYOUT, CURATORS_POOL, signerAddress());
        setup.controller = new FixedPriceArrngController();
        setup.randomizer = new NextGenRandomizerRNG(
            address(setup.deployed.core), address(setup.deployed.admins), address(setup.controller)
        );
        setup.deployed.core.addRandomizer(COLLECTION_ID, address(setup.randomizer));
    }

    function _mintFixedPriceDropWithSignature(
        CompositionSetup memory setup,
        string memory tokenData,
        uint256 nonce
    )
        private
        returns (
            StreamDrops.DropAuthorization memory authorization,
            bytes memory signature,
            uint256 tokenId
        )
    {
        (authorization, signature) = _buildSignedFixedPriceAuthorization(setup, tokenData, nonce);
        vm.deal(address(this), 20 ether);
        setup.deployed.drops.mintDrop{ value: PRICE }(authorization, tokenData, signature);
        tokenId = setup.deployed.drops.retrieveTokenID(authorization.dropId);
        _assertSuccessfulFixedPriceMint(setup, authorization, tokenId, "minted");
    }

    function _buildSignedFixedPriceAuthorization(
        CompositionSetup memory setup,
        string memory tokenData,
        uint256 nonce
    ) private returns (StreamDrops.DropAuthorization memory authorization, bytes memory) {
        authorization = buildFixedPriceAuthorization(
            setup.deployed.drops,
            POSTER,
            RECIPIENT,
            address(this),
            tokenData,
            COLLECTION_ID,
            PRICE,
            nonce,
            nonce + 1_000,
            block.timestamp + 2 days
        );
        return (authorization, signAuthorization(setup.deployed.drops, authorization));
    }

    function _assertSuccessfulFixedPriceMint(
        CompositionSetup memory setup,
        StreamDrops.DropAuthorization memory authorization,
        uint256 tokenId,
        string memory label
    ) private view {
        setup.deployed.core.ownerOf(tokenId).assertEq(RECIPIENT, label);
        setup.deployed.drops.retrieveTokenID(authorization.dropId).assertEq(tokenId, label);
        setup.deployed.drops.isDropConsumed(authorization.dropId).assertTrue(label);
        setup.deployed.drops.fixedPricePosterCredits(POSTER).assertEq(2 ether, label);
        setup.deployed.drops.fixedPriceProtocolCredits(PAYOUT).assertEq(1 ether, label);
        setup.deployed.drops.fixedPriceCuratorReserveCredits(CURATORS_POOL).assertEq(1 ether, label);
        setup.deployed.drops.totalFixedPricePosterOwed().assertEq(2 ether, label);
        setup.deployed.drops.totalFixedPriceProtocolOwed().assertEq(1 ether, label);
        setup.deployed.drops.totalFixedPriceCuratorReserveOwed().assertEq(1 ether, label);
        setup.deployed.drops.totalOwed().assertEq(PRICE, label);
        address(setup.deployed.drops).balance.assertEq(PRICE, label);
        setup.randomizer.pendingRandomnessRequests(COLLECTION_ID).assertEq(1, label);
        setup.randomizer.tokenToRequest(tokenId).assertEq(setup.controller.lastRequestId(), label);
        setup.deployed.core.retrieveTokenHash(tokenId).assertEq(bytes32(0), label);
    }

    function _assertNoFixedPriceAccounting(CompositionSetup memory setup, string memory label)
        private
        view
    {
        setup.deployed.drops.fixedPricePosterCredits(POSTER).assertEq(0, label);
        setup.deployed.drops.fixedPriceProtocolCredits(PAYOUT).assertEq(0, label);
        setup.deployed.drops.fixedPriceCuratorReserveCredits(CURATORS_POOL).assertEq(0, label);
        setup.deployed.drops.totalFixedPricePosterOwed().assertEq(0, label);
        setup.deployed.drops.totalFixedPriceProtocolOwed().assertEq(0, label);
        setup.deployed.drops.totalFixedPriceCuratorReserveOwed().assertEq(0, label);
        setup.deployed.drops.totalOwed().assertEq(0, label);
        address(setup.deployed.drops).balance.assertEq(0, label);
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
        returns (FixedPriceSnapshot memory snapshot)
    {
        snapshot = FixedPriceSnapshot({
            owner: setup.deployed.core.ownerOf(tokenId),
            posterCredit: setup.deployed.drops.fixedPricePosterCredits(POSTER),
            protocolCredit: setup.deployed.drops.fixedPriceProtocolCredits(PAYOUT),
            curatorCredit: setup.deployed.drops.fixedPriceCuratorReserveCredits(CURATORS_POOL),
            totalPosterOwed: setup.deployed.drops.totalFixedPricePosterOwed(),
            totalProtocolOwed: setup.deployed.drops.totalFixedPriceProtocolOwed(),
            totalCuratorOwed: setup.deployed.drops.totalFixedPriceCuratorReserveOwed(),
            totalOwed: setup.deployed.drops.totalOwed(),
            balance: address(setup.deployed.drops).balance,
            pendingRequests: setup.randomizer.pendingRandomnessRequests(COLLECTION_ID),
            randomizerEpoch: setup.deployed.core.viewRandomizerEpoch(COLLECTION_ID),
            collectionRandomizer: setup.deployed.core
            .viewCollectionRandomizerContract(COLLECTION_ID),
            tokenRequest: setup.randomizer.tokenToRequest(tokenId),
            tokenHash: setup.deployed.core.retrieveTokenHash(tokenId)
        });
    }

    function _assertSnapshot(
        CompositionSetup memory setup,
        uint256 tokenId,
        FixedPriceSnapshot memory beforeSnapshot,
        string memory label
    ) private view {
        setup.deployed.core.ownerOf(tokenId).assertEq(beforeSnapshot.owner, label);
        _assertFixedPriceAccountingSnapshot(setup, beforeSnapshot, label);
        setup.randomizer.pendingRandomnessRequests(COLLECTION_ID)
            .assertEq(beforeSnapshot.pendingRequests, label);
        setup.deployed.core.viewRandomizerEpoch(COLLECTION_ID)
            .assertEq(beforeSnapshot.randomizerEpoch, label);
        setup.deployed.core.viewCollectionRandomizerContract(COLLECTION_ID)
            .assertEq(beforeSnapshot.collectionRandomizer, label);
        setup.randomizer.tokenToRequest(tokenId).assertEq(beforeSnapshot.tokenRequest, label);
        setup.deployed.core.retrieveTokenHash(tokenId).assertEq(beforeSnapshot.tokenHash, label);
    }

    function _assertFixedPriceAccountingSnapshot(
        CompositionSetup memory setup,
        FixedPriceSnapshot memory snapshot,
        string memory label
    ) private view {
        setup.deployed.drops.fixedPricePosterCredits(POSTER).assertEq(snapshot.posterCredit, label);
        setup.deployed.drops.fixedPriceProtocolCredits(PAYOUT)
            .assertEq(snapshot.protocolCredit, label);
        setup.deployed.drops.fixedPriceCuratorReserveCredits(CURATORS_POOL)
            .assertEq(snapshot.curatorCredit, label);
        setup.deployed.drops.totalFixedPricePosterOwed().assertEq(snapshot.totalPosterOwed, label);
        setup.deployed.drops.totalFixedPriceProtocolOwed()
            .assertEq(snapshot.totalProtocolOwed, label);
        setup.deployed.drops.totalFixedPriceCuratorReserveOwed()
            .assertEq(snapshot.totalCuratorOwed, label);
        setup.deployed.drops.totalOwed().assertEq(snapshot.totalOwed, label);
        address(setup.deployed.drops).balance.assertEq(snapshot.balance, label);
    }

    function _callMintDropWithValue(
        CompositionSetup memory setup,
        StreamDrops.DropAuthorization memory authorization,
        string memory tokenData,
        bytes memory signature
    ) private returns (bool success, bytes memory returnData) {
        (success, returnData) = address(setup.deployed.drops).call{ value: PRICE }(
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

    function _assertRevertedWithMessage(
        bool success,
        bytes memory returnData,
        string memory expectedMessage
    ) private pure {
        success.assertFalse("call unexpectedly succeeded");
        // Pin the current nested Error(string) revert surface. If the production
        // path moves to custom errors, update these low-level assertions.
        bytes4 selector = bytes4(returnData);
        require(selector == ERROR_STRING_SELECTOR, "unexpected revert selector");
        _decodeErrorString(returnData).assertEq(expectedMessage, "unexpected revert");
    }

    function _decodeErrorString(bytes memory returnData) private pure returns (string memory) {
        require(returnData.length >= 4, "short revert");
        bytes memory encodedReason = new bytes(returnData.length - 4);
        for (uint256 i = 0; i < encodedReason.length; i++) {
            encodedReason[i] = returnData[i + 4];
        }
        return abi.decode(encodedReason, (string));
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

contract FixedPriceArrngController {
    uint256 public nextRequestId = 1;
    uint256 public lastRequestId;

    function requestRandomWords(uint256, address) external payable returns (uint256 requestId) {
        requestId = nextRequestId;
        lastRequestId = requestId;
        nextRequestId++;
    }

    // Permissionless on purpose: this test double models a cooperative arRNG
    // controller, not production access control.
    function fulfill(NextGenRandomizerRNG randomizer, uint256 requestId, uint256[] memory words)
        external
    {
        randomizer.receiveRandomness(requestId, words);
    }
}
