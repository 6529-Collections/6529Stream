// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Pre-mint binding of an immutable ordered recovery policy to a collection.
interface IStreamEntropyCollectionRecovery is IERC165 {
    struct CollectionRecovery {
        bytes32 policyId;
        bytes32 policyHash;
        uint16 maxFreshRecoveryAttempts;
        uint64 revision;
        bytes32 lastActionId;
    }
    error InvalidCollectionRecovery(uint256 collectionId);
    error CollectionRecoveryReplay(uint256 collectionId, bytes32 actionId);
    event CollectionFreshRecoveryConfigured(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed policyId,
        bytes32 policyHash,
        uint16 maxFreshRecoveryAttempts,
        uint32 providerEpoch,
        uint64 revision,
        bytes32 actionId
    );
    function configureCollectionFreshRecovery(
        uint256 collectionId,
        uint16 maxFreshRecoveryAttempts,
        bytes32 policyId
    ) external;
    function collectionFreshRecovery(uint256 collectionId)
        external
        view
        returns (CollectionRecovery memory);
    function collectionFreshRecoveryTransition(
        uint256 collectionId,
        uint16 maxFreshRecoveryAttempts,
        bytes32 policyId
    ) external view returns (bytes32 scope, bytes32 oldHash, bytes32 newHash);
}
