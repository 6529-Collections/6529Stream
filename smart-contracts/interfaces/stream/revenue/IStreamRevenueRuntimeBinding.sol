// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Explicit once-only governed opt-in to the common revenue lifecycle.
interface IStreamRevenueRuntimeBinding {
    error RevenueRuntimeAlreadyBound();
    error InvalidRevenueRuntimeBinding();
    event RevenueRuntimeRegistryBound(
        uint16 schemaVersion,
        address indexed registry,
        bytes32 indexed actionId,
        bytes32 registryCodeHash,
        address indexed factory
    );
    function revenueRuntimeRegistry() external view returns (address);
    function revenueRuntimeRegistryCodeHash() external view returns (bytes32);
    function revenueRuntimeBindingTransitionHashes(address registry)
        external
        view
        returns (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash);
    function initializeRevenueRuntimeRegistry(address registry) external;
}
