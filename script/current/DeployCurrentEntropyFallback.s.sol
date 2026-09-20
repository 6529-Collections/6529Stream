// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamEntropyFallbackPlan.sol";

/// @notice Explicit local deployment entry; deploys an ordinary backup with independent parameter storage.
/// @dev Does not register, select, or configure the instance. Retain constructor bytes and code hash.
contract DeployCurrentEntropyFallback {
    event EntropyFallbackDeployed(
        address indexed primary,
        address indexed backup,
        bytes32 runtimeCodeHash,
        bytes32 constructorHash
    );

    function deploy(
        StreamEntropyCoordinator primary,
        IStreamTimeParameterHost.TimeParameterConfig[3] calldata times,
        bytes32 deploymentHash,
        string calldata uri,
        bytes32 moduleHash
    ) external returns (StreamEntropyCoordinator backup) {
        StreamEntropyCoordinator.DeploymentConfig memory c =
            StreamEntropyFallbackPlan.deploymentConfig(
                primary, times, deploymentHash, uri, moduleHash
            );
        backup = new StreamEntropyCoordinator(c);
        StreamEntropyFallbackPlan.requirePair(primary, backup);
        emit EntropyFallbackDeployed(
            address(primary), address(backup), address(backup).codehash, keccak256(abi.encode(c))
        );
    }
}
