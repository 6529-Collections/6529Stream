// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamRoyaltyResolver } from "./IStreamRoyaltyResolver.sol";

/// @notice Current prepared collection royalty snapshots; old live royalty interfaces remain exact.
interface IStreamRoyaltySnapshot {
    struct Source {
        uint256 collectionId;
        bytes32 electionHash;
        bytes32 sourceAssignmentHash;
        bytes32 modeAssignmentHash;
        bytes32 sourceRoyaltyPolicyHash;
        IStreamRoyaltyResolver.RoyaltyConfig config;
    }

    struct Snapshot {
        bool exists;
        uint256 collectionId;
        uint256 tokenId;
        address manager;
        bytes32 operationRoot;
        bytes32 operationId;
        bytes32 preparedProofHash;
        bytes32 electionHash;
        bytes32 sourceAssignmentHash;
        bytes32 modeAssignmentHash;
        bytes32 sourceRoyaltyPolicyHash;
        bytes32 tokenAssignmentHash;
        bytes32 tokenRoyaltyPolicyHash;
        bytes32 tokenConfigHash;
    }

    error InvalidRoyaltySnapshot();
    error RoyaltySnapshotModeRequired(uint256 collectionId);
    error RoyaltySnapshotMutationClosed(uint256 collectionId);
    error RoyaltyModeAlreadyElected(uint256 collectionId);

    event CollectionRoyaltyModeElected(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed electionHash,
        address indexed executor,
        address core,
        uint8 mode
    );
    event TokenRoyaltySnapshotted(
        uint16 schemaVersion,
        bytes32 indexed operationId,
        uint256 indexed tokenId,
        bytes32 indexed operationRoot,
        uint256 collectionId,
        bytes32 revenueClass,
        bytes32 tokenRoyaltyAssignmentHash
    );
    function electCollectionRoyaltyMode(uint256 collectionId, uint8 mode) external;
    /// @notice Current canonical source economics plus separately signed mode commitment.
    /// @dev Requires current selected Artist consent; prospective approval uses the separate facts API.
    function currentRoyaltySnapshotSource(uint256 collectionId)
        external
        view
        returns (Source memory);
    function royaltySnapshot(uint256 tokenId) external view returns (Snapshot memory);

    /// @dev Both expected and returned values are canonical ROYALTY_POLICY_V1 hashes.
    function snapshotTokenRoyaltyAtMint(
        uint256 tokenId,
        uint256 collectionId,
        bytes32 operationRoot,
        bytes32 operationId,
        bytes32 revenueClass,
        bytes32 expectedRoyaltyAssignmentHash
    ) external returns (bytes32 tokenRoyaltyAssignmentHash);
}
