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

    function testFailedRoleBindingKeepsAllPendingAndFixedConfigurationRetryable() public {
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
}
