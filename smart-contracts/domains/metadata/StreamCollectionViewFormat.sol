// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact immutable ABI carrier definition; referenced view documents have their own schemas.
library StreamCollectionViewFormat {
    bytes32 internal constant SCHEMA_ID = keccak256("STREAM_COLLECTION_VIEW_MANIFEST_ABI_V1");
    string internal constant DEFINITION =
        "{\"name\":\"STREAM_COLLECTION_VIEW_MANIFEST_ABI_V1\",\"encoding\":\"Solidity abi.encode\",\"canonicalization\":\"RAW_BYTES\",\"types\":[\"uint256\",\"uint64\",\"bytes32\",\"(bytes32,bytes32,string,bytes32,string,bool)\"],\"fields\":[\"collectionId\",\"revision\",\"previousRecordHash\",\"manifest\"],\"manifestFields\":[\"viewId\",\"schemaId\",\"uri\",\"contentHash\",\"mimeType\",\"defaultForView\"],\"contentHash\":\"keccak256 over exact retained referenced-view bytes\",\"authority\":\"DISPLAY class 7 or 8; no Artist consent or renderer adoption\"}";

    function definition() internal pure returns (bytes memory) {
        return bytes(DEFINITION);
    }

    function hash() internal pure returns (bytes32) {
        return keccak256(bytes(DEFINITION));
    }
}
