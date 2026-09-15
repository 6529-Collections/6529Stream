// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamMetadataRouter } from "./StreamMetadataRouter.sol";
import { StreamMetadataContentRoot } from "./StreamMetadataContentRoot.sol";
import { StreamMetadataContentAuthorization } from "./StreamMetadataContentAuthorization.sol";
import { StreamMetadataImageURI } from "./StreamMetadataImageURI.sol";
import { StreamMetadataRenderer } from "./StreamMetadataRenderer.sol";
import { StreamMetadataTokenRenderer } from "./StreamMetadataTokenRenderer.sol";
import { IStreamCore } from "../../interfaces/stream/core/IStreamCore.sol";
import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamMetadataServingFacts
} from "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    IStreamCollectionMetadataV1
} from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamCollectionManifestWriter
} from "../../interfaces/stream/metadata/IStreamCollectionManifestWriter.sol";
import {
    StreamCollectionManifestTypes as M
} from "../../interfaces/stream/metadata/StreamCollectionManifestTypes.sol";

/// @dev Typed selector declarations only; the Router retains these exact public signatures.
interface IStreamMetadataRouterContentSelectors {
    function setCollectionMetadata(
        uint256 collectionId,
        string calldata name,
        string calldata description,
        string calldata image,
        string calldata animationBaseURI
    ) external;
    function setCollectionScript(uint256 collectionId, string calldata script) external;
    function setCollectionScriptManifest(uint256 collectionId, M.ScriptManifest calldata value)
        external;
    function setCollectionMediaManifest(uint256 collectionId, M.MediaManifest calldata value)
        external;
    function previewArtistScriptManifestState(uint256 collectionId, M.ScriptManifest calldata value)
        external
        view
        returns (bytes32);
    function previewArtistMediaManifestState(uint256 collectionId, M.MediaManifest calldata value)
        external
        view
        returns (bytes32);
    function selectedCollectionManifest(uint256 collectionId, uint8 kind)
        external
        view
        returns (M.Selection memory);
    function previewArtistScriptState(uint256 collectionId, string calldata script)
        external
        view
        returns (bytes32);
    function previewArtistMediaState(
        uint256 collectionId,
        string calldata image,
        string calldata animationBaseURI
    ) external view returns (bytes32);
    function artistContentFamilyState(uint256 collectionId, bytes32 familyId)
        external
        view
        returns (bool supported, bytes32 currentStateHash);
    function artistContentFreezeState(uint256 collectionId) external view returns (bytes32);
}

