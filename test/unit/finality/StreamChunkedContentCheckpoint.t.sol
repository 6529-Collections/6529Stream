// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScriptBundlesTest,
    BundleMockVm,
    B,
    M,
    BundleLegacyAdminBoundary,
    DependencyRegistry
} from "../metadata/StreamScriptBundles.t.sol";
import {
    StreamOnchainContentCheckpoint
} from "../../../smart-contracts/domains/finality/StreamOnchainContentCheckpoint.sol";
import {
    StreamChunkedContentEvidence
} from "../../../smart-contracts/domains/finality/StreamChunkedContentEvidence.sol";
import {
    StreamFinalityRouterEvidence
} from "../../../smart-contracts/domains/finality/StreamFinalityRouterEvidence.sol";
import {
    StreamMetadataRecoveryRoutes
} from "../../../smart-contracts/domains/metadata/StreamMetadataRecoveryRoutes.sol";
import {
    StreamMetadataTokenRenderer
} from "../../../smart-contracts/domains/metadata/StreamMetadataTokenRenderer.sol";
import {
    IStreamOnchainContentCheckpoint
} from "../../../smart-contracts/interfaces/stream/finality/IStreamOnchainContentCheckpoint.sol";
import {
    IStreamMetadataRouter
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataRouter.sol";
import {
    IStreamArtistAttributionState
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionState.sol";
import {
    IStreamArtistAttribution,
    IStreamCollectionArtistRegistry
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttribution.sol";
import {
    IStreamGasParameterHost
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamTokenContentLeaf
} from "../../../smart-contracts/interfaces/stream/metadata/StreamTokenContentTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType,
    StreamFinalityDomains
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { Strings } from "../../../smart-contracts/vendor/openzeppelin/Strings.sol";
import { Vm } from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import { Base64 } from "../../../smart-contracts/vendor/openzeppelin/Base64.sol";

/// @dev Explicit typed inventory boundary; the checkpoint, Router, Metadata and blobs are actual contracts.
contract ChunkCheckpointInventoryBoundary {
    address public immutable core;
    bytes32 public commitment = keccak256("one historical token");

    constructor(address c) {
        core = c;
    }

    function setCommitment(bytes32 h) external {
        commitment = h;
    }

    function requireCompleteCollection(uint256 c) external view returns (uint256, bytes32) {
        require(c == 1);
        return (1, commitment);
    }

    function collectionTokenAt(uint256 c, uint256 i) external pure returns (uint256) {
        require(c == 1 && i == 0);
        return 91;
    }
}

/// @notice Actual chunk admission, rendering, content locks and checkpoint roots; typed Core/Artist/inventory/entropy.
/// @dev Authored cases; execution is deferred to the consolidated native cohort.
contract StreamChunkedContentCheckpointTest is StreamScriptBundlesTest {
    using Strings for uint256;
    StreamOnchainContentCheckpoint private checkpoint;
    ChunkCheckpointInventoryBoundary private inventory;
    bytes32 private constant CHUNK_PROFILE = keccak256("6529STREAM_CONTENT_CHUNKED_ONCHAIN_V1");
    bytes32 private constant SCRIPT_FAMILY = keccak256("SCRIPT_SOURCE");
    bytes32 private constant DEPENDENCY_FAMILY = keccak256("DEPENDENCY_SOURCE");
    bytes32 private constant MEDIA_FAMILY = keccak256("MEDIA_MANIFEST");

    function _checkpointSetup() private {
        core.setMinted(0);
        router.setCollectionMetadata(1, "Name", "Description", "", "");
        core.setMinted(1);
        StreamMetadataRecoveryRoutes.Pointer memory p = StreamMetadataRecoveryRoutes.Pointer(
            address(router),
            address(router).codehash,
            false,
            keccak256("METADATA_ROUTER"),
            type(IStreamMetadataRouter).interfaceId,
            address(this),
            1,
            keccak256("module"),
            keccak256("deployment"),
            1
        );
        core.setRecoveryPointer(keccak256("METADATA_ROUTER"), p);
        inventory = new ChunkCheckpointInventoryBoundary(address(core));
        checkpoint = new StreamOnchainContentCheckpoint(
            address(core),
            address(router),
            address(inventory),
            address(this),
            IStreamGasParameterHost.GasParameterConfig(
                "CONTENT_CHECKPOINT_READ_GAS", 2000000, 100000, 1
            ),
            IStreamGasParameterHost.GasParameterConfig(
                "CONTENT_CHECKPOINT_RENDER_GAS", 80000000, 1000000, 1
            )
        );
    }

    function _large() private pure returns (bytes memory s) {
        s = new bytes(9000);
        for (uint256 i; i < s.length; ++i) {
            s[i] = 0x20;
        }
        s[0] = 0x2f;
        s[1] = 0x2f;
    }

    function _largeSelected(bool withLibrary) private returns (bytes memory script, bytes32 id) {
        bytes memory raw = _large();
        bytes32 lib = withLibrary
            ? _publish(_one(bytes("const value=7;")), true, 0, M.PayloadSourceType.SSTORE2)
            : bytes32(0);
        id = _publish(_one(raw), false, lib, M.PayloadSourceType.SSTORE2);
        _select(id);
        script = withLibrary ? bytes.concat(bytes("const value=7;\n;\n"), raw) : raw;
    }

    function _lock() private {
        bytes32[4] memory locks = [
            keccak256("SCRIPT"),
            keccak256("MEDIA_MANIFEST"),
            keccak256("BASE_URI"),
            keccak256("DEPENDENCIES")
        ];
        for (uint256 i; i < 4; ++i) {
            artist.freeze(locks[i], router.artistContentFreezeState(1));
            router.applyArtistContentFreeze(1, keccak256("manifest freeze"));
        }
        BundleMockVm v = BundleMockVm(address(vm));
        v.mockCall(
            address(artist),
            abi.encodeWithSelector(
                bytes4(0x01ffc9a7), type(IStreamArtistAttributionState).interfaceId
            ),
            abi.encode(true)
        );
        v.mockCall(
            address(artist),
            abi.encodeCall(IStreamArtistAttributionState.collectionArtistState, (1)),
            abi.encode(uint8(2), uint64(4), keccak256("artist"), uint8(1), keccak256("binding"))
        );
        IStreamCollectionArtistRegistry.Attribution memory a =
            IStreamCollectionArtistRegistry.Attribution(
                address(0xa11ce),
                address(0xa11ce),
                keccak256("identity"),
                keccak256("binding"),
                keccak256("acceptance"),
                4,
                0
            );
        v.mockCall(
            address(artist),
            abi.encodeCall(IStreamArtistAttribution.attribution, (1)),
            abi.encode(a)
        );
        router.lockArtistIdentity(1);
        v.clearMockedCalls();
        router.lockDisplayMetadata(1);
    }

    function _payload(bytes memory script)
        private
        view
        returns (IStreamOnchainContentCheckpoint.TokenPayload[] memory p)
    {
        p = new IStreamOnchainContentCheckpoint.TokenPayload[](1);
        bytes memory html = abi.encodePacked(
            "<html><head></head><body><script>const tokenId=91;const tokenHash='",
            uint256(keccak256("seed")).toHexString(32),
            "';const tokenDataBase64='",
            Base64.encode(hex"00ff6529"),
            "';",
            StreamMetadataTokenRenderer.prepareScript(string(script)),
            "</script></body></html>"
        );
        p[0] = IStreamOnchainContentCheckpoint.TokenPayload(91, "", html);
    }

    function component(bytes32 family) external view returns (bool, bytes32) {
        return StreamFinalityRouterEvidence.facts(
            StreamFinalityRouterEvidence.Config(
                address(core), address(router), block.chainid, 2000000, 5000000
            ),
            family,
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
        );
    }

    function _leaf(bytes32 id, IStreamOnchainContentCheckpoint.TokenPayload memory p)
        private
        view
        returns (bytes32 hash)
    {
        StreamTokenContentLeaf memory f = checkpoint.checkpointLeaf(id, 0);
        require(
            f.tokenId == 91
                && f.metadataHash
                    == keccak256(bytes(router.historicalFullTokenMetadataJSON(address(core), 91)))
                && f.imageHash == 0 && f.animationHash == keccak256(p.animation)
                && f.contentHash == 0 && f.tokenDataHash == keccak256(hex"00ff6529"),
            "all six actual leaf fields"
        );
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_TOKEN_CONTENT_LEAF_V1"),
                block.chainid,
                address(core),
                uint256(91),
                f.metadataHash,
                bytes32(0),
                f.animationHash,
                bytes32(0),
                keccak256(hex"00ff6529")
            )
        );
    }

    function testChunkedProfileFullArtworkLibraryLeafAndIndependentPlanRoot() public {
        _checkpointSetup();
        (bytes memory script,) = _largeSelected(true);
        _lock();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamOnchainContentCheckpoint.CheckpointUnsupportedPresentation.selector
            )
        );
        checkpoint.beginCollectionCheckpoint(1);
        bytes32 id = checkpoint.beginChunkedCollectionCheckpoint(1);
        IStreamOnchainContentCheckpoint.Plan memory p = checkpoint.checkpoint(id);
        require(
            checkpoint.checkpointProfile(id) == CHUNK_PROFILE
                && id
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_CONTENT_CHECKPOINT_V1"),
                            block.chainid,
                            address(checkpoint),
                            CHUNK_PROFILE,
                            address(core),
                            address(router),
                            address(inventory),
                            uint256(1),
                            uint256(1),
                            p.inventoryHash,
                            p.servingStateHash
                        )
                    ),
            "explicit independent plan domain"
        );
        require(
            _contains(router.tokenMetadataJSON(address(core), 91), "web3://")
                && _contains(
                    router.historicalFullTokenMetadataJSON(address(core), 91),
                    "data:text/html;base64,"
                ),
            "compact and complete are distinct"
        );
        IStreamOnchainContentCheckpoint.TokenPayload[] memory payload = _payload(script);
        checkpoint.appendCheckpointTokens(id, payload);
        require(
            checkpoint.requireCurrentCheckpoint(id).contentRoot == _leaf(id, payload[0]),
            "one leaf exact root"
        );
        require(checkpoint.beginChunkedCollectionCheckpoint(1) == id, "idempotent plan");
        bytes32[6] memory families = [
            keccak256("METADATA_ROUTER"),
            keccak256("RENDERER"),
            keccak256("RENDER_CONTEXT"),
            MEDIA_FAMILY,
            SCRIPT_FAMILY,
            DEPENDENCY_FAMILY
        ];
        for (uint256 i; i < 6; ++i) {
            (bool locked, bytes32 hash) = this.component(families[i]);
            require(locked && hash != 0, "each actual chunked family");
        }
    }

    function testChunkedHistoricalFullJSONAndRootRemainStableAcrossBurnAndCoreFreeze() public {
        _checkpointSetup();
        (bytes memory script,) = _largeSelected(false);
        _lock();
        bytes32 id = checkpoint.beginChunkedCollectionCheckpoint(1);
        bytes32 before = keccak256(bytes(router.historicalFullTokenMetadataJSON(address(core), 91)));
        core.setLifecycle(3);
        core.setFrozen(true);
        require(
            keccak256(bytes(router.historicalFullTokenMetadataJSON(address(core), 91))) == before
                && _contains(router.tokenJSON(91), '"render_state":"burned"'),
            "historical bytes and current disclosure"
        );
        checkpoint.appendCheckpointTokens(id, _payload(script));
        bytes32 root = checkpoint.requireCurrentCheckpoint(id).contentRoot;
        require(root == _leaf(id, _payload(script)[0]), "burn keeps full root");
        inventory.setCommitment(keccak256("new actual inventory"));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamOnchainContentCheckpoint.CheckpointInputChanged.selector, id
            )
        );
        checkpoint.requireCurrentCheckpoint(id);
        require(checkpoint.checkpoint(id).contentRoot == root, "completed history retained");
    }

    function testChunkedBadPayloadAndPendingEntropyRollBackThenExactRetry() public {
        _checkpointSetup();
        (bytes memory script,) = _largeSelected(false);
        _lock();
        bytes32 id = checkpoint.beginChunkedCollectionCheckpoint(1);
        IStreamOnchainContentCheckpoint.TokenPayload[] memory payload = _payload(script);
        bytes memory animation = payload[0].animation;
        payload[0].animation = bytes.concat(animation, bytes(" "));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamOnchainContentCheckpoint.CheckpointPayloadMismatch.selector, uint256(91)
            )
        );
        checkpoint.appendCheckpointTokens(id, payload);
        require(checkpoint.checkpoint(id).nextIndex == 0, "payload atomicity");
        payload[0].animation = animation;
        entropy.setFinalized(false);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamOnchainContentCheckpoint.CheckpointPayloadMismatch.selector, uint256(91)
            )
        );
        checkpoint.appendCheckpointTokens(id, payload);
        require(checkpoint.checkpoint(id).nextIndex == 0, "entropy atomicity");
        entropy.setFinalized(true);
        checkpoint.appendCheckpointTokens(id, payload);
        require(
            checkpoint.requireCurrentCheckpoint(id).contentRoot == _leaf(id, payload[0]),
            "original payload retry"
        );
    }

    function testChunkedManifestOrBlobDriftCannotAdvanceAndRestoredPayloadRetries() public {
        _checkpointSetup();
        vm.recordLogs();
        (bytes memory script, bytes32 bundle) = _largeSelected(false);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        address pointer;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(metadata) && logs[i].topics.length == 3
                    && logs[i].topics[0]
                        == keccak256(
                            "ScriptBundleChunkStored(uint16,bytes32,uint256,bytes32,address,address)"
                        ) && logs[i].topics[1] == bundle && logs[i].topics[2] == 0
            ) {
                (uint16 schema, bytes32 hash, address first, address tail) =
                    abi.decode(logs[i].data, (uint16, bytes32, address, address));
                require(schema == 1 && hash == keccak256(script) && tail == address(0));
                pointer = first;
            }
        }
        require(pointer.code.length == script.length + 1, "actual blob from actual producer event");
        _lock();
        bytes32 id = checkpoint.beginChunkedCollectionCheckpoint(1);
        IStreamOnchainContentCheckpoint.TokenPayload[] memory payload = _payload(script);
        bytes32 manifest = metadata.scriptManifestHash(1);
        BundleMockVm v = BundleMockVm(address(vm));
        v.mockCall(
            address(metadata),
            abi.encodeCall(B.recordedScriptBundle, (manifest)),
            abi.encode(keccak256("wrong"))
        );
        vm.expectRevert();
        checkpoint.appendCheckpointTokens(id, payload);
        require(checkpoint.checkpoint(id).nextIndex == 0, "manifest drift rollback");
        v.clearMockedCalls();
        bytes memory original = pointer.code;
        vm.etch(pointer, hex"00");
        vm.expectRevert();
        checkpoint.appendCheckpointTokens(id, payload);
        require(checkpoint.checkpoint(id).nextIndex == 0, "blob drift rollback");
        vm.etch(pointer, original);
        checkpoint.appendCheckpointTokens(id, _payload(script));
        require(
            checkpoint.requireCurrentCheckpoint(id).contentRoot == _leaf(id, _payload(script)[0]),
            "identical repaired bytes"
        );
    }

    function testChunkedComponentFamiliesPinRegistryVersionWithIndependentFailure() public {
        _checkpointSetup();
        DependencyRegistry registry =
            new DependencyRegistry(address(new BundleLegacyAdminBoundary()));
        string[] memory strings_ = new string[](1);
        strings_[0] = "const version=1;";
        bytes32 key = keccak256("versions");
        registry.addDependency(key, strings_);
        bytes[] memory raw = _one(bytes(strings_[0]));
        B.Plan memory plan = _plan(raw, true, 0, M.PayloadSourceType.DEPENDENCY_REGISTRY);
        B.RegistrySource memory g = B.RegistrySource(
            address(registry),
            address(registry).codehash,
            key,
            1,
            registry.getDependencyScriptContentHashAtVersion(key, 1)
        );
        bytes32 lib = metadata.beginRegistryLibrary(plan, g);
        metadata.appendScriptBundle(lib, 0, raw[0]);
        metadata.finalizeScriptBundle(lib);
        bytes32 bundle = _publish(_one(_large()), false, lib, M.PayloadSourceType.SSTORE2);
        _select(bundle);
        _lock();
        (bool locked, bytes32 dep) = this.component(DEPENDENCY_FAMILY);
        require(locked);
        (, bytes32 sc) = this.component(SCRIPT_FAMILY);
        (, bytes32 media) = this.component(MEDIA_FAMILY);
        B.Selection memory s = router.collectionScriptBundle(1);
        bytes32 payload =
            keccak256(abi.encode(s.host, s.codeHash, lib, metadata.scriptBundle(lib), g));
        require(
            dep
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CHUNKED_ROUTER_COMPONENT_EVIDENCE_V1"),
                        block.chainid,
                        address(core),
                        address(router),
                        DEPENDENCY_FAMILY,
                        StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0),
                        payload
                    )
                ),
            "independent dependency commitment"
        );
        registry.addDependencyScriptIndex(key, 0, "const version=2;");
        (, bytes32 same) = this.component(DEPENDENCY_FAMILY);
        require(same == dep, "immutable original version");
        bytes memory original = address(registry).code;
        vm.etch(address(registry), hex"00");
        vm.expectRevert();
        this.component(DEPENDENCY_FAMILY);
        (, bytes32 sc2) = this.component(SCRIPT_FAMILY);
        (, bytes32 media2) = this.component(MEDIA_FAMILY);
        require(sc2 == sc && media2 == media, "family failures independent");
        vm.etch(address(registry), original);
        (, same) = this.component(DEPENDENCY_FAMILY);
        require(same == dep, "same version repair");
    }

    function testOriginalStableComponentHashAndStrictProfileEntryRemainExact() public {
        _checkpointSetup();
        string memory script = "oldArtwork();";
        artist.approve(1, SCRIPT, router.previewArtistScriptState(1, script), keccak256("stable"));
        router.setCollectionScript(1, script);
        _lock();
        (bool locked, bytes32 h) = this.component(SCRIPT_FAMILY);
        require(
            locked
                && h
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ROUTER_COMPONENT_EVIDENCE_V1"),
                            block.chainid,
                            address(core),
                            address(router),
                            SCRIPT_FAMILY,
                            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0),
                            keccak256(
                                abi.encode(keccak256(bytes(script)), uint32(bytes(script).length))
                            )
                        )
                    ),
            "original component bytes exact"
        );
        vm.expectRevert();
        checkpoint.beginChunkedCollectionCheckpoint(1);
        bytes32 id = checkpoint.beginCollectionCheckpoint(1);
        require(checkpoint.checkpointProfile(id) == checkpoint.PROFILE());
        checkpoint.appendCheckpointTokens(id, _payload(bytes(script)));
        require(checkpoint.requireCurrentCheckpoint(id).tokenCount == 1, "original inline recipe");
    }
}
