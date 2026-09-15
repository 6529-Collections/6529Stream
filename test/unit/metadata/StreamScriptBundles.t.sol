// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamCollectionMetadataV1
} from "../../../smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol";
import "../../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";
import "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    StreamScriptBundles
} from "../../../smart-contracts/domains/metadata/StreamScriptBundles.sol";
import {
    StreamMetadataBundleRenderer
} from "../../../smart-contracts/domains/metadata/StreamMetadataBundleRenderer.sol";
import {
    StreamMetadataRouter
} from "../../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import {
    StreamMetadataTokenRenderer
} from "../../../smart-contracts/domains/metadata/StreamMetadataTokenRenderer.sol";
import {
    IStreamScriptBundles as B
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScriptBundles.sol";
import {
    StreamCollectionManifestTypes as M
} from "../../../smart-contracts/interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import { Strings } from "../../../smart-contracts/vendor/openzeppelin/Strings.sol";
import { Base64 } from "../../../smart-contracts/vendor/openzeppelin/Base64.sol";
import {
    DependencyRegistry
} from "../../../smart-contracts/domains/dependencies/DependencyRegistry.sol";
import { ManifestArtistBoundary } from "./StreamCollectionManifests.t.sol";
import {
    PresentationCoreBoundary,
    PresentationEntropyBoundary
} from "./StreamMetadataServing.t.sol";
import { MetadataExecutorBoundary } from "./StreamCollectionMetadataV1.t.sol";
import "../../helpers/MetadataRecoveryServingBoundaries.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";

interface BundleMockVm {
    function mockCall(address target, bytes calldata data, bytes calldata returned) external;
    function mockCallRevert(address target, bytes calldata data, bytes calldata reason) external;
    function clearMockedCalls() external;
}

contract BundleArtistBoundary is ManifestArtistBoundary {
    address public finalityRegistry;
    bytes32 public finalityRegistryCodeHash;

    constructor(address c) ManifestArtistBoundary(c) {
        finalityRegistry =
            address(new MetadataRecoveryOriginalBoundary(c, address(this), msg.sender));
        finalityRegistryCodeHash = finalityRegistry.codehash;
    }
}

contract BundleLegacyAdminBoundary {
    function retrieveFunctionAdmin(address, address, bytes4) external pure returns (bool) {
        return true;
    }

    function retrieveGlobalAdmin(address) external pure returns (bool) {
        return true;
    }
}

contract BundleCompanionBoundary {
    address public core;
    address public governanceAuthority;
    address public originalFinalityRegistry;
    address public artistEvidence;
    address public ownerEvidence;
    mapping(bytes32 => StreamMetadataRecoveryRoutes.Route) private routes;
    uint8 public fault;

    constructor(address c, address e, address o, address a, address w) {
        core = c;
        governanceAuthority = e;
        originalFinalityRegistry = o;
        artistEvidence = a;
        ownerEvidence = w;
    }

    function setFault(uint8 x) external {
        fault = x;
    }

    function setOriginal(address x) external {
        originalFinalityRegistry = x;
    }

    function setRoute(bytes32 kind, address module, bytes32 recoveryId) external {
        routes[kind] = StreamMetadataRecoveryRoutes.Route(
            true,
            module,
            keccak256(abi.encode(kind, module, recoveryId)),
            keccak256("original"),
            recoveryId
        );
    }

    function clearRoute(bytes32 kind) external {
        delete routes[kind];
    }

    function resolvedFinalityRoute(bytes32 kind, StreamFinalityScope calldata scope)
        external
        view
        returns (StreamMetadataRecoveryRoutes.Route memory r)
    {
        require(
            scope.collectionId == 1
                && ((scope.scopeType == StreamFinalityScopeType.TOKEN && scope.tokenId == 91)
                    || (scope.scopeType == StreamFinalityScopeType.COLLECTION
                        && scope.tokenId == 0)),
            "scope"
        );
        if (fault == 1) assembly ("memory-safe") { return(0, 159) }
        r = routes[kind];
        if (fault == 2) r.pinned = false;
    }

    function finalityRecoveryRouteStatus(bytes32 kind, StreamFinalityScope calldata)
        external
        view
        returns (bool, bool, bytes32, bytes32)
    {
        StreamMetadataRecoveryRoutes.Route memory r = routes[kind];
        return (
            r.pinned,
            r.pinned && fault != 3,
            fault == 4 ? bytes32(uint256(1)) : r.hash,
            fault == 5 ? bytes32(uint256(1)) : r.recoveryId
        );
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("STREAM_ARTWORK_FINALITY_RECOVERY");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return type(IStreamArtworkFinalityRecovery).interfaceId;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamArtworkFinalityRecovery).interfaceId;
    }
}

