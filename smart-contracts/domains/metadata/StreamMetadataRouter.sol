// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/metadata/IStreamMetadataRouter.sol";
import "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import "../../interfaces/stream/entropy/IStreamEntropyView.sol";
import "../../interfaces/stream/artist/IStreamCollectionArtistRegistry.sol";
import "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../interfaces/stream/artist/IStreamArtistContentFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistContentRatification.sol";
import "../../interfaces/stream/artist/IStreamArtistContentMutationFacts.sol";
import {
    IStreamArtistContentAuthority
} from "../../interfaces/stream/artist/IStreamArtistContentAuthority.sol";
import {
    StreamArtistContentTypes
} from "../../interfaces/stream/artist/StreamArtistContentTypes.sol";
import "../modules/StreamModuleBase.sol";
import "./StreamMetadataRenderer.sol";
import "./StreamMetadataArtistPresentation.sol";
import "./StreamMetadataTokenRenderer.sol";
import "./StreamMetadataTokenReads.sol";
import "./StreamMetadataImageURI.sol";
import "./StreamMetadataContentRoot.sol";
import "./StreamMetadataContentLocks.sol";
import "./StreamMetadataContentAuthorization.sol";
import "./StreamMetadataFinalityServing.sol";
import "./StreamMetadataRouterCollectionReads.sol";
import "./StreamMetadataScopeMembership.sol";
import { StreamMetadataDisplayParameters } from "./StreamMetadataDisplayParameters.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { StreamArtistDisplayReads } from "./StreamArtistDisplayReads.sol";
import { StreamArtistDisplayJSON } from "./StreamArtistDisplayJSON.sol";
import {
    StreamArtistDisplayTypes
} from "../../interfaces/stream/metadata/StreamArtistDisplayTypes.sol";
import "../../interfaces/stream/metadata/IStreamMetadataScopeMembership.sol";
import "../../interfaces/stream/metadata/IStreamMetadataRenderingProfile.sol";
import {
    IStreamCollectionManifestWriter,
    IStreamMetadataManifestSelection
} from "../../interfaces/stream/metadata/IStreamCollectionManifestWriter.sol";
import {
    StreamCollectionManifestTypes as M
} from "../../interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import {
    IStreamContentRootPublication
} from "../../interfaces/stream/metadata/IStreamContentRootPublication.sol";

