// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/RandomizerRNG.sol";
import "../smart-contracts/RandomizerVRF.sol";
import "../smart-contracts/StreamAdmins.sol";
import "../smart-contracts/StreamRandomizerLifecycle.sol";
import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";
import "./mocks/MockRandomizerCore.sol";

contract StreamRandomizerRetryTest is CharacterizationTestBase {
    using Assertions for bool;
    using Assertions for bytes32;
    using Assertions for uint256;

    uint256 private constant TOKEN_ID = 10_000_000_000;
    uint256 private constant COLLECTION_ID = 1;
    bytes32 private constant RANDOMNESS_FULFILLED_TOPIC =
        keccak256("RandomnessFulfilled(uint256,uint256,uint256,bytes32)");
    bytes32 private constant RANDOMNESS_RETRIED_TOPIC = keccak256(
        "RandomnessPostProcessingRetried(uint256,uint256,uint256,address,uint256,uint256,bytes32)"
    );
    bytes32 private constant RANDOMNESS_RETRY_FAILED_TOPIC = keccak256(
        "RandomnessPostProcessingRetryFailed(uint256,uint256,uint256,address,uint256,uint256,bytes32,bytes32)"
    );

    function testVrfRetryCompletesFailedPostProcessingWithStoredSeed() public {
        (MockRandomizerCore core, RetryVrfCoordinator coordinator, NextGenRandomizerVRF vrf) =
            _deployVrfRetry();
        uint256[] memory words = _words(777);
        bytes32 expectedSeed = _failVrfPostProcessing(core, coordinator, vrf, words);

        core.setRejectTokenHash(false);
        vm.recordLogs();
        vrf.retryRandomnessPostProcessing(1);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        _assertRetrySucceeded(logs, address(vrf), 1, TOKEN_ID, 1, expectedSeed);
        _assertRandomnessFulfilled(logs, address(vrf), 1, TOKEN_ID, expectedSeed);
        core.retrieveTokenHash(TOKEN_ID).assertEq(expectedSeed, "token hash");
        StreamRandomizerLifecycle.RandomnessRequest memory request =
            vrf.retrieveRandomnessRequest(1);
        uint256(request.state)
            .assertEq(uint256(StreamRandomizerLifecycle.RandomnessRequestState.Fulfilled), "state");
        request.derivedSeed.assertEq(expectedSeed, "seed changed");
        request.failureDataHash.assertEq(bytes32(0), "failure hash");
        request.postProcessingRetryCount.assertEq(1, "retry count");
        vrf.pendingRandomnessRequests(COLLECTION_ID).assertEq(0, "pending collection");
        vrf.totalPendingRandomnessRequests().assertEq(0, "pending total");
    }

    function testArrngRetryCompletesFailedPostProcessingWithStoredSeed() public {
        (MockRandomizerCore core, RetryArrngController controller, NextGenRandomizerRNG rng) =
            _deployArrngRetry();
        uint256[] memory words = _words(999);
        bytes32 expectedSeed = _failArrngPostProcessing(core, controller, rng, words);

        core.setRejectTokenHash(false);
        vm.recordLogs();
        rng.retryRandomnessPostProcessing(1);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        _assertRetrySucceeded(logs, address(rng), 1, TOKEN_ID, 1, expectedSeed);
        _assertRandomnessFulfilled(logs, address(rng), 1, TOKEN_ID, expectedSeed);
        core.retrieveTokenHash(TOKEN_ID).assertEq(expectedSeed, "token hash");
        StreamRandomizerLifecycle.RandomnessRequest memory request =
            rng.retrieveRandomnessRequest(1);
        uint256(request.state)
            .assertEq(uint256(StreamRandomizerLifecycle.RandomnessRequestState.Fulfilled), "state");
        request.derivedSeed.assertEq(expectedSeed, "seed changed");
        request.failureDataHash.assertEq(bytes32(0), "failure hash");
        request.postProcessingRetryCount.assertEq(1, "retry count");
        rng.pendingRandomnessRequests(COLLECTION_ID).assertEq(0, "pending collection");
        rng.totalPendingRandomnessRequests().assertEq(0, "pending total");
    }

    function testRetryRejectsUnauthorizedCallerAndPreservesFailure() public {
        (MockRandomizerCore core, RetryVrfCoordinator coordinator, NextGenRandomizerVRF vrf) =
            _deployVrfRetry();
        bytes32 expectedSeed = _failVrfPostProcessing(core, coordinator, vrf, _words(777));

        core.setRejectTokenHash(false);
        vm.prank(address(0xBEEF));
        vm.expectRevert("Not allowed");
        vrf.retryRandomnessPostProcessing(1);

        StreamRandomizerLifecycle.RandomnessRequest memory request =
            vrf.retrieveRandomnessRequest(1);
        uint256(request.state)
            .assertEq(
                uint256(StreamRandomizerLifecycle.RandomnessRequestState.FailedPostProcessing),
                "state"
            );
        request.derivedSeed.assertEq(expectedSeed, "seed changed");
        request.postProcessingRetryCount.assertEq(0, "retry count");
        core.retrieveTokenHash(TOKEN_ID).assertEq(bytes32(0), "token hash");
    }

    function testRetryAfterTerminalFulfillmentFails() public {
        (MockRandomizerCore core, RetryVrfCoordinator coordinator, NextGenRandomizerVRF vrf) =
            _deployVrfRetry();
        vm.prank(address(core));
        vrf.calculateTokenHash(COLLECTION_ID, TOKEN_ID, 123);
        coordinator.fulfill(vrf, 1, _words(777));

        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRandomizerLifecycle.RandomnessRequestNotFailedPostProcessing.selector,
                uint256(1),
                StreamRandomizerLifecycle.RandomnessRequestState.Fulfilled
            )
        );
        vrf.retryRandomnessPostProcessing(1);
    }

    function testRetryLimitBoundsRepeatedDeterministicFailures() public {
        (MockRandomizerCore core, RetryVrfCoordinator coordinator, NextGenRandomizerVRF vrf) =
            _deployVrfRetry();
        uint256[] memory words = _words(777);
        bytes32 expectedSeed = _failVrfPostProcessing(core, coordinator, vrf, words);
        bytes32 failureDataHash = _failureDataHash();

        vrf.MAX_RANDOMNESS_POST_PROCESSING_RETRIES().assertEq(3, "max retries");
        _assertRetryAttemptFails(vrf, 1, expectedSeed, failureDataHash);
        _assertRetryAttemptFails(vrf, 2, expectedSeed, failureDataHash);
        _assertRetryAttemptFails(vrf, 3, expectedSeed, failureDataHash);

        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRandomizerLifecycle.RandomnessPostProcessingRetryLimitReached.selector,
                uint256(1),
                vrf.MAX_RANDOMNESS_POST_PROCESSING_RETRIES(),
                vrf.MAX_RANDOMNESS_POST_PROCESSING_RETRIES()
            )
        );
        vrf.retryRandomnessPostProcessing(1);
    }

    function testRetryRejectsChangedTokenCollectionBinding() public {
        (MockRandomizerCore core, RetryVrfCoordinator coordinator, NextGenRandomizerVRF vrf) =
            _deployVrfRetry();
        _failVrfPostProcessing(core, coordinator, vrf, _words(777));

        core.setRejectTokenHash(false);
        core.setTokenCollection(TOKEN_ID, COLLECTION_ID + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRandomizerLifecycle.WrongRandomnessTokenCollection.selector,
                uint256(1),
                TOKEN_ID,
                COLLECTION_ID,
                COLLECTION_ID + 1
            )
        );
        vrf.retryRandomnessPostProcessing(1);

        StreamRandomizerLifecycle.RandomnessRequest memory request =
            vrf.retrieveRandomnessRequest(1);
        uint256(request.state)
            .assertEq(
                uint256(StreamRandomizerLifecycle.RandomnessRequestState.FailedPostProcessing),
                "state"
            );
        request.postProcessingRetryCount.assertEq(0, "retry count");
        core.retrieveTokenHash(TOKEN_ID).assertEq(bytes32(0), "token hash");
    }

    function testRetryRejectsChangedRandomizerEpoch() public {
        (MockRandomizerCore core, RetryVrfCoordinator coordinator, NextGenRandomizerVRF vrf) =
            _deployVrfRetry();
        _failVrfPostProcessing(core, coordinator, vrf, _words(777));

        core.setRejectTokenHash(false);
        core.setRandomizer(COLLECTION_ID, address(vrf), 2);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRandomizerLifecycle.StaleRandomnessRequest.selector,
                uint256(1),
                uint256(1),
                uint256(2),
                address(vrf),
                address(vrf)
            )
        );
        vrf.retryRandomnessPostProcessing(1);

        StreamRandomizerLifecycle.RandomnessRequest memory request =
            vrf.retrieveRandomnessRequest(1);
        uint256(request.state)
            .assertEq(
                uint256(StreamRandomizerLifecycle.RandomnessRequestState.FailedPostProcessing),
                "state"
            );
        request.postProcessingRetryCount.assertEq(0, "retry count");
        core.retrieveTokenHash(TOKEN_ID).assertEq(bytes32(0), "token hash");
    }

    function testRetryRejectsChangedRandomizerProvider() public {
        (MockRandomizerCore core, RetryVrfCoordinator coordinator, NextGenRandomizerVRF vrf) =
            _deployVrfRetry();
        _failVrfPostProcessing(core, coordinator, vrf, _words(777));

        address replacementProvider = address(0xCAFE);
        core.setRejectTokenHash(false);
        core.setRandomizer(COLLECTION_ID, replacementProvider, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRandomizerLifecycle.StaleRandomnessRequest.selector,
                uint256(1),
                uint256(1),
                uint256(1),
                address(vrf),
                replacementProvider
            )
        );
        vrf.retryRandomnessPostProcessing(1);

        StreamRandomizerLifecycle.RandomnessRequest memory request =
            vrf.retrieveRandomnessRequest(1);
        uint256(request.state)
            .assertEq(
                uint256(StreamRandomizerLifecycle.RandomnessRequestState.FailedPostProcessing),
                "state"
            );
        request.postProcessingRetryCount.assertEq(0, "retry count");
        core.retrieveTokenHash(TOKEN_ID).assertEq(bytes32(0), "token hash");
    }

    function _assertRetryAttemptFails(
        NextGenRandomizerVRF vrf,
        uint256 retryCount,
        bytes32 expectedSeed,
        bytes32 failureDataHash
    ) private {
        vm.recordLogs();
        vrf.retryRandomnessPostProcessing(1);
        _assertRetryFailed(
            vm.getRecordedLogs(), address(vrf), 1, TOKEN_ID, retryCount, expectedSeed
        );

        StreamRandomizerLifecycle.RandomnessRequest memory request =
            vrf.retrieveRandomnessRequest(1);
        uint256(request.state)
            .assertEq(
                uint256(StreamRandomizerLifecycle.RandomnessRequestState.FailedPostProcessing),
                "state"
            );
        request.failureDataHash.assertEq(failureDataHash, "failure hash");
        request.postProcessingRetryCount.assertEq(retryCount, "retry count");
    }

    function _deployVrfRetry()
        private
        returns (MockRandomizerCore core, RetryVrfCoordinator coordinator, NextGenRandomizerVRF vrf)
    {
        StreamAdmins admins = new StreamAdmins(address(this));
        core = new MockRandomizerCore();
        coordinator = new RetryVrfCoordinator();
        vrf = new NextGenRandomizerVRF(1, address(coordinator), address(core), address(admins));
        core.setRandomizer(COLLECTION_ID, address(vrf), 1);
        core.setTokenCollection(TOKEN_ID, COLLECTION_ID);
    }

    function _deployArrngRetry()
        private
        returns (MockRandomizerCore core, RetryArrngController controller, NextGenRandomizerRNG rng)
    {
        StreamAdmins admins = new StreamAdmins(address(this));
        core = new MockRandomizerCore();
        controller = new RetryArrngController();
        rng = new NextGenRandomizerRNG(address(core), address(admins), address(controller));
        core.setRandomizer(COLLECTION_ID, address(rng), 1);
        core.setTokenCollection(TOKEN_ID, COLLECTION_ID);
    }

    function _failVrfPostProcessing(
        MockRandomizerCore core,
        RetryVrfCoordinator coordinator,
        NextGenRandomizerVRF vrf,
        uint256[] memory words
    ) private returns (bytes32 expectedSeed) {
        core.setRejectTokenHash(true);
        vm.prank(address(core));
        vrf.calculateTokenHash(COLLECTION_ID, TOKEN_ID, 123);
        expectedSeed = _expectedSeed(address(vrf), 1, words);
        coordinator.fulfill(vrf, 1, words);
        _assertFailedRequest(vrf.retrieveRandomnessRequest(1), expectedSeed);
    }

    function _failArrngPostProcessing(
        MockRandomizerCore core,
        RetryArrngController controller,
        NextGenRandomizerRNG rng,
        uint256[] memory words
    ) private returns (bytes32 expectedSeed) {
        core.setRejectTokenHash(true);
        vm.prank(address(core));
        rng.calculateTokenHash(COLLECTION_ID, TOKEN_ID, 123);
        expectedSeed = _expectedSeed(address(rng), 1, words);
        controller.fulfill(rng, 1, words);
        _assertFailedRequest(rng.retrieveRandomnessRequest(1), expectedSeed);
    }

    function _assertFailedRequest(
        StreamRandomizerLifecycle.RandomnessRequest memory request,
        bytes32 expectedSeed
    ) private pure {
        uint256(request.state)
            .assertEq(
                uint256(StreamRandomizerLifecycle.RandomnessRequestState.FailedPostProcessing),
                "failed state"
            );
        request.derivedSeed.assertEq(expectedSeed, "seed");
        request.failureDataHash.assertEq(_failureDataHash(), "failure hash");
        request.postProcessingRetryCount.assertEq(0, "retry count");
    }

    function _assertRetrySucceeded(
        Vm.Log[] memory logs,
        address emitter,
        uint256 requestId,
        uint256 tokenId,
        uint256 retryCount,
        bytes32 expectedSeed
    ) private pure {
        bool found = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].emitter == emitter && logs[i].topics.length == 4
                    && logs[i].topics[0] == RANDOMNESS_RETRIED_TOPIC
                    && uint256(logs[i].topics[1]) == requestId
                    && uint256(logs[i].topics[2]) == COLLECTION_ID
                    && uint256(logs[i].topics[3]) == tokenId
            ) {
                (
                    address actualProvider,
                    uint256 actualEpoch,
                    uint256 actualRetryCount,
                    bytes32 actualSeed
                ) = abi.decode(logs[i].data, (address, uint256, uint256, bytes32));
                found = actualProvider == emitter && actualEpoch == 1
                    && actualRetryCount == retryCount && actualSeed == expectedSeed;
            }
        }
        found.assertTrue("retry event");
    }

    function _assertRetryFailed(
        Vm.Log[] memory logs,
        address emitter,
        uint256 requestId,
        uint256 tokenId,
        uint256 retryCount,
        bytes32 expectedSeed
    ) private pure {
        bool found = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].emitter == emitter && logs[i].topics.length == 4
                    && logs[i].topics[0] == RANDOMNESS_RETRY_FAILED_TOPIC
                    && uint256(logs[i].topics[1]) == requestId
                    && uint256(logs[i].topics[2]) == COLLECTION_ID
                    && uint256(logs[i].topics[3]) == tokenId
            ) {
                (
                    address actualProvider,
                    uint256 actualEpoch,
                    uint256 actualRetryCount,
                    bytes32 actualSeed,
                    bytes32 actualFailureDataHash
                ) = abi.decode(logs[i].data, (address, uint256, uint256, bytes32, bytes32));
                found = actualProvider == emitter && actualEpoch == 1
                    && actualRetryCount == retryCount && actualSeed == expectedSeed
                    && actualFailureDataHash == _failureDataHash();
            }
        }
        found.assertTrue("retry failed event");
    }

    function _assertRandomnessFulfilled(
        Vm.Log[] memory logs,
        address emitter,
        uint256 requestId,
        uint256 tokenId,
        bytes32 expectedSeed
    ) private pure {
        bool found = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].emitter == emitter && logs[i].topics.length == 4
                    && logs[i].topics[0] == RANDOMNESS_FULFILLED_TOPIC
                    && uint256(logs[i].topics[1]) == requestId
                    && uint256(logs[i].topics[2]) == COLLECTION_ID
                    && uint256(logs[i].topics[3]) == tokenId
            ) {
                found = abi.decode(logs[i].data, (bytes32)) == expectedSeed;
            }
        }
        found.assertTrue("fulfilled event");
    }

    function _expectedSeed(address provider, uint256 requestId, uint256[] memory words)
        private
        pure
        returns (bytes32)
    {
        return
            keccak256(abi.encode(provider, requestId, COLLECTION_ID, TOKEN_ID, uint256(1), words));
    }

    function _failureDataHash() private pure returns (bytes32) {
        return keccak256(abi.encodeWithSelector(MockRandomizerCore.MockTokenHashRejected.selector));
    }

    function _words(uint256 value) private pure returns (uint256[] memory words) {
        words = new uint256[](1);
        words[0] = value;
    }
}

contract RetryVrfCoordinator {
    uint256 public nextRequestId = 1;

    function requestRandomWords(bytes32, uint64, uint16, uint32, uint32)
        external
        returns (uint256 requestId)
    {
        requestId = nextRequestId;
        nextRequestId++;
    }

    function fulfill(NextGenRandomizerVRF randomizer, uint256 requestId, uint256[] memory words)
        external
    {
        randomizer.rawFulfillRandomWords(requestId, words);
    }
}

contract RetryArrngController {
    uint256 public nextRequestId = 1;

    function requestRandomWords(uint256, address) external returns (uint256 requestId) {
        requestId = nextRequestId;
        nextRequestId++;
    }

    function fulfill(NextGenRandomizerRNG randomizer, uint256 requestId, uint256[] memory words)
        external
    {
        randomizer.receiveRandomness(requestId, words);
    }
}
