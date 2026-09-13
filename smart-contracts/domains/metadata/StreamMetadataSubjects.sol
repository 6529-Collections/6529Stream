// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Canonical museum record subjects specified by [CMC-SUBJECT-ID].
/// @dev Shape validation is separate from the host's actual Core membership checks.
library StreamMetadataSubjects {
    bytes32 internal constant MEDIA_DOMAIN =
        0x030f2701e9035fcb711b3acc44ec0bf14b4f4e344e231cdaadce7d14e590994b;

    error InvalidMetadataScope();

    function scopeSubject(uint256 chainId, address core, StreamFinalityScope memory scope)
        internal
        pure
        returns (bytes32)
    {
        if (core == address(0) || scope.collectionId == 0) revert InvalidMetadataScope();
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            if (scope.tokenId != 0 || scope.scopeId != bytes32(0)) revert InvalidMetadataScope();
            return keccak256(
                abi.encode(
                    StreamFinalityDomains.STREAM_SUBJECT_COLLECTION_V1,
                    chainId,
                    core,
                    scope.collectionId
                )
            );
        }
        if (scope.scopeType == StreamFinalityScopeType.TOKEN) {
            if (scope.tokenId == 0 || scope.scopeId != bytes32(0)) revert InvalidMetadataScope();
            return keccak256(
                abi.encode(
                    StreamFinalityDomains.STREAM_SUBJECT_TOKEN_V1, chainId, core, scope.tokenId
                )
            );
        }
        if (scope.tokenId != 0 || scope.scopeId == bytes32(0)) revert InvalidMetadataScope();
        return keccak256(
            abi.encode(
                StreamFinalityDomains.STREAM_SUBJECT_SCOPE_V1,
                chainId,
                core,
                scope.collectionId,
                uint8(scope.scopeType),
                scope.scopeId
            )
        );
    }

    function mediaSubject(uint256 chainId, address core, uint256 collectionId, bytes32 objectId)
        internal
        pure
        returns (bytes32)
    {
        if (core == address(0) || collectionId == 0 || objectId == bytes32(0)) {
            revert InvalidMetadataScope();
        }
        return keccak256(abi.encode(MEDIA_DOMAIN, chainId, core, collectionId, objectId));
    }
}
