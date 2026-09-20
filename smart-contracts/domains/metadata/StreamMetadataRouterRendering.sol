// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamMetadataRouter } from "./StreamMetadataRouter.sol";
import { StreamMetadataBundleRenderer } from "./StreamMetadataBundleRenderer.sol";
import "./StreamMetadataRecoveryRoutes.sol";
import "../../interfaces/stream/core/IStreamCore.sol";
import { StreamMetadataFinalityServing } from "./StreamMetadataFinalityServing.sol";
import { StreamMetadataTokenReads } from "./StreamMetadataTokenReads.sol";
import { StreamMetadataDisplayParameters } from "./StreamMetadataDisplayParameters.sol";
import { StreamArtistDisplayJSON } from "./StreamArtistDisplayJSON.sol";
import { StreamMetadataTokenRenderer } from "./StreamMetadataTokenRenderer.sol";
import {
    IStreamScriptBundles as B
} from "../../interfaces/stream/metadata/IStreamScriptBundles.sol";
import {
    StreamCollectionManifestTypes as M
} from "../../interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import {
    IStreamMetadataServingFacts as F
} from "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    StreamMetadataRenderTypes as T
} from "../../interfaces/stream/metadata/StreamMetadataRenderTypes.sol";

interface IStreamRouterLiveFrame {
    function liveAttributionObject(uint256 collectionId, uint256 tokenId)
        external
        view
        returns (bytes memory);
}

/// @notice Fixed delegatecall renderer orchestration; all storage roots and immutables come from Router.
library StreamMetadataRouterRendering {
    struct Context {
        address core;
        address artist;
        bytes32 artistCodeHash;
        StreamMetadataRecoveryRoutes.OriginalAnchor anchor;
    }
    error TokenEntropyNotFinalized(uint256 tokenId);

    function serve(
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
        bool allowBurned,
        uint8 mode
    ) public view returns (string memory) {
        StreamMetadataRecoveryRoutes.Environment memory env =
            StreamMetadataRecoveryRoutes.Environment(x.core, x.artist, x.artistCodeHash);
        bool frozen;
        string memory result;
        if (mode >= 2) {
            if (mode == 4) {
                (frozen, result) = StreamMetadataFinalityServing.historicalFullToken(
                    presentations, anchors, env, x.anchor, tokenId
                );
            } else {
                (frozen, result) = StreamMetadataFinalityServing.fullToken(
                    presentations, anchors, env, x.anchor, tokenId, mode == 3
                );
            }
        } else {
            (frozen, result) = StreamMetadataFinalityServing.token(
                presentations, anchors, env, x.anchor, tokenId, allowBurned, mode == 1
            );
        }
        if (frozen) return result;
        StreamMetadataTokenReads.TokenFacts memory facts =
            StreamMetadataTokenReads.facts(x.core, tokenId, allowBurned);
        if (allowBurned && !facts.finalized) revert TokenEntropyNotFinalized(tokenId);
        if (mode == 2 || mode == 3) {
            (,,, bool burned) = IStreamCore(x.core).tokenCollectionIdentity(tokenId);
            if (burned) facts.state = "burned";
        }
        StreamMetadataRouter.PreparedMetadata storage p = prepared[facts.collectionId];
        F.ServingSource memory metadata =
            F.ServingSource(p.name, p.description, p.image, p.animationBaseURI, p.animationScript);
        T.Token memory token = T.Token(
            tokenId,
            facts.collectionId,
            facts.serial,
            facts.seed,
            facts.finalized,
            facts.state,
            IStreamCore(x.core).tokenData(tokenId),
            collections[facts.collectionId].configured
        );
        bool nestedArtist = !(allowBurned && presentations[facts.collectionId].locked);
        bytes memory artist = !nestedArtist
            ? StreamMetadataTokenReads.artistJSON(presentations, x.artist, facts.collectionId)
            : live(facts.collectionId, tokenId);
        B.Selection memory bundle =
            StreamMetadataBundleRenderer.selection(selections[facts.collectionId][2]);
        if (bundle.bundleId != 0) {
            StreamMetadataBundleRenderer.requireLive(bundle, x.core);
            return StreamMetadataBundleRenderer.renderCurrent(
                mode == 4 ? 2 : mode,
                token,
                metadata,
                artist,
                nestedArtist,
                bundle,
                address(this),
                block.chainid,
                x.core
            );
        }
        if (mode == 3) return StreamMetadataTokenRenderer.html(token, metadata);
        return StreamMetadataTokenRenderer.renderCurrent(
            mode == 4 ? 2 : mode, token, metadata, artist, nestedArtist, block.chainid, x.core
        );
    }

    function live(uint256 collectionId, uint256 tokenId) public view returns (bytes memory) {
        uint256 cap =
            StreamMetadataDisplayParameters.value(StreamMetadataDisplayParameters.OUTER_GAS);
        uint256 reserve =
            StreamMetadataDisplayParameters.value(StreamMetadataDisplayParameters.RETURN_GAS);
        uint256 available = gasleft();
        if (available <= reserve) return StreamArtistDisplayJSON.unavailable();
        available -= reserve;
        if (cap > available || available - cap < cap / 63) {
            return StreamArtistDisplayJSON.unavailable();
        }
        bytes memory input =
            abi.encodeCall(IStreamRouterLiveFrame.liveAttributionObject, (collectionId, tokenId));
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, address(), add(input, 32), mload(input), 0, 0)
            size := returndatasize()
        }
        if (!ok || size < 64 || size > 32768 + 64) {
            return StreamArtistDisplayJSON.unavailable();
        }
        bytes memory raw = new bytes(size);
        assembly ("memory-safe") { returndatacopy(add(raw, 32), 0, size) }
        uint256 offset;
        uint256 length;
        assembly ("memory-safe") {
            offset := mload(add(raw, 32))
            length := mload(add(raw, 64))
        }
        if (offset != 32 || length > 32768 || size != 64 + ((length + 31) / 32) * 32) {
            return StreamArtistDisplayJSON.unavailable();
        }
        bytes memory value = abi.decode(raw, (bytes));
        if (keccak256(raw) != keccak256(abi.encode(value))) {
            return StreamArtistDisplayJSON.unavailable();
        }
        return value;
    }
}
