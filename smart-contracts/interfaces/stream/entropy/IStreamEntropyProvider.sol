// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";

enum StreamProviderResultStatus {
    UNKNOWN,
    REQUESTED,
    RAW_RANDOMNESS_RECEIVED,
    DELIVERED,
    TERMINAL_STALE,
    TERMINAL_FAILED
}

/// @notice Authenticated asynchronous adapter boundary; requests use coordinator-owned keys.
interface IStreamEntropyProvider is IERC165 {
    function isStreamEntropyProvider() external view returns (bool);
    function streamEntropyProviderFamily() external pure returns (bytes32);
    function streamEntropyProviderVersion() external pure returns (bytes32);
    function streamEntropyProviderConfigHash() external view returns (bytes32);
    function quoteRequest(bytes calldata context) external view returns (uint256 fee);
    function requestEntropy(bytes32 requestKey, bytes calldata context)
        external
        payable
        returns (uint256 providerRequestId);
    function retryCoordinatorFulfillment(uint256 providerRequestId) external;
    function providerResultStatus(uint256 providerRequestId)
        external
        view
        returns (
            StreamProviderResultStatus status,
            bytes32 requestKey,
            bytes32 rawRandomnessHash,
            bool rawRandomnessReceived,
            bool delivered
        );
}
