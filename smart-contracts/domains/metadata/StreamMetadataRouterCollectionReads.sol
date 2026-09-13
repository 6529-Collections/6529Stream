// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamMetadataRouter.sol";
import "./StreamMetadataArtistPresentation.sol";
import "./StreamMetadataRecoveryRoutes.sol";
import "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import "../../interfaces/stream/core/IStreamCore.sol";

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
