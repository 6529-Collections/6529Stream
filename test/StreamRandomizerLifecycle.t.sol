// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/IXRandoms.sol";
import "../smart-contracts/RandomizerNXT.sol";
import "../smart-contracts/RandomizerRNG.sol";
import "../smart-contracts/RandomizerVRF.sol";
import "../smart-contracts/StreamRandomizerLifecycle.sol";
import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";
import "./helpers/StreamFixture.sol";
import "./mocks/MockRandomizer.sol";
import "./mocks/MockRandomizerCore.sol";

contract StreamRandomizerLifecycleTest is CharacterizationTestBase, StreamFixture {
    using Assertions for address;
    using Assertions for bool;
    using Assertions for bytes32;
    using Assertions for uint256;

    address private constant PAYOUT = address(0x2002);
    address private constant CURATORS_POOL = address(0x3003);
    uint256 private constant TOKEN_ID = 10_000_000_000;
    uint256 private constant COLLECTION_ID = 1;
    bytes32 private constant PAUSE_REASON = keccak256("randomness-incident");

    function testVrfRequestRecordsLifecycleAndFulfillmentSetsHashOnce() public {
        (DeployedStream memory deployed, MockVrfCoordinator coordinator, NextGenRandomizerVRF vrf) =
            _deployVrfRandomizer();

        _mintToken(deployed);

        StreamRandomizerLifecycle.RandomnessRequest memory request =
            vrf.retrieveRandomnessRequest(1);
        request.collectionId.assertEq(COLLECTION_ID, "collection");
        request.tokenId.assertEq(TOKEN_ID, "token");
        request.provider.assertEq(address(vrf), "provider");
        request.providerRequestId.assertEq(1, "provider request");
        request.randomizerEpoch.assertEq(2, "epoch");
        uint256(request.state)
            .assertEq(uint256(StreamRandomizerLifecycle.RandomnessRequestState.Pending), "state");
        vrf.tokenToRequest(TOKEN_ID).assertEq(1, "token request");
        vrf.requestToToken(1).assertEq(TOKEN_ID, "request token");

        uint256[] memory words = _words(777);
        bytes32 expectedSeed = keccak256(
            abi.encode(address(vrf), uint256(1), COLLECTION_ID, TOKEN_ID, uint256(2), words)
        );
        coordinator.fulfill(vrf, 1, words);

        deployed.core.retrieveTokenHash(TOKEN_ID).assertEq(expectedSeed, "token hash");
        request = vrf.retrieveRandomnessRequest(1);
        uint256(request.state)
            .assertEq(
                uint256(StreamRandomizerLifecycle.RandomnessRequestState.Fulfilled), "fulfilled"
            );
        request.derivedSeed.assertEq(expectedSeed, "stored seed");

        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRandomizerLifecycle.RandomnessRequestNotPending.selector,
                uint256(1),
                StreamRandomizerLifecycle.RandomnessRequestState.Fulfilled
            )
        );
        coordinator.fulfill(vrf, 1, words);
    }

    function testVrfUnknownAndEmptyFulfillmentsFailClosed() public {
        (DeployedStream memory deployed, MockVrfCoordinator coordinator, NextGenRandomizerVRF vrf) =
            _deployVrfRandomizer();

        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRandomizerLifecycle.UnknownRandomnessRequest.selector, uint256(999)
            )
        );
        coordinator.fulfill(vrf, 999, _words(1));

        _mintToken(deployed);

        vm.expectRevert(
            abi.encodeWithSelector(StreamRandomizerLifecycle.EmptyRandomWords.selector, uint256(1))
        );
        coordinator.fulfill(vrf, 1, new uint256[](0));
    }

    function testVrfStaleEpochOrProviderFulfillmentFails() public {
        (DeployedStream memory deployed, MockVrfCoordinator coordinator, NextGenRandomizerVRF vrf) =
            _deployVrfRandomizer();

        _mintToken(deployed);

        NoopRandomizer replacement = new NoopRandomizer();
        deployed.core.addRandomizer(COLLECTION_ID, address(replacement));

        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRandomizerLifecycle.StaleRandomnessRequest.selector,
                uint256(1),
                uint256(2),
                uint256(3),
                address(vrf),
                address(replacement)
            )
        );
        coordinator.fulfill(vrf, 1, _words(777));

        deployed.core.retrieveTokenHash(TOKEN_ID).assertEq(bytes32(0), "stale hash written");
    }

    function testMarkedStaleRequestIsObservableAndCannotFulfill() public {
        (DeployedStream memory deployed, MockVrfCoordinator coordinator, NextGenRandomizerVRF vrf) =
            _deployVrfRandomizer();

        _mintToken(deployed);

        vrf.markStaleRequest(1);
        uint256(vrf.randomnessRequestState(1))
            .assertEq(uint256(StreamRandomizerLifecycle.RandomnessRequestState.Stale), "not stale");

        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRandomizerLifecycle.RandomnessRequestNotPending.selector,
                uint256(1),
                StreamRandomizerLifecycle.RandomnessRequestState.Stale
            )
        );
        coordinator.fulfill(vrf, 1, _words(777));
    }

    function testRandomnessRequestPauseDoesNotBlockVrfFulfillment() public {
        (DeployedStream memory deployed, MockVrfCoordinator coordinator, NextGenRandomizerVRF vrf) =
            _deployVrfRandomizer();

        _mintToken(deployed);

        deployed.admins
            .setPaused(deployed.admins.PAUSE_DOMAIN_RANDOMNESS_REQUEST(), true, PAUSE_REASON);
        coordinator.fulfill(vrf, 1, _words(777));

        (deployed.core.retrieveTokenHash(TOKEN_ID) == bytes32(0)).assertFalse("fulfillment paused");
    }

    function testArrngRequestAndFulfillmentUseSameLifecycle() public {
        DeployedStream memory deployed = deployStream(PAYOUT, CURATORS_POOL);
        MockArrngLifecycleController controller = new MockArrngLifecycleController();
        NextGenRandomizerRNG rng = new NextGenRandomizerRNG(
            address(deployed.core), address(deployed.admins), address(controller)
        );
        deployed.core.addRandomizer(COLLECTION_ID, address(rng));

        _mintToken(deployed);

        StreamRandomizerLifecycle.RandomnessRequest memory request =
            rng.retrieveRandomnessRequest(1);
        request.collectionId.assertEq(COLLECTION_ID, "collection");
        request.tokenId.assertEq(TOKEN_ID, "token");
        request.provider.assertEq(address(rng), "provider");
        request.randomizerEpoch.assertEq(2, "epoch");

        uint256[] memory words = _words(999);
        bytes32 expectedSeed = keccak256(
            abi.encode(address(rng), uint256(1), COLLECTION_ID, TOKEN_ID, uint256(2), words)
        );
        controller.fulfill(rng, 1, words);

        deployed.core.retrieveTokenHash(TOKEN_ID).assertEq(expectedSeed, "token hash");
        uint256(rng.randomnessRequestState(1))
            .assertEq(
                uint256(StreamRandomizerLifecycle.RandomnessRequestState.Fulfilled), "fulfilled"
            );
    }

    function testArrngControllerCannotReenterFulfillmentDuringRequest() public {
        DeployedStream memory deployed = deployStream(PAYOUT, CURATORS_POOL);
        ReentrantArrngLifecycleController controller = new ReentrantArrngLifecycleController();
        NextGenRandomizerRNG rng = new NextGenRandomizerRNG(
            address(deployed.core), address(deployed.admins), address(controller)
        );
        deployed.core.addRandomizer(COLLECTION_ID, address(rng));

        vm.expectRevert(
            abi.encodeWithSelector(NextGenRandomizerRNG.RandomizerRequestReentrancy.selector)
        );
        _mintToken(deployed);

        deployed.core.retrieveTokenHash(TOKEN_ID).assertEq(bytes32(0), "reentrant hash written");
    }

    function testArrngZeroRequestIdFailsBeforeRecordingLifecycle() public {
        DeployedStream memory deployed = deployStream(PAYOUT, CURATORS_POOL);
        ZeroRequestIdArrngLifecycleController controller =
            new ZeroRequestIdArrngLifecycleController();
        NextGenRandomizerRNG rng = new NextGenRandomizerRNG(
            address(deployed.core), address(deployed.admins), address(controller)
        );
        deployed.core.addRandomizer(COLLECTION_ID, address(rng));

        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRandomizerLifecycle.UnknownRandomnessRequest.selector, uint256(0)
            )
        );
        _mintToken(deployed);

        uint256(rng.randomnessRequestState(0))
            .assertEq(uint256(StreamRandomizerLifecycle.RandomnessRequestState.None), "zero state");
        rng.tokenToRequest(TOKEN_ID).assertEq(0, "token request recorded");
        deployed.core.retrieveTokenHash(TOKEN_ID).assertEq(bytes32(0), "hash written");
    }

    function testNxtRandomizerCannotBeConfiguredForProductionCollections() public {
        DeployedStream memory deployed = deployStream(PAYOUT, CURATORS_POOL);
        NextGenRandomizerNXT nxt = new NextGenRandomizerNXT(
            address(new MockXRandoms()), address(deployed.admins), address(deployed.core)
        );

        nxt.isRandomizerContract().assertFalse("nxt advertises production randomizer");

        (bool success,) = address(deployed.core)
            .call(
                abi.encodeWithSelector(
                    deployed.core.addRandomizer.selector, COLLECTION_ID, address(nxt)
                )
            );

        success.assertFalse("nxt configured as production randomizer");
    }

    function testVrfWrongCollectionBindingFailsClosed() public {
        DeployedStream memory deployed = deployStream(PAYOUT, CURATORS_POOL);
        MockRandomizerCore core = new MockRandomizerCore();
        MockVrfCoordinator coordinator = new MockVrfCoordinator();
        NextGenRandomizerVRF vrf = new NextGenRandomizerVRF(
            1, address(coordinator), address(core), address(deployed.admins)
        );

        core.setRandomizer(COLLECTION_ID, address(vrf), 1);
        core.setTokenCollection(TOKEN_ID, COLLECTION_ID + 1);

        vm.prank(address(core));
        vrf.calculateTokenHash(COLLECTION_ID, TOKEN_ID, 123);

        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRandomizerLifecycle.WrongRandomnessTokenCollection.selector,
                uint256(1),
                TOKEN_ID,
                COLLECTION_ID,
                COLLECTION_ID + 1
            )
        );
        coordinator.fulfill(vrf, 1, _words(777));
    }

    function _deployVrfRandomizer()
        private
        returns (
            DeployedStream memory deployed,
            MockVrfCoordinator coordinator,
            NextGenRandomizerVRF vrf
        )
    {
        deployed = deployStream(PAYOUT, CURATORS_POOL);
        coordinator = new MockVrfCoordinator();
        vrf = new NextGenRandomizerVRF(
            1, address(coordinator), address(deployed.core), address(deployed.admins)
        );
        deployed.core.addRandomizer(COLLECTION_ID, address(vrf));
    }

    function _mintToken(DeployedStream memory deployed) private {
        vm.prank(address(deployed.minter));
        deployed.core.mint(TOKEN_ID, address(0xBEEF), "data", 123, COLLECTION_ID);
    }

    function _words(uint256 word) private pure returns (uint256[] memory words) {
        words = new uint256[](1);
        words[0] = word;
    }
}

contract MockVrfCoordinator {
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

contract MockArrngLifecycleController {
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

contract ReentrantArrngLifecycleController {
    function requestRandomWords(uint256, address) external returns (uint256 requestId) {
        uint256[] memory words = new uint256[](1);
        words[0] = 123;
        NextGenRandomizerRNG(payable(msg.sender)).receiveRandomness(1, words);
        return 1;
    }
}

contract ZeroRequestIdArrngLifecycleController {
    function requestRandomWords(uint256, address) external pure returns (uint256 requestId) {
        return 0;
    }
}

contract MockXRandoms is IXRandoms {
    function randomNumber() external pure returns (uint256) {
        return 4;
    }

    function randomWord() external pure returns (string memory) {
        return "word";
    }
}
