// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamMetadataPolicyContentRootV2 as PolicyRoot
} from "../../smart-contracts/domains/metadata/StreamMetadataPolicyContentRootV2.sol";
import {
    IStreamPolicyContentRootPublicationV2 as PolicyRootInterface
} from "../../smart-contracts/interfaces/stream/metadata/IStreamPolicyContentRootPublicationV2.sol";
import {
    IStreamMetadataFullViews,
    IStreamMetadataHistoricalFullView
} from "../../smart-contracts/interfaces/stream/metadata/IStreamMetadataFullViews.sol";
import {
    IStreamScriptBundles as B,
    IStreamScriptBundleSelection
} from "../../smart-contracts/interfaces/stream/metadata/IStreamScriptBundles.sol";
import {
    IStreamStaticMetadataRouter as Static
} from "../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamRenderer as Renderer
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    StreamMetadataStaticRouting as StaticRouting
} from "../../smart-contracts/domains/metadata/StreamMetadataStaticRouting.sol";
import {
    StreamMetadataStaticState as StaticState
} from "../../smart-contracts/domains/metadata/StreamMetadataStaticState.sol";
import {
    StreamMetadataStaticConfiguration as StaticConfiguration
} from "../../smart-contracts/domains/metadata/StreamMetadataStaticConfiguration.sol";
import {
    OriginalRendererCallsForSharing as StaticCalls
} from "./OriginalRendererCallsForSharing.sol";
import {
    StreamMetadataRouterRendering
} from "../../smart-contracts/domains/metadata/StreamMetadataRouterRendering.sol";
import {
    StreamMetadataBundleRenderer
} from "../../smart-contracts/domains/metadata/StreamMetadataBundleRenderer.sol";

