// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ScopedPolicyActualProviderFixtureV2
} from "./StreamFinalityScopedPolicyEvidenceProviderV2.t.sol";
import {
    StreamFinalityScopedPolicyProfileDiscoveryV2 as Discovery
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPolicyProfileDiscoveryV2.sol";
import {
    StreamFinalityScopedPolicyEvidenceProviderV2 as Provider
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPolicyEvidenceProviderV2.sol";
import {
    StreamScopedPolicyPublicationFactoryV2 as Factory
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyPublicationFactoryV2.sol";
import {
    StreamFinalityDiscoveryTypes as D
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityDiscoveryTypes.sol";
import {
    IStreamFinalityProfileSources as P
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    IStreamScopedPolicyPublicationEvidenceBindingV2 as Binding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyPublicationEvidenceBindingV2.sol";
import {
    StreamScopedPolicyPublicationGraphTypesV2 as Graph
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopedPolicyPublicationGraphTypesV2.sol";
import {
    StreamScopedPolicySnapshotDefinitionsV2 as SnapshotDefinitions
} from "../../../smart-contracts/domains/records/StreamScopedPolicySnapshotDefinitionsV2.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../../../smart-contracts/domains/finality/StreamFinalityRouterEvidence.sol";
import {
    StreamMetadataRecoveryRoutes as Routes
} from "../../../smart-contracts/domains/metadata/StreamMetadataRecoveryRoutes.sol";
import {
    StreamMetadataSubjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    IStreamCorePointers
} from "../../../smart-contracts/interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamModuleRegistry
} from "../../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";
import {
    IStreamArtistMintConsent
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMintConsent.sol";
import {
    IStreamFinalityRouterEvidenceBinding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityRouterEvidenceBinding.sol";
import {
    IStreamFinalityServingHostAdapter
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityServingHostAdapter.sol";
import {
    IStreamFinalityHostAdapter
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityHostAdapter.sol";
import {
    IStreamFinalityCurrentComponentRoutes,
    IStreamFinalityCurrentEntropyRoute,
    StreamFinalityCurrentComponentRoute
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import {
    IStreamArtworkFinalityComponent,
    IStreamArtworkScopedFinalityComponent
} from "../../../smart-contracts/interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType,
    StreamFinalityDomains
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { IERC165 } from "../../../smart-contracts/vendor/openzeppelin/IERC165.sol";

/// @dev Typed reciprocal adapter only. No frozen component evidence or finality is invented.
contract ScopedPolicyDiscoveryAdapterBoundaryV2 {
    address public immutable core;
    address public immutable host;
    address public immutable metadataHost;
    address public immutable evidenceProvider;
    bytes32 public immutable componentType;

    constructor(address c, address h, address m, address p, bytes32 family) {
        core = c;
        host = h;
        metadataHost = m;
        evidenceProvider = p;
        componentType = family;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IERC165).interfaceId
            || id == type(IStreamFinalityServingHostAdapter).interfaceId
            || id == type(IStreamArtworkFinalityComponent).interfaceId
            || id == type(IStreamArtworkScopedFinalityComponent).interfaceId;
    }
    function requireCurrentSelection() external pure { }
}

/// @notice Genuine factory children, provider selector, native entropy source, Snapshot and
/// Router V2 root feed the additive discovery. Construction runs in setUp, before test calls.
/// @dev The original three profile endpoints, seven adapters, Artist module admission, Registry
/// reciprocity and Router-candidate gate are explicit typed boundaries. No complete inventory,
/// frozen component set, sanctioned finality, transaction envelope or runtime-gas acceptance is
/// claimed. Positive/budget tests never mock provider source selection or factory graph reads.
contract StreamFinalityScopedPolicyProfileDiscoveryV2Test is ScopedPolicyActualProviderFixtureV2 {
    D.Configuration private dc;
    Discovery private discovery;
    Binding.FactoryBinding private boundFactory;
    P.Profile[3] private originalProfiles;

    function setUp() public override {
        super.setUp();
        _providerSetup(1, true);
        dc = _configuration(address(actualProvider));
        boundFactory = actualProvider.scopedPolicyPublicationBinding();
        discovery =
            new Discovery(dc, actualProvider.finalitySourceConfigurationHash(), boundFactory);
        _activate(discovery, dc);
    }

    function _mock(address target, bytes memory input, bytes memory output) private {
        snapshotVm.mockCall(target, input, output);
    }

    function _addressRead(address target, string memory sig, address result) private {
        _mock(target, abi.encodeWithSignature(sig), abi.encode(result));
    }

    function _supportsBoundary(address target) private {
        _mock(target, abi.encodeWithSelector(IERC165.supportsInterface.selector), abi.encode(true));
        _mock(
            target,
            abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))),
            abi.encode(false)
        );
    }

    function _configuration(address provider) private returns (D.Configuration memory c) {
        for (uint8 i; i < 3; ++i) {
            P.Profile memory p = Provider(provider).finalitySourceProfile(i);
            originalProfiles[i] = p;
            _addressRead(p.snapshots, "core()", address(core));
            _addressRead(p.snapshots, "metadataHost()", address(metadata));
            _addressRead(p.referenceRender, "core()", address(core));
            _addressRead(p.referenceRender, "metadataHost()", address(metadata));
            _addressRead(p.referenceRender, "metadataRouter()", address(router));
            _addressRead(p.referenceRender, "snapshots()", p.snapshots);
            _addressRead(p.entropyFactory, "core()", address(core));
            _addressRead(p.entropyFactory, "metadataHost()", address(metadata));
            _addressRead(p.entropyFactory, "scopeMembershipHost()", address(scopedMembership));
            _supportsBoundary(p.referenceRender);
            _supportsBoundary(p.entropyFactory);
        }
        c.core = address(core);
        c.metadata = address(metadata);
        c.router = address(router);
        c.provider = provider;
        c.membership = address(scopedMembership);
        c.entropyFactory = originalProfiles[0].entropyFactory;
        c.referenceRender = originalProfiles[0].referenceRender;
        c.artist = address(artist);
        c.finalityRegistry = originalProviderConfig.targets[12];
        c.finalityRegistryCodeHash = c.finalityRegistry.codehash;
        c.readGas = 2000000;
        c.componentGas = 256000000;
        c.entropyGas = 32000000;
        _supportsBoundary(c.artist);
        for (uint256 i; i < 7; ++i) {
            address adapter = address(
                new ScopedPolicyDiscoveryAdapterBoundaryV2(
                    c.core, i == 6 ? c.metadata : c.router, c.metadata, provider, _family(i)
                )
            );
            if (i == 6) c.metadataAdapter = adapter;
            else c.routerAdapters[i] = adapter;
        }
    }

    function _family(uint256 i) private pure returns (bytes32) {
        if (i == 0) return StreamFinalityDomains.COMPONENT_METADATA_ROUTER;
        if (i == 1) return StreamFinalityDomains.COMPONENT_RENDERER;
        if (i == 2) return StreamFinalityDomains.COMPONENT_RENDER_CONTEXT;
        if (i == 3) return StreamFinalityDomains.COMPONENT_MEDIA_MANIFEST;
        if (i == 4) return StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE;
        if (i == 5) return StreamFinalityDomains.COMPONENT_DEPENDENCY_SOURCE;
        return StreamFinalityDomains.COMPONENT_COLLECTION_METADATA;
    }

    function _activate(Discovery target, D.Configuration memory c) private {
        _addressRead(c.finalityRegistry, "scopeEvidenceProvider()", c.provider);
        _addressRead(c.finalityRegistry, "finalityDiscovery()", address(target));
        _addressRead(c.finalityRegistry, "coreReads()", c.core);
        _addressRead(c.finalityRegistry, "metadataReads()", c.metadata);
        _addressRead(c.finalityRegistry, "sanctionReads()", c.artist);
        _mock(
            c.provider,
            abi.encodeCall(
                IStreamFinalityRouterEvidenceBinding.requireCurrentRouterCandidate,
                (uint256(1), c.finalityRegistry)
            ),
            bytes("")
        );
        _mock(
            c.artist,
            abi.encodeWithSignature("streamModuleType()"),
            abi.encode(keccak256("ARTIST_REGISTRY"))
        );
        _mock(
            c.artist,
            abi.encodeWithSignature("streamModuleInterfaceId()"),
            abi.encode(type(IStreamArtistMintConsent).interfaceId)
        );
        Routes.Pointer memory pointer = Routes.Pointer(
            c.artist,
            c.artist.codehash,
            false,
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId,
            address(scopedModules),
            1,
            keccak256("typed Artist module"),
            keccak256("typed Artist deployment"),
            1
        );
        _mock(
            c.core,
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (keccak256("ARTIST_REGISTRY"))),
            abi.encode(pointer)
        );
        _mock(
            address(scopedModules),
            abi.encodeCall(
                IStreamModuleRegistry.isModuleEligible,
                (c.artist, keccak256("ARTIST_REGISTRY"), type(IStreamArtistMintConsent).interfaceId)
            ),
            abi.encode(true)
        );
    }

    function _assertRoutes(
        StreamFinalityCurrentComponentRoute[] memory routes,
        address reference_,
        address entropy_
    ) private view {
        require(routes.length == 9, "exact unsigned identity projection");
        uint256 found;
        for (uint256 i; i < routes.length; ++i) {
            if (i != 0) {
                require(
                    routes[i - 1].componentType < routes[i].componentType, "canonical family order"
                );
            }
            require(
                routes[i].interfaceId == type(IStreamArtworkScopedFinalityComponent).interfaceId
                    && routes[i].codeHash == routes[i].component.codehash
            );
            if (routes[i].componentType == StreamFinalityDomains.COMPONENT_REFERENCE_RENDER) {
                require(routes[i].component == reference_);
                found |= 1;
            }
            if (routes[i].componentType == StreamFinalityDomains.COMPONENT_ENTROPY_COORDINATOR) {
                require(routes[i].component == entropy_);
                found |= 2;
            }
        }
        require(found == 3, "both independently selected new children");
    }

    function _coolSelector(Discovery target) private {
        // Existing fixture cheatcode explicitly resets these accounts/storage for retries.
        safeVm.cool(address(target));
        safeVm.cool(address(actualProvider));
        safeVm.cool(address(publicationFactory));
        safeVm.cool(address(scopedFactory));
        safeVm.cool(address(scopedMembership));
        safeVm.cool(address(scopedSources));
        safeVm.cool(address(core));
        safeVm.cool(address(metadata));
        safeVm.cool(address(router));
        safeVm.cool(publicationGraph.sourceSet);
        for (uint256 i; i < 7; ++i) {
            safeVm.cool(publicationGraph.children[i]);
        }
    }

    function testColdActualProviderDiscoveryUsesConfiguredOuterBudgetAndGenuineDynamicRoutes()
        public
    {
        // setUp is a separate call; this is the first selector/route call in the test.
        StreamFinalityCurrentComponentRoute[] memory routes =
            discovery.requireCurrentRoutes(publication.scope, false);
        _assertRoutes(routes, publicationGraph.children[4], publicationGraph.sourceSet);
        P.Sources memory source = actualProvider.finalitySourcesForScope(publication.scope);
        require(
            source.profile.profileHash == SnapshotDefinitions.PROFILE_HASH
                && source.profile.referenceRender == publicationGraph.children[4]
                && source.profile.snapshots == publicationGraph.children[3]
        );
        require(
            source.profile.configurationHash == boundFactory.configurationHash
                && discovery.dependencyCodeHash(publicationGraph.children[4]) == 0,
            "new child is admitted by exact graph, never a generic mutable pin"
        );
        require(discovery.finalityComponentCountForScope(publication.scope) == 10);
        require(keccak256(abi.encode(discovery.configuration())) == keccak256(abi.encode(dc)));
    }

    function testScalarAndFormerDerivedBudgetRefuseThenSameActualSourcesPassConfiguredBudget()
        public
    {
        bytes memory input = abi.encodeCall(P.finalitySourcesForScope, (publication.scope));
        (bool ok,) = address(actualProvider).staticcall{ gas: 2000000 }(input);
        require(!ok, "scalar budget cannot transport genuine stored provider context plus graph");
        D.Configuration memory tooSmall = dc;
        tooSmall.componentGas = uint32(boundFactory.graphGas + boundFactory.graphGas / 63 + 100000);
        bytes32 config = actualProvider.finalitySourceConfigurationHash();
        vm.expectRevert(
            abi.encodeWithSelector(
                Discovery.DiscoveryConfiguration.selector, address(publicationFactory)
            )
        );
        new Discovery(tooSmall, config, boundFactory);
        // This old derived allowance is syntactically above the constructor minimum, but is
        // insufficient for the cold actual provider projection. It is not a protocol gas bound.
        tooSmall.componentGas = uint32(boundFactory.graphGas + boundFactory.graphGas / 63 + 200000);
        Discovery oldBudget = new Discovery(tooSmall, config, boundFactory);
        _activate(oldBudget, tooSmall);
        _coolSelector(oldBudget);
        vm.expectRevert(
            abi.encodeWithSelector(
                Reads.RouterEvidenceRead.selector,
                address(actualProvider),
                P.finalitySourcesForScope.selector
            )
        );
        oldBudget.requireCurrentRoutes(publication.scope, false);
        _activate(discovery, dc);
        _coolSelector(discovery);
        _assertRoutes(
            discovery.requireCurrentRoutes(publication.scope, false),
            publicationGraph.children[4],
            publicationGraph.sourceSet
        );
    }

    function testOriginalThreeProfilesRemainByteIdenticalAndOriginalScopedRouteKeepsItsPin()
        public
    {
        for (uint8 i; i < 3; ++i) {
            P.Profile memory p = actualProvider.finalitySourceProfile(i);
            require(
                keccak256(abi.encode(p))
                        == keccak256(abi.encode(previousProvider.finalitySourceProfile(i)))
                    && keccak256(abi.encode(p)) == keccak256(abi.encode(originalProfiles[i]))
            );
            require(
                discovery.dependencyCodeHash(p.referenceRender) == p.referenceRenderCodeHash
                    && discovery.dependencyCodeHash(p.snapshots) == p.snapshotsCodeHash
                    && discovery.dependencyCodeHash(p.entropyFactory) == p.entropyFactoryCodeHash
            );
        }
        StreamFinalityScope memory untouched =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 92, 0);
        P.Sources memory selected = actualProvider.finalitySourcesForScope(untouched);
        require(
            keccak256(abi.encode(selected))
                    == keccak256(abi.encode(previousProvider.finalitySourcesForScope(untouched)))
                && selected.profile.profileHash == originalProfiles[1].profileHash
        );
        address oldEntropy = address(
            new ScopedPolicyDiscoveryAdapterBoundaryV2(
                address(core),
                address(router),
                address(metadata),
                address(actualProvider),
                StreamFinalityDomains.COMPONENT_ENTROPY_COORDINATOR
            )
        );
        _mock(
            originalProfiles[1].entropyFactory,
            abi.encodeCall(IStreamFinalityCurrentEntropyRoute.requireCurrentRoute, (untouched)),
            abi.encode(
                StreamFinalityCurrentComponentRoute(
                    StreamFinalityDomains.COMPONENT_ENTROPY_COORDINATOR,
                    oldEntropy,
                    type(IStreamArtworkScopedFinalityComponent).interfaceId,
                    oldEntropy.codehash
                )
            )
        );
        _assertRoutes(
            discovery.requireCurrentRoutes(untouched, false),
            originalProfiles[1].referenceRender,
            oldEntropy
        );
        _assertRoutes(
            discovery.requireCurrentRoutes(publication.scope, false),
            publicationGraph.children[4],
            publicationGraph.sourceSet
        );
    }

    function testExactSelectedProfileRejectsForeignChildTagAndFullTokenTupleThenRestores() public {
        _assertRoutes(
            discovery.requireCurrentRoutes(publication.scope, false),
            publicationGraph.children[4],
            publicationGraph.sourceSet
        );
        P.Sources memory saved = actualProvider.finalitySourcesForScope(publication.scope);
        StreamFinalityScope memory otherScope =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 92, 0);
        bytes32 otherPlan = scopedSources.beginInventory(otherScope);
        scopedSources.appendInventory(otherPlan, 256);
        scopedFactory.prepareSourceSet(otherScope);
        Graph.Graph memory otherGraph = publicationFactory.prepareGraph(otherScope, 7);
        require(
            otherGraph.graphId != publicationGraph.graphId
                && otherGraph.children[4] != publicationGraph.children[4],
            "two genuine scope-bound factory graphs"
        );
        bytes memory input = abi.encodeCall(P.finalitySourcesForScope, (publication.scope));
        P.Sources memory changed = abi.decode(abi.encode(saved), (P.Sources));
        changed.scope.collectionId = 2;
        _mock(address(actualProvider), input, abi.encode(changed));
        vm.expectRevert(abi.encodeWithSelector(Discovery.DiscoveryUnsupportedProfile.selector));
        discovery.requireCurrentRoutes(publication.scope, false);
        changed = abi.decode(abi.encode(saved), (P.Sources));
        changed.profile.referenceRender = otherGraph.children[4];
        changed.profile.referenceRenderCodeHash = otherGraph.codeHashes[4];
        changed.profile.snapshots = otherGraph.children[3];
        changed.profile.snapshotsCodeHash = otherGraph.codeHashes[3];
        _mock(address(actualProvider), input, abi.encode(changed));
        vm.expectRevert(abi.encodeWithSelector(Discovery.DiscoveryUnsupportedProfile.selector));
        discovery.requireCurrentRoutes(publication.scope, false);
        changed = abi.decode(abi.encode(saved), (P.Sources));
        changed.profile.profileHash = keccak256("unknown selected profile");
        _mock(address(actualProvider), input, abi.encode(changed));
        vm.expectRevert(abi.encodeWithSelector(Discovery.DiscoveryUnsupportedProfile.selector));
        discovery.requireCurrentRoutes(publication.scope, false);
        _mock(address(actualProvider), input, abi.encode(saved));
        _assertRoutes(
            discovery.requireCurrentRoutes(publication.scope, false),
            publicationGraph.children[4],
            publicationGraph.sourceSet
        );
    }

    function testGenuineChildRuntimeFactoryPinAndWrongCollectionCannotFallbackToOldRoutes() public {
        _assertRoutes(
            discovery.requireCurrentRoutes(publication.scope, false),
            publicationGraph.children[4],
            publicationGraph.sourceSet
        );
        bytes memory code = publicationGraph.children[4].code;
        vm.etch(publicationGraph.children[4], hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                Reads.RouterEvidenceRead.selector,
                address(actualProvider),
                P.finalitySourcesForScope.selector
            )
        );
        discovery.requireCurrentRoutes(publication.scope, false);
        vm.etch(publicationGraph.children[4], code);
        code = address(publicationFactory).code;
        vm.etch(address(publicationFactory), hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                Reads.RouterEvidenceRead.selector,
                address(actualProvider),
                P.finalitySourcesForScope.selector
            )
        );
        discovery.requireCurrentRoutes(publication.scope, false);
        vm.etch(address(publicationFactory), code);
        StreamFinalityScope memory wrong =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 2, publication.scope.tokenId, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                Reads.RouterEvidenceRead.selector,
                address(actualProvider),
                P.finalitySourcesForScope.selector
            )
        );
        discovery.requireCurrentRoutes(wrong, false);
        _assertRoutes(
            discovery.requireCurrentRoutes(publication.scope, false),
            publicationGraph.children[4],
            publicationGraph.sourceSet
        );
    }

    function testConstructorBindsFixedRecipeWithoutAnyScopeChildrenAndRejectsAlteredBinding()
        public
    {
        Factory emptyFactory = new Factory(publicationRecipe);
        Binding.FactoryBinding memory b = Binding.FactoryBinding(
            address(emptyFactory),
            address(emptyFactory).codehash,
            emptyFactory.recipeHash(),
            emptyFactory.sourceFactoryDependenciesHash(),
            64000000,
            0
        );
        Provider emptyProvider = new Provider(
            originalProviderConfig,
            originalScopedConfig,
            collectionPolicyConfig,
            oldPolicyOutput,
            oldPolicyOutput.codehash,
            b
        );
        D.Configuration memory c = _configuration(address(emptyProvider));
        b = emptyProvider.scopedPolicyPublicationBinding();
        require(emptyFactory.graphForPlan(publicationGraph.inventoryPlan).preparedChildren == 0);
        Discovery emptyDiscovery =
            new Discovery(c, emptyProvider.finalitySourceConfigurationHash(), b);
        require(
            emptyDiscovery.scopeEvidenceProvider() == address(emptyProvider)
                && emptyFactory.graphForPlan(publicationGraph.inventoryPlan).graphId == 0,
            "constructor never requires a minted-scope publication graph"
        );
        b.recipeHash = keccak256("another recipe");
        bytes32 config = emptyProvider.finalitySourceConfigurationHash();
        vm.expectRevert(
            abi.encodeWithSelector(
                Discovery.DiscoveryConfiguration.selector, address(emptyProvider)
            )
        );
        new Discovery(c, config, b);
    }
}
