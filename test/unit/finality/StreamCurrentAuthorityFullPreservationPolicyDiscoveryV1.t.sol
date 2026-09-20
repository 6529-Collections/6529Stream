// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamFinalityLineageDiscovery.t.sol";
import {
    StreamCurrentAuthorityFullPreservationPolicyDiscoveryV1 as ScopedDiscovery
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityFullPreservationPolicyDiscoveryV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyDiscoveryFactoryReadsV1 as FactoryReads
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedPreservationPolicyDiscoveryFactoryReadsV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyPublicationGraphReadsV1 as GraphReads
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedPreservationPolicyPublicationGraphReadsV1.sol";
import {
    IStreamScopedPreservationPolicyPublicationFactoryV1 as BaseFactory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPreservationPolicyPublicationFactoryV1.sol";
import {
    IStreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1 as CurrentFactory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1.sol";
import {
    IStreamScopedPreservationPolicyPublicationEvidenceBindingV1 as FactoryBinding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPreservationPolicyPublicationEvidenceBindingV1.sol";
import {
    StreamScopedPreservationPolicyPublicationGraphTypesV1 as Graph
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopedPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyPublicationTypesV1 as CurrentGraph
} from "../../../smart-contracts/interfaces/stream/finality/StreamCurrentAuthorityScopedPreservationPolicyPublicationTypesV1.sol";
import {
    StreamArtistArchiveOriginTypes as Origin
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as Capture
} from "../../../smart-contracts/interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamScopedPreservationPolicySnapshotDefinitionsV1 as ScopedDefinitions
} from "../../../smart-contracts/domains/records/StreamScopedPreservationPolicySnapshotDefinitionsV1.sol";
import {
    IStreamGasParameterHost as Gas
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";

import {
    IStreamFinalityPreservationFactoryProfileSourcesV1 as Catalogue
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityPreservationFactoryProfileSourcesV1.sol";
import {
    StreamCurrentAuthorityPreservationPolicyDiscoveryFactoryReadsV1 as CollectionReads
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityPreservationPolicyDiscoveryFactoryReadsV1.sol";
import {
    StreamCurrentAuthorityPreservationPolicyPublicationGraphReadsV1 as CollectionGraphReads
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityPreservationPolicyPublicationGraphReadsV1.sol";
import {
    StreamCurrentAuthorityPreservationPolicyPublicationTypesV1 as CollectionDomains
} from "../../../smart-contracts/interfaces/stream/finality/StreamCurrentAuthorityPreservationPolicyPublicationTypesV1.sol";
import {
    StreamPreservationPolicyPublicationGraphTypesV1 as CollectionGraph
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationPolicyPublicationGraphTypesV1.sol";
import {
    IStreamCurrentAuthorityPreservationPolicyPublicationFactoryV1 as CurrentCollectionFactory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamCurrentAuthorityPreservationPolicyPublicationFactoryV1.sol";
import {
    IStreamPreservationPolicyPublicationFactoryV1 as CollectionFactory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyPublicationFactoryV1.sol";
import {
    IStreamPreservationPolicyPublicationGraphBindingV1 as CollectionBinding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyPublicationGraphBindingV1.sol";
import {
    StreamPreservationPolicySnapshotDefinitionsV1 as CollectionDefinitions
} from "../../../smart-contracts/domains/records/StreamPreservationPolicySnapshotDefinitionsV1.sol";

interface PreservationLineageVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
}

contract PreservationLineageFactoryReadsHarness {
    function validate(
        StreamFinalityDiscoveryTypes.Configuration memory c,
        FactoryBinding.FactoryBinding memory b
    ) external view returns (address, bytes32) {
        return FactoryReads.validate(c, b);
    }

    function current(
        FactoryBinding.FactoryBinding memory b,
        address e,
        bytes32 hash,
        StreamFinalityScope memory scope
    ) external view returns (Profiles.Profile memory) {
        return FactoryReads.current(b, e, hash, scope);
    }
}

/// @dev Production discovery and both FactoryReads execute against explicit typed provider,
/// factory, Core and Finality tables. Both GraphReads.bindings(r,od,ad,false) calls are mocked at
/// their exact linked-library ABIs. No actual provider host, factory deployment, current authority
/// ancestry, source publication, producer admission or complete inventory/finality is claimed.
/// Recipe validation, canonical getters, graph IDs, reference pins, original profile semantics,
/// Core selection and current sanction route checks are real. No 55/60 or gas claim is made.
contract StreamCurrentAuthorityFullPreservationPolicyDiscoveryV1Test is LineageDiscoveryFixture {
    PreservationLineageVm private constant scopedVm =
        PreservationLineageVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    ScopedDiscovery private scoped;
    PreservationLineageFactoryReadsHarness private factoryReads;
    FactoryBinding.FactoryBinding private binding;
    Graph.Recipe private recipe;
    Origin.Dependencies private origin;
    Capture.Dependencies private capture;
    CollectionBinding.CollectionFactoryBinding private collectionBinding;
    CollectionGraph.Recipe private collectionRecipe;
    Profiles.Profile[2] private catalog;
    Profiles.Profile private selected;
    Graph.Graph private graph;
    bytes32 private constant SOURCES = keccak256("explicit fixed source catalog");

    function setUp() public override {
        super.setUp();
        c.readGas = 500000;
        c.componentGas = 8000000;
        c.entropyGas = 4000000;
        factoryReads = new PreservationLineageFactoryReadsHarness();
        _catalog();
        _factory();
        _collectionFactory();
        scoped = new ScopedDiscovery(c, SOURCES, collectionBinding, binding);
        _address(c.finalityRegistry, "finalityDiscovery()", address(scoped));
    }

    function _catalog() private {
        address snapshots = IStreamFinalityDiscoverySources(c.provider).snapshotHost();
        _address(snapshots, "core()", c.core);
        _address(snapshots, "metadataHost()", c.metadata);
        _support(c.provider, type(Catalogue).interfaceId);
        _put(
            c.provider,
            abi.encodeCall(Catalogue.preservationFactorySourceProfile, ()),
            abi.encode(
                keccak256("6529STREAM_CURRENT_AUTHORITY_PRESERVATION_FACTORY_PROFILE_SOURCES_V1")
            )
        );
        _put(
            c.provider,
            abi.encodeCall(Profiles.finalitySourceConfigurationHash, ()),
            abi.encode(SOURCES)
        );
        for (uint8 i; i < 2; ++i) {
            catalog[i] = Profiles.Profile(
                ProfileReads.profileHash(i),
                c.referenceRender,
                c.referenceRender.codehash,
                snapshots,
                snapshots.codehash,
                c.entropyFactory,
                c.entropyFactory.codehash,
                keccak256(abi.encode("catalog", i))
            );
            _put(
                c.provider,
                abi.encodeCall(Profiles.finalitySourceProfile, (i)),
                abi.encode(catalog[i])
            );
        }
        selected = catalog[0];
        _source();
    }

    function _factory() private {
        address target = _new();
        origin = Origin.Dependencies(_new(), bytes32(0), 6000000, Origin.PROFILE);
        origin.workerCodeHash = origin.worker.codehash;
        // Predicted late resolver: no code or getter exists here. Only structural constructor
        // graph admission is mocked; operative resolver proof belongs to the real graph cohort.
        capture = Capture.Dependencies(
            address(0xD311), keccak256("predicted resolver runtime"), 16000000
        );
        Graph.Recipe memory r;
        for (uint256 i; i < 12; ++i) {
            if (i == 5 || i == 6) continue;
            r.inventory.targets[i] = _new();
            r.inventory.codeHashes[i] = r.inventory.targets[i].codehash;
        }
        r.inventory.targets[0] = c.core;
        r.inventory.targets[1] = c.metadata;
        r.inventory.targets[4] = c.router;
        r.inventory.codeHashes[0] = c.core.codehash;
        r.inventory.codeHashes[1] = c.metadata.codehash;
        r.inventory.codeHashes[4] = c.router.codehash;
        for (uint256 i; i < 5; ++i) {
            r.inventory.artistTargets[i] = i == 0 ? c.artist : _new();
            r.inventory.artistCodeHashes[i] = r.inventory.artistTargets[i].codehash;
        }
        r.inventory.artistContentOwner = _new();
        r.inventory.artistContentOwnerCodeHash = r.inventory.artistContentOwner.codehash;
        r.inventory.chainId = block.chainid;
        r.inventory.readGas = 500000;
        r.inventory.sourceGas = 4000000;
        r.inventory.selectionGas = 4000000;
        r.inventory.snapshotGas = 4000000;
        r.inventory.referenceGas = 4000000;
        r.targets = [c.membership, _new(), c.entropyFactory, _new()];
        for (uint256 i; i < 4; ++i) {
            r.codeHashes[i] = r.targets[i].codehash;
        }
        r.readinessReadGas = 500000;
        r.readinessSourceGas = 4000000;
        r.factorySourceGas = 4000000;
        r.bundleReadGas = 500000;
        r.bundleArchiveGas = 4000000;
        r.checkpointGas[0] = _gas("STATIC_CONTENT_READ_GAS", 2);
        r.checkpointGas[1] = _gas("STATIC_CONTENT_RENDER_GAS", 2);
        r.outputGas = _gas("STATIC_OUTPUT_MANIFEST_READ_GAS", 2);
        r.snapshotGas[0] = _gas("SCOPED_POLICY_SNAPSHOT_READ_GAS", 2);
        r.snapshotGas[1] = _gas("SCOPED_POLICY_SNAPSHOT_SOURCE_GAS", 2);
        r.snapshotGas[2] = _gas("SCOPED_POLICY_SNAPSHOT_INVENTORY_GAS", 2);
        r.referenceGas[0] = _gas("SCOPED_POLICY_REFERENCE_READ_GAS", 1);
        r.referenceGas[1] = _gas("SCOPED_POLICY_REFERENCE_SOURCE_GAS", 1);
        r.referenceGas[2] = _gas("SCOPED_POLICY_REFERENCE_SNAPSHOT_GAS", 1);
        r.referenceGas[3] = _gas("SCOPED_POLICY_REFERENCE_ARCHIVE_GAS", 1);
        recipe = r;
        binding = FactoryBinding.FactoryBinding({
            factory: target,
            factoryCodeHash: target.codehash,
            recipeHash: CurrentGraph.recipeHash(block.chainid, r, origin, capture),
            sourceFactoryDependenciesHash: keccak256("exact underlying source dependencies"),
            graphGas: 4000000,
            configurationHash: keccak256("fixed provider scoped graph configuration")
        });
        _support(target, type(BaseFactory).interfaceId);
        _support(target, type(CurrentFactory).interfaceId);
        _support(c.provider, type(FactoryBinding).interfaceId);
        _put(
            c.provider,
            abi.encodeCall(FactoryBinding.scopedPreservationPolicyPublicationBinding, ()),
            abi.encode(binding)
        );
        _put(
            target,
            abi.encodeCall(BaseFactory.scopedPreservationPolicyPublicationFactoryProfile, ()),
            abi.encode(CurrentGraph.FACTORY_PROFILE)
        );
        _put(target, abi.encodeCall(BaseFactory.recipeHash, ()), abi.encode(binding.recipeHash));
        _put(
            target,
            abi.encodeCall(BaseFactory.sourceFactoryDependenciesHash, ()),
            abi.encode(binding.sourceFactoryDependenciesHash)
        );
        _put(target, abi.encodeCall(BaseFactory.recipe, ()), abi.encode(r));
        _put(target, abi.encodeCall(CurrentFactory.originDependencies, ()), abi.encode(origin));
        _put(target, abi.encodeCall(CurrentFactory.authorityDependencies, ()), abi.encode(capture));
        _address(target, "core()", c.core);
        _address(target, "metadataHost()", c.metadata);
        _address(target, "entropySourceFactory()", c.entropyFactory);
        scopedVm.mockCall(
            address(GraphReads),
            abi.encodeWithSelector(GraphReads.bindings.selector, r, origin, capture, false),
            abi.encode(binding.sourceFactoryDependenciesHash)
        );
    }

    function _collectionFactory() private {
        // Recipe field shapes are shared; gas-name changes are explicit and validated by
        // the actual COLLECTION Recipe kernel. No source/output/receipt is cast.
        CollectionGraph.Recipe memory r = abi.decode(abi.encode(recipe), (CollectionGraph.Recipe));
        r.snapshotGas[0].name = "POLICY_SNAPSHOT_READ_GAS";
        r.snapshotGas[1].name = "POLICY_SNAPSHOT_SOURCE_GAS";
        r.snapshotGas[2].name = "POLICY_SNAPSHOT_INVENTORY_GAS";
        r.referenceGas[0].name = "POLICY_REFERENCE_READ_GAS";
        r.referenceGas[1].name = "POLICY_REFERENCE_SOURCE_GAS";
        r.referenceGas[2].name = "POLICY_REFERENCE_SNAPSHOT_GAS";
        r.referenceGas[3].name = "POLICY_REFERENCE_ARCHIVE_GAS";
        collectionRecipe = r;
        address target = _new();
        collectionBinding = CollectionBinding.CollectionFactoryBinding(
            target,
            target.codehash,
            CollectionDomains.recipeHash(block.chainid, r, origin, capture),
            keccak256("collection entropy dependencies"),
            4000000,
            keccak256("collection configuration")
        );
        _support(target, type(CollectionFactory).interfaceId);
        _support(target, type(CurrentCollectionFactory).interfaceId);
        _support(c.provider, type(CollectionBinding).interfaceId);
        _put(
            c.provider,
            abi.encodeCall(CollectionBinding.collectionPreservationPolicyPublicationBinding, ()),
            abi.encode(collectionBinding)
        );
        _put(
            target,
            abi.encodeCall(CollectionFactory.preservationPolicyPublicationFactoryProfile, ()),
            abi.encode(CollectionDomains.FACTORY_PROFILE)
        );
        _put(
            target,
            abi.encodeCall(CollectionFactory.recipeHash, ()),
            abi.encode(collectionBinding.recipeHash)
        );
        _put(
            target,
            abi.encodeCall(CollectionFactory.sourceFactoryDependenciesHash, ()),
            abi.encode(collectionBinding.sourceFactoryDependenciesHash)
        );
        _put(target, abi.encodeCall(CollectionFactory.recipe, ()), abi.encode(r));
        _put(
            target,
            abi.encodeCall(CurrentCollectionFactory.originDependencies, ()),
            abi.encode(origin)
        );
        _put(
            target,
            abi.encodeCall(CurrentCollectionFactory.authorityDependencies, ()),
            abi.encode(capture)
        );
        _address(target, "core()", c.core);
        _address(target, "metadataHost()", c.metadata);
        _address(target, "entropySourceFactory()", c.entropyFactory);
        scopedVm.mockCall(
            address(CollectionGraphReads),
            abi.encodeWithSelector(
                CollectionGraphReads.bindings.selector, r, origin, capture, false
            ),
            abi.encode(collectionBinding.sourceFactoryDependenciesHash)
        );
    }

    function _collectionGraphId(CollectionGraph.Graph memory g) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                CollectionDomains.GRAPH_DOMAIN,
                block.chainid,
                collectionBinding.factory,
                collectionBinding.recipeHash,
                collectionBinding.sourceFactoryDependenciesHash,
                g.scope,
                g.inventoryPlan,
                g.sourceSet,
                g.sourceSetCodeHash
            )
        );
    }

    function testCollectionFactoryProfileAndCapabilityCannotBorrowScopedRecipe() public {
        _put(
            collectionBinding.factory,
            abi.encodeCall(CollectionFactory.preservationPolicyPublicationFactoryProfile, ()),
            abi.encode(CurrentGraph.FACTORY_PROFILE)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                CollectionReads.DiscoveryConfiguration.selector, collectionBinding.factory
            )
        );
        this.collectionValidation();
        _put(
            collectionBinding.factory,
            abi.encodeCall(CollectionFactory.preservationPolicyPublicationFactoryProfile, ()),
            abi.encode(CollectionDomains.FACTORY_PROFILE)
        );
        Capture.Dependencies memory changed = capture;
        changed.resolverGas += 1;
        _put(
            collectionBinding.factory,
            abi.encodeCall(CurrentCollectionFactory.authorityDependencies, ()),
            abi.encode(changed)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                CollectionReads.DiscoveryConfiguration.selector, collectionBinding.factory
            )
        );
        this.collectionValidation();
    }

    function collectionValidation() external view {
        CollectionReads.validate(c, collectionBinding);
    }

    function testCollectionGraphUsesItsExactOriginalFactoryAndCurrentSanction() public {
        CollectionGraph.Graph memory g;
        g.scope = scope;
        g.inventoryPlan = keccak256("collection exact plan");
        g.sourceSet = _new();
        g.sourceSetCodeHash = g.sourceSet.codehash;
        for (uint256 i; i < 7; ++i) {
            g.children[i] = _new();
            g.codeHashes[i] = g.children[i].codehash;
        }
        g.preparedChildren = 7;
        g.graphId = _collectionGraphId(g);
        _put(
            collectionBinding.factory,
            abi.encodeCall(CollectionFactory.requireCurrentGraph, (scope)),
            abi.encode(g)
        );
        selected = Profiles.Profile(
            CollectionDefinitions.PROFILE_HASH,
            g.children[4],
            g.codeHashes[4],
            g.children[3],
            g.codeHashes[3],
            c.entropyFactory,
            c.entropyFactory.codehash,
            collectionBinding.configurationHash
        );
        _source();
        _staticServing(true);
        _sign();
        _support(g.children[4], type(IStreamArtworkFinalityComponent).interfaceId);
        _support(g.children[4], type(IStreamArtworkScopedFinalityComponent).interfaceId);
        _address(g.children[3], "core()", c.core);
        _address(g.children[3], "metadataHost()", c.metadata);
        _address(g.children[4], "core()", c.core);
        _address(g.children[4], "metadataHost()", c.metadata);
        _address(g.children[4], "metadataRouter()", c.router);
        _address(g.children[4], "snapshots()", g.children[3]);
        _record(g.children[4], keccak256("REFERENCE_RENDER"), true);
        _assertCurrent();
        g.graphId = keccak256(
            abi.encode(
                CurrentGraph.GRAPH_DOMAIN,
                block.chainid,
                collectionBinding.factory,
                collectionBinding.recipeHash,
                collectionBinding.sourceFactoryDependenciesHash,
                g.scope,
                g.inventoryPlan,
                g.sourceSet,
                g.sourceSetCodeHash
            )
        );
        _put(
            collectionBinding.factory,
            abi.encodeCall(CollectionFactory.requireCurrentGraph, (scope)),
            abi.encode(g)
        );
        vm.expectRevert(
            abi.encodeWithSelector(CollectionReads.DiscoveryUnsupportedProfile.selector)
        );
        scoped.finalityComponentCount(1);
    }

    function testNewCatalogueMarkerCannotBeReplacedByOriginalFixedArtistProvider() public {
        _put(
            c.provider,
            abi.encodeCall(Catalogue.preservationFactorySourceProfile, ()),
            abi.encode(keccak256("6529STREAM_FINALITY_PRESERVATION_FACTORY_PROFILE_SOURCES_V1"))
        );
        vm.expectRevert(
            abi.encodeWithSelector(ScopedDiscovery.DiscoveryConfiguration.selector, c.provider)
        );
        new ScopedDiscovery(c, SOURCES, collectionBinding, binding);
    }

    function _gas(string memory name, uint8 failure)
        private
        pure
        returns (Gas.GasParameterConfig memory)
    {
        return Gas.GasParameterConfig(name, 500000, 500000, failure);
    }

    function _source() private {
        _put(
            c.provider,
            abi.encodeCall(Profiles.finalitySourcesForScope, (scope)),
            abi.encode(Profiles.Sources(scope, selected))
        );
    }

    function _graphValue() private {
        _put(
            binding.factory,
            abi.encodeCall(BaseFactory.requireCurrentGraph, (scope)),
            abi.encode(graph)
        );
    }

    function _graphId(Graph.Graph memory g) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                CurrentGraph.GRAPH_DOMAIN,
                block.chainid,
                binding.factory,
                binding.recipeHash,
                binding.sourceFactoryDependenciesHash,
                g.scope,
                g.inventoryPlan,
                g.sourceSet,
                g.sourceSetCodeHash
            )
        );
    }

    function _dynamicScope() private {
        scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 42, 0);
        graph.scope = scope;
        graph.inventoryPlan = keccak256("actual graph boundary plan");
        graph.sourceSet = _new();
        graph.sourceSetCodeHash = graph.sourceSet.codehash;
        for (uint256 i; i < 7; ++i) {
            graph.children[i] = _new();
            graph.codeHashes[i] = graph.children[i].codehash;
        }
        graph.preparedChildren = 7;
        graph.graphId = _graphId(graph);
        _graphValue();
        selected = Profiles.Profile(
            ScopedDefinitions.PROFILE_HASH,
            graph.children[4],
            graph.codeHashes[4],
            graph.children[3],
            graph.codeHashes[3],
            c.entropyFactory,
            c.entropyFactory.codehash,
            binding.configurationHash
        );
        _source();
        StreamScopeMembershipFacts memory members;
        members.scopeSubject = StreamMetadataSubjects.scopeSubject(block.chainid, c.core, scope);
        members.membershipHash = keccak256("one exact token");
        members.tokenCount = 1;
        _put(
            c.membership,
            abi.encodeCall(IStreamFinalityScopeMembership.requireScopeMembership, (scope)),
            abi.encode(members)
        );
        _staticServing(true);
        _address(graph.children[3], "core()", c.core);
        _address(graph.children[3], "metadataHost()", c.metadata);
        _address(graph.children[4], "core()", c.core);
        _address(graph.children[4], "metadataHost()", c.metadata);
        _address(graph.children[4], "metadataRouter()", c.router);
        _address(graph.children[4], "snapshots()", graph.children[3]);
        _support(graph.children[4], type(IStreamArtworkScopedFinalityComponent).interfaceId);
        _support(address(entropy), type(IStreamArtworkScopedFinalityComponent).interfaceId);
        _scopedRecord(graph.children[4], keccak256("REFERENCE_RENDER"));
        _scopedRecord(authority.registry, keccak256("ARTIST_SANCTION"));
        _put(
            c.entropyFactory,
            abi.encodeCall(IStreamFinalityCurrentEntropyRoute.requireCurrentRoute, (scope)),
            abi.encode(
                StreamFinalityCurrentComponentRoute(
                    keccak256("ENTROPY_COORDINATOR"),
                    address(entropy),
                    type(IStreamArtworkScopedFinalityComponent).interfaceId,
                    address(entropy).codehash
                )
            )
        );
        _sign();
    }

    function _staticServing(bool active) private {
        IStreamMetadataServingFacts.ServingFacts memory f;
        f.configured = true;
        f.mode = keccak256("ONCHAIN");
        f.presentationProfile = keccak256("6529STREAM_STATIC_METADATA_SELECTION_V1");
        _put(
            c.router,
            abi.encodeCall(IStreamMetadataServingFacts.collectionServingFacts, (uint256(1))),
            abi.encode(f)
        );
        _put(
            c.router,
            abi.encodeCall(StaticRouter.staticMetadataActivation, (uint256(1))),
            abi.encode(
                active ? keccak256("static root") : bytes32(0),
                uint64(active ? 1 : 0),
                keccak256("static head")
            )
        );
    }

    function _scopedRecord(address target, bytes32 family) private {
        StreamFinalityComponentState memory s = _state(target, family, true);
        s.interfaceId = type(IStreamArtworkScopedFinalityComponent).interfaceId;
        _put(
            target,
            abi.encodeCall(IStreamArtworkScopedFinalityComponent.finalityStateForScope, (scope)),
            abi.encode(s)
        );
    }

    function _assertCurrent() private view {
        StreamFinalityCurrentComponentRoute[] memory routes =
            scoped.requireCurrentRoutes(scope, true);
        uint256 found;
        for (uint256 i; i < routes.length; ++i) {
            if (routes[i].componentType == keccak256("ARTIST_SANCTION")) {
                ++found;
                require(
                    routes[i].component == authority.registry
                        && routes[i].codeHash == authority.registryCodeHash
                );
                require(
                    scoped.finalityComponentAtForScope(scope, i).component == authority.registry
                );
            }
        }
        require(found == 1 && scoped.configuration().artist == c.artist);
    }

    function testOriginalCatalogUsesAuthenticatedBThenUnpredictedCWithoutChangingAnchor() public {
        _sign();
        _assertCurrent();
        (, bytes32 before_) = scoped.nonSanctionDiscoveryFacts(scope);
        _successor(_new());
        _sign();
        _assertCurrent();
        (, bytes32 after_) = scoped.nonSanctionDiscoveryFacts(scope);
        require(before_ == after_ && scoped.sourceConfigurationHash() == SOURCES);
    }

    function testFactoryReferenceAndCurrentSanctionRemainSeparateAcrossBAndC() public {
        _dynamicScope();
        _assertCurrent();
        require(
            scoped.dependencyCodeHash(graph.children[4]) == 0,
            "reference admitted only through selected graph"
        );
        StreamFinalityCurrentComponentRoute[] memory routes =
            scoped.requireCurrentRoutes(scope, true);
        uint256 found;
        for (uint256 i; i < routes.length; ++i) {
            if (routes[i].componentType == keccak256("REFERENCE_RENDER")) {
                ++found;
                require(routes[i].component == graph.children[4]);
                require(scoped.finalityComponentAtForScope(scope, i).component == graph.children[4]);
            }
        }
        require(found == 1);
        _successor(_new());
        _sign();
        _scopedRecord(authority.registry, keccak256("ARTIST_SANCTION"));
        _assertCurrent();
    }

    function testFactoryAndProviderProfileSubstitutionRejectedExactly() public {
        _put(
            binding.factory,
            abi.encodeCall(BaseFactory.scopedPreservationPolicyPublicationFactoryProfile, ()),
            abi.encode(Graph.PROFILE)
        );
        vm.expectRevert(
            abi.encodeWithSelector(FactoryReads.DiscoveryConfiguration.selector, binding.factory)
        );
        factoryReads.validate(c, binding);
        _put(
            binding.factory,
            abi.encodeCall(BaseFactory.scopedPreservationPolicyPublicationFactoryProfile, ()),
            abi.encode(CurrentGraph.FACTORY_PROFILE)
        );
        FactoryBinding.FactoryBinding memory changed = binding;
        changed.factory = _new();
        _put(
            c.provider,
            abi.encodeCall(FactoryBinding.scopedPreservationPolicyPublicationBinding, ()),
            abi.encode(changed)
        );
        vm.expectRevert(
            abi.encodeWithSelector(FactoryReads.DiscoveryConfiguration.selector, c.provider)
        );
        factoryReads.validate(c, binding);
    }

    function testBothFactoryInterfacesAndCanonicalERC165AreRequired() public {
        _put(
            binding.factory,
            abi.encodeCall(IERC165.supportsInterface, (type(CurrentFactory).interfaceId)),
            abi.encode(false)
        );
        vm.expectRevert(
            abi.encodeWithSelector(FactoryReads.DiscoveryConfiguration.selector, binding.factory)
        );
        factoryReads.validate(c, binding);
        _support(binding.factory, type(CurrentFactory).interfaceId);
        _put(
            binding.factory,
            abi.encodeCall(IERC165.supportsInterface, (type(BaseFactory).interfaceId)),
            abi.encode(uint256(2))
        );
        vm.expectRevert(
            abi.encodeWithSelector(FactoryReads.DiscoveryConfiguration.selector, binding.factory)
        );
        factoryReads.validate(c, binding);
    }

    function testOriginAndAuthorityDependencySubstitutionCannotReuseRecipeHash() public {
        Origin.Dependencies memory wrongOrigin = origin;
        wrongOrigin.worker = _new();
        _put(
            binding.factory,
            abi.encodeCall(CurrentFactory.originDependencies, ()),
            abi.encode(wrongOrigin)
        );
        vm.expectRevert(
            abi.encodeWithSelector(FactoryReads.DiscoveryConfiguration.selector, binding.factory)
        );
        factoryReads.validate(c, binding);
        _put(
            binding.factory,
            abi.encodeCall(CurrentFactory.originDependencies, ()),
            abi.encode(origin)
        );
        Capture.Dependencies memory wrongCapture = capture;
        wrongCapture.resolver = _new();
        _put(
            binding.factory,
            abi.encodeCall(CurrentFactory.authorityDependencies, ()),
            abi.encode(wrongCapture)
        );
        vm.expectRevert(
            abi.encodeWithSelector(FactoryReads.DiscoveryConfiguration.selector, binding.factory)
        );
        factoryReads.validate(c, binding);
    }

    function testMalformedOriginGetterAndFactoryRuntimeFailClosed() public {
        _put(
            binding.factory,
            abi.encodeCall(CurrentFactory.originDependencies, ()),
            abi.encode(origin.worker)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityRouterEvidence.RouterEvidenceRead.selector,
                binding.factory,
                CurrentFactory.originDependencies.selector
            )
        );
        factoryReads.validate(c, binding);
        FactoryBinding.FactoryBinding memory wrong = binding;
        wrong.factoryCodeHash = keccak256("wrong factory runtime");
        vm.expectRevert(
            abi.encodeWithSelector(FactoryReads.DiscoveryDependency.selector, binding.factory)
        );
        factoryReads.validate(c, wrong);
    }

    function testDynamicGraphOldDomainIncompleteAndChangedChildRejected() public {
        _dynamicScope();
        graph.graphId = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_PUBLICATION_GRAPH_V1"),
                block.chainid,
                binding.factory,
                binding.recipeHash,
                binding.sourceFactoryDependenciesHash,
                scope,
                graph.inventoryPlan,
                graph.sourceSet,
                graph.sourceSetCodeHash
            )
        );
        _graphValue();
        vm.expectRevert(abi.encodeWithSelector(FactoryReads.DiscoveryUnsupportedProfile.selector));
        scoped.finalityComponentCountForScope(scope);
        graph.graphId = _graphId(graph);
        graph.preparedChildren = 6;
        _graphValue();
        vm.expectRevert(abi.encodeWithSelector(FactoryReads.DiscoveryUnsupportedProfile.selector));
        scoped.finalityComponentCountForScope(scope);
        graph.preparedChildren = 7;
        graph.codeHashes[4] = keccak256("changed child runtime");
        _graphValue();
        vm.expectRevert(
            abi.encodeWithSelector(FactoryReads.DiscoveryDependency.selector, graph.children[4])
        );
        scoped.finalityComponentCountForScope(scope);
    }

    function testProviderCannotSubstituteReferenceOrConfigurationForFactoryGraph() public {
        _dynamicScope();
        selected.referenceRender = _new();
        _source();
        vm.expectRevert(
            abi.encodeWithSelector(ScopedDiscovery.DiscoveryUnsupportedProfile.selector)
        );
        scoped.requireCurrentRoutes(scope, false);
        selected.referenceRender = graph.children[4];
        selected.configurationHash = keccak256("other binding");
        _source();
        vm.expectRevert(
            abi.encodeWithSelector(ScopedDiscovery.DiscoveryUnsupportedProfile.selector)
        );
        scoped.finalityComponentCountForScope(scope);
    }

    function testLegacyStableProfileCannotAdmitStaticAndScopedRequiresActivation() public {
        _staticServing(true);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityRouterEvidence.RouterEvidenceProfile.selector, c.router
            )
        );
        scoped.finalityComponentCount(1);
        _dynamicScope();
        _staticServing(false);
        vm.expectRevert(
            abi.encodeWithSelector(ScopedDiscovery.DiscoveryUnsupportedProfile.selector)
        );
        scoped.finalityComponentCountForScope(scope);
        _staticServing(true);
        require(scoped.finalityComponentCountForScope(scope) == 10);
    }

    function testOriginalFinalityAnchorAndCurrentCoreSelectionBothRequired() public {
        _address(c.finalityRegistry, "sanctionReads()", authority.registry);
        vm.expectRevert(
            abi.encodeWithSelector(
                ScopedDiscovery.DiscoveryConfiguration.selector, c.finalityRegistry
            )
        );
        scoped.finalityComponentCount(1);
        _address(c.finalityRegistry, "sanctionReads()", c.artist);
        _selected(
            c.artist, keccak256("ARTIST_REGISTRY"), type(IStreamArtistMintConsent).interfaceId
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRecoveryRoutes.MetadataRecoveryBindingInvalid.selector, c.artist
            )
        );
        scoped.finalityComponentCount(1);
        _selected(
            authority.registry,
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId
        );
        require(scoped.finalityComponentCount(1) == 10);
    }

    function testConstructorDoesNotReadLateFinalityResolverOrScope() public {
        bytes memory runtime = c.finalityRegistry.code;
        vm.etch(c.finalityRegistry, bytes(""));
        DiscoveryReadTable(c.provider)
            .remove(abi.encodeCall(Profiles.finalitySourcesForScope, (scope)));
        ScopedDiscovery early = new ScopedDiscovery(c, SOURCES, collectionBinding, binding);
        require(address(early).code.length != 0 && capture.resolver.code.length == 0);
        vm.etch(c.finalityRegistry, runtime);
    }
}
