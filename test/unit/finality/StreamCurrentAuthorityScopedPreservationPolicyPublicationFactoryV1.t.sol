// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    ScopedPreservationReferenceFixtureV1,
    ScopedPreservationReferenceExternalBoundary
} from "../preservation/StreamScopedPreservationPolicyReferencePublicationV1.t.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1 as GraphFactory
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1.sol";
import {
    StreamScopedPreservationPolicyPublicationGraphTypesV1 as GraphTypes
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopedPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamScopedPreservationPolicyPublicationRecipeV1 as GraphRecipe
} from "../../../smart-contracts/domains/finality/StreamScopedPreservationPolicyPublicationRecipeV1.sol";
import {
    IStreamScopedPreservationPolicyPublicationFactoryV1 as GraphInterface
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPreservationPolicyPublicationFactoryV1.sol";
import {
    IStreamFinalityEntropySourceFactory as EntropyFactory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as GraphSnapshot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    IStreamScopedPreservationPolicyReferencePublicationV1 as GraphReference
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedPreservationPolicyReferencePublicationV1.sol";
import {
    IStreamScopedContentRootPublication as GraphRoot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    IStreamGasParameterHost as GraphGas
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { Vm } from "../../regression/legacy/helpers/CharacterizationTestBase.sol";

import {
    IStreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1 as AuthorityFactory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyPublicationTypesV1 as Domains
} from "../../../smart-contracts/interfaces/stream/finality/StreamCurrentAuthorityScopedPreservationPolicyPublicationTypesV1.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../../smart-contracts/interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamArtistCurrentAuthorityTypes as C
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import {
    IStreamArtistCurrentAuthorityResolver as Resolver
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamArtistCurrentAuthorityResolver.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyGraphSelectionV1 as Selection
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedPreservationPolicyGraphSelectionV1.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "../../../smart-contracts/domains/finality/StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityScopedPreservationPolicyProviderReadsV1 as Policy
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicyProviderReadsV1.sol";
import {
    IStreamScopedPreservationPolicyPublicationEvidenceBindingV1 as Binding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPreservationPolicyPublicationEvidenceBindingV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1 as InventoryChild
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyBundleArchiveCoverageV1 as BundleChild
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPreservationPolicyBundleArchiveCoverageV1.sol";

import {
    IStreamPreservationPolicyContentCheckpointV1 as GraphContent
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as GraphOutput
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";

/// @dev Explicit pinned topology boundary: supplies no Artist records or current selection.
contract AuthorityScopedPreservationGraphLateBoundary {
    function marker() external pure returns (uint256) {
        return 1;
    }
}

/// @dev Synthetic fixed-anchor boundary. Real currentSelection is intentionally unavailable.
contract AuthorityScopedPreservationGraphResolverBoundary {
    C.Anchors private _anchors;

    constructor(C.Anchors memory a) {
        _anchors = a;
    }

    function anchors() external view returns (C.Anchors memory) {
        return _anchors;
    }

    function currentAuthorityProfile() external pure returns (bytes32) {
        return C.PROFILE;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(Resolver).interfaceId;
    }

    function currentSelection() external pure returns (C.Selection memory) {
        revert("no current Artist boundary");
    }

    function setAnchors(C.Anchors memory a) external {
        _anchors = a;
    }
}

contract AuthorityScopedPreservationGraphSelectionHarness {
    function initialize(Native.Config memory c, Binding.FactoryBinding memory b)
        external
        view
        returns (Selection.Context memory)
    {
        return Selection.initialize(c, b);
    }

    function current(Selection.Context memory c, StreamFinalityScope memory scope)
        external
        view
        returns (Policy.Config memory, GraphTypes.Graph memory)
    {
        return Selection.current(c, scope);
    }
}

/// @notice Genuine seven preservation CREATE workers with explicit resolver/Artist topology boundaries.
/// @dev These tests prove graph construction and rejection behavior, not Artist provenance,
/// current selection, complete publication, archival evidence, or end-to-end Finality.
contract StreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1Test is
    ScopedPreservationReferenceFixtureV1
{
    GraphTypes.Recipe private graphRecipe;
    GraphFactory private graphFactory;
    O.Dependencies private origin;
    D.Dependencies private authority;
    AuthorityScopedPreservationGraphResolverBoundary private resolver;

    function testPredictedResolverConstructionPrecedesScopeAndFinalityThenAdmitsExactRuntime()
        public
    {
        _initialize(1);
        graphRecipe = _recipeFixture();
        origin = O.Dependencies(
            graphRecipe.inventory.artistTargets[0],
            graphRecipe.inventory.artistCodeHashes[0],
            8000000,
            O.PROFILE
        );
        C.Anchors memory a = _anchors(graphRecipe);
        AuthorityScopedPreservationGraphResolverBoundary template =
            new AuthorityScopedPreservationGraphResolverBoundary(a);
        address predicted =
            createVm.computeCreateAddress(address(this), createVm.getNonce(address(this)) + 1);
        authority = D.Dependencies(predicted, address(template).codehash, 16000000);
        snapshotVm.mockCallRevert(
            address(scopedFactory),
            abi.encodeWithSelector(EntropyFactory.currentInventoryPlan.selector),
            bytes("no scope before construction")
        );
        graphFactory = new GraphFactory(graphRecipe, origin, authority);
        require(predicted.code.length == 0, "constructor cannot read future resolver");
        require(
            graphFactory.recipeHash()
                == Domains.recipeHash(block.chainid, graphRecipe, origin, authority)
        );
        require(
            graphFactory.recipeHash()
                != keccak256(abi.encode(GraphTypes.PROFILE, block.chainid, graphRecipe)),
            "new recipe domain"
        );
        require(
            graphFactory.supportsInterface(type(GraphInterface).interfaceId)
                && graphFactory.supportsInterface(type(AuthorityFactory).interfaceId)
        );
        require(!graphFactory.supportsInterface(0xffffffff));
        require(
            graphFactory.scopedPreservationPolicyPublicationFactoryProfile()
                == Domains.FACTORY_PROFILE
        );
        resolver = new AuthorityScopedPreservationGraphResolverBoundary(a);
        require(
            address(resolver) == predicted
                && address(resolver).codehash == authority.resolverCodeHash
        );
        require(
            keccak256(
                abi.encode(graphFactory.originDependencies(), graphFactory.authorityDependencies())
            ) == keccak256(abi.encode(origin, authority))
        );
        require(graphFactory.graphForPlan(keccak256("unprepared")).graphId == 0);
    }

    function testSevenRealChildrenRetainOldPublicationChildrenAndFullAuthorityProfiles() public {
        StreamFinalityScope memory scope = _setup();
        uint64 beforeNonce = createVm.getNonce(address(graphFactory));
        vm.prank(address(0xB0B));
        GraphTypes.Graph memory g = graphFactory.prepareGraph(scope, 7);
        require(
            g.preparedChildren == 7 && createVm.getNonce(address(graphFactory)) == beforeNonce + 7
        );
        require(
            keccak256(abi.encode(g))
                == keccak256(abi.encode(graphFactory.requireCurrentGraph(scope)))
        );
        require(
            g.graphId
                == keccak256(
                    abi.encode(
                        Domains.GRAPH_DOMAIN,
                        block.chainid,
                        address(graphFactory),
                        graphFactory.recipeHash(),
                        graphFactory.sourceFactoryDependenciesHash(),
                        scope,
                        g.inventoryPlan,
                        g.sourceSet,
                        g.sourceSetCodeHash
                    )
                )
        );
        require(
            keccak256(abi.encode(GraphSnapshot(g.children[3]).dependencies()))
                == keccak256(abi.encode(GraphRecipe.snapshot(graphRecipe, g)))
        );
        require(
            keccak256(abi.encode(GraphReference(g.children[4]).dependencies()))
                == keccak256(abi.encode(GraphRecipe.referenceDependencies(graphRecipe, g)))
        );
        for (uint256 i; i < 7; ++i) {
            require(g.children[i] != address(0) && g.children[i].codehash == g.codeHashes[i]);
        }
        require(
            GraphContent(g.children[1]).preservationPolicyProfile()
                == keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_V1")
        );
        require(
            GraphContent(g.children[1]).preservationOutputProfile()
                == keccak256("6529STREAM_PRESERVATION_RENDER_V1")
        );
        require(GraphContent(g.children[1]).terminalReadiness() == g.children[0]);
        require(GraphContent(g.children[1]).entropySourceSet() == g.sourceSet);
        require(GraphOutput(g.children[2]).contentCheckpoint() == g.children[1]);
        require(
            GraphOutput(g.children[2]).outputProfile()
                == keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_V1")
        );
        require(
            GraphSnapshot(g.children[3]).scopedPreservationPolicySnapshotProfile()
                == keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V1")
        );
        require(
            GraphReference(g.children[4]).scopedPreservationPolicyReferenceProfile()
                == keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_V1")
        );
        InventoryChild inventory = InventoryChild(g.children[5]);
        BundleChild bundle = BundleChild(g.children[6]);
        require(
            inventory.scopedPreservationPolicyInventoryProfile()
                == D.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE
        );
        require(inventory.originProfile() == D.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE);
        require(
            inventory.dependencyHash()
                == D.dependencyHash(
                    D.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE,
                    GraphRecipe.inventory(graphRecipe, g),
                    origin,
                    authority
                )
        );
        require(
            keccak256(abi.encode(inventory.originDependencies(), inventory.authorityDependencies()))
                == keccak256(abi.encode(origin, authority))
        );
        require(bundle.INVENTORY_PROFILE() == D.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE);
        require(
            bundle.dependencyHash()
                == keccak256(
                    abi.encode(
                        bundle.PROFILE(),
                        D.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE,
                        GraphRecipe.bundle(graphRecipe, g),
                        origin,
                        authority
                    )
                )
        );
        require(
            keccak256(abi.encode(bundle.originDependencies(), bundle.authorityDependencies()))
                == keccak256(abi.encode(origin, authority))
        );
        require(
            GraphSnapshot(g.children[3]).currentSnapshot(scope).recordHash == 0,
            "no publication silently granted"
        );
        require(GraphReference(g.children[4]).currentReference(scope).observation.recordHash == 0);
        uint64 afterNonce = createVm.getNonce(address(graphFactory));
        require(
            keccak256(abi.encode(graphFactory.prepareGraph(scope, 7))) == keccak256(abi.encode(g))
        );
        require(createVm.getNonce(address(graphFactory)) == afterNonce, "idempotent completion");
    }

    function testMissingResolverRejectsOperativeUseWithoutCreatingAChild() public {
        StreamFinalityScope memory scope = _setup();
        D.Dependencies memory predicted =
            D.Dependencies(address(0x6529CA), keccak256("future runtime"), 16000000);
        GraphFactory f = new GraphFactory(graphRecipe, origin, predicted);
        uint64 beforeNonce = createVm.getNonce(address(f));
        vm.expectRevert();
        f.prepareGraph(scope, 1);
        require(
            createVm.getNonce(address(f)) == beforeNonce
                && f.graphForPlan(scopedFactory.currentInventoryPlan(scope)).graphId == 0
        );
    }

    function testWrongOriginalResolverAnchorAndRuntimeFailWithoutErasingPartialGraph() public {
        StreamFinalityScope memory scope = _setup();
        GraphTypes.Graph memory first = graphFactory.prepareGraph(scope, 1);
        uint64 nonce = createVm.getNonce(address(graphFactory));
        C.Anchors memory a = _anchors(graphRecipe);
        a.targets[2] = address(core);
        a.codeHashes[2] = address(core).codehash;
        resolver.setAnchors(a);
        vm.expectRevert(
            abi.encodeWithSelector(
                GraphTypes.PublicationGraphDependency.selector, address(resolver)
            )
        );
        graphFactory.prepareGraph(scope, 1);
        require(createVm.getNonce(address(graphFactory)) == nonce);
        require(
            keccak256(abi.encode(graphFactory.graphForPlan(first.inventoryPlan)))
                == keccak256(abi.encode(first))
        );
        resolver.setAnchors(_anchors(graphRecipe));
        vm.etch(address(resolver), hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                GraphTypes.PublicationGraphDependency.selector, address(resolver)
            )
        );
        graphFactory.prepareGraph(scope, 1);
        require(createVm.getNonce(address(graphFactory)) == nonce);
    }

    function testWrongOriginProfileAndResolverBoundsRejectConstruction() public {
        _setup();
        O.Dependencies memory badOrigin = origin;
        badOrigin.profile = keccak256("wrong original profile");
        vm.expectRevert(abi.encodeWithSelector(O.InvalidArchiveOrigin.selector));
        new GraphFactory(graphRecipe, badOrigin, authority);
        D.Dependencies memory badAuthority = authority;
        badAuthority.resolverGas = 49999;
        vm.expectRevert(abi.encodeWithSelector(GraphTypes.PublicationRecipeInvalid.selector));
        new GraphFactory(graphRecipe, origin, badAuthority);
        badAuthority = authority;
        badAuthority.resolverCodeHash = keccak256("wrong resolver runtime");
        vm.expectRevert(
            abi.encodeWithSelector(
                GraphTypes.PublicationGraphDependency.selector, address(resolver)
            )
        );
        new GraphFactory(graphRecipe, origin, badAuthority);
    }

    function testLateChildFailureRollsBackGraphNonceThenIdenticalRetryCompletes() public {
        StreamFinalityScope memory scope = _setup();
        GraphTypes.Graph memory first = graphFactory.prepareGraph(scope, 3);
        uint64 nonce = createVm.getNonce(address(graphFactory));
        snapshotVm.mockCallRevert(
            address(externalArchive),
            abi.encodeWithSignature("core()"),
            bytes("external coverage unavailable")
        );
        vm.expectRevert();
        graphFactory.prepareGraph(scope, 4);
        require(createVm.getNonce(address(graphFactory)) == nonce);
        require(
            keccak256(abi.encode(first))
                == keccak256(abi.encode(graphFactory.graphForPlan(first.inventoryPlan)))
        );
        snapshotVm.mockCall(
            address(externalArchive), abi.encodeWithSignature("core()"), abi.encode(address(core))
        );
        GraphTypes.Graph memory g = graphFactory.prepareGraph(scope, 4);
        require(g.preparedChildren == 7 && g.graphId == first.graphId);
        require(g.children[3] == createVm.computeCreateAddress(address(graphFactory), nonce));
        for (uint256 i; i < 3; ++i) {
            require(g.children[i] == first.children[i]);
        }
    }

    function testSelectionUsesNewRecipeGraphAndInventoryDomains() public {
        StreamFinalityScope memory scope = _setup();
        GraphTypes.Graph memory g = graphFactory.prepareGraph(scope, 7);
        AuthorityScopedPreservationGraphSelectionHarness h =
            new AuthorityScopedPreservationGraphSelectionHarness();
        Native.Config memory original = _original(graphRecipe);
        Binding.FactoryBinding memory b = _binding();
        Selection.Context memory c = h.initialize(original, b);
        require(
            c.binding.configurationHash
                == keccak256(
                    abi.encode(
                        Domains.PROVIDER_CONFIGURATION_DOMAIN,
                        original.chainId,
                        address(h),
                        original,
                        b.factory,
                        b.factoryCodeHash,
                        b.recipeHash,
                        b.sourceFactoryDependenciesHash,
                        b.graphGas,
                        origin,
                        authority
                    )
                )
        );
        (Policy.Config memory selected, GraphTypes.Graph memory actual) = h.current(c, scope);
        require(keccak256(abi.encode(actual)) == keccak256(abi.encode(g)));
        require(
            selected.inventoryDependencyHash
                == D.dependencyHash(
                    D.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE,
                    GraphRecipe.inventory(graphRecipe, g),
                    origin,
                    authority
                )
        );
        require(selected.targets[18] == g.children[5] && selected.targets[19] == g.children[6]);
        require(
            selected.targets[11] == original.targets[11],
            "historical original Artist anchor retained"
        );
        b.recipeHash = keccak256(abi.encode(GraphTypes.PROFILE, block.chainid, graphRecipe));
        vm.expectRevert(
            abi.encodeWithSelector(
                Selection.ScopedPolicyGraphSource.selector, address(graphFactory)
            )
        );
        h.initialize(original, b);
        b = _binding();
        snapshotVm.mockCall(
            address(graphFactory),
            abi.encodeCall(GraphInterface.scopedPreservationPolicyPublicationFactoryProfile, ()),
            abi.encode(GraphTypes.PROFILE)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Selection.ScopedPolicyGraphSource.selector, address(graphFactory)
            )
        );
        h.initialize(original, b);
    }

    function testSelectionRejectsCapabilityDriftAndCanonicalGetterFraming() public {
        StreamFinalityScope memory scope = _setup();
        graphFactory.prepareGraph(scope, 7);
        AuthorityScopedPreservationGraphSelectionHarness h =
            new AuthorityScopedPreservationGraphSelectionHarness();
        Selection.Context memory c = h.initialize(_original(graphRecipe), _binding());
        D.Dependencies memory other = authority;
        other.resolverGas += 1;
        snapshotVm.mockCall(
            address(graphFactory),
            abi.encodeCall(AuthorityFactory.authorityDependencies, ()),
            abi.encode(other)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Selection.ScopedPolicyGraphSource.selector, address(graphFactory)
            )
        );
        h.current(c, scope);
        snapshotVm.mockCall(
            address(graphFactory),
            abi.encodeCall(AuthorityFactory.authorityDependencies, ()),
            bytes.concat(abi.encode(authority), bytes32(0))
        );
        vm.expectRevert();
        h.current(c, scope);
        snapshotVm.mockCall(
            address(graphFactory),
            abi.encodeCall(AuthorityFactory.authorityDependencies, ()),
            abi.encode(authority)
        );
        O.Dependencies memory changedOrigin = origin;
        changedOrigin.originGas += 1;
        snapshotVm.mockCall(
            address(graphFactory),
            abi.encodeCall(AuthorityFactory.originDependencies, ()),
            abi.encode(changedOrigin)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Selection.ScopedPolicyGraphSource.selector, address(graphFactory)
            )
        );
        h.current(c, scope);
        snapshotVm.mockCall(
            address(graphFactory),
            abi.encodeCall(AuthorityFactory.originDependencies, ()),
            abi.encode(origin)
        );
        h.current(c, scope);
    }

    function testOldSixthStageProfileAndChangedFullDependencyHashRejectRetainedGraph() public {
        StreamFinalityScope memory scope = _setup();
        GraphTypes.Graph memory g = graphFactory.prepareGraph(scope, 7);
        bytes32 retained = keccak256(abi.encode(g));
        snapshotVm.mockCall(
            g.children[5],
            abi.encodeWithSignature("scopedPreservationPolicyInventoryProfile()"),
            abi.encode(keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_RENDER_CRITICAL_V1"))
        );
        vm.expectRevert(
            abi.encodeWithSelector(GraphTypes.PublicationGraphChanged.selector, g.graphId)
        );
        graphFactory.requireCurrentGraph(scope);
        require(keccak256(abi.encode(graphFactory.graphForPlan(g.inventoryPlan))) == retained);
        snapshotVm.mockCall(
            g.children[5],
            abi.encodeWithSignature("scopedPreservationPolicyInventoryProfile()"),
            abi.encode(D.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE)
        );
        O.Dependencies memory changedOrigin = origin;
        changedOrigin.originGas += 1;
        snapshotVm.mockCall(
            g.children[5],
            abi.encodeWithSignature("dependencyHash()"),
            abi.encode(
                D.dependencyHash(
                    D.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE,
                    GraphRecipe.inventory(graphRecipe, g),
                    changedOrigin,
                    authority
                )
            )
        );
        vm.expectRevert(
            abi.encodeWithSelector(GraphTypes.PublicationGraphChanged.selector, g.graphId)
        );
        graphFactory.requireCurrentGraph(scope);
        snapshotVm.mockCall(
            g.children[5],
            abi.encodeWithSignature("dependencyHash()"),
            abi.encode(
                D.dependencyHash(
                    D.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE,
                    GraphRecipe.inventory(graphRecipe, g),
                    origin,
                    authority
                )
            )
        );
        require(keccak256(abi.encode(graphFactory.requireCurrentGraph(scope))) == retained);
    }

    function _setup() private returns (StreamFinalityScope memory scope) {
        _initialize(1);
        graphRecipe = _recipeFixture();
        origin = O.Dependencies(
            graphRecipe.inventory.artistTargets[0],
            graphRecipe.inventory.artistCodeHashes[0],
            8000000,
            O.PROFILE
        );
        resolver = new AuthorityScopedPreservationGraphResolverBoundary(_anchors(graphRecipe));
        authority = D.Dependencies(address(resolver), address(resolver).codehash, 16000000);
        graphFactory = new GraphFactory(graphRecipe, origin, authority);
        scope = _scopedScope(1);
        bytes32 plan = scopedSources.beginInventory(scope);
        scopedSources.appendInventory(plan, 256);
        scopedFactory.prepareSourceSet(scope);
    }

    function _anchors(GraphTypes.Recipe memory r) private view returns (C.Anchors memory a) {
        a.targets = [
            r.inventory.targets[0],
            r.inventory.targets[1],
            r.inventory.targets[4],
            r.inventory.artistTargets[0],
            r.inventory.artistTargets[0]
        ];
        for (uint256 i; i < 5; ++i) {
            a.codeHashes[i] = a.targets[i].codehash;
        }
        a.finalityRegistry = r.inventory.artistTargets[0];
        a.chainId = block.chainid;
        a.readGas = 500000;
    }

    function _original(GraphTypes.Recipe memory r) private pure returns (Native.Config memory c) {
        for (uint256 i; i < 22; ++i) {
            c.targets[i] = r.inventory.artistTargets[0];
            c.codeHashes[i] = r.inventory.artistCodeHashes[0];
        }
        uint256[12] memory indexes = [uint256(0), 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21];
        for (uint256 i; i < 12; ++i) {
            if (i != 5 && i != 6) {
                c.targets[indexes[i]] = r.inventory.targets[i];
                c.codeHashes[indexes[i]] = r.inventory.codeHashes[i];
            }
        }
        c.targets[3] = r.targets[0];
        c.codeHashes[3] = r.codeHashes[0];
        c.targets[11] = r.inventory.artistTargets[0];
        c.codeHashes[11] = r.inventory.artistCodeHashes[0];
        c.chainId = r.inventory.chainId;
        c.readGas = r.inventory.readGas;
        c.sourceGas = 256000000;
        c.componentSourceGas = 128000000;
        c.inventoryDependencyHash = keccak256("boundary original inventory");
    }

    function _binding() private view returns (Binding.FactoryBinding memory b) {
        b.factory = address(graphFactory);
        b.factoryCodeHash = address(graphFactory).codehash;
        b.recipeHash = graphFactory.recipeHash();
        b.sourceFactoryDependenciesHash = graphFactory.sourceFactoryDependenciesHash();
        b.graphGas = 32000000;
    }

    function _recipeFixture() private returns (GraphTypes.Recipe memory r) {
        address late = address(new AuthorityScopedPreservationGraphLateBoundary());
        externalArchive = new ScopedPreservationReferenceExternalBoundary(address(core));
        r.inventory.targets = [
            address(core),
            address(metadata),
            address(schemas),
            address(snapshotStore),
            address(router),
            address(0),
            address(0),
            late,
            late,
            late,
            address(snapshotCoverage),
            address(externalArchive)
        ];
        for (uint256 i; i < 12; ++i) {
            if (i != 5 && i != 6) r.inventory.codeHashes[i] = r.inventory.targets[i].codehash;
        }
        for (uint256 i; i < 5; ++i) {
            r.inventory.artistTargets[i] = late;
            r.inventory.artistCodeHashes[i] = late.codehash;
        }
        r.inventory.artistContentOwner = late;
        r.inventory.artistContentOwnerCodeHash = late.codehash;
        r.inventory.chainId = block.chainid;
        r.inventory.readGas = 2000000;
        r.inventory.sourceGas = 64000000;
        r.inventory.selectionGas = 8000000;
        r.inventory.snapshotGas = 128000000;
        r.inventory.referenceGas = 256000000;
        r.targets = [
            address(scopedMembership),
            address(scopedSelections),
            address(scopedFactory),
            address(executor)
        ];
        for (uint256 i; i < 4; ++i) {
            r.codeHashes[i] = r.targets[i].codehash;
        }
        r.readinessReadGas = 2000000;
        r.readinessSourceGas = 6000000;
        r.factorySourceGas = 16000000;
        r.bundleReadGas = 2000000;
        r.bundleArchiveGas = 8000000;
        r.checkpointGas[0] =
            GraphGas.GasParameterConfig("STATIC_CONTENT_READ_GAS", 8000000, 50000, 2);
        r.checkpointGas[1] =
            GraphGas.GasParameterConfig("STATIC_CONTENT_RENDER_GAS", 16000000, 50000, 2);
        r.outputGas =
            GraphGas.GasParameterConfig("STATIC_OUTPUT_MANIFEST_READ_GAS", 32000000, 50000, 2);
        r.snapshotGas = _snapshotGas();
        r.referenceGas = _referenceGas();
    }
}
