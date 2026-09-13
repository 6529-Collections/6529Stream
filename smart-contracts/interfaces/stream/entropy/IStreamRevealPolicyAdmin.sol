// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Collection reveal operations authorized by the current ROLE_ENTROPY_ADMIN.
interface IStreamRevealPolicyAdmin is IERC165 {
    event RevealPolicyConfigured(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint8 requestMode,
        bytes32 revealOwnerRole,
        uint64 requestSLOBlocks,
        uint256 revealFeePerTokenWei
    );
    event RevealFeePerTokenUpdated(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint256 oldRevealFeePerTokenWei,
        uint256 newRevealFeePerTokenWei
    );
    event RevealFeeEscrowFunded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed funder,
        uint256 amountWei,
        uint256 escrowWei
    );
    event RevealFeeEscrowSpent(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint256 indexed tokenId,
        uint256 amountWei,
        uint256 escrowWei
    );
    event RevealFeeEscrowWithdrawn(
        uint16 schemaVersion, uint256 indexed collectionId, address indexed to, uint256 amountWei
    );

    function configureCollectionRevealPolicy(
        uint256 collectionId,
        uint8 requestMode,
        bytes32 revealOwnerRole,
        uint64 requestSLOBlocks,
        uint256 revealFeePerTokenWei
    ) external;
    function updateRevealFeePerToken(uint256 collectionId, uint256 newRevealFeePerTokenWei) external;
    function withdrawRevealFeeEscrow(uint256 collectionId, uint256 amountWei) external;
}
