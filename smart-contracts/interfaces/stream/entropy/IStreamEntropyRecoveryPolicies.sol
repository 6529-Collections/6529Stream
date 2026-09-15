// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Frozen precommitments for exceptional fresh entropy recovery.
/// @dev Policy registration alone does not authorize a request or attach a policy to a collection.
interface IStreamEntropyRecoveryPolicies is IERC165 {
    struct FreshRecoveryStep {
        address provider;
        uint32 providerEpoch;
        bytes32 providerConfigHash;
        uint64 notBeforeBlocks;
        bool acceptLateOriginalFulfillment;
    }

    struct FreshRecoveryPolicy {
        bool exists;
        bool frozen;
        uint16 maxFreshRecoveryAttempts;
        bytes32 incidentDeclarerRole;
        bytes32 reasonSchemaHash;
        bytes32 policyManifestHash;
        FreshRecoveryStep[] steps;
    }
    error InvalidFreshRecoveryPolicy(bytes32 policyId);
    error FreshRecoveryPolicyIsFrozen(bytes32 policyId);
    error FreshRecoveryPolicyUnauthorized(address caller);
    error FreshRecoveryPolicyInvalidContext();
    error FreshRecoveryPolicyReplay(bytes32 policyId, bytes32 actionId);

    event FreshRecoveryPolicyConfigured(
        uint16 schemaVersion,
        bytes32 indexed policyId,
        bytes32 indexed policyHash,
        uint16 maxFreshRecoveryAttempts,
        bytes32 incidentDeclarerRole,
        bytes32 policyManifestHash
    );
    event FreshRecoveryPolicyFrozen(
        uint16 schemaVersion, bytes32 indexed policyId, bytes32 indexed policyHash
    );
    /// @notice Complete ordered preimage; the original configuration event remains unchanged.
    event FreshRecoveryPolicyDefinition(
        uint16 schemaVersion,
        bytes32 indexed policyId,
        bytes32 indexed policyHash,
        bytes32 reasonSchemaHash,
        FreshRecoveryStep[] steps
    );
    event FreshRecoveryPolicyAction(
        uint16 schemaVersion, bytes32 indexed policyId, bytes32 indexed actionId, uint64 revision
    );

    function configureFreshRecoveryPolicy(
        bytes32 policyId,
        uint16 maxFreshRecoveryAttempts,
        bytes32 incidentDeclarerRole,
        bytes32 reasonSchemaHash,
        bytes32 policyManifestHash,
        FreshRecoveryStep[] calldata steps
    ) external;
    function freezeFreshRecoveryPolicy(bytes32 policyId) external;
    function freshRecoveryPolicy(bytes32 policyId)
        external
        view
        returns (
            FreshRecoveryPolicy memory policy,
            bytes32 policyHash,
            uint64 revision,
            bytes32 lastActionId
        );
    /// @notice Exact class-1 call commitments; proposedHash is the canonical policy hash.
    /// @dev Freezing requires proposedHash to equal the stored hash. Execution rehashes all inputs.
    function freshRecoveryPolicyTransition(bytes32 policyId, bytes32 proposedHash, bool freezing)
        external
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash);
}
