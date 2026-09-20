// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamMetadataRouterReadFacade as ReadFacade } from "./StreamMetadataRouterReadFacade.sol";
import {
    StreamViewAdoptionTypes as ViewTypes
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import {
    IStreamViewAdoptionRouter as ViewAPI
} from "../../interfaces/stream/metadata/IStreamViewAdoptionRouter.sol";
import { StreamViewAdoption as ViewAdoption } from "./StreamViewAdoption.sol";
import { StreamViewAdoptionState as ViewState } from "./StreamViewAdoptionState.sol";
import { StreamViewAdoptionRouting as ViewRouting } from "./StreamViewAdoptionRouting.sol";
import { StreamViewAdoptionTransport as ViewTransport } from "./StreamViewAdoptionTransport.sol";
import {
    IStreamMetadataFullViews,
    IStreamMetadataHistoricalFullView
} from "../../interfaces/stream/metadata/IStreamMetadataFullViews.sol";
import {
    IStreamScriptBundles as B,
    IStreamScriptBundleSelection
} from "../../interfaces/stream/metadata/IStreamScriptBundles.sol";
import {
    IStreamStaticMetadataRouter as Static
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import { IStreamRenderer as Renderer } from "../../interfaces/stream/metadata/IStreamRenderer.sol";
import { StreamMetadataStaticRouting as StaticRouting } from "./StreamMetadataStaticRouting.sol";
import { StreamMetadataStaticState as StaticState } from "./StreamMetadataStaticState.sol";
import {
    StreamMetadataStaticConfiguration as StaticConfiguration
} from "./StreamMetadataStaticConfiguration.sol";
import { StreamRendererCalls as StaticCalls } from "./StreamRendererCalls.sol";
import { StreamMetadataRouterRendering } from "./StreamMetadataRouterRendering.sol";
import { StreamMetadataBundleRenderer } from "./StreamMetadataBundleRenderer.sol";

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
import { StreamMetadataRouterContent } from "./StreamMetadataRouterContent.sol";
import { StreamMetadataRouterConfigCodec } from "./StreamMetadataRouterConfigCodec.sol";
import { StreamMetadataRouterRootCodec } from "./StreamMetadataRouterRootCodec.sol";
import "./StreamMetadataArtistPresentation.sol";
import "./StreamMetadataTokenRenderer.sol";
import "./StreamMetadataTokenReads.sol";
import "./StreamMetadataImageURI.sol";
import "./StreamMetadataContentRoot.sol";
import {
    IStreamPolicyContentRootPublicationV2 as PolicyRootInterface
} from "../../interfaces/stream/metadata/IStreamPolicyContentRootPublicationV2.sol";
import { StreamMetadataScopedContent } from "./StreamMetadataScopedContent.sol";
import { StreamMetadataScopedContentState } from "./StreamMetadataScopedContentState.sol";
import {
    IStreamScopedContentRootPublication as ScopedRoot
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
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

    // Memory-backed flags avoid specializing the large serving path for each public selector.
    struct TokenViewOptions {
        bool allowBurned;
        uint8 mode;
    }
    uint256 private immutable _staticChainId = block.chainid;
    bytes32 private immutable _viewRoutingCodeHash = address(ViewRouting).codehash;
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
    StreamMetadataScopedContentState.State private _scopedContentRoots;
    event ScopedContentRootPublished(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed scopeSubject,
        bytes32 indexed recordHash,
        ScopedRoot.Record record,
        ScopedRoot.Aggregate collectionAggregate
    );
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
    // Preserve the original inferred error ABI across the fixed read-facade extraction.
    error StaticMetadataSourceChanged(address target);
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
    // Retain manifest errors in the host ABI while the fixed worker emits their original selectors.
    error InvalidCollectionManifest();
    error UnsupportedCollectionManifest();
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
        return id == type(ViewAPI).interfaceId || id == type(Static).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId
            || id == type(IStreamMetadataRouter).interfaceId
            || id == type(IStreamMetadataRenderingProfile).interfaceId
            || id == type(IStreamMetadataHistoricalFullView).interfaceId
            || id == type(IStreamMetadataFullViews).interfaceId
            || id == type(IStreamScriptBundleSelection).interfaceId
            || id == type(IStreamContentRootPublication).interfaceId
            || id == type(PolicyRootInterface).interfaceId || id == type(ScopedRoot).interfaceId
            || id == type(IStreamMetadataServingFacts).interfaceId
            || id == type(IStreamArtistContentFacts).interfaceId
            || id == type(IStreamArtistContentMutationFacts).interfaceId
            || id == type(IStreamMetadataScopeMembership).interfaceId || super.supportsInterface(id);
    }

    /// @notice Explicit static-profile activation; the original serving profile stays unselected otherwise.
    function setDefaultMetadataConfig(Static.ConfigInput calldata input)
        external
        returns (bytes32)
    {
        return StreamMetadataRouterConfigCodec.write(
            _contentLayout(), _contentContext(), 0, 0, msg.data
        );
    }

    function activateStaticMetadata(uint256 collectionId, bytes32 expectedDefaultRecord) external {
        _requireContentCollection(collectionId);
        StaticConfiguration.activate(
            _contentLayout(), _contentContext(), collectionId, expectedDefaultRecord
        );
    }

    function setCollectionMetadataConfig(uint256 collectionId, Static.ConfigInput calldata input)
        external
        returns (bytes32)
    {
        _requireContentCollection(collectionId);
        return StreamMetadataRouterConfigCodec.write(
            _contentLayout(), _contentContext(), collectionId, 0, msg.data
        );
    }

    function setTokenMetadataConfig(uint256 tokenId, Static.ConfigInput calldata input)
        external
        returns (bytes32)
    {
        uint256 id = _staticCollection(tokenId);
        _requireContentCollection(id);
        return StreamMetadataRouterConfigCodec.write(
            _contentLayout(), _contentContext(), id, tokenId, msg.data
        );
    }

    function defaultMetadataConfig() external view returns (Static.ConfigRecord memory) {
        StaticState.State storage s = StaticState.state();
        return StaticState.record(s.defaultHead);
    }

    function metadataConfigAuthorization(bytes32 hash)
        external
        view
        returns (Static.Authorization memory)
    {
        return StaticState.state().authorizations[hash];
    }

    function metadataConfigRecord(bytes32 hash) external view returns (Static.ConfigRecord memory) {
        return StaticState.record(hash);
    }

    function collectionMetadataConfig(uint256 id)
        external
        view
        returns (Static.ConfigRecord memory)
    {
        return StaticState.resolved(id, 0);
    }

    function resolvedMetadataConfig(uint256 tokenId)
        external
        view
        returns (Static.ConfigRecord memory)
    {
        return StaticState.resolved(_staticCollection(tokenId), tokenId);
    }

    function staticMetadataActivation(uint256 id) external view returns (bytes32, uint64, bytes32) {
        StaticState.State storage s = StaticState.state();
        StaticState.Collection storage c = s.collections[id];
        Static.ConfigRecord storage record = s.records[c.activationDefault];
        return (record.previous, record.defaultRevision, c.overridesHead);
    }

    function previewStaticMetadataConfig(
        uint256 id,
        uint256 token,
        Static.ConfigInput calldata input
    ) external view returns (bytes32) {
        return StreamMetadataRouterConfigCodec.preview(_contentContext(), msg.data);
    }

    function previewStaticMetadataActivation(uint256 id, bytes32 expected)
        external
        view
        returns (bytes32)
    {
        return StaticConfiguration.previewActivation(_contentContext(), id, expected);
    }

    /// @notice Named raw Metadata companion read: no renderer or external linked library is called.
    /// @dev Collection zero is the explicit empty golden-vector source, never a token route.
    function staticRenderSource(uint256 id) external view returns (Static.RawSource memory) {
        return _staticSource(id);
    }

    function staticRenderSourceForConfig(uint256 id, bytes32 hash)
        external
        view
        returns (Static.RawSource memory source, Renderer.MetadataConfig memory config)
    {
        if (hash == 0) {
            config.mode = Renderer.MetadataMode.ONCHAIN;
            return (_staticSource(id), config);
        }
        Static.ConfigRecord storage r = StaticState.state().records[hash];
        if (r.recordHash != hash || r.collectionId != id || r.level == 0) {
            revert Static.InvalidStaticMetadataConfig();
        }
        config = r.config;
        if (r.sourceSnapshotHash == 0) return (_staticSource(id), config);
        source = StaticState.state().frozenSources[hash];
        if (
            keccak256(abi.encode(keccak256("6529STREAM_STATIC_SOURCE_SNAPSHOT_V1"), source))
                != r.sourceSnapshotHash
        ) revert Static.InvalidStaticMetadataConfig();
    }

    function _staticSource(uint256 id) private view returns (Static.RawSource memory source) {
        CollectionMetadata storage m = _collections[id];
        source = Static.RawSource(
            _staticChainId,
            m.configured,
            m.name,
            m.description,
            m.image,
            m.animationBaseURI,
            m.animationScript,
            _selectedManifests[id][2],
            _selectedManifests[id][3]
        );
    }

    function _staticCollection(uint256 token) private view returns (uint256 id) {
        bytes memory raw = StaticCalls.read(
            address(core),
            abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (token)),
            StaticCalls.ReadOptions(128, true),
            StreamMetadataDisplayParameters.value(StreamMetadataDisplayParameters.READ_GAS)
        );
        bool exists;
        (exists, id,,) = abi.decode(raw, (bool, uint256, uint256, bool));
        if (!exists) revert InvalidToken(token);
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
        StreamMetadataRouterContent.write(_contentLayout(), _contentContext(), msg.data);
    }

    /// @notice Optional onchain generative script. It receives tokenId, tokenHash and tokenDataBase64.
    /// @dev A stored script takes precedence over the external animation base URI after reveal.
    function setCollectionScript(uint256 collectionId, string calldata script) external {
        StreamMetadataRouterContent.write(_contentLayout(), _contentContext(), msg.data);
    }

    /// @notice Select full typed facts about the actual current script after original content authority.
    function setCollectionScriptManifest(uint256 collectionId, M.ScriptManifest calldata value)
        external
    {
        StreamMetadataRouterContent.write(_contentLayout(), _contentContext(), msg.data);
    }

    function setCollectionMediaManifest(uint256 collectionId, M.MediaManifest calldata value)
        external
    {
        StreamMetadataRouterContent.write(_contentLayout(), _contentContext(), msg.data);
    }

    function previewArtistScriptManifestState(uint256 collectionId, M.ScriptManifest calldata value)
        external
        view
        returns (bytes32)
    {
        bytes memory result =
            StreamMetadataRouterContent.read(_contentLayout(), _contentContext(), msg.data);
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }

    function previewArtistMediaManifestState(uint256 collectionId, M.MediaManifest calldata value)
        external
        view
        returns (bytes32)
    {
        bytes memory result =
            StreamMetadataRouterContent.read(_contentLayout(), _contentContext(), msg.data);
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }

    function selectedCollectionManifest(uint256 collectionId, uint8 kind)
        external
        view
        returns (M.Selection calldata)
    {
        bytes memory result =
            StreamMetadataRouterContent.read(_contentLayout(), _contentContext(), msg.data);
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
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
        returns (CollectionMetadata calldata)
    {
        _collectionRead();
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
        _requireCollection(collectionId);
    }

    function artistPresentation(uint256 collectionId)
        external
        view
        override
        returns (ArtistPresentation calldata)
    {
        _collectionRead();
    }

    function collectionServingFacts(uint256 collectionId)
        external
        view
        override
        returns (ServingFacts calldata result)
    {
        _collectionRead();
    }

    function collectionScriptBundle(uint256 collectionId)
        external
        view
        returns (B.Selection calldata)
    {
        _collectionRead();
    }

    function _scriptBundleId(uint256 collectionId) private view returns (bytes32) {
        return StreamMetadataBundleRenderer.selectedBundleId(_selectedManifests[collectionId][2]);
    }

    function collectionServingSource(uint256 collectionId)
        external
        view
        override
        returns (ServingSource calldata)
    {
        _collectionRead();
    }

    function collectionLiveArtistStatus(uint256 collectionId)
        external
        view
        override
        returns (LiveArtistStatus calldata)
    {
        _collectionRead();
    }

    function _collectionRead() private view {
        bytes memory result = StreamMetadataRouterCollectionReads.read(
            _contentLayout(),
            _artistPresentation,
            _contentContext(),
            address(StreamMetadataTokenRenderer),
            address(StreamMetadataBundleRenderer),
            msg.data
        );
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
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
        _requireCollection(collectionId);
        _requireSelectedArtistRegistry();
        CollectionMetadata storage metadata = _collections[collectionId];
        if (
            !metadata.configured
                || (!StaticState.activated(collectionId)
                    && bytes(metadata.animationScript).length == 0
                    && _scriptBundleId(collectionId) == 0)
        ) {
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
        bytes memory result =
            StreamMetadataRouterContent.read(_contentLayout(), _contentContext(), msg.data);
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }

    function artistContentLockState(uint256 collectionId, bytes32 lockClass)
        external
        view
        override
        returns (bool supported, bool locked)
    {
        _requireContentCollection(collectionId);
        // This router has no dependency assignment mutation: its renderer is linked into code.
        if (lockClass == LOCK_DEPENDENCIES) {
            return (
                true,
                _scriptBundleId(collectionId) == 0
                    || _artistContentLocks[collectionId][CONTENT_SCRIPT]
            );
        }
        supported = lockClass == StaticState.FAMILY || lockClass == CONTENT_SCRIPT
            || lockClass == CONTENT_MEDIA || lockClass == LOCK_BASE_URI;
        return (supported, supported && _artistContentLocks[collectionId][lockClass]);
    }

    function artistContentFreezeState(uint256 collectionId)
        external
        view
        override
        returns (bytes32)
    {
        bytes memory result = StreamMetadataRouterContent.read(
            _contentLayout(), _contentContext(), msg.data
        );
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
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
        bytes memory result =
            StreamMetadataRouterContent.read(_contentLayout(), _contentContext(), msg.data);
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }

    /// @notice MEDIA_MANIFEST binds both render-affecting fields changed by setCollectionMetadata.
    function previewArtistMediaState(
        uint256 collectionId,
        string calldata image,
        string calldata animationBaseURI
    ) external view returns (bytes32) {
        bytes memory result = StreamMetadataRouterContent.read(
            _contentLayout(), _contentContext(), msg.data
        );
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }

    function _requireContentCollection(uint256 collectionId) private view {
        _requireCollection(collectionId);
        _requireSelectedArtistRegistry();
    }

    function _requireCollection(uint256 collectionId) private view {
        if (!core.collectionExists(collectionId)) revert InvalidCollection(collectionId);
    }

    function _contentState(uint256 collectionId) private view returns (bytes32) {
        return StreamMetadataRouterContent.currentState(
            _contentLayout(), _contentContext(), collectionId
        );
    }

    function previewContentRootPublication(Publication calldata publication, address publisher)
        external
        view
        override
        returns (bytes32)
    {
        _requireContentCollection(publication.collectionId);
        return StreamMetadataRouterRootCodec.preview(
            _contentRoots, _scopedContentRoots, _contentLayout(), _contentContext(), msg.data
        );
    }

    function publishVerifiedTokenContentRoot(Publication calldata publication)
        external
        override
        returns (bytes32 recordHash)
    {
        _requireContentCollection(publication.collectionId);
        return StreamMetadataRouterRootCodec.publish(
            _contentRoots, _scopedContentRoots, _contentLayout(), _contentContext(), msg.data
        );
    }

    function previewPolicyContentRootPublication(
        Publication calldata publication,
        address publisher
    ) external view returns (bytes32) {
        _requireContentCollection(publication.collectionId);
        return StreamMetadataRouterRootCodec.preview(
            _contentRoots, _scopedContentRoots, _contentLayout(), _contentContext(), msg.data
        );
    }

    function publishVerifiedPolicyContentRoot(Publication calldata publication)
        external
        returns (bytes32 recordHash)
    {
        _requireContentCollection(publication.collectionId);
        return StreamMetadataRouterRootCodec.publish(
            _contentRoots, _scopedContentRoots, _contentLayout(), _contentContext(), msg.data
        );
    }

    function policyContentRootBinding(bytes32 recordHash)
        external
        view
        returns (PolicyRootInterface.Binding calldata)
    {
        _rootRead();
    }

    function previewViewAdoption(ViewTypes.Input calldata, address)
        external
        view
        returns (bytes32, bytes32)
    {
        bytes memory raw =
            ViewAdoption.previewEncoded(_contentLayout(), _contentContext(), msg.data);
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }

    function adoptView(ViewTypes.Input calldata) external returns (bytes32) {
        return ViewAdoption.adoptEncoded(_contentLayout(), _contentContext(), msg.data);
    }

    function viewAdoptionHead(StreamFinalityScope calldata scope) external view returns (bytes32) {
        return ViewState.state().heads[ViewState.subject(address(core), scope)];
    }

    function viewAdoptionEncoded(bytes32 hash) external view returns (bytes memory) {
        bytes memory raw = ViewTransport.encoded(hash);
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }

    function viewAdoptionCarrier(bytes32 hash) external view returns (address, bytes32, uint32) {
        ViewState.Carrier storage carrier = ViewState.state().records[hash];
        return (carrier.pointer, carrier.hash, carrier.size);
    }

    function viewAdoptionAggregate(uint256 cid) external view returns (ViewTypes.Aggregate memory) {
        return ViewState.state().aggregates[cid];
    }

    function tokenJSONForView(uint256, bytes32) external view returns (string memory) {
        _view();
    }

    function tokenHTMLForView(uint256, bytes32) external view returns (string memory) {
        _view();
    }

    function historicalTokenJSONForView(uint256, bytes32) external view returns (string memory) {
        _view();
    }

    function historicalTokenHTMLForView(uint256, bytes32) external view returns (string memory) {
        _view();
    }

    function _view() private view {
        bytes memory raw = ViewTransport.serve(_viewRoutingCodeHash, msg.data);
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }

    function previewScopedContentRootPublication(
        ScopedRoot.Publication calldata publication,
        address publisher
    ) external view returns (bytes32) {
        _requireContentCollection(publication.scope.collectionId);
        return StreamMetadataRouterRootCodec.preview(
            _contentRoots, _scopedContentRoots, _contentLayout(), _contentContext(), msg.data
        );
    }

    function publishScopedContentRootPublication(ScopedRoot.Publication calldata publication)
        external
        returns (bytes32)
    {
        _requireContentCollection(publication.scope.collectionId);
        return StreamMetadataRouterRootCodec.publish(
            _contentRoots, _scopedContentRoots, _contentLayout(), _contentContext(), msg.data
        );
    }

    function scopedContentRootHead(StreamFinalityScope calldata) external view returns (bytes32) {
        bytes memory out =
            StreamMetadataScopedContent.read(_scopedContentRoots, address(core), msg.data);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function scopedContentRootRecord(bytes32) external view returns (ScopedRoot.Record calldata) {
        bytes memory out =
            StreamMetadataScopedContent.read(_scopedContentRoots, address(core), msg.data);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    /// @notice Direct bounded aggregate read used by the fixed common-content worker.
    /// @dev No dependency calls or delegated reads; preserves the original worker's nine-root layout.
    function scopedContentRootAggregate(uint256 collectionId)
        external
        view
        returns (ScopedRoot.Aggregate memory)
    {
        return _scopedContentRoots.aggregates[collectionId];
    }

    function scopedTokenContentRoot(StreamFinalityScope calldata)
        external
        view
        returns (bytes32, uint64, bytes32)
    {
        bytes memory out =
            StreamMetadataScopedContent.read(_scopedContentRoots, address(core), msg.data);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
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

    function contentRootRecord(bytes32 hash) external view override returns (Record calldata) {
        _rootRead();
    }

    function _rootRead() private view {
        bytes memory result = StreamMetadataRouterRootCodec.read(_contentRoots, msg.data);
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }

    function collectionContentRootHead(uint256 collectionId)
        external
        view
        override
        returns (bytes32)
    {
        return _contentRoots.heads[collectionId];
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

    function _authorizeContentWrite(uint256 collectionId, bytes32 familyId, bytes32 newStateHash)
        private
        returns (bytes32 consent, bytes32 ratification)
    {
        return StreamMetadataRouterContent.authorize(
            _contentLayout(), _contentContext(), collectionId, familyId, newStateHash
        );
    }

    function _recordContentApplication(
        uint256 collectionId,
        bytes32 familyId,
        bytes32 consent,
        bytes32 ratification
    ) private {
        StreamMetadataRouterContent.recordApplication(
            _contentLayout(), _contentContext(), collectionId, familyId, consent, ratification
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

    /// @notice Full executable output, including retained identities of burned tokens.
    function tokenHTML(uint256 tokenId) external view returns (string memory) {
        return _serveTokenView(tokenId, TokenViewOptions(true, 3));
    }

    function tokenJSON(uint256 tokenId) external view returns (string memory) {
        return _serveTokenView(tokenId, TokenViewOptions(true, 2));
    }

    function historicalFullTokenMetadataJSON(address core_, uint256 tokenId)
        external
        view
        returns (string memory)
    {
        _requireCore(core_);
        return _serveTokenView(tokenId, TokenViewOptions(true, 4));
    }

    function _serveToken(uint256 tokenId, bool allowBurned, bool asURI)
        private
        view
        returns (string memory)
    {
        return _serveTokenView(tokenId, TokenViewOptions(allowBurned, asURI ? 1 : 0));
    }

    function _serveTokenView(uint256 tokenId, TokenViewOptions memory options)
        private
        view
        returns (string memory)
    {
        return ReadFacade.token(
            _prepared,
            _collections,
            _artistPresentation,
            originalFinalityAnchor,
            _selectedManifests,
            _readContext(),
            tokenId,
            options
        );
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

    function _readContext() private view returns (ReadFacade.Context memory) {
        return ReadFacade.Context(
            address(core),
            address(artistRegistry),
            _artistRegistryCodeHash,
            _originalFinalityAnchorInitialized,
            servingOriginalFinalityAnchor
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
        return StreamMetadataRouterRendering.live(collectionId, tokenId);
    }

    function _artistJSON(uint256 collectionId) private view returns (bytes memory) {
        return StreamMetadataTokenReads.artistJSON(
            _artistPresentation, address(artistRegistry), collectionId
        );
    }

    function contractURIForCore(address core_) external view override returns (string memory) {
        _requireCore(core_);
        if (bytes(_contractMetadataURI).length != 0) return _contractMetadataURI;
        return StreamMetadataRenderPreparation.defaultContractURI();
    }

    function contractURIForCollection(address core_, uint256 collectionId)
        external
        view
        override
        returns (string memory)
    {
        _requireCore(core_);
        _requireCollection(collectionId);
        return ReadFacade.collection(
            _prepared, _artistPresentation, originalFinalityAnchor, _readContext(), collectionId
        );
    }

    function _requireCore(address supplied) private view {
        if (supplied != address(core)) revert InvalidCore(supplied);
    }

    /// @dev Retain the existing derived-contract preparation hook.
    function _prepareScript(string memory raw) internal pure returns (string memory) {
        return StreamMetadataTokenRenderer.prepareScript(raw);
    }

    /// @dev Compiler-derived original roots; no layout constants or caller-supplied storage addresses.
    function _contentLayout() private pure returns (StreamMetadataRouterContent.Layout memory) {
        uint256 slot0;
        uint256 slot1;
        uint256 slot2;
        uint256 slot3;
        uint256 slot4;
        uint256 slot5;
        uint256 slot6;
        uint256 slot7;
        uint256 slot8;
        assembly ("memory-safe") {
            slot0 := _collections.slot
            slot1 := _prepared.slot
            slot2 := _artistContentLocks.slot
            slot3 := _evolutionRatification.slot
            slot4 := _evolutionContent.slot
            slot5 := consumedArtistContentConsent.slot
            slot6 := _displayMetadataLocked.slot
            slot7 := _contentRoots.slot
            slot8 := _selectedManifests.slot
        }
        return StreamMetadataRouterContent.Layout({
            _collections: slot0,
            _prepared: slot1,
            _artistContentLocks: slot2,
            _evolutionRatification: slot3,
            _evolutionContent: slot4,
            consumedArtistContentConsent: slot5,
            _displayMetadataLocked: slot6,
            _contentRoots: slot7,
            _selectedManifests: slot8
        });
    }

    function _contentContext() private view returns (StreamMetadataRouterContent.Context memory) {
        return
            StreamMetadataRouterContent.Context(address(core), address(artistRegistry), authority);
    }
}
