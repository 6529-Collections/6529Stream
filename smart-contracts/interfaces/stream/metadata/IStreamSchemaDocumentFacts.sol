// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamSchemaRegistry.sol";

/// @notice Bounded document facts without copying registration names, URIs or chunk arrays.
/// @dev Additive to the original registry interface. Declaration hash retains provenance;
///      these facts do not reconstruct the omitted name and URI declaration preimage.
interface IStreamSchemaDocumentFacts {
    struct DocumentFacts {
        bool exists;
        IStreamSchemaRegistry.DocumentKind kind;
        IStreamSchemaRegistry.DocumentStatus status;
        bytes32 contentHash;
        bytes32 canonicalizationId;
        bytes32 supersedesId;
        uint32 totalBytes;
        uint256 chunkCount;
        bytes32 declarationHash;
    }

    /// @dev Exactly nine ABI words. Unknown IDs return zero-valued facts with exists=false.
    function documentFacts(bytes32 documentId) external view returns (DocumentFacts memory);

    /// @dev Original document ordering, including repetitions. Unknown IDs/indices revert.
    function documentChunkHashAt(bytes32 documentId, uint256 index) external view returns (bytes32);
}
