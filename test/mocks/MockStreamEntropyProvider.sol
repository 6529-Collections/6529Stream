// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyProvider.sol";
import "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCoordinator.sol";
import "../../smart-contracts/vendor/openzeppelin/ERC165.sol";

/// @notice LOCAL TEST ONLY: anyone can supply deterministic test randomness or simulate outages.
contract MockStreamEntropyProvider is ERC165, IStreamEntropyProvider {
    struct Result {
        bytes32 key;
        bytes32 raw;
        StreamProviderResultStatus status;
        bool received;
        bool delivered;
    }
    IStreamEntropyCoordinator public immutable coordinator;
    uint256 public fee;
    uint256 public nextRequestId = 1;
    bool public reenterOnRequest;
    mapping(uint256 => Result) public results;

    constructor(address coordinator_) {
        coordinator = IStreamEntropyCoordinator(coordinator_);
    }

    function supportsInterface(bytes4 id) public view override(ERC165, IERC165) returns (bool) {
        return id == type(IStreamEntropyProvider).interfaceId || super.supportsInterface(id);
    }

    function isStreamEntropyProvider() external pure returns (bool) {
        return true;
    }

    function streamEntropyProviderFamily() external pure returns (bytes32) {
        return keccak256("LOCAL_TEST_ONLY");
    }

    function streamEntropyProviderVersion() external pure returns (bytes32) {
        return keccak256("local-test-v1");
    }

    function streamEntropyProviderConfigHash() external view returns (bytes32) {
        return keccak256(abi.encode("LOCAL_TEST_ONLY", address(coordinator)));
    }

    function setFee(uint256 value) external {
        fee = value;
    }

    function setNextRequestId(uint256 value) external {
        nextRequestId = value;
    }

    function setReenterOnRequest(bool value) external {
        reenterOnRequest = value;
    }

    function quoteRequest(bytes calldata) external view returns (uint256) {
        return fee;
    }

    function requestEntropy(bytes32 key, bytes calldata) external payable returns (uint256 id) {
        require(msg.sender == address(coordinator), "coordinator only");
        require(msg.value == fee, "exact provider fee");
        id = nextRequestId++;
        results[id] = Result(key, 0, StreamProviderResultStatus.REQUESTED, false, false);
        if (reenterOnRequest) coordinator.fulfillEntropy(key, bytes32(uint256(7)));
    }

    function fulfill(uint256 id, bytes32 raw) external returns (uint8 outcome) {
        Result storage result = results[id];
        require(result.key != 0, "unknown request");
        if (!result.received) {
            result.raw = raw;
            result.received = true;
            result.status = StreamProviderResultStatus.RAW_RANDOMNESS_RECEIVED;
        } else {
            require(result.raw == raw, "cannot replace raw result");
        }
        outcome = coordinator.fulfillEntropy(result.key, result.raw);
        if (outcome == 0 || outcome == 3) {
            result.delivered = true;
            result.status = StreamProviderResultStatus.DELIVERED;
        }
    }

    function fail(uint256 id) external {
        require(!results[id].received, "raw received");
        results[id].status = StreamProviderResultStatus.TERMINAL_FAILED;
    }

    function retryCoordinatorFulfillment(uint256 id) external {
        Result storage result = results[id];
        require(result.received, "raw missing");
        uint8 outcome = coordinator.fulfillEntropy(result.key, result.raw);
        if (outcome == 0 || outcome == 3) {
            result.delivered = true;
            result.status = StreamProviderResultStatus.DELIVERED;
        }
    }

    function providerResultStatus(uint256 id)
        external
        view
        returns (StreamProviderResultStatus, bytes32, bytes32, bool, bool)
    {
        Result storage result = results[id];
        return (
            result.status,
            result.key,
            result.received ? keccak256(abi.encode(result.raw)) : bytes32(0),
            result.received,
            result.delivered
        );
    }
}
