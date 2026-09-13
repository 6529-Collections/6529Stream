// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/artist/IStreamArtistContentAuthority.sol";

/// @notice Fixed-library application of exact artist freeze authorization in Router storage.
library StreamMetadataContentLocks {
    error InvalidArtistContentFreeze(bytes32 recordHash);
    event CollectionMetadataLocked(
        uint256 indexed collectionId,
        bytes32 indexed lockId,
        address actor,
        uint8 authorityClass,
        bytes32 freezeAuthorizationHash,
        uint16 schemaVersion
    );

    function applyFreeze(
        mapping(uint256 => mapping(bytes32 => bool)) storage locks,
        address artist,
        uint256 collectionId,
        bytes32 freezeRecordHash,
        bytes32 currentState
    ) public {
        IStreamArtistContentAuthority authority = IStreamArtistContentAuthority(artist);
        C.FreezeRecord memory record = authority.contentFreezeAuthorization(freezeRecordHash);
        if (
            freezeRecordHash == 0 || record.recordHash != freezeRecordHash || record.artistId == 0
                || record.metadataContract != address(this) || record.authorityClass == 0
                || record.lockClasses.length == 0 || record.lockClasses.length > 16
                || record.expectedStateHash != currentState
        ) revert InvalidArtistContentFreeze(freezeRecordHash);
        bytes32 previous;
        for (uint256 i; i < record.lockClasses.length; ++i) {
            bytes32 lockClass = record.lockClasses[i];
            if (
                lockClass <= previous
                    || (lockClass != keccak256("SCRIPT")
                        && lockClass != keccak256("MEDIA_MANIFEST")
                        && lockClass != keccak256("BASE_URI")
                        && lockClass != keccak256("DEPENDENCIES"))
            ) revert InvalidArtistContentFreeze(freezeRecordHash);
            (bool authorized, bytes32 operative) =
                authority.isContentFreezeAuthorized(collectionId, lockClass);
            if (!authorized || operative != freezeRecordHash) {
                revert InvalidArtistContentFreeze(freezeRecordHash);
            }
            previous = lockClass;
        }
        for (uint256 i; i < record.lockClasses.length; ++i) {
            bytes32 lockClass = record.lockClasses[i];
            if (locks[collectionId][lockClass]) continue;
            locks[collectionId][lockClass] = true;
            emit CollectionMetadataLocked(
                collectionId, lockClass, msg.sender, record.authorityClass, freezeRecordHash, 1
            );
        }
    }
}
