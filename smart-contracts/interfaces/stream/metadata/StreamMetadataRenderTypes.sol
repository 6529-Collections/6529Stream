// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Fixed linked-renderer input; authorization and provider reads remain in the router.
library StreamMetadataRenderTypes {
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
