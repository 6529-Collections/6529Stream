// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPolicyContentRootV2.t.sol";
import {
    StreamCollectionManifestTypes as ManifestSelection
} from "../../../smart-contracts/interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import {
    StreamMetadataPolicyContentRootV2 as OldRoot
} from "../../../smart-contracts/domains/metadata/StreamMetadataPolicyContentRootV2.sol";
import { IERC165 } from "../../../smart-contracts/vendor/openzeppelin/IERC165.sol";
import {
    IStreamPreservationPolicyPublicationFactoryV1 as GraphFactory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyPublicationFactoryV1.sol";
import {
    StreamPreservationPolicyPublicationGraphTypesV1 as PublicationGraph
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationPolicyPublicationGraphTypesV1.sol";
import {
    IStreamFinalityEntropySourceFactory as EntropyFactory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import {
    StreamMetadataPreservationPolicyContentRootV1 as PreservationRoot
} from "../../../smart-contracts/domains/metadata/StreamMetadataPreservationPolicyContentRootV1.sol";
import {
    StreamMetadataScopedPreservationPolicyContentV1 as PreservationScoped
} from "../../../smart-contracts/domains/metadata/StreamMetadataScopedPreservationPolicyContentV1.sol";
import {
    StreamMetadataRouterRootCodec as OldCodec
} from "../../../smart-contracts/domains/metadata/StreamMetadataRouterRootCodec.sol";
import {
    StreamMetadataRouterContent as Content
} from "../../../smart-contracts/domains/metadata/StreamMetadataRouterContent.sol";
import {
    StreamMetadataContentRoot as Roots
} from "../../../smart-contracts/domains/metadata/StreamMetadataContentRoot.sol";
import {
    StreamMetadataScopedContentState as ScopedState
} from "../../../smart-contracts/domains/metadata/StreamMetadataScopedContentState.sol";
import {
    IStreamContentRootPublication as Root
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamContentRootPublication.sol";
import {
    IStreamScopedContentRootPublication as Scoped
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamPreservationPolicyContentRootPublicationV1 as Preservation
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPreservationPolicyContentRootPublicationV1.sol";
import {
    IStreamScopedPreservationPolicyContentRootPublicationV1 as ScopedPreservation
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicyContentRootPublicationV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as Outputs
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as Checkpoint
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamPreservationPolicyOutputEvidenceBindingV1 as PreservationProvider
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyOutputEvidenceBindingV1.sol";
import {
    IStreamPreservationPolicyPublicationGraphBindingV1 as PreservationGraph
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyPublicationGraphBindingV1.sol";
import {
    StreamPreservationPolicyContentRootSchemasV1 as RootDocuments
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyContentRootSchemasV1.sol";
import {
    StreamPreservationPolicyOutputSchemasV1 as OutputDocuments
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyOutputSchemasV1.sol";
import {
    StreamMetadataContentAuthorization as Authorization
} from "../../../smart-contracts/domains/metadata/StreamMetadataContentAuthorization.sol";

interface PreservationRootVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
    function mockCallRevert(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
    function etch(address, bytes calldata) external;
}

/// @dev Fixed worker test host, NOT the Router deployment. Compiler-owned original state roots,
/// original authorization/evolution worker and shared publication codec are executed here. Artist op17
/// signature production and complete output/snapshot validation are explicit fixture boundaries.
contract PreservationRootWorkerHost {
    address public immutable core;
    address public immutable artist;
    mapping(uint256 => StreamMetadataRouter.CollectionMetadata) private collections;
    mapping(uint256 => StreamMetadataRouter.PreparedMetadata) private prepared;
    mapping(uint256 => mapping(bytes32 => bool)) private locks;
    mapping(uint256 => bytes32) private evolutionRatification;
    mapping(uint256 => bytes32) private evolutionContent;
    mapping(bytes32 => bool) public consumedArtistContentConsent;
    mapping(uint256 => bool) private displayLocks;
    Roots.State private roots;
    mapping(uint256 => mapping(uint8 => ManifestSelection.Selection)) private selections;
    ScopedState.State private scoped;

    constructor(address c, address a) {
        core = c;
        artist = a;
    }

    function previewCollection(Root.Publication memory p, address publisher)
        external
        view
        returns (bytes32)
    {
        return OldCodec.preview(
            roots,
            scoped,
            _layout(),
            _context(),
            abi.encodeCall(
                Preservation.previewPreservationPolicyContentRootPublication, (p, publisher)
            )
        );
    }

    function publishCollection(Root.Publication memory p) external returns (bytes32 hash) {
        return OldCodec.publish(
            roots,
            scoped,
            _layout(),
            _context(),
            abi.encodeCall(Preservation.publishVerifiedPreservationPolicyContentRoot, (p))
        );
    }

    function previewOld(bytes calldata input) external view returns (bytes32) {
        return OldCodec.preview(roots, scoped, _layout(), _context(), input);
    }

    function publishOld(bytes calldata input) external returns (bytes32) {
        return OldCodec.publish(roots, scoped, _layout(), _context(), input);
    }

    function previewScoped(Scoped.Publication memory p, address publisher)
        external
        view
        returns (bytes32)
    {
        return OldCodec.preview(
            roots,
            scoped,
            _layout(),
            _context(),
            abi.encodeCall(
                ScopedPreservation.previewScopedPreservationPolicyContentRootPublication,
                (p, publisher)
            )
        );
    }

    function publishScoped(Scoped.Publication memory p) external returns (bytes32) {
        return OldCodec.publish(
            roots,
            scoped,
            _layout(),
            _context(),
            abi.encodeCall(
                ScopedPreservation.publishScopedPreservationPolicyContentRootPublication, (p)
            )
        );
    }

    function collectionContentRootHead(uint256 cid) external view returns (bytes32) {
        return roots.heads[cid];
    }

    function contentRootRecord(bytes32 key) external view returns (Root.Record memory) {
        return roots.records[key];
    }

    function binding(bytes32 key) external view returns (Preservation.Binding memory) {
        return abi.decode(
            OldCodec.read(
                roots, abi.encodeCall(Preservation.preservationPolicyContentRootBinding, (key))
            ),
            (Preservation.Binding)
        );
    }

    function oldBinding(bytes32 key) external view returns (PV.Binding memory) {
        return OldRoot.readBinding(key);
    }

    function scopedBinding(bytes32 key) external view returns (ScopedPreservation.Binding memory) {
        return abi.decode(
            OldCodec.read(
                roots,
                abi.encodeCall(ScopedPreservation.scopedPreservationPolicyContentRootBinding, (key))
            ),
            (ScopedPreservation.Binding)
        );
    }

    function scopedContentRootAggregate(uint256 cid)
        external
        view
        returns (Scoped.Aggregate memory)
    {
        return scoped.aggregates[cid];
    }

    function scopedHead(StreamFinalityScope memory scope) external view returns (bytes32) {
        return scoped.heads[ScopedState.subject(core, scope)];
    }

    function scopedRecord(bytes32 key) external view returns (Scoped.Record memory) {
        return scoped.records[key];
    }

    function family(uint256 cid) external view returns (bytes32) {
        return ScopedState.familyCurrent(core, cid, Roots.familyState(roots, core, cid));
    }

    function current(uint256 cid) external view returns (bytes32) {
        return Content.currentState(_layout(), _context(), cid);
    }

    function _context() private view returns (Content.Context memory) {
        return Content.Context(core, artist, address(this));
    }

    function _layout() private pure returns (Content.Layout memory l) {
        uint256[9] memory slots;
        assembly ("memory-safe") {
            mstore(slots, collections.slot)
            mstore(add(slots, 32), prepared.slot)
            mstore(add(slots, 64), locks.slot)
            mstore(add(slots, 96), evolutionRatification.slot)
            mstore(add(slots, 128), evolutionContent.slot)
            mstore(add(slots, 160), consumedArtistContentConsent.slot)
            mstore(add(slots, 192), displayLocks.slot)
            mstore(add(slots, 224), roots.slot)
            mstore(add(slots, 256), selections.slot)
        }
        return Content.Layout(
            slots[0], slots[1], slots[2], slots[3], slots[4], slots[5], slots[6], slots[7], slots[8]
        );
    }
}

contract PreservationCheckpointBoundary is RootCheckpointBoundary {
    constructor(address c, address r) RootCheckpointBoundary(c, r) { }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(Checkpoint).interfaceId;
    }

    function preservationPolicyProfile() external pure returns (bytes32) {
        return keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1");
    }

    function preservationOutputProfile() external pure returns (bytes32) {
        return keccak256("6529STREAM_PRESERVATION_RENDER_V1");
    }

    function entropySourceSet() external view returns (address) {
        return address(this);
    }
}

contract PreservationManifestBoundary {
    address public immutable core;
    address public immutable contentCheckpoint;
    address public immutable artifactCoverage;
    address public immutable router;
    uint8 public fault;
    bytes32 public lateConsent;

    constructor(address c, address cp, address a, address r) {
        core = c;
        contentCheckpoint = cp;
        artifactCoverage = a;
        router = r;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(Outputs).interfaceId;
    }

    function outputProfile() external pure returns (bytes32) {
        return keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1");
    }

    function change(uint8 value, bytes32 consent) external {
        fault = value;
        lateConsent = consent;
    }

    function requireCurrentManifest(bytes32 key, bytes32 artistId)
        external
        view
        returns (Outputs.Manifest memory m)
    {
        require(
            msg.sender == router && key == keccak256("verified") && artistId == keccak256("artist"),
            "exact preservation manifest caller/identity"
        );
        require(fault != 1, "current complete output unavailable");
        m.checkpointHash = keccak256("checkpoint");
        m.checkpointStateHash = keccak256("complete checkpoint");
        m.entropySourceSet = contentCheckpoint;
        m.inventoryHash = keccak256("inventory");
        m.policyChainHash = keccak256("policy chain");
        m.artifactHash = keccak256("artifact");
        m.coverageHash = keccak256("coverage");
        m.artistId = artistId;
        m.contentRoot = keccak256("preservation content root");
        m.outputRoot = keccak256("ordered complete per-row producer output");
        m.manifestHash = keccak256("manifest");
        m.scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        m.tokenCount = 2;
        m.byteLength = 2944;
        m.metadataRouter = fault == 2 ? address(0xBAD) : router;
        m.preservationProfile =
            fault == 3 ? keccak256("live profile") : keccak256("6529STREAM_PRESERVATION_RENDER_V1");
        if (fault == 4) m.scope.tokenId = 91;
        if (fault == 5) m.entropySourceSet = address(0xBAD);
        if (fault == 6) m.policyChainHash = 0;
        if (fault == 7) m.tokenCount = 0;
        if (
            lateConsent != 0
                && PreservationRootWorkerHost(router).consumedArtistContentConsent(lateConsent)
        ) m.outputRoot = keccak256("changed after consent");
    }
}

contract PreservationProviderBoundary is RootProviderBoundary {
    address public immutable preservationPolicyOutputManifest;
    bytes32 public immutable preservationPolicyOutputManifestCodeHash;

    constructor(address m, address s, address output) RootProviderBoundary(m, s, output) {
        preservationPolicyOutputManifest = output;
        preservationPolicyOutputManifestCodeHash = output.codehash;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(PreservationProvider).interfaceId;
    }
}

abstract contract PreservationRootWorkerFixture is ContentRootPublicationFixture {
    PreservationRootWorkerHost internal host;
    PreservationManifestBoundary internal preservationManifest;
    address internal preservationCheckpoint;
    address internal preservationArtifacts;
    PreservationRootVm internal constant calls =
        PreservationRootVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @dev Reuses the original real Metadata/governance/Schema/Store fixture operations; does not
    /// instantiate the actual Router, sign Artist op17, render outputs or produce finality evidence.
    function setUp() public virtual override {
        vm.warp(1000);
        core = new RootCoreBoundary();
        artist = new RootArtistBoundary(address(core));
        executor = new MetadataExecutorBoundary();
        schemas = new StreamSchemaRegistry(address(executor));
        store = StreamSchemaDocumentStore(schemas.chunkStore());
        _register(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(schemas.RAW_BYTES_DEFINITION()),
            schemas.RAW_BYTES()
        );
        StreamCollectionMetadataV1.Configuration memory c;
        c.core = address(core);
        c.executor = address(executor);
        c.schemas = address(schemas);
        c.artistRegistry = address(artist);
        c.deploymentManifestHash = keccak256("deployment");
        c.manifestHash = keccak256("manifest");
        c.manifestURI = "ipfs://metadata";
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        c.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        metadata = new StreamCollectionMetadataV1(c);
        host = new PreservationRootWorkerHost(address(core), address(artist));
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(artist));
        core.setPointer(keccak256("METADATA_ROUTER"), address(host));
        core.setPointer(keccak256("COLLECTION_METADATA"), address(metadata));
        core.setMinted(1);
        preservationCheckpoint =
            address(new PreservationCheckpointBoundary(address(core), address(host)));
        preservationArtifacts = address(new RootArtifactsBoundary(address(schemas)));
        preservationManifest = new PreservationManifestBoundary(
            address(core), preservationCheckpoint, preservationArtifacts, address(host)
        );
        provider = address(
            new PreservationProviderBoundary(
                address(metadata), address(schemas), address(preservationManifest)
            )
        );
        _selectProvider(provider);
        _grant(1, 7, address(this), true);
        _preservationDocuments();
    }

    function assertTrue(bool condition) internal pure {
        require(condition, "assert true");
    }

    function assertEq(bytes32 a, bytes32 b) internal pure {
        require(a == b, "bytes32 equality");
    }

    function assertEq(uint256 a, uint256 b) internal pure {
        require(a == b, "integer equality");
    }

    function assertEq(address a, address b) internal pure {
        require(a == b, "address equality");
    }

    function assertEq(bytes memory a, bytes memory b) internal pure {
        require(keccak256(a) == keccak256(b), "bytes equality");
    }

    function _selectProvider(address selectedProvider) internal {
        finality = new RootFinalityBoundary(
            address(core),
            address(artist),
            address(metadata),
            selectedProvider,
            preservationArtifacts
        );
        artist.configure(address(host), address(finality));
        core.setPointer(keccak256("ARTWORK_FINALITY_REGISTRY"), address(finality));
    }

    function _preservationDocuments() internal {
        string[5] memory names = [
            "STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V1",
            "STREAM_ABI_PRESERVATION_POLICY_OUTPUT_MANIFEST_V1",
            "STREAM_PRESERVATION_POLICY_TOKEN_CONTENT_LEAF_V1",
            "STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1",
            "STREAM_ABI_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1"
        ];
        for (uint256 i; i < names.length; ++i) {
            _register(
                names[i],
                (i == 1 || i == 4)
                    ? IStreamSchemaRegistry.DocumentKind.CANONICALIZATION
                    : IStreamSchemaRegistry.DocumentKind.SCHEMA,
                RootDocuments.document(keccak256(bytes(names[i]))),
                schemas.RAW_BYTES()
            );
        }
    }

    function _approvePreservation(Root.Publication memory p, bytes32 consent)
        internal
        returns (bytes32 expected)
    {
        expected = host.previewCollection(p, address(this));
        artist.approve(expected, consent);
    }

    function _invalidCollection(Root.Publication memory p) internal {
        (bool ok,) =
            address(host).staticcall(abi.encodeCall(host.previewCollection, (p, address(this))));
        assertTrue(!ok);
    }
}

contract StreamPreservationPolicyContentRootV1Test is PreservationRootWorkerFixture {
    event PreservationPolicyContentRootBindingPublished(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed recordHash,
        Preservation.Binding binding
    );

    function testCollectionRootBeforeSnapshotLiteralHashesEventsAndImmutableHistory() public {
        Root.Publication memory p = _publication();
        bytes32 consent = keccak256("original op17 approval");
        bytes32 expected = _approvePreservation(p, consent);
        vm.recordLogs();
        bytes32 key = host.publishCollection(p);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Root.Record memory r = host.contentRootRecord(key);
        Preservation.Binding memory b = host.binding(key);
        assertEq(abi.encode(b).length, 608);
        assertEq(b.metadataRouter, address(host));
        assertEq(b.preservationOutputProfile, keccak256("6529STREAM_PRESERVATION_RENDER_V1"));
        assertEq(b.outputRoot, keccak256("ordered complete per-row producer output"));
        assertEq(b.rootSchemaHash, keccak256(RootDocuments.document(RootDocuments.ROOT_SCHEMA)));
        assertEq(
            key,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1"),
                    block.chainid,
                    address(host),
                    r,
                    b
                )
            )
        );
        Root.Record memory blank = abi.decode(abi.encode(r), (Root.Record));
        blank.stateHash = 0;
        blank.artistConsent = 0;
        blank.publishedAt = 0;
        assertEq(
            r.stateHash,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_STATE_V1"),
                    block.chainid,
                    address(host),
                    blank,
                    b
                )
            )
        );
        assertEq(host.family(1), expected);
        assertEq(host.collectionContentRootHead(1), key);
        assertTrue(host.consumedArtistContentConsent(consent));
        // No snapshot contract exists in this fixture: COLLECTION publication consumes the current
        // output first. A subsequent actual snapshot must bind this original root (integration gap).
        assertEq(logs.length, 3);
        assertEq(logs[0].emitter, address(host));
        assertEq(logs[0].data, abi.encode(uint16(3), r));
        assertEq(logs[1].data, abi.encode(uint16(1), b));
        p.expectedPredecessor = key;
        preservationManifest.change(1, 0);
        _invalidCollection(p);
        assertEq(abi.encode(host.contentRootRecord(key)), abi.encode(r));
        assertEq(abi.encode(host.binding(key)), abi.encode(b));
    }

    function testCurrentManifestCanonicalRouterProfileAndScopeAreRequired() public {
        Root.Publication memory p = _publication();
        host.previewCollection(p, address(this));
        for (uint8 i = 1; i <= 7; ++i) {
            preservationManifest.change(i, 0);
            _invalidCollection(p);
            preservationManifest.change(0, 0);
            host.previewCollection(p, address(this));
        }
        bytes memory callData = abi.encodeCall(
            Outputs.requireCurrentManifest, (p.verifiedManifestRecordHash, keccak256("artist"))
        );
        vm.prank(address(host));
        Outputs.Manifest memory m = preservationManifest.requireCurrentManifest(
            p.verifiedManifestRecordHash, keccak256("artist")
        );
        bytes memory canonical = abi.encode(m);
        calls.mockCall(
            address(preservationManifest), callData, bytes.concat(canonical, bytes32(uint256(1)))
        );
        _invalidCollection(p);
        calls.clearMockedCalls();
        assembly ("memory-safe") { mstore(canonical, sub(mload(canonical), 32)) }
        calls.mockCall(address(preservationManifest), callData, canonical);
        _invalidCollection(p);
        calls.clearMockedCalls();
        host.previewCollection(p, address(this));
    }

    function testCheckpointCapabilityProfilesRuntimeAndGasCannotDowngrade() public {
        Root.Publication memory p = _publication();
        bytes[4] memory inputs = [
            abi.encodeCall(IERC165.supportsInterface, (type(Checkpoint).interfaceId)),
            abi.encodeCall(Checkpoint.preservationPolicyProfile, ()),
            abi.encodeCall(Checkpoint.preservationOutputProfile, ()),
            abi.encodeCall(Checkpoint.metadataRouter, ())
        ];
        for (uint256 i; i < inputs.length; ++i) {
            calls.mockCall(preservationCheckpoint, inputs[i], abi.encode(uint256(0)));
            _invalidCollection(p);
            calls.clearMockedCalls();
            host.previewCollection(p, address(this));
        }
        finality.setReadGas(49999);
        _invalidCollection(p);
        finality.setReadGas(type(uint256).max);
        _invalidCollection(p);
        finality.setReadGas(5000000);
        bytes memory saved = address(preservationManifest).code;
        calls.etch(address(preservationManifest), hex"60006000fd");
        _invalidCollection(p);
        calls.etch(address(preservationManifest), saved);
        host.previewCollection(p, address(this));
    }

    function testNewGraphCapabilityIsFailClosedAndNeverFallsBackToStaticOutput() public {
        Root.Publication memory p = _publication();
        bytes memory capability =
            abi.encodeCall(IERC165.supportsInterface, (type(PreservationGraph).interfaceId));
        calls.mockCall(provider, capability, abi.encode(true));
        _invalidCollection(p);
        calls.clearMockedCalls();
        calls.mockCall(provider, capability, abi.encode(uint256(2)));
        _invalidCollection(p);
        calls.clearMockedCalls();
        // Old graph/provider support does not advertise either new preservation capability.
        calls.mockCall(
            provider,
            abi.encodeCall(IERC165.supportsInterface, (type(PreservationProvider).interfaceId)),
            abi.encode(false)
        );
        _invalidCollection(p);
        calls.clearMockedCalls();
        host.previewCollection(p, address(this));
    }

    function testGraphReaderAuthenticatesRecipeScopeDomainChildrenAndCurrentInventory() public {
        // The factory is an explicit transport/validation boundary. The production graph reader
        // executes its exact pin, recipe, inventory, graph-domain and child checks here.
        address factory = address(new RootArtifactsBoundary(address(schemas)));
        address sourceFactory = address(new RootArtifactsBoundary(address(schemas)));
        PublicationGraph.Recipe memory recipe;
        recipe.inventory.chainId = block.chainid;
        recipe.inventory.targets[0] = address(core);
        recipe.inventory.targets[1] = address(metadata);
        recipe.inventory.targets[2] = address(schemas);
        recipe.inventory.targets[3] = address(store);
        recipe.inventory.targets[4] = address(host);
        for (uint256 i; i < 5; ++i) {
            recipe.inventory.codeHashes[i] = recipe.inventory.targets[i].codehash;
        }
        recipe.targets[2] = sourceFactory;
        recipe.codeHashes[2] = sourceFactory.codehash;
        recipe.factorySourceGas = 5000000;
        bytes32 recipeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRESERVATION_POLICY_PUBLICATION_FACTORY_V1"),
                block.chainid,
                recipe
            )
        );
        PreservationGraph.CollectionFactoryBinding memory binding_ =
            PreservationGraph.CollectionFactoryBinding(
                factory,
                factory.codehash,
                recipeHash,
                keccak256("source dependencies"),
                5000000,
                keccak256("original provider configuration")
            );
        PublicationGraph.Graph memory graph;
        graph.scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        graph.inventoryPlan = keccak256("current inventory plan");
        graph.sourceSet = preservationCheckpoint;
        graph.sourceSetCodeHash = preservationCheckpoint.codehash;
        graph.preparedChildren = 7;
        for (uint256 i; i < 7; ++i) {
            graph.children[i] = i == 2 ? address(preservationManifest) : preservationCheckpoint;
            graph.codeHashes[i] = graph.children[i].codehash;
        }
        graph.graphId = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRESERVATION_POLICY_PUBLICATION_GRAPH_V1"),
                block.chainid,
                factory,
                recipeHash,
                binding_.sourceFactoryDependenciesHash,
                graph.scope,
                graph.inventoryPlan,
                graph.sourceSet,
                graph.sourceSetCodeHash
            )
        );
        calls.mockCall(
            provider,
            abi.encodeCall(IERC165.supportsInterface, (type(PreservationGraph).interfaceId)),
            abi.encode(true)
        );
        calls.mockCall(
            provider,
            abi.encodeCall(PreservationGraph.collectionPreservationPolicyPublicationBinding, ()),
            abi.encode(binding_)
        );
        calls.mockCall(
            factory,
            abi.encodeCall(IERC165.supportsInterface, (type(GraphFactory).interfaceId)),
            abi.encode(true)
        );
        calls.mockCall(
            factory,
            abi.encodeCall(GraphFactory.preservationPolicyPublicationFactoryProfile, ()),
            abi.encode(PublicationGraph.PROFILE)
        );
        calls.mockCall(factory, abi.encodeCall(GraphFactory.recipeHash, ()), abi.encode(recipeHash));
        calls.mockCall(
            factory,
            abi.encodeCall(GraphFactory.sourceFactoryDependenciesHash, ()),
            abi.encode(binding_.sourceFactoryDependenciesHash)
        );
        calls.mockCall(factory, abi.encodeCall(GraphFactory.core, ()), abi.encode(address(core)));
        calls.mockCall(
            factory, abi.encodeCall(GraphFactory.metadataHost, ()), abi.encode(address(metadata))
        );
        calls.mockCall(factory, abi.encodeCall(GraphFactory.recipe, ()), abi.encode(recipe));
        bytes memory graphCall = abi.encodeCall(GraphFactory.requireCurrentGraph, (graph.scope));
        calls.mockCall(factory, graphCall, abi.encode(graph));
        calls.mockCall(
            sourceFactory,
            abi.encodeCall(EntropyFactory.currentInventoryPlan, (graph.scope)),
            abi.encode(graph.inventoryPlan)
        );
        calls.mockCall(
            sourceFactory,
            abi.encodeCall(EntropyFactory.sourceSetForPlan, (graph.inventoryPlan)),
            abi.encode(graph.sourceSet, graph.sourceSetCodeHash)
        );
        Root.Publication memory p = _publication();
        bytes32 good = host.previewCollection(p, address(this));
        for (uint256 i; i < 5; ++i) {
            PublicationGraph.Graph memory bad =
                abi.decode(abi.encode(graph), (PublicationGraph.Graph));
            if (i == 0) bad.preparedChildren = 6;
            if (i == 1) bad.scope.collectionId = 2;
            if (i == 2) bad.graphId = keccak256("old live graph domain");
            if (i == 3) bad.codeHashes[6] = keccak256("stale child runtime");
            if (i == 4) {
                bad.inventoryPlan = keccak256("superseded inventory");
                // Keep the graph commitment internally valid so the current inventory join,
                // rather than an unrelated stale graphId, is the refusing check.
                bad.graphId = keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRESERVATION_POLICY_PUBLICATION_GRAPH_V1"),
                        block.chainid,
                        factory,
                        recipeHash,
                        binding_.sourceFactoryDependenciesHash,
                        bad.scope,
                        bad.inventoryPlan,
                        bad.sourceSet,
                        bad.sourceSetCodeHash
                    )
                );
            }
            calls.mockCall(factory, graphCall, abi.encode(bad));
            _invalidCollection(p);
            calls.mockCall(factory, graphCall, abi.encode(graph));
            assertEq(host.previewCollection(p, address(this)), good);
        }
        calls.mockCall(
            factory,
            abi.encodeCall(GraphFactory.preservationPolicyPublicationFactoryProfile, ()),
            abi.encode(keccak256("6529STREAM_POLICY_PUBLICATION_FACTORY_V2"))
        );
        _invalidCollection(p);
        calls.clearMockedCalls();
        host.previewCollection(p, address(this));
    }

    function testExactSchemaRegistrationWriterAndPublisherBinding() public {
        Root.Publication memory p = _publication();
        bytes32 approved = _approvePreservation(p, keccak256("publisher approval"));
        _grant(1, 7, address(0xA11CE), true);
        assertTrue(host.previewCollection(p, address(0xA11CE)) != approved);
        vm.expectRevert(
            abi.encodeWithSelector(
                Authorization.ArtistContentAuthorizationRequired.selector, uint256(1)
            )
        );
        vm.prank(address(0xA11CE));
        host.publishCollection(p);
        _grant(1, 7, address(this), false);
        _invalidCollection(p);
        _grant(0, 8, address(this), true);
        assertTrue(host.previewCollection(p, address(this)) != approved);
        bytes32 id = RootDocuments.ROOT_SCHEMA;
        IStreamSchemaRegistry.DocumentView memory doc = schemas.document(id);
        doc.specification.contentHash = keccak256("live document under preservation name");
        calls.mockCall(address(schemas), abi.encodeCall(schemas.document, (id)), abi.encode(doc));
        _invalidCollection(p);
        calls.clearMockedCalls();
        doc = schemas.document(id);
        doc.specification.canonicalizationId = keccak256("RFC8785_JCS");
        calls.mockCall(address(schemas), abi.encodeCall(schemas.document, (id)), abi.encode(doc));
        _invalidCollection(p);
        calls.clearMockedCalls();
        _approvePreservation(p, keccak256("global replacement approval"));
        host.publishCollection(p);
    }

    function testLateReprepareRollsBackOneUseConsentAndIdenticalRetry() public {
        Root.Publication memory p = _publication();
        bytes32 consent = keccak256("retry same op17");
        _approvePreservation(p, consent);
        bytes32 beforeFamily = host.family(1);
        preservationManifest.change(0, consent);
        vm.expectRevert(abi.encodeWithSelector(Root.InvalidContentRootPublication.selector));
        host.publishCollection(p);
        assertTrue(!host.consumedArtistContentConsent(consent));
        assertEq(host.collectionContentRootHead(1), bytes32(0));
        assertEq(host.family(1), beforeFamily);
        preservationManifest.change(0, 0);
        bytes32 key = host.publishCollection(p);
        p.expectedPredecessor = key;
        artist.approve(host.previewCollection(p, address(this)), consent);
        vm.expectRevert(
            abi.encodeWithSelector(Authorization.ArtistContentConsentConsumed.selector, consent)
        );
        host.publishCollection(p);
        assertEq(host.collectionContentRootHead(1), key);
    }

    function testOldV2PreservationOldV2ShareHistoryAndRejectCrossProfileEvidence() public {
        string[5] memory names = [
            "STREAM_POLICY_OUTPUT_MANIFEST_V2",
            "STREAM_ABI_POLICY_OUTPUT_MANIFEST_V2",
            "STREAM_POLICY_TOKEN_CONTENT_LEAF_V2",
            "STREAM_POLICY_CONTENT_ROOT_RECORD_V2",
            "STREAM_ABI_POLICY_CONTENT_ROOT_RECORD_V2"
        ];
        for (uint256 i; i < names.length; ++i) {
            _register(
                names[i],
                (i == 1 || i == 4)
                    ? IStreamSchemaRegistry.DocumentKind.CANONICALIZATION
                    : IStreamSchemaRegistry.DocumentKind.SCHEMA,
                RD.document(keccak256(bytes(names[i]))),
                schemas.RAW_BYTES()
            );
        }
        PolicyRootManifestBoundary old = new PolicyRootManifestBoundary(
            address(core), preservationCheckpoint, preservationArtifacts, address(host)
        );
        address legacy = address(
            new RootManifestBoundary(address(core), preservationCheckpoint, preservationArtifacts)
        );
        address oldProvider = address(
            new PolicyRootProviderBoundary(
                address(metadata), address(schemas), legacy, address(old)
            )
        );
        Root.Publication memory p = _publication();
        _selectProvider(oldProvider);
        _invalidCollection(p);
        bytes32 oldFirst = _publishV2(p, keccak256("old first"));
        Root.Record memory retained = host.contentRootRecord(oldFirst);
        _selectProvider(provider);
        p.expectedPredecessor = oldFirst;
        (bool ok,) = address(host)
            .staticcall(
                abi.encodeCall(
                    host.previewOld,
                    (abi.encodeCall(PV.previewPolicyContentRootPublication, (p, address(this))))
                )
            );
        assertTrue(!ok);
        _approvePreservation(p, keccak256("preservation middle"));
        bytes32 middle = host.publishCollection(p);
        assertEq(host.binding(oldFirst).profileId, bytes32(0));
        assertEq(host.oldBinding(middle).profileId, bytes32(0));
        _selectProvider(oldProvider);
        p.expectedPredecessor = middle;
        bytes32 last = _publishV2(p, keccak256("old last"));
        assertEq(host.contentRootRecord(last).publication.expectedPredecessor, middle);
        assertEq(host.contentRootRecord(middle).publication.expectedPredecessor, oldFirst);
        assertEq(abi.encode(host.contentRootRecord(oldFirst)), abi.encode(retained));
    }

    function _publishV2(Root.Publication memory p, bytes32 consent) private returns (bytes32) {
        artist.approve(
            host.previewOld(
                abi.encodeCall(PV.previewPolicyContentRootPublication, (p, address(this)))
            ),
            consent
        );
        return host.publishOld(abi.encodeCall(PV.publishVerifiedPolicyContentRoot, (p)));
    }
}
