// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamScopeMembershipTypes.sol";
import "./StreamArtworkFinalityTypes.sol";

/// @notice Complete, ordered coordinator-at-mint discovery for an authenticated token scope.
/// @dev Indexing-time code identities are not mint-time code proofs or entropy readiness.
interface IStreamFinalityCoordinatorInventory {
    struct Progress {
        bool exists;
        bool complete;
        uint256 processedTokens;
        uint256 tokenCount;
        uint256 coordinatorCount;
        bytes32 tokenChain;
        bytes32 coordinatorChain;
        bytes32 commitment;
    }

    struct Coordinator {
        address coordinator;
        bytes32 indexedCodeHash;
        uint256 firstTokenIndex;
    }

    event CoordinatorInventoryBegun(
        bytes32 indexed planId, bytes32 indexed scopeSubject, uint256 tokenCount
    );
    event OriginalCoordinatorIndexed(
        bytes32 indexed planId,
        uint256 indexed index,
        address indexed coordinator,
        bytes32 indexedCodeHash,
        uint256 firstTokenIndex
    );
    event CoordinatorInventoryProgressed(
        bytes32 indexed planId, uint256 processedTokens, uint256 coordinatorCount
    );
    event CoordinatorInventoryCompleted(bytes32 indexed planId, bytes32 commitment);

    function core() external view returns (address);
    function scopeMembershipHost() external view returns (address);
    function beginInventory(StreamFinalityScope calldata scope) external returns (bytes32 planId);
    function appendInventory(bytes32 planId, uint256 maximumTokens) external;
    function inventoryProgress(bytes32 planId) external view returns (Progress memory);
    function inventoryScope(bytes32 planId)
        external
        view
        returns (StreamFinalityScope memory, StreamScopeMembershipFacts memory);
    function coordinatorAt(bytes32 planId, uint256 index) external view returns (Coordinator memory);
    /// @notice Validates current membership and complete traversal, not live code of every entry.
    function requireCompleteInventory(bytes32 planId) external view returns (Progress memory);
    /// @notice Validates one recorded coordinator against its indexing-time runtime pin.
    /// @dev Does not require today's selected coordinator or reclassify this as mint-time code.
    function requireCoordinator(bytes32 planId, uint256 index)
        external
        view
        returns (Coordinator memory);
}
