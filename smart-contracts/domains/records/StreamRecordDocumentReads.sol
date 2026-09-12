// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import "../metadata/StreamSchemaDocumentStore.sol";

/// @notice Bounded interpretation and payload reads shared by record hosts.
/// @dev Public library functions keep dynamic document decoding outside the host runtime.
library StreamRecordDocumentReads {
    function activeSchema(address registry, bytes32 schemaId, bytes32 canonId, uint256 gasCap)
        public
        view
        returns (bytes32, bytes32)
    {
        IStreamSchemaRegistry.DocumentView memory schema = abi.decode(
            _read(
                registry, abi.encodeCall(IStreamSchemaRegistry.document, (schemaId)), 8192, gasCap
            ),
            (IStreamSchemaRegistry.DocumentView)
        );
        IStreamSchemaRegistry.DocumentView memory canon = abi.decode(
            _read(
                registry, abi.encodeCall(IStreamSchemaRegistry.document, (canonId)), 8192, gasCap
            ),
            (IStreamSchemaRegistry.DocumentView)
        );
        if (
            !schema.exists || schema.status != IStreamSchemaRegistry.DocumentStatus.ACTIVE
                || schema.specification.kind != IStreamSchemaRegistry.DocumentKind.SCHEMA
        ) revert IStreamCollectionMetadataV1.MetadataSchemaUnavailable(schemaId);
        if (
            !canon.exists || canon.status != IStreamSchemaRegistry.DocumentStatus.ACTIVE
                || canon.specification.kind != IStreamSchemaRegistry.DocumentKind.CANONICALIZATION
        ) revert IStreamCollectionMetadataV1.MetadataSchemaUnavailable(canonId);
        return (schema.specification.contentHash, canon.specification.contentHash);
    }

    function chunk(address store, bytes32 hash, uint256 gasCap) public view returns (bytes memory) {
        return abi.decode(
            _read(store, abi.encodeCall(StreamSchemaDocumentStore.readChunk, (hash)), 8352, gasCap),
            (bytes)
        );
    }

    function _read(address target, bytes memory input, uint256 maximum, uint256 cap)
        private
        view
        returns (bytes memory data)
    {
        if (gasleft() <= cap + cap / 63 + 10000) {
            revert IStreamCollectionMetadataV1.MetadataReadFailed(target);
        }
        data = new bytes(maximum);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(data, 32), maximum)
            size := returndatasize()
        }
        if (!ok || size > maximum) revert IStreamCollectionMetadataV1.MetadataReadFailed(target);
        assembly ("memory-safe") { mstore(data, size) }
    }
}
