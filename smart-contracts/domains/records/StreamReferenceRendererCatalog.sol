// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import "./StreamReferenceRenderDefinitions.sol";
import "./StreamWorkRecordContext.sol";
import "./StreamSnapshotManifestJson.sol";

/// @notice Exact current registered class for one fixed renderer-version catalog.
/// @dev Registration is attributed classification, not EVM static analysis of artwork JavaScript.
library StreamReferenceRendererCatalog {
    function requireStatic(
        StreamReferenceRenderTypes.Dependencies memory d,
        StreamReferenceRenderTypes.RendererDeclaration memory value
    ) public view returns (StreamReferenceRenderTypes.RendererDeclaration memory) {
        if (value.rendererClass != keccak256("STATIC")) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        StreamWorkRecordContext.Dependencies memory defs;
        for (uint256 i; i < 4; ++i) {
            defs.targets[i] = d.targets[i];
            defs.codeHashes[i] = d.codeHashes[i];
        }
        defs.chainId = d.chainId;
        defs.readGas = d.readGas;
        StreamWorkRecordContext.definition(
            defs,
            StreamReferenceRenderDefinitions.RENDERER_SCHEMA_ID,
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            StreamReferenceRenderDefinitions.RENDERER_SCHEMA_HASH,
            StreamReferenceRenderDefinitions.RENDERER_SCHEMA_BYTES,
            keccak256("RAW_BYTES"),
            true
        );
        StreamWorkRecordContext.definition(
            defs,
            StreamReferenceRenderDefinitions.RENDERER_PROFILE_ID,
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            StreamReferenceRenderDefinitions.RENDERER_PROFILE_HASH,
            StreamReferenceRenderDefinitions.RENDERER_PROFILE_BYTES,
            keccak256("RAW_BYTES"),
            true
        );
        bytes memory exact = declarationJSON(value);
        if (keccak256(exact) != d.rendererCatalogHash || exact.length != d.rendererCatalogBytes) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        StreamWorkRecordContext.definition(
            defs,
            d.rendererCatalogId,
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            d.rendererCatalogHash,
            d.rendererCatalogBytes,
            keccak256("RAW_BYTES"),
            true
        );
        return value;
    }

    function declarationJSON(StreamReferenceRenderTypes.RendererDeclaration memory v)
        public
        pure
        returns (bytes memory)
    {
        if (
            v.renderer == address(0) || v.rendererCodeHash == 0 || v.routerVersion == 0
                || v.routerManifestHash == 0 || v.presentationProfile == 0 || v.rendererContext == 0
                || v.dependencyReadSet == 0
                || (v.rendererClass != keccak256("STATIC")
                    && v.rendererClass != keccak256("DYNAMIC"))
        ) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        string memory out = string.concat(
            '{"context":',
            StreamSnapshotManifestJson.hashJSON(v.rendererContext),
            ',"dependencyReadSet":',
            StreamSnapshotManifestJson.hashJSON(v.dependencyReadSet),
            ',"presentationProfile":',
            StreamSnapshotManifestJson.hashJSON(v.presentationProfile),
            ',"renderer":',
            StreamSnapshotManifestJson.accountJSON(v.renderer)
        );
        out = string.concat(
            out,
            ',"rendererClass":"',
            v.rendererClass == keccak256("STATIC") ? "STATIC" : "DYNAMIC",
            '","rendererCodeHash":',
            StreamSnapshotManifestJson.hashJSON(v.rendererCodeHash),
            ',"routerManifestHash":',
            StreamSnapshotManifestJson.hashJSON(v.routerManifestHash),
            ',"routerVersion":',
            StreamSnapshotManifestJson.hashJSON(v.routerVersion),
            ',"version":1}'
        );
        return bytes(out);
    }
}