contract BundleFrozenSourceBoundary {
    address public immutable core;
    B.Selection private saved;
    bytes32 private immutable payloadHash;
    uint32 private immutable payloadLength;
    uint8 public fault;

    constructor(address c, B.Selection memory selected, B.Facts memory f) {
        core = c;
        saved = selected;
        payloadHash = f.payloadHash;
        payloadLength = f.totalBytes;
    }

    function setFault(uint8 value) external {
        fault = value;
    }

    function collectionScriptBundle(uint256) external view returns (B.Selection memory) {
        return saved;
    }

    function collectionServingSource(uint256)
        external
        pure
        returns (IStreamMetadataServingFacts.ServingSource memory)
    {
        return IStreamMetadataServingFacts.ServingSource(
            "Frozen", "saved description", "ipfs://saved", "", ""
        );
    }

    function collectionServingFacts(uint256)
        external
        view
        returns (IStreamMetadataServingFacts.ServingFacts memory f)
    {
        f.presentationProfile = keccak256("6529STREAM_ROUTER_CHUNKED_PRESENTATION_V1");
        f.configured = true;
        f.mode = keccak256("ONCHAIN");
        f.renderer = address(StreamMetadataBundleRenderer);
        f.rendererCodeHash = f.renderer.codehash;
        f.scriptHash = fault == 1 ? keccak256("wrong") : payloadHash;
        f.scriptBytes = payloadLength;
        f.imageURIHash = keccak256("ipfs://saved");
        f.animationBaseURIHash = keccak256("");
        f.scriptLocked = true;
        f.mediaLocked = true;
        f.baseURILocked = true;
        f.dependenciesLocked = true;
        f.artistIdentityLocked = true;
        f.displayMetadataLocked = true;
        f.coreFrozen = true;
    }

    function artistPresentation(uint256)
        external
        pure
        returns (IStreamMetadataServingFacts.ArtistPresentation memory a)
    {
        a.locked = true;
        a.registry = address(1);
        a.registryCodeHash = bytes32(uint256(1));
        a.artistId = bytes32(uint256(2));
        a.bindingGeneration = 3;
        a.bindingHash = bytes32(uint256(4));
        a.nominatedArtist = address(5);
        a.identityRecordHash = bytes32(uint256(6));
        a.acceptanceRecordHash = bytes32(uint256(7));
        a.snapshotHash = bytes32(uint256(8));
    }

    function tokenSeed(uint256) external pure returns (bytes32, bool) {
        return (keccak256("saved-seed"), true);
    }
}

