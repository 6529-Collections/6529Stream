// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    ScopedPreservationSnapshotFixtureV1
} from "../metadata/StreamScopedPreservationPolicySnapshotPublicationV1.t.sol";
import {
    StreamPreservationPolicyPublicationFactoryV1 as GraphFactory
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyPublicationFactoryV1.sol";
import {
    StreamPreservationPolicyPublicationGraphTypesV1 as GraphTypes
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamPreservationPolicyPublicationRecipeV1 as GraphRecipe
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyPublicationRecipeV1.sol";
import {
    IStreamPreservationPolicyPublicationFactoryV1 as GraphInterface
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyPublicationFactoryV1.sol";
import {
    IStreamFinalityEntropySourceFactory as EntropyFactory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import {
    IStreamPreservationPolicySnapshotPublicationV1 as GraphSnapshot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPreservationPolicySnapshotPublicationV1.sol";
import {
    IStreamPreservationPolicyReferencePublicationV1 as GraphReference
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamPreservationPolicyReferencePublicationV1.sol";
import {
    IStreamContentRootPublication as GraphRoot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamContentRootPublication.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    IStreamGasParameterHost as GraphGas
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { Vm } from "../../regression/legacy/helpers/CharacterizationTestBase.sol";

import {
    StreamFinalityEntropyPolicySourceFactoryV2 as CollectionSourceFactory
} from "../../../smart-contracts/domains/finality/StreamFinalityEntropyPolicySourceFactoryV2.sol";
import {
    StreamCollectionTokenInventory as CollectionTokens
} from "../../../smart-contracts/domains/finality/StreamCollectionTokenInventory.sol";
import {
    IStreamEntropyCollectionPolicy as EntropyPolicy
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as GraphEntropy
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";

import {
    IStreamExternalArtifactCurrentPair
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamExternalArtifactCurrentPair.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as GraphContent
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as GraphOutput
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import {
    IStreamPreservationPolicyRenderCriticalInventoryV1 as GraphInventory
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamPreservationPolicyRenderCriticalInventoryV1.sol";
import {
    IStreamBundleArchiveCoverage as GraphBundle
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamBundleArchiveCoverage.sol";
import {
    IStreamPolicyPublicationFactoryV2 as OriginalGraphInterface
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPolicyPublicationFactoryV2.sol";

/// @dev Explicit late WORK/RIGHTS/conservation and Artist topology boundary. Creation only pins
/// these contracts; no test here claims their records, archival proofs or finality are complete.
contract PreservationPolicyGraphExternalBoundaryV1 {
    address public immutable core;

    constructor(address c) {
        core = c;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamExternalArtifactCurrentPair).interfaceId;
    }
}

contract PreservationPolicyGraphLateBoundaryV1 {
    function marker() external pure returns (uint256) {
        return 1;
    }
}

/// @notice Genuine mixed native policies, Collection source factory and seven preservation-profile children.
/// @dev Inherits explicit Core identity, Artist, governance, renderer and archival boundaries.
/// No publication completion, actual-current Finality or transaction gas acceptance is claimed.
contract StreamPreservationPolicyPublicationFactoryV1Test is ScopedPreservationSnapshotFixtureV1 {
    PreservationPolicyGraphExternalBoundaryV1 private externalArchive;
    CollectionSourceFactory private collectionFactory;
    GraphFactory private graphFactory;
    GraphTypes.Recipe private graphRecipe;

    function testRecipeConstructionRequiresNoInventoryReadsOrPreparedChildren() public {
        _initialize(1);
        collectionFactory = new CollectionSourceFactory(_scopedDependencies());
        GraphTypes.Recipe memory r = _recipeFixture();
        snapshotVm.mockCallRevert(
            address(collectionFactory),
            abi.encodeWithSelector(EntropyFactory.currentInventoryPlan.selector),
            abi.encodePacked("no current scope")
        );
        GraphFactory f = new GraphFactory(r);
        require(f.recipeHash() == keccak256(abi.encode(GraphTypes.PROFILE, block.chainid, r)));
        require(f.graphForPlan(keccak256("unprepared")).graphId == 0);
        require(f.supportsInterface(type(GraphInterface).interfaceId));
        require(!f.supportsInterface(type(OriginalGraphInterface).interfaceId));
        require(f.preservationPolicyPublicationFactoryProfile() == GraphTypes.PROFILE);
        require(f.core() == address(core) && f.metadataHost() == address(metadata));
    }

    function testPermissionlessSevenStageGraphNeedsNoSnapshotOrRootAndPinsOriginalConstructors()
        public
    {
        StreamFinalityScope memory scope = _setup(2);
        // Failing these root methods makes an accidental publication dependency observable.
        snapshotVm.mockCallRevert(
            address(router),
            abi.encodeCall(GraphRoot.collectionContentRootHead, (scope.collectionId)),
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
                        keccak256("6529STREAM_PRESERVATION_POLICY_PUBLICATION_GRAPH_V1"),
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
        require(GraphEntropy(g.sourceSet).sourceCount() == 2, "both original coordinators retained");
        GraphEntropy.TokenReadiness memory terminal =
            GraphEntropy(g.sourceSet).tokenEntropyReadiness(91);
        GraphEntropy.TokenReadiness memory finalized =
            GraphEntropy(g.sourceSet).tokenEntropyReadiness(92);
        require(
            terminal.terminal && !terminal.finalized && terminal.seed == 0,
            "terminal is not finalized"
        );
        require(finalized.finalized && finalized.seed != 0, "original finalized seed retained");
        require(
            keccak256(abi.encode(GraphSnapshot(g.children[3]).dependencies()))
                == keccak256(abi.encode(GraphRecipe.snapshot(graphRecipe, g)))
        );
        require(
            keccak256(abi.encode(GraphReference(g.children[4]).dependencies()))
                == keccak256(abi.encode(GraphRecipe.referenceDependencies(graphRecipe, g)))
        );
        require(
            GraphContent(g.children[1]).preservationPolicyProfile()
                == keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1")
        );
        require(
            GraphContent(g.children[1]).preservationOutputProfile()
                == keccak256("6529STREAM_PRESERVATION_RENDER_V1")
        );
        require(
            GraphOutput(g.children[2]).outputProfile()
                == keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1")
        );
        require(
            GraphSnapshot(g.children[3]).preservationPolicySnapshotProfile()
                == keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_V1")
        );
        require(
            GraphReference(g.children[4]).preservationPolicyReferenceProfile()
                == keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_V1")
        );
        require(
            GraphInventory(g.children[5]).preservationPolicyInventoryProfile()
                == keccak256("6529STREAM_PRESERVATION_POLICY_COLLECTION_RENDER_CRITICAL_V1")
        );
        require(GraphBundle(g.children[6]).renderCriticalInventory() == g.children[5]);
        require(
            GraphBundle(g.children[6]).core() == address(core)
                && GraphBundle(g.children[6]).metadataHost() == address(metadata)
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
            "PolicyPublicationChildPrepared(uint16,bytes32,bytes32,uint8,address,bytes32)"
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
                        == keccak256(abi.encode(uint16(1), first.children[0], first.codeHashes[0]))
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

    function testExpandedActualMembershipRequiresNewGraphAndRetainsOriginalHistory() public {
        StreamFinalityScope memory scope = _setup(1);
        GraphTypes.Graph memory oldGraph = graphFactory.prepareGraph(scope, 7);
        _scopedToken(93, 3, 2, address(terminalCoordinator));
        core.setMinted(3);
        vm.prank(address(core));
        terminalCoordinator.onTokenMinted(1, 93, address(this), keccak256("new original mint"));
        uint256[] memory ids = new uint256[](1);
        ids[0] = 93;
        CollectionTokens(scopedMembership.tokenInventory()).appendCollectionTokens(1, ids);
        vm.expectRevert();
        graphFactory.requireCurrentGraph(scope);
        bytes32 plan = scopedSources.beginInventory(scope);
        scopedSources.appendInventory(plan, 256);
        collectionFactory.prepareSourceSet(scope);
        GraphTypes.Graph memory next = graphFactory.prepareGraph(scope, 1);
        require(next.inventoryPlan != oldGraph.inventoryPlan && next.graphId != oldGraph.graphId);
        require(next.children[0] != oldGraph.children[0] && next.sourceSet != oldGraph.sourceSet);
        require(
            keccak256(abi.encode(graphFactory.graphForPlan(oldGraph.inventoryPlan)))
                == keccak256(abi.encode(oldGraph)),
            "original graph retained exactly"
        );
    }

    function testOriginalFullPolicyDriftFailsBeforeChildrenAndRestoresExactPlan() public {
        StreamFinalityScope memory scope = _setup(1);
        GraphTypes.Graph memory g = graphFactory.prepareGraph(scope, 1);
        EntropyPolicy.PolicyRecord memory p =
            EntropyPolicy(address(terminalCoordinator)).collectionEntropyPolicy(1);
        bytes memory original = abi.encode(p);
        p.lastActionId = keccak256("changed original policy action");
        snapshotVm.mockCall(
            address(terminalCoordinator),
            abi.encodeCall(EntropyPolicy.collectionEntropyPolicy, (uint256(1))),
            abi.encode(p)
        );
        uint64 nonce = createVm.getNonce(address(graphFactory));
        vm.expectRevert();
        graphFactory.prepareGraph(scope, 6);
        require(createVm.getNonce(address(graphFactory)) == nonce);
        require(graphFactory.graphForPlan(g.inventoryPlan).preparedChildren == 1);
        snapshotVm.mockCall(
            address(terminalCoordinator),
            abi.encodeCall(EntropyPolicy.collectionEntropyPolicy, (uint256(1))),
            original
        );
        require(graphFactory.prepareGraph(scope, 6).graphId == g.graphId);
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
            address(collectionFactory),
            abi.encodeCall(EntropyFactory.currentInventoryPlan, (scope)),
            abi.encode(keccak256("different actual plan"))
        );
        vm.expectRevert();
        graphFactory.requireCurrentGraph(scope);
        require(graphFactory.graphForPlan(g.inventoryPlan).graphId == g.graphId);
    }

    function testRecipeRejectsSuppliedChildrenBadGasOrWrongOriginalGraph() public {
        _initialize(1);
        collectionFactory = new CollectionSourceFactory(_scopedDependencies());
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
        uint64 nonce = createVm.getNonce(address(graphFactory));
        vm.expectRevert(abi.encodeWithSelector(GraphTypes.PublicationRecipeInvalid.selector));
        graphFactory.prepareGraph(scope, 0);
        vm.expectRevert(abi.encodeWithSelector(GraphTypes.PublicationRecipeInvalid.selector));
        graphFactory.prepareGraph(scope, 8);
        scope.tokenId = 91;
        vm.expectRevert(abi.encodeWithSelector(GraphTypes.PublicationRecipeInvalid.selector));
        graphFactory.prepareGraph(scope, 1);
        scope.tokenId = 0;
        scope.scopeId = keccak256("noncanonical collection");
        vm.expectRevert(abi.encodeWithSelector(GraphTypes.PublicationRecipeInvalid.selector));
        graphFactory.prepareGraph(scope, 1);
        scope.scopeId = 0;
        scope.collectionId = 0;
        vm.expectRevert(abi.encodeWithSelector(GraphTypes.PublicationRecipeInvalid.selector));
        graphFactory.prepareGraph(scope, 1);
        scope.collectionId = 1;
        scope.tokenId = 91;
        scope.scopeType = StreamFinalityScopeType.TOKEN;
        vm.expectRevert(abi.encodeWithSelector(GraphTypes.PublicationRecipeInvalid.selector));
        graphFactory.prepareGraph(scope, 1);
        scope.tokenId = 0;
        scope.scopeId = keccak256("release");
        scope.scopeType = StreamFinalityScopeType.RELEASE;
        vm.expectRevert(abi.encodeWithSelector(GraphTypes.PublicationRecipeInvalid.selector));
        graphFactory.prepareGraph(scope, 1);
        scope.scopeType = StreamFinalityScopeType.SEASON;
        vm.expectRevert(abi.encodeWithSelector(GraphTypes.PublicationRecipeInvalid.selector));
        graphFactory.prepareGraph(scope, 1);
        scope.scopeType = StreamFinalityScopeType.VIEW;
        vm.expectRevert(abi.encodeWithSelector(GraphTypes.PublicationRecipeInvalid.selector));
        graphFactory.prepareGraph(scope, 1);
        require(createVm.getNonce(address(graphFactory)) == nonce);
    }

    function testConstructorMayPinAbsentLateOwnerButPreparationRequiresItsActualRuntime() public {
        _initialize(1);
        collectionFactory = new CollectionSourceFactory(_scopedDependencies());
        GraphTypes.Recipe memory r = _recipeFixture();
        r.inventory.artistTargets[1] = address(0xAABBCC);
        r.inventory.artistCodeHashes[1] = keccak256("reserved original Coordinator runtime");
        GraphFactory f = new GraphFactory(r);
        StreamFinalityScope memory scope = _indexCollection();
        vm.expectRevert(
            abi.encodeWithSelector(
                GraphTypes.PublicationGraphDependency.selector, address(0xAABBCC)
            )
        );
        f.prepareGraph(scope, 1);
        require(f.graphForPlan(collectionFactory.currentInventoryPlan(scope)).graphId == 0);
    }

    function testDistinctChildProfilesRejectOldInterpretationWithoutErasingGraph() public {
        StreamFinalityScope memory scope = _setup(1);
        GraphTypes.Graph memory g = graphFactory.prepareGraph(scope, 7);
        string[5] memory methods = [
            "preservationPolicyProfile()",
            "outputProfile()",
            "preservationPolicySnapshotProfile()",
            "preservationPolicyReferenceProfile()",
            "preservationPolicyInventoryProfile()"
        ];
        bytes32[5] memory expected = [
            keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1"),
            keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1"),
            keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_V1"),
            keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_V1"),
            keccak256("6529STREAM_PRESERVATION_POLICY_COLLECTION_RENDER_CRITICAL_V1")
        ];
        for (uint256 i; i < 5; ++i) {
            snapshotVm.mockCall(
                g.children[i + 1],
                abi.encodeWithSignature(methods[i]),
                abi.encode(keccak256("original live-output profile"))
            );
            vm.expectRevert(
                abi.encodeWithSelector(GraphTypes.PublicationGraphChanged.selector, g.graphId)
            );
            graphFactory.requireCurrentGraph(scope);
            require(
                keccak256(abi.encode(graphFactory.graphForPlan(g.inventoryPlan)))
                    == keccak256(abi.encode(g))
            );
            snapshotVm.mockCall(
                g.children[i + 1], abi.encodeWithSignature(methods[i]), abi.encode(expected[i])
            );
            graphFactory.requireCurrentGraph(scope);
        }
    }

    function _setup(uint8 terminalStatus) private returns (StreamFinalityScope memory scope) {
        _initialize(terminalStatus);
        collectionFactory = new CollectionSourceFactory(_scopedDependencies());
        graphRecipe = _recipeFixture();
        graphFactory = new GraphFactory(graphRecipe);
        return _indexCollection();
    }

    function _indexCollection() private returns (StreamFinalityScope memory scope) {
        scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        bytes32 plan = scopedSources.beginInventory(scope);
        scopedSources.appendInventory(plan, 256);
        collectionFactory.prepareSourceSet(scope);
    }

    function _recipeFixture() private returns (GraphTypes.Recipe memory r) {
        address late = address(new PreservationPolicyGraphLateBoundaryV1());
        externalArchive = new PreservationPolicyGraphExternalBoundaryV1(address(core));
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
            address(collectionFactory),
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
        r.snapshotGas[0].name = "POLICY_SNAPSHOT_READ_GAS";
        r.snapshotGas[1].name = "POLICY_SNAPSHOT_SOURCE_GAS";
        r.snapshotGas[2].name = "POLICY_SNAPSHOT_INVENTORY_GAS";
        r.referenceGas[0] =
            GraphGas.GasParameterConfig("POLICY_REFERENCE_READ_GAS", 2000000, 50000, 1);
        r.referenceGas[1] =
            GraphGas.GasParameterConfig("POLICY_REFERENCE_SOURCE_GAS", 8000000, 50000, 1);
        r.referenceGas[2] =
            GraphGas.GasParameterConfig("POLICY_REFERENCE_SNAPSHOT_GAS", 128000000, 50000, 1);
        r.referenceGas[3] =
            GraphGas.GasParameterConfig("POLICY_REFERENCE_ARCHIVE_GAS", 2000000, 50000, 1);
        r.referenceGas[0].name = "POLICY_REFERENCE_READ_GAS";
        r.referenceGas[1].name = "POLICY_REFERENCE_SOURCE_GAS";
        r.referenceGas[2].name = "POLICY_REFERENCE_SNAPSHOT_GAS";
        r.referenceGas[3].name = "POLICY_REFERENCE_ARCHIVE_GAS";
    }
}
