// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Fixed linked-renderer input; authorization and provider reads remain in the router.
library StreamMetadataRenderTypes {
    /// @notice Fixed input and embedded-dependency profile, available without any renderer call.
    function profile() internal pure returns (bytes32, bytes32, bytes32) {
        return (
            keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1"),
            keccak256("6529STREAM_METADATA_TOKEN_RENDER_CONTEXT_V1"),
            keccak256("6529STREAM_METADATA_RENDER_NO_EXTERNAL_READS_V1")
        );
    }

    struct Token {
        uint256 tokenId;
        uint256 collectionId;
        uint256 serial;
        bytes32 seed;
        bool finalized;
        string state;
        bytes tokenData;
        bool configured;
    }
}
