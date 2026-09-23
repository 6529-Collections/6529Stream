// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamFinalityScope } from "./StreamArtworkFinalityTypes.sol";

/// @notice Complete ordered VIEW output preservation; preparation is not publication authority.
library StreamViewPreservationManifestTypesV1 {
    bytes32 internal constant PROFILE =
        keccak256("6529STREAM_ADOPTED_VIEW_PRESERVATION_MANIFEST_V1");
    uint256 internal constant PART_ROWS = 64;
    uint256 internal constant MAX_ROWS = 16384;
    uint256 internal constant MAX_BYTES = 524288;

    struct Configuration {
        address core;
        bytes32 coreCodeHash;
        address checkpoint;
        bytes32 checkpointCodeHash;
        bytes32 checkpointConfigurationHash;
        address coverage;
        bytes32 coverageCodeHash;
        address schemas;
        bytes32 schemasCodeHash;
        uint256 chainId;
        uint32 readGas;
        uint32 checkpointGas;
    }

    /// @dev Thirteen static words. The full four-word scope is never replaced by its numeric id.
    struct Header {
        bytes32 checkpointId;
        bytes32 checkpointStateHash;
        StreamFinalityScope scope;
        bytes32 adoptionRecord;
        bytes32 sourceContextHash;
        bytes32 membershipHash;
        bytes32 policyChainHash;
        uint64 tokenCount;
        bytes32 outputRoot;
        bytes32 contentRoot;
    }

    struct Carrier {
        bytes32 artifactHash;
        bytes32 coverageHash;
        bytes32 artistId;
        bytes32 contentHash;
        uint64 byteLength;
    }

    struct Part {
        Header header;
        Carrier carrier;
        uint64 first;
        uint16 count;
        uint256 firstToken;
        uint256 lastToken;
    }

    /// @dev Nine static words; every value comes from a verified immutable Part.
    struct Descriptor {
        bytes32 recordHash;
        bytes32 artifactHash;
        bytes32 coverageHash;
        bytes32 contentHash;
        uint64 byteLength;
        uint64 first;
        uint16 count;
        uint256 firstToken;
        uint256 lastToken;
    }

    struct Plan {
        Header header;
        Carrier carrier;
        uint16 partCount;
        uint16 nextPart;
        uint64 nextRow;
        uint256 previousToken;
        bytes32 partChain;
        bytes32 recordHash;
    }
    error InvalidViewManifest();
    error ViewManifestUnknown(bytes32 key);
    error ViewManifestOrder(uint256 index);
    error ViewManifestChanged(bytes32 key);
    error ViewManifestChunk(address pointer);
}
