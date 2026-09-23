// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamPreservationPolicyContentRootV1.t.sol";
import {
    StreamPreservationPolicyContentRootSchemasV2 as V2Docs
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyContentRootSchemasV2.sol";
import {
    StreamPreservationPolicyRootFamiliesV2 as Families
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyRootFamiliesV2.sol";
import {
    StreamCurrentAuthorityPreservationPolicyPublicationTypesV1 as Current
} from "../../../smart-contracts/interfaces/stream/finality/StreamCurrentAuthorityPreservationPolicyPublicationTypesV1.sol";
import {
    IStreamCurrentAuthorityPreservationPolicyPublicationFactoryV1 as CurrentFactory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamCurrentAuthorityPreservationPolicyPublicationFactoryV1.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../../smart-contracts/interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";

/// @dev Explicit validated checkpoint/output boundaries, not actual token rendering or admission.
contract PreservationCheckpointV2Boundary is RootCheckpointBoundary {
    constructor(address c, address r) RootCheckpointBoundary(c, r) { }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(Checkpoint).interfaceId;
    }

    function preservationPolicyProfile() external pure returns (bytes32) {
        return keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_CHECKPOINT_V2");
    }

    function preservationOutputProfile() external pure returns (bytes32) {
        return Families.V2;
    }

    function entropySourceSet() external view returns (address) {
        return address(this);
    }
}

contract PreservationManifestV2Boundary {
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
        return keccak256("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2");
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
        m.preservationProfile = fault == 3 ? keccak256("live profile") : Families.V2;
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

/// @notice Executes the actual shared root codec, consent/state workers, and registered definitions.
/// @dev The factory transport and already-validated manifest are explicit boundaries; these cases
/// do not establish actual factory creation, Artist signatures, producer admission, or finality.
contract StreamPreservationPolicyContentRootV2Test is PreservationRootWorkerFixture {
    PreservationManifestV2Boundary private v2Manifest;
    address private legacyProvider;
    address private v2Provider;

    function setUp() public override {
        super.setUp();
        legacyProvider = provider;
        preservationCheckpoint =
            address(new PreservationCheckpointV2Boundary(address(core), address(host)));
        v2Manifest = new PreservationManifestV2Boundary(
            address(core), preservationCheckpoint, preservationArtifacts, address(host)
        );
        provider = address(
            new PreservationProviderBoundary(
                address(metadata), address(schemas), address(v2Manifest)
            )
        );
        v2Provider = provider;
        _selectProvider(provider);
        string[4] memory names = [
            "STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2",
            "STREAM_ABI_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2",
            "STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2",
            "STREAM_ABI_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2"
        ];
        for (uint256 i; i < names.length; ++i) {
            _register(
                names[i],
                i % 2 == 1
                    ? IStreamSchemaRegistry.DocumentKind.CANONICALIZATION
                    : IStreamSchemaRegistry.DocumentKind.SCHEMA,
                V2Docs.document(keccak256(bytes(names[i]))),
                schemas.RAW_BYTES()
            );
        }
        _installGraph();
    }

    function _installGraph() private {
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
        O.Dependencies memory origin;
        D.Dependencies memory authority;
        bytes32 recipeHash = Current.recipeHash(block.chainid, recipe, origin, authority);
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
            graph.children[i] = i == 2 ? address(v2Manifest) : preservationCheckpoint;
            graph.codeHashes[i] = graph.children[i].codehash;
        }
        graph.graphId = keccak256(
            abi.encode(
                Current.GRAPH_DOMAIN,
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
            abi.encode(Current.FACTORY_PROFILE)
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
        calls.mockCall(
            factory,
            abi.encodeCall(IERC165.supportsInterface, (type(CurrentFactory).interfaceId)),
            abi.encode(true)
        );
        calls.mockCall(
            factory, abi.encodeCall(CurrentFactory.originDependencies, ()), abi.encode(origin)
        );
        calls.mockCall(
            factory, abi.encodeCall(CurrentFactory.authorityDependencies, ()), abi.encode(authority)
        );
    }

    function testV2RootUsesExactDomainsBindingEventAndImmutableHistory() public {
        Root.Publication memory p = _publication();
        bytes32 consent = keccak256("original op17 approval");
        bytes32 expected = _approvePreservation(p, consent);
        vm.recordLogs();
        bytes32 key = host.publishCollection(p);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Root.Record memory r = host.contentRootRecord(key);
        Preservation.Binding memory b = host.binding(key);
        assertEq(abi.encode(b).length, 608);
        assertEq(b.profileId, V2Docs.PROFILE);
        assertEq(b.metadataRouter, address(host));
        assertEq(b.preservationOutputProfile, Families.V2);
        assertEq(b.outputRoot, keccak256("ordered complete per-row producer output"));
        assertEq(b.rootSchemaHash, keccak256(V2Docs.document(V2Docs.ROOT_SCHEMA)));
        assertEq(
            key,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2"),
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
                    keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_STATE_V2"),
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
        assertEq(logs[1].data, abi.encode(uint16(2), b));
        p.expectedPredecessor = key;
        v2Manifest.change(1, 0);
        _invalidCollection(p);
        assertEq(abi.encode(host.contentRootRecord(key)), abi.encode(r));
        assertEq(abi.encode(host.binding(key)), abi.encode(b));
    }

    function testV2LateReprepareRollsBackOneUseConsentAndIdenticalRetry() public {
        Root.Publication memory p = _publication();
        bytes32 consent = keccak256("retry same op17");
        _approvePreservation(p, consent);
        bytes32 beforeFamily = host.family(1);
        v2Manifest.change(0, consent);
        vm.expectRevert(abi.encodeWithSelector(Root.InvalidContentRootPublication.selector));
        host.publishCollection(p);
        assertTrue(!host.consumedArtistContentConsent(consent));
        assertEq(host.collectionContentRootHead(1), bytes32(0));
        assertEq(host.family(1), beforeFamily);
        v2Manifest.change(0, 0);
        bytes32 key = host.publishCollection(p);
        p.expectedPredecessor = key;
        artist.approve(host.previewCollection(p, address(this)), consent);
        vm.expectRevert(
            abi.encodeWithSelector(Authorization.ArtistContentConsentConsumed.selector, consent)
        );
        host.publishCollection(p);
        assertEq(host.collectionContentRootHead(1), key);
    }

    function testV2RejectsLegacyUnknownViewAndMixedCheckpointHeaders() public {
        Root.Publication memory p = _publication();
        bytes32 good = host.previewCollection(p, address(this));
        bytes32[3] memory bad =
            [Families.V1, bytes32(0), keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_V1")];
        for (uint256 i; i < bad.length; ++i) {
            calls.mockCall(
                preservationCheckpoint,
                abi.encodeCall(Checkpoint.preservationOutputProfile, ()),
                abi.encode(bad[i])
            );
            _invalidCollection(p);
        }
        calls.mockCall(
            preservationCheckpoint,
            abi.encodeCall(Checkpoint.preservationOutputProfile, ()),
            abi.encode(Families.V2)
        );
        assertEq(host.previewCollection(p, address(this)), good);
        calls.mockCall(
            preservationCheckpoint,
            abi.encodeCall(Checkpoint.preservationPolicyProfile, ()),
            abi.encode(Families.checkpointProfile(Families.V1, false))
        );
        _invalidCollection(p);
        calls.mockCall(
            preservationCheckpoint,
            abi.encodeCall(Checkpoint.preservationPolicyProfile, ()),
            abi.encode(Families.checkpointProfile(Families.V2, false))
        );
        calls.mockCall(
            address(v2Manifest),
            abi.encodeCall(Outputs.outputProfile, ()),
            abi.encode(Families.outputProfile(Families.V1, false))
        );
        _invalidCollection(p);
        calls.mockCall(
            address(v2Manifest),
            abi.encodeCall(Outputs.outputProfile, ()),
            abi.encode(Families.outputProfile(Families.V2, false))
        );
        v2Manifest.change(3, 0);
        _invalidCollection(p);
        v2Manifest.change(0, 0);
        assertEq(host.previewCollection(p, address(this)), good);
        calls.mockCall(
            provider,
            abi.encodeCall(IERC165.supportsInterface, (type(PreservationGraph).interfaceId)),
            abi.encode(false)
        );
        _invalidCollection(p);
    }

    function testV2RequiresExactGovernedDefinitionsAndPublisherConsent() public {
        Root.Publication memory p = _publication();
        bytes32 consent = keccak256("V2 publisher");
        bytes32 approved = _approvePreservation(p, consent);
        _grant(1, 7, address(0xA11CE), true);
        assertTrue(host.previewCollection(p, address(0xA11CE)) != approved);
        vm.expectRevert(
            abi.encodeWithSelector(
                Authorization.ArtistContentAuthorizationRequired.selector, uint256(1)
            )
        );
        vm.prank(address(0xA11CE));
        host.publishCollection(p);
        IStreamSchemaRegistry.DocumentView memory doc = schemas.document(V2Docs.ROOT_SCHEMA);
        doc.specification.contentHash = keccak256(RootDocuments.document(RootDocuments.ROOT_SCHEMA));
        calls.mockCall(
            address(schemas),
            abi.encodeCall(schemas.document, (V2Docs.ROOT_SCHEMA)),
            abi.encode(doc)
        );
        _invalidCollection(p);
        assertTrue(!host.consumedArtistContentConsent(consent));
        assertEq(host.collectionContentRootHead(1), bytes32(0));
    }

    function testV1AndV2RootsShareOriginalHistoryWithoutReinterpretingBindings() public {
        Root.Publication memory p = _publication();
        _selectProvider(legacyProvider);
        _approvePreservation(p, keccak256("V1 first"));
        bytes32 first = host.publishCollection(p);
        Root.Record memory saved = host.contentRootRecord(first);
        Preservation.Binding memory savedBinding = host.binding(first);
        assertEq(savedBinding.profileId, RootDocuments.PROFILE);
        _selectProvider(v2Provider);
        p.expectedPredecessor = first;
        _approvePreservation(p, keccak256("V2 middle"));
        bytes32 middle = host.publishCollection(p);
        assertEq(host.binding(middle).profileId, V2Docs.PROFILE);
        _selectProvider(legacyProvider);
        p.expectedPredecessor = middle;
        _approvePreservation(p, keccak256("V1 last"));
        bytes32 last = host.publishCollection(p);
        assertEq(host.binding(last).profileId, RootDocuments.PROFILE);
        assertEq(host.contentRootRecord(last).publication.expectedPredecessor, middle);
        assertEq(host.contentRootRecord(middle).publication.expectedPredecessor, first);
        assertEq(abi.encode(host.contentRootRecord(first)), abi.encode(saved));
        assertEq(abi.encode(host.binding(first)), abi.encode(savedBinding));
    }
}
