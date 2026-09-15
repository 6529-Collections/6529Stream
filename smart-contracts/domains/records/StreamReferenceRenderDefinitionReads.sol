// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import "./StreamReferenceRenderDefinitions.sol";
import "./StreamWorkRecordContext.sol";

library StreamReferenceRenderDefinitionReads {
    function requireDefinitions(StreamReferenceRenderTypes.Dependencies memory d) public view {
        StreamWorkRecordContext.Dependencies memory defs;
        for (uint256 i; i < 4; ++i) {
            defs.targets[i] = d.targets[i];
            defs.codeHashes[i] = d.codeHashes[i];
        }
        defs.chainId = d.chainId;
        defs.readGas = d.readGas;
        bytes32[7] memory ids = [
            StreamReferenceRenderDefinitions.SCHEMA_ID,
            StreamReferenceRenderDefinitions.PROFILE_ID,
            StreamReferenceRenderDefinitions.ENVIRONMENT_SCHEMA_ID,
            StreamReferenceRenderDefinitions.PNG_SCHEMA_ID,
            StreamReferenceRenderDefinitions.ZIP_SCHEMA_ID,
            StreamReferenceRenderDefinitions.FORMAT_CATALOG_ID,
            StreamReferenceRenderDefinitions.CANON_ID
        ];
        bytes32[7] memory hashes = [
            StreamReferenceRenderDefinitions.SCHEMA_HASH,
            StreamReferenceRenderDefinitions.PROFILE_HASH,
            StreamReferenceRenderDefinitions.ENVIRONMENT_SCHEMA_HASH,
            StreamReferenceRenderDefinitions.PNG_SCHEMA_HASH,
            StreamReferenceRenderDefinitions.ZIP_SCHEMA_HASH,
            StreamReferenceRenderDefinitions.FORMAT_CATALOG_HASH,
            StreamReferenceRenderDefinitions.CANON_HASH
        ];
        uint32[7] memory lengths = [
            StreamReferenceRenderDefinitions.SCHEMA_BYTES,
            StreamReferenceRenderDefinitions.PROFILE_BYTES,
            StreamReferenceRenderDefinitions.ENVIRONMENT_SCHEMA_BYTES,
            StreamReferenceRenderDefinitions.PNG_SCHEMA_BYTES,
            StreamReferenceRenderDefinitions.ZIP_SCHEMA_BYTES,
            StreamReferenceRenderDefinitions.FORMAT_CATALOG_BYTES,
            StreamReferenceRenderDefinitions.CANON_BYTES
        ];
        for (uint256 i; i < 7; ++i) {
            IStreamSchemaRegistry.DocumentKind kind = i == 6
                ? IStreamSchemaRegistry.DocumentKind.CANONICALIZATION
                : (i == 1 || i == 5)
                    ? IStreamSchemaRegistry.DocumentKind.CATALOG
                    : IStreamSchemaRegistry.DocumentKind.SCHEMA;
            StreamWorkRecordContext.definition(
                defs, ids[i], kind, hashes[i], lengths[i], keccak256("RAW_BYTES"), true
            );
        }
    }
}
