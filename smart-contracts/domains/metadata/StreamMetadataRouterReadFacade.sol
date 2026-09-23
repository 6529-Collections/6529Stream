// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamMetadataRouter } from "./StreamMetadataRouter.sol";
import { StreamMetadataRouterRendering } from "./StreamMetadataRouterRendering.sol";
import { StreamMetadataFinalityServing } from "./StreamMetadataFinalityServing.sol";
import { StreamMetadataRecoveryRoutes } from "./StreamMetadataRecoveryRoutes.sol";
import { StreamMetadataDisplayParameters } from "./StreamMetadataDisplayParameters.sol";
import { StreamMetadataRenderPreparation } from "./StreamMetadataRenderPreparation.sol";
import { StreamMetadataStaticState as StaticState } from "./StreamMetadataStaticState.sol";
import { StreamMetadataStaticRouting as StaticRouting } from "./StreamMetadataStaticRouting.sol";
import { StreamRendererCalls as StaticCalls } from "./StreamRendererCalls.sol";
import { IStreamCoreIdentity } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import {
    IStreamMetadataServingFacts as F
} from "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    StreamCollectionManifestTypes as M
} from "../../interfaces/stream/metadata/StreamCollectionManifestTypes.sol";

/// @notice Original token and collection read orchestration, moved without any storage writes.
/// @dev The Router supplies compiler-owned references and its original immutable/stored facts.
/// The initialized-anchor check remains lazy, after the original token identity/STATIC branch.
library StreamMetadataRouterReadFacade {
    struct Context {
        address core;
        address artist;
        bytes32 artistCodeHash;
        bool anchorInitialized;
        StreamMetadataRecoveryRoutes.OriginalAnchor anchor;
    }
    error OriginalFinalityAnchorUninitialized();

    function token(
        mapping(uint256 => StreamMetadataRouter.PreparedMetadata) storage prepared,
        mapping(
            uint256 => StreamMetadataRouter.CollectionMetadata
        ) storage collections,
        mapping(uint256 => F.ArtistPresentation) storage presentations,
        mapping(
            uint256 => StreamMetadataRecoveryRoutes.OriginalAnchor
        ) storage anchors,
        mapping(uint256 => mapping(uint8 => M.Selection)) storage selections,
        Context memory x,
        uint256 tokenId,
        StreamMetadataRouter.TokenViewOptions memory options
    ) public view returns (string memory) {
        bool allowBurned = options.allowBurned;
        uint8 mode = options.mode;
        // Probe only dispatch identity. Unknown tokens retain the original legacy finality/
        // identity error path; the strict new config reads still use _staticCollection.
        bytes memory identity = StaticCalls.read(
            x.core,
            abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (tokenId)),
            StaticCalls.ReadOptions(128, true),
            StreamMetadataDisplayParameters.value(StreamMetadataDisplayParameters.READ_GAS)
        );
        (bool exists, uint256 staticCollection,,) =
            abi.decode(identity, (bool, uint256, uint256, bool));
        if (exists && StaticState.activated(staticCollection)) {
            return StaticRouting.serve(x.core, tokenId, allowBurned, mode);
        }
        return StreamMetadataRouterRendering.serve(
            prepared,
            collections,
            presentations,
            anchors,
            selections,
            StreamMetadataRouterRendering.Context(x.core, x.artist, x.artistCodeHash, _anchor(x)),
            tokenId,
            allowBurned,
            mode
        );
    }

    function collection(
        mapping(uint256 => StreamMetadataRouter.PreparedMetadata) storage prepared,
        mapping(
            uint256 => F.ArtistPresentation
        ) storage presentations,
        mapping(uint256 => StreamMetadataRecoveryRoutes.OriginalAnchor) storage anchors,
        Context memory x,
        uint256 collectionId
    ) public view returns (string memory) {
        (bool frozen, string memory resolved) = StreamMetadataFinalityServing.collection(
            presentations,
            anchors,
            StreamMetadataRecoveryRoutes.Environment(x.core, x.artist, x.artistCodeHash),
            _anchor(x),
            collectionId
        );
        if (frozen) return resolved;
        StreamMetadataRouter.PreparedMetadata storage metadata = prepared[collectionId];
        return StreamMetadataRenderPreparation.attributedCollectionURI(
            metadata.name,
            metadata.description,
            metadata.image,
            StreamMetadataRouterRendering.live(collectionId, 0)
        );
    }

    function _anchor(Context memory x)
        private
        pure
        returns (StreamMetadataRecoveryRoutes.OriginalAnchor memory)
    {
        if (!x.anchorInitialized) revert OriginalFinalityAnchorUninitialized();
        return x.anchor;
    }
}