/// @notice Serves current-Core identities and their original coordinator's canonical entropy.
contract StreamMetadataRouter is
    StreamModuleBase,
    IStreamMetadataRouter,
    IStreamArtistContentFacts,
    IStreamArtistContentMutationFacts,
    IStreamMetadataServingFacts,
    IStreamContentRootPublication,
    IStreamMetadataScopeMembership
{
    struct CollectionMetadata {
        string name;
        string description;
        string image;
        string animationBaseURI;
        string animationScript;
        bool configured;
    }

    struct PreparedMetadata {
        string name;
        string description;
        string image;
        string animationBaseURI;
        string animationScript;
    }

    struct ContentApplication {
        bytes32 consent;
        bytes32 ratification;
    }
    IStreamCore public immutable core;
    address public immutable authority;
    IStreamArtistAttribution public immutable artistRegistry;
    bytes32 private immutable _artistRegistryCodeHash;
    mapping(uint256 => CollectionMetadata) private _collections;
    mapping(uint256 => PreparedMetadata) private _prepared;
    string private _contractMetadataURI;
    mapping(uint256 => mapping(bytes32 => bool)) private _artistContentLocks;
    mapping(uint256 => bytes32) private _evolutionRatification;
    mapping(uint256 => bytes32) private _evolutionContent;
    mapping(bytes32 => bool) public consumedArtistContentConsent;
    mapping(uint256 => ArtistPresentation) private _artistPresentation;
    mapping(uint256 => bool) private _displayMetadataLocked;
    StreamMetadataContentRoot.State private _contentRoots;
    mapping(uint256 => StreamMetadataRecoveryRoutes.OriginalAnchor) public originalFinalityAnchor;

    StreamMetadataRecoveryRoutes.OriginalAnchor public servingOriginalFinalityAnchor;
    bool private _originalFinalityAnchorInitialized;
    mapping(uint256 => mapping(uint8 => M.Selection)) private _selectedManifests;
    event CollectionManifestSelected(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint8 indexed kind,
        bytes32 indexed manifestHash,
        address host,
        bytes32 hostCodeHash
    );
    error OriginalFinalityAnchorAlreadyInitialized();
    error OriginalFinalityAnchorUninitialized();
    event OriginalFinalityAnchorInitialized(
        uint16 schemaVersion, address indexed registry, bytes32 codeHash
    );

    /// @notice Admit the fixed facade's original finality after the cyclic graph is complete.
    function initializeOriginalFinalityAnchor() external {
        if (msg.sender != authority) revert Unauthorized(msg.sender);
        if (
            _originalFinalityAnchorInitialized
                || servingOriginalFinalityAnchor.registry != address(0)
                || servingOriginalFinalityAnchor.codeHash != 0
        ) {
            revert OriginalFinalityAnchorAlreadyInitialized();
        }
        StreamMetadataRecoveryRoutes.OriginalAnchor memory a =
            StreamMetadataRecoveryRoutes.captureOriginal(
                StreamMetadataRecoveryRoutes.Environment(
                    address(core), address(artistRegistry), _artistRegistryCodeHash
                )
            );
        servingOriginalFinalityAnchor = a;
        _originalFinalityAnchorInitialized = true;
        emit OriginalFinalityAnchorInitialized(1, a.registry, a.codeHash);
    }

    bytes32 public constant LIVE_ATTRIBUTION_PROFILE = StreamArtistDisplayTypes.PROFILE;

    function LIVE_ATTRIBUTION_GAS() external view returns (uint256) {
        return StreamMetadataDisplayParameters.value(StreamMetadataDisplayParameters.OUTER_GAS);
    }

    function governanceAuthority() external view returns (address) {
        return authority;
    }

    function gasParameter(bytes32 id) external view returns (uint256) {
        return StreamMetadataDisplayParameters.value(id);
    }

    function gasParameterInfo(bytes32 id) external view returns (uint256, uint256, uint8, uint64) {
        return StreamMetadataDisplayParameters.info(id);
    }

    function gasParameterIds() external pure returns (bytes32[] memory) {
        return StreamMetadataDisplayParameters.ids();
    }

    function gasParameterTransition(bytes32 id, uint256 next)
        external
        view
        returns (bytes32, bytes32, bytes32)
    {
        return StreamMetadataDisplayParameters.transition(id, next);
    }

    function raiseGasParameter(bytes32 id, uint256 next) external {
        StreamMetadataDisplayParameters.raise(authority, id, next);
    }
    uint256 public constant LIVE_ATTRIBUTION_MAX_BYTES = 32768;

    bytes32 public constant CONTENT_SCRIPT = keccak256("SCRIPT");
    bytes32 public constant CONTENT_MEDIA = keccak256("MEDIA_MANIFEST");
    bytes32 public constant CONTENT_ROOT = keccak256("CONTENT_ROOT");
    bytes32 public constant LOCK_BASE_URI = keccak256("BASE_URI");
    bytes32 public constant LOCK_DEPENDENCIES = keccak256("DEPENDENCIES");
    bytes32 public constant LOCK_ARTIST_IDENTITY = keccak256("ARTIST_IDENTITY");
    bytes32 public constant LOCK_DISPLAY_METADATA = keccak256("DISPLAY_METADATA");
    bytes32 public constant PRESENTATION_PROFILE =
        keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1");

    error Unauthorized(address caller);
    error InvalidCore(address supplied);
    error InvalidManifest();
    error InvalidCollection(uint256 collectionId);
    error CollectionFrozen(uint256 collectionId);
    error InvalidToken(uint256 tokenId);
    error MetadataJSONLimitExceeded(uint256 escapedBytes, uint256 maximumBytes);
    error ArtistContentAuthorizationRequired(uint256 collectionId);
    error UnconfiguredOnchainContent(uint256 collectionId);
    error ArtistRegistryBindingChanged(address selected);
    error ArtistContentLocked(uint256 collectionId, bytes32 lockClass);
    error InvalidArtistContentFreeze(bytes32 recordHash);
    error ArtistContentConsentConsumed(bytes32 recordHash);
    error ArtistContentEvolutionBroken(uint256 collectionId);
    error PresentationAlreadyLocked(uint256 collectionId, bytes32 lockId);
    error DisplayMetadataUnconfigured(uint256 collectionId);
    error TokenEntropyNotFinalized(uint256 tokenId);
    event CollectionMetadataConfigured(uint256 indexed collectionId, bytes32 metadataHash);
    event CollectionScriptConfigured(uint256 indexed collectionId, bytes32 scriptHash);
    event ContractMetadataConfigured(bytes32 uriHash);
    event ArtistContentConsentApplied(
        uint256 indexed collectionId,
        bytes32 indexed familyId,
        bytes32 indexed consentRecordHash,
        bytes32 resultingContentStateHash,
        uint16 schemaVersion
    );
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
        ArtistPresentation snapshot,
        uint16 schemaVersion
    );

    constructor(
        address core_,
        address authority_,
        bytes32 deploymentManifestHash,
        string memory manifestURI,
        bytes32 manifestHash,
        IStreamArtistAttribution artistRegistry_
    )
        StreamModuleBase(
            keccak256("6529stream.metadata-router.schema.v1"),
            address(0),
            deploymentManifestHash,
            manifestURI,
            manifestHash
        )
    {
        if (core_.code.length == 0 || !IERC165(core_).supportsInterface(0x80ac58cd)) revert InvalidCore(core_);
        if (authority_ == address(0) || deploymentManifestHash == 0 || manifestHash == 0) {
            revert InvalidManifest();
        }
        core = IStreamCore(core_);
        authority = authority_;
        StreamMetadataDisplayParameters.initialize(authority_);
        if (
            address(artistRegistry_).code.length == 0 || artistRegistry_.core() != core_
                || !IERC165(address(artistRegistry_))
                    .supportsInterface(type(IStreamArtistAttribution).interfaceId)
                || !IERC165(address(artistRegistry_))
                    .supportsInterface(type(IStreamArtistContentRatification).interfaceId)
                || IERC165(address(artistRegistry_)).supportsInterface(0xffffffff)
        ) revert InvalidManifest();
        artistRegistry = artistRegistry_;
        _artistRegistryCodeHash = address(artistRegistry_).codehash;
    }

    function streamModuleType() public pure override returns (bytes32) {
        return 0x7024d3e2544fc48a261933c43d901dca0ee3fc26ea2b857748ab0c295a16f20a;
    }

    function streamModuleVersion() public pure override returns (bytes32) {
        return keccak256("6529stream.metadata-router.v1");
    }

    function streamModuleInterfaceId() public pure override returns (bytes4) {
        return type(IStreamMetadataRouter).interfaceId;
    }

    function supportsInterface(bytes4 id)
        public
        view
        override(StreamModuleBase, IERC165)
        returns (bool)
    {
        return id == type(IStreamGasParameterHost).interfaceId
            || id == type(IStreamMetadataRouter).interfaceId
            || id == type(IStreamMetadataRenderingProfile).interfaceId
            || id == type(IStreamContentRootPublication).interfaceId
            || id == type(IStreamMetadataServingFacts).interfaceId
            || id == type(IStreamArtistContentFacts).interfaceId
            || id == type(IStreamArtistContentMutationFacts).interfaceId
            || id == type(IStreamMetadataScopeMembership).interfaceId || super.supportsInterface(id);
    }

    function scopeCoversToken(StreamFinalityScope calldata, uint256)
        external
        view
        override
        returns (bool)
    {
        _scopeMembership();
    }

    function scopeTokenAt(StreamFinalityScope calldata, uint256)
        external
        view
        override
        returns (uint256)
    {
        _scopeMembership();
    }

    function _scopeMembership() private view {
        uint256 result = StreamMetadataScopeMembership.read(
            _artistPresentation,
            originalFinalityAnchor,
            StreamMetadataRecoveryRoutes.Environment(
                address(core), address(artistRegistry), _artistRegistryCodeHash
            ),
            _servingAnchor(),
            msg.data
        );
        assembly ("memory-safe") {
            mstore(0, result)
            return(0, 32)
        }
    }

    function setCollectionMetadata(
        uint256 collectionId,
        string calldata name,
        string calldata description,
        string calldata image,
        string calldata animationBaseURI
    ) external {
        _requireMutable(collectionId);
        if (
            _displayMetadataLocked[collectionId]
                && (keccak256(bytes(name)) != keccak256(bytes(_collections[collectionId].name))
                    || keccak256(bytes(description))
                        != keccak256(bytes(_collections[collectionId].description)))
        ) revert ArtistContentLocked(collectionId, LOCK_DISPLAY_METADATA);
        StreamMetadataRenderer.requireValidUtf8Bytes("name", name, 256);
        StreamMetadataRenderer.requireValidUtf8Bytes("description", description, 2048);
        StreamMetadataImageURI.requireImageURI(image);
        StreamMetadataRenderer.requireValidUtf8ContentUri(
            "animationBaseURI", animationBaseURI, 2048, true
        );
        ContentApplication memory application =
            _authorizeMediaWrite(collectionId, image, animationBaseURI);
        if (
            keccak256(bytes(_collections[collectionId].image)) != keccak256(bytes(image))
                || keccak256(bytes(_collections[collectionId].animationBaseURI))
                    != keccak256(bytes(animationBaseURI))
        ) {
            _clearManifest(collectionId, 3);
        }
        _prepareCollectionMetadata(collectionId, name, description, image, animationBaseURI);
        CollectionMetadata storage metadata = _collections[collectionId];
        metadata.name = name;
        metadata.description = description;
        metadata.image = image;
        metadata.animationBaseURI = animationBaseURI;
        metadata.configured = true;
        emit CollectionMetadataConfigured(
            collectionId, keccak256(abi.encode(name, description, image, animationBaseURI))
        );
        _recordContentApplication(
            collectionId, CONTENT_MEDIA, application.consent, application.ratification
        );
    }

    /// @notice Optional onchain generative script. It receives tokenId, tokenHash and tokenDataBase64.
    /// @dev A stored script takes precedence over the external animation base URI after reveal.
    function setCollectionScript(uint256 collectionId, string calldata script) external {
        _requireMutable(collectionId);
        StreamMetadataRenderer.requireValidUtf8Bytes("animationScript", script, 8192);
        bytes32 consent;
        bytes32 ratification;
        if (
            keccak256(bytes(_collections[collectionId].animationScript)) != keccak256(bytes(script))
        ) {
            _requireContentUnlocked(collectionId, CONTENT_SCRIPT);
            (consent, ratification) = _authorizeContentWrite(
                collectionId, CONTENT_SCRIPT, _scriptState(collectionId, script)
            );
            _clearManifest(collectionId, 2);
        }
        _collections[collectionId].animationScript = script;
        _prepared[collectionId].animationScript = StreamMetadataTokenRenderer.prepareScript(script);
        emit CollectionScriptConfigured(collectionId, keccak256(bytes(script)));
        _recordContentApplication(collectionId, CONTENT_SCRIPT, consent, ratification);
    }

    /// @notice Select full typed facts about the actual current script after original content authority.
    function setCollectionScriptManifest(uint256 collectionId, M.ScriptManifest calldata value)
        external
    {
        _requireMutable(collectionId);
        _requireContentCollection(collectionId);
        _requireContentUnlocked(collectionId, CONTENT_SCRIPT);
        address host = _manifestHost();
        bytes32 hash =
            IStreamCollectionManifestWriter(host).previewScriptManifest(collectionId, value);
        M.Selection memory selection = M.Selection(host, host.codehash, hash);
        if (
            keccak256(abi.encode(selection))
                == keccak256(abi.encode(_selectedManifests[collectionId][2]))
        ) return;
        (bytes32 consent, bytes32 ratification) = _authorizeContentWrite(
            collectionId,
            CONTENT_SCRIPT,
            _withManifest(
                _scriptState(collectionId, _collections[collectionId].animationScript), selection
            )
        );
        if (
            IStreamCollectionManifestWriter(host).storeScriptManifest(collectionId, value) != hash
                || _manifestHost() != host
        ) {
            revert IStreamCollectionManifestWriter.InvalidCollectionManifest();
        }
        _selectedManifests[collectionId][2] = selection;
        emit CollectionManifestSelected(1, collectionId, 2, hash, host, selection.codeHash);
        _recordContentApplication(collectionId, CONTENT_SCRIPT, consent, ratification);
    }

    function setCollectionMediaManifest(uint256 collectionId, M.MediaManifest calldata value)
        external
    {
        _requireMutable(collectionId);
        _requireContentCollection(collectionId);
        _requireContentUnlocked(collectionId, CONTENT_MEDIA);
        address host = _manifestHost();
        bytes32 hash =
            IStreamCollectionManifestWriter(host).previewMediaManifest(collectionId, value);
        M.Selection memory selection = M.Selection(host, host.codehash, hash);
        if (
            keccak256(abi.encode(selection))
                == keccak256(abi.encode(_selectedManifests[collectionId][3]))
        ) return;
        (bytes32 consent, bytes32 ratification) = _authorizeContentWrite(
            collectionId,
            CONTENT_MEDIA,
            _withManifest(
                _mediaState(
                    collectionId,
                    _collections[collectionId].image,
                    _collections[collectionId].animationBaseURI
                ),
                selection
            )
        );
        if (
            IStreamCollectionManifestWriter(host).storeMediaManifest(collectionId, value) != hash
                || _manifestHost() != host
        ) {
            revert IStreamCollectionManifestWriter.InvalidCollectionManifest();
        }
        _selectedManifests[collectionId][3] = selection;
        emit CollectionManifestSelected(1, collectionId, 3, hash, host, selection.codeHash);
        _recordContentApplication(collectionId, CONTENT_MEDIA, consent, ratification);
    }

    function previewArtistScriptManifestState(uint256 collectionId, M.ScriptManifest calldata value)
        external
        view
        returns (bytes32)
    {
        _requireContentCollection(collectionId);
        address host = _manifestHost();
        bytes32 hash =
            IStreamCollectionManifestWriter(host).previewScriptManifest(collectionId, value);
        return _withManifest(
            _scriptState(collectionId, _collections[collectionId].animationScript),
            M.Selection(host, host.codehash, hash)
        );
    }

    function previewArtistMediaManifestState(uint256 collectionId, M.MediaManifest calldata value)
        external
        view
        returns (bytes32)
    {
        _requireContentCollection(collectionId);
        address host = _manifestHost();
        bytes32 hash =
            IStreamCollectionManifestWriter(host).previewMediaManifest(collectionId, value);
        return _withManifest(
            _mediaState(
                collectionId,
                _collections[collectionId].image,
                _collections[collectionId].animationBaseURI
            ),
            M.Selection(host, host.codehash, hash)
        );
    }

    function selectedCollectionManifest(uint256 collectionId, uint8 kind)
        external
        view
        returns (M.Selection memory)
    {
        if (kind != 2 && kind != 3) {
            revert IStreamCollectionManifestWriter.UnsupportedCollectionManifest();
        }
        M.Selection memory selected = _selectedManifests[collectionId][kind];
        if (
            selected.manifestHash != 0
                && (_manifestHost() != selected.host || selected.host.codehash != selected.codeHash)
        ) {
            revert IStreamCollectionManifestWriter.InvalidCollectionManifest();
        }
        return selected;
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

    function _clearManifest(uint256 collectionId, uint8 kind) private {
        if (_selectedManifests[collectionId][kind].manifestHash == 0) return;
        delete _selectedManifests[collectionId][kind];
        emit CollectionManifestSelected(1, collectionId, kind, 0, address(0), 0);
    }

    function _manifestHost() private view returns (address host) {
        bytes32 hash;
        uint8 status;
        uint64 revision;
        (
            address selectedRouter,
            bytes32 routerHash,,,,,
            uint8 routerStatus,,,
            uint64 routerRevision
        ) = IStreamCorePointers(address(core)).getSatellitePointer(keccak256("METADATA_ROUTER"));
        if (
            selectedRouter != address(this) || routerHash != address(this).codehash
                || routerStatus != 1 || routerRevision == 0
        ) {
            revert IStreamCollectionManifestWriter.InvalidCollectionManifest();
        }
        (host, hash,,,,, status,,, revision) = IStreamCorePointers(address(core))
            .getSatellitePointer(keccak256("COLLECTION_METADATA"));
        if (
            host.code.length == 0 || host.codehash != hash || status != 1 || revision == 0
                || IStreamCollectionMetadataV1(host).core() != address(core)
        ) revert IStreamCollectionManifestWriter.InvalidCollectionManifest();
    }

    function setContractMetadataURI(string calldata uri) external {
        if (msg.sender != authority) revert Unauthorized(msg.sender);
        StreamMetadataRenderer.requireValidUtf8ContentUri("contractURI", uri, 2048, false);
        _contractMetadataURI = uri;
        emit ContractMetadataConfigured(keccak256(bytes(uri)));
        // Configuration can precede Core installation; Core remains the ERC-7572 event source.
        try core.emitContractURIUpdated() { } catch { }
    }

    function collectionMetadata(uint256 collectionId)
        external
        view
        returns (CollectionMetadata memory)
    {
        return _collections[collectionId];
    }

    function lockArtistIdentity(uint256 collectionId) external override returns (bytes32) {
        _requirePresentationAuthority(collectionId);
        return StreamMetadataRouterCollectionReads.lockArtistIdentity(
            _artistPresentation,
            originalFinalityAnchor,
            StreamMetadataRecoveryRoutes.Environment(
                address(core), address(artistRegistry), _artistRegistryCodeHash
            ),
            collectionId
        );
    }

    function lockDisplayMetadata(uint256 collectionId) external override {
        _requirePresentationAuthority(collectionId);
        if (_displayMetadataLocked[collectionId]) {
            revert PresentationAlreadyLocked(collectionId, LOCK_DISPLAY_METADATA);
        }
        if (!_collections[collectionId].configured) {
            revert DisplayMetadataUnconfigured(collectionId);
        }
        _displayMetadataLocked[collectionId] = true;
        emit CollectionMetadataLocked(collectionId, LOCK_DISPLAY_METADATA, msg.sender, 0, 0, 1);
    }

    function _requirePresentationAuthority(uint256 collectionId) private view {
        if (msg.sender != authority) revert Unauthorized(msg.sender);
        if (!core.collectionExists(collectionId)) revert InvalidCollection(collectionId);
    }

    function artistPresentation(uint256 collectionId)
        external
        view
        override
        returns (ArtistPresentation memory)
    {
        return _artistPresentation[collectionId];
    }

    function collectionServingFacts(uint256 collectionId)
        external
        view
        override
        returns (ServingFacts memory result)
    {
        return StreamMetadataRouterCollectionReads.facts(
            _collections,
            _artistContentLocks,
            _artistPresentation,
            _displayMetadataLocked,
            core,
            collectionId,
            address(StreamMetadataTokenRenderer)
        );
    }

    function collectionServingSource(uint256 collectionId)
        external
        view
        override
        returns (ServingSource memory)
    {
        return StreamMetadataRouterCollectionReads.source(_collections, core, collectionId);
    }

    function collectionLiveArtistStatus(uint256 collectionId)
        external
        view
        override
        returns (LiveArtistStatus memory)
    {
        if (!core.collectionExists(collectionId)) revert InvalidCollection(collectionId);
        return StreamMetadataArtistPresentation.live(
            address(core), address(artistRegistry), collectionId
        );
    }

    /// @notice Exact current-router ONCHAIN content profile for first-release ratification.
    /// @dev Includes the actual linked renderer and content fields, not descriptive records.
    ///      Future content-freeze authorization must use this same versioned state commitment.
    function currentArtistContentState(uint256 collectionId)
        external
        view
        override
        returns (address metadataContract, bytes32 contentStateHash)
    {
        if (!core.collectionExists(collectionId)) revert InvalidCollection(collectionId);
        _requireSelectedArtistRegistry();
        CollectionMetadata storage metadata = _collections[collectionId];
        if (!metadata.configured || bytes(metadata.animationScript).length == 0) {
            revert UnconfiguredOnchainContent(collectionId);
        }
        return (address(this), _contentState(collectionId));
    }

    function artistContentFamilyState(uint256 collectionId, bytes32 familyId)
        external
        view
        override
        returns (bool supported, bytes32 currentStateHash)
    {
        _requireContentCollection(collectionId);
        if (familyId == CONTENT_ROOT) {
            return (
                true,
                StreamMetadataContentRoot.familyState(_contentRoots, address(core), collectionId)
            );
        }
        CollectionMetadata storage metadata = _collections[collectionId];
        if (familyId == CONTENT_SCRIPT) {
            return (
                true,
                _withManifest(
                    _scriptState(collectionId, metadata.animationScript),
                    _selectedManifests[collectionId][2]
                )
            );
        }
        if (familyId == CONTENT_MEDIA) {
            return (
                true,
                _withManifest(
                    _mediaState(collectionId, metadata.image, metadata.animationBaseURI),
                    _selectedManifests[collectionId][3]
                )
            );
        }
        return (false, bytes32(0));
    }

    function artistContentLockState(uint256 collectionId, bytes32 lockClass)
        external
        view
        override
        returns (bool supported, bool locked)
    {
        _requireContentCollection(collectionId);
        // This router has no dependency assignment mutation: its renderer is linked into code.
        if (lockClass == LOCK_DEPENDENCIES) return (true, true);
        supported =
            lockClass == CONTENT_SCRIPT || lockClass == CONTENT_MEDIA || lockClass == LOCK_BASE_URI;
        return (supported, supported && _artistContentLocks[collectionId][lockClass]);
    }

    function artistContentFreezeState(uint256 collectionId)
        external
        view
        override
        returns (bytes32)
    {
        _requireContentCollection(collectionId);
        return _contentState(collectionId);
    }

    function artistContentEvolution(uint256 collectionId)
        external
        view
        override
        returns (bytes32, bytes32)
    {
        _requireContentCollection(collectionId);
        return (_evolutionRatification[collectionId], _evolutionContent[collectionId]);
    }

    /// @notice Exact resulting SCRIPT family commitment for artist consent tooling.
    function previewArtistScriptState(uint256 collectionId, string calldata script)
        external
        view
        returns (bytes32)
    {
        _requireContentCollection(collectionId);
        bytes32 result = _scriptState(collectionId, script);
        if (
            keccak256(bytes(script)) == keccak256(bytes(_collections[collectionId].animationScript))
        ) {
            return _withManifest(result, _selectedManifests[collectionId][2]);
        }
        return result;
    }

    /// @notice MEDIA_MANIFEST binds both render-affecting fields changed by setCollectionMetadata.
    function previewArtistMediaState(
        uint256 collectionId,
        string calldata image,
        string calldata animationBaseURI
    ) external view returns (bytes32) {
        _requireContentCollection(collectionId);
        bytes32 result = _mediaState(collectionId, image, animationBaseURI);
        if (
            keccak256(bytes(image)) == keccak256(bytes(_collections[collectionId].image))
                && keccak256(bytes(animationBaseURI))
                    == keccak256(bytes(_collections[collectionId].animationBaseURI))
        ) {
            return _withManifest(result, _selectedManifests[collectionId][3]);
        }
        return result;
    }

    function _requireContentCollection(uint256 collectionId) private view {
        if (!core.collectionExists(collectionId)) revert InvalidCollection(collectionId);
        _requireSelectedArtistRegistry();
    }

    function _contentHostContext(uint256 collectionId) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                block.chainid,
                address(core),
                collectionId,
                address(this),
                address(this).codehash,
                address(StreamMetadataRenderer),
                address(StreamMetadataRenderer).codehash
            )
        );
    }

    function _contentState(uint256 collectionId) private view returns (bytes32) {
        CollectionMetadata storage metadata = _collections[collectionId];
        bytes32 serving = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROUTER_ONCHAIN_CONTENT_V1"),
                _contentHostContext(collectionId),
                keccak256(bytes(metadata.image)),
                keccak256(bytes(metadata.animationBaseURI)),
                keccak256(bytes(metadata.animationScript))
            )
        );
        bytes32 rootHead = _contentRoots.heads[collectionId];
        if (rootHead != 0) {
            serving = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ROUTER_CONTENT_WITH_ROOT_V1"),
                    serving,
                    _contentRoots.records[rootHead].stateHash
                )
            );
        }
        M.Selection memory script = _selectedManifests[collectionId][2];
        M.Selection memory media = _selectedManifests[collectionId][3];
        if (script.manifestHash == 0 && media.manifestHash == 0) return serving;
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ROUTER_CONTENT_WITH_MANIFESTS_V1"), serving, script, media
            )
        );
    }

    function previewContentRootPublication(Publication calldata publication, address publisher)
        external
        view
        override
        returns (bytes32)
    {
        _requireContentCollection(publication.collectionId);
        return StreamMetadataContentRoot.prepare(
            _contentRoots,
            StreamMetadataContentRoot.Context(address(core), address(artistRegistry)),
            publication,
            publisher
        )
        .stateHash;
    }

    function publishVerifiedTokenContentRoot(Publication calldata publication)
        external
        override
        returns (bytes32 recordHash)
    {
        _requireContentCollection(publication.collectionId);
        StreamMetadataContentRoot.Context memory ctx =
            StreamMetadataContentRoot.Context(address(core), address(artistRegistry));
        Record memory prepared =
            StreamMetadataContentRoot.prepare(_contentRoots, ctx, publication, msg.sender);
        (bytes32 consent, bytes32 ratification) =
            _authorizeContentWrite(publication.collectionId, CONTENT_ROOT, prepared.stateHash);
        recordHash =
            StreamMetadataContentRoot.publish(_contentRoots, ctx, publication, prepared, consent);
        _recordContentApplication(publication.collectionId, CONTENT_ROOT, consent, ratification);
    }

    function tokenContentRoot(uint256 collectionId, bytes32 subject)
        external
        view
        override
        returns (bytes32, uint64, bytes32)
    {
        return StreamMetadataContentRoot.readRoot(
            _contentRoots, address(core), collectionId, subject
        );
    }

    function contentRootRecord(bytes32 hash) external view override returns (Record memory) {
        return StreamMetadataContentRoot.readRecord(_contentRoots, hash);
    }

    function collectionContentRootHead(uint256 collectionId)
        external
        view
        override
        returns (bytes32)
    {
        return _contentRoots.heads[collectionId];
    }

    function _scriptState(uint256 collectionId, string memory script)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ROUTER_CONTENT_FAMILY_V1"),
                _contentHostContext(collectionId),
                CONTENT_SCRIPT,
                keccak256(bytes(script))
            )
        );
    }

    function _mediaState(uint256 collectionId, string memory image, string memory baseURI)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ROUTER_CONTENT_FAMILY_V1"),
                _contentHostContext(collectionId),
                CONTENT_MEDIA,
                keccak256(bytes(image)),
                keccak256(bytes(baseURI))
            )
        );
    }

    /// @notice Anyone may apply the artist's exact, current defensive freeze without editing content.
    function applyArtistContentFreeze(uint256 collectionId, bytes32 freezeRecordHash) external {
        _requireContentCollection(collectionId);
        StreamMetadataContentLocks.applyFreeze(
            _artistContentLocks,
            address(artistRegistry),
            collectionId,
            freezeRecordHash,
            _contentState(collectionId)
        );
    }

    function _requireContentUnlocked(uint256 collectionId, bytes32 lockClass) private view {
        if (_artistContentLocks[collectionId][lockClass]) {
            revert ArtistContentLocked(collectionId, lockClass);
        }
    }

    function _authorizeMediaWrite(uint256 collectionId, string memory image, string memory baseURI)
        private
        returns (ContentApplication memory application)
    {
        CollectionMetadata storage metadata = _collections[collectionId];
        bool uriChanged = keccak256(bytes(metadata.animationBaseURI)) != keccak256(bytes(baseURI));
        if (keccak256(bytes(metadata.image)) != keccak256(bytes(image)) || uriChanged) {
            _requireContentUnlocked(collectionId, CONTENT_MEDIA);
            if (uriChanged) _requireContentUnlocked(collectionId, LOCK_BASE_URI);
            (application.consent, application.ratification) = _authorizeContentWrite(
                collectionId, CONTENT_MEDIA, _mediaState(collectionId, image, baseURI)
            );
        }
    }

    function _authorizeContentWrite(uint256 collectionId, bytes32 familyId, bytes32 newStateHash)
        private
        returns (bytes32 consent, bytes32 ratification)
    {
        _requireSelectedArtistRegistry();
        return StreamMetadataContentAuthorization.authorize(
            consumedArtistContentConsent,
            _evolutionRatification,
            _evolutionContent,
            StreamMetadataContentAuthorization.Context(
                address(core), address(artistRegistry), collectionId, _contentState(collectionId)
            ),
            familyId,
            newStateHash
        );
    }

    function _recordContentApplication(
        uint256 collectionId,
        bytes32 familyId,
        bytes32 consent,
        bytes32 ratification
    ) private {
        if (consent == bytes32(0)) return;
        StreamMetadataContentAuthorization.recordApplication(
            _evolutionRatification,
            _evolutionContent,
            collectionId,
            familyId,
            consent,
            ratification,
            _contentState(collectionId)
        );
    }

    function _requireSelectedArtistRegistry() private view {
        (address selected, bytes32 codeHash,,,,,,,,) =
            IStreamCorePointers(address(core)).getSatellitePointer(keccak256("ARTIST_REGISTRY"));
        if (
            selected != address(artistRegistry) || selected.code.length == 0
                || codeHash != selected.codehash
        ) {
            revert ArtistRegistryBindingChanged(selected);
        }
    }

    function tokenURI(address core_, uint256 tokenId)
        external
        view
        override
        returns (string memory)
    {
        _requireCore(core_);
        return _serveToken(tokenId, false, true);
    }

    /// @notice Exact profile of the locally linked renderer, without routed serving recursion.
    function renderingProfile() external pure returns (bytes32, bytes32, bytes32) {
        return StreamMetadataRenderTypes.profile();
    }

    function tokenMetadataJSON(address core_, uint256 tokenId) public view returns (string memory) {
        _requireCore(core_);
        return _serveToken(tokenId, false, false);
    }

    function historicalTokenMetadataJSON(address core_, uint256 tokenId)
        external
        view
        override
        returns (string memory)
    {
        _requireCore(core_);
        return _serveToken(tokenId, true, false);
    }

    function _serveToken(uint256 tokenId, bool allowBurned, bool asURI)
        private
        view
        returns (string memory)
    {
        (bool frozen, string memory resolved) = StreamMetadataFinalityServing.token(
            _artistPresentation,
            originalFinalityAnchor,
            StreamMetadataRecoveryRoutes.Environment(
                address(core), address(artistRegistry), _artistRegistryCodeHash
            ),
            _servingAnchor(),
            tokenId,
            allowBurned,
            asURI
        );
        if (frozen) return resolved;
        StreamMetadataTokenReads.TokenFacts memory facts = _tokenFacts(tokenId, allowBurned);
        if (allowBurned && !facts.finalized) revert TokenEntropyNotFinalized(tokenId);
        return _renderToken(facts, asURI, allowBurned);
    }

    function _renderToken(
        StreamMetadataTokenReads.TokenFacts memory facts,
        bool asURI,
        bool historical
    ) private view returns (string memory) {
        PreparedMetadata storage prepared = _prepared[facts.collectionId];
        ServingSource memory metadata = ServingSource(
            prepared.name,
            prepared.description,
            prepared.image,
            prepared.animationBaseURI,
            prepared.animationScript
        );
        StreamMetadataRenderTypes.Token memory token = StreamMetadataRenderTypes.Token(
            facts.tokenId,
            facts.collectionId,
            facts.serial,
            facts.seed,
            facts.finalized,
            facts.state,
            core.tokenData(facts.tokenId),
            _collections[facts.collectionId].configured
        );
        bytes memory artist = historical && _artistPresentation[facts.collectionId].locked
            ? _artistJSON(facts.collectionId)
            : StreamArtistDisplayJSON.nested(_liveAttribution(facts.collectionId, facts.tokenId));
        // Local typed values already have their exact ABI shape. The independently selected
        // finality path still uses renderForFinality to validate its serialized input.
        return asURI
            ? StreamMetadataTokenRenderer.renderURI(token, metadata, artist)
            : StreamMetadataTokenRenderer.render(token, metadata, artist);
    }

    function _tokenFacts(uint256 tokenId, bool allowBurned)
        private
        view
        returns (StreamMetadataTokenReads.TokenFacts memory facts)
    {
        return StreamMetadataTokenReads.facts(address(core), tokenId, allowBurned);
    }

    /// @dev A self-only bounded frame isolates all optional live attribution dependencies.
    function liveAttributionObject(uint256 collectionId, uint256 tokenId)
        external
        view
        returns (bytes memory)
    {
        if (msg.sender != address(this)) revert Unauthorized(msg.sender);
        StreamMetadataRecoveryRoutes.OriginalAnchor memory a = _servingAnchor();
        return StreamArtistDisplayReads.object(
            address(core),
            address(artistRegistry),
            _artistRegistryCodeHash,
            a.registry,
            a.codeHash,
            collectionId,
            tokenId
        );
    }

    function _servingAnchor()
        private
        view
        returns (StreamMetadataRecoveryRoutes.OriginalAnchor memory)
    {
        if (!_originalFinalityAnchorInitialized) revert OriginalFinalityAnchorUninitialized();
        return servingOriginalFinalityAnchor;
    }

    function _liveAttribution(uint256 collectionId, uint256 tokenId)
        private
        view
        returns (bytes memory)
    {
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
        bytes memory input = abi.encodeCall(this.liveAttributionObject, (collectionId, tokenId));
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, address(), add(input, 32), mload(input), 0, 0)
            size := returndatasize()
        }
        if (!ok || size < 64 || size > LIVE_ATTRIBUTION_MAX_BYTES + 64) {
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
        if (
            offset != 32 || length > LIVE_ATTRIBUTION_MAX_BYTES
                || size != 64 + ((length + 31) / 32) * 32
        ) return StreamArtistDisplayJSON.unavailable();
        bytes memory value = abi.decode(raw, (bytes));
        if (keccak256(raw) != keccak256(abi.encode(value))) {
            return StreamArtistDisplayJSON.unavailable();
        }
        return value;
    }

    function _artistJSON(uint256 collectionId) private view returns (bytes memory) {
        return StreamMetadataTokenReads.artistJSON(
            _artistPresentation, address(artistRegistry), collectionId
        );
    }

    function contractURIForCore(address core_) external view override returns (string memory) {
        _requireCore(core_);
        if (bytes(_contractMetadataURI).length != 0) return _contractMetadataURI;
        return _dataURI('{"name":"6529 Stream","description":"6529 Stream NFT collections."}');
    }

    function contractURIForCollection(address core_, uint256 collectionId)
        external
        view
        override
        returns (string memory)
    {
        _requireCore(core_);
        if (!core.collectionExists(collectionId)) revert InvalidCollection(collectionId);
        (bool frozen, string memory resolved) = StreamMetadataFinalityServing.collection(
            _artistPresentation,
            originalFinalityAnchor,
            StreamMetadataRecoveryRoutes.Environment(
                address(core), address(artistRegistry), _artistRegistryCodeHash
            ),
            _servingAnchor(),
            collectionId
        );
        if (frozen) return resolved;
        PreparedMetadata storage metadata = _prepared[collectionId];
        return _dataURI(
            string(
                abi.encodePacked(
                    '{"name":"',
                    metadata.name,
                    '","description":"',
                    metadata.description,
                    '","image":"',
                    metadata.image,
                    '"',
                    StreamArtistDisplayJSON.nested(_liveAttribution(collectionId, 0)),
                    "}"
                )
            )
        );
    }

    function _requireMutable(uint256 collectionId) private view {
        if (msg.sender != authority) revert Unauthorized(msg.sender);
        if (!core.collectionExists(collectionId)) revert InvalidCollection(collectionId);
        if (core.collectionFreezeStatus(collectionId)) revert CollectionFrozen(collectionId);
    }

    function _requireCore(address supplied) private view {
        if (supplied != address(core)) revert InvalidCore(supplied);
    }

    function _dataURI(string memory json) private pure returns (string memory) {
        return StreamMetadataRenderPreparation.dataURI(json);
    }

    function _prepareCollectionMetadata(
        uint256 collectionId,
        string memory name,
        string memory description,
        string memory image,
        string memory animationBaseURI
    ) private {
        ServingSource memory escaped =
            StreamMetadataTokenRenderer.prepareMetadata(name, description, image, animationBaseURI);
        PreparedMetadata storage prepared = _prepared[collectionId];
        prepared.name = escaped.name;
        prepared.description = escaped.description;
        prepared.image = escaped.imageURI;
        prepared.animationBaseURI = escaped.animationBaseURI;
    }

    /// @dev Retain the existing derived-contract preparation hook.
    function _prepareScript(string memory raw) internal pure returns (string memory) {
        return StreamMetadataTokenRenderer.prepareScript(raw);
    }
}
