// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamCurrentFinalityGraph } from "./StreamCurrentFinalityGraph.sol";
import { StreamCurrentGraphCreation } from "./StreamCurrentGraphCreation.sol";
import {
    StreamStaticSelectionCheckpoint
} from "../../smart-contracts/domains/finality/StreamStaticSelectionCheckpoint.sol";
import {
    StreamStaticContentCheckpoint
} from "../../smart-contracts/domains/finality/StreamStaticContentCheckpoint.sol";
import {
    StreamStaticOutputManifest
} from "../../smart-contracts/domains/finality/StreamStaticOutputManifest.sol";
import {
    StreamScopedSnapshotPublication
} from "../../smart-contracts/domains/metadata/StreamScopedSnapshotPublication.sol";
import {
    StreamScopedReferencePublication
} from "../../smart-contracts/domains/preservation/StreamScopedReferencePublication.sol";
import {
    StreamScopedRenderCriticalInventory
} from "../../smart-contracts/domains/preservation/StreamScopedRenderCriticalInventory.sol";
import {
    StreamScopedBundleArchiveCoverage
} from "../../smart-contracts/domains/preservation/StreamScopedBundleArchiveCoverage.sol";
import {
    StreamFinalityEntropyPolicySourceFactoryV2
} from "../../smart-contracts/domains/finality/StreamFinalityEntropyPolicySourceFactoryV2.sol";
import {
    StreamFinalityScopedEntropyPolicySourceFactoryV2
} from "../../smart-contracts/domains/finality/StreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    StreamPolicyPublicationFactoryV2
} from "../../smart-contracts/domains/finality/StreamPolicyPublicationFactoryV2.sol";
import {
    StreamScopedPolicyPublicationFactoryV2
} from "../../smart-contracts/domains/finality/StreamScopedPolicyPublicationFactoryV2.sol";
import {
    StreamFinalityNativeProviderReads
} from "../../smart-contracts/domains/finality/StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityScopedProviderReads
} from "../../smart-contracts/domains/finality/StreamFinalityScopedProviderReads.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2
} from "../../smart-contracts/domains/finality/StreamFinalityCoordinatorPolicyReadsV2.sol";
import {
    StreamFinalityDiscoveryTypes
} from "../../smart-contracts/interfaces/stream/finality/StreamFinalityDiscoveryTypes.sol";
import {
    StreamScopedSnapshotTypes
} from "../../smart-contracts/interfaces/stream/metadata/StreamScopedSnapshotTypes.sol";
import {
    StreamScopedReferenceTypes
} from "../../smart-contracts/interfaces/stream/preservation/StreamScopedReferenceTypes.sol";
import {
    StreamRenderCriticalSourceTypes
} from "../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamBundleArchiveTypes
} from "../../smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamPolicyPublicationGraphTypesV2
} from "../../smart-contracts/interfaces/stream/finality/StreamPolicyPublicationGraphTypesV2.sol";
import {
    StreamScopedPolicyPublicationGraphTypesV2
} from "../../smart-contracts/interfaces/stream/finality/StreamScopedPolicyPublicationGraphTypesV2.sol";
import {
    IStreamPolicyPublicationGraphBindingV2
} from "../../smart-contracts/interfaces/stream/finality/IStreamPolicyPublicationGraphBindingV2.sol";
import {
    IStreamScopedPolicyPublicationEvidenceBindingV2
} from "../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyPublicationEvidenceBindingV2.sol";
import {
    IStreamFinalityFactoryProfileSourcesV2
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityFactoryProfileSourcesV2.sol";
import {
    StreamFinalityFullPolicyDiscoveryV2
} from "../../smart-contracts/domains/finality/StreamFinalityFullPolicyDiscoveryV2.sol";
import {
    IStreamGasParameterHost
} from "../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Genuine full-policy companions for the current graph's reserved CREATE topology.
/// @dev No inventory or publication is fabricated at construction. Per-plan publication children
/// are created only after genuine authoritative inventory and frozen original policies exist.
abstract contract StreamCurrentFullPolicyGraph is StreamCurrentFinalityGraph {
    StreamStaticSelectionCheckpoint internal fullPolicySelection;
    StreamStaticContentCheckpoint internal fullPolicyContent;
    StreamStaticOutputManifest internal fullPolicyOutput;
    StreamScopedSnapshotPublication internal fullPolicyScopedSnapshots;
    StreamScopedReferencePublication internal fullPolicyScopedReference;
    StreamScopedRenderCriticalInventory internal fullPolicyScopedInventory;
    StreamScopedBundleArchiveCoverage internal fullPolicyScopedBundle;
    StreamFinalityEntropyPolicySourceFactoryV2 internal fullPolicyCollectionSources;
    StreamFinalityScopedEntropyPolicySourceFactoryV2 internal fullPolicyScopedSources;
    StreamPolicyPublicationFactoryV2 internal fullPolicyCollectionFactory;
    StreamScopedPolicyPublicationFactoryV2 internal fullPolicyScopedFactory;

    /// @dev Reusable beside the original phase-one CurrentGraphStateV3. It records only
    /// actual companions and accepted constructor bindings, without inventing a current plan.
    struct FullPolicyCompanionState {
        uint256 chainId;
        address[11] products;
        bytes32[11] codeHashes;
        address provider;
        bytes32 providerCodeHash;
        address discovery;
        bytes32 discoveryCodeHash;
        IStreamPolicyPublicationGraphBindingV2.CollectionFactoryBinding collectionBinding;
        IStreamScopedPolicyPublicationEvidenceBindingV2.FactoryBinding scopedBinding;
        bytes32 sourceConfigurationHash;
    }

    function _assemblyComponentSourceGas() internal pure virtual override returns (uint256) {
        return 16000000;
    }

    function _assemblyManifestSourceGas() internal pure virtual override returns (uint256) {
        return 24000000;
    }

    function _fullPolicyCompanionState() internal view returns (FullPolicyCompanionState memory s) {
        s.chainId = block.chainid;
        s.products = [
            address(fullPolicySelection),
            address(fullPolicyContent),
            address(fullPolicyOutput),
            address(fullPolicyScopedSnapshots),
            address(fullPolicyScopedReference),
            address(fullPolicyScopedInventory),
            address(fullPolicyScopedBundle),
            address(fullPolicyCollectionSources),
            address(fullPolicyScopedSources),
            address(fullPolicyCollectionFactory),
            address(fullPolicyScopedFactory)
        ];
        for (uint256 i; i < 11; ++i) {
            require(s.products[i].code.length != 0, "actual full-policy companion");
            s.codeHashes[i] = _assemblyKnownCodeHash(s.products[i]);
        }
        s.provider = address(assemblyProvider);
        s.providerCodeHash = _assemblyKnownCodeHash(s.provider);
        s.discovery = address(assemblyDiscovery);
        s.discoveryCodeHash = _assemblyKnownCodeHash(s.discovery);
        s.collectionBinding =
            IStreamPolicyPublicationGraphBindingV2(s.provider).collectionPolicyPublicationBinding();
        s.scopedBinding = IStreamScopedPolicyPublicationEvidenceBindingV2(s.provider)
            .scopedPolicyPublicationBinding();
        IStreamPolicyPublicationGraphBindingV2.CollectionFactoryBinding memory collection =
            _fullPolicyCollectionBinding();
        IStreamScopedPolicyPublicationEvidenceBindingV2.FactoryBinding memory scoped =
            _fullPolicyScopedBinding();
        require(
            s.collectionBinding.configurationHash != 0 && s.scopedBinding.configurationHash != 0,
            "accepted factory configuration hashes"
        );
        collection.configurationHash = s.collectionBinding.configurationHash;
        scoped.configurationHash = s.scopedBinding.configurationHash;
        require(
            keccak256(abi.encode(collection)) == keccak256(abi.encode(s.collectionBinding))
                && keccak256(abi.encode(scoped)) == keccak256(abi.encode(s.scopedBinding)),
            "exact publication bindings"
        );
        // Recipe roots include every original/predicted late coordinate and governed budget.
        require(
            collection.recipeHash
                    == keccak256(
                        abi.encode(
                            StreamPolicyPublicationGraphTypesV2.PROFILE,
                            block.chainid,
                            _fullPolicyCollectionRecipe()
                        )
                    )
                && scoped.recipeHash
                    == keccak256(
                        abi.encode(
                            StreamScopedPolicyPublicationGraphTypesV2.PROFILE,
                            block.chainid,
                            _fullPolicyScopedRecipe()
                        )
                    ),
            "same immutable publication recipes"
        );
        bytes32 dependenciesHash = keccak256(abi.encode(_fullPolicySourceDependencies()));
        require(
            collection.sourceFactoryDependenciesHash == dependenciesHash
                && scoped.sourceFactoryDependenciesHash == dependenciesHash
                && keccak256(abi.encode(fullPolicyCollectionSources.dependencies()))
                    == dependenciesHash
                && keccak256(abi.encode(fullPolicyScopedSources.dependencies()))
                == dependenciesHash,
            "same original policy source dependencies"
        );
        s.sourceConfigurationHash =
            IStreamFinalityFactoryProfileSourcesV2(s.provider).finalitySourceConfigurationHash();
        require(
            s.sourceConfigurationHash != 0
                && StreamFinalityFullPolicyDiscoveryV2(s.discovery).sourceConfigurationHash()
                    == s.sourceConfigurationHash
                && StreamFinalityFullPolicyDiscoveryV2(s.discovery).scopeEvidenceProvider()
                    == s.provider,
            "same reciprocal discovery configuration"
        );
    }

    function _requireFullPolicyCompanionsUnchanged(FullPolicyCompanionState memory expected)
        internal
        view
    {
        require(
            keccak256(abi.encode(expected)) == keccak256(abi.encode(_fullPolicyCompanionState())),
            "unchanged full-policy companion checkpoint"
        );
    }

    function _assemblyProviderName() internal pure virtual override returns (string memory) {
        return "StreamFinalityFullPolicyEvidenceProviderV2";
    }

    function _assemblyProviderParents()
        internal
        pure
        virtual
        override
        returns (string[] memory parents)
    {
        parents = new string[](2);
        parents[0] = "StreamFinalityNativeEvidenceProvider";
        parents[1] = "StreamFinalityRouterEvidenceProvider";
    }

    function _assemblyProviderCreation() internal view virtual override returns (bytes memory) {
        return _graphCreation(
            StreamCurrentGraphCreation.Kind.StreamFinalityFullPolicyEvidenceProviderV2
        );
    }

    function _assemblyProviderArguments(StreamFinalityNativeProviderReads.Config memory c)
        internal
        view
        virtual
        override
        returns (bytes memory)
    {
        return abi.encode(
            c,
            _fullPolicyScopedConfiguration(c),
            _fullPolicyCollectionBinding(),
            _fullPolicyScopedBinding()
        );
    }

    function _assemblyDiscoveryName() internal pure virtual override returns (string memory) {
        return "StreamFinalityFullPolicyDiscoveryV2";
    }

    function _assemblyDiscoveryCreation() internal view virtual override returns (bytes memory) {
        return _graphCreation(StreamCurrentGraphCreation.Kind.StreamFinalityFullPolicyDiscoveryV2);
    }

    function _assemblyDiscoveryArguments(StreamFinalityDiscoveryTypes.Configuration memory d)
        internal
        view
        virtual
        override
        returns (bytes memory)
    {
        d.componentGas = _fullPolicyDiscoveryComponentGas();
        // The provider computes these hashes at its actual reserved address. Discovery pins
        // those exact accepted configurations, rather than the zero-hash constructor inputs.
        address provider = address(assemblyProvider);
        return abi.encode(
            d,
            IStreamFinalityFactoryProfileSourcesV2(provider).finalitySourceConfigurationHash(),
            IStreamPolicyPublicationGraphBindingV2(provider).collectionPolicyPublicationBinding(),
            IStreamScopedPolicyPublicationEvidenceBindingV2(provider)
                .scopedPolicyPublicationBinding()
        );
    }

    function _prepareAssemblyProviderCompanions() internal virtual override {
        require(address(fullPolicySelection) == address(0), "fresh full-policy companions");
        // Base late runtimes have already been derived. The same exact Coordinator and
        // selector hashes enter both future original products and these immutable recipes.
        _fullPolicyStaticCompanions();
        _fullPolicyScopedPublications();
        _fullPolicyScopedPreservation();
        StreamFinalityCoordinatorPolicyReadsV2.Dependencies memory d =
            _fullPolicySourceDependencies();
        fullPolicyCollectionSources = StreamFinalityEntropyPolicySourceFactoryV2(
            _assemblyCreate(
                StreamCurrentGraphCreation.Kind.StreamFinalityEntropyPolicySourceFactoryV2,
                abi.encode(d)
            )
        );
        fullPolicyScopedSources = StreamFinalityScopedEntropyPolicySourceFactoryV2(
            _assemblyCreate(
                StreamCurrentGraphCreation.Kind.StreamFinalityScopedEntropyPolicySourceFactoryV2,
                abi.encode(d)
            )
        );
        fullPolicyCollectionFactory = StreamPolicyPublicationFactoryV2(
            _assemblyCreate(
                StreamCurrentGraphCreation.Kind.StreamPolicyPublicationFactoryV2,
                abi.encode(_fullPolicyCollectionRecipe())
            )
        );
        fullPolicyScopedFactory = StreamScopedPolicyPublicationFactoryV2(
            _assemblyCreate(
                StreamCurrentGraphCreation.Kind.StreamScopedPolicyPublicationFactoryV2,
                abi.encode(_fullPolicyScopedRecipe())
            )
        );
    }

    function _fullPolicyDiscoveryComponentGas() internal pure virtual returns (uint32) {
        return 20000000;
    }

    function _fullPolicyStaticCompanions() private {
        fullPolicySelection = StreamStaticSelectionCheckpoint(
            payable(_assemblyCreate(
                    StreamCurrentGraphCreation.Kind.StreamStaticSelectionCheckpoint,
                    abi.encode(
                        address(assemblyCore),
                        address(assemblyRouter),
                        address(assemblyMembership),
                        address(assemblyExecutor),
                        _gas("STATIC_CHECKPOINT_READ_GAS", 500000, 50000, 1)
                    )
                ))
        );
        fullPolicyContent = StreamStaticContentCheckpoint(
            payable(_assemblyCreate(
                    StreamCurrentGraphCreation.Kind.StreamStaticContentCheckpoint,
                    abi.encode(
                        address(fullPolicySelection),
                        address(assemblyExecutor),
                        _gas("STATIC_CONTENT_READ_GAS", 2000000, 50000, 2),
                        _gas("STATIC_CONTENT_RENDER_GAS", 3000000, 50000, 2)
                    )
                ))
        );
        fullPolicyOutput = StreamStaticOutputManifest(
            payable(_assemblyCreate(
                    StreamCurrentGraphCreation.Kind.StreamStaticOutputManifest,
                    abi.encode(
                        address(assemblyCore),
                        address(fullPolicyContent),
                        address(assemblyArtifact),
                        address(assemblyExecutor),
                        _gas("STATIC_OUTPUT_MANIFEST_READ_GAS", 4000000, 50000, 2)
                    )
                ))
        );
    }

    function _fullPolicyScopedPublications() private {
        StreamScopedSnapshotTypes.Dependencies memory d;
        d.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblySchemas),
            address(assemblyStore),
            address(assemblyRouter),
            address(assemblyMembership),
            address(fullPolicySelection),
            address(fullPolicyContent),
            address(fullPolicyOutput),
            address(assemblyArtifact),
            address(assemblyCoordinators)
        ];
        for (uint256 i; i < 11; ++i) {
            d.codeHashes[i] = _assemblyKnownCodeHash(d.targets[i]);
        }
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.sourceGas = 6000000;
        d.inventoryGas = 4000000;
        IStreamGasParameterHost.GasParameterConfig[3] memory snapshotGas;
        snapshotGas[0] = _gas("SCOPED_SNAPSHOT_READ_GAS", d.readGas, 50000, 2);
        snapshotGas[1] = _gas("SCOPED_SNAPSHOT_SOURCE_GAS", d.sourceGas, 50000, 2);
        snapshotGas[2] = _gas("SCOPED_SNAPSHOT_INVENTORY_GAS", d.inventoryGas, 50000, 2);
        fullPolicyScopedSnapshots = StreamScopedSnapshotPublication(
            payable(_assemblyCreate(
                    StreamCurrentGraphCreation.Kind.StreamScopedSnapshotPublication,
                    abi.encode(d, address(assemblyExecutor), snapshotGas)
                ))
        );
        StreamScopedReferenceTypes.Dependencies memory r;
        r.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblySchemas),
            address(assemblyStore),
            address(assemblyRouter),
            address(fullPolicyScopedSnapshots),
            address(assemblyExternal)
        ];
        for (uint256 i; i < 7; ++i) {
            r.codeHashes[i] = _assemblyKnownCodeHash(r.targets[i]);
        }
        r.chainId = block.chainid;
        r.readGas = 500000;
        r.sourceGas = 4000000;
        r.snapshotGas = 8000000;
        r.archiveGas = 2000000;
        IStreamGasParameterHost.GasParameterConfig[4] memory referenceGas;
        referenceGas[0] = _gas("SCOPED_REFERENCE_READ_GAS", r.readGas, 50000, 1);
        referenceGas[1] = _gas("SCOPED_REFERENCE_SOURCE_GAS", r.sourceGas, 50000, 1);
        referenceGas[2] = _gas("SCOPED_REFERENCE_SNAPSHOT_GAS", r.snapshotGas, 50000, 1);
        referenceGas[3] = _gas("SCOPED_REFERENCE_ARCHIVE_GAS", r.archiveGas, 50000, 1);
        fullPolicyScopedReference = StreamScopedReferencePublication(
            payable(_assemblyCreate(
                    StreamCurrentGraphCreation.Kind.StreamScopedReferencePublication,
                    abi.encode(r, address(assemblyExecutor), referenceGas)
                ))
        );
    }

    function _fullPolicyScopedInventoryDependencies()
        internal
        view
        returns (StreamRenderCriticalSourceTypes.Dependencies memory d)
    {
        d = _assemblyInventoryDependencies();
        d.sourceGas = 8000000;
        d.snapshotGas = 10000000;
        d.referenceGas = 14000000;
        d.targets[5] = address(fullPolicyScopedSnapshots);
        d.codeHashes[5] = _assemblyKnownCodeHash(d.targets[5]);
        d.targets[6] = address(fullPolicyScopedReference);
        d.codeHashes[6] = _assemblyKnownCodeHash(d.targets[6]);
    }

    function _fullPolicyScopedPreservation() private {
        fullPolicyScopedInventory = StreamScopedRenderCriticalInventory(
            _assemblyCreate(
                StreamCurrentGraphCreation.Kind.StreamScopedRenderCriticalInventory,
                abi.encode(_fullPolicyScopedInventoryDependencies())
            )
        );
        StreamBundleArchiveTypes.Dependencies memory b;
        b.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(fullPolicyScopedInventory),
            address(assemblyArtifact),
            address(assemblyExternal),
            assemblySuite.archive
        ];
        for (uint256 i; i < 6; ++i) {
            b.codeHashes[i] = _assemblyKnownCodeHash(b.targets[i]);
        }
        b.chainId = block.chainid;
        b.readGas = 500000;
        b.archiveGas = 2000000;
        fullPolicyScopedBundle = StreamScopedBundleArchiveCoverage(
            _assemblyCreate(
                StreamCurrentGraphCreation.Kind.StreamScopedBundleArchiveCoverage, abi.encode(b)
            )
        );
    }

    function _fullPolicySourceDependencies()
        internal
        view
        returns (StreamFinalityCoordinatorPolicyReadsV2.Dependencies memory d)
    {
        d.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblyMembership),
            address(assemblyCoordinators)
        ];
        for (uint256 i; i < 4; ++i) {
            d.codeHashes[i] = _assemblyKnownCodeHash(d.targets[i]);
        }
        d.chainId = block.chainid;
        d.readGas = 150000;
        d.inventoryGas = 3000000;
    }

    function _fullPolicyCollectionRecipe()
        internal
        view
        virtual
        returns (StreamPolicyPublicationGraphTypesV2.Recipe memory r)
    {
        r.inventory = _assemblyInventoryDependencies();
        // Nested forwarding caps strictly increase toward the caller; these are configured
        // budgets, not measured gas acceptance evidence.
        r.inventory.sourceGas = 8000000;
        r.inventory.selectionGas = 8000000;
        r.inventory.snapshotGas = 16000000;
        r.inventory.referenceGas = 20000000;
        r.inventory.targets[5] = address(0);
        r.inventory.targets[6] = address(0);
        r.inventory.codeHashes[5] = 0;
        r.inventory.codeHashes[6] = 0;
        r.targets = [
            address(assemblyMembership),
            address(fullPolicySelection),
            address(fullPolicyCollectionSources),
            address(assemblyExecutor)
        ];
        for (uint256 i; i < 4; ++i) {
            r.codeHashes[i] = _assemblyKnownCodeHash(r.targets[i]);
        }
        r.readinessReadGas = 500000;
        r.readinessSourceGas = 4000000;
        r.factorySourceGas = 8000000;
        r.bundleReadGas = 500000;
        r.bundleArchiveGas = 2000000;
        r.checkpointGas[0] = _gas("STATIC_CONTENT_READ_GAS", 6000000, 50000, 2);
        r.checkpointGas[1] = _gas("STATIC_CONTENT_RENDER_GAS", 3000000, 50000, 2);
        r.outputGas = _gas("STATIC_OUTPUT_MANIFEST_READ_GAS", 8000000, 50000, 2);
        r.snapshotGas[0] = _gas("POLICY_SNAPSHOT_READ_GAS", 500000, 50000, 2);
        r.snapshotGas[1] = _gas("POLICY_SNAPSHOT_SOURCE_GAS", 12000000, 50000, 2);
        r.snapshotGas[2] = _gas("POLICY_SNAPSHOT_INVENTORY_GAS", 4000000, 50000, 2);
        r.referenceGas[0] = _gas("POLICY_REFERENCE_READ_GAS", 500000, 50000, 1);
        r.referenceGas[1] = _gas("POLICY_REFERENCE_SOURCE_GAS", 8000000, 50000, 1);
        r.referenceGas[2] = _gas("POLICY_REFERENCE_SNAPSHOT_GAS", 14000000, 50000, 1);
        r.referenceGas[3] = _gas("POLICY_REFERENCE_ARCHIVE_GAS", 2000000, 50000, 1);
    }

    function _fullPolicyScopedRecipe()
        internal
        view
        returns (StreamScopedPolicyPublicationGraphTypesV2.Recipe memory r)
    {
        StreamPolicyPublicationGraphTypesV2.Recipe memory c = _fullPolicyCollectionRecipe();
        r.inventory = c.inventory;
        r.targets = c.targets;
        r.codeHashes = c.codeHashes;
        r.targets[2] = address(fullPolicyScopedSources);
        r.codeHashes[2] = _assemblyKnownCodeHash(r.targets[2]);
        r.readinessReadGas = c.readinessReadGas;
        r.readinessSourceGas = c.readinessSourceGas;
        r.factorySourceGas = c.factorySourceGas;
        r.bundleReadGas = c.bundleReadGas;
        r.bundleArchiveGas = c.bundleArchiveGas;
        r.checkpointGas = c.checkpointGas;
        r.outputGas = c.outputGas;
        r.snapshotGas = c.snapshotGas;
        r.snapshotGas[0].name = "SCOPED_POLICY_SNAPSHOT_READ_GAS";
        r.snapshotGas[1].name = "SCOPED_POLICY_SNAPSHOT_SOURCE_GAS";
        r.snapshotGas[2].name = "SCOPED_POLICY_SNAPSHOT_INVENTORY_GAS";
        r.referenceGas = c.referenceGas;
        r.referenceGas[0].name = "SCOPED_POLICY_REFERENCE_READ_GAS";
        r.referenceGas[1].name = "SCOPED_POLICY_REFERENCE_SOURCE_GAS";
        r.referenceGas[2].name = "SCOPED_POLICY_REFERENCE_SNAPSHOT_GAS";
        r.referenceGas[3].name = "SCOPED_POLICY_REFERENCE_ARCHIVE_GAS";
    }

    function _fullPolicyScopedConfiguration(StreamFinalityNativeProviderReads.Config memory c)
        internal
        view
        returns (StreamFinalityScopedProviderReads.Config memory s)
    {
        // Copy each word: aliasing a memory array would modify the original configuration.
        for (uint256 i; i < 22; ++i) {
            s.targets[i] = c.targets[i];
            s.codeHashes[i] = c.codeHashes[i];
        }
        s.targets[6] = address(fullPolicyOutput);
        s.targets[7] = address(fullPolicyContent);
        s.targets[8] = address(fullPolicyScopedSnapshots);
        s.targets[9] = address(fullPolicyScopedReference);
        s.targets[18] = address(fullPolicyScopedInventory);
        s.targets[19] = address(fullPolicyScopedBundle);
        uint256[6] memory roles = [uint256(6), 7, 8, 9, 18, 19];
        for (uint256 i; i < 6; ++i) {
            s.codeHashes[roles[i]] = _assemblyKnownCodeHash(s.targets[roles[i]]);
        }
        s.chainId = c.chainId;
        s.readGas = c.readGas;
        s.sourceGas = c.sourceGas;
        s.componentSourceGas = c.componentSourceGas;
        s.inventoryDependencyHash = fullPolicyScopedInventory.dependencyHash();
    }

    function _fullPolicyCollectionBinding()
        internal
        view
        returns (IStreamPolicyPublicationGraphBindingV2.CollectionFactoryBinding memory b)
    {
        b.factory = address(fullPolicyCollectionFactory);
        b.factoryCodeHash = b.factory.codehash;
        b.recipeHash = fullPolicyCollectionFactory.recipeHash();
        b.sourceFactoryDependenciesHash =
            fullPolicyCollectionFactory.sourceFactoryDependenciesHash();
        b.graphGas = 12000000;
    }

    function _fullPolicyScopedBinding()
        internal
        view
        returns (IStreamScopedPolicyPublicationEvidenceBindingV2.FactoryBinding memory b)
    {
        b.factory = address(fullPolicyScopedFactory);
        b.factoryCodeHash = b.factory.codehash;
        b.recipeHash = fullPolicyScopedFactory.recipeHash();
        b.sourceFactoryDependenciesHash = fullPolicyScopedFactory.sourceFactoryDependenciesHash();
        b.graphGas = 12000000;
    }
}
