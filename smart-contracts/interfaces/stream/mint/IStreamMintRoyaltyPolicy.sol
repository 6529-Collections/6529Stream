// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Explicit royalty authorization committed by the existing phase config/policy hashes.
interface IStreamMintRoyaltyPolicy {
    struct Policy {
        bool configured;
        bytes32 applicationConfigHash;
        address resolver;
        bytes32 resolverRuntimeHash;
        bytes32 electionHash;
        bytes32 expectedModeAssignmentHash;
        bytes32 expectedSourceRoyaltyPolicyHash;
    }

    error InvalidMintRoyaltyPolicy();
    error MintRoyaltyPolicyAlreadyConfigured(uint256 collectionId, bytes32 phaseId);
    error PreparedRoyaltySnapshotRequired(uint256 collectionId);
    event MintPhaseRoyaltyPolicyRegistered(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        bytes32 indexed configHash,
        Policy policy
    );

    function registerPhaseRoyaltyPolicy(
        uint256 collectionId,
        bytes32 phaseId,
        Policy calldata policy
    ) external returns (bytes32 configHash);
    function phaseRoyaltyPolicy(uint256 collectionId, bytes32 phaseId)
        external
        view
        returns (Policy memory);
    function phaseRoyaltyConfigHash(uint256 collectionId, bytes32 phaseId, Policy calldata policy)
        external
        view
        returns (bytes32);
}
