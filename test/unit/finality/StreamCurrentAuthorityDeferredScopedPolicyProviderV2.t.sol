// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamCurrentAuthorityDeferredScopedPolicyEvidenceProviderV2 as Host
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityDeferredScopedPolicyEvidenceProviderV2.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "../../../smart-contracts/domains/finality/StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityScopedProviderReads as Scoped
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedProviderReads.sol";
import {
    StreamCurrentAuthorityDeferredPolicyBindingTypesV2 as T
} from "../../../smart-contracts/interfaces/stream/finality/StreamCurrentAuthorityDeferredPolicyBindingTypesV2.sol";
import {
    IStreamCurrentAuthorityDeferredPolicyBindingV2 as Binding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamCurrentAuthorityDeferredPolicyBindingV2.sol";
import {
    IStreamScopedPolicyPublicationEvidenceBindingV2 as GraphBinding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyPublicationEvidenceBindingV2.sol";
import {
    IStreamCurrentAuthorityScopedPolicyPublicationFactoryV2 as Factory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamCurrentAuthorityScopedPolicyPublicationFactoryV2.sol";
import {
    IStreamScopedPolicyPublicationFactoryV2 as OldFactory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyPublicationFactoryV2.sol";
import {
    IStreamFinalityScopedEntropyPolicySourceFactoryV2 as EntropyFactory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    StreamScopedPolicyPublicationGraphTypesV2 as G
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopedPolicyPublicationGraphTypesV2.sol";
import {
    StreamCurrentAuthorityScopedPolicyPublicationTypesV2 as Domains
} from "../../../smart-contracts/interfaces/stream/finality/StreamCurrentAuthorityScopedPolicyPublicationTypesV2.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as Policies
} from "../../../smart-contracts/domains/finality/StreamFinalityCoordinatorPolicyReadsV2.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../../smart-contracts/interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    IStreamGasParameterHost as Gas
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    IStreamMetadataServingFacts as Serving
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    IStreamMetadataRouter as Router
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataRouter.sol";
import {
    IStreamPolicyContentRootPublicationV2 as PolicyRoot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPolicyContentRootPublicationV2.sol";
import {
    IStreamScopedPolicyContentRootPublicationV2 as ScopedRoot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPolicyContentRootPublicationV2.sol";
import {
    IStreamFinalityProfileSources as Profiles
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    StreamFinalityProfileSourceReads as ProfileReads
} from "../../../smart-contracts/domains/finality/StreamFinalityProfileSourceReads.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamScopedPolicySnapshotDefinitionsV2 as ScopedDefinitions
} from "../../../smart-contracts/domains/records/StreamScopedPolicySnapshotDefinitionsV2.sol";
import {
    StreamFinalityComponentExpectation
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { IERC165 } from "../../../smart-contracts/vendor/openzeppelin/IERC165.sol";
import {
    FinalityMultiOriginReadTable as Table
} from "./StreamFinalityMultiOriginConfiguration.t.sol";

import {
    StreamCurrentAuthorityDeferredPolicyValidationV2 as Validation
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityDeferredPolicyValidationV2.sol";
import {
    StreamCurrentAuthorityScopedPolicyBaseEvidenceProviderV2 as FallbackBase
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedPolicyBaseEvidenceProviderV2.sol";
import {
    StreamCurrentAuthorityNativeProviderReads as FallbackReads
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityNativeProviderReads.sol";
import {
    StreamCurrentAuthorityNativeSanctionReview as FallbackReview
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityNativeSanctionReview.sol";
import {
    StreamFinalityInputManifestReads as FallbackManifest
} from "../../../smart-contracts/domains/finality/StreamFinalityInputManifestReads.sol";
import {
    StreamFinalityInputManifestTypes as FallbackTypes
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityInputManifestTypes.sol";
import {
    StreamFinalityInputManifestSchemas as FallbackSchemas
} from "../../../smart-contracts/domains/finality/StreamFinalityInputManifestSchemas.sol";
import {
    StreamMetadataRecoveryRoutes as FallbackRecovery
} from "../../../smart-contracts/domains/metadata/StreamMetadataRecoveryRoutes.sol";
import {
    IStreamCollectionMetadataV1 as FallbackMetadata
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamArtworkFinalityRegistry as FallbackRegistry
} from "../../../smart-contracts/interfaces/stream/finality/IStreamArtworkFinalityRegistry.sol";
import {
    IStreamFinalitySanctionReview as FallbackReviewInterface
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalitySanctionReview.sol";
import {
    IStreamFinalityCurrentComponentRoutes as FallbackRoutes,
    StreamFinalityCurrentComponentRoute
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import {
    StreamCurrentAuthorityScopedProviderOperations as ScopedFallbackOperations
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedProviderOperations.sol";
import {
    IStreamScopedContentRootPublication as ScopedFallbackRoot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    StreamCurrentAuthorityScopedPolicyGraphSelectionV2 as ComponentGraph
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedPolicyGraphSelectionV2.sol";
import {
    StreamFinalityScopedPolicyProviderReadsV2 as ComponentConfig
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPolicyProviderReadsV2.sol";
import {
    StreamFinalityScopedPolicyMetadataFactsV2 as ComponentMetadata
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPolicyMetadataFactsV2.sol";
import {
    StreamFinalityScopedPolicyStaticComponentsV2 as ComponentStatic
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPolicyStaticComponentsV2.sol";
import {
    StreamFinalityHostComponentFacts
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityEvidenceTypes.sol";
import {
    StreamScopeMembershipFacts
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    StreamMetadataSubjects as ComponentSubjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    StreamFinalityDeferredProfileSourceReadsV2 as BoundComponentSelection
} from "../../../smart-contracts/domains/finality/StreamFinalityDeferredProfileSourceReadsV2.sol";
import {
    StreamFinalityPolicyProviderComponentsV2 as BoundPolicyComponents
} from "../../../smart-contracts/domains/finality/StreamFinalityPolicyProviderComponentsV2.sol";

interface DeferredScopedBindingVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function mockCall(address target, bytes calldata data, bytes calldata result) external;
    function mockCallRevert(address target, bytes calldata data, bytes calldata result) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
    function prank(address caller) external;
    function etch(address target, bytes calldata runtime) external;
}

/// @notice Actual deferred host constructor, pending guards and unaffected source dispatch.
/// @dev Typed source tables deliberately supply topology facts only. These cases do not claim
/// authentic publication, a successful governed binding, or full Finality/currentness execution.
contract StreamCurrentAuthorityDeferredScopedPolicyProviderV2Test {
    Native.Config private original;
    Scoped.Config private scoped;
    G.Recipe private recipe;
    GraphBinding.FactoryBinding private factoryBinding;
    O.Dependencies private origin;
    D.Dependencies private authority;
    Table private factory;
    Table private executor;
    Host private host;

    function setUp() public {
        for (uint256 i; i < 22; ++i) {
            original.targets[i] = address(new Table());
            original.codeHashes[i] = original.targets[i].codehash;
        }
        original.chainId = block.chainid;
        original.readGas = 1000000;
        original.componentSourceGas = 16000000;
        original.sourceGas = 40000000;
        original.inventoryDependencyHash = keccak256("original inventory");
        scoped = abi.decode(abi.encode(original), (Scoped.Config));
        scoped.inventoryDependencyHash = keccak256("scoped inventory");
        uint256[4] memory changes = [uint256(8), 9, 18, 19];
        for (uint256 i; i < changes.length; ++i) {
            scoped.targets[changes[i]] = address(new Table());
            scoped.codeHashes[changes[i]] = scoped.targets[changes[i]].codehash;
        }
        executor = new Table();
        _set(original.targets[1], "core()", abi.encode(original.targets[0]));
        _set(original.targets[1], "schemaRegistry()", abi.encode(original.targets[4]));
        _set(original.targets[1], "chunkStore()", abi.encode(original.targets[5]));
        _set(original.targets[1], "governanceAuthority()", abi.encode(address(executor)));
        _set(original.targets[1], "executorCodeHash()", abi.encode(address(executor).codehash));
        _set(address(executor), "isStreamGovernedParameterAuthority()", abi.encode(true));
        _set(original.targets[2], "core()", abi.encode(original.targets[0]));
        _set(original.targets[3], "core()", abi.encode(original.targets[0]));
        _set(original.targets[3], "metadataHost()", abi.encode(original.targets[1]));
        _support(original.targets[2], type(Serving).interfaceId);
        _support(original.targets[2], type(Router).interfaceId);
        for (uint256 i = 1; i < 3; ++i) {
            _set(original.targets[i], "streamModuleVersion()", abi.encode(keccak256("version")));
            _set(
                original.targets[i],
                "streamModuleManifest()",
                abi.encode("fixture://module", keccak256("manifest"))
            );
        }
        _recipe();
        _factory();
        host = new Host(original, scoped, factoryBinding);
        Table(original.targets[2])
            .set(
                abi.encodeWithSignature("supportsInterface(bytes4)", type(PolicyRoot).interfaceId),
                abi.encode(false)
            );
        _support(original.targets[2], type(ScopedRoot).interfaceId);
        Table(original.targets[2])
            .set(
                abi.encodeWithSignature("staticMetadataActivation(uint256)", uint256(1)),
                abi.encode(keccak256("activation"), uint64(1), bytes32(0))
            );
    }

    function _set(address target, string memory selector, bytes memory value) private {
        Table(target).set(abi.encodeWithSignature(selector), value);
    }

    function _support(address target, bytes4 id) private {
        Table(target)
            .set(
                abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)),
                abi.encode(true)
            );
        Table(target).set(abi.encodeCall(IERC165.supportsInterface, (id)), abi.encode(true));
        Table(target)
            .set(abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), abi.encode(false));
    }

    function _recipe() private {
        uint256[12] memory indexes = [uint256(0), 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21];
        for (uint256 i; i < 12; ++i) {
            if (i == 5 || i == 6) continue;
            recipe.inventory.targets[i] = original.targets[indexes[i]];
            recipe.inventory.codeHashes[i] = original.codeHashes[indexes[i]];
        }
        for (uint256 i; i < 5; ++i) {
            recipe.inventory.artistTargets[i] = original.targets[11];
            recipe.inventory.artistCodeHashes[i] = original.codeHashes[11];
        }
        recipe.inventory.artistContentOwner = original.targets[11];
        recipe.inventory.artistContentOwnerCodeHash = original.codeHashes[11];
        recipe.inventory.chainId = block.chainid;
        recipe.inventory.readGas = 1000000;
        recipe.inventory.sourceGas = 2000000;
        recipe.inventory.selectionGas = 2000000;
        recipe.inventory.snapshotGas = 4000000;
        recipe.inventory.referenceGas = 8000000;
        recipe.targets =
            [original.targets[3], address(new Table()), address(new Table()), address(executor)];
        for (uint256 i; i < 4; ++i) {
            recipe.codeHashes[i] = recipe.targets[i].codehash;
        }
        _set(recipe.targets[1], "core()", abi.encode(original.targets[0]));
        _set(recipe.targets[1], "metadataHost()", abi.encode(original.targets[1]));
        _set(recipe.targets[1], "metadataRouter()", abi.encode(original.targets[2]));
        _set(recipe.targets[1], "scopeMembership()", abi.encode(original.targets[3]));
        _support(recipe.targets[2], type(EntropyFactory).interfaceId);
        _set(
            recipe.targets[2],
            "scopedPolicyFactoryProfile()",
            abi.encode(keccak256("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2"))
        );
        Policies.Dependencies memory d;
        d.targets =
            [original.targets[0], original.targets[1], original.targets[3], original.targets[10]];
        for (uint256 i; i < 4; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 1000000;
        d.inventoryGas = 4000000;
        _set(recipe.targets[2], "dependencies()", abi.encode(d));
        factoryBinding.sourceFactoryDependenciesHash = keccak256(abi.encode(d));
        recipe.readinessReadGas = 1000000;
        recipe.readinessSourceGas = 2000000;
        recipe.factorySourceGas = 4000000;
        recipe.bundleReadGas = 1000000;
        recipe.bundleArchiveGas = 4000000;
        recipe.checkpointGas[0] = _gas("STATIC_CONTENT_READ_GAS", 2);
        recipe.checkpointGas[1] = _gas("STATIC_CONTENT_RENDER_GAS", 2);
        recipe.outputGas = _gas("STATIC_OUTPUT_MANIFEST_READ_GAS", 2);
        recipe.snapshotGas[0] = _gas("SCOPED_POLICY_SNAPSHOT_READ_GAS", 2);
        recipe.snapshotGas[1] = _gas("SCOPED_POLICY_SNAPSHOT_SOURCE_GAS", 2);
        recipe.snapshotGas[2] = _gas("SCOPED_POLICY_SNAPSHOT_INVENTORY_GAS", 2);
        recipe.referenceGas[0] = _gas("SCOPED_POLICY_REFERENCE_READ_GAS", 1);
        recipe.referenceGas[1] = _gas("SCOPED_POLICY_REFERENCE_SOURCE_GAS", 1);
        recipe.referenceGas[2] = _gas("SCOPED_POLICY_REFERENCE_SNAPSHOT_GAS", 1);
        recipe.referenceGas[3] = _gas("SCOPED_POLICY_REFERENCE_ARCHIVE_GAS", 1);
        origin = O.Dependencies(original.targets[11], original.codeHashes[11], 4000000, O.PROFILE);
        authority = D.Dependencies(address(0x6529A0), keccak256("future resolver"), 8000000);
    }

    function _gas(string memory name, uint8 failureClass)
        private
        pure
        returns (Gas.GasParameterConfig memory)
    {
        return Gas.GasParameterConfig(name, 4000000, 50000, failureClass);
    }

    function _factory() private {
        factory = new Table();
        factoryBinding.factory = address(factory);
        factoryBinding.factoryCodeHash = address(factory).codehash;
        factoryBinding.recipeHash = Domains.recipeHash(block.chainid, recipe, origin, authority);
        factoryBinding.graphGas = 4000000;
        _support(address(factory), type(Factory).interfaceId);
        _support(address(factory), type(OldFactory).interfaceId);
        _set(
            address(factory),
            "scopedPolicyPublicationFactoryProfile()",
            abi.encode(Domains.FACTORY_PROFILE)
        );
        _set(address(factory), "recipeHash()", abi.encode(factoryBinding.recipeHash));
        _set(
            address(factory),
            "sourceFactoryDependenciesHash()",
            abi.encode(factoryBinding.sourceFactoryDependenciesHash)
        );
        _set(address(factory), "core()", abi.encode(original.targets[0]));
        _set(address(factory), "metadataHost()", abi.encode(original.targets[1]));
        _set(address(factory), "recipe()", abi.encode(recipe));
        _set(address(factory), "originDependencies()", abi.encode(origin));
        _set(address(factory), "authorityDependencies()", abi.encode(authority));
    }

    function _collection() private pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
    }

    function _reject(bytes memory input, bytes4 selector) private view {
        (bool ok, bytes memory out) = address(host).staticcall(input);
        require(!ok && out.length >= 4 && bytes4(out) == selector, "exact pending rejection");
    }

    function testConstructorHasNoCollectionPolicyConfigAndPinsExactCapability() public view {
        require(host.deferredPolicyBindingProfile() == T.PROFILE && host.policyBindingHash() == 0);
        require(
            host.supportsInterface(type(Binding).interfaceId) && !host.supportsInterface(0xffffffff)
        );
        T.Capability memory cap = host.policyBindingCapability();
        require(
            cap.authority == address(executor)
                && cap.authorityCodeHash == address(executor).codehash
        );
        require(
            cap.originalHash == keccak256(abi.encode(original))
                && cap.scopedHash == keccak256(abi.encode(scoped))
        );
        require(cap.graphHash == host.scopedPolicyPublicationBinding().configurationHash);
        require(cap.capabilityHash == T.hashCapability(block.chainid, address(host), cap));
        require(authority.resolver.code.length == 0, "no current resolver needed before Finality");
        bytes32 expected = keccak256(
            abi.encode(
                keccak256(
                    "6529STREAM_CURRENT_AUTHORITY_DEFERRED_FINALITY_SOURCE_CONFIGURATION_SCOPED_POLICY_V2"
                ),
                block.chainid,
                address(host),
                cap,
                host.finalitySourceProfile(0),
                host.finalitySourceProfile(1),
                host.scopedPolicyPublicationBinding()
            )
        );
        require(host.finalitySourceConfigurationHash() == expected);
    }

    function testEveryCollectionPolicyGetterIsExplicitlyPending() public view {
        _reject(abi.encodeCall(host.policyConfiguration, ()), T.CollectionPolicyPending.selector);
        _reject(abi.encodeCall(host.requirePolicyBinding, ()), T.CollectionPolicyPending.selector);
        _reject(
            abi.encodeCall(host.finalitySourceProfile, (uint8(2))),
            T.CollectionPolicyPending.selector
        );
        _reject(abi.encodeCall(host.policyOutputManifestV2, ()), T.CollectionPolicyPending.selector);
        _reject(
            abi.encodeCall(host.policyOutputManifestV2CodeHash, ()),
            T.CollectionPolicyPending.selector
        );
        _reject(
            abi.encodeCall(host.policySnapshotPublicationV2, ()), T.CollectionPolicyPending.selector
        );
        _reject(
            abi.encodeCall(host.policySnapshotPublicationV2CodeHash, ()),
            T.CollectionPolicyPending.selector
        );
        _reject(
            abi.encodeCall(host.policyReferencePublicationV2, ()),
            T.CollectionPolicyPending.selector
        );
        _reject(
            abi.encodeCall(host.policyReferencePublicationV2CodeHash, ()),
            T.CollectionPolicyPending.selector
        );
    }

    function testNativeAndScopedSelectionDoNotReadPendingCatalogueSlot() public {
        Profiles.Sources memory n = host.finalitySourcesForScope(_collection());
        require(
            keccak256(abi.encode(n.profile)) == keccak256(abi.encode(host.finalitySourceProfile(0)))
        );
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 7, 0);
        Table(original.targets[2])
            .set(
                abi.encodeWithSignature(
                    "scopedContentRootHead((uint8,uint256,uint256,bytes32))", scope
                ),
                abi.encode(bytes32(0))
            );
        Profiles.Sources memory s = host.finalitySourcesForScope(scope);
        require(
            keccak256(abi.encode(s.profile)) == keccak256(abi.encode(host.finalitySourceProfile(1)))
        );
        require(host.policyBindingHash() == 0);
    }

    function testScopedPolicyGraphDispatchDoesNotReadPendingCollectionBinding() public {
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 7, 0);
        G.Graph memory graph;
        graph.scope = scope;
        graph.inventoryPlan = keccak256("original source inventory plan");
        graph.sourceSet = address(new Table());
        graph.sourceSetCodeHash = graph.sourceSet.codehash;
        graph.preparedChildren = 7;
        for (uint256 i; i < 7; ++i) {
            graph.children[i] = address(new Table());
            graph.codeHashes[i] = graph.children[i].codehash;
        }
        graph.graphId = keccak256(
            abi.encode(
                Domains.GRAPH_DOMAIN,
                block.chainid,
                address(factory),
                factoryBinding.recipeHash,
                factoryBinding.sourceFactoryDependenciesHash,
                scope,
                graph.inventoryPlan,
                graph.sourceSet,
                graph.sourceSetCodeHash
            )
        );
        factory.set(abi.encodeCall(OldFactory.requireCurrentGraph, (scope)), abi.encode(graph));
        bytes32 head = keccak256("explicit scoped policy root");
        Table(original.targets[2])
            .set(
                abi.encodeWithSignature(
                    "scopedContentRootHead((uint8,uint256,uint256,bytes32))", scope
                ),
                abi.encode(head)
            );
        ScopedRoot.Binding memory root;
        root.profileId = keccak256("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_V2");
        root.outputManifest = graph.children[2];
        root.outputManifestCodeHash = graph.codeHashes[2];
        root.checkpoint = graph.children[1];
        root.checkpointCodeHash = graph.codeHashes[1];
        root.entropySourceSet = graph.sourceSet;
        root.entropySourceSetCodeHash = graph.sourceSetCodeHash;
        root.sourceFactory = recipe.targets[2];
        root.sourceFactoryCodeHash = recipe.codeHashes[2];
        root.factoryDependenciesHash = factoryBinding.sourceFactoryDependenciesHash;
        root.snapshotProfileHash = ScopedDefinitions.PROFILE_HASH;
        Table(original.targets[2])
            .set(
                abi.encodeCall(ScopedRoot.scopedPolicyContentRootBinding, (head)), abi.encode(root)
            );
        Profiles.Sources memory actual = host.finalitySourcesForScope(scope);
        require(actual.profile.profileHash == ScopedDefinitions.PROFILE_HASH);
        require(
            actual.profile.snapshots == graph.children[3]
                && actual.profile.referenceRender == graph.children[4]
        );
        require(
            actual.profile.configurationHash
                == host.scopedPolicyPublicationBinding().configurationHash
        );
        require(host.scopedPolicySnapshotHost(scope) == graph.children[3]);
        require(host.scopedPolicySnapshotCodeHash(scope) == graph.codeHashes[3]);
        require(host.policyBindingHash() == 0);
    }

    function testUnboundPreparedEntryKeepsOriginalRegistryCallerGuard() public view {
        StreamFinalityComponentExpectation[] memory empty =
            new StreamFinalityComponentExpectation[](0);
        _reject(
            abi.encodeCall(
                host.requirePreparedFinalityScopeInputs, (_collection(), bytes32(uint256(1)), empty)
            ),
            bytes4(keccak256("NativeProviderOriginalRegistryOnly()"))
        );
    }

    function testRoleBindingFailureKeepsAllPendingAndFixedConfigurationRetryable() public {
        bytes32 fixedHash = host.finalitySourceConfigurationHash();
        Native.Config memory wrong = original;
        wrong.targets[0] = original.targets[1];
        wrong.codeHashes[0] = original.codeHashes[1];
        (bool first, bytes memory firstError) = address(host)
            .call(
                abi.encodeCall(
                    host.bindCollectionPolicy, (wrong, original.targets[6], original.codeHashes[6])
                )
            );
        (bool second, bytes memory secondError) = address(host)
            .call(
                abi.encodeCall(
                    host.bindCollectionPolicy, (wrong, original.targets[6], original.codeHashes[6])
                )
            );
        require(!first && !second && host.policyBindingHash() == 0);
        require(
            keccak256(firstError)
                == keccak256(abi.encodeWithSelector(T.InvalidCollectionPolicyBinding.selector))
        );
        require(
            keccak256(secondError) == keccak256(firstError),
            "failed mutation remains exactly retryable"
        );
        require(host.finalitySourceConfigurationHash() == fixedHash);
        _reject(abi.encodeCall(host.policyConfiguration, ()), T.CollectionPolicyPending.selector);
        Profiles.Sources memory n = host.finalitySourcesForScope(_collection());
        require(n.profile.profileHash == ProfileReads.profileHash(0));
    }

    // The fixed Validation library is an explicit typed boundary for these write-frame
    // regressions. These synthetic receipts do not establish genuine governed admission.
    function _workerVm() private pure returns (DeferredScopedBindingVm) {
        return DeferredScopedBindingVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    }

    function _workerContext() private view returns (Validation.Context memory) {
        return Validation.Context(original, host.policyBindingCapability(), origin, authority);
    }

    function _workerReceipt() private view returns (T.Receipt memory r) {
        r.capabilityHash = host.policyBindingCapability().capabilityHash;
        r.policy = original;
        for (uint256 i; i < 22; ++i) {
            r.policy.targets[i] = address(uint160(0xB000 + i));
            r.policy.codeHashes[i] = keccak256(abi.encode("bound role", i));
        }
        r.policy.readGas = 123456;
        r.policy.sourceGas = 87654321;
        r.policy.componentSourceGas = 7654321;
        r.policy.inventoryDependencyHash = keccak256("bound inventory");
        r.output = address(0xC001);
        r.outputCodeHash = keccak256("bound output");
        r.profile = T.boundProfile(
            block.chainid, address(host), r.capabilityHash, r.policy, r.output, r.outputCodeHash
        );
        r.sourceSet = address(0xC002);
        r.sourceSetCodeHash = keccak256("bound source set");
        r.scope = _collection();
        r.inventoryPlan = keccak256("bound plan");
        r.sourceFactoryDependenciesHash = keccak256("bound factory dependencies");
        r.sourceSetDataHash = keccak256("bound source data");
        r.actionId = keccak256("executed binding action");
        r.bindingHash = T.receiptHash(r);
    }

    function _workerBindInput(T.Receipt memory r) private view returns (bytes memory) {
        return abi.encodeWithSelector(
            Validation.bind.selector, _workerContext(), r.policy, r.output, r.outputCodeHash
        );
    }

    function _assertWorkerReceipt(T.Receipt memory r, bytes32 fixedHash) private view {
        require(
            keccak256(abi.encode(host.requirePolicyBinding())) == keccak256(abi.encode(r)),
            "complete receipt at original storage"
        );
        require(
            keccak256(abi.encode(host.policyConfiguration())) == keccak256(abi.encode(r.policy)),
            "all policy words retained"
        );
        require(
            keccak256(abi.encode(host.finalitySourceProfile(2)))
                == keccak256(abi.encode(r.profile)),
            "complete published profile"
        );
        require(host.policyBindingHash() == r.bindingHash);
        require(host.policyOutputManifestV2() == r.output);
        require(host.policyOutputManifestV2CodeHash() == r.outputCodeHash);
        require(host.policySnapshotPublicationV2() == r.policy.targets[8]);
        require(host.policySnapshotPublicationV2CodeHash() == r.policy.codeHashes[8]);
        require(host.policyReferencePublicationV2() == r.policy.targets[9]);
        require(host.policyReferencePublicationV2CodeHash() == r.policy.codeHashes[9]);
        require(
            host.finalitySourceConfigurationHash() == fixedHash,
            "constructor source commitment unchanged"
        );
        require(host.policyBindingCapability().capabilityHash == r.capabilityHash);
        require(
            keccak256(abi.encode(host.nativeConfiguration())) == keccak256(abi.encode(original))
        );
        require(keccak256(abi.encode(host.scopedConfiguration())) == keccak256(abi.encode(scoped)));
    }

    function testWorkerPublishesWholeReceiptAndExactOriginalEvent() public {
        T.Receipt memory r = _workerReceipt();
        bytes32 fixedHash = host.finalitySourceConfigurationHash();
        _workerVm().mockCall(address(Validation), _workerBindInput(r), abi.encode(r));
        _workerVm().recordLogs();
        host.bindCollectionPolicy(r.policy, r.output, r.outputCodeHash);
        DeferredScopedBindingVm.Log[] memory logs = _workerVm().getRecordedLogs();
        _assertWorkerReceipt(r, fixedHash);
        require(logs.length == 1 && logs[0].emitter == address(host));
        require(logs[0].topics.length == 4);
        require(
            logs[0].topics[0] == keccak256("CollectionPolicyBound(bytes32,bytes32,bytes32,bytes32)")
        );
        require(logs[0].topics[1] == r.capabilityHash && logs[0].topics[2] == r.bindingHash);
        require(logs[0].topics[3] == r.actionId);
        require(keccak256(logs[0].data) == keccak256(abi.encode(T.proposalHash(r))));
    }

    function testWorkerExactValidatorFailureRollsBackThenIdenticalInputSucceeds() public {
        T.Receipt memory r = _workerReceipt();
        bytes32 fixedHash = host.finalitySourceConfigurationHash();
        bytes memory boundary = _workerBindInput(r);
        bytes memory rejected =
            abi.encodeWithSelector(T.CollectionPolicyBindingDependency.selector, address(0xD00D));
        _workerVm().mockCallRevert(address(Validation), boundary, rejected);
        bytes memory input =
            abi.encodeCall(host.bindCollectionPolicy, (r.policy, r.output, r.outputCodeHash));
        (bool first, bytes memory reason) = address(host).call(input);
        require(!first && keccak256(reason) == keccak256(rejected));
        testEveryCollectionPolicyGetterIsExplicitlyPending();
        require(
            host.policyBindingHash() == 0 && host.finalitySourceConfigurationHash() == fixedHash
        );
        _workerVm().mockCall(address(Validation), boundary, abi.encode(r));
        (bool second, bytes memory out) = address(host).call(input);
        require(second && out.length == 0, "identical input retry after full rollback");
        _assertWorkerReceipt(r, fixedHash);
    }

    function testBoundWorkerRefusesMutationAndTransitionBeforeValidator() public {
        T.Receipt memory r = _workerReceipt();
        bytes32 fixedHash = host.finalitySourceConfigurationHash();
        _workerVm().mockCall(address(Validation), _workerBindInput(r), abi.encode(r));
        host.bindCollectionPolicy(r.policy, r.output, r.outputCodeHash);
        _workerVm().mockCallRevert(address(Validation), _workerBindInput(r), hex"decafbad");
        (bool ok, bytes memory out) = address(host)
            .call(abi.encodeCall(host.bindCollectionPolicy, (r.policy, r.output, r.outputCodeHash)));
        require(
            !ok
                && keccak256(out)
                    == keccak256(abi.encodeWithSelector(T.CollectionPolicyAlreadyBound.selector))
        );
        _reject(
            abi.encodeCall(host.bindingTransition, (r.policy, r.output, r.outputCodeHash)),
            T.CollectionPolicyAlreadyBound.selector
        );
        _assertWorkerReceipt(r, fixedHash);
    }

    function testWorkerTransitionUsesOriginalTypedContextWithoutWriting() public {
        T.Receipt memory r = _workerReceipt();
        T.Transition memory expected = T.transition(block.chainid, address(host), r);
        _workerVm()
            .mockCall(
                address(Validation),
                abi.encodeWithSelector(
                    Validation.transition.selector,
                    _workerContext(),
                    r.policy,
                    r.output,
                    r.outputCodeHash
                ),
                abi.encode(expected)
            );
        T.Transition memory result = host.bindingTransition(r.policy, r.output, r.outputCodeHash);
        require(keccak256(abi.encode(result)) == keccak256(abi.encode(expected)));
        testEveryCollectionPolicyGetterIsExplicitlyPending();
        require(host.policyBindingHash() == 0);
    }

    function testOriginalRegistryGuardPrecedesInvalidGraphScopeInBothPreparedCalls() public view {
        StreamFinalityScope memory malformed =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 0, 0, 0);
        StreamFinalityComponentExpectation[] memory entries =
            new StreamFinalityComponentExpectation[](0);
        bytes4 rejected = bytes4(keccak256("NativeProviderOriginalRegistryOnly()"));
        _reject(
            abi.encodeCall(
                host.requirePreparedFinalityScopeInputs, (malformed, bytes32(0), entries)
            ),
            rejected
        );
        _reject(
            abi.encodeCall(
                host.requirePreparedFinalityScopeInputsAndReview, (malformed, bytes32(0), entries)
            ),
            rejected
        );
    }

    function testValidationGasGetterDoesNotResolveCurrentScopedGraph() public view {
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 7, 0);
        // No current graph response is installed in this fresh constructor fixture.
        require(host.scopedPolicySnapshotValidationGas(scope) == original.componentSourceGas);
        (bool ok,) =
            address(host).staticcall(abi.encodeCall(host.scopedPolicySnapshotHost, (scope)));
        require(!ok, "actual graph still required by operative snapshot selection");
    }

    // Differential COLLECTION extraction boundary: both actual hosts execute their original
    // mode/anchor/route checks and real manifest encoder. The fixed public reader's pin,
    // component and statement results, manifest archival admission and capture review are
    // explicitly synthetic full typed boundaries. Recovery selection is also an exact typed
    // boundary; the self-call and every subsequent original Registry/Router reciprocal check
    // execute genuinely. This is not an inventory, archive or full Finality ceremony claim.
    function _fallbackStatement() private view returns (FallbackTypes.Statement memory s) {
        s.scope = _collection();
        s.coreFactsHash = keccak256("differential core facts");
        s.contentRoot = keccak256("differential content root");
        s.leafCount = 2;
        s.contentRootSchemaId = keccak256("differential root schema");
        s.snapshotManifestHash = keccak256("differential snapshot manifest");
        s.referenceRenderManifestHash = keccak256("differential reference manifest");
        s.inputs.rootRecordHash = keccak256("root record");
        s.inputs.snapshotRecordHash = keccak256("snapshot record");
        s.inputs.referenceRenderRecordHash = keccak256("reference record");
        s.inputs.intentWaiverRecordHash = keccak256("explicit intent waiver");
        s.inputs.interviewEvidenceHash = keccak256("interview evidence");
        s.inputs.rightsStatementRecordHash = keccak256("rights statement");
        s.inputs.workDescriptionRecordHash = keccak256("work description");
        s.inputs.renderCriticalEvidenceHash = keccak256("render critical evidence");
        s.inputs.bundleCoverageHash = keccak256("bundle coverage");
        s.entropyPolicy = 1;
        s.postFreezePolicy = 1;
        s.sanctionPolicy = 1;
        bytes32[9] memory families = [
            keccak256("METADATA_ROUTER"),
            keccak256("RENDERER"),
            keccak256("RENDER_CONTEXT"),
            keccak256("MEDIA_MANIFEST"),
            keccak256("SCRIPT_SOURCE"),
            keccak256("DEPENDENCY_SOURCE"),
            keccak256("COLLECTION_METADATA"),
            keccak256("ENTROPY_COORDINATOR"),
            keccak256("REFERENCE_RENDER")
        ];
        for (uint256 i; i < 9; ++i) {
            for (uint256 j = i + 1; j < 9; ++j) {
                if (families[j] < families[i]) {
                    (families[i], families[j]) = (families[j], families[i]);
                }
            }
        }
        s.nonSanctionComponents = new StreamFinalityComponentExpectation[](9);
        for (uint256 i; i < 9; ++i) {
            s.nonSanctionComponents[i] = StreamFinalityComponentExpectation(
                families[i],
                original.targets[i],
                bytes4(0x11223344),
                original.codeHashes[i],
                keccak256(abi.encode("module", i)),
                keccak256(abi.encode("manifest", i)),
                keccak256(abi.encode("data", i))
            );
        }
    }

    function _fallbackPayload(FallbackTypes.Statement memory s)
        private
        view
        returns (bytes memory)
    {
        // Independent literal encoding, compared with the unchanged production encoder on
        // both paths. No worker encoder is used to construct the expected return value.
        return abi.encode(
            FallbackSchemas.SCHEMA_ID,
            FallbackSchemas.CANON_ID,
            original.chainId,
            original.targets[0],
            original.targets[1],
            original.targets[12],
            s
        );
    }

    function _fallbackReview() private pure returns (FallbackReviewInterface.ReviewFacts memory r) {
        r.schemaVersion = 1;
        r.profile = 2;
        r.contentRoot = keccak256("differential content root");
        r.mediaContentHashes = new bytes32[](0);
        r.referenceRenderContentHashes = new bytes32[](2);
        r.referenceRenderContentHashes[0] = keccak256("first actual-boundary capture");
        r.referenceRenderContentHashes[1] = keccak256("last actual-boundary capture");
    }

    function _fallbackStatementInput(FallbackTypes.Statement memory s)
        private
        view
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            FallbackReads.statement.selector, original, s.scope, s.nonSanctionComponents
        );
    }

    function _fallbackAdmissionInput(FallbackTypes.Statement memory s)
        private
        view
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            FallbackManifest.requireCurrent.selector,
            FallbackReads.manifestDependencies(original),
            s,
            keccak256(_fallbackPayload(s))
        );
    }

    function _fallbackMode(bool onchain) private {
        Serving.ServingFacts memory f;
        f.configured = true;
        f.mode = onchain ? keccak256("ONCHAIN") : keccak256("OFFCHAIN");
        Table(original.targets[2])
            .set(abi.encodeCall(Serving.collectionServingFacts, (uint256(1))), abi.encode(f));
    }

    function _fallbackAnchor(address provider) private {
        _set(original.targets[12], "scopeEvidenceProvider()", abi.encode(provider));
        _set(original.targets[12], "scopeEvidenceProviderCodeHash()", abi.encode(provider.codehash));
    }

    function _fallbackRoutes(FallbackTypes.Statement memory s, bool corrupt) private {
        StreamFinalityCurrentComponentRoute[] memory routes =
            new StreamFinalityCurrentComponentRoute[](9);
        for (uint256 i; i < 9; ++i) {
            StreamFinalityComponentExpectation memory row = s.nonSanctionComponents[i];
            routes[i] = StreamFinalityCurrentComponentRoute(
                row.componentType, row.component, row.interfaceId, row.codeHash
            );
        }
        if (corrupt) routes[0].codeHash = keccak256("different current route");
        Table(original.targets[13])
            .set(
                abi.encodeCall(FallbackRoutes.requireCurrentRoutes, (s.scope, false)),
                abi.encode(routes)
            );
    }

    function _fallbackFixture()
        private
        returns (FallbackBase baseline, FallbackTypes.Statement memory s)
    {
        baseline = new FallbackBase(original, scoped);
        s = _fallbackStatement();
        _fallbackMode(true);
        _workerVm()
            .mockCall(
                address(FallbackReads),
                abi.encodeWithSelector(FallbackReads.requirePins.selector, original),
                bytes("")
            );
        _workerVm()
            .mockCall(
                address(FallbackReads),
                abi.encodeWithSelector(FallbackReads.currentComponents.selector, original, s.scope),
                abi.encode(s.nonSanctionComponents)
            );
        _workerVm().mockCall(address(FallbackReads), _fallbackStatementInput(s), abi.encode(s));
        _workerVm()
            .mockCall(
                address(FallbackManifest),
                _fallbackAdmissionInput(s),
                abi.encode(FallbackSchemas.SCHEMA_ID, FallbackSchemas.CANON_ID)
            );
        _workerVm()
            .mockCall(
                address(FallbackReview),
                abi.encodeWithSelector(FallbackReview.review.selector, original, s),
                abi.encode(_fallbackReview())
            );
        address[3] memory targets = [original.targets[2], original.targets[1], original.targets[12]];
        bytes32[3] memory kinds = [
            keccak256("METADATA_ROUTER"),
            keccak256("COLLECTION_METADATA"),
            keccak256("ARTWORK_FINALITY_REGISTRY")
        ];
        bytes4[3] memory ids = [
            type(Router).interfaceId,
            type(FallbackMetadata).interfaceId,
            type(FallbackRegistry).interfaceId
        ];
        for (uint256 i; i < 3; ++i) {
            _workerVm()
                .mockCall(
                    address(FallbackRecovery),
                    abi.encodeWithSelector(
                        FallbackRecovery.requireCurrentHost.selector,
                        original.targets[0],
                        kinds[i],
                        targets[i],
                        kinds[i],
                        ids[i]
                    ),
                    bytes("")
                );
        }
        _set(original.targets[12], "coreReads()", abi.encode(original.targets[0]));
        _set(original.targets[12], "metadataReads()", abi.encode(original.targets[1]));
        _set(original.targets[12], "sanctionReads()", abi.encode(original.targets[11]));
        _set(original.targets[2], "artistRegistry()", abi.encode(original.targets[11]));
        Table(original.targets[2])
            .set(
                abi.encodeWithSignature("originalFinalityAnchor(uint256)", uint256(1)),
                abi.encode(original.targets[12], original.codeHashes[12])
            );
        Serving.ArtistPresentation memory presentation;
        presentation.locked = true;
        presentation.snapshotHash = keccak256("original locked Artist presentation");
        presentation.registry = original.targets[11];
        Table(original.targets[2])
            .set(abi.encodeCall(Serving.artistPresentation, (uint256(1))), abi.encode(presentation));
        _support(original.targets[13], type(FallbackRoutes).interfaceId);
        _fallbackRoutes(s, false);
    }

    function _fallbackPair(
        FallbackBase baseline,
        bytes memory input,
        bool success,
        bytes memory expected,
        bool registryCaller
    ) private {
        address[2] memory providers = [address(baseline), address(host)];
        for (uint256 i; i < 2; ++i) {
            _fallbackAnchor(providers[i]);
            // Install reciprocal facts before prank: no argument evaluation consumes it.
            if (registryCaller) _workerVm().prank(original.targets[12]);
            (bool ok, bytes memory raw) = providers[i].staticcall(input);
            require(
                ok == success && raw.length == expected.length
                    && keccak256(raw) == keccak256(expected),
                "whole original return/revert parity"
            );
        }
        require(
            keccak256(abi.encode(host.nativeConfiguration())) == keccak256(abi.encode(original)),
            "native constructor configuration unchanged"
        );
        require(
            keccak256(abi.encode(baseline.nativeConfiguration()))
                == keccak256(abi.encode(original)),
            "baseline configuration unchanged"
        );
        require(host.policyBindingHash() == 0, "native fallback never binds deferred policy");
    }

    function testNativeFallbackMatchesUnchangedBaseManifestInputsReviewAndPreparedReturns() public {
        (FallbackBase baseline, FallbackTypes.Statement memory s) = _fallbackFixture();
        bytes memory payload = _fallbackPayload(s);
        bytes32 hash = keccak256(payload);
        bytes memory inputs =
            abi.encode(s.inputs, FallbackSchemas.SCHEMA_ID, FallbackSchemas.CANON_ID);
        _fallbackPair(
            baseline,
            abi.encodeCall(host.inputManifestBytes, (s.scope)),
            true,
            abi.encode(payload),
            false
        );
        _fallbackPair(
            baseline,
            abi.encodeCall(host.requireFinalityScopeInputs, (s.scope, hash)),
            true,
            inputs,
            false
        );
        _fallbackPair(
            baseline,
            abi.encodeCall(host.requireSanctionReviewFacts, (s.scope, hash)),
            true,
            abi.encode(_fallbackReview()),
            false
        );
        _fallbackPair(
            baseline,
            abi.encodeCall(
                host.requirePreparedFinalityScopeInputs, (s.scope, hash, s.nonSanctionComponents)
            ),
            true,
            inputs,
            true
        );
        _fallbackPair(
            baseline,
            abi.encodeCall(
                host.requirePreparedFinalityScopeInputsAndReview,
                (s.scope, hash, s.nonSanctionComponents)
            ),
            true,
            abi.encode(
                s.inputs, FallbackSchemas.SCHEMA_ID, FallbackSchemas.CANON_ID, _fallbackReview()
            ),
            true
        );
    }

    function testNativeFallbackPinsModeOriginalAnchorAndStatementKeepOriginalFailureOrder() public {
        (FallbackBase baseline, FallbackTypes.Statement memory s) = _fallbackFixture();
        bytes memory input = abi.encodeCall(host.inputManifestBytes, (s.scope));
        bytes memory pinsFailure = abi.encodeWithSelector(
            FallbackReads.NativeProviderDependency.selector, original.targets[18]
        );
        bytes memory statementFailure =
            abi.encodeWithSelector(FallbackReads.NativeProviderSource.selector);
        _workerVm()
            .mockCallRevert(
                address(FallbackReads),
                abi.encodeWithSelector(FallbackReads.requirePins.selector, original),
                pinsFailure
            );
        _workerVm()
            .mockCallRevert(address(FallbackReads), _fallbackStatementInput(s), statementFailure);
        _fallbackMode(false);
        Table(original.targets[2])
            .set(
                abi.encodeWithSignature("originalFinalityAnchor(uint256)", uint256(1)),
                abi.encode(original.targets[0], original.codeHashes[0])
            );
        _fallbackPair(baseline, input, false, pinsFailure, false);
        _workerVm()
            .mockCall(
                address(FallbackReads),
                abi.encodeWithSelector(FallbackReads.requirePins.selector, original),
                bytes("")
            );
        _fallbackPair(
            baseline, input, false, abi.encodeWithSignature("RouterProviderScope()"), false
        );
        _fallbackMode(true);
        _fallbackPair(
            baseline,
            input,
            false,
            abi.encodeWithSignature("RouterProviderAnchor(address)", original.targets[12]),
            false
        );
        Table(original.targets[2])
            .set(
                abi.encodeWithSignature("originalFinalityAnchor(uint256)", uint256(1)),
                abi.encode(original.targets[12], original.codeHashes[12])
            );
        _fallbackPair(baseline, input, false, statementFailure, false);
        _workerVm().mockCall(address(FallbackReads), _fallbackStatementInput(s), abi.encode(s));
        _fallbackPair(baseline, input, true, abi.encode(_fallbackPayload(s)), false);
    }

    function testNativeFallbackManifestAdmissionPrecedesReviewAndRestoresExactly() public {
        (FallbackBase baseline, FallbackTypes.Statement memory s) = _fallbackFixture();
        bytes32 hash = keccak256(_fallbackPayload(s));
        bytes memory admissionFailure =
            abi.encodeWithSelector(FallbackManifest.InputManifestBytes.selector, hash);
        bytes memory reviewFailure =
            abi.encodeWithSignature("DifferentialReviewRejected(bytes32)", hash);
        _workerVm()
            .mockCallRevert(address(FallbackManifest), _fallbackAdmissionInput(s), admissionFailure);
        _workerVm()
            .mockCallRevert(
                address(FallbackReview),
                abi.encodeWithSelector(FallbackReview.review.selector, original, s),
                reviewFailure
            );
        bytes memory input = abi.encodeCall(host.requireSanctionReviewFacts, (s.scope, hash));
        _fallbackPair(baseline, input, false, admissionFailure, false);
        _fallbackPair(
            baseline,
            abi.encodeCall(
                host.requirePreparedFinalityScopeInputsAndReview,
                (s.scope, hash, s.nonSanctionComponents)
            ),
            false,
            admissionFailure,
            true
        );
        _workerVm()
            .mockCall(
                address(FallbackManifest),
                _fallbackAdmissionInput(s),
                abi.encode(FallbackSchemas.SCHEMA_ID, FallbackSchemas.CANON_ID)
            );
        _fallbackPair(baseline, input, false, reviewFailure, false);
        _fallbackPair(
            baseline,
            abi.encodeCall(host.requireFinalityScopeInputs, (s.scope, hash)),
            true,
            abi.encode(s.inputs, FallbackSchemas.SCHEMA_ID, FallbackSchemas.CANON_ID),
            false
        );
        _workerVm()
            .mockCall(
                address(FallbackReview),
                abi.encodeWithSelector(FallbackReview.review.selector, original, s),
                abi.encode(_fallbackReview())
            );
        _fallbackPair(baseline, input, true, abi.encode(_fallbackReview()), false);
    }

    function testNativeFallbackPreparedOriginalRegistryAndCurrentRoutesPrecedeStatement() public {
        (FallbackBase baseline, FallbackTypes.Statement memory s) = _fallbackFixture();
        bytes32 hash = keccak256(_fallbackPayload(s));
        bytes memory input = abi.encodeCall(
            host.requirePreparedFinalityScopeInputs, (s.scope, hash, s.nonSanctionComponents)
        );
        bytes memory statementFailure =
            abi.encodeWithSelector(FallbackReads.NativeProviderSource.selector);
        _workerVm()
            .mockCallRevert(address(FallbackReads), _fallbackStatementInput(s), statementFailure);
        _fallbackRoutes(s, true);
        _fallbackPair(
            baseline,
            input,
            false,
            abi.encodeWithSignature("NativeProviderOriginalRegistryOnly()"),
            false
        );
        _fallbackPair(
            baseline,
            abi.encodeCall(
                host.requirePreparedFinalityScopeInputsAndReview,
                (s.scope, hash, s.nonSanctionComponents)
            ),
            false,
            abi.encodeWithSignature("NativeProviderOriginalRegistryOnly()"),
            false
        );
        _fallbackPair(
            baseline,
            input,
            false,
            abi.encodeWithSignature("FinalityRoutesMismatch(uint256)", uint256(0)),
            true
        );
        _fallbackRoutes(s, false);
        _fallbackPair(baseline, input, false, statementFailure, true);
        _workerVm().mockCall(address(FallbackReads), _fallbackStatementInput(s), abi.encode(s));
        _fallbackPair(
            baseline,
            input,
            true,
            abi.encode(s.inputs, FallbackSchemas.SCHEMA_ID, FallbackSchemas.CANON_ID),
            true
        );
    }

    /// @dev Exact whole-Config fixed-library boundary for the unchanged scoped operation
    /// producer. Only dispatch/config/tuple projection is claimed here: all source admission
    /// inside the scoped worker remains outside this test. The host's actual graph selection
    /// executes against the typed Router table and must observe an exact zero root head.
    function _scopedFallbackMocks(StreamFinalityScope memory scope)
        private
        returns (bytes memory payload, bytes32 hash)
    {
        payload = abi.encode("synthetic original scoped operation bytes", scope);
        hash = keccak256(payload);
        FallbackTypes.Statement memory value = _fallbackStatement();
        FallbackReviewInterface.ReviewFacts memory review = _fallbackReview();
        FallbackReviewInterface.ReviewFacts memory noReview;
        bytes32 schema = keccak256("scoped operation boundary schema");
        bytes32 canon = keccak256("scoped operation boundary canon");
        _workerVm()
            .mockCall(
                address(ScopedFallbackOperations),
                abi.encodeWithSelector(ScopedFallbackOperations.manifest.selector, scoped, scope),
                abi.encode(payload)
            );
        _workerVm()
            .mockCall(
                address(ScopedFallbackOperations),
                abi.encodeWithSelector(
                    ScopedFallbackOperations.inputs.selector, scoped, scope, hash
                ),
                abi.encode(value.inputs, schema, canon)
            );
        _workerVm()
            .mockCall(
                address(ScopedFallbackOperations),
                abi.encodeWithSelector(
                    ScopedFallbackOperations.review.selector, scoped, scope, hash
                ),
                abi.encode(review)
            );
        _workerVm()
            .mockCall(
                address(ScopedFallbackOperations),
                abi.encodeWithSelector(
                    ScopedFallbackOperations.prepared.selector,
                    scoped,
                    scope,
                    hash,
                    value.nonSanctionComponents,
                    false
                ),
                abi.encode(value.inputs, schema, canon, noReview)
            );
        _workerVm()
            .mockCall(
                address(ScopedFallbackOperations),
                abi.encodeWithSelector(
                    ScopedFallbackOperations.prepared.selector,
                    scoped,
                    scope,
                    hash,
                    value.nonSanctionComponents,
                    true
                ),
                abi.encode(value.inputs, schema, canon, review)
            );
    }

    function _scopedFallbackZeroHead(StreamFinalityScope memory scope) private {
        Table(original.targets[2])
            .set(
                abi.encodeCall(ScopedFallbackRoot.scopedContentRootHead, (scope)),
                abi.encode(bytes32(0))
            );
    }

    function testScopedFallbackPreservesExactOriginalConfigAndAllFiveOperationProjections() public {
        FallbackBase baseline = new FallbackBase(original, scoped);
        require(
            keccak256(abi.encode(original)) != keccak256(abi.encode(scoped)),
            "different original and scoped configurations"
        );
        StreamFinalityScope[3] memory scopes = [
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 7, bytes32(0)),
            StreamFinalityScope(StreamFinalityScopeType.RELEASE, 1, 0, keccak256("release")),
            StreamFinalityScope(StreamFinalityScopeType.SEASON, 1, 0, keccak256("season"))
        ];
        FallbackTypes.Statement memory value = _fallbackStatement();
        bytes32 schema = keccak256("scoped operation boundary schema");
        bytes32 canon = keccak256("scoped operation boundary canon");
        for (uint256 i; i < scopes.length; ++i) {
            StreamFinalityScope memory scope = scopes[i];
            _scopedFallbackZeroHead(scope);
            (bytes memory payload, bytes32 hash) = _scopedFallbackMocks(scope);
            _fallbackPair(
                baseline,
                abi.encodeCall(host.inputManifestBytes, (scope)),
                true,
                abi.encode(payload),
                false
            );
            _fallbackPair(
                baseline,
                abi.encodeCall(host.requireFinalityScopeInputs, (scope, hash)),
                true,
                abi.encode(value.inputs, schema, canon),
                false
            );
            _fallbackPair(
                baseline,
                abi.encodeCall(host.requireSanctionReviewFacts, (scope, hash)),
                true,
                abi.encode(_fallbackReview()),
                false
            );
            _fallbackPair(
                baseline,
                abi.encodeCall(
                    host.requirePreparedFinalityScopeInputs,
                    (scope, hash, value.nonSanctionComponents)
                ),
                true,
                abi.encode(value.inputs, schema, canon),
                true
            );
            _fallbackPair(
                baseline,
                abi.encodeCall(
                    host.requirePreparedFinalityScopeInputsAndReview,
                    (scope, hash, value.nonSanctionComponents)
                ),
                true,
                abi.encode(value.inputs, schema, canon, _fallbackReview()),
                true
            );
        }
        require(
            keccak256(abi.encode(host.scopedConfiguration())) == keccak256(abi.encode(scoped)),
            "host scoped configuration retained"
        );
        require(
            keccak256(abi.encode(baseline.scopedConfiguration())) == keccak256(abi.encode(scoped)),
            "base scoped configuration retained"
        );
    }

    function testScopedFallbackCanonicalCoordinatesPrecedeSelectionAndMockedOperations() public {
        FallbackBase baseline = new FallbackBase(original, scoped);
        StreamFinalityScope[3] memory malformed = [
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 0, bytes32(0)),
            StreamFinalityScope(StreamFinalityScopeType.RELEASE, 1, 7, keccak256("release")),
            StreamFinalityScope(StreamFinalityScopeType.SEASON, 1, 0, bytes32(0))
        ];
        // Even an invalid advertised graph capability cannot precede canonical coordinates.
        // Installing successful invalid-scope operation mocks makes bypassing either host's
        // own canonical guard a false success, rather than an incidental producer failure.
        Table(original.targets[2])
            .set(
                abi.encodeCall(IERC165.supportsInterface, (type(ScopedRoot).interfaceId)),
                abi.encode(false)
            );
        for (uint256 i; i < malformed.length; ++i) {
            (, bytes32 hash) = _scopedFallbackMocks(malformed[i]);
            bytes memory rejected = abi.encodeWithSignature("InvalidMetadataScope()");
            _fallbackPair(
                baseline,
                abi.encodeCall(host.inputManifestBytes, (malformed[i])),
                false,
                rejected,
                false
            );
            _fallbackPair(
                baseline,
                abi.encodeCall(host.requireFinalityScopeInputs, (malformed[i], hash)),
                false,
                rejected,
                false
            );
            _fallbackPair(
                baseline,
                abi.encodeCall(host.requireSanctionReviewFacts, (malformed[i], hash)),
                false,
                rejected,
                false
            );
        }
        StreamFinalityScope memory valid =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 7, bytes32(0));
        _scopedFallbackZeroHead(valid);
        (bytes memory payload,) = _scopedFallbackMocks(valid);
        // The combined host retains its earlier graph-selection admission. The original base
        // has no such selection gate; successful scoped operation mocks do not waive it.
        bytes memory input = abi.encodeCall(host.inputManifestBytes, (valid));
        (bool ok, bytes memory raw) = address(host).staticcall(input);
        bytes memory expected =
            abi.encodeWithSignature("ScopedPolicyGraphSource(address)", original.targets[2]);
        require(
            !ok && raw.length == expected.length && keccak256(raw) == keccak256(expected),
            "existing selection gate precedes scoped fallback"
        );
        _support(original.targets[2], type(ScopedRoot).interfaceId);
        _fallbackPair(baseline, input, true, abi.encode(payload), false);
    }

    // Graph-current and the two local fact producers are explicit, exact typed boundaries.
    // Actual host graph selection, original runtime pins, membership admission, family check
    // and constructor module-identity projection execute. No factory deployment/currentness,
    // metadata sealing or STATIC publication readiness is asserted by these isolated tests.
    function _componentGraphFixture()
        private
        returns (
            ComponentGraph.Context memory context,
            ComponentConfig.Config memory configured,
            StreamFinalityScope memory scope
        )
    {
        _set(
            original.targets[1],
            "streamModuleVersion()",
            abi.encode(keccak256("distinct metadata version"))
        );
        _set(
            original.targets[1],
            "streamModuleManifest()",
            abi.encode("fixture://distinct-metadata", keccak256("distinct metadata manifest"))
        );
        _set(
            original.targets[2],
            "streamModuleVersion()",
            abi.encode(keccak256("distinct router version"))
        );
        _set(
            original.targets[2],
            "streamModuleManifest()",
            abi.encode("fixture://distinct-router", keccak256("distinct router manifest"))
        );
        host = new Host(original, scoped, factoryBinding);
        context.original = original;
        context.binding = host.scopedPolicyPublicationBinding();
        context.recipe = recipe;
        context.origin = origin;
        context.authority = authority;
        scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 7, bytes32(0));
        configured.targets = original.targets;
        configured.codeHashes = original.codeHashes;
        configured.chainId = original.chainId;
        configured.readGas = original.readGas;
        configured.sourceGas = original.sourceGas;
        configured.componentSourceGas = original.componentSourceGas;
        configured.inventoryDependencyHash = keccak256("typed selected graph inventory");
        for (uint256 i = 6; i <= 10; ++i) {
            configured.targets[i] = address(new Table());
            configured.codeHashes[i] = configured.targets[i].codehash;
        }
        bytes32 head = keccak256("typed selected graph root");
        Table(original.targets[2])
            .set(
                abi.encodeCall(ScopedFallbackRoot.scopedContentRootHead, (scope)), abi.encode(head)
            );
        ScopedRoot.Binding memory root;
        root.profileId = keccak256("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_V2");
        root.outputManifest = configured.targets[6];
        root.outputManifestCodeHash = configured.codeHashes[6];
        root.checkpoint = configured.targets[7];
        root.checkpointCodeHash = configured.codeHashes[7];
        Table(original.targets[2])
            .set(
                abi.encodeCall(ScopedRoot.scopedPolicyContentRootBinding, (head)), abi.encode(root)
            );
        _componentGraphCurrent(context, configured, scope);
        _workerVm()
            .mockCall(
                address(ComponentMetadata),
                abi.encodeWithSelector(ComponentMetadata.facts.selector, configured, scope),
                abi.encode(true, keccak256("typed graph metadata facts"))
            );
        _workerVm()
            .mockCall(
                address(ComponentStatic),
                abi.encodeWithSelector(
                    ComponentStatic.facts.selector, configured, scope, keccak256("RENDERER")
                ),
                abi.encode(false, keccak256("typed graph static facts"))
            );
    }

    function _componentGraphCurrent(
        ComponentGraph.Context memory context,
        ComponentConfig.Config memory configured,
        StreamFinalityScope memory scope
    ) private {
        G.Graph memory graph;
        graph.scope = scope;
        graph.graphId = keccak256("typed complete graph projection");
        graph.preparedChildren = 7;
        _workerVm()
            .mockCall(
                address(ComponentGraph),
                abi.encodeWithSelector(ComponentGraph.current.selector, context, scope),
                abi.encode(configured, graph)
            );
    }

    function _componentMembership(StreamFinalityScope memory scope, bool valid) private {
        StreamScopeMembershipFacts memory facts;
        facts.scopeSubject = valid
            ? ComponentSubjects.scopeSubject(original.chainId, original.targets[0], scope)
            : keccak256("different scope subject");
        facts.membershipHash = keccak256("actual boundary membership commitment");
        facts.tokenCount = 1;
        Table(original.targets[3])
            .set(
                abi.encodeWithSignature(
                    "requireScopeMembership((uint8,uint256,uint256,bytes32))", scope
                ),
                abi.encode(facts)
            );
    }

    function _componentFactsCall(
        bytes32 family,
        StreamFinalityScope memory scope,
        bool success,
        bytes memory expected
    ) private view {
        (bool ok, bytes memory raw) = address(host)
            .staticcall(abi.encodeCall(host.finalityComponentFacts, (family, scope)));
        require(
            ok == success && raw.length == expected.length && keccak256(raw) == keccak256(expected),
            "exact graph component result/refusal"
        );
    }

    function _componentExpected(bool metadata) private pure returns (bytes memory) {
        StreamFinalityHostComponentFacts memory f;
        f.frozen = metadata;
        f.dataHash = metadata
            ? keccak256("typed graph metadata facts")
            : keccak256("typed graph static facts");
        f.moduleVersion = metadata
            ? keccak256("distinct metadata version")
            : keccak256("distinct router version");
        f.manifestHash = metadata
            ? keccak256("distinct metadata manifest")
            : keccak256("distinct router manifest");
        return abi.encode(f);
    }

    function testGraphFactsCurrentMembershipAndFamilyChecksRetainOriginalOrder() public {
        (
            ComponentGraph.Context memory context,
            ComponentConfig.Config memory configured,
            StreamFinalityScope memory scope
        ) = _componentGraphFixture();
        bytes32 unsupported = keccak256("unsupported graph component family");
        bytes memory graphFailure = abi.encodeWithSelector(
            ComponentGraph.ScopedPolicyGraphSource.selector, address(factory)
        );
        _workerVm()
            .mockCallRevert(
                address(ComponentGraph),
                abi.encodeWithSelector(ComponentGraph.current.selector, context, scope),
                graphFailure
            );
        _componentFactsCall(unsupported, scope, false, graphFailure);
        _componentGraphCurrent(context, configured, scope);
        _componentFactsCall(
            unsupported,
            scope,
            false,
            abi.encodeWithSignature(
                "RouterEvidenceRead(address,bytes4)",
                original.targets[3],
                bytes4(keccak256("requireScopeMembership((uint8,uint256,uint256,bytes32))"))
            )
        );
        _componentMembership(scope, false);
        _componentFactsCall(
            unsupported, scope, false, abi.encodeWithSignature("RouterProviderScope()")
        );
        _componentMembership(scope, true);
        _componentFactsCall(
            unsupported,
            scope,
            false,
            abi.encodeWithSignature("RouterEvidenceFamily(bytes32)", unsupported)
        );
        _componentFactsCall(keccak256("COLLECTION_METADATA"), scope, true, _componentExpected(true));
        _componentFactsCall(keccak256("RENDERER"), scope, true, _componentExpected(false));
    }

    function testGraphFactsRetainOriginalPinsDistinctModuleIdentitiesAndComponentScopeCap() public {
        (,, StreamFinalityScope memory scope) = _componentGraphFixture();
        _componentMembership(scope, true);
        bytes memory runtime = original.targets[1].code;
        _workerVm().etch(original.targets[1], hex"60006000fd");
        _componentFactsCall(
            keccak256("COLLECTION_METADATA"),
            scope,
            false,
            abi.encodeWithSignature("RouterProviderDependency(address)", original.targets[1])
        );
        _workerVm().etch(original.targets[1], runtime);
        _componentFactsCall(keccak256("COLLECTION_METADATA"), scope, true, _componentExpected(true));
        _componentFactsCall(keccak256("RENDERER"), scope, true, _componentExpected(false));
        // Isolated forwarding regression only: synthetic deep graph/fact producers make this
        // bound feasible. It cannot satisfy RouterEvidence's reservation if membership is
        // accidentally read with original.sourceGas (40m), instead of componentSourceGas (16m).
        // This is not measured full-graph, cold-state or transaction-limit acceptance.
        uint256 cap = original.componentSourceGas + 3000000;
        require(cap < original.sourceGas, "fixture distinguishes outer and component budgets");
        (bool ok, bytes memory raw) = address(host).staticcall{ gas: cap }(
            abi.encodeCall(host.finalityComponentFacts, (keccak256("RENDERER"), scope))
        );
        bytes memory expected = _componentExpected(false);
        require(
            ok && raw.length == expected.length && keccak256(raw) == keccak256(expected),
            "original component scope cap retained"
        );
        require(
            host.policyBindingHash() == 0, "graph facts never consume deferred collection binding"
        );
    }

    function _boundComponentSelection(T.Receipt memory r) private {
        BoundComponentSelection.Context memory c;
        c.core = original.targets[0];
        c.router = original.targets[2];
        c.routerCodeHash = original.codeHashes[2];
        c.chainId = original.chainId;
        c.readGas = original.readGas;
        c.policyOutput = r.output;
        c.policyOutputCodeHash = r.outputCodeHash;
        c.profiles[0] = host.finalitySourceProfile(0);
        c.profiles[1] = host.finalitySourceProfile(1);
        c.profiles[2] = r.profile;
        c.policyBound = true;
        _workerVm()
            .mockCall(
                address(BoundComponentSelection),
                abi.encodeWithSelector(BoundComponentSelection.current.selector, c, r.scope),
                abi.encode(Profiles.Sources(r.scope, r.profile))
            );
    }

    function _boundComponentExpected(bool metadata) private pure returns (bytes memory) {
        StreamFinalityHostComponentFacts memory f;
        f.frozen = metadata;
        f.dataHash = metadata
            ? keccak256("typed bound policy metadata facts")
            : keccak256("typed bound policy static facts");
        f.moduleVersion = metadata
            ? keccak256("distinct metadata version")
            : keccak256("distinct router version");
        f.manifestHash = metadata
            ? keccak256("distinct metadata manifest")
            : keccak256("distinct router manifest");
        return abi.encode(f);
    }

    /// @dev The genuine bind write-frame consumes an explicitly mocked complete Validation
    /// result. Selection.current and PolicyComponents.facts are exact typed producer boundaries;
    /// no policy publication or governance validity is claimed. Original pins/membership/family
    /// admission and all four original module-identity projections remain real host/worker code.
    function testBoundPolicyFactsPreserveOriginalAdmissionIdentityAndCompleteBindingReceipt()
        public
    {
        _componentGraphFixture(); // Distinct original metadata/router identities; no collection membership installed.
        T.Receipt memory r = _workerReceipt();
        bytes32 fixedHash = host.finalitySourceConfigurationHash();
        _workerVm().mockCall(address(Validation), _workerBindInput(r), abi.encode(r));
        host.bindCollectionPolicy(r.policy, r.output, r.outputCodeHash);
        _assertWorkerReceipt(r, fixedHash);
        _boundComponentSelection(r);
        bytes32 metadata = keccak256("COLLECTION_METADATA");
        bytes32 renderer = keccak256("RENDERER");
        bytes32 unsupported = keccak256("unsupported bound policy component");
        _workerVm()
            .mockCall(
                address(BoundPolicyComponents),
                abi.encodeWithSelector(
                    BoundPolicyComponents.facts.selector, r.policy, r.scope, metadata
                ),
                abi.encode(true, keccak256("typed bound policy metadata facts"))
            );
        _workerVm()
            .mockCall(
                address(BoundPolicyComponents),
                abi.encodeWithSelector(
                    BoundPolicyComponents.facts.selector, r.policy, r.scope, renderer
                ),
                abi.encode(false, keccak256("typed bound policy static facts"))
            );
        // A successful invalid-family producer result must not waive the host family guard.
        _workerVm()
            .mockCall(
                address(BoundPolicyComponents),
                abi.encodeWithSelector(
                    BoundPolicyComponents.facts.selector, r.policy, r.scope, unsupported
                ),
                abi.encode(true, keccak256("unreachable unsupported family facts"))
            );
        _componentFactsCall(
            unsupported,
            r.scope,
            false,
            abi.encodeWithSignature(
                "RouterEvidenceRead(address,bytes4)",
                original.targets[3],
                bytes4(keccak256("requireScopeMembership((uint8,uint256,uint256,bytes32))"))
            )
        );
        _componentMembership(r.scope, false);
        _componentFactsCall(
            unsupported, r.scope, false, abi.encodeWithSignature("RouterProviderScope()")
        );
        _componentMembership(r.scope, true);
        _componentFactsCall(
            unsupported,
            r.scope,
            false,
            abi.encodeWithSignature("RouterEvidenceFamily(bytes32)", unsupported)
        );
        _assertWorkerReceipt(r, fixedHash);
        bytes memory runtime = original.targets[1].code;
        _workerVm().etch(original.targets[1], hex"60006000fd");
        _componentFactsCall(
            metadata,
            r.scope,
            false,
            abi.encodeWithSignature("RouterProviderDependency(address)", original.targets[1])
        );
        _workerVm().etch(original.targets[1], runtime);
        _componentFactsCall(metadata, r.scope, true, _boundComponentExpected(true));
        _componentFactsCall(renderer, r.scope, true, _boundComponentExpected(false));
        _assertWorkerReceipt(r, fixedHash);
    }
}
