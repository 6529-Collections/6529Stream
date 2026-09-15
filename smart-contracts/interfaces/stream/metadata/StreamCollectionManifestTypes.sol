// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Full typed manifest facts; no hash is inferred from a URI.
library StreamCollectionManifestTypes {
    enum PayloadSourceType {
        NONE,
        INLINE_CHUNKS,
        SSTORE2,
        ETHFS,
        DEPENDENCY_REGISTRY,
        IPFS,
        ARWEAVE,
        HTTPS,
        WEB3_CALL
    }

    struct ScriptManifest {
        bytes32 scriptHash;
        bytes32 rendererCompatibility;
        PayloadSourceType sourceType;
        string libraryURI;
        string scriptURI;
        string sourcePointer;
        string mimeType;
        uint256 chunkCount;
        bool executable;
    }

    struct MediaManifest {
        PayloadSourceType imageSourceType;
        string imageURI;
        bytes32 imageHash;
        string imageMimeType;
        PayloadSourceType animationSourceType;
        string animationURI;
        bytes32 animationHash;
        string animationMimeType;
        PayloadSourceType contentSourceType;
        string contentURI;
        bytes32 contentHash;
        string contentMimeType;
        string manifestURI;
        bytes32 manifestHash;
        string alternatesURI;
        bytes32 alternatesHash;
    }

    struct Selection {
        address host;
        bytes32 codeHash;
        bytes32 manifestHash;
    }
}
