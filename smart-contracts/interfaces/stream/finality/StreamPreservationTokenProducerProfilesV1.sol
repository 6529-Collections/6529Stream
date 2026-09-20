// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Closed token producer family; VIEW output is a separate interpretation.
/// @dev Family admission never substitutes for the exact selected Registry/version admission.
library StreamPreservationTokenProducerProfilesV1 {
    bytes32 internal constant ORIGINAL_PROFILE = keccak256("6529STREAM_PRESERVATION_RENDER_V1");
    bytes32 internal constant CURRENT_ARTIST_PROFILE =
        keccak256("6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1");
    bytes32 internal constant FAMILY_PROFILE = keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2");
    bytes32 internal constant COLLECTION_CHECKPOINT_PROFILE =
        keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_CHECKPOINT_V2");
    bytes32 internal constant SCOPED_CHECKPOINT_PROFILE =
        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_CHECKPOINT_V2");
    bytes32 internal constant OUTPUT_MANIFEST_PROFILE =
        keccak256("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2");

    function isSupported(bytes32 profile) internal pure returns (bool) {
        return profile == ORIGINAL_PROFILE || profile == CURRENT_ARTIST_PROFILE;
    }
}
