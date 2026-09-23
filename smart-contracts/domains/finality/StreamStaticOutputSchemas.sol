// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact registered interpretation; never relabel the original inline leaf manifest.
library StreamStaticOutputSchemas {
    bytes32 internal constant SCHEMA = keccak256("STREAM_STATIC_OUTPUT_MANIFEST_V1");
    bytes32 internal constant CANON = keccak256("STREAM_ABI_STATIC_OUTPUT_MANIFEST_V1");

    function document(bytes32 id) internal pure returns (bytes memory) {
        if (id == SCHEMA) {
            return bytes(
                '{"name":"STREAM_STATIC_OUTPUT_MANIFEST_V1","version":1,"profile":"6529STREAM_STATIC_CURRENT_FULL_CONTENT_V1","format":"Solidity ABI","scope":"Exact complete checkpoint scope; current profile excludes VIEW and non-ONCHAIN modes","rows":"Every original IStreamStaticContentCheckpoint.Output in exact checkpoint order","fields":["StreamTokenContentLeaf(uint256 tokenId,bytes32 metadataHash,bytes32 imageHash,bytes32 animationHash,bytes32 contentHash,bytes32 tokenDataHash)","bytes32 selectionRowHash","bytes32 sourceFactsHash","bytes32 htmlHash"],"commitments":"Original CMC six-field content tree plus distinct ordered output chain","preservation":"This artifact preserves output hashes and source commitments, not full JSON,HTML,image or tokenData bytes","authority":"Current artifact coverage and checkpoint computation do not establish artist association,publication authority or finality acceptance","history":"Current validation repeats full original outputs and current two-family archival completion; historical records remain readable"}'
            );
        }
        if (id == CANON) {
            return bytes(
                '{"name":"STREAM_ABI_STATIC_OUTPUT_MANIFEST_V1","version":1,"encoding":"abi.encode(bytes32 schemaId,uint256 chainId,address core,address checkpoint,bytes32 checkpointHash,bytes32 checkpointStateHash,StreamFinalityScope scope,bytes32 contentRoot,bytes32 outputRoot,uint64 tokenCount,IStreamStaticContentCheckpoint.Output[] rows)","schemaId":"keccak256(STREAM_STATIC_OUTPUT_MANIFEST_V1)","checkpointStateHash":"keccak256(abi.encode(complete original checkpoint Plan))","scope":"uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId","headBytes":448,"arrayOffset":448,"headerBytesIncludingArrayCount":480,"rowBytes":288,"length":"480+288*tokenCount","arrayCount":"Exactly positive tokenCount","words":"32-byte big-endian,addresses and narrow unsigned integers zero-extended","trailingBytes":"Forbidden","alternateOffsets":"Forbidden","rowOrder":"Exact checkpoint order","hash":"Keccak-256 of exact complete manifest bytes; not JCS"}'
            );
        }
        revert("unknown static output document");
    }
}
