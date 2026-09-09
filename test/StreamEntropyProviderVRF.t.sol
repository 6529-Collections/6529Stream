// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./helpers/CharacterizationTestBase.sol";
import "./mocks/MockVRFCoordinatorV2Plus.sol";
import "../smart-contracts/domains/entropy/StreamEntropyProviderVRF.sol";

/// @notice Delivery fault injector only; real current-Core fulfillment is tested separately.
contract VRFDeliveryTarget {
    uint8 public mode;
    bytes32 public deliveredKey;
    bytes32 public deliveredRaw;
    uint256 public deliveries;

    function setMode(uint8 value) external {
        mode = value;
    }

    function request(StreamEntropyProviderVRF adapter, bytes32 key) external returns (uint256) {
        return adapter.requestEntropy(key, abi.encode("fixture context"));
    }

    function fulfillEntropy(bytes32 key, bytes32 raw) external returns (uint8) {
        if (mode == 10) revert("temporary coordinator failure");
        if (mode == 11) {
            assembly ("memory-safe") { for { } 1 { } { } }
        }
        if (mode == 12) {
            assembly ("memory-safe") {
                mstore(0, 256)
                return(0, 32)
            }
        }
        if (mode == 13) assembly ("memory-safe") { return(0, 0) }
        deliveredKey = key;
        deliveredRaw = raw;
        ++deliveries;
        return mode;
    }
}

