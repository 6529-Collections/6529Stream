// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamRoyaltyResolver } from "./IStreamRoyaltyResolver.sol";

/// @notice Additive exact-key royalty mutations and historical token terms.
/// @dev Governance authority is the resolver's pinned owner. Bound assignment
///      mutations separately require current artist economics consent.
interface IStreamTokenRoyaltyResolver {
    error InvalidRoyaltyScope(uint8 scope, uint256 scopeId);
    error InvalidRoyaltyToken(uint256 tokenId);
    error RoyaltyAssignmentMissing(uint8 scope, uint256 scopeId);
    error RoyaltyAssignmentFrozen(uint8 scope, uint256 scopeId);

    event RevenueAssignmentSet(
        bytes32 indexed revenueClass,
        uint8 indexed scope,
        uint256 indexed scopeId,
        uint16 schemaVersion,
        address actor,
        bytes32 previousProfileOrTemplateId,
        address previousWallet,
        uint16 previousRoyaltyBps,
        bytes32 profileOrTemplateId,
        address wallet,
        uint16 royaltyBps,
        bool isTemplate,
        bool looseningAdvertised,
        bytes32 looseningTermsHash
    );

    event RevenueAssignmentCleared(
        bytes32 indexed revenueClass,
        uint8 indexed scope,
        uint256 indexed scopeId,
        uint16 schemaVersion,
        address actor,
        bytes32 previousProfileOrTemplateId,
        address previousWallet,
        uint16 previousRoyaltyBps,
        bool wasTemplate
    );

    event RevenueAssignmentFrozen(
        bytes32 indexed revenueClass,
        uint8 indexed scope,
        uint256 indexed scopeId,
        uint16 schemaVersion,
        bool permanent,
        uint8 freezeMode
    );

    /// @notice Exact key outcome; a clear records zero and does not relabel inherited rights.
    event RoyaltyAssignmentContext(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint256 indexed tokenId,
        bytes32 indexed assignmentHash,
        uint8 scope,
        uint256 scopeId,
        bytes32 previousAssignmentHash,
        bytes32 royaltyPolicyHash,
        address actor
    );

    function configureTokenRoyalty(uint256 tokenId, bytes32 profileId, uint16 royaltyBps) external;
    function clearTokenRoyalty(uint256 tokenId) external;
    function clearCollectionRoyalty(uint256 collectionId) external;

    /// @notice Materializes current token/ancestor terms and permanently freezes the token key.
    /// @dev Artist consent binds the resulting frozen token hash. This is not the
    ///      collection-only unilateral artist freeze authorization surface.
    function freezeTokenRoyalty(uint256 tokenId) external;

    function tokenRoyalty(uint256 tokenId)
        external
        view
        returns (IStreamRoyaltyResolver.RoyaltyConfig memory);
}
