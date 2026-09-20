// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ScopedPolicyActualProviderFixtureV2
} from "./StreamFinalityScopedPolicyEvidenceProviderV2.t.sol";
import {
    StreamFinalityFullPreservationPolicyDiscoveryV1 as Discovery
} from "../../../smart-contracts/domains/finality/StreamFinalityFullPreservationPolicyDiscoveryV1.sol";
import {
    StreamFinalityFullPreservationPolicyEvidenceProviderV1 as Provider
} from "../../../smart-contracts/domains/finality/StreamFinalityFullPreservationPolicyEvidenceProviderV1.sol";
import {
    StreamScopedPreservationPolicyPublicationFactoryV1 as Factory
} from "../../../smart-contracts/domains/finality/StreamScopedPreservationPolicyPublicationFactoryV1.sol";
import {
    StreamFinalityDiscoveryTypes as D
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityDiscoveryTypes.sol";
import {
    IStreamFinalityProfileSources as P
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    IStreamScopedPreservationPolicyPublicationEvidenceBindingV1 as Binding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPreservationPolicyPublicationEvidenceBindingV1.sol";
import {
    StreamScopedPreservationPolicyPublicationGraphTypesV1 as Graph
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopedPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamScopedPreservationPolicySnapshotDefinitionsV1 as SnapshotDefinitions
} from "../../../smart-contracts/domains/records/StreamScopedPreservationPolicySnapshotDefinitionsV1.sol";
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

import {
    ScopedPolicyDiscoveryAdapterBoundaryV2
} from "./StreamFinalityScopedPolicyProfileDiscoveryV2.t.sol";
import {
    StreamPreservationPolicyPublicationFactoryV1 as CollectionFactory
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyPublicationFactoryV1.sol";
import {
    StreamPreservationPolicyPublicationGraphTypesV1 as CollectionGraph
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationPolicyPublicationGraphTypesV1.sol";
import {
    IStreamPreservationPolicyPublicationFactoryV1 as CollectionFactoryInterface
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyPublicationFactoryV1.sol";
import {
    StreamFinalityEntropyPolicySourceFactoryV2 as CollectionEntropy
} from "../../../smart-contracts/domains/finality/StreamFinalityEntropyPolicySourceFactoryV2.sol";
import {
    IStreamPreservationPolicyPublicationGraphBindingV1 as CollectionBinding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyPublicationGraphBindingV1.sol";
import {
    IStreamFinalityPreservationFactoryProfileSourcesV1 as Catalogue
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityPreservationFactoryProfileSourcesV1.sol";
import {
    IStreamPreservationPolicyContentRootPublicationV1 as CollectionRoot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPreservationPolicyContentRootPublicationV1.sol";
import {
    IStreamContentRootPublication as Root
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamContentRootPublication.sol";
import {
    IStreamPolicyOutputEvidenceBindingV2 as OldOutput
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPolicyOutputEvidenceBindingV2.sol";
import {
    StreamFinalityFactoryProfileSourceReadsV2 as StaticSelection
} from "../../../smart-contracts/domains/finality/StreamFinalityFactoryProfileSourceReadsV2.sol";
import {
    StreamFinalityPreservationPolicyGraphSelectionV1 as CollectionSelection
} from "../../../smart-contracts/domains/finality/StreamFinalityPreservationPolicyGraphSelectionV1.sol";
import {
    StreamPreservationPolicySnapshotDefinitionsV1 as CollectionDefinitions
} from "../../../smart-contracts/domains/records/StreamPreservationPolicySnapshotDefinitionsV1.sol";

import {
    IStreamScopedPreservationPolicyContentRootPublicationV1 as ScopedRoot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicyContentRootPublicationV1.sol";
import {
    IStreamScopedContentRootPublication as OriginalScopedRoot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    StreamFinalityScopedPreservationPolicyGraphSelectionV1 as ScopedSelection
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicyGraphSelectionV1.sol";

/// @notice Actual immutable factories/provider/discovery and genuine mixed-policy children.
/// @dev Core token identities, original0/1 sources, adapters, Artist admission and Registry are
/// inherited named boundaries. COLLECTION canonical root admission is a typed Router boundary:
/// these cases test selection and current route identities, not publication/Artist17 or complete
/// finality. Both new root bindings are explicit already-admitted typed Router boundaries.
/// No provider selection or factory graph return is mocked in positives. Actual preservation
/// producer/admission/output publication and complete finality remain separate ceremony tests.
contract StreamFinalityFullPreservationPolicyDiscoveryV1Test is
    ScopedPolicyActualProviderFixtureV2
{
    Factory private preservationFactory;
    Graph.Graph private preservationGraph;
    Provider private fullProvider;
    Discovery private discovery;
    CollectionEntropy private collectionEntropy;
    CollectionFactory private collectionFactory;
    CollectionGraph.Recipe private collectionRecipe;
    CollectionBinding.CollectionFactoryBinding private collectionBinding;
    Binding.FactoryBinding private scopedBinding;
    D.Configuration private dc;
    P.Profile[2] private originalProfiles;

    function setUp() public override {
        super.setUp();
        _providerSetup(1, false);
        // The source fixture retains old published capabilities; new root authority is a named
        // typed boundary here, while both actual new factories and all their children are real.
        _mock(
            address(router),
            abi.encodeCall(IERC165.supportsInterface, (type(CollectionRoot).interfaceId)),
            abi.encode(true)
        );
        _mock(
            address(router),
            abi.encodeCall(IERC165.supportsInterface, (type(ScopedRoot).interfaceId)),
            abi.encode(true)
        );
        Graph.Recipe memory scopedRecipe = abi.decode(abi.encode(publicationRecipe), (Graph.Recipe));
        preservationFactory = new Factory(scopedRecipe);
        preservationGraph = preservationFactory.prepareGraph(publication.scope, 7);
        Binding.FactoryBinding memory sb = Binding.FactoryBinding(
            address(preservationFactory),
            address(preservationFactory).codehash,
            preservationFactory.recipeHash(),
            preservationFactory.sourceFactoryDependenciesHash(),
            64000000,
            0
        );
        collectionEntropy = new CollectionEntropy(_scopedDependencies());
        // Shapes are identical, but profile-specific gas names and source factory are explicit.
        collectionRecipe = abi.decode(abi.encode(publicationRecipe), (CollectionGraph.Recipe));
        collectionRecipe.targets[2] = address(collectionEntropy);
        collectionRecipe.codeHashes[2] = address(collectionEntropy).codehash;
        collectionRecipe.snapshotGas[0].name = "POLICY_SNAPSHOT_READ_GAS";
        collectionRecipe.snapshotGas[1].name = "POLICY_SNAPSHOT_SOURCE_GAS";
        collectionRecipe.snapshotGas[2].name = "POLICY_SNAPSHOT_INVENTORY_GAS";
        collectionRecipe.referenceGas[0].name = "POLICY_REFERENCE_READ_GAS";
        collectionRecipe.referenceGas[1].name = "POLICY_REFERENCE_SOURCE_GAS";
        collectionRecipe.referenceGas[2].name = "POLICY_REFERENCE_SNAPSHOT_GAS";
        collectionRecipe.referenceGas[3].name = "POLICY_REFERENCE_ARCHIVE_GAS";
        collectionFactory = new CollectionFactory(collectionRecipe);
        CollectionBinding.CollectionFactoryBinding memory cb =
            CollectionBinding.CollectionFactoryBinding(
                address(collectionFactory),
                address(collectionFactory).codehash,
                collectionFactory.recipeHash(),
                collectionFactory.sourceFactoryDependenciesHash(),
                64000000,
                0
            );
        fullProvider = new Provider(originalProviderConfig, originalScopedConfig, cb, sb);
        collectionBinding = fullProvider.collectionPreservationPolicyPublicationBinding();
        scopedBinding = fullProvider.scopedPreservationPolicyPublicationBinding();
        dc = _configuration(address(fullProvider));
        discovery = new Discovery(
            dc, fullProvider.finalitySourceConfigurationHash(), collectionBinding, scopedBinding
        );
        _activate(discovery, dc);
        _scopedRootBoundary();
    }

    function _collectionScope() private pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
    }

    function _prepareCollection() private returns (CollectionGraph.Graph memory g) {
        StreamFinalityScope memory scope = _collectionScope();
        bytes32 plan = scopedSources.beginInventory(scope);
        scopedSources.appendInventory(plan, 256);
        collectionEntropy.prepareSourceSet(scope);
        return collectionFactory.prepareGraph(scope, 7);
    }

    function _rootBoundary(CollectionGraph.Graph memory g)
        private
        returns (CollectionRoot.Binding memory b)
    {
        b.profileId = keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1");
        b.outputManifest = g.children[2];
        b.outputManifestCodeHash = g.codeHashes[2];
        b.checkpoint = g.children[1];
        b.checkpointCodeHash = g.codeHashes[1];
        b.entropySourceSet = g.sourceSet;
        b.entropySourceSetCodeHash = g.sourceSetCodeHash;
        b.checkpointHash = keccak256("admitted collection checkpoint");
        b.checkpointStateHash = keccak256("admitted collection state");
        b.inventoryHash = keccak256("admitted collection inventory");
        b.policyChainHash = keccak256("admitted complete policy chain");
        b.outputRoot = keccak256("admitted original output root");
        b.outputSchemaHash = keccak256("original output schema");
        b.outputCanonicalizationHash = keccak256("original output canonicalization");
        b.leafSchemaHash = keccak256("original leaf schema");
        b.rootSchemaHash = keccak256("original root schema");
        b.rootCanonicalizationHash = keccak256("original root canonicalization");
        b.metadataRouter = address(router);
        b.preservationOutputProfile = keccak256("6529STREAM_PRESERVATION_RENDER_V1");
        _setRootBoundary(b);
    }

    function _setRootBoundary(CollectionRoot.Binding memory b) private {
        bytes32 head = keccak256("explicit already-admitted collection root boundary");
        _mock(
            address(router),
            abi.encodeCall(Root.collectionContentRootHead, (uint256(1))),
            abi.encode(head)
        );
        _mock(
            address(router),
            abi.encodeCall(CollectionRoot.preservationPolicyContentRootBinding, (head)),
            abi.encode(b)
        );
    }

    function testFactoryCatalogueHasOnlyOriginalTwoExactProfilesAndNoGlobalPolicyGetter() public {
        require(fullProvider.supportsInterface(type(Catalogue).interfaceId));
        require(!fullProvider.supportsInterface(type(P).interfaceId));
        require(!fullProvider.supportsInterface(type(OldOutput).interfaceId));
        require(
            fullProvider.preservationFactorySourceProfile()
                == keccak256("6529STREAM_FINALITY_PRESERVATION_FACTORY_PROFILE_SOURCES_V1")
        );
        for (uint8 i; i < 2; ++i) {
            require(
                keccak256(abi.encode(fullProvider.finalitySourceProfile(i)))
                    == keccak256(abi.encode(actualProvider.finalitySourceProfile(i)))
            );
        }
        vm.expectRevert(
            abi.encodeWithSelector(StaticSelection.InvalidFinalitySourceProfile.selector)
        );
        fullProvider.finalitySourceProfile(2);
        (bool ok,) =
            address(fullProvider).staticcall(abi.encodeCall(OldOutput.policyOutputManifestV2, ()));
        require(!ok, "no invented global policy output");
        require(
            fullProvider.finalitySourceConfigurationHash()
                == keccak256(
                    abi.encode(
                        keccak256(
                            "6529STREAM_FINALITY_PRESERVATION_FACTORY_SOURCE_CONFIGURATION_V1"
                        ),
                        block.chainid,
                        address(fullProvider),
                        originalProviderConfig,
                        originalScopedConfig,
                        collectionBinding,
                        scopedBinding
                    )
                )
        );
        bytes32 plan = collectionEntropy.currentInventoryPlan(_collectionScope());
        require(collectionFactory.graphForPlan(plan).graphId == 0);
        (address set,) = collectionEntropy.sourceSetForPlan(plan);
        require(set == address(0), "constructor admitted no COLLECTION source or graph");
    }

    function testGenuineScopedRouteRemainsUsableBeforeAnyCollectionGraph() public {
        // setUp is separate; this is the first route read in this test transaction.
        _assertRoutes(
            discovery.requireCurrentRoutes(publication.scope, false),
            preservationGraph.children[4],
            preservationGraph.sourceSet,
            false
        );
        require(
            fullProvider.finalitySourcesForScope(publication.scope).profile.referenceRender
                == preservationGraph.children[4]
        );
        require(
            fullProvider.finalitySourcesForScope(_collectionScope()).profile.referenceRender
                == originalProfiles[0].referenceRender
        );
    }

    function testCollectionPolicyFailsClosedUntilActualSevenChildrenThenAdmitsWithoutSetter()
        public
    {
        StreamFinalityScope memory scope = _collectionScope();
        bytes32 commitment = fullProvider.finalitySourceConfigurationHash();
        require(
            fullProvider.finalitySourcesForScope(scope).profile.profileHash
                == originalProfiles[0].profileHash
        );
        CollectionGraph.Graph memory absent;
        _rootBoundary(absent);
        vm.expectRevert(
            abi.encodeWithSelector(
                Reads.RouterEvidenceRead.selector,
                address(collectionFactory),
                CollectionFactoryInterface.requireCurrentGraph.selector
            )
        );
        fullProvider.finalitySourcesForScope(scope);
        bytes32 plan = scopedSources.beginInventory(scope);
        scopedSources.appendInventory(plan, 256);
        collectionEntropy.prepareSourceSet(scope);
        CollectionGraph.Graph memory g = collectionFactory.prepareGraph(scope, 3);
        _rootBoundary(g);
        vm.expectRevert(
            abi.encodeWithSelector(
                Reads.RouterEvidenceRead.selector,
                address(collectionFactory),
                CollectionFactoryInterface.requireCurrentGraph.selector
            )
        );
        fullProvider.finalitySourcesForScope(scope);
        g = collectionFactory.prepareGraph(scope, 4);
        _rootBoundary(g);
        P.Sources memory sources = fullProvider.finalitySourcesForScope(scope);
        require(
            sources.profile.profileHash == CollectionDefinitions.PROFILE_HASH
                && sources.profile.snapshots == g.children[3]
                && sources.profile.referenceRender == g.children[4]
        );
        require(
            sources.profile.entropyFactory == address(collectionEntropy)
                && sources.profile.configurationHash == collectionBinding.configurationHash
        );
        _assertRoutes(
            discovery.requireCurrentRoutes(scope, false), g.children[4], g.sourceSet, true
        );
        require(
            fullProvider.finalitySourceConfigurationHash() == commitment
                && discovery.sourceConfigurationHash() == commitment
        );
        require(
            discovery.dependencyCodeHash(g.children[4]) == 0,
            "dynamic child was never a static catalogue pin"
        );
    }

    function testCollectionExactGraphRootPinsAndOriginalCommitmentsCannotBeSubstituted() public {
        CollectionGraph.Graph memory g = _prepareCollection();
        CollectionRoot.Binding memory saved = _rootBoundary(g);
        StreamFinalityScope memory scope = _collectionScope();
        require(
            fullProvider.finalitySourcesForScope(scope).profile.referenceRender == g.children[4]
        );
        CollectionRoot.Binding memory changed =
            abi.decode(abi.encode(saved), (CollectionRoot.Binding));
        changed.outputManifest = preservationGraph.children[2];
        changed.outputManifestCodeHash = preservationGraph.codeHashes[2];
        _setRootBoundary(changed);
        vm.expectRevert(
            abi.encodeWithSelector(CollectionSelection.PolicyGraphSource.selector, address(router))
        );
        fullProvider.finalitySourcesForScope(scope);
        changed = abi.decode(abi.encode(saved), (CollectionRoot.Binding));
        changed.inventoryHash = 0;
        _setRootBoundary(changed);
        vm.expectRevert(
            abi.encodeWithSelector(CollectionSelection.PolicyGraphSource.selector, address(router))
        );
        fullProvider.finalitySourcesForScope(scope);
        _setRootBoundary(saved);
        _assertRoutes(
            discovery.requireCurrentRoutes(scope, false), g.children[4], g.sourceSet, true
        );
    }

    function testSelectedCollectionTupleTagAndRuntimeCorruptionsRestoreExactRoute() public {
        CollectionGraph.Graph memory g = _prepareCollection();
        _rootBoundary(g);
        StreamFinalityScope memory scope = _collectionScope();
        _assertRoutes(
            discovery.requireCurrentRoutes(scope, false), g.children[4], g.sourceSet, true
        );
        P.Sources memory saved = fullProvider.finalitySourcesForScope(scope);
        bytes memory input = abi.encodeCall(Catalogue.finalitySourcesForScope, (scope));
        P.Sources memory changed = abi.decode(abi.encode(saved), (P.Sources));
        changed.scope.tokenId = 91;
        _mock(address(fullProvider), input, abi.encode(changed));
        vm.expectRevert(abi.encodeWithSelector(Discovery.DiscoveryUnsupportedProfile.selector));
        discovery.requireCurrentRoutes(scope, false);
        changed = abi.decode(abi.encode(saved), (P.Sources));
        changed.profile.profileHash = keccak256("unknown factory profile");
        _mock(address(fullProvider), input, abi.encode(changed));
        vm.expectRevert(abi.encodeWithSelector(Discovery.DiscoveryUnsupportedProfile.selector));
        discovery.requireCurrentRoutes(scope, false);
        changed = abi.decode(abi.encode(saved), (P.Sources));
        changed.profile.configurationHash = keccak256("different source configuration");
        _mock(address(fullProvider), input, abi.encode(changed));
        vm.expectRevert(abi.encodeWithSelector(Discovery.DiscoveryUnsupportedProfile.selector));
        discovery.requireCurrentRoutes(scope, false);
        _mock(address(fullProvider), input, abi.encode(saved));
        bytes memory code = g.children[4].code;
        vm.etch(g.children[4], hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                Reads.RouterEvidenceRead.selector,
                address(collectionFactory),
                CollectionFactoryInterface.requireCurrentGraph.selector
            )
        );
        discovery.requireCurrentRoutes(scope, false);
        vm.etch(g.children[4], code);
        _assertRoutes(
            discovery.requireCurrentRoutes(scope, false), g.children[4], g.sourceSet, true
        );
    }

    function testCollectionSelectedChildMustRetainExactReciprocalAndInterface() public {
        CollectionGraph.Graph memory g = _prepareCollection();
        _rootBoundary(g);
        StreamFinalityScope memory scope = _collectionScope();
        _assertRoutes(
            discovery.requireCurrentRoutes(scope, false), g.children[4], g.sourceSet, true
        );
        _addressRead(g.children[4], "snapshots()", preservationGraph.children[3]);
        vm.expectRevert(
            abi.encodeWithSelector(Discovery.DiscoveryConfiguration.selector, g.children[4])
        );
        discovery.requireCurrentRoutes(scope, false);
        _addressRead(g.children[4], "snapshots()", g.children[3]);
        _mock(
            g.children[4],
            abi.encodeCall(
                IERC165.supportsInterface, (type(IStreamArtworkFinalityComponent).interfaceId)
            ),
            abi.encode(false)
        );
        vm.expectRevert(
            abi.encodeWithSelector(Discovery.DiscoveryConfiguration.selector, g.children[4])
        );
        discovery.requireCurrentRoutes(scope, false);
        _mock(
            g.children[4],
            abi.encodeCall(
                IERC165.supportsInterface, (type(IStreamArtworkFinalityComponent).interfaceId)
            ),
            abi.encode(true)
        );
        _assertRoutes(
            discovery.requireCurrentRoutes(scope, false), g.children[4], g.sourceSet, true
        );
    }

    function testConstructorRejectsChangedFactoryBindingsAndInsufficientGraphBudget() public {
        CollectionBinding.CollectionFactoryBinding memory changed = collectionBinding;
        changed.recipeHash = keccak256("wrong fixed recipe");
        bytes32 hash = fullProvider.finalitySourceConfigurationHash();
        vm.expectRevert(
            abi.encodeWithSelector(Discovery.DiscoveryConfiguration.selector, address(fullProvider))
        );
        new Discovery(dc, hash, changed, scopedBinding);
        D.Configuration memory low = dc;
        uint256 minimumOuter = collectionBinding.graphGas + collectionBinding.graphGas / 63 + 100000;
        require(minimumOuter <= type(uint32).max);
        low.componentGas = uint32(minimumOuter);
        vm.expectRevert(
            abi.encodeWithSelector(Discovery.DiscoveryConfiguration.selector, scopedBinding.factory)
        );
        new Discovery(low, hash, collectionBinding, scopedBinding);
        Binding.FactoryBinding memory smaller = scopedBinding;
        smaller.graphGas = 50000;
        // A tampered binding cannot be used to evade either independent fixed recipe check.
        vm.expectRevert(
            abi.encodeWithSelector(Discovery.DiscoveryConfiguration.selector, address(fullProvider))
        );
        new Discovery(dc, hash, collectionBinding, smaller);
    }

    function _scopedRootBoundary() private returns (ScopedRoot.Binding memory b) {
        Graph.Graph memory g = preservationGraph;
        b.profileId = keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_V1");
        b.outputManifest = g.children[2];
        b.outputManifestCodeHash = g.codeHashes[2];
        b.checkpoint = g.children[1];
        b.checkpointCodeHash = g.codeHashes[1];
        b.entropySourceSet = g.sourceSet;
        b.entropySourceSetCodeHash = g.sourceSetCodeHash;
        b.sourceFactory = preservationFactory.entropySourceFactory();
        b.sourceFactoryCodeHash = b.sourceFactory.codehash;
        b.factoryDependenciesHash = preservationFactory.sourceFactoryDependenciesHash();
        b.snapshotProfileHash = SnapshotDefinitions.PROFILE_HASH;
        b.metadataRouter = address(router);
        b.preservationOutputProfile = keccak256("6529STREAM_PRESERVATION_RENDER_V1");
        _setScopedRoot(b);
    }

    function _setScopedRoot(ScopedRoot.Binding memory b) private {
        bytes32 head = keccak256("typed admitted preservation scoped root");
        _mock(
            address(router),
            abi.encodeCall(OriginalScopedRoot.scopedContentRootHead, (publication.scope)),
            abi.encode(head)
        );
        _mock(
            address(router),
            abi.encodeCall(ScopedRoot.scopedPreservationPolicyContentRootBinding, (head)),
            abi.encode(b)
        );
    }

    function testPreservationRootBindingsRequireAllNewWordsAndRejectOldTupleWidths() public {
        CollectionGraph.Graph memory g = _prepareCollection();
        CollectionRoot.Binding memory original = _rootBoundary(g);
        require(abi.encode(original).length == 608);
        StreamFinalityScope memory scope = _collectionScope();
        fullProvider.finalitySourcesForScope(scope);
        for (uint256 i; i < 3; ++i) {
            CollectionRoot.Binding memory bad =
                abi.decode(abi.encode(original), (CollectionRoot.Binding));
            if (i == 0) {
                bad.metadataRouter = address(collectionFactory);
            } else if (i == 1) {
                bad.preservationOutputProfile = keccak256("live output is a separate profile");
            } else {
                bad.profileId = keccak256("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2");
            }
            _setRootBoundary(bad);
            vm.expectRevert(
                abi.encodeWithSelector(
                    CollectionSelection.PolicyGraphSource.selector, address(router)
                )
            );
            fullProvider.finalitySourcesForScope(scope);
        }
        bytes32 head = keccak256("explicit already-admitted collection root boundary");
        bytes memory exact = abi.encode(original);
        bytes memory oldWidth = new bytes(544);
        for (uint256 i; i < oldWidth.length; ++i) {
            oldWidth[i] = exact[i];
        }
        _mock(
            address(router),
            abi.encodeCall(CollectionRoot.preservationPolicyContentRootBinding, (head)),
            oldWidth
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Reads.RouterEvidenceRead.selector,
                address(router),
                CollectionRoot.preservationPolicyContentRootBinding.selector
            )
        );
        fullProvider.finalitySourcesForScope(scope);
        _setRootBoundary(original);
        _assertRoutes(
            discovery.requireCurrentRoutes(scope, false), g.children[4], g.sourceSet, true
        );
    }

    function testScopedPreservationGraphCannotBorrowCollectionChildOrOldProfile() public {
        ScopedRoot.Binding memory original = _scopedRootBoundary();
        require(abi.encode(original).length == 800);
        _assertRoutes(
            discovery.requireCurrentRoutes(publication.scope, false),
            preservationGraph.children[4],
            preservationGraph.sourceSet,
            false
        );
        CollectionGraph.Graph memory cg = _prepareCollection();
        for (uint256 i; i < 4; ++i) {
            ScopedRoot.Binding memory bad = abi.decode(abi.encode(original), (ScopedRoot.Binding));
            if (i == 0) {
                bad.outputManifest = cg.children[2];
                bad.outputManifestCodeHash = cg.codeHashes[2];
            } else if (i == 1) {
                bad.metadataRouter = address(collectionFactory);
            } else if (i == 2) {
                bad.preservationOutputProfile = keccak256("wrong preservation producer profile");
            } else {
                bad.profileId = keccak256("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_V2");
            }
            _setScopedRoot(bad);
            vm.expectRevert(
                abi.encodeWithSelector(
                    ScopedSelection.ScopedPolicyGraphSource.selector, address(router)
                )
            );
            fullProvider.finalitySourcesForScope(publication.scope);
        }
        _setScopedRoot(original);
        P.Sources memory sources = fullProvider.finalitySourcesForScope(publication.scope);
        require(sources.profile.profileHash == SnapshotDefinitions.PROFILE_HASH);
        P.Sources memory wrong = abi.decode(abi.encode(sources), (P.Sources));
        wrong.scope.collectionId = 2;
        _mock(
            address(fullProvider),
            abi.encodeCall(Catalogue.finalitySourcesForScope, (publication.scope)),
            abi.encode(wrong)
        );
        vm.expectRevert(abi.encodeWithSelector(Discovery.DiscoveryUnsupportedProfile.selector));
        discovery.requireCurrentRoutes(publication.scope, false);
        _mock(
            address(fullProvider),
            abi.encodeCall(Catalogue.finalitySourcesForScope, (publication.scope)),
            abi.encode(sources)
        );
        _assertRoutes(
            discovery.requireCurrentRoutes(publication.scope, false),
            preservationGraph.children[4],
            preservationGraph.sourceSet,
            false
        );
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
        for (uint8 i; i < 2; ++i) {
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
        address entropy_,
        bool collection
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
                routes[i].interfaceId
                        == (collection
                                ? type(IStreamArtworkFinalityComponent).interfaceId
                                : type(IStreamArtworkScopedFinalityComponent).interfaceId)
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
}