/// @notice Actual MetadataV1/Router/bytecode blobs and original Safe; Core/Artist/governance are explicit typed boundaries.
contract StreamScriptBundlesTest is CharacterizationTestBase, OfficialSafeFixture {
    using Strings for uint256;
    PresentationCoreBoundary private core;
    BundleArtistBoundary private artist;
    PresentationEntropyBoundary private entropy;
    StreamMetadataRouter private router;
    StreamCollectionMetadataV1 private metadata;
    bytes32 private constant SCRIPT = keccak256("SCRIPT");

    function setUp() public {
        core = new PresentationCoreBoundary();
        artist = new BundleArtistBoundary(address(core));
        entropy = new PresentationEntropyBoundary();
        core.configure(address(artist), address(entropy));
        router = _router(address(this));
        artist.setRouter(address(router));
        MetadataExecutorBoundary executor = new MetadataExecutorBoundary();
        StreamSchemaRegistry schemas = new StreamSchemaRegistry(address(executor));
        StreamCollectionMetadataV1.Configuration memory c;
        c.core = address(core);
        c.executor = address(executor);
        c.schemas = address(schemas);
        c.artistRegistry = address(artist);
        c.deploymentManifestHash = keccak256("deployment");
        c.manifestHash = keccak256("manifest");
        c.manifestURI = "ipfs://metadata";
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 1000000, 100000, 2
        );
        c.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        metadata = new StreamCollectionMetadataV1(c);
        _pointer(keccak256("METADATA_ROUTER"), address(router));
        _pointer(keccak256("COLLECTION_METADATA"), address(metadata));
        router.initializeOriginalFinalityAnchor();
        router.setCollectionMetadata(1, "Name", "Description", "ipfs://image", "");
        core.setMinted(1);
    }

    function _router(address authority) private returns (StreamMetadataRouter) {
        return new StreamMetadataRouter(
            address(core),
            authority,
            keccak256("deployment"),
            "ipfs://router",
            keccak256("manifest"),
            IStreamArtistAttribution(address(artist))
        );
    }

    function _pointer(bytes32 key, address target) private {
        StreamMetadataRecoveryRoutes.Pointer memory p;
        p.target = target;
        p.codeHash = target.codehash;
        p.status = 1;
        p.revision = 1;
        core.setRecoveryPointer(key, p);
    }

    function _plan(
        bytes[] memory chunks,
        bool libraryOnly,
        bytes32 libraryBundle,
        M.PayloadSourceType source
    ) private pure returns (B.Plan memory p) {
        p.sourceType = source;
        p.libraryOnly = libraryOnly;
        p.libraryBundle = libraryBundle;
        p.chunkHashes = new bytes32[](chunks.length);
        p.chunkLengths = new uint32[](chunks.length);
        bytes memory joined;
        for (uint256 i; i < chunks.length; ++i) {
            p.chunkHashes[i] = keccak256(chunks[i]);
            p.chunkLengths[i] = uint32(chunks[i].length);
            joined = bytes.concat(joined, chunks[i]);
        }
        p.payloadHash = keccak256(joined);
    }

    function _one(bytes memory payload) private pure returns (bytes[] memory chunks) {
        chunks = new bytes[](1);
        chunks[0] = payload;
    }

    function _publish(
        bytes[] memory chunks,
        bool libraryOnly,
        bytes32 libraryBundle,
        M.PayloadSourceType source
    ) private returns (bytes32 id) {
        id = metadata.beginScriptBundle(_plan(chunks, libraryOnly, libraryBundle, source));
        for (uint256 i; i < chunks.length; ++i) {
            metadata.appendScriptBundle(id, i, chunks[i]);
        }
        metadata.finalizeScriptBundle(id);
    }

    function _manifest(bytes32 id) private view returns (M.ScriptManifest memory m) {
        B.Facts memory f = metadata.scriptBundle(id);
        m.scriptHash = f.payloadHash;
        m.rendererCompatibility = keccak256("6529STREAM_ROUTER_CHUNKED_PRESENTATION_V1");
        m.sourceType = f.sourceType;
        m.sourcePointer = uint256(id).toHexString(32);
        m.mimeType = "application/javascript";
        m.chunkCount = f.chunkCount;
        m.executable = true;
        m.scriptURI = "ipfs://mirror";
        if (f.libraryBundle != 0) m.libraryURI = "https://example.test/provenance-only.js";
    }

    function _select(bytes32 id) private returns (M.ScriptManifest memory m) {
        m = _manifest(id);
        artist.approve(
            1,
            SCRIPT,
            router.previewArtistScriptManifestState(1, m),
            keccak256(abi.encode("approve", id))
        );
        router.setCollectionScriptManifest(1, m);
    }

    function _contains(string memory text, string memory needle) private pure returns (bool) {
        bytes memory a = bytes(text);
        bytes memory b = bytes(needle);
        if (b.length > a.length) return false;
        for (uint256 i; i <= a.length - b.length; ++i) {
            bool match_ = true;
            for (uint256 j; j < b.length; ++j) {
                if (a[i + j] != b[j]) {
                    match_ = false;
                    break;
                }
            }
            if (match_) return true;
        }
        return false;
    }

    function testLegacySmallManifestNeedsNoBundleCapabilityAndAdvertisedFailureIsTerminal() public {
        string memory script = "oldArtwork();";
        artist.approve(
            1, SCRIPT, router.previewArtistScriptState(1, script), keccak256("raw legacy")
        );
        router.setCollectionScript(1, script);
        M.ScriptManifest memory m;
        m.scriptHash = keccak256(bytes(script));
        m.rendererCompatibility = keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1");
        m.sourceType = M.PayloadSourceType.INLINE_CHUNKS;
        m.mimeType = "application/javascript";
        m.chunkCount = 1;
        m.executable = true;
        artist.approve(
            1, SCRIPT, router.previewArtistScriptManifestState(1, m), keccak256("legacy manifest")
        );
        router.setCollectionScriptManifest(1, m);
        bytes32 hash = metadata.scriptManifestHash(1);
        BundleMockVm mock = BundleMockVm(address(vm));
        bytes memory capability = abi.encodeWithSelector(bytes4(0x01ffc9a7), type(B).interfaceId);
        // Typed compatibility boundary: original host advertises exact absence, and has no
        // new selector. Its actual original manifest/storage/Router paths still execute.
        mock.mockCall(address(metadata), capability, abi.encode(false));
        mock.mockCallRevert(
            address(metadata), abi.encodeCall(B.recordedScriptBundle, (hash)), "no new selector"
        );
        require(router.collectionScriptBundle(1).bundleId == 0);
        require(_contains(router.tokenHTML(91), script));
        require(bytes(router.tokenURI(address(core), 91)).length != 0);
        bytes32 preview = router.previewArtistScriptState(1, "replacement();");
        mock.mockCall(address(metadata), capability, abi.encode(true));
        vm.expectRevert(
            abi.encodeWithSelector(StreamMetadataBundleRenderer.InvalidBundleRendering.selector)
        );
        router.collectionScriptBundle(1);
        mock.mockCall(address(metadata), capability, abi.encode(uint256(2)));
        vm.expectRevert(
            abi.encodeWithSelector(StreamMetadataBundleRenderer.InvalidBundleRendering.selector)
        );
        router.collectionScriptBundle(1);
        mock.mockCallRevert(address(metadata), capability, "capability failed");
        vm.expectRevert(
            abi.encodeWithSelector(StreamMetadataBundleRenderer.InvalidBundleRendering.selector)
        );
        router.collectionScriptBundle(1);
        mock.clearMockedCalls();
        require(router.previewArtistScriptState(1, "replacement();") == preview);
        artist.approve(1, SCRIPT, preview, keccak256("replace legacy"));
        router.setCollectionScript(1, "replacement();");
        require(metadata.scriptManifestHash(1) == 0);
    }

    function testFullJsonHasExactlyOneTokenDataFieldForStableOnchainAndOffchain() public {
        StreamMetadataRenderTypes.Token memory t;
        t.finalized = true;
        t.tokenData = hex"00ff6529";
        t.state = "finalized";
        IStreamMetadataServingFacts.ServingSource memory m;
        for (uint256 branch; branch < 2; ++branch) {
            if (branch == 1) m.script = "render();";
            string memory json = StreamMetadataTokenRenderer.fullJSON(t, m, "");
            bytes memory a = bytes(json);
            bytes memory key = bytes('"token_data_base64"');
            uint256 matches;
            for (uint256 i; i + key.length <= a.length; ++i) {
                bool equal = true;
                for (uint256 j; j < key.length; ++j) {
                    if (a[i + j] != key[j]) {
                        equal = false;
                        break;
                    }
                }
                if (equal) ++matches;
            }
            require(matches == 1, "unique token data field");
            require(
                keccak256(bytes(abi.decode(vm.parseJson(json, ".token_data_base64"), (string))))
                    == keccak256("AP9lKQ==")
            );
            require(_contains(json, '"properties":{"stream":{"render_state":"finalized"}}'));
        }
    }

    function testLogical24576ChunkUsesTwoDeployableBlobsAndExactReconstruction() public {
        bytes memory payload = new bytes(24576);
        for (uint256 i; i < payload.length; ++i) {
            payload[i] = "a";
        }
        vm.recordLogs();
        bytes32 id = _publish(_one(payload), false, 0, M.PayloadSourceType.SSTORE2);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool physical;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].topics[0]
                    == keccak256(
                        "ScriptBundleChunkStored(uint16,bytes32,uint256,bytes32,address,address)"
                    )
            ) {
                (uint16 schema, bytes32 hash, address first, address tail) =
                    abi.decode(logs[i].data, (uint16, bytes32, address, address));
                require(
                    schema == 1 && hash == keccak256(payload) && first.code.length == 24576
                        && tail.code.length == 2,
                    "physical split"
                );
                physical = true;
            }
        }
        require(physical && metadata.scriptBundle(id).totalBytes == 24576);
        _select(id);
        require(keccak256(metadata.scriptChunk(1, 0)) == keccak256(payload));
        require(keccak256(metadata.scriptBundleChunks(id, 0, 1)[0]) == keccak256(payload));
        require(bytes(router.tokenURI(address(core), 91)).length <= 24576, "compact URI cap");
        string memory html = router.tokenHTML(91);
        require(
            bytes(html).length > 24576 && _contains(html, string(payload)), "full bytes preserved"
        );
        require(
            _contains(router.tokenJSON(91), '"token_data_base64":"AP9lKQ=="'), "full data bytes"
        );
    }

    function testAll32MaximumChunksHaveFull786432LogicalCapacity() public {
        bytes memory payload = new bytes(24576);
        for (uint256 i; i < payload.length; ++i) {
            payload[i] = "a";
        }
        bytes[] memory chunks = new bytes[](32);
        for (uint256 i; i < 32; ++i) {
            chunks[i] = payload;
        }
        bytes32 id = _publish(chunks, false, 0, M.PayloadSourceType.SSTORE2);
        require(
            metadata.scriptBundle(id).totalBytes == 786432
                && metadata.scriptBundle(id).chunkCount == 32
        );
        for (uint256 i; i < 32; i += 4) {
            bytes[] memory page = metadata.scriptBundleChunks(id, i, 4);
            require(page.length == 4);
            for (uint256 j; j < 4; ++j) {
                require(keccak256(page[j]) == keccak256(payload));
            }
        }
        _select(id);
        string memory html = router.tokenHTML(91);
        require(
            bytes(html).length > 786432 && bytes(router.tokenURI(address(core), 91)).length <= 24576
        );
    }

    function testIncompleteWrongHashAndOutOfBoundsNeverSelectOrOverwrite() public {
        B.Plan memory p =
            _plan(_one(bytes("original")), false, 0, M.PayloadSourceType.INLINE_CHUNKS);
        bytes32 id = metadata.beginScriptBundle(p);
        vm.expectRevert(abi.encodeWithSelector(B.InvalidScriptBundle.selector, id));
        metadata.finalizeScriptBundle(id);
        M.ScriptManifest memory m = _manifest(id);
        vm.expectRevert(abi.encodeWithSelector(B.InvalidScriptBundle.selector, id));
        router.previewArtistScriptManifestState(1, m);
        vm.expectRevert(abi.encodeWithSelector(B.InvalidScriptBundle.selector, id));
        metadata.appendScriptBundle(id, 0, "changed");
        metadata.appendScriptBundle(id, 0, "original");
        metadata.finalizeScriptBundle(id);
        vm.expectRevert(abi.encodeWithSelector(B.InvalidScriptBundle.selector, id));
        metadata.appendScriptBundle(id, 0, "changed");
        vm.expectRevert(abi.encodeWithSelector(B.InvalidScriptBundle.selector, id));
        metadata.scriptBundleChunks(id, 0, 5);
        vm.expectRevert(abi.encodeWithSelector(B.InvalidScriptBundle.selector, id));
        metadata.scriptBundleChunk(id, 1);
        p.chunkLengths[0] = 8193;
        vm.expectRevert(abi.encodeWithSelector(B.InvalidScriptBundle.selector, bytes32(0)));
        metadata.beginScriptBundle(p);
        require(keccak256(metadata.scriptBundleChunk(id, 0)) == keccak256("original"));
    }

    function testPinnedLibraryAndCrossChunkClosingTagEscapeHaveOneExecutableScript() public {
        bytes32 lib = _publish(
            _one(bytes("const libraryValue=7;")), true, 0, M.PayloadSourceType.INLINE_CHUNKS
        );
        bytes[] memory chunks = new bytes[](2);
        chunks[0] = bytes("document.body.textContent=libraryValue;/* </ScR");
        chunks[1] = bytes("iPt> */");
        bytes32 id = _publish(chunks, false, lib, M.PayloadSourceType.INLINE_CHUNKS);
        _select(id);
        string memory html = router.tokenHTML(91);
        require(
            _contains(
                html,
                "const libraryValue=7;\n;\ndocument.body.textContent=libraryValue;/* <\\/ScRiPt> */"
            ),
            "whole payload escaped"
        );
        require(
            !_contains(html, "<script src=")
                && !_contains(html, "https://example.test/provenance-only.js")
        );
        require(keccak256(metadata.dependencyChunk(lib, 0)) == keccak256("const libraryValue=7;"));
        require(
            _contains(
                router.tokenMetadataJSON(address(core), 91), '"properties":{"render_mode":"compact"'
            )
        );
    }

    function testOriginalAuthorityConsentNoopFreezeAndSameRawReplacement() public {
        bytes32 id = _publish(_one(bytes("render();")), false, 0, M.PayloadSourceType.INLINE_CHUNKS);
        M.ScriptManifest memory m = _manifest(id);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistContentAuthorizationRequired.selector, uint256(1)
            )
        );
        router.setCollectionScriptManifest(1, m);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.MetadataAuthorityRequired.selector)
        );
        metadata.storeScriptManifest(1, m);
        _select(id);
        bytes32 hash = metadata.scriptManifestHash(1);
        router.setCollectionScriptManifest(1, m);
        require(metadata.scriptManifestHash(1) == hash);
        // The retained legacy raw string is empty, but setting that same value must clear a bundle.
        artist.approve(1, SCRIPT, router.previewArtistScriptState(1, ""), keccak256("clear bundle"));
        router.setCollectionScript(1, "");
        require(metadata.scriptManifestHash(1) == 0);
        require(metadata.recordedScriptBundle(hash) == id && metadata.scriptBundle(id).finalized);
        artist.approve(
            1, SCRIPT, router.previewArtistScriptManifestState(1, m), keccak256("select again")
        );
        router.setCollectionScriptManifest(1, m);
        artist.freeze(SCRIPT, router.artistContentFreezeState(1));
        router.applyArtistContentFreeze(1, keccak256("manifest freeze"));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistContentLocked.selector, uint256(1), SCRIPT
            )
        );
        router.setCollectionScript(1, "changed");
        (, bool locked) = router.artistContentLockState(1, keccak256("DEPENDENCIES"));
        require(locked);
    }

    function testCurrentPointerDriftFailsButRetainedChunksRemainReadable() public {
        bytes32 id = _publish(_one(bytes("render();")), false, 0, M.PayloadSourceType.INLINE_CHUNKS);
        _select(id);
        _pointer(keccak256("COLLECTION_METADATA"), address(artist));
        vm.expectRevert(
            abi.encodeWithSelector(StreamMetadataBundleRenderer.InvalidBundleRendering.selector)
        );
        router.tokenHTML(91);
        require(keccak256(metadata.scriptBundleChunk(id, 0)) == keccak256("render();"));
        _pointer(keccak256("COLLECTION_METADATA"), address(metadata));
        require(_contains(router.tokenHTML(91), "render();"));
    }

    function testBurnedFullViewsDiscloseStateAndOrdinaryERC721ReadStillRejects() public {
        bytes32 id = _publish(_one(bytes("render();")), false, 0, M.PayloadSourceType.INLINE_CHUNKS);
        _select(id);
        core.setLifecycle(3);
        require(_contains(router.tokenJSON(91), '"stream":{"render_state":"burned"}'));
        require(_contains(router.tokenHTML(91), "data-stream-render-state=\"burned\""));
        vm.expectRevert(
            abi.encodeWithSelector(StreamMetadataFinalityServing.InvalidToken.selector, uint256(91))
        );
        router.tokenURI(address(core), 91);
        core.setLifecycle(2);
        entropy.setFinalized(false);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.TokenEntropyNotFinalized.selector, uint256(91)
            )
        );
        router.tokenHTML(91);
    }

    function testStreamingUtf8AcrossChunksAndUnfinishedOrOverlongSequences() public {
        bytes[] memory chunks = new bytes[](2);
        chunks[0] = hex"2f2fe2";
        chunks[1] = hex"82ac";
        B.Plan memory p = _plan(chunks, false, 0, M.PayloadSourceType.INLINE_CHUNKS);
        bytes32 id = metadata.beginScriptBundle(p);
        vm.expectRevert(abi.encodeWithSelector(B.InvalidScriptBundle.selector, id));
        metadata.appendScriptBundle(id, 1, chunks[1]);
        metadata.appendScriptBundle(id, 0, chunks[0]);
        vm.expectRevert(abi.encodeWithSelector(B.InvalidScriptBundle.selector, id));
        metadata.finalizeScriptBundle(id);
        metadata.appendScriptBundle(id, 1, chunks[1]);
        metadata.finalizeScriptBundle(id);
        require(metadata.scriptBundle(id).payloadHash == keccak256(hex"2f2fe282ac"));
        p = _plan(_one(hex"c080"), false, 0, M.PayloadSourceType.INLINE_CHUNKS);
        id = metadata.beginScriptBundle(p);
        vm.expectRevert(abi.encodeWithSelector(B.InvalidScriptBundle.selector, id));
        metadata.appendScriptBundle(id, 0, hex"c080");
        p = _plan(_one(hex"edbfbf"), false, 0, M.PayloadSourceType.INLINE_CHUNKS);
        id = metadata.beginScriptBundle(p);
        vm.expectRevert(abi.encodeWithSelector(B.InvalidScriptBundle.selector, id));
        metadata.appendScriptBundle(id, 0, hex"edbfbf");
    }

    function testActualLegacyRegistryVersionIsPinnedWithoutLatestOrURIExecution() public {
        DependencyRegistry registry =
            new DependencyRegistry(address(new BundleLegacyAdminBoundary()));
        string[] memory chunks = new string[](2);
        chunks[0] = "const lib=";
        chunks[1] = "7;";
        bytes32 key = keccak256("library v1");
        registry.addDependency(key, chunks);
        bytes[] memory raw = new bytes[](2);
        raw[0] = bytes(chunks[0]);
        raw[1] = bytes(chunks[1]);
        B.Plan memory p = _plan(raw, true, 0, M.PayloadSourceType.DEPENDENCY_REGISTRY);
        B.RegistrySource memory source = B.RegistrySource(
            address(registry),
            address(registry).codehash,
            key,
            1,
            registry.getDependencyScriptContentHashAtVersion(key, 1)
        );
        bytes32 lib = metadata.beginRegistryLibrary(p, source);
        metadata.appendScriptBundle(lib, 0, raw[0]);
        metadata.appendScriptBundle(lib, 1, raw[1]);
        metadata.finalizeScriptBundle(lib);
        bytes32 id = _publish(
            _one(bytes("document.body.textContent=lib;")),
            false,
            lib,
            M.PayloadSourceType.INLINE_CHUNKS
        );
        _select(id);
        string memory expected = router.tokenHTML(91);
        registry.addDependencyScriptIndex(key, 1, "999;");
        require(
            keccak256(bytes(router.tokenHTML(91))) == keccak256(bytes(expected)),
            "latest version cannot drift pinned bytes"
        );
        M.DependencyManifest memory dm = metadata.dependencyManifest(lib);
        require(
            dm.dependencyId == lib && dm.dependencyHash == p.payloadHash && dm.useDependencyRegistry
                && keccak256(bytes(dm.version)) == keccak256("1")
        );
        require(
            metadata.scriptBundleRegistry(lib).version == 1 && _contains(expected, "const lib=7;")
        );
        source.contentHash = keccak256("wrong");
        vm.expectRevert(abi.encodeWithSelector(B.InvalidScriptBundle.selector, bytes32(0)));
        metadata.beginRegistryLibrary(p, source);
        vm.etch(address(registry), hex"00");
        vm.expectRevert();
        router.tokenHTML(91);
    }

    function testSafeSelectionFailureKeepsNonceAndIdenticalSignedRetry() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 71;
        keys[1] = 72;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 9011);
        router = _router(address(account));
        artist.setRouter(address(router));
        _pointer(keccak256("METADATA_ROUTER"), address(router));
        core.setMinted(0);
        require(
            executeSafe(
                account,
                keys,
                address(router),
                0,
                abi.encodeCall(
                    router.setCollectionMetadata, (1, "Name", "Description", "ipfs://image", "")
                ),
                0
            )
        );
        core.setMinted(1);
        bytes32 id =
            _publish(_one(bytes("safeScript();")), false, 0, M.PayloadSourceType.INLINE_CHUNKS);
        M.ScriptManifest memory m = _manifest(id);
        bytes memory data = abi.encodeCall(router.setCollectionScriptManifest, (1, m));
        uint256 nonce = account.nonce();
        bytes32 digest = account.getTransactionHash(
            address(router), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory signatures = safeThresholdSignature(keys, digest);
        bytes memory transaction = abi.encodeCall(
            account.execTransaction,
            (address(router), 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signatures)
        );
        (bool ok, bytes memory reason) = address(account).call(transaction);
        require(
            !ok && keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && account.nonce() == nonce
        );
        require(metadata.scriptManifestHash(1) == 0 && metadata.scriptBundle(id).finalized);
        bytes32 approval = keccak256("exact Safe bundle approval");
        artist.approve(1, SCRIPT, router.previewArtistScriptManifestState(1, m), approval);
        (ok, reason) = address(account).call(transaction);
        require(
            ok && abi.decode(reason, (bool)) && account.nonce() == nonce + 1
                && router.consumedArtistContentConsent(approval)
        );
        require(metadata.recordedScriptBundle(metadata.scriptManifestHash(1)) == id);
    }

    function testFrozenFullViewsUseSavedBundleWithCurrentPointersChangedAndRestoreOnProofDrift()
        public
    {
        bytes32 id =
            _publish(_one(bytes("savedArtwork();")), false, 0, M.PayloadSourceType.INLINE_CHUNKS);
        _select(id);
        BundleFrozenSourceBoundary source = new BundleFrozenSourceBoundary(
            address(core), router.collectionScriptBundle(1), metadata.scriptBundle(id)
        );
        address original = artist.finalityRegistry();
        MetadataRecoveryOriginalBoundary(original).setCount(7);
        MetadataRecoveryRegistryBoundary registry = new MetadataRecoveryRegistryBoundary();
        MetadataRecoveryOwnerBoundary owner =
            new MetadataRecoveryOwnerBoundary(address(core), address(this));
        BundleCompanionBoundary companion = new BundleCompanionBoundary(
            address(core), address(this), original, address(artist), address(owner)
        );
        StreamMetadataRecoveryRoutes.Pointer memory p = StreamMetadataRecoveryRoutes.Pointer(
            address(registry),
            address(registry).codehash,
            false,
            keccak256("MODULE_REGISTRY"),
            0,
            address(registry),
            1,
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            1
        );
        core.setRecoveryPointer(keccak256("MODULE_REGISTRY"), p);
        p = StreamMetadataRecoveryRoutes.Pointer(
            address(companion),
            address(companion).codehash,
            false,
            keccak256("STREAM_ARTWORK_FINALITY_RECOVERY"),
            type(IStreamArtworkFinalityRecovery).interfaceId,
            address(registry),
            1,
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            1
        );
        core.setRecoveryPointer(keccak256("ARTWORK_FINALITY_RECOVERY"), p);
        bytes32[7] memory kinds = [
            keccak256("METADATA_ROUTER"),
            keccak256("MEDIA_MANIFEST"),
            keccak256("RENDERER"),
            keccak256("RENDER_CONTEXT"),
            keccak256("SCRIPT_SOURCE"),
            keccak256("DEPENDENCY_SOURCE"),
            keccak256("ENTROPY_COORDINATOR")
        ];
        for (uint256 i; i < 7; ++i) {
            companion.setRoute(
                kinds[i],
                address(
                    new MetadataRecoveryAdapterBoundary(address(core), address(source), kinds[i])
                ),
                0
            );
        }
        string memory html = router.tokenHTML(91);
        require(_contains(html, "savedArtwork();"));
        _pointer(keccak256("COLLECTION_METADATA"), address(artist));
        _pointer(keccak256("METADATA_ROUTER"), address(artist));
        require(
            keccak256(bytes(router.tokenHTML(91))) == keccak256(bytes(html)),
            "saved selected bytes independent of live pointers"
        );
        core.setLifecycle(3);
        require(_contains(router.tokenJSON(91), '"render_state":"burned"'));
        source.setFault(1);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataFinalityServing.MetadataFrozenBytesInvalid.selector, address(source)
            )
        );
        router.tokenHTML(91);
        source.setFault(0);
        require(_contains(router.tokenHTML(91), "savedArtwork();"));
        companion.setFault(3);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRecoveryRoutes.MetadataFrozenRouteInvalid.selector,
                keccak256("METADATA_ROUTER")
            )
        );
        router.tokenHTML(91);
    }
}