contract StreamEntropyProviderVRFTest is CharacterizationTestBase {
    MockVRFCoordinatorV2Plus private upstream;
    VRFDeliveryTarget private target;
    StreamEntropyProviderVRF private adapter;
    bytes32 private constant KEY = keccak256("request");
    bytes32 private constant MANIFEST = keccak256("local manifest");
    event CallbackGasMeasured(uint256 gasUsed);

    function setUp() public {
        upstream = new MockVRFCoordinatorV2Plus();
        target = new VRFDeliveryTarget();
        adapter = new StreamEntropyProviderVRF(
            StreamEntropyProviderVRF.Config({
                coordinator: address(target),
                authority: address(this),
                vrfCoordinator: address(upstream),
                subscriptionId: uint256(type(uint64).max) + 100,
                keyHash: keccak256("VRF key"),
                requestConfirmations: 3,
                callbackGasLimit: 500000,
                maximumCallbackGasLimit: 2500000,
                nativePayment: true
            }),
            MANIFEST,
            "ipfs://local-vrf",
            MANIFEST
        );
    }

    function testV25RequestIdentityAuthenticationAndDuplicateCallback() public {
        uint256 id = target.request(adapter, KEY);
        IVRFCoordinatorV2Plus.RandomWordsRequest memory request = upstream.lastRequest();
        require(request.subId > type(uint64).max && request.numWords == 1, "v2.5 width and words");
        require(
            request.callbackGasLimit == 500000 && request.requestConfirmations == 3,
            "request config"
        );
        require(
            keccak256(request.extraArgs)
                == keccak256(
                    hex"92fd13380000000000000000000000000000000000000000000000000000000000000001"
                ),
            "native billing ABI"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                VRFConsumerBaseV2.OnlyCoordinatorCanFulfill.selector,
                address(this),
                address(upstream)
            )
        );
        adapter.rawFulfillRandomWords(id, new uint256[](1));
        (bool success, uint256 gasUsed) = upstream.fulfill(id, 42);
        require(success && target.deliveredKey() == KEY, "authenticated callback delivered");
        bytes32 raw = target.deliveredRaw();
        upstream.fulfill(id, 999);
        require(
            target.deliveries() == 1 && target.deliveredRaw() == raw,
            "duplicate never changes output"
        );
        (StreamProviderResultStatus status,,, bool received, bool delivered) =
            adapter.providerResultStatus(id);
        require(
            status == StreamProviderResultStatus.DELIVERED && received && delivered,
            "delivered probe"
        );
        emit CallbackGasMeasured(gasUsed);
    }

    function testRevertOutOfGasAndMalformedResponseRetainIdenticalRandomness() public {
        for (uint8 mode = 10; mode <= 13; ++mode) {
            bytes32 key = keccak256(abi.encode(KEY, mode));
            uint256 id = target.request(adapter, key);
            target.setMode(mode);
            vm.recordLogs();
            (bool success,) = upstream.fulfill(id, 123);
            require(success, "upstream callback survives coordinator failure including OOG");
            _assertFailedDeliveryEvent(id);
            (StreamProviderResultStatus status,, bytes32 hash, bool received, bool delivered) =
                adapter.providerResultStatus(id);
            require(
                status == StreamProviderResultStatus.RAW_RANDOMNESS_RECEIVED && received
                    && !delivered,
                "retained for retry"
            );
            target.setMode(0);
            vm.prank(address(0xbabe));
            adapter.retryCoordinatorFulfillment(id);
            require(
                keccak256(abi.encode(target.deliveredRaw())) == hash, "retry identical stored raw"
            );
            vm.expectRevert(
                abi.encodeWithSelector(StreamEntropyProviderVRF.ResultNotRetryable.selector, id)
            );
            adapter.retryCoordinatorFulfillment(id);
        }
    }

    function testRevokedOutputRemainsRetryableButStaleOutputIsTerminal() public {
        uint256 id = target.request(adapter, KEY);
        target.setMode(5);
        upstream.fulfill(id, 0);
        (StreamProviderResultStatus status,,, bool received, bool delivered) =
            adapter.providerResultStatus(id);
        require(
            status == StreamProviderResultStatus.RAW_RANDOMNESS_RECEIVED && received && !delivered,
            "revoked output retained"
        );
        target.setMode(0);
        adapter.retryCoordinatorFulfillment(id);
        uint256 staleId = target.request(adapter, keccak256("stale"));
        target.setMode(1);
        upstream.fulfill(staleId, 1);
        (status,,, received, delivered) = adapter.providerResultStatus(staleId);
        require(
            status == StreamProviderResultStatus.TERMINAL_STALE && received && !delivered,
            "stale output retained terminal"
        );
    }

    function testRequestReplayCollisionAndOperationalConfig() public {
        target.request(adapter, KEY);
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyProviderVRF.InvalidRequest.selector, KEY)
        );
        target.request(adapter, KEY);
        upstream.setNextRequestId(1);
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyProviderVRF.DuplicateProviderRequest.selector, 1)
        );
        target.request(adapter, keccak256("second request"));
        bytes32 configHash = adapter.streamEntropyProviderConfigHash();
        adapter.updateSubscription(17, false);
        require(
            adapter.streamEntropyProviderConfigHash() == configHash,
            "billing is not randomness identity"
        );
        vm.prank(address(0xbabe));
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyProviderVRF.Unauthorized.selector, address(0xbabe))
        );
        adapter.updateSubscription(18, true);
        require(
            adapter.supportsInterface(type(IStreamEntropyProvider).interfaceId)
                && adapter.supportsInterface(type(IStreamModule).interfaceId)
                && adapter.supportsInterface(0x01ffc9a7) && !adapter.supportsInterface(0xffffffff),
            "module ABI"
        );
    }

    function testUnauthorizedRequestsPaymentsAndUnknownCallbacks() public {
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyProviderVRF.Unauthorized.selector, address(this))
        );
        adapter.requestEntropy(KEY, "");
        vm.deal(address(target), 1);
        vm.prank(address(target));
        vm.expectRevert(abi.encodeWithSelector(StreamEntropyProviderVRF.UnexpectedPayment.selector));
        adapter.requestEntropy{ value: 1 }(KEY, "");
        uint256[] memory words = new uint256[](1);
        (bool success,) = upstream.fulfillTo(address(adapter), 999, words, 500000);
        require(success, "unknown callback is observable without reverting upstream");
        (StreamProviderResultStatus status,,, bool received,) = adapter.providerResultStatus(999);
        require(
            status == StreamProviderResultStatus.UNKNOWN && !received,
            "unknown ID cannot insert result"
        );
        uint256 id = target.request(adapter, KEY);
        (success,) = upstream.fulfillTo(address(adapter), id, new uint256[](0), 500000);
        (status,,, received,) = adapter.providerResultStatus(id);
        require(
            success && status == StreamProviderResultStatus.REQUESTED && !received,
            "invalid word count cannot invent result"
        );
    }

    function _assertFailedDeliveryEvent(uint256 requestId) private {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 signature =
            keccak256("ProviderCoordinatorFulfillmentAttempted(uint16,bytes32,uint256,bool,bytes)");
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(adapter) || logs[i].topics[0] != signature) continue;
            require(uint256(logs[i].topics[2]) == requestId, "failure event request binding");
            (uint16 schema, bool success, bytes memory response) =
                abi.decode(logs[i].data, (uint16, bool, bytes));
            require(schema == 1 && !success && response.length == 0, "bounded failure event data");
            return;
        }
        revert("retained-result failure event missing");
    }
}