/// @notice Fixed Router content worker. Delegate execution preserves the original caller and host.
/// @dev Every storage root is supplied only by the Router using compiler-derived slots; no new storage.
library StreamMetadataRouterContent {
    struct Layout {
        uint256 _collections;
        uint256 _prepared;
        uint256 _artistContentLocks;
        uint256 _evolutionRatification;
        uint256 _evolutionContent;
        uint256 consumedArtistContentConsent;
        uint256 _displayMetadataLocked;
        uint256 _contentRoots;
        uint256 _selectedManifests;
    }

    struct Context {
        address core;
        address artist;
        address authority;
    }
    bytes32 private constant CONTENT_SCRIPT = keccak256("SCRIPT");
    bytes32 private constant CONTENT_MEDIA = keccak256("MEDIA_MANIFEST");
    bytes32 private constant CONTENT_ROOT = keccak256("CONTENT_ROOT");
    bytes32 private constant LOCK_BASE_URI = keccak256("BASE_URI");
    bytes32 private constant LOCK_DISPLAY_METADATA = keccak256("DISPLAY_METADATA");
    event CollectionManifestSelected(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint8 indexed kind,
        bytes32 indexed manifestHash,
        address host,
        bytes32 hostCodeHash
    );
    error Unauthorized(address caller);
    error InvalidCollection(uint256 collectionId);
    error CollectionFrozen(uint256 collectionId);
    error ArtistRegistryBindingChanged(address selected);
    error ArtistContentLocked(uint256 collectionId, bytes32 lockClass);
    event CollectionMetadataConfigured(uint256 indexed collectionId, bytes32 metadataHash);
    event CollectionScriptConfigured(uint256 indexed collectionId, bytes32 scriptHash);
    error UnsupportedRouterContentSelector(bytes4 selector);

    function _collections(Layout memory l)
        private
        pure
        returns (mapping(uint256 => StreamMetadataRouter.CollectionMetadata) storage value)
    {
        uint256 slot = l._collections;
        assembly ("memory-safe") { value.slot := slot }
    }

    function _prepared(Layout memory l)
        private
        pure
        returns (mapping(uint256 => StreamMetadataRouter.PreparedMetadata) storage value)
    {
        uint256 slot = l._prepared;
        assembly ("memory-safe") { value.slot := slot }
    }

    function _artistContentLocks(Layout memory l)
        private
        pure
        returns (mapping(uint256 => mapping(bytes32 => bool)) storage value)
    {
        uint256 slot = l._artistContentLocks;
        assembly ("memory-safe") { value.slot := slot }
    }

    function _evolutionRatification(Layout memory l)
        private
        pure
        returns (mapping(uint256 => bytes32) storage value)
    {
        uint256 slot = l._evolutionRatification;
        assembly ("memory-safe") { value.slot := slot }
    }

    function _evolutionContent(Layout memory l)
        private
        pure
        returns (mapping(uint256 => bytes32) storage value)
    {
        uint256 slot = l._evolutionContent;
        assembly ("memory-safe") { value.slot := slot }
    }

    function consumedArtistContentConsent(Layout memory l)
        private
        pure
        returns (mapping(bytes32 => bool) storage value)
    {
        uint256 slot = l.consumedArtistContentConsent;
        assembly ("memory-safe") { value.slot := slot }
    }

    function _displayMetadataLocked(Layout memory l)
        private
        pure
        returns (mapping(uint256 => bool) storage value)
    {
        uint256 slot = l._displayMetadataLocked;
        assembly ("memory-safe") { value.slot := slot }
    }

    function _contentRoots(Layout memory l)
        private
        pure
        returns (StreamMetadataContentRoot.State storage value)
    {
        uint256 slot = l._contentRoots;
        assembly ("memory-safe") { value.slot := slot }
    }

    function _selectedManifests(Layout memory l)
        private
        pure
        returns (mapping(uint256 => mapping(uint8 => M.Selection)) storage value)
    {
        uint256 slot = l._selectedManifests;
        assembly ("memory-safe") { value.slot := slot }
    }

    function write(Layout memory l, Context memory e, bytes calldata input) public {
        bytes4 selector = bytes4(input[:4]);
        if (selector == IStreamMetadataRouterContentSelectors.setCollectionMetadata.selector) {
            (
                uint256 collectionId,
                string memory name,
                string memory description,
                string memory image,
                string memory animationBaseURI
            ) = abi.decode(input[4:], (uint256, string, string, string, string));
            _setCollectionMetadata(l, e, collectionId, name, description, image, animationBaseURI);
            return;
        }
        if (selector == IStreamMetadataRouterContentSelectors.setCollectionScript.selector) {
            (uint256 collectionId, string memory script) = abi.decode(input[4:], (uint256, string));
            _setCollectionScript(l, e, collectionId, script);
            return;
        }
        if (selector == IStreamMetadataRouterContentSelectors.setCollectionScriptManifest.selector)
        {
            (uint256 collectionId, M.ScriptManifest memory value) =
                abi.decode(input[4:], (uint256, M.ScriptManifest));
            _setCollectionScriptManifest(l, e, collectionId, value);
            return;
        }
        if (selector == IStreamMetadataRouterContentSelectors.setCollectionMediaManifest.selector) {
            (uint256 collectionId, M.MediaManifest memory value) =
                abi.decode(input[4:], (uint256, M.MediaManifest));
            _setCollectionMediaManifest(l, e, collectionId, value);
            return;
        }
        revert UnsupportedRouterContentSelector(selector);
    }

    function read(Layout memory l, Context memory e, bytes calldata input)
        public
        view
        returns (bytes memory)
    {
        bytes4 selector = bytes4(input[:4]);
        if (
            selector
                == IStreamMetadataRouterContentSelectors.previewArtistScriptManifestState.selector
        ) {
            (uint256 collectionId, M.ScriptManifest memory value) =
                abi.decode(input[4:], (uint256, M.ScriptManifest));
            return abi.encode(_previewArtistScriptManifestState(l, e, collectionId, value));
        }
        if (
            selector
                == IStreamMetadataRouterContentSelectors.previewArtistMediaManifestState.selector
        ) {
            (uint256 collectionId, M.MediaManifest memory value) =
                abi.decode(input[4:], (uint256, M.MediaManifest));
            return abi.encode(_previewArtistMediaManifestState(l, e, collectionId, value));
        }
        if (selector == IStreamMetadataRouterContentSelectors.selectedCollectionManifest.selector) {
            (uint256 collectionId, uint8 kind) = abi.decode(input[4:], (uint256, uint8));
            return abi.encode(_selectedCollectionManifest(l, e, collectionId, kind));
        }
        if (selector == IStreamMetadataRouterContentSelectors.previewArtistScriptState.selector) {
            (uint256 collectionId, string memory script) = abi.decode(input[4:], (uint256, string));
            return abi.encode(_previewArtistScriptState(l, e, collectionId, script));
        }
        if (selector == IStreamMetadataRouterContentSelectors.previewArtistMediaState.selector) {
            (uint256 collectionId, string memory image, string memory animationBaseURI) =
                abi.decode(input[4:], (uint256, string, string));
            return abi.encode(_previewArtistMediaState(l, e, collectionId, image, animationBaseURI));
        }
        if (selector == IStreamMetadataRouterContentSelectors.artistContentFamilyState.selector) {
            (uint256 collectionId, bytes32 familyId) = abi.decode(input[4:], (uint256, bytes32));
            (bool supported, bytes32 state) =
                _artistContentFamilyState(l, e, collectionId, familyId);
            return abi.encode(supported, state);
        }
        if (selector == IStreamMetadataRouterContentSelectors.artistContentFreezeState.selector) {
            (uint256 collectionId) = abi.decode(input[4:], (uint256));
            return abi.encode(_artistContentFreezeState(l, e, collectionId));
        }
        revert UnsupportedRouterContentSelector(selector);
    }

    function currentState(Layout memory l, Context memory e, uint256 collectionId)
        public
        view
        returns (bytes32)
    {
        return _contentState(l, e, collectionId);
    }

    function authorize(
        Layout memory l,
        Context memory e,
        uint256 collectionId,
        bytes32 familyId,
        bytes32 state
    ) public returns (bytes32, bytes32) {
        return _authorizeContentWrite(l, e, collectionId, familyId, state);
    }

    function recordApplication(
        Layout memory l,
        Context memory e,
        uint256 collectionId,
        bytes32 familyId,
        bytes32 consent,
        bytes32 ratification
    ) public {
        _recordContentApplication(l, e, collectionId, familyId, consent, ratification);
    }

    function _setCollectionMetadata(
        Layout memory l,
        Context memory e,
        uint256 collectionId,
        string memory name,
        string memory description,
        string memory image,
        string memory animationBaseURI
    ) private {
        _requireMutable(l, e, collectionId);
        if (
            _displayMetadataLocked(l)[collectionId]
                && (keccak256(bytes(name)) != keccak256(bytes(_collections(l)[collectionId].name))
                    || keccak256(bytes(description))
                        != keccak256(bytes(_collections(l)[collectionId].description)))
        ) revert ArtistContentLocked(collectionId, LOCK_DISPLAY_METADATA);
        StreamMetadataRenderer.requireValidUtf8Bytes("name", name, 256);
        StreamMetadataRenderer.requireValidUtf8Bytes("description", description, 2048);
        StreamMetadataImageURI.requireImageURI(image);
        StreamMetadataRenderer.requireValidUtf8ContentUri(
            "animationBaseURI", animationBaseURI, 2048, true
        );
        StreamMetadataRouter.ContentApplication memory application =
            _authorizeMediaWrite(l, e, collectionId, image, animationBaseURI);
        if (
            keccak256(bytes(_collections(l)[collectionId].image)) != keccak256(bytes(image))
                || keccak256(bytes(_collections(l)[collectionId].animationBaseURI))
                    != keccak256(bytes(animationBaseURI))
        ) {
            _clearManifest(l, e, collectionId, 3);
        }
        _prepareCollectionMetadata(l, e, collectionId, name, description, image, animationBaseURI);
        StreamMetadataRouter.CollectionMetadata storage metadata = _collections(l)[collectionId];
        metadata.name = name;
        metadata.description = description;
        metadata.image = image;
        metadata.animationBaseURI = animationBaseURI;
        metadata.configured = true;
        emit CollectionMetadataConfigured(
            collectionId, keccak256(abi.encode(name, description, image, animationBaseURI))
        );
        _recordContentApplication(
            l, e, collectionId, CONTENT_MEDIA, application.consent, application.ratification
        );
    }

    function _setCollectionScript(
        Layout memory l,
        Context memory e,
        uint256 collectionId,
        string memory script
    ) private {
        _requireMutable(l, e, collectionId);
        StreamMetadataRenderer.requireValidUtf8Bytes("animationScript", script, 8192);
        bytes32 consent;
        bytes32 ratification;
        if (
            keccak256(bytes(_collections(l)[collectionId].animationScript))
                != keccak256(bytes(script))
        ) {
            _requireContentUnlocked(l, e, collectionId, CONTENT_SCRIPT);
            (consent, ratification) = _authorizeContentWrite(
                l, e, collectionId, CONTENT_SCRIPT, _scriptState(l, e, collectionId, script)
            );
            _clearManifest(l, e, collectionId, 2);
        }
        _collections(l)[collectionId].animationScript = script;
        _prepared(l)[collectionId].animationScript =
            StreamMetadataTokenRenderer.prepareScript(script);
        emit CollectionScriptConfigured(collectionId, keccak256(bytes(script)));
        _recordContentApplication(l, e, collectionId, CONTENT_SCRIPT, consent, ratification);
    }

    function _setCollectionScriptManifest(
        Layout memory l,
        Context memory e,
        uint256 collectionId,
        M.ScriptManifest memory value
    ) private {
        _requireMutable(l, e, collectionId);
        _requireContentCollection(l, e, collectionId);
        _requireContentUnlocked(l, e, collectionId, CONTENT_SCRIPT);
        address host = _manifestHost(l, e);
        bytes32 hash =
            IStreamCollectionManifestWriter(host).previewScriptManifest(collectionId, value);
        M.Selection memory selection = M.Selection(host, host.codehash, hash);
        if (
            keccak256(abi.encode(selection))
                == keccak256(abi.encode(_selectedManifests(l)[collectionId][2]))
        ) return;
        (bytes32 consent, bytes32 ratification) = _authorizeContentWrite(
            l,
            e,
            collectionId,
            CONTENT_SCRIPT,
            _withManifest(
                _scriptState(l, e, collectionId, _collections(l)[collectionId].animationScript),
                selection
            )
        );
        if (
            IStreamCollectionManifestWriter(host).storeScriptManifest(collectionId, value) != hash
                || _manifestHost(l, e) != host
        ) {
            revert IStreamCollectionManifestWriter.InvalidCollectionManifest();
        }
        _selectedManifests(l)[collectionId][2] = selection;
        emit CollectionManifestSelected(1, collectionId, 2, hash, host, selection.codeHash);
        _recordContentApplication(l, e, collectionId, CONTENT_SCRIPT, consent, ratification);
    }

    function _setCollectionMediaManifest(
        Layout memory l,
        Context memory e,
        uint256 collectionId,
        M.MediaManifest memory value
    ) private {
        _requireMutable(l, e, collectionId);
        _requireContentCollection(l, e, collectionId);
        _requireContentUnlocked(l, e, collectionId, CONTENT_MEDIA);
        address host = _manifestHost(l, e);
        bytes32 hash =
            IStreamCollectionManifestWriter(host).previewMediaManifest(collectionId, value);
        M.Selection memory selection = M.Selection(host, host.codehash, hash);
        if (
            keccak256(abi.encode(selection))
                == keccak256(abi.encode(_selectedManifests(l)[collectionId][3]))
        ) return;
        (bytes32 consent, bytes32 ratification) = _authorizeContentWrite(
            l,
            e,
            collectionId,
            CONTENT_MEDIA,
            _withManifest(
                _mediaState(
                    l,
                    e,
                    collectionId,
                    _collections(l)[collectionId].image,
                    _collections(l)[collectionId].animationBaseURI
                ),
                selection
            )
        );
        if (
            IStreamCollectionManifestWriter(host).storeMediaManifest(collectionId, value) != hash
                || _manifestHost(l, e) != host
        ) {
            revert IStreamCollectionManifestWriter.InvalidCollectionManifest();
        }
        _selectedManifests(l)[collectionId][3] = selection;
        emit CollectionManifestSelected(1, collectionId, 3, hash, host, selection.codeHash);
        _recordContentApplication(l, e, collectionId, CONTENT_MEDIA, consent, ratification);
    }

    function _previewArtistScriptManifestState(
        Layout memory l,
        Context memory e,
        uint256 collectionId,
        M.ScriptManifest memory value
    ) private view returns (bytes32) {
        _requireContentCollection(l, e, collectionId);
        address host = _manifestHost(l, e);
        bytes32 hash =
            IStreamCollectionManifestWriter(host).previewScriptManifest(collectionId, value);
        return _withManifest(
            _scriptState(l, e, collectionId, _collections(l)[collectionId].animationScript),
            M.Selection(host, host.codehash, hash)
        );
    }

    function _previewArtistMediaManifestState(
        Layout memory l,
        Context memory e,
        uint256 collectionId,
        M.MediaManifest memory value
    ) private view returns (bytes32) {
        _requireContentCollection(l, e, collectionId);
        address host = _manifestHost(l, e);
        bytes32 hash =
            IStreamCollectionManifestWriter(host).previewMediaManifest(collectionId, value);
        return _withManifest(
            _mediaState(
                l,
                e,
                collectionId,
                _collections(l)[collectionId].image,
                _collections(l)[collectionId].animationBaseURI
            ),
            M.Selection(host, host.codehash, hash)
        );
    }

    function _selectedCollectionManifest(
        Layout memory l,
        Context memory e,
        uint256 collectionId,
        uint8 kind
    ) private view returns (M.Selection memory) {
        if (kind != 2 && kind != 3) {
            revert IStreamCollectionManifestWriter.UnsupportedCollectionManifest();
        }
        M.Selection memory selected = _selectedManifests(l)[collectionId][kind];
        if (
            selected.manifestHash != 0
                && (_manifestHost(l, e) != selected.host
                    || selected.host.codehash != selected.codeHash)
        ) {
            revert IStreamCollectionManifestWriter.InvalidCollectionManifest();
        }
        return selected;
    }

    function _previewArtistScriptState(
        Layout memory l,
        Context memory e,
        uint256 collectionId,
        string memory script
    ) private view returns (bytes32) {
        _requireContentCollection(l, e, collectionId);
        bytes32 result = _scriptState(l, e, collectionId, script);
        if (
            keccak256(bytes(script))
                == keccak256(bytes(_collections(l)[collectionId].animationScript))
        ) {
            return _withManifest(result, _selectedManifests(l)[collectionId][2]);
        }
        return result;
    }

    function _previewArtistMediaState(
        Layout memory l,
        Context memory e,
        uint256 collectionId,
        string memory image,
        string memory animationBaseURI
    ) private view returns (bytes32) {
        _requireContentCollection(l, e, collectionId);
        bytes32 result = _mediaState(l, e, collectionId, image, animationBaseURI);
        if (
            keccak256(bytes(image)) == keccak256(bytes(_collections(l)[collectionId].image))
                && keccak256(bytes(animationBaseURI))
                    == keccak256(bytes(_collections(l)[collectionId].animationBaseURI))
        ) {
            return _withManifest(result, _selectedManifests(l)[collectionId][3]);
        }
        return result;
    }

    function _artistContentFamilyState(
        Layout memory l,
        Context memory e,
        uint256 collectionId,
        bytes32 familyId
    ) private view returns (bool supported, bytes32 currentStateHash) {
        _requireContentCollection(l, e, collectionId);
        if (familyId == CONTENT_ROOT) {
            return
                (
                    true,
                    StreamMetadataContentRoot.familyState(_contentRoots(l), e.core, collectionId)
                );
        }
        StreamMetadataRouter.CollectionMetadata storage metadata = _collections(l)[collectionId];
        if (familyId == CONTENT_SCRIPT) {
            return (
                true,
                _withManifest(
                    _scriptState(l, e, collectionId, metadata.animationScript),
                    _selectedManifests(l)[collectionId][2]
                )
            );
        }
        if (familyId == CONTENT_MEDIA) {
            return (
                true,
                _withManifest(
                    _mediaState(l, e, collectionId, metadata.image, metadata.animationBaseURI),
                    _selectedManifests(l)[collectionId][3]
                )
            );
        }
        return (false, bytes32(0));
    }

    function _artistContentFreezeState(Layout memory l, Context memory e, uint256 collectionId)
        private
        view
        returns (bytes32)
    {
        _requireContentCollection(l, e, collectionId);
        return _contentState(l, e, collectionId);
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

    function _clearManifest(Layout memory l, Context memory e, uint256 collectionId, uint8 kind)
        private
    {
        if (_selectedManifests(l)[collectionId][kind].manifestHash == 0) return;
        delete _selectedManifests(l)[collectionId][kind];
        emit CollectionManifestSelected(1, collectionId, kind, 0, address(0), 0);
    }

    function _manifestHost(Layout memory l, Context memory e) private view returns (address host) {
        bytes32 hash;
        uint8 status;
        uint64 revision;
        (
            address selectedRouter,
            bytes32 routerHash,,,,,
            uint8 routerStatus,,,
            uint64 routerRevision
        ) = IStreamCorePointers(e.core).getSatellitePointer(keccak256("METADATA_ROUTER"));
        if (
            selectedRouter != address(this) || routerHash != address(this).codehash
                || routerStatus != 1 || routerRevision == 0
        ) {
            revert IStreamCollectionManifestWriter.InvalidCollectionManifest();
        }
        (host, hash,,,,, status,,, revision) =
            IStreamCorePointers(e.core).getSatellitePointer(keccak256("COLLECTION_METADATA"));
        if (
            host.code.length == 0 || host.codehash != hash || status != 1 || revision == 0
                || IStreamCollectionMetadataV1(host).core() != e.core
        ) revert IStreamCollectionManifestWriter.InvalidCollectionManifest();
    }

    function _contentHostContext(Layout memory l, Context memory e, uint256 collectionId)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                block.chainid,
                e.core,
                collectionId,
                address(this),
                address(this).codehash,
                address(StreamMetadataRenderer),
                address(StreamMetadataRenderer).codehash
            )
        );
    }

    function _contentState(Layout memory l, Context memory e, uint256 collectionId)
        private
        view
        returns (bytes32)
    {
        StreamMetadataRouter.CollectionMetadata storage metadata = _collections(l)[collectionId];
        bytes32 serving = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROUTER_ONCHAIN_CONTENT_V1"),
                _contentHostContext(l, e, collectionId),
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
        if (script.manifestHash == 0 && media.manifestHash == 0) return serving;
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ROUTER_CONTENT_WITH_MANIFESTS_V1"), serving, script, media
            )
        );
    }

    function _scriptState(
        Layout memory l,
        Context memory e,
        uint256 collectionId,
        string memory script
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ROUTER_CONTENT_FAMILY_V1"),
                _contentHostContext(l, e, collectionId),
                CONTENT_SCRIPT,
                keccak256(bytes(script))
            )
        );
    }

    function _mediaState(
        Layout memory l,
        Context memory e,
        uint256 collectionId,
        string memory image,
        string memory baseURI
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ROUTER_CONTENT_FAMILY_V1"),
                _contentHostContext(l, e, collectionId),
                CONTENT_MEDIA,
                keccak256(bytes(image)),
                keccak256(bytes(baseURI))
            )
        );
    }

    function _requireContentUnlocked(
        Layout memory l,
        Context memory e,
        uint256 collectionId,
        bytes32 lockClass
    ) private view {
        if (_artistContentLocks(l)[collectionId][lockClass]) {
            revert ArtistContentLocked(collectionId, lockClass);
        }
    }

    function _authorizeMediaWrite(
        Layout memory l,
        Context memory e,
        uint256 collectionId,
        string memory image,
        string memory baseURI
    ) private returns (StreamMetadataRouter.ContentApplication memory application) {
        StreamMetadataRouter.CollectionMetadata storage metadata = _collections(l)[collectionId];
        bool uriChanged = keccak256(bytes(metadata.animationBaseURI)) != keccak256(bytes(baseURI));
        if (keccak256(bytes(metadata.image)) != keccak256(bytes(image)) || uriChanged) {
            _requireContentUnlocked(l, e, collectionId, CONTENT_MEDIA);
            if (uriChanged) _requireContentUnlocked(l, e, collectionId, LOCK_BASE_URI);
            (application.consent, application.ratification) = _authorizeContentWrite(
                l, e, collectionId, CONTENT_MEDIA, _mediaState(l, e, collectionId, image, baseURI)
            );
        }
    }

    function _authorizeContentWrite(
        Layout memory l,
        Context memory e,
        uint256 collectionId,
        bytes32 familyId,
        bytes32 newStateHash
    ) private returns (bytes32 consent, bytes32 ratification) {
        _requireSelectedArtistRegistry(l, e);
        return StreamMetadataContentAuthorization.authorize(
            consumedArtistContentConsent(l),
            _evolutionRatification(l),
            _evolutionContent(l),
            StreamMetadataContentAuthorization.Context(
                e.core, e.artist, collectionId, _contentState(l, e, collectionId)
            ),
            familyId,
            newStateHash
        );
    }

    function _recordContentApplication(
        Layout memory l,
        Context memory e,
        uint256 collectionId,
        bytes32 familyId,
        bytes32 consent,
        bytes32 ratification
    ) private {
        if (consent == bytes32(0)) return;
        StreamMetadataContentAuthorization.recordApplication(
            _evolutionRatification(l),
            _evolutionContent(l),
            collectionId,
            familyId,
            consent,
            ratification,
            _contentState(l, e, collectionId)
        );
    }

    function _requireSelectedArtistRegistry(Layout memory l, Context memory e) private view {
        (address selected, bytes32 codeHash,,,,,,,,) =
            IStreamCorePointers(e.core).getSatellitePointer(keccak256("ARTIST_REGISTRY"));
        if (selected != e.artist || selected.code.length == 0 || codeHash != selected.codehash) {
            revert ArtistRegistryBindingChanged(selected);
        }
    }

    function _requireContentCollection(Layout memory l, Context memory e, uint256 collectionId)
        private
        view
    {
        if (!IStreamCore(e.core).collectionExists(collectionId)) {
            revert InvalidCollection(collectionId);
        }
        _requireSelectedArtistRegistry(l, e);
    }

    function _requireMutable(Layout memory l, Context memory e, uint256 collectionId) private view {
        if (msg.sender != e.authority) revert Unauthorized(msg.sender);
        if (!IStreamCore(e.core).collectionExists(collectionId)) {
            revert InvalidCollection(collectionId);
        }
        if (IStreamCore(e.core).collectionFreezeStatus(collectionId)) {
            revert CollectionFrozen(collectionId);
        }
    }

    function _prepareCollectionMetadata(
        Layout memory l,
        Context memory e,
        uint256 collectionId,
        string memory name,
        string memory description,
        string memory image,
        string memory animationBaseURI
    ) private {
        IStreamMetadataServingFacts.ServingSource memory escaped =
            StreamMetadataTokenRenderer.prepareMetadata(name, description, image, animationBaseURI);
        StreamMetadataRouter.PreparedMetadata storage prepared = _prepared(l)[collectionId];
        prepared.name = escaped.name;
        prepared.description = escaped.description;
        prepared.image = escaped.imageURI;
        prepared.animationBaseURI = escaped.animationBaseURI;
    }
}