import "../../smart-contracts/interfaces/stream/core/IStreamCore.sol";
import "../../smart-contracts/interfaces/stream/core/IStreamCorePointers.sol";
import "../../smart-contracts/interfaces/stream/metadata/IStreamMetadataRouter.sol";
import "../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyView.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamCollectionArtistRegistry.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistContentFacts.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistContentRatification.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistContentMutationFacts.sol";
import {
    IStreamArtistContentAuthority
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistContentAuthority.sol";
import {
    StreamArtistContentTypes
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import "../../smart-contracts/domains/modules/StreamModuleBase.sol";
import "../../smart-contracts/domains/metadata/StreamMetadataRenderer.sol";
import {
    StreamMetadataRouterContent
} from "../../smart-contracts/domains/metadata/StreamMetadataRouterContent.sol";
import "../../smart-contracts/domains/metadata/StreamMetadataArtistPresentation.sol";
import "../../smart-contracts/domains/metadata/StreamMetadataTokenRenderer.sol";
import "../../smart-contracts/domains/metadata/StreamMetadataTokenReads.sol";
import "../../smart-contracts/domains/metadata/StreamMetadataImageURI.sol";
import "../../smart-contracts/domains/metadata/StreamMetadataContentRoot.sol";
import {
    StreamMetadataScopedContent
} from "../../smart-contracts/domains/metadata/StreamMetadataScopedContent.sol";
import {
    StreamMetadataScopedContentState
} from "../../smart-contracts/domains/metadata/StreamMetadataScopedContentState.sol";
import {
    IStreamScopedContentRootPublication as ScopedRoot
} from "../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import "../../smart-contracts/domains/metadata/StreamMetadataContentLocks.sol";
import "../../smart-contracts/domains/metadata/StreamMetadataContentAuthorization.sol";
import "../../smart-contracts/domains/metadata/StreamMetadataFinalityServing.sol";
import "../../smart-contracts/domains/metadata/StreamMetadataRouterCollectionReads.sol";
import "../../smart-contracts/domains/metadata/StreamMetadataScopeMembership.sol";
import {
    StreamMetadataDisplayParameters
} from "../../smart-contracts/domains/metadata/StreamMetadataDisplayParameters.sol";
import {
    IStreamGasParameterHost
} from "../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamArtistDisplayReads
} from "../../smart-contracts/domains/metadata/StreamArtistDisplayReads.sol";
import {
    StreamArtistDisplayJSON
} from "../../smart-contracts/domains/metadata/StreamArtistDisplayJSON.sol";
import {
    StreamArtistDisplayTypes
} from "../../smart-contracts/interfaces/stream/metadata/StreamArtistDisplayTypes.sol";
import "../../smart-contracts/interfaces/stream/metadata/IStreamMetadataScopeMembership.sol";
import "../../smart-contracts/interfaces/stream/metadata/IStreamMetadataRenderingProfile.sol";
import {
    IStreamCollectionManifestWriter,
    IStreamMetadataManifestSelection
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionManifestWriter.sol";
import {
    StreamCollectionManifestTypes as M
} from "../../smart-contracts/interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import {
    IStreamContentRootPublication
} from "../../smart-contracts/interfaces/stream/metadata/IStreamContentRootPublication.sol";

import {
    StreamMetadataRouter
} from "../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";

/// @notice Frozen pre-codec method oracle extracted from e0eb03c38fefab405a3b14f259c0b75de2994a05.
/// @dev Test-only same-storage facade: the 15 affected methods and their helpers retain
/// their old bodies; unrelated functions are omitted. Shared structs are qualified to the
/// production Router for storage-pointer compatibility. Never used by production routing.
contract RouterCodecReference is StreamModuleBase {
    struct ContentApplication {
        bytes32 consent;
        bytes32 ratification;
    }
    uint256 private immutable _staticChainId = block.chainid;
    IStreamCore public immutable core;
    address public immutable authority;
    IStreamArtistAttribution public immutable artistRegistry;
    bytes32 private immutable _artistRegistryCodeHash;
    mapping(uint256 => StreamMetadataRouter.CollectionMetadata) private _collections;
    mapping(uint256 => StreamMetadataRouter.PreparedMetadata) private _prepared;
    string private _contractMetadataURI;
    mapping(uint256 => mapping(bytes32 => bool)) private _artistContentLocks;
    mapping(uint256 => bytes32) private _evolutionRatification;
    mapping(uint256 => bytes32) private _evolutionContent;
    mapping(bytes32 => bool) public consumedArtistContentConsent;
    mapping(uint256 => IStreamMetadataServingFacts.ArtistPresentation) private _artistPresentation;
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
    event OriginalFinalityAnchorInitialized(
        uint16 schemaVersion, address indexed registry, bytes32 codeHash
    );

    bytes32 public constant LIVE_ATTRIBUTION_PROFILE = StreamArtistDisplayTypes.PROFILE;

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
        IStreamMetadataServingFacts.ArtistPresentation snapshot,
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

    function setDefaultMetadataConfig(Static.ConfigInput calldata input)
        external
        returns (bytes32)
    {
        return StaticConfiguration.set(_contentLayout(), _contentContext(), 0, 0, input);
    }

    function setCollectionMetadataConfig(uint256 collectionId, Static.ConfigInput calldata input)
        external
        returns (bytes32)
    {
        _requireContentCollection(collectionId);
        return StaticConfiguration.set(_contentLayout(), _contentContext(), collectionId, 0, input);
    }

    function setTokenMetadataConfig(uint256 tokenId, Static.ConfigInput calldata input)
        external
        returns (bytes32)
    {
        uint256 id = _staticCollection(tokenId);
        _requireContentCollection(id);
        return StaticConfiguration.set(_contentLayout(), _contentContext(), id, tokenId, input);
    }

    function previewStaticMetadataConfig(
        uint256 id,
        uint256 token,
        Static.ConfigInput calldata input
    ) external view returns (bytes32) {
        return StaticConfiguration.preview(_contentContext(), id, token, input);
    }

    function _staticCollection(uint256 token) private view returns (uint256 id) {
        bytes memory raw = StaticCalls.read(
            address(core),
            abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (token)),
            128,
            true,
            StreamMetadataDisplayParameters.value(StreamMetadataDisplayParameters.READ_GAS)
        );
        bool exists;
        (exists, id,,) = abi.decode(raw, (bool, uint256, uint256, bool));
        if (!exists) revert InvalidToken(token);
    }

    function collectionMetadata(uint256 collectionId)
        external
        view
        returns (StreamMetadataRouter.CollectionMetadata memory)
    {
        return _collections[collectionId];
    }

    function artistPresentation(uint256 collectionId)
        external
        view
        returns (IStreamMetadataServingFacts.ArtistPresentation memory)
    {
        return _artistPresentation[collectionId];
    }

    function collectionServingFacts(uint256 collectionId)
        external
        view
        returns (IStreamMetadataServingFacts.ServingFacts memory result)
    {
        result = StreamMetadataRouterCollectionReads.facts(
            _collections,
            _artistContentLocks,
            _artistPresentation,
            _displayMetadataLocked,
            core,
            collectionId,
            address(StreamMetadataTokenRenderer)
        );
        B.Selection memory selected = _scriptBundle(collectionId);
        if (selected.bundleId != 0) {
            B.Facts memory f = StreamMetadataBundleRenderer.facts(selected);
            result.presentationProfile = StreamMetadataBundleRenderer.PROFILE;
            result.mode = keccak256("ONCHAIN");
            result.scriptHash = f.payloadHash;
            result.scriptBytes = f.totalBytes;
            result.renderer = address(StreamMetadataBundleRenderer);
            result.rendererCodeHash = result.renderer.codehash;
            result.dependenciesLocked = result.scriptLocked;
        }
        if (StaticState.activated(collectionId)) {
            Static.ConfigRecord memory selectedConfig = StaticState.resolved(collectionId, 0);
            // Old finality providers must reject this distinct profile. They cannot infer
            // a new renderer's output from an old linked-renderer source tuple.
            result.presentationProfile = keccak256("6529STREAM_STATIC_METADATA_SELECTION_V1");
            result.renderer = selectedConfig.selection.renderer;
            result.rendererCodeHash = selectedConfig.selection.rendererCodeHash;
            result.mode = selectedConfig.config.mode == Renderer.MetadataMode.ONCHAIN
                ? keccak256("ONCHAIN")
                : selectedConfig.config.mode == Renderer.MetadataMode.OFFCHAIN
                    ? keccak256("OFFCHAIN")
                    : keccak256("HYBRID");
            result.dependenciesLocked = selectedConfig.config.frozen
                || _artistContentLocks[collectionId][StaticState.FAMILY];
        }
    }

    function collectionScriptBundle(uint256 collectionId)
        external
        view
        returns (B.Selection memory)
    {
        return _scriptBundle(collectionId);
    }

    function _scriptBundle(uint256 collectionId) private view returns (B.Selection memory) {
        return StreamMetadataBundleRenderer.selection(_selectedManifests[collectionId][2]);
    }

    function collectionServingSource(uint256 collectionId)
        external
        view
        returns (IStreamMetadataServingFacts.ServingSource memory)
    {
        IStreamMetadataServingFacts.ServingSource memory result =
            StreamMetadataRouterCollectionReads.source(_collections, core, collectionId);
        if (_scriptBundle(collectionId).bundleId != 0) result.script = "";
        return result;
    }

    function collectionLiveArtistStatus(uint256 collectionId)
        external
        view
        returns (IStreamMetadataServingFacts.LiveArtistStatus memory)
    {
        if (!core.collectionExists(collectionId)) revert InvalidCollection(collectionId);
        return StreamMetadataArtistPresentation.live(
            address(core), address(artistRegistry), collectionId
        );
    }

    function _requireContentCollection(uint256 collectionId) private view {
        if (!core.collectionExists(collectionId)) revert InvalidCollection(collectionId);
        _requireSelectedArtistRegistry();
    }

    function previewContentRootPublication(
        IStreamContentRootPublication.Publication calldata publication,
        address publisher
    ) external view returns (bytes32) {
        _requireContentCollection(publication.collectionId);
        bytes32 legacy =
            StreamMetadataContentRoot.prepare(
            _contentRoots,
            StreamMetadataContentRoot.Context(address(core), address(artistRegistry)),
            publication,
            publisher
        )
        .stateHash;
        return StreamMetadataScopedContentState.familyCurrent(
            address(core), publication.collectionId, legacy
        );
    }

    function publishVerifiedTokenContentRoot(
        IStreamContentRootPublication.Publication calldata publication
    ) external returns (bytes32 recordHash) {
        _requireContentCollection(publication.collectionId);
        StreamMetadataContentRoot.Context memory ctx =
            StreamMetadataContentRoot.Context(address(core), address(artistRegistry));
        IStreamContentRootPublication.Record memory prepared =
            StreamMetadataContentRoot.prepare(_contentRoots, ctx, publication, msg.sender);
        (bytes32 consent, bytes32 ratification) = _authorizeContentWrite(
            publication.collectionId,
            CONTENT_ROOT,
            StreamMetadataScopedContentState.familyCurrent(
                address(core), publication.collectionId, prepared.stateHash
            )
        );
        recordHash =
            StreamMetadataContentRoot.publish(_contentRoots, ctx, publication, prepared, consent);
        _recordContentApplication(publication.collectionId, CONTENT_ROOT, consent, ratification);
    }

    // V2 method bodies frozen from integration 13be0020; only type qualification differs.
    function previewPolicyContentRootPublication(
        IStreamContentRootPublication.Publication calldata publication,
        address publisher
    ) external view returns (bytes32) {
        _requireContentCollection(publication.collectionId);
        (IStreamContentRootPublication.Record memory prepared,) = PolicyRoot.prepare(
            _contentRoots,
            StreamMetadataContentRoot.Context(address(core), address(artistRegistry)),
            publication,
            publisher
        );
        return StreamMetadataScopedContentState.familyCurrent(
            address(core), publication.collectionId, prepared.stateHash
        );
    }

    function publishVerifiedPolicyContentRoot(
        IStreamContentRootPublication.Publication calldata publication
    ) external returns (bytes32 recordHash) {
        _requireContentCollection(publication.collectionId);
        StreamMetadataContentRoot.Context memory ctx =
            StreamMetadataContentRoot.Context(address(core), address(artistRegistry));
        (
            IStreamContentRootPublication.Record memory prepared,
            PolicyRootInterface.Binding memory binding
        ) = PolicyRoot.prepare(_contentRoots, ctx, publication, msg.sender);
        (bytes32 consent, bytes32 ratification) = _authorizeContentWrite(
            publication.collectionId,
            CONTENT_ROOT,
            StreamMetadataScopedContentState.familyCurrent(
                address(core), publication.collectionId, prepared.stateHash
            )
        );
        recordHash = PolicyRoot.publish(_contentRoots, ctx, publication, prepared, binding, consent);
        _recordContentApplication(publication.collectionId, CONTENT_ROOT, consent, ratification);
    }

    function policyContentRootBinding(bytes32 recordHash)
        external
        view
        returns (PolicyRootInterface.Binding memory)
    {
        return PolicyRoot.readBinding(recordHash);
    }

    function previewScopedContentRootPublication(
        ScopedRoot.Publication calldata publication,
        address publisher
    ) external view returns (bytes32) {
        _requireContentCollection(publication.scope.collectionId);
        return StreamMetadataScopedContent.preview(
            _scopedContentRoots, _contentLayout(), _contentContext(), publication, publisher
        );
    }

    function publishScopedContentRootPublication(ScopedRoot.Publication calldata publication)
        external
        returns (bytes32)
    {
        _requireContentCollection(publication.scope.collectionId);
        return StreamMetadataScopedContent.publish(
            _scopedContentRoots, _contentLayout(), _contentContext(), publication
        );
    }

    function contentRootRecord(bytes32 hash)
        external
        view
        returns (IStreamContentRootPublication.Record memory)
    {
        return StreamMetadataContentRoot.readRecord(_contentRoots, hash);
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
