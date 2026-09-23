// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    ScopedPolicyReferenceFixtureV2,
    ScopedPolicyReferenceExternalBoundaryV2
} from "../preservation/StreamScopedPolicyReferencePublicationV2.t.sol";
import {
    StreamScopedPolicyPublicationFactoryV2 as GraphFactory
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyPublicationFactoryV2.sol";
import {
    StreamScopedPolicyPublicationGraphTypesV2 as GraphTypes
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopedPolicyPublicationGraphTypesV2.sol";
import {
    StreamScopedPolicyPublicationRecipeV2 as GraphRecipe
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyPublicationRecipeV2.sol";
import {
    IStreamScopedPolicyPublicationFactoryV2 as GraphInterface
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyPublicationFactoryV2.sol";
import {
    IStreamFinalityEntropySourceFactory as EntropyFactory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import {
    IStreamScopedPolicySnapshotPublicationV2 as GraphSnapshot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPolicySnapshotPublicationV2.sol";
import {
    IStreamScopedPolicyReferencePublicationV2 as GraphReference
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedPolicyReferencePublicationV2.sol";
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

/// @dev Explicit late WORK/RIGHTS/conservation and Artist topology boundary. Creation only pins
/// these contracts; no test here claims their records, archival proofs or finality are complete.
contract ScopedPolicyGraphLateBoundaryV2 {
    function marker() external pure returns (uint256) {
        return 1;
    }
}

contract StreamScopedPolicyPublicationFactoryV2Test is ScopedPolicyReferenceFixtureV2 {
    GraphFactory private graphFactory;
    GraphTypes.Recipe private graphRecipe;

    function testRecipeConstructionNeverRequiresMintedScopeOrPreparedChildren() public {
        _initialize(1);
        GraphTypes.Recipe memory r = _recipeFixture();
        snapshotVm.mockCallRevert(
            address(scopedFactory),
            abi.encodeWithSelector(EntropyFactory.currentInventoryPlan.selector),
            abi.encodePacked("no current scope")
        );
        GraphFactory f = new GraphFactory(r);
        require(f.recipeHash() == keccak256(abi.encode(GraphTypes.PROFILE, block.chainid, r)));
        require(f.graphForPlan(keccak256("unprepared")).graphId == 0);
        require(f.supportsInterface(type(GraphInterface).interfaceId));
        require(f.scopedPolicyPublicationFactoryProfile() == GraphTypes.PROFILE);
        require(f.core() == address(core) && f.metadataHost() == address(metadata));
    }

    function testPermissionlessSevenStageGraphNeedsNoSnapshotOrRootAndPinsOriginalConstructors()
        public
    {
        StreamFinalityScope memory scope = _setup(2);
        // Failing these root methods makes an accidental publication dependency observable.
        snapshotVm.mockCallRevert(
            address(router),
            abi.encodeCall(GraphRoot.scopedContentRootHead, (scope)),
            abi.encodePacked("root unavailable before publication")
        );
        uint64 beforeNonce = createVm.getNonce(address(graphFactory));
        vm.prank(address(0xB0B));
        GraphTypes.Graph memory g = graphFactory.prepareGraph(scope, 7);
        require(
            g.preparedChildren == 7 && createVm.getNonce(address(graphFactory)) == beforeNonce + 7
        );
        require(
            keccak256(abi.encode(graphFactory.requireCurrentGraph(scope)))
                == keccak256(abi.encode(g))
        );
        require(
            g.graphId
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_POLICY_PUBLICATION_GRAPH_V2"),
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
        for (uint256 i; i < 7; ++i) {
            require(g.children[i] != address(0) && g.children[i].codehash == g.codeHashes[i]);
        }
        require(
            keccak256(abi.encode(GraphSnapshot(g.children[3]).dependencies()))
                == keccak256(abi.encode(GraphRecipe.snapshot(graphRecipe, g)))
        );
        require(
            keccak256(abi.encode(GraphReference(g.children[4]).dependencies()))
                == keccak256(abi.encode(GraphRecipe.referenceDependencies(graphRecipe, g)))
        );
        require(GraphSnapshot(g.children[3]).currentSnapshot(scope).recordHash == 0);
        require(GraphReference(g.children[4]).currentReference(scope).observation.recordHash == 0);
    }

    function testBoundedPreparationHasExactEventsAndIdempotentResume() public {
        StreamFinalityScope memory scope = _setup(1);
        vm.recordLogs();
        GraphTypes.Graph memory first = graphFactory.prepareGraph(scope, 1);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256(
            "ScopedPolicyPublicationChildPrepared(uint16,bytes32,bytes32,uint8,address,bytes32)"
        );
        uint256 seen;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(graphFactory) && logs[i].topics[0] == topic) {
                ++seen;
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == first.graphId
                        && logs[i].topics[2] == first.inventoryPlan
                        && logs[i].topics[3] == bytes32(0)
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(abi.encode(uint16(2), first.children[0], first.codeHashes[0]))
                );
            }
        }
        require(seen == 1 && first.preparedChildren == 1);
        vm.expectRevert();
        graphFactory.requireCurrentGraph(scope);
        GraphTypes.Graph memory complete = graphFactory.prepareGraph(scope, 6);
        require(complete.children[0] == first.children[0] && complete.preparedChildren == 7);
        uint64 nonce = createVm.getNonce(address(graphFactory));
        require(
            keccak256(abi.encode(graphFactory.prepareGraph(scope, 7)))
                == keccak256(abi.encode(complete))
        );
        require(createVm.getNonce(address(graphFactory)) == nonce);
    }

    function testDistinctTokenReleaseSeasonPlansNeverAliasChildren() public {
        StreamFinalityScope memory token = _setup(1);
        GraphTypes.Graph memory one = graphFactory.prepareGraph(token, 1);
        StreamFinalityScope memory release = _indexScope(2);
        StreamFinalityScope memory season = _indexScope(3);
        GraphTypes.Graph memory two = graphFactory.prepareGraph(release, 1);
        GraphTypes.Graph memory three = graphFactory.prepareGraph(season, 1);
        require(one.inventoryPlan != two.inventoryPlan && two.inventoryPlan != three.inventoryPlan);
        require(one.children[0] != two.children[0] && two.children[0] != three.children[0]);
        require(one.graphId != two.graphId && two.graphId != three.graphId);
        token.collectionId = 2;
        vm.expectRevert();
        graphFactory.prepareGraph(token, 1);
    }

    function testPartialCreationFailureRollsBackChildrenNonceAndResumesSamePlan() public {
        StreamFinalityScope memory scope = _setup(2);
        GraphTypes.Graph memory first = graphFactory.prepareGraph(scope, 3);
        uint64 nonce = createVm.getNonce(address(graphFactory));
        snapshotVm.mockCallRevert(
            address(externalArchive),
            abi.encodeWithSignature("core()"),
            abi.encodePacked("external host unavailable")
        );
        vm.expectRevert();
        graphFactory.prepareGraph(scope, 4);
        GraphTypes.Graph memory failed = graphFactory.graphForPlan(first.inventoryPlan);
        require(keccak256(abi.encode(first)) == keccak256(abi.encode(failed)));
        require(createVm.getNonce(address(graphFactory)) == nonce);
        snapshotVm.mockCall(
            address(externalArchive), abi.encodeWithSignature("core()"), abi.encode(address(core))
        );
        GraphTypes.Graph memory complete = graphFactory.prepareGraph(scope, 4);
        require(complete.preparedChildren == 7 && complete.graphId == first.graphId);
        require(complete.children[3] == createVm.computeCreateAddress(address(graphFactory), nonce));
        for (uint256 i; i < 3; ++i) {
            require(complete.children[i] == first.children[i]);
        }
    }

    function testCurrentRuntimeAndOriginalFactoryDriftFailWithoutErasingRetainedGraph() public {
        StreamFinalityScope memory scope = _setup(1);
        GraphTypes.Graph memory g = graphFactory.prepareGraph(scope, 7);
        bytes memory original = g.children[4].code;
        vm.etch(g.children[4], hex"00");
        vm.expectRevert();
        graphFactory.requireCurrentGraph(scope);
        require(
            keccak256(abi.encode(graphFactory.graphForPlan(g.inventoryPlan)))
                == keccak256(abi.encode(g))
        );
        vm.etch(g.children[4], original);
        graphFactory.requireCurrentGraph(scope);
        snapshotVm.mockCall(
            address(scopedFactory),
            abi.encodeCall(EntropyFactory.currentInventoryPlan, (scope)),
            abi.encode(keccak256("different actual plan"))
        );
        vm.expectRevert();
        graphFactory.requireCurrentGraph(scope);
        require(graphFactory.graphForPlan(g.inventoryPlan).graphId == g.graphId);
    }

    function testRecipeRejectsSuppliedChildrenBadGasOrWrongOriginalGraph() public {
        _initialize(1);
        GraphTypes.Recipe memory r = _recipeFixture();
        r.inventory.targets[5] = address(this);
        r.inventory.codeHashes[5] = address(this).codehash;
        vm.expectRevert();
        new GraphFactory(r);
        r.inventory.targets[5] = address(0);
        r.inventory.codeHashes[5] = 0;
        r.referenceGas[0].failureClass = 2;
        vm.expectRevert();
        new GraphFactory(r);
        r.referenceGas[0].failureClass = 1;
        r.targets[0] = address(core);
        r.codeHashes[0] = address(core).codehash;
        vm.expectRevert();
        new GraphFactory(r);
    }

    function testUnsupportedScopeAndPreparationBoundsDoNotCreateChildren() public {
        StreamFinalityScope memory scope = _setup(1);
        vm.expectRevert();
        graphFactory.prepareGraph(scope, 0);
        vm.expectRevert();
        graphFactory.prepareGraph(scope, 8);
        scope.scopeType = StreamFinalityScopeType.COLLECTION;
        scope.tokenId = 0;
        vm.expectRevert();
        graphFactory.prepareGraph(scope, 1);
        scope.scopeType = StreamFinalityScopeType.VIEW;
        scope.scopeId = keccak256("view");
        vm.expectRevert();
        graphFactory.prepareGraph(scope, 1);
    }

    function _setup(uint8 kind) private returns (StreamFinalityScope memory scope) {
        _initialize(1);
        graphRecipe = _recipeFixture();
        graphFactory = new GraphFactory(graphRecipe);
        return _indexScope(kind);
    }

    function _indexScope(uint8 kind) private returns (StreamFinalityScope memory scope) {
        scope = _scopedScope(kind);
        bytes32 plan = scopedSources.beginInventory(scope);
        scopedSources.appendInventory(plan, 256);
        scopedFactory.prepareSourceSet(scope);
    }

    function _recipeFixture() private returns (GraphTypes.Recipe memory r) {
        address late = address(new ScopedPolicyGraphLateBoundaryV2());
        externalArchive = new ScopedPolicyReferenceExternalBoundaryV2(address(core));
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
