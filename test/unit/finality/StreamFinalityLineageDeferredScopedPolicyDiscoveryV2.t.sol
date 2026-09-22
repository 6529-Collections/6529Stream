// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamFinalityLineageDiscovery.t.sol";
import {
    StreamFinalityLineageDeferredScopedPolicyDiscoveryV2 as ScopedDiscovery
} from "../../../smart-contracts/domains/finality/StreamFinalityLineageDeferredScopedPolicyDiscoveryV2.sol";
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

import {
    IStreamCurrentAuthorityDeferredPolicyBindingV2 as DeferredBinding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamCurrentAuthorityDeferredPolicyBindingV2.sol";
import {
    StreamCurrentAuthorityDeferredPolicyBindingTypesV2 as Deferred
} from "../../../smart-contracts/interfaces/stream/finality/StreamCurrentAuthorityDeferredPolicyBindingTypesV2.sol";

import {
    StreamFinalityLineageDeferredScopedPolicySelectionV2 as LineageSelection
} from "../../../smart-contracts/domains/finality/StreamFinalityLineageDeferredScopedPolicySelectionV2.sol";

interface DeferredScopedLineageVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function mockCallRevert(address target, bytes calldata input, bytes calldata output) external;
}

/// @dev Production discovery and FactoryReads execute against explicit typed source/Finality
/// tables. Only GraphReads.bindings(r,od,ad,false) is mocked at its exact linked-library ABI;
/// this isolates constructor-graph admission, not seven-child deployment or source validity.
/// Recipe validation, canonical getters, graph IDs, reference pins, original profile semantics,
/// and deferred Discovery receipt admission execute genuinely. Deferred receipts are synthetic
/// typed provider boundaries and do not establish Executor authorization or one-time state.
/// Core selection and current sanction route checks are real. No 55/60 or gas claim is made.
contract StreamFinalityLineageDeferredScopedPolicyDiscoveryV2Test is LineageDiscoveryFixture {
    DeferredScopedLineageVm private constant scopedVm =
        DeferredScopedLineageVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    ScopedDiscovery private scoped;
    FactoryBinding.FactoryBinding private binding;
    Graph.Recipe private recipe;
    Origin.Dependencies private origin;
    Capture.Dependencies private capture;
    Profiles.Profile[3] private catalog;
    Profiles.Profile private selected;
    Graph.Graph private graph;
    bytes32 private SOURCES;
    Deferred.Capability private capability;
    Deferred.Receipt private receipt;

    function setUp() public override {
        super.setUp();
        c.readGas = 500000;
        c.componentGas = 8000000;
        c.entropyGas = 4000000;
        _catalog();
        _factory();
        _capability();
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

    function _capability() private {
        capability = Deferred.Capability(
            recipe.targets[3],
            recipe.codeHashes[3],
            catalog[0].configurationHash,
            catalog[1].configurationHash,
            binding.configurationHash,
            bytes32(0)
        );
        capability.capabilityHash = Deferred.hashCapability(block.chainid, c.provider, capability);
        SOURCES = keccak256(
            abi.encode(
                keccak256(
                    "6529STREAM_CURRENT_AUTHORITY_DEFERRED_FINALITY_SOURCE_CONFIGURATION_SCOPED_POLICY_V2"
                ),
                block.chainid,
                c.provider,
                capability,
                catalog[0],
                catalog[1],
                binding
            )
        );
        _put(
            c.provider,
            abi.encodeCall(Profiles.finalitySourceConfigurationHash, ()),
            abi.encode(SOURCES)
        );
        _support(c.provider, type(DeferredBinding).interfaceId);
        _put(
            c.provider,
            abi.encodeCall(DeferredBinding.deferredPolicyBindingProfile, ()),
            abi.encode(Deferred.PROFILE)
        );
        _put(
            c.provider,
            abi.encodeCall(DeferredBinding.policyBindingCapability, ()),
            abi.encode(capability)
        );
        _put(
            c.provider,
            abi.encodeCall(DeferredBinding.policyBindingHash, ()),
            abi.encode(bytes32(0))
        );
        _address(c.metadata, "governanceAuthority()", capability.authority);
        _put(
            c.metadata,
            abi.encodeWithSignature("executorCodeHash()"),
            abi.encode(capability.authorityCodeHash)
        );
        // No profile2 or receipt getter exists in the pending fixture.
    }

    /// @dev Synthetic bound receipt only: real Executor single-use admission is a separate host cohort.
    function _bindPolicyBoundary() private {
        receipt.capabilityHash = capability.capabilityHash;
        receipt.policy.chainId = block.chainid;
        receipt.policy.readGas = c.readGas;
        receipt.policy.sourceGas = 16000000;
        receipt.policy.componentSourceGas = 6000000;
        receipt.policy.inventoryDependencyHash =
            keccak256("actual inventory configuration boundary");
        for (uint256 i; i < 22; ++i) {
            receipt.policy.targets[i] = _new();
        }
        receipt.policy.targets[0] = c.core;
        receipt.policy.targets[1] = c.metadata;
        receipt.policy.targets[2] = c.router;
        receipt.policy.targets[3] = c.membership;
        receipt.policy.targets[11] = c.artist;
        receipt.policy.targets[12] = c.finalityRegistry;
        receipt.policy.targets[13] = address(scoped);
        for (uint256 i; i < 22; ++i) {
            receipt.policy.codeHashes[i] = receipt.policy.targets[i].codehash;
        }
        receipt.output = _new();
        receipt.outputCodeHash = receipt.output.codehash;
        receipt.sourceSet = _new();
        receipt.sourceSetCodeHash = receipt.sourceSet.codehash;
        receipt.scope = scope;
        receipt.inventoryPlan = keccak256("complete original collection inventory");
        receipt.sourceFactoryDependenciesHash =
            keccak256("closed original policy factory dependencies");
        receipt.sourceSetDataHash = keccak256("retained original full policy source");
        receipt.actionId = keccak256("synthetic executed binding action receipt");
        receipt.profile = Deferred.boundProfile(
            block.chainid,
            c.provider,
            receipt.capabilityHash,
            receipt.policy,
            receipt.output,
            receipt.outputCodeHash
        );
        receipt.bindingHash = Deferred.receiptHash(receipt);
        _receiptValue();
        selected = receipt.profile;
        _source();
        _address(receipt.output, "core()", c.core);
        address checkpoint = _new();
        _address(receipt.output, "contentCheckpoint()", checkpoint);
        _address(checkpoint, "entropySourceSet()", receipt.sourceSet);
        _address(receipt.sourceSet, "core()", c.core);
        _address(receipt.sourceSet, "factory()", receipt.profile.entropyFactory);
        _put(
            receipt.sourceSet,
            abi.encodeWithSignature("inventoryPlan()"),
            abi.encode(receipt.inventoryPlan)
        );
        _put(
            receipt.sourceSet,
            abi.encodeWithSignature("sourceSetDataHash()"),
            abi.encode(receipt.sourceSetDataHash)
        );
        _put(receipt.sourceSet, abi.encodeWithSignature("sourceScope()"), abi.encode(scope));
        _address(selected.snapshots, "core()", c.core);
        _address(selected.snapshots, "metadataHost()", c.metadata);
        _address(selected.referenceRender, "core()", c.core);
        _address(selected.referenceRender, "metadataHost()", c.metadata);
        _address(selected.referenceRender, "metadataRouter()", c.router);
        _address(selected.referenceRender, "snapshots()", selected.snapshots);
        _address(selected.entropyFactory, "core()", c.core);
        _address(selected.entropyFactory, "metadataHost()", c.metadata);
        _address(selected.entropyFactory, "scopeMembershipHost()", c.membership);
        _support(selected.referenceRender, type(IStreamArtworkFinalityComponent).interfaceId);
        _support(selected.referenceRender, type(IStreamArtworkScopedFinalityComponent).interfaceId);
        _support(selected.entropyFactory, type(IStreamFinalityEntropySourceFactory).interfaceId);
        _support(selected.entropyFactory, type(IStreamFinalityCurrentEntropyRoute).interfaceId);
        _put(
            selected.entropyFactory,
            abi.encodeCall(IStreamFinalityCurrentEntropyRoute.requireCurrentRoute, (scope)),
            abi.encode(
                StreamFinalityCurrentComponentRoute(
                    keccak256("ENTROPY_COORDINATOR"),
                    address(entropy),
                    type(IStreamArtworkFinalityComponent).interfaceId,
                    address(entropy).codehash
                )
            )
        );
        _record(selected.referenceRender, keccak256("REFERENCE_RENDER"), true);
        _staticServing(true);
        _sign();
    }

    function _receiptValue() private {
        _put(
            c.provider,
            abi.encodeCall(DeferredBinding.requirePolicyBinding, ()),
            abi.encode(receipt)
        );
        _put(
            c.provider,
            abi.encodeCall(DeferredBinding.policyBindingHash, ()),
            abi.encode(receipt.bindingHash)
        );
    }

    function _refreshReceipt() private {
        receipt.profile = Deferred.boundProfile(
            block.chainid,
            c.provider,
            receipt.capabilityHash,
            receipt.policy,
            receipt.output,
            receipt.outputCodeHash
        );
        receipt.bindingHash = Deferred.receiptHash(receipt);
        _receiptValue();
        selected = receipt.profile;
        _source();
    }

    function testDeferredCapabilityAndSourceDomainRejectStrictOrChangedProfiles() public {
        _put(
            c.provider,
            abi.encodeCall(DeferredBinding.deferredPolicyBindingProfile, ()),
            abi.encode(bytes32(0))
        );
        vm.expectRevert(
            abi.encodeWithSelector(ScopedDiscovery.DiscoveryConfiguration.selector, c.provider)
        );
        new ScopedDiscovery(c, SOURCES, binding);
        _put(
            c.provider,
            abi.encodeCall(DeferredBinding.deferredPolicyBindingProfile, ()),
            abi.encode(Deferred.PROFILE)
        );
        Deferred.Capability memory wrong = capability;
        wrong.originalHash = keccak256("changed original profile");
        wrong.capabilityHash = Deferred.hashCapability(block.chainid, c.provider, wrong);
        _put(
            c.provider,
            abi.encodeCall(DeferredBinding.policyBindingCapability, ()),
            abi.encode(wrong)
        );
        vm.expectRevert(
            abi.encodeWithSelector(ScopedDiscovery.DiscoveryConfiguration.selector, c.provider)
        );
        new ScopedDiscovery(c, SOURCES, binding);
        _put(
            c.provider,
            abi.encodeCall(DeferredBinding.policyBindingCapability, ()),
            abi.encode(capability)
        );
        bytes32 other = keccak256("strict source hash is not deferred capability domain");
        _put(
            c.provider,
            abi.encodeCall(Profiles.finalitySourceConfigurationHash, ()),
            abi.encode(other)
        );
        vm.expectRevert(
            abi.encodeWithSelector(ScopedDiscovery.DiscoveryConfiguration.selector, c.provider)
        );
        new ScopedDiscovery(c, other, binding);
    }

    function testPendingReceiptIsExactAndNativeDoesNotReadIt() public {
        selected.profileHash = ProfileReads.profileHash(2);
        _source();
        scopedVm.mockCallRevert(
            c.provider,
            abi.encodeCall(DeferredBinding.requirePolicyBinding, ()),
            abi.encodeWithSelector(Deferred.CollectionPolicyPending.selector)
        );
        vm.expectRevert(abi.encodeWithSelector(Deferred.CollectionPolicyPending.selector));
        scoped.finalityComponentCount(1);
        selected = catalog[0];
        _source();
        require(
            scoped.finalityComponentCount(1) == 10 && scoped.sourceConfigurationHash() == SOURCES
        );
    }

    function testPendingSourceSelectionBubblesOnlySharedFourByteError() public {
        bytes memory input = abi.encodeCall(Profiles.finalitySourcesForScope, (scope));
        scopedVm.mockCallRevert(
            c.provider, input, abi.encodeWithSelector(Deferred.CollectionPolicyPending.selector)
        );
        vm.expectRevert(abi.encodeWithSelector(Deferred.CollectionPolicyPending.selector));
        scoped.finalityComponentCount(1);
        scopedVm.mockCallRevert(
            c.provider,
            input,
            abi.encodeWithSelector(Deferred.CollectionPolicyAlreadyBound.selector)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityRouterEvidence.RouterEvidenceRead.selector,
                c.provider,
                Profiles.finalitySourcesForScope.selector
            )
        );
        scoped.finalityComponentCount(1);
    }

    function testBoundCollectionPolicyUsesExactReceiptAcrossBThenUnpredictedC() public {
        _bindPolicyBoundary();
        _assertCurrent();
        require(
            scoped.dependencyCodeHash(selected.referenceRender) == 0
                && scoped.dependencyCodeHash(selected.entropyFactory) == 0
        );
        bytes32 savedBinding = receipt.bindingHash;
        _successor(_new());
        _sign();
        _assertCurrent();
        require(
            receipt.bindingHash == savedBinding && scoped.sourceConfigurationHash() == SOURCES
                && scoped.configuration().artist == c.artist
        );
    }

    function testBoundReceiptRequiresExactScopeActionCapabilityAndCommitment() public {
        _bindPolicyBoundary();
        Deferred.Receipt memory saved = receipt;
        receipt.scope.collectionId = 2;
        receipt.bindingHash = Deferred.receiptHash(receipt);
        _receiptValue();
        vm.expectRevert(
            abi.encodeWithSelector(ScopedDiscovery.DiscoveryConfiguration.selector, c.provider)
        );
        scoped.finalityComponentCount(1);
        receipt = saved;
        receipt.actionId = 0;
        receipt.bindingHash = Deferred.receiptHash(receipt);
        _receiptValue();
        vm.expectRevert(
            abi.encodeWithSelector(ScopedDiscovery.DiscoveryConfiguration.selector, c.provider)
        );
        scoped.finalityComponentCount(1);
        receipt = saved;
        receipt.capabilityHash = keccak256("other capability");
        _refreshReceipt();
        vm.expectRevert(
            abi.encodeWithSelector(ScopedDiscovery.DiscoveryConfiguration.selector, c.provider)
        );
        scoped.finalityComponentCount(1);
        receipt = saved;
        receipt.bindingHash = keccak256("wrong bound receipt hash");
        _receiptValue();
        vm.expectRevert(
            abi.encodeWithSelector(ScopedDiscovery.DiscoveryConfiguration.selector, c.provider)
        );
        scoped.finalityComponentCount(1);
    }

    function testBoundProfileRepeatsOriginalReciprocalAndERC165Checks() public {
        _bindPolicyBoundary();
        _address(selected.referenceRender, "snapshots()", c.artist);
        vm.expectRevert(
            abi.encodeWithSelector(
                ScopedDiscovery.DiscoveryConfiguration.selector, selected.referenceRender
            )
        );
        scoped.finalityComponentCount(1);
        _address(selected.referenceRender, "snapshots()", selected.snapshots);
        _put(
            selected.entropyFactory,
            abi.encodeCall(
                IERC165.supportsInterface, (type(IStreamFinalityCurrentEntropyRoute).interfaceId)
            ),
            abi.encode(false)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                ScopedDiscovery.DiscoveryConfiguration.selector, selected.entropyFactory
            )
        );
        scoped.finalityComponentCount(1);
    }

    function testBoundSourceScopeOutputAndRuntimeRemainExact() public {
        _bindPolicyBoundary();
        StreamFinalityScope memory wrong = scope;
        wrong.collectionId = 2;
        _put(receipt.sourceSet, abi.encodeWithSignature("sourceScope()"), abi.encode(wrong));
        vm.expectRevert(
            abi.encodeWithSelector(ScopedDiscovery.DiscoveryDependency.selector, receipt.sourceSet)
        );
        scoped.finalityComponentCount(1);
        _put(receipt.sourceSet, abi.encodeWithSignature("sourceScope()"), abi.encode(scope));
        _address(receipt.output, "core()", c.artist);
        vm.expectRevert(
            abi.encodeWithSelector(ScopedDiscovery.DiscoveryConfiguration.selector, receipt.output)
        );
        scoped.finalityComponentCount(1);
        _address(receipt.output, "core()", c.core);
        vm.etch(selected.snapshots, hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(ScopedDiscovery.DiscoveryDependency.selector, selected.snapshots)
        );
        scoped.finalityComponentCount(1);
    }

    function testBoundSelectedProfileMalformedReceiptAndCapabilityMutationReject() public {
        _bindPolicyBoundary();
        selected.configurationHash = keccak256("substituted profile tuple");
        _source();
        vm.expectRevert(
            abi.encodeWithSelector(ScopedDiscovery.DiscoveryUnsupportedProfile.selector)
        );
        scoped.finalityComponentCount(1);
        selected = receipt.profile;
        _source();
        _put(
            c.provider,
            abi.encodeCall(DeferredBinding.requirePolicyBinding, ()),
            abi.encode(receipt.bindingHash)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityRouterEvidence.RouterEvidenceRead.selector,
                c.provider,
                DeferredBinding.requirePolicyBinding.selector
            )
        );
        scoped.finalityComponentCount(1);
        _receiptValue();
        capability.graphHash = keccak256("changed closed factory capability");
        _put(
            c.provider,
            abi.encodeCall(DeferredBinding.policyBindingCapability, ()),
            abi.encode(capability)
        );
        vm.expectRevert(
            abi.encodeWithSelector(ScopedDiscovery.DiscoveryDependency.selector, c.provider)
        );
        scoped.finalityComponentCount(1);
    }

    /// @dev The linked reader must retain the discovery host, not the library, in the exact
    /// provider receipt. Every current read remains static against constructor-only state.
    function testLinkedSelectionKeepsHostReceiptIdentityAndOriginalConfiguration() public {
        _bindPolicyBoundary();
        bytes32 beforeState = _configurationDigest();
        Deferred.Receipt memory original = receipt;
        require(original.policy.targets[13] == address(scoped));
        require(scoped.finalityComponentCount(1) == 10);
        _assertCurrent();
        (uint256 count, bytes32 hash) = scoped.nonSanctionDiscoveryFacts(scope);
        require(count == 9 && hash != 0);
        require(_configurationDigest() == beforeState);

        receipt.policy.targets[13] = address(LineageSelection);
        _refreshReceipt();
        vm.expectRevert(
            abi.encodeWithSelector(ScopedDiscovery.DiscoveryConfiguration.selector, c.provider)
        );
        scoped.finalityComponentCount(1);
        require(_configurationDigest() == beforeState);

        receipt = original;
        selected = original.profile;
        _source();
        _receiptValue();
        require(scoped.finalityComponentCount(1) == 10);
        _assertCurrent();
        require(_configurationDigest() == beforeState);
    }

    function testLinkedSelectionChecksOriginalSourceHashBeforePendingRead() public {
        bytes memory input = abi.encodeCall(Profiles.finalitySourcesForScope, (scope));
        scopedVm.mockCallRevert(
            c.provider, input, abi.encodeWithSelector(Deferred.CollectionPolicyPending.selector)
        );
        _put(
            c.provider,
            abi.encodeCall(Profiles.finalitySourceConfigurationHash, ()),
            abi.encode(keccak256("wrong source configuration before pending"))
        );
        vm.expectRevert(
            abi.encodeWithSelector(ScopedDiscovery.DiscoveryDependency.selector, c.provider)
        );
        scoped.finalityComponentCount(1);
        _put(
            c.provider,
            abi.encodeCall(Profiles.finalitySourceConfigurationHash, ()),
            abi.encode(SOURCES)
        );
        vm.expectRevert(abi.encodeWithSelector(Deferred.CollectionPolicyPending.selector));
        scoped.finalityComponentCount(1);
        scopedVm.mockCall(c.provider, input, abi.encode(Profiles.Sources(scope, selected)));
        require(scoped.finalityComponentCount(1) == 10);
    }

    function testLinkedDeferredReceiptRejectsPendingSelectorWithTrailingBytesAndRetries() public {
        _bindPolicyBoundary();
        bytes memory input = abi.encodeCall(DeferredBinding.requirePolicyBinding, ());
        bytes32 beforeState = _configurationDigest();
        scopedVm.mockCallRevert(
            c.provider,
            input,
            abi.encodePacked(Deferred.CollectionPolicyPending.selector, bytes32(uint256(1)))
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityRouterEvidence.RouterEvidenceRead.selector,
                c.provider,
                DeferredBinding.requirePolicyBinding.selector
            )
        );
        scoped.finalityComponentCount(1);
        require(_configurationDigest() == beforeState);
        scopedVm.mockCall(c.provider, input, abi.encode(receipt));
        require(scoped.finalityComponentCount(1) == 10);
        _assertCurrent();
        require(_configurationDigest() == beforeState);
    }

    function _configurationDigest() private view returns (bytes32) {
        bytes32 pins;
        address[12] memory targets = [
            c.core,
            c.metadata,
            c.router,
            c.provider,
            c.membership,
            c.entropyFactory,
            c.referenceRender,
            c.artist,
            selected.snapshots,
            selected.referenceRender,
            selected.entropyFactory,
            binding.factory
        ];
        for (uint256 i; i < targets.length; ++i) {
            pins = keccak256(abi.encode(pins, targets[i], scoped.dependencyCodeHash(targets[i])));
        }
        for (uint256 i; i < 6; ++i) {
            pins = keccak256(
                abi.encode(
                    pins, c.routerAdapters[i], scoped.dependencyCodeHash(c.routerAdapters[i])
                )
            );
        }
        return keccak256(
            abi.encode(
                scoped.core(),
                scoped.metadataHost(),
                scoped.scopeEvidenceProvider(),
                scoped.deploymentChainId(),
                scoped.sourceConfigurationHash(),
                scoped.configuration(),
                pins,
                scoped.dependencyCodeHash(c.metadataAdapter)
            )
        );
    }
}
