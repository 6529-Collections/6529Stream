// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    ScopedPolicyReferenceFixtureV2,
    ScopedPolicyReferenceExternalBoundaryV2
} from "../preservation/StreamScopedPolicyReferencePublicationV2.t.sol";
import {
    StreamFinalityScopedPolicyEvidenceProviderV2 as ProviderV2
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPolicyEvidenceProviderV2.sol";
import {
    StreamFinalityPolicyMultiScopeEvidenceProvider as PriorProvider
} from "../../../smart-contracts/domains/finality/StreamFinalityPolicyMultiScopeEvidenceProvider.sol";
import {
    StreamFinalityNativeProviderReads as NativeConfig
} from "../../../smart-contracts/domains/finality/StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityScopedProviderReads as PriorScoped
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedProviderReads.sol";
import {
    IStreamScopedPolicyPublicationEvidenceBindingV2 as FactoryBinding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyPublicationEvidenceBindingV2.sol";
import {
    StreamScopedPolicyPublicationGraphTypesV2 as GraphTypes
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopedPolicyPublicationGraphTypesV2.sol";
import {
    StreamScopedPolicyPublicationFactoryV2 as Factory
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyPublicationFactoryV2.sol";
import {
    StreamFinalityProfileSourceReads as PriorSelection
} from "../../../smart-contracts/domains/finality/StreamFinalityProfileSourceReads.sol";
import {
    IStreamFinalityProfileSources as Profiles
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    StreamFinalityScopedPolicyGraphSelectionV2 as GraphSelection
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPolicyGraphSelectionV2.sol";
import {
    StreamScopedPolicySnapshotDefinitionsV2 as SnapshotDefinitions
} from "../../../smart-contracts/domains/records/StreamScopedPolicySnapshotDefinitionsV2.sol";
import {
    IStreamScopedPolicyContentRootEvidenceBindingV2 as RootProviderBinding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyContentRootEvidenceBindingV2.sol";
import {
    StreamScopedPolicySnapshotTypesV2 as SnapshotTypes
} from "../../../smart-contracts/interfaces/stream/metadata/StreamScopedPolicySnapshotTypesV2.sol";
import {
    StreamSnapshotTypes as LegacySnapshot
} from "../../../smart-contracts/interfaces/stream/metadata/StreamSnapshotTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType,
    StreamFinalityComponentExpectation
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamScopedPolicyContentCheckpointV2 as CheckpointHost
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyContentCheckpointV2.sol";
import {
    IStreamScopedPolicyContentCheckpointV2 as Checkpoint
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyContentCheckpointV2.sol";
import {
    StreamScopedPolicyOutputManifestV2 as OutputHostV2
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyOutputManifestV2.sol";
import {
    StreamScopedPolicyOutputSchemasV2 as OutputDefinitions
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyOutputSchemasV2.sol";
import {
    StreamScopedPolicySnapshotPublicationV2 as SnapshotHostV2
} from "../../../smart-contracts/domains/metadata/StreamScopedPolicySnapshotPublicationV2.sol";
import {
    IStreamScopedPolicyContentRootPublicationV2 as RootV2
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPolicyContentRootPublicationV2.sol";
import {
    IStreamScopedContentRootPublication as ScopedRootV1
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamGasParameterHost as ProviderGas
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @dev Named original profile and late record topology boundary. Genuine current scoped graph,
/// snapshot, root, factory and provider are exercised; no full Registry ceremony is claimed.
contract ScopedPolicyProviderLateBoundaryV2 {
    function marker() external pure returns (uint256) {
        return 1;
    }
}

abstract contract ScopedPolicyActualProviderFixtureV2 is ScopedPolicyReferenceFixtureV2 {
    ProviderV2 internal actualProvider;
    PriorProvider internal previousProvider;
    Factory internal publicationFactory;
    GraphTypes.Recipe internal publicationRecipe;
    GraphTypes.Graph internal publicationGraph;
    NativeConfig.Config internal originalProviderConfig;
    NativeConfig.Config internal collectionPolicyConfig;
    PriorScoped.Config internal originalScopedConfig;
    FactoryBinding.FactoryBinding internal factoryBinding;
    address internal oldPolicyOutput;

    function _providerSetup(uint8 kind, bool publishRoot) internal {
        _initialize(1);
        externalArchive = new ScopedPolicyReferenceExternalBoundaryV2(address(core));
        _providerConfiguration();
        publicationRecipe = _publicationRecipe();
        publicationFactory = new Factory(publicationRecipe);
        factoryBinding = FactoryBinding.FactoryBinding(
            address(publicationFactory),
            address(publicationFactory).codehash,
            publicationFactory.recipeHash(),
            publicationFactory.sourceFactoryDependenciesHash(),
            64000000,
            0
        );
        actualProvider = new ProviderV2(
            originalProviderConfig,
            originalScopedConfig,
            collectionPolicyConfig,
            oldPolicyOutput,
            oldPolicyOutput.codehash,
            factoryBinding
        );
        previousProvider = new PriorProvider(
            originalProviderConfig,
            originalScopedConfig,
            collectionPolicyConfig,
            oldPolicyOutput,
            oldPolicyOutput.codehash
        );
        StreamFinalityScope memory scope = _scopedScope(kind);
        bytes32 plan = scopedSources.beginInventory(scope);
        scopedSources.appendInventory(plan, 256);
        scopedFactory.prepareSourceSet(scope);
        publicationGraph = publicationFactory.prepareGraph(scope, 7);
        publication.scope = scope;
        if (publishRoot) _providerPublication();
    }

    function _providerPublication() internal {
        snapshotContent = CheckpointHost(publicationGraph.children[1]);
        snapshotOutputs = OutputHostV2(publicationGraph.children[2]);
        snapshotHost = SnapshotHostV2(publicationGraph.children[3]);
        bytes32 selected = scopedSelections.begin(publication.scope);
        scopedSelections.append(selected, 16);
        bytes32 checkpoint =
            snapshotContent.begin(selected, keccak256("genuine factory provider checkpoint"));
        snapshotContent.append(checkpoint, _scopedPayload(publication.scope));
        Checkpoint.Plan memory p = snapshotContent.requireCurrentCheckpoint(checkpoint);
        Checkpoint.Output[] memory rows = new Checkpoint.Output[](p.tokenCount);
        for (uint256 i; i < rows.length; ++i) {
            rows[i] = snapshotContent.outputAt(checkpoint, i);
        }
        bytes memory raw = abi.encode(
            OutputDefinitions.SCHEMA,
            block.chainid,
            address(core),
            address(snapshotContent),
            checkpoint,
            keccak256(abi.encode(p)),
            snapshotContent.entropySourceSet(),
            p.inventoryHash,
            p.policyChainHash,
            p.scope,
            p.contentRoot,
            p.outputRoot,
            p.tokenCount,
            rows
        );
        (bytes32 artifact, bytes32 coverage) = _archive(raw);
        bytes32 outputPlan =
            snapshotOutputs.beginManifest(checkpoint, artifact, coverage, SNAPSHOT_ARTIST);
        bytes32 output = snapshotOutputs.verifyNextOutputs(outputPlan, p.tokenCount);
        publication = SnapshotTypes.Publication(
            p.scope,
            keccak256("genuine factory provider snapshot"),
            0,
            0,
            output,
            publicationGraph.inventoryPlan,
            0,
            "ipfs://genuine-factory-policy-snapshot",
            1000,
            keccak256("provider graph")
        );
        _configureJoinedRootBoundary();
        address registry = _joinedFinalityAddress();
        _mockWord(registry, "scopeEvidenceProvider()", abi.encode(address(actualProvider)));
        _mockWord(
            registry,
            "scopeEvidenceProviderCodeHash()",
            abi.encode(address(actualProvider).codehash)
        );
        adoptedSnapshot = _publish();
        adoptedRoot = _adopt(adoptedSnapshot, 1);
    }

    function _providerConfiguration() internal {
        NativeConfig.Config memory n;
        n.chainId = block.chainid;
        n.readGas = 2000000;
        n.componentSourceGas = 256000000;
        n.sourceGas = 512000000;
        n.inventoryDependencyHash = keccak256("explicit original inventory boundary");
        for (uint256 i; i < 22; ++i) {
            n.targets[i] = address(new ScopedPolicyProviderLateBoundaryV2());
        }
        n.targets[0] = address(core);
        n.targets[1] = address(metadata);
        n.targets[2] = address(router);
        n.targets[3] = address(scopedMembership);
        n.targets[4] = address(schemas);
        n.targets[5] = address(snapshotStore);
        n.targets[11] = address(artist);
        n.targets[12] = _joinedFinalityAddress();
        n.targets[20] = address(snapshotCoverage);
        n.targets[21] = address(externalArchive);
        for (uint256 i; i < 22; ++i) {
            n.codeHashes[i] = n.targets[i].codehash;
        }
        originalProviderConfig = n;
        for (uint256 i; i < 22; ++i) {
            originalScopedConfig.targets[i] = n.targets[i];
            originalScopedConfig.codeHashes[i] = n.codeHashes[i];
        }
        originalScopedConfig.chainId = n.chainId;
        originalScopedConfig.readGas = n.readGas;
        originalScopedConfig.sourceGas = n.sourceGas;
        originalScopedConfig.componentSourceGas = n.componentSourceGas;
        originalScopedConfig.inventoryDependencyHash =
            keccak256("explicit original scoped inventory boundary");
        uint256[4] memory scopedIndexes = [uint256(8), 9, 18, 19];
        for (uint256 i; i < 4; ++i) {
            uint256 j = scopedIndexes[i];
            originalScopedConfig.targets[j] = address(new ScopedPolicyProviderLateBoundaryV2());
            originalScopedConfig.codeHashes[j] = originalScopedConfig.targets[j].codehash;
        }
        collectionPolicyConfig = n;
        uint256[5] memory policyIndexes = [uint256(8), 9, 10, 18, 19];
        for (uint256 i; i < 5; ++i) {
            uint256 j = policyIndexes[i];
            collectionPolicyConfig.targets[j] = address(new ScopedPolicyProviderLateBoundaryV2());
            collectionPolicyConfig.codeHashes[j] = collectionPolicyConfig.targets[j].codehash;
        }
        oldPolicyOutput = address(new ScopedPolicyProviderLateBoundaryV2());
    }

    function _publicationRecipe() internal view returns (GraphTypes.Recipe memory r) {
        NativeConfig.Config memory n = originalProviderConfig;
        uint256[12] memory index = [uint256(0), 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21];
        for (uint256 i; i < 12; ++i) {
            if (i != 5 && i != 6) {
                r.inventory.targets[i] = n.targets[index[i]];
                r.inventory.codeHashes[i] = n.codeHashes[index[i]];
            }
        }
        for (uint256 i; i < 5; ++i) {
            r.inventory.artistTargets[i] = i == 0 ? address(artist) : n.targets[15];
            r.inventory.artistCodeHashes[i] = r.inventory.artistTargets[i].codehash;
        }
        r.inventory.artistContentOwner = n.targets[15];
        r.inventory.artistContentOwnerCodeHash = n.codeHashes[15];
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
            ProviderGas.GasParameterConfig("STATIC_CONTENT_READ_GAS", 8000000, 50000, 2);
        r.checkpointGas[1] =
            ProviderGas.GasParameterConfig("STATIC_CONTENT_RENDER_GAS", 16000000, 50000, 2);
        r.outputGas =
            ProviderGas.GasParameterConfig("STATIC_OUTPUT_MANIFEST_READ_GAS", 32000000, 50000, 2);
        r.snapshotGas = _snapshotGas();
        r.referenceGas = _referenceGas();
    }
}

contract StreamFinalityScopedPolicyEvidenceProviderV2Test is ScopedPolicyActualProviderFixtureV2 {
    function testActualProviderBootstrapHasCheapBudgetAndRequiresDeclaredCapForGenuineGraph()
        public
    {
        _providerSetup(2, false);
        (bool small, bytes memory out) = address(actualProvider).staticcall{ gas: 150000 }(
            abi.encodeCall(
                RootProviderBinding.scopedPolicySnapshotValidationGas, (publication.scope)
            )
        );
        require(small && abi.decode(out, (uint256)) == originalProviderConfig.componentSourceGas);
        (small,) = address(actualProvider).staticcall{ gas: 2000000 }(
            abi.encodeCall(RootProviderBinding.scopedPolicySnapshotHost, (publication.scope))
        );
        require(!small, "whole graph cannot use the scalar budget");
        require(
            actualProvider.scopedPolicySnapshotHost(publication.scope)
                == publicationGraph.children[3]
        );
        require(
            actualProvider.scopedPolicySnapshotCodeHash(publication.scope)
                == publicationGraph.codeHashes[3]
        );
        require(router.scopedContentRootHead(publication.scope) == 0);
        _providerPublication();
        require(
            adoptedRoot != 0
                && router.scopedContentRootRecord(adoptedRoot).snapshotHost
                    == publicationGraph.children[3]
        );
        require(
            snapshotHost.requireCurrent(publication.scope, adoptedSnapshot, 1).recordHash
                == adoptedSnapshot
        );
    }

    function testActualRootElectsGenuineFactorySourcesAndPreservesOldThreeCatalogueEntries()
        public
    {
        _providerSetup(2, true);
        FactoryBinding.FactoryBinding memory b = actualProvider.scopedPolicyPublicationBinding();
        require(
            b.configurationHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_POLICY_PROVIDER_CONFIGURATION_V2"),
                        block.chainid,
                        address(actualProvider),
                        originalProviderConfig,
                        b.factory,
                        b.factoryCodeHash,
                        b.recipeHash,
                        b.sourceFactoryDependenciesHash,
                        b.graphGas
                    )
                )
        );
        Profiles.Sources memory selected = actualProvider.finalitySourcesForScope(publication.scope);
        require(keccak256(abi.encode(selected.scope)) == keccak256(abi.encode(publication.scope)));
        require(selected.profile.profileHash == SnapshotDefinitions.PROFILE_HASH);
        require(
            selected.profile.snapshots == publicationGraph.children[3]
                && selected.profile.referenceRender == publicationGraph.children[4]
        );
        require(
            selected.profile.configurationHash == b.configurationHash
                && selected.profile.entropyFactory == address(scopedFactory)
        );
        for (uint8 i; i < 3; ++i) {
            require(
                keccak256(abi.encode(actualProvider.finalitySourceProfile(i)))
                    == keccak256(abi.encode(previousProvider.finalitySourceProfile(i)))
            );
        }
        require(
            actualProvider.scopedSnapshotHash(publication.scope)
                == snapshotHost.currentSnapshot(publication.scope).manifestHash
        );
        (bytes32 root, uint64 count, bytes32 schema) =
            actualProvider.scopedContentRoot(publication.scope);
        require(
            root == router.scopedContentRootRecord(adoptedRoot).contentRoot && count == 2
                && schema == OutputDefinitions.LEAF_SCHEMA
        );
    }

    function testOriginalCollectionSnapshotRemainsExactAfterScopedPolicyAdoption() public {
        _providerSetup(1, true);
        LegacySnapshot.Receipt memory old;
        old.manifestHash = keccak256("original COLLECTION exact manifest");
        snapshotVm.mockCall(
            originalProviderConfig.targets[8],
            abi.encodeWithSignature("currentSnapshot(uint256)", uint256(1)),
            abi.encode(old)
        );
        require(actualProvider.latestCollectionSnapshotHash(1) == old.manifestHash);
        require(previousProvider.latestCollectionSnapshotHash(1) == old.manifestHash);
        require(actualProvider.scopedSnapshotHash(publication.scope) != old.manifestHash);
    }

    function testUnknownProfileAndChangedGenuineChildFailWithoutLegacyFallback() public {
        _providerSetup(1, true);
        RootV2.Binding memory original = router.scopedPolicyContentRootBinding(adoptedRoot);
        RootV2.Binding memory changed = abi.decode(abi.encode(original), (RootV2.Binding));
        changed.profileId = keccak256("unknown profile");
        snapshotVm.mockCall(
            address(router),
            abi.encodeCall(RootV2.scopedPolicyContentRootBinding, (adoptedRoot)),
            abi.encode(changed)
        );
        vm.expectRevert();
        actualProvider.finalitySourcesForScope(publication.scope);
        vm.expectRevert();
        actualProvider.scopedSnapshotHash(publication.scope);
        snapshotVm.mockCall(
            address(router),
            abi.encodeCall(RootV2.scopedPolicyContentRootBinding, (adoptedRoot)),
            abi.encode(original)
        );
        bytes memory child = publicationGraph.children[4].code;
        vm.etch(publicationGraph.children[4], hex"00");
        vm.expectRevert();
        actualProvider.finalitySourcesForScope(publication.scope);
        vm.etch(publicationGraph.children[4], child);
        require(
            actualProvider.finalitySourcesForScope(publication.scope).profile.snapshots
                == address(snapshotHost)
        );
    }

    function testDeclaredRootGraphBudgetTooSmallFailsAndExactLargerValueRepairs() public {
        _providerSetup(1, false);
        // The actual provider/graph constructor is valid; only the selected provider's reported
        // read budget is fault-injected to exercise the Router's bounded transport branch.
        snapshotVm.mockCall(
            address(actualProvider),
            abi.encodeCall(
                RootProviderBinding.scopedPolicySnapshotValidationGas, (publication.scope)
            ),
            abi.encode(uint256(2000000))
        );
        // Prepare source publications while avoiding an expected revert over internal helpers.
        vm.expectRevert();
        this.prepareActualRoot();
        require(router.scopedContentRootHead(publication.scope) == 0);
        snapshotVm.mockCall(
            address(actualProvider),
            abi.encodeCall(
                RootProviderBinding.scopedPolicySnapshotValidationGas, (publication.scope)
            ),
            abi.encode(originalProviderConfig.componentSourceGas)
        );
        this.prepareActualRoot();
        require(adoptedRoot != 0);
    }

    function prepareActualRoot() external {
        require(msg.sender == address(this));
        _providerPublication();
    }

    function testConstructorRejectsInsufficientNestedBudgetAndRecipeMismatch() public {
        _providerSetup(1, false);
        FactoryBinding.FactoryBinding memory b = factoryBinding;
        b.graphGas = originalProviderConfig.componentSourceGas;
        vm.expectRevert();
        new ProviderV2(
            originalProviderConfig,
            originalScopedConfig,
            collectionPolicyConfig,
            oldPolicyOutput,
            oldPolicyOutput.codehash,
            b
        );
        b = factoryBinding;
        b.recipeHash ^= bytes32(uint256(1));
        vm.expectRevert();
        new ProviderV2(
            originalProviderConfig,
            originalScopedConfig,
            collectionPolicyConfig,
            oldPolicyOutput,
            oldPolicyOutput.codehash,
            b
        );
    }

    function testPreparedScopePathsRetainOriginalRegistryGuardAndExactTokenScope() public {
        _providerSetup(1, true);
        StreamFinalityComponentExpectation[] memory rows =
            new StreamFinalityComponentExpectation[](0);
        vm.expectRevert(abi.encodeWithSignature("NativeProviderOriginalRegistryOnly()"));
        actualProvider.requirePreparedFinalityScopeInputs(
            publication.scope, bytes32(uint256(1)), rows
        );
        vm.expectRevert(abi.encodeWithSignature("NativeProviderOriginalRegistryOnly()"));
        actualProvider.requirePreparedFinalityScopeInputsAndReview(
            publication.scope, bytes32(uint256(1)), rows
        );
        StreamFinalityScope memory wrong = publication.scope;
        wrong.collectionId = 2;
        vm.expectRevert();
        actualProvider.scopedPolicySnapshotHost(wrong);
        vm.expectRevert();
        actualProvider.scopedContentRoot(wrong);
        require(
            actualProvider.scopedPolicySnapshotValidationGas(publication.scope)
                == originalProviderConfig.componentSourceGas
        );
    }
}
