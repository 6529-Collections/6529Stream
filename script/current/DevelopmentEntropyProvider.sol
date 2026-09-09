// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/interfaces/stream/IStreamEntropyProvider.sol";
import "../../smart-contracts/interfaces/stream/IStreamEntropyCoordinator.sol";
import "../../smart-contracts/vendor/openzeppelin/ERC165.sol";

/// @notice ANVIL DEVELOPMENT ONLY. Controller-supplied values are not secure randomness.
/// @dev Refuses every chain except 31337. Public test transactions remain inspectable on Anvil.
contract DevelopmentEntropyProvider is ERC165, IStreamEntropyProvider {
    struct Result {
        bytes32 requestKey;
        bytes32 raw;
        bool received;
        bool delivered;
    }
    address public immutable controller;
    IStreamEntropyCoordinator public immutable coordinator;
    uint256 public nextRequestId = 1;
    mapping(uint256 => Result) public results;

    constructor(address coordinator_, address controller_) {
        require(block.chainid == 31337, "development provider requires Anvil chain31337");
        require(
            coordinator_.code.length != 0 && controller_ != address(0), "invalid development config"
        );
        coordinator = IStreamEntropyCoordinator(coordinator_);
        controller = controller_;
    }

    function supportsInterface(bytes4 id) public view override(ERC165, IERC165) returns (bool) {
        return id == type(IStreamEntropyProvider).interfaceId || super.supportsInterface(id);
    }

    function isStreamEntropyProvider() external pure returns (bool) {
        return true;
    }

    function streamEntropyProviderFamily() external pure returns (bytes32) {
        return keccak256("ANVIL_DEVELOPMENT_ONLY_NOT_RANDOMNESS");
    }

    function streamEntropyProviderVersion() external pure returns (bytes32) {
        return keccak256("development-v1");
    }

    function streamEntropyProviderConfigHash() external view returns (bytes32) {
        return keccak256(abi.encode("ANVIL_DEVELOPMENT_ONLY", address(coordinator), controller));
    }

    function quoteRequest(bytes calldata) external pure returns (uint256) {
        return 0;
    }

    function requestEntropy(bytes32 requestKey, bytes calldata)
        external
        payable
        returns (uint256 id)
    {
        require(msg.sender == address(coordinator) && msg.value == 0, "coordinator, zero fee only");
        id = nextRequestId++;
        results[id].requestKey = requestKey;
    }

    function fulfill(uint256 id, bytes32 raw) external returns (uint8 outcome) {
        require(msg.sender == controller, "development controller only");
        Result storage item = results[id];
        require(item.requestKey != bytes32(0), "unknown request");
        require(!item.received || item.raw == raw, "cannot replace retained result");
        item.raw = raw;
        item.received = true;
        return _deliver(item);
    }

    function retryCoordinatorFulfillment(uint256 id) external {
        Result storage item = results[id];
        require(item.received, "raw result absent");
        _deliver(item);
    }

    function providerResultStatus(uint256 id)
        external
        view
        returns (StreamProviderResultStatus, bytes32, bytes32, bool, bool)
    {
        Result storage item = results[id];
        StreamProviderResultStatus status = item.delivered
            ? StreamProviderResultStatus.DELIVERED
            : item.received
                ? StreamProviderResultStatus.RAW_RANDOMNESS_RECEIVED
                : item.requestKey != 0
                    ? StreamProviderResultStatus.REQUESTED
                    : StreamProviderResultStatus.UNKNOWN;
        return (
            status,
            item.requestKey,
            item.received ? keccak256(abi.encode(item.raw)) : bytes32(0),
            item.received,
            item.delivered
        );
    }

    function _deliver(Result storage item) private returns (uint8 outcome) {
        outcome = coordinator.fulfillEntropy(item.requestKey, item.raw);
        if (outcome == 0 || outcome == 3) item.delivered = true;
    }
}
