// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamMetadataRouterContent as Content } from "./StreamMetadataRouterContent.sol";
import { StreamMetadataRouter } from "./StreamMetadataRouter.sol";
import { StreamMetadataContentRoot } from "./StreamMetadataContentRoot.sol";
import {
    StreamMetadataScopedContentState as ScopedState
} from "./StreamMetadataScopedContentState.sol";
import { StreamMetadataStaticState as StaticState } from "./StreamMetadataStaticState.sol";
import { StreamMetadataRenderer } from "./StreamMetadataRenderer.sol";
import {
    StreamCollectionManifestTypes as M
} from "../../interfaces/stream/metadata/StreamCollectionManifestTypes.sol";

/// @notice Exact common Router content-state read, separated to keep its mutation worker bounded.
/// @dev Same original compiler-derived roots, formula and read order; no independent authority.
library StreamMetadataRouterContentState {
    function current(Content.Layout memory l, Content.Context memory e, uint256 collectionId)
        public
        view
        returns (bytes32)
    {
        StreamMetadataRouter.CollectionMetadata storage metadata = _collections(l)[collectionId];
        bytes32 serving = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROUTER_ONCHAIN_CONTENT_V1"),
                _hostContext(e.core, collectionId),
                keccak256(bytes(metadata.image)),
                keccak256(bytes(metadata.animationBaseURI)),
                keccak256(bytes(metadata.animationScript))
            )
        );
        bytes32 rootHead = _contentRoots(l).heads[collectionId];
        if (rootHead != 0) {
            serving = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ROUTER_CONTENT_WITH_ROOT_V1"),
                    serving,
                    _contentRoots(l).records[rootHead].stateHash
                )
            );
        }
        M.Selection memory script = _selectedManifests(l)[collectionId][2];
        M.Selection memory media = _selectedManifests(l)[collectionId][3];
        if (script.manifestHash != 0 || media.manifestHash != 0) {
            serving = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ROUTER_CONTENT_WITH_MANIFESTS_V1"), serving, script, media
                )
            );
        }
        serving = ScopedState.servingCurrent(e.core, collectionId, serving);
        return StaticState.withContent(e.core, collectionId, serving);
    }

    function script(address core, uint256 collectionId, string memory script)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ROUTER_CONTENT_FAMILY_V1"),
                _hostContext(core, collectionId),
                keccak256("SCRIPT"),
                keccak256(bytes(script))
            )
        );
    }

    function media(address core, uint256 collectionId, string memory image, string memory baseURI)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ROUTER_CONTENT_FAMILY_V1"),
                _hostContext(core, collectionId),
                keccak256("MEDIA_MANIFEST"),
                keccak256(bytes(image)),
                keccak256(bytes(baseURI))
            )
        );
    }

    function family(
        Content.Layout memory l,
        Content.Context memory e,
        uint256 collectionId,
        bytes32 familyId
    ) public view returns (bool supported, bytes32 currentStateHash) {
        if (familyId == StaticState.FAMILY) {
            return (true, StaticState.family(e.core, collectionId));
        }
        if (familyId == keccak256("CONTENT_ROOT")) {
            return (
                true,
                ScopedState.familyCurrent(
                    e.core,
                    collectionId,
                    StreamMetadataContentRoot.familyState(_contentRoots(l), e.core, collectionId)
                )
            );
        }
        StreamMetadataRouter.CollectionMetadata storage metadata = _collections(l)[collectionId];
        if (familyId == keccak256("SCRIPT")) {
            return (
                true,
                _withManifest(
                    script(e.core, collectionId, metadata.animationScript),
                    _selectedManifests(l)[collectionId][2]
                )
            );
        }
        if (familyId == keccak256("MEDIA_MANIFEST")) {
            return (
                true,
                _withManifest(
                    media(e.core, collectionId, metadata.image, metadata.animationBaseURI),
                    _selectedManifests(l)[collectionId][3]
                )
            );
        }
        return (false, bytes32(0));
    }

    function _withManifest(bytes32 rawState, M.Selection memory selection)
        private
        pure
        returns (bytes32)
    {
        if (selection.manifestHash == 0) return rawState;
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ROUTER_CONTENT_FAMILY_WITH_MANIFEST_V1"), rawState, selection
            )
        );
    }

    function _collections(Content.Layout memory l)
        private
        pure
        returns (mapping(uint256 => StreamMetadataRouter.CollectionMetadata) storage value)
    {
        uint256 slot = l._collections;
        assembly ("memory-safe") { value.slot := slot }
    }

    function _contentRoots(Content.Layout memory l)
        private
        pure
        returns (StreamMetadataContentRoot.State storage value)
    {
        uint256 slot = l._contentRoots;
        assembly ("memory-safe") { value.slot := slot }
    }

    function _selectedManifests(Content.Layout memory l)
        private
        pure
        returns (mapping(uint256 => mapping(uint8 => M.Selection)) storage value)
    {
        uint256 slot = l._selectedManifests;
        assembly ("memory-safe") { value.slot := slot }
    }

    function _hostContext(address core, uint256 collectionId) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                block.chainid,
                core,
                collectionId,
                address(this),
                address(this).codehash,
                address(StreamMetadataRenderer),
                address(StreamMetadataRenderer).codehash
            )
        );
    }
}
