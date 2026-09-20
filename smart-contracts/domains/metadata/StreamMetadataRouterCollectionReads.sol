// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamMetadataRouter } from "./StreamMetadataRouter.sol";
import { StreamMetadataArtistPresentation } from "./StreamMetadataArtistPresentation.sol";
import { StreamMetadataRecoveryRoutes } from "./StreamMetadataRecoveryRoutes.sol";
import {
    IStreamMetadataServingFacts
} from "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import { IStreamCore } from "../../interfaces/stream/core/IStreamCore.sol";
import { StreamMetadataRouterContent as Content } from "./StreamMetadataRouterContent.sol";
import { StreamMetadataStaticState as ConfigState } from "./StreamMetadataStaticState.sol";
import { StreamMetadataBundleRenderer as Bundle } from "./StreamMetadataBundleRenderer.sol";
import { StreamMetadataTokenRenderer as TokenRenderer } from "./StreamMetadataTokenRenderer.sol";
import {
    IStreamScriptBundles as Bundles
} from "../../interfaces/stream/metadata/IStreamScriptBundles.sol";
import {
    IStreamStaticMetadataRouter as Config
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import { IStreamRenderer as Render } from "../../interfaces/stream/metadata/IStreamRenderer.sol";
import {
    StreamCollectionManifestTypes as Manifests
} from "../../interfaces/stream/metadata/StreamCollectionManifestTypes.sol";

/// @notice Storage-backed raw collection reads; never routes or reads current finality.
/// @dev Router import supplies only its permanent nested storage type. Every storage root,
///      Core and actual linked renderer address is supplied by the fixed Router call site.
library StreamMetadataRouterCollectionReads {
    bytes32 private constant PRESENTATION_PROFILE =
        keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1");
    bytes32 private constant CONTENT_SCRIPT = keccak256("SCRIPT");
    bytes32 private constant CONTENT_MEDIA = keccak256("MEDIA_MANIFEST");
    bytes32 private constant LOCK_BASE_URI = keccak256("BASE_URI");
    error InvalidCollection(uint256 collectionId);
    error UnsupportedRouterCollectionSelector(bytes4 selector);
    error PresentationAlreadyLocked(uint256 collectionId, bytes32 lockId);
    event CollectionMetadataLocked(
        uint256 indexed collectionId,
        bytes32 indexed lockId,
        address actor,
        uint8 authorityClass,
        bytes32 freezeAuthorizationHash,
        uint16 schemaVersion
    );
    event ArtistPresentationLocked(
        uint256 indexed collectionId,
        bytes32 indexed snapshotHash,
        IStreamMetadataServingFacts.ArtistPresentation snapshot,
        uint16 schemaVersion
    );

    /// @notice Encode complete existing read results once, in the fixed original storage context.
    function read(
        Content.Layout memory layout,
        mapping(uint256 => IStreamMetadataServingFacts.ArtistPresentation) storage presentations,
        Content.Context memory context,
        bytes calldata input
    ) public view returns (bytes memory) {
        bytes4 selector = bytes4(input[:4]);
        uint256 collectionId = abi.decode(input[4:], (uint256));
        if (selector == StreamMetadataRouter.collectionMetadata.selector) {
            return abi.encode(_collections(layout)[collectionId]);
        }
        if (selector == IStreamMetadataServingFacts.artistPresentation.selector) {
            return abi.encode(presentations[collectionId]);
        }
        if (selector == IStreamMetadataServingFacts.collectionServingFacts.selector) {
            return abi.encode(_completeFacts(layout, presentations, context, collectionId));
        }
        if (selector == IStreamMetadataServingFacts.collectionServingSource.selector) {
            IStreamMetadataServingFacts.ServingSource memory result =
                source(_collections(layout), IStreamCore(context.core), collectionId);
            if (_scriptBundle(layout, collectionId).bundleId != 0) result.script = "";
            return abi.encode(result);
        }
        if (selector == IStreamMetadataServingFacts.collectionLiveArtistStatus.selector) {
            if (!IStreamCore(context.core).collectionExists(collectionId)) {
                revert InvalidCollection(collectionId);
            }
            return abi.encode(
                StreamMetadataArtistPresentation.live(context.core, context.artist, collectionId)
            );
        }
        if (selector == StreamMetadataRouter.collectionScriptBundle.selector) {
            return abi.encode(_scriptBundle(layout, collectionId));
        }
        revert UnsupportedRouterCollectionSelector(selector);
    }

    function _completeFacts(
        Content.Layout memory layout,
        mapping(uint256 => IStreamMetadataServingFacts.ArtistPresentation) storage presentations,
        Content.Context memory context,
        uint256 collectionId
    ) private view returns (IStreamMetadataServingFacts.ServingFacts memory result) {
        result = facts(
            _collections(layout),
            _locks(layout),
            presentations,
            _displayLocks(layout),
            IStreamCore(context.core),
            collectionId,
            address(TokenRenderer)
        );
        Bundles.Selection memory selected = _scriptBundle(layout, collectionId);
        if (selected.bundleId != 0) {
            Bundles.Facts memory f = Bundle.facts(selected);
            result.presentationProfile = Bundle.PROFILE;
            result.mode = keccak256("ONCHAIN");
            result.scriptHash = f.payloadHash;
            result.scriptBytes = f.totalBytes;
            result.renderer = address(Bundle);
            result.rendererCodeHash = result.renderer.codehash;
            result.dependenciesLocked = result.scriptLocked;
        }
        if (ConfigState.activated(collectionId)) {
            Config.ConfigRecord memory selectedConfig = ConfigState.resolved(collectionId, 0);
            // Preserve the distinct profile that makes older finality providers refuse this route.
            result.presentationProfile = keccak256("6529STREAM_STATIC_METADATA_SELECTION_V1");
            result.renderer = selectedConfig.selection.renderer;
            result.rendererCodeHash = selectedConfig.selection.rendererCodeHash;
            result.mode = selectedConfig.config.mode == Render.MetadataMode.ONCHAIN
                ? keccak256("ONCHAIN")
                : selectedConfig.config.mode == Render.MetadataMode.OFFCHAIN
                    ? keccak256("OFFCHAIN")
                    : keccak256("HYBRID");
            result.dependenciesLocked =
                selectedConfig.config.frozen || _locks(layout)[collectionId][ConfigState.FAMILY];
        }
    }

    function _collections(Content.Layout memory layout)
        private
        pure
        returns (mapping(uint256 => StreamMetadataRouter.CollectionMetadata) storage value)
    {
        uint256 slot = layout._collections;
        assembly ("memory-safe") { value.slot := slot }
    }

    function _locks(Content.Layout memory layout)
        private
        pure
        returns (mapping(uint256 => mapping(bytes32 => bool)) storage value)
    {
        uint256 slot = layout._artistContentLocks;
        assembly ("memory-safe") { value.slot := slot }
    }

    function _displayLocks(Content.Layout memory layout)
        private
        pure
        returns (mapping(uint256 => bool) storage value)
    {
        uint256 slot = layout._displayMetadataLocked;
        assembly ("memory-safe") { value.slot := slot }
    }

    function _scriptBundle(Content.Layout memory layout, uint256 collectionId)
        private
        view
        returns (Bundles.Selection memory)
    {
        uint256 slot = layout._selectedManifests;
        mapping(uint256 => mapping(uint8 => Manifests.Selection)) storage selections;
        assembly ("memory-safe") { selections.slot := slot }
        return Bundle.selection(selections[collectionId][2]);
    }

    /// @dev Fixed Router performs its existing authority/collection guards before delegating.
    function lockArtistIdentity(
        mapping(
            uint256 => IStreamMetadataServingFacts.ArtistPresentation
        ) storage _artistPresentation,
        mapping(
            uint256 => StreamMetadataRecoveryRoutes.OriginalAnchor
        ) storage anchors,
        StreamMetadataRecoveryRoutes.Environment memory e,
        uint256 collectionId
    ) public returns (bytes32) {
        bytes32 LOCK_ARTIST_IDENTITY = keccak256("ARTIST_IDENTITY");
        if (_artistPresentation[collectionId].locked) {
            revert PresentationAlreadyLocked(collectionId, LOCK_ARTIST_IDENTITY);
        }
        if (anchors[collectionId].registry != address(0) || anchors[collectionId].codeHash != 0) {
            revert StreamMetadataRecoveryRoutes.MetadataRecoveryBindingInvalid(anchors[collectionId].registry);
        }
        IStreamMetadataServingFacts.ArtistPresentation memory snapshot =
            StreamMetadataArtistPresentation.snapshot(e.core, e.artist, collectionId);
        StreamMetadataRecoveryRoutes.OriginalAnchor memory anchor =
            StreamMetadataRecoveryRoutes.captureOriginal(e);
        anchors[collectionId] = anchor;
        _artistPresentation[collectionId] = snapshot;
        emit CollectionMetadataLocked(collectionId, LOCK_ARTIST_IDENTITY, msg.sender, 0, 0, 1);
        emit ArtistPresentationLocked(collectionId, snapshot.snapshotHash, snapshot, 1);
        return snapshot.snapshotHash;
    }

    function facts(
        mapping(uint256 => StreamMetadataRouter.CollectionMetadata) storage _collections,
        mapping(
            uint256 => mapping(bytes32 => bool)
        ) storage _artistContentLocks,
        mapping(
            uint256 => IStreamMetadataServingFacts.ArtistPresentation
        ) storage _artistPresentation,
        mapping(uint256 => bool) storage _displayMetadataLocked,
        IStreamCore core,
        uint256 collectionId,
        address renderer_
    ) public view returns (IStreamMetadataServingFacts.ServingFacts memory result) {
        if (!core.collectionExists(collectionId)) revert InvalidCollection(collectionId);
        StreamMetadataRouter.CollectionMetadata storage metadata = _collections[collectionId];
        result.presentationProfile = PRESENTATION_PROFILE;
        result.configured = metadata.configured;
        uint256 length = bytes(metadata.animationScript).length;
        result.mode = length == 0 ? keccak256("OFFCHAIN") : keccak256("ONCHAIN");
        result.renderer = renderer_;
        result.rendererCodeHash = result.renderer.codehash;
        result.scriptHash = keccak256(bytes(metadata.animationScript));
        result.scriptBytes = uint32(length); // Writes enforce the 8192-byte bound.
        result.imageURIHash = keccak256(bytes(metadata.image));
        result.animationBaseURIHash = keccak256(bytes(metadata.animationBaseURI));
        result.scriptLocked = _artistContentLocks[collectionId][CONTENT_SCRIPT];
        result.mediaLocked = _artistContentLocks[collectionId][CONTENT_MEDIA];
        result.baseURILocked = _artistContentLocks[collectionId][LOCK_BASE_URI];
        result.dependenciesLocked = true; // No mutable renderer/library assignment exists.
        result.artistIdentityLocked = _artistPresentation[collectionId].locked;
        result.displayMetadataLocked = _displayMetadataLocked[collectionId];
        result.coreFrozen = core.collectionFreezeStatus(collectionId);
    }

    function source(
        mapping(uint256 => StreamMetadataRouter.CollectionMetadata) storage _collections,
        IStreamCore core,
        uint256 collectionId
    ) public view returns (IStreamMetadataServingFacts.ServingSource memory) {
        if (!core.collectionExists(collectionId)) revert InvalidCollection(collectionId);
        StreamMetadataRouter.CollectionMetadata storage metadata = _collections[collectionId];
        return IStreamMetadataServingFacts.ServingSource(
            metadata.name,
            metadata.description,
            metadata.image,
            metadata.animationBaseURI,
            metadata.animationScript
        );
    }
}
