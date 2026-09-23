// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamEntropyRecoveryPolicies.sol";

/// @notice Precommitted permission to replace the live coordinator while original requests remain.
/// @dev Never transfers subjects, funds, or fulfillment authority to the replacement.
interface IStreamEntropyCoordinatorContinuity is IERC165 {
    function configureFreshRecoveryPolicyV2(
        bytes32 policyId,
        uint16 maxFreshRecoveryAttempts,
        bytes32 incidentDeclarerRole,
        bytes32 reasonSchemaHash,
        bytes32 policyManifestHash,
        IStreamEntropyRecoveryPolicies.FreshRecoveryStep[] calldata steps,
        address successor,
        bytes32 successorCodeHash
    ) external;
    function freshRecoveryPolicyV2Transition(bytes32 policyId, bytes32 proposedHash)
        external
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash);
    function coordinatorReplacementTerms(bytes32 policyId)
        external
        view
        returns (address successor, bytes32 successorCodeHash, bytes32 policyHash);
    function uncoveredPendingRequestCount(address successor, bytes32 successorCodeHash)
        external
        view
        returns (uint256);

    event FreshRecoveryCoordinatorReplacement(
        uint16 schemaVersion,
        bytes32 indexed policyId,
        bytes32 indexed policyHash,
        address indexed successor,
        bytes32 successorCodeHash
    );
    error InvalidEntropyContinuity();
}
