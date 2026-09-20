// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Immutable role-6 implementation backing this factory's version-4 split clones.
/// @dev Additive capability; profile IDs and runtime hashes remain deployment-line specific.
interface IStreamSplitWalletImplementation {
    error SplitWalletImplementationChanged(
        address implementation, bytes32 expected, bytes32 actual
    );
    error SplitWalletCloneDeploymentFailed(bytes32 profileId);

    event SplitWalletImplementationPinned(
        uint16 schemaVersion,
        address indexed implementation,
        bytes32 indexed runtimeCodeHash,
        uint16 walletVersion,
        bytes32 cloneInitCodeHash,
        bytes32 cloneRuntimeCodeHash
    );

    function splitWalletImplementation() external view returns (address);
    function splitWalletImplementationCodeHash() external view returns (bytes32);
}
