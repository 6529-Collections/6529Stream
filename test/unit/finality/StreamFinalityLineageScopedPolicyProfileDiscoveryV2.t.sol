// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamFinalityLineageDiscovery.t.sol";
import {
    StreamFinalityLineageScopedPolicyProfileDiscoveryV2 as ScopedDiscovery
} from "../../../smart-contracts/domains/finality/StreamFinalityLineageScopedPolicyProfileDiscoveryV2.sol";
import {
    StreamCurrentAuthorityScopedPolicyDiscoveryFactoryReadsV2 as FactoryReads
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedPolicyDiscoveryFactoryReadsV2.sol";
import {
    StreamCurrentAuthorityScopedPolicyPublicationGraphReadsV2 as GraphReads
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedPolicyPublicationGraphReadsV2.sol";
import {
    IStreamScopedPolicyPublicationFactoryV2 as BaseFactory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyPublicationFactoryV2.sol";
import {
    IStreamCurrentAuthorityScopedPolicyPublicationFactoryV2 as CurrentFactory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamCurrentAuthorityScopedPolicyPublicationFactoryV2.sol";
import {
    IStreamScopedPolicyPublicationEvidenceBindingV2 as FactoryBinding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyPublicationEvidenceBindingV2.sol";
import {
    StreamScopedPolicyPublicationGraphTypesV2 as Graph
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopedPolicyPublicationGraphTypesV2.sol";
import {
    StreamCurrentAuthorityScopedPolicyPublicationTypesV2 as CurrentGraph
} from "../../../smart-contracts/interfaces/stream/finality/StreamCurrentAuthorityScopedPolicyPublicationTypesV2.sol";
import {
    StreamArtistArchiveOriginTypes as Origin
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as Capture
} from "../../../smart-contracts/interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamScopedPolicySnapshotDefinitionsV2 as ScopedDefinitions
} from "../../../smart-contracts/domains/records/StreamScopedPolicySnapshotDefinitionsV2.sol";
import {
    IStreamGasParameterHost as Gas
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";

interface ScopedLineageVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
}

contract ScopedLineageFactoryReadsHarness {
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

/// @dev Production discovery and FactoryReads execute against explicit typed source/Finality
/// tables. Only GraphReads.bindings(r,od,ad,false) is mocked at its exact linked-library ABI;
/// this isolates constructor-graph admission, not seven-child deployment or source validity.
/// Recipe validation, canonical getters, graph IDs, reference pins, original profile semantics,
/// Core selection and current sanction route checks are real. No 55/60 or gas claim is made.
contract StreamFinalityLineageScopedPolicyProfileDiscoveryV2Test is LineageDiscoveryFixture {
    ScopedLineageVm private constant scopedVm =
        ScopedLineageVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    ScopedDiscovery private scoped;
    ScopedLineageFactoryReadsHarness private factoryReads;
    FactoryBinding.FactoryBinding private binding;
    Graph.Recipe private recipe;
    Origin.Dependencies private origin;
    Capture.Dependencies private capture;
    Profiles.Profile[3] private catalog;
    Profiles.Profile private selected;
    Graph.Graph private graph;
    bytes32 private constant SOURCES = keccak256("explicit fixed source catalog");

    function setUp() public override {
        super.setUp();
        c.readGas = 500000;
        c.componentGas = 8000000;
        c.entropyGas = 4000000;
        factoryReads = new ScopedLineageFactoryReadsHarness();
        _catalog();
        _factory();
        scoped = new ScopedDiscovery(c, SOURCES, binding);
        _address(c.finalityRegistry, "finalityDiscovery()", address(scoped));
    }

    function _catalog() private {
        address snapshots = IStreamFinalityDiscoverySources(c.provider).snapshotHost();
        _address(snapshots, "core()", c.core);
        _address(snapshots, "metadataHost()", c.metadata);
        _support(c.provider, type(Profiles).interfaceId);
        _put(
            c.provider,
            abi.encodeCall(Profiles.finalitySourceConfigurationHash, ()),
            abi.encode(SOURCES)
        );
        for (uint8 i; i < 3; ++i) {
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
            abi.encodeCall(FactoryBinding.scopedPolicyPublicationBinding, ()),
            abi.encode(binding)
        );
        _put(
            target,
            abi.encodeCall(BaseFactory.scopedPolicyPublicationFactoryProfile, ()),
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
            abi.encodeCall(BaseFactory.scopedPolicyPublicationFactoryProfile, ()),
            abi.encode(Graph.PROFILE)
        );
        vm.expectRevert(
            abi.encodeWithSelector(FactoryReads.DiscoveryConfiguration.selector, binding.factory)
        );
        factoryReads.validate(c, binding);
        _put(
            binding.factory,
            abi.encodeCall(BaseFactory.scopedPolicyPublicationFactoryProfile, ()),
            abi.encode(CurrentGraph.FACTORY_PROFILE)
        );
        FactoryBinding.FactoryBinding memory changed = binding;
        changed.factory = _new();
        _put(
            c.provider,
            abi.encodeCall(FactoryBinding.scopedPolicyPublicationBinding, ()),
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
                keccak256("6529STREAM_SCOPED_POLICY_PUBLICATION_GRAPH_V2"),
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
        ScopedDiscovery early = new ScopedDiscovery(c, SOURCES, binding);
        require(address(early).code.length != 0 && capture.resolver.code.length == 0);
        vm.etch(c.finalityRegistry, runtime);
    }
}
