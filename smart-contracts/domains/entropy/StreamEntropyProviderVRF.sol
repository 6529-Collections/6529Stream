// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/entropy/IStreamEntropyProvider.sol";
import "../../interfaces/stream/entropy/IStreamEntropyCoordinator.sol";
import "../../integrations/chainlink/IVRFCoordinatorV2Plus.sol";
import "../../vendor/chainlink/VRFConsumerBaseV2.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../modules/StreamModuleBase.sol";

/// @notice Subscription-funded VRF v2.5 adapter. Every upstream result is stored before delivery.
/// @dev The vendored V2 base provides the unchanged rawFulfillRandomWords callback ABI and an
/// immutable sender check only; requests use the distinct v2.5 ABI with uint256 subscription IDs.
/// Upstream migration changes randomness identity and requires a new adapter deployment.
contract StreamEntropyProviderVRF is
    StreamModuleBase,
    VRFConsumerBaseV2,
    ReentrancyGuard,
    IStreamEntropyProvider
{
    bytes32 public constant RAW_DOMAIN = keccak256("6529STREAM_VRF_RAW_V1");
    uint32 public constant VRF_CALLBACK_GAS_FLOOR = 300000;
    uint32 public constant NUM_WORDS = 1;
    // This reserve belongs to the adapter frame, not to the coordinator's fulfillment envelope.
    // A subcall that exhausts its gas must leave enough to publish the retained-result outcome.
    uint256 private constant _DELIVERY_RESERVE = 50000;
    bytes4 private constant _EXTRA_ARGS_V1_TAG = bytes4(keccak256("VRF ExtraArgsV1"));

    struct Config {
        address coordinator;
        address authority;
        address vrfCoordinator;
        uint256 subscriptionId;
        bytes32 keyHash;
        uint16 requestConfirmations;
        uint32 callbackGasLimit;
        uint32 maximumCallbackGasLimit;
        bool nativePayment;
    }

    struct ProviderResult {
        bytes32 requestKey;
        bytes32 rawRandomness;
        StreamProviderResultStatus status;
        uint64 receivedAtBlock;
        uint64 deliveredAtBlock;
    }

    address public immutable coordinator;
    address public immutable authority;
    address public immutable vrfCoordinatorAddress;
    bytes32 public immutable keyHash;
    uint16 public immutable requestConfirmations;
    uint32 public immutable maximumCallbackGasLimit;
    uint32 public immutable callbackGasLimit;
    uint256 public subscriptionId;
    bool public nativePayment;
    mapping(uint256 => ProviderResult) public results;
    mapping(bytes32 => uint256) public keyToVrfRequest;

    error InvalidConfiguration();
    error Unauthorized(address caller);
    error InvalidRequest(bytes32 requestKey);
    error DuplicateProviderRequest(uint256 providerRequestId);
    error UnexpectedPayment();
    error ResultNotRetryable(uint256 providerRequestId);

    event VRFEntropyRequested(
        uint16 schemaVersion,
        bytes32 indexed requestKey,
        uint256 indexed vrfRequestId,
        uint256 indexed subscriptionId,
        uint32 providerEpoch,
        bytes32 keyHash,
        uint16 requestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    );
    event VRFRequestContext(
        uint16 schemaVersion, uint256 indexed vrfRequestId, bytes32 contextHash, bool nativePayment
    );
    event VRFEntropyReceived(
        uint16 schemaVersion,
        bytes32 indexed requestKey,
        uint256 indexed vrfRequestId,
        bytes32 rawRandomness
    );
    event VRFCallbackIgnored(uint16 schemaVersion, uint256 indexed vrfRequestId, uint8 reason);
    event ProviderCoordinatorFulfillmentAttempted(
        uint16 schemaVersion,
        bytes32 indexed requestKey,
        uint256 indexed providerRequestId,
        bool success,
        bytes returnData
    );
    event VRFSubscriptionUpdated(
        uint16 schemaVersion,
        uint256 indexed oldSubscriptionId,
        uint256 indexed newSubscriptionId,
        bool nativePayment
    );

    constructor(
        Config memory config,
        bytes32 deploymentManifestHash,
        string memory manifestURI,
        bytes32 manifestHash
    )
        StreamModuleBase(
            keccak256("6529stream.entropy-provider-vrf-v2.5.schema.v1"),
            address(0),
            deploymentManifestHash,
            manifestURI,
            manifestHash
        )
        VRFConsumerBaseV2(config.vrfCoordinator)
    {
        if (
            config.coordinator.code.length == 0 || config.vrfCoordinator.code.length == 0
                || config.authority == address(0) || config.subscriptionId == 0
                || config.keyHash == 0 || config.requestConfirmations == 0
                || config.requestConfirmations > 200
                || config.callbackGasLimit < VRF_CALLBACK_GAS_FLOOR
                || config.callbackGasLimit > config.maximumCallbackGasLimit
                || deploymentManifestHash == 0 || manifestHash == 0
        ) revert InvalidConfiguration();
        coordinator = config.coordinator;
        authority = config.authority;
        vrfCoordinatorAddress = config.vrfCoordinator;
        subscriptionId = config.subscriptionId;
        keyHash = config.keyHash;
        requestConfirmations = config.requestConfirmations;
        maximumCallbackGasLimit = config.maximumCallbackGasLimit;
        callbackGasLimit = config.callbackGasLimit;
        nativePayment = config.nativePayment;
    }

    function streamModuleType() public pure override returns (bytes32) {
        return keccak256("ENTROPY_PROVIDER");
    }

    function streamModuleVersion() public pure override returns (bytes32) {
        return keccak256("6529stream.entropy-provider-vrf-v2.5.v1");
    }

    function streamModuleInterfaceId() public pure override returns (bytes4) {
        return type(IStreamEntropyProvider).interfaceId;
    }

    function supportsInterface(bytes4 id)
        public
        view
        override(StreamModuleBase, IERC165)
        returns (bool)
    {
        return id == type(IStreamEntropyProvider).interfaceId || super.supportsInterface(id);
    }

    function isStreamEntropyProvider() external pure override returns (bool) {
        return true;
    }

    function streamEntropyProviderFamily() external pure override returns (bytes32) {
        return keccak256("6529STREAM_ENTROPY_PROVIDER_VRF");
    }

    function streamEntropyProviderVersion() external pure override returns (bytes32) {
        return streamModuleVersion();
    }

    function streamEntropyProviderConfigHash() external view override returns (bytes32) {
        return keccak256(
            abi.encode(
                streamModuleVersion(),
                block.chainid,
                coordinator,
                vrfCoordinatorAddress,
                keyHash,
                requestConfirmations,
                NUM_WORDS
            )
        );
    }

    function quoteRequest(bytes calldata) external pure override returns (uint256) {
        return 0;
    }

    /// @notice The subscription pays Chainlink directly; no per-request Ether is accepted here.
    function requestEntropy(bytes32 requestKey, bytes calldata context)
        external
        payable
        override
        nonReentrant
        returns (uint256 providerRequestId)
    {
        if (msg.sender != coordinator) revert Unauthorized(msg.sender);
        if (msg.value != 0) revert UnexpectedPayment();
        if (requestKey == 0 || keyToVrfRequest[requestKey] != 0) revert InvalidRequest(requestKey);
        uint32 callbackGas = callbackGasLimit;
        providerRequestId = IVRFCoordinatorV2Plus(vrfCoordinatorAddress)
            .requestRandomWords(
                IVRFCoordinatorV2Plus.RandomWordsRequest({
                keyHash: keyHash,
                subId: subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGas,
                numWords: NUM_WORDS,
                extraArgs: abi.encodeWithSelector(_EXTRA_ARGS_V1_TAG, nativePayment)
            })
            );
        if (providerRequestId == 0 || results[providerRequestId].requestKey != 0) {
            revert DuplicateProviderRequest(providerRequestId);
        }
        keyToVrfRequest[requestKey] = providerRequestId;
        results[providerRequestId].requestKey = requestKey;
        results[providerRequestId].status = StreamProviderResultStatus.REQUESTED;
        emit VRFEntropyRequested(
            1,
            requestKey,
            providerRequestId,
            subscriptionId,
            1,
            keyHash,
            requestConfirmations,
            callbackGas,
            NUM_WORDS
        );
        emit VRFRequestContext(1, providerRequestId, keccak256(context), nativePayment);
    }

    /// @notice Operational billing only; changing this never changes a committed randomness input.
    function updateSubscription(uint256 newSubscriptionId, bool useNativePayment) external {
        if (msg.sender != authority) revert Unauthorized(msg.sender);
        if (newSubscriptionId == 0) revert InvalidConfiguration();
        emit VRFSubscriptionUpdated(1, subscriptionId, newSubscriptionId, useNativePayment);
        subscriptionId = newSubscriptionId;
        nativePayment = useNativePayment;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
        nonReentrant
    {
        ProviderResult storage result = results[requestId];
        if (result.status != StreamProviderResultStatus.REQUESTED) {
            emit VRFCallbackIgnored(1, requestId, result.requestKey == 0 ? 1 : 2);
            return;
        }
        if (randomWords.length != NUM_WORDS) {
            emit VRFCallbackIgnored(1, requestId, 3);
            return;
        }
        result.rawRandomness =
            keccak256(abi.encode(RAW_DOMAIN, result.requestKey, requestId, randomWords));
        result.receivedAtBlock = uint64(block.number);
        result.status = StreamProviderResultStatus.RAW_RANDOMNESS_RECEIVED;
        emit VRFEntropyReceived(1, result.requestKey, requestId, result.rawRandomness);
        _deliver(requestId, result);
    }

    function retryCoordinatorFulfillment(uint256 requestId) external override nonReentrant {
        ProviderResult storage result = results[requestId];
        if (result.status != StreamProviderResultStatus.RAW_RANDOMNESS_RECEIVED) {
            revert ResultNotRetryable(requestId);
        }
        _deliver(requestId, result);
    }

    function _deliver(uint256 requestId, ProviderResult storage result) private {
        bytes memory callData = abi.encodeCall(
            IStreamEntropyCoordinator.fulfillEntropy, (result.requestKey, result.rawRandomness)
        );
        address target = coordinator;
        uint256 availableGas = gasleft();
        if (availableGas <= _DELIVERY_RESERVE) {
            emit ProviderCoordinatorFulfillmentAttempted(1, result.requestKey, requestId, false, "");
            return;
        }
        uint256 forwardedGas = availableGas - _DELIVERY_RESERVE;
        bool success;
        uint256 responseSize;
        uint256 outcome;
        // Copy exactly one return word. A revert, OOG, invalid uint8 or malformed return cannot
        // undo the already-persisted randomness or exhaust the adapter by growing return data.
        assembly ("memory-safe") {
            let response := mload(0x40)
            mstore(response, 0)
            success := call(
                forwardedGas,
                target,
                0,
                add(callData, 32),
                mload(callData),
                response,
                32
            )
            responseSize := returndatasize()
            outcome := mload(response)
        }
        if (!success || responseSize != 32 || outcome > 5) {
            emit ProviderCoordinatorFulfillmentAttempted(1, result.requestKey, requestId, false, "");
            return;
        }
        if (outcome == 0 || outcome == 3) {
            result.status = StreamProviderResultStatus.DELIVERED;
            result.deliveredAtBlock = uint64(block.number);
        } else if (outcome == 1 || outcome == 2) {
            result.status = StreamProviderResultStatus.TERMINAL_STALE;
        }
        emit ProviderCoordinatorFulfillmentAttempted(
            1, result.requestKey, requestId, true, abi.encode(uint8(outcome))
        );
    }

    function providerResultStatus(uint256 requestId)
        external
        view
        override
        returns (
            StreamProviderResultStatus status,
            bytes32 requestKey,
            bytes32 rawRandomnessHash,
            bool rawRandomnessReceived,
            bool delivered
        )
    {
        ProviderResult storage result = results[requestId];
        status = result.status;
        requestKey = result.requestKey;
        rawRandomnessReceived = status == StreamProviderResultStatus.RAW_RANDOMNESS_RECEIVED
            || status == StreamProviderResultStatus.DELIVERED
            || status == StreamProviderResultStatus.TERMINAL_STALE;
        rawRandomnessHash =
            rawRandomnessReceived ? keccak256(abi.encode(result.rawRandomness)) : bytes32(0);
        delivered = status == StreamProviderResultStatus.DELIVERED;
    }
}
