// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistEstateCoverage
} from "../../smart-contracts/domains/artist/StreamArtistEstateCoverage.sol";
import {
    StreamArtistTimingState
} from "../../smart-contracts/domains/artist/StreamArtistTimingState.sol";
import {
    StreamCurrentArtistFactoryCalls
} from "./StreamCurrentArtistFactoryCalls.sol";

import { StreamCurrentGraphKinds } from "./StreamCurrentGraphKinds.sol";
import { StreamArchivalCoverage } from "../../smart-contracts/domains/preservation/StreamArchivalCoverage.sol";
import { StreamArtistOnboardingCoordinator } from "../../smart-contracts/domains/artist/StreamArtistOnboardingCoordinator.sol";
import { StreamArtistOnboardingRegistry } from "../../smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol";
import { StreamArweaveCheckpointVerifier } from "../../smart-contracts/domains/preservation/StreamArweaveCheckpointVerifier.sol";
import { StreamArweaveObjectCheckpointVerifier } from "../../smart-contracts/domains/preservation/StreamArweaveObjectCheckpointVerifier.sol";
import { StreamAssetPolicyRegistry } from "../../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol";
import { StreamCollectionSnapshots } from "../../smart-contracts/domains/metadata/StreamCollectionSnapshots.sol";
import { StreamCollectionTokenInventory } from "../../smart-contracts/domains/finality/StreamCollectionTokenInventory.sol";
import { StreamContentLeafManifest } from "../../smart-contracts/domains/finality/StreamContentLeafManifest.sol";
import { StreamCoreFinalityAdapter } from "../../smart-contracts/domains/finality/StreamCoreFinalityAdapter.sol";
import { StreamExternalArtifactCoverage } from "../../smart-contracts/domains/preservation/StreamExternalArtifactCoverage.sol";
import { StreamFinalityArtifactCoverage } from "../../smart-contracts/domains/preservation/StreamFinalityArtifactCoverage.sol";
import { StreamFinalityCoordinatorInventory } from "../../smart-contracts/domains/finality/StreamFinalityCoordinatorInventory.sol";
import { StreamFinalityEntropySourceFactory } from "../../smart-contracts/domains/finality/StreamFinalityEntropySourceFactory.sol";
import { StreamFinalityScopeMembership } from "../../smart-contracts/domains/finality/StreamFinalityScopeMembership.sol";
import { StreamFinalityServingHostAdapter } from "../../smart-contracts/domains/finality/StreamFinalityServingHostAdapter.sol";
import { StreamGovernanceExecutor } from "../../smart-contracts/domains/governance/StreamGovernanceExecutor.sol";
import { StreamMintLedger } from "../../smart-contracts/domains/mint/StreamMintLedger.sol";
import { StreamMintManager } from "../../smart-contracts/domains/mint/StreamMintManager.sol";
import { StreamOnchainContentCheckpoint } from "../../smart-contracts/domains/finality/StreamOnchainContentCheckpoint.sol";
import { StreamReferenceRenderPublication } from "../../smart-contracts/domains/preservation/StreamReferenceRenderPublication.sol";
import { StreamRevenueResolver } from "../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";
import { StreamRoleRegistry } from "../../smart-contracts/domains/governance/StreamRoleRegistry.sol";
import { StreamRoyaltyResolver } from "../../smart-contracts/domains/revenue/StreamRoyaltyResolver.sol";
import { StreamSplitFactory } from "../../smart-contracts/domains/revenue/StreamSplitFactory.sol";
import { StreamSystemManifest } from "../../smart-contracts/domains/governance/StreamSystemManifest.sol";
import { StreamArtistOnboardingTypes as T } from "../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import "./StreamCurrentAuthorityGraphCreation.sol";
import {
    StreamArtistCurrentAuthorityTypes as CurrentAuthority
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as AuthorityInventory
} from "../../smart-contracts/interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamArtistArchiveOriginTypes as ArchiveOrigin
} from "../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import "./StreamCurrentFinalityArtifacts.sol";
import "./StreamDeploymentSlot.sol";
import "./StreamCurrentStackPlan.sol";
import "../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import "../../smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol";
import "../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";
import {
    StreamReferenceRendererCatalog
} from "../../smart-contracts/domains/records/StreamReferenceRendererCatalog.sol";
import "../../smart-contracts/domains/finality/StreamFinalityCoordinatorPolicyReads.sol";

import {
    StreamRenderCriticalSourceTypes
} from "../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamBundleArchiveTypes
} from "../../smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamReferenceRenderTypes
} from "../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamSnapshotTypes
} from "../../smart-contracts/interfaces/stream/metadata/StreamSnapshotTypes.sol";
import {
    StreamFinalityDiscoveryTypes
} from "../../smart-contracts/interfaces/stream/finality/StreamFinalityDiscoveryTypes.sol";
import {
    StreamFinalityNativeProviderReads
} from "../../smart-contracts/domains/finality/StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityDomains
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityDeploymentConfiguration
} from "../../smart-contracts/interfaces/stream/finality/StreamFinalityDeploymentTypes.sol";
import {
    StreamArchivalTypes
} from "../../smart-contracts/interfaces/stream/preservation/StreamArchivalTypes.sol";

/// @notice Original current-authority Finality graph, constructed before presentation locks.
/// @dev This additive recipe retains complete linked-runtime and one-use CREATE verification.
/// It does not import deployed legacy selector history or resume a legacy V3 graph checkpoint.
/// The resolver has constructor-only storage, so its runtime is predicted independently of its
/// provider anchor: provider is installed first, then the resolver, then Finality and Coordinator.
abstract contract StreamCurrentAuthorityFinalityGraph is StreamCurrentFinalityArtifacts {
    address internal graphOperator;
    bytes32 internal graphDeploymentHash;
    bytes32 internal graphFinalityManifestHash;
    string internal graphFinalityManifestURI;
    bytes32 internal graphRendererCatalogId;
    StreamGovernanceExecutor internal assemblyExecutor;
    StreamRoleRegistry internal assemblyRoles;
    StreamModuleRegistry internal assemblyModules;
    StreamCore internal assemblyCore;
    StreamSystemManifest internal assemblyManifest;
    StreamDeploymentSlot internal assemblyCoordinatorSlot;
    address internal assemblyCoordinatorAddress;
    bytes internal assemblyCoordinatorRuntime;
    StreamMintLedger internal assemblyLedger;
    StreamMintManager internal assemblyManager;
    StreamAssetPolicyRegistry internal assemblyAssetPolicy;
    StreamSplitFactory internal assemblySplits;
    StreamArtistOnboardingRegistry internal assemblyArtists;
    StreamArtistOnboardingCoordinator internal assemblyCoordinator;
    T.SuiteConfiguration internal assemblySuite;
    StreamMetadataRouter internal assemblyRouter;
    StreamRevenueResolver internal assemblyPrimary;
    StreamRoyaltyResolver internal assemblyRoyalties;
    StreamArweaveCheckpointVerifier internal assemblyCheckpointVerifier;
    StreamArchivalCoverage internal assemblyArchive;
    StreamSchemaRegistry internal assemblySchemas;
    StreamSchemaDocumentStore internal assemblyStore;
    StreamCollectionMetadataV1 internal assemblyMetadata;
    enum Late {
        PROVIDER,
        CORE_ADAPTER,
        DISCOVERY,
        REGISTRY,
        WORK,
        RIGHTS,
        CONSERVATION,
        INVENTORY,
        BUNDLE
    }
    StreamDeploymentSlot[9] internal assemblySlots;
    address[9] internal assemblyLate;
    bytes[9] internal assemblyRuntimes;
    StreamCollectionTokenInventory internal assemblyTokens;
    StreamFinalityScopeMembership internal assemblyMembership;
    StreamFinalityCoordinatorInventory internal assemblyCoordinators;
    StreamFinalityEntropySourceFactory internal assemblyEntropyFactory;
    StreamOnchainContentCheckpoint internal assemblyContentCheckpoint;
    StreamContentLeafManifest internal assemblyLeaves;
    StreamFinalityArtifactCoverage internal assemblyArtifact;
    StreamArweaveObjectCheckpointVerifier internal assemblyObjectVerifier;
    StreamExternalArtifactCoverage internal assemblyExternal;
    StreamCollectionSnapshots internal assemblySnapshots;
    StreamReferenceRenderPublication internal assemblyReference;
    StreamCurrentAuthorityNativeEvidenceProvider internal assemblyProvider;
    StreamCoreFinalityAdapter internal assemblyCoreAdapter;
    StreamFinalityLineageCurrentDiscovery internal assemblyDiscovery;
    StreamLineageArtworkFinalityRegistry internal assemblyFinality;
    StreamCurrentAuthorityWorkRecordSelection internal assemblyWork;
    StreamCurrentAuthorityRightsRecordSelection internal assemblyRights;
    StreamCurrentAuthorityConservationRecordSelection internal assemblyConservation;
    StreamCurrentAuthorityRenderCriticalInventory internal assemblyInventory;
    StreamCurrentAuthorityBundleArchiveCoverage internal assemblyBundle;
    address[6] internal assemblyRouterAdapters;
    address internal assemblyMetadataAdapter;

    function _graphCreation(StreamCurrentGraphKinds.Kind kind)
        internal
        view
        virtual
        returns (bytes memory);

    function _authorityCreation(StreamCurrentAuthorityGraphCreation.Kind kind)
        internal
        view
        virtual
        returns (bytes memory);

    StreamDeploymentSlot internal assemblyAuthorityResolverSlot;
    address internal assemblyAuthorityResolverAddress;
    bytes internal assemblyAuthorityResolverRuntime;
    StreamArtistCurrentAuthorityResolver internal assemblyAuthorityResolver;
    StreamArtistArchiveOriginReads internal assemblyOriginWorker;

    function _reserveCurrentCoordinator(address operator_) internal returns (address) {
        require(graphOperator == address(0) && operator_ != address(0), "fresh graph operator");
        graphOperator = operator_;
        (assemblyCoordinatorSlot, assemblyCoordinatorAddress) = _slot();
        return assemblyCoordinatorAddress;
    }

    function _bindCurrentArtistGraph(
        T.SuiteConfiguration memory suite,
        address modules_,
        address executor_,
        address manifest_,
        address archive_,
        address checkpoint_,
        bytes32 deploymentHash
    ) internal {
        require(
            address(assemblyCore) == address(0) && graphOperator != address(0),
            "fresh graph binding"
        );
        require(
            suite.registry.code.length != 0 && suite.core.code.length != 0,
            "actual early artist graph"
        );
        require(
            StreamArtistOnboardingRegistry(payable(suite.registry)).operationCoordinator()
                == assemblyCoordinatorAddress,
            "original reserved Coordinator"
        );
        assemblySuite = suite;
        assemblyCore = StreamCore(payable(suite.core));
        assemblyManager = StreamMintManager(payable(suite.mintManager));
        assemblyRoles = StreamRoleRegistry(suite.roleRegistry);
        assemblyModules = StreamModuleRegistry(modules_);
        assemblyExecutor = StreamGovernanceExecutor(payable(executor_));
        assemblyManifest = StreamSystemManifest(manifest_);
        assemblyArtists = StreamArtistOnboardingRegistry(payable(suite.registry));
        assemblyRouter = StreamMetadataRouter(suite.metadata);
        assemblyPrimary = StreamRevenueResolver(suite.primaryResolver);
        assemblyRoyalties = StreamRoyaltyResolver(suite.royaltyResolver);
        assemblyArchive = StreamArchivalCoverage(archive_);
        assemblyCheckpointVerifier = StreamArweaveCheckpointVerifier(checkpoint_);
        graphDeploymentHash = deploymentHash;
        graphFinalityManifestHash = keccak256("current-stack native finality module v1");
        graphFinalityManifestURI = "https://engineering.example.invalid/6529stream/current/finality";
        graphRendererCatalogId = keccak256("STREAM_CURRENT_REFERENCE_RENDERER_CLASS_V1");
        assemblySchemas = StreamSchemaRegistry(
            payable(_assemblyCreate(
                    StreamCurrentGraphKinds.Kind.StreamSchemaRegistry, abi.encode(executor_)
                ))
        );
        assemblyStore = StreamSchemaDocumentStore(assemblySchemas.chunkStore());
        assemblyMetadata = StreamCollectionMetadataV1(
            payable(_assemblyCreate(
                    StreamCurrentGraphKinds.Kind.StreamCollectionMetadataV1,
                    abi.encode(
                        StreamCollectionMetadataV1.Configuration(
                            suite.core,
                            executor_,
                            address(assemblySchemas),
                            suite.registry,
                            deploymentHash,
                            "https://engineering.example.invalid/6529stream/current/metadata",
                            keccak256("current-stack collection metadata module v1"),
                            _gas("METADATA_DEPENDENCY_READ_GAS", 400000, 50000, 1),
                            _gas("METADATA_ARTIST_READ_GAS", 12000000, 50000, 1)
                        )
                    )
                ))
        );
        _deployCurrentGraphPrerequisites();
    }

    function _requireCurrentGraphSelections() internal view {
        _requireCurrentGraphFoundationSelections();
        bytes32[3] memory keys = [
            keccak256("COLLECTION_METADATA"),
            keccak256("METADATA_ROUTER"),
            keccak256("ARTIST_REGISTRY")
        ];
        address[3] memory targets =
            [address(assemblyMetadata), address(assemblyRouter), address(assemblyArtists)];
        for (uint256 i; i < 3; ++i) {
            StreamCorePointerState memory selected =
                StreamCurrentStackPlan.readPointer(assemblyCore, keys[i]);
            require(
                selected.target == targets[i] && selected.codeHash == targets[i].codehash
                    && selected.registryStatus == 1,
                "executed original graph pointer selection"
            );
        }
    }

    function _requireCurrentGraphFoundationSelections() private view {
        StreamCorePointerState memory modules =
            StreamCurrentStackPlan.readPointer(assemblyCore, keccak256("MODULE_REGISTRY"));
        require(
            modules.target == address(assemblyModules)
                && modules.codeHash == address(assemblyModules).codehash
                && modules.registryStatus == 1,
            "actual selected ModuleRegistry"
        );
        StreamCorePointerState memory manifestPointer =
            StreamCurrentStackPlan.readPointer(assemblyCore, keccak256("SYSTEM_MANIFEST"));
        require(
            manifestPointer.target == address(assemblyManifest)
                && manifestPointer.codeHash == address(assemblyManifest).codehash
                && manifestPointer.frozen && manifestPointer.registryStatus == 1,
            "original frozen SystemManifest"
        );
    }

    function _currentGraphRendererCatalog(uint256 collectionId)
        internal
        view
        returns (bytes memory)
    {
        // Raw serving facts expose the immutable linked renderer before artwork publication.
        // Only its fixed identity/profile enter this catalog; configured/locked readiness does not.
        IStreamMetadataServingFacts.ServingFacts memory f =
            assemblyRouter.collectionServingFacts(collectionId);
        (bytes32 presentation, bytes32 context, bytes32 dependencies) =
            assemblyRouter.renderingProfile();
        (string memory uri, bytes32 manifest) = assemblyRouter.streamModuleManifest();
        require(
            bytes(uri).length != 0 && f.renderer.code.length != 0
                && f.renderer.codehash == f.rendererCodeHash,
            "actual original linked renderer"
        );
        return StreamReferenceRendererCatalog.declarationJSON(
            StreamReferenceRenderTypes.RendererDeclaration(
                f.renderer,
                f.rendererCodeHash,
                assemblyRouter.streamModuleVersion(),
                manifest,
                presentation,
                context,
                dependencies,
                keccak256("STATIC")
            )
        );
    }

    function _completeCurrentFinalityGraph(bytes memory rendererCatalog) internal {
        require(
            address(assemblyCoordinator) == address(0)
                && assemblyCoordinatorAddress.code.length == 0,
            "original Coordinator not yet deployed"
        );
        _requireCurrentGraphSelections();
        _deployCurrentGraphSourceHosts(rendererCatalog);
        _deployAssemblyFinalityGraph();
    }

    function _deployCurrentGraphPrerequisites() internal {
        (assemblyAuthorityResolverSlot, assemblyAuthorityResolverAddress) = _slot();
        assemblyOriginWorker = StreamArtistArchiveOriginReads(
            _authorityCreate(
                StreamCurrentAuthorityGraphCreation.Kind.StreamArtistArchiveOriginReads, bytes("")
            )
        );
        for (uint256 i; i < 9; ++i) {
            (assemblySlots[i], assemblyLate[i]) = _slot();
        }
        assemblyTokens = StreamCollectionTokenInventory(
            payable(_assemblyCreate(
                    StreamCurrentGraphKinds.Kind.StreamCollectionTokenInventory,
                    abi.encode(
                        address(assemblyCore),
                        address(assemblyExecutor),
                        _gas("TOKEN_INVENTORY_CORE_READ_GAS", 150000, 50000, 1)
                    )
                ))
        );
        assemblyMembership = StreamFinalityScopeMembership(
            payable(_assemblyCreate(
                    StreamCurrentGraphKinds.Kind.StreamFinalityScopeMembership,
                    abi.encode(
                        address(assemblyCore),
                        address(assemblyMetadata),
                        address(assemblyTokens),
                        address(assemblyExecutor),
                        _gas("SCOPE_MEMBERSHIP_READ_GAS", 500000, 50000, 1)
                    )
                ))
        );
        assemblyCoordinators = StreamFinalityCoordinatorInventory(
            payable(_assemblyCreate(
                    StreamCurrentGraphKinds.Kind.StreamFinalityCoordinatorInventory,
                    abi.encode(address(assemblyCore), address(assemblyMembership), 150000, 2000000)
                ))
        );
        StreamFinalityCoordinatorPolicyReads.Dependencies memory entropyDependencies;
        entropyDependencies.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblyMembership),
            address(assemblyCoordinators)
        ];
        for (uint256 i; i < 4; ++i) {
            entropyDependencies.codeHashes[i] = entropyDependencies.targets[i].codehash;
        }
        entropyDependencies.chainId = block.chainid;
        entropyDependencies.readGas = 150000;
        entropyDependencies.inventoryGas = 3000000;
        assemblyEntropyFactory = StreamFinalityEntropySourceFactory(
            payable(_assemblyCreate(
                    StreamCurrentGraphKinds.Kind.StreamFinalityEntropySourceFactory,
                    abi.encode(entropyDependencies)
                ))
        );
        assemblyContentCheckpoint = StreamOnchainContentCheckpoint(
            payable(_assemblyCreate(
                    StreamCurrentGraphKinds.Kind.StreamOnchainContentCheckpoint,
                    abi.encode(
                        address(assemblyCore),
                        address(assemblyRouter),
                        address(assemblyTokens),
                        address(assemblyExecutor),
                        _gas("CONTENT_CHECKPOINT_READ_GAS", 500000, 50000, 1),
                        _gas("CONTENT_CHECKPOINT_RENDER_GAS", 3000000, 50000, 1)
                    )
                ))
        );
        assemblyArtifact = StreamFinalityArtifactCoverage(
            payable(_assemblyCreate(
                    StreamCurrentGraphKinds.Kind.StreamFinalityArtifactCoverage,
                    abi.encode(
                        address(assemblyCore),
                        address(assemblyArchive),
                        address(assemblySchemas),
                        address(assemblyStore),
                        assemblyLate[uint256(Late.REGISTRY)],
                        address(assemblyExecutor),
                        _gas("FINALITY_ARTIFACT_DEPENDENCY_READ_GAS", 500000, 300000, 2)
                    )
                ))
        );
        assemblyLeaves = StreamContentLeafManifest(
            payable(_assemblyCreate(
                    StreamCurrentGraphKinds.Kind.StreamContentLeafManifest,
                    abi.encode(
                        address(assemblyCore),
                        address(assemblyContentCheckpoint),
                        address(assemblyArtifact),
                        address(assemblyExecutor),
                        _gas("CONTENT_LEAF_MANIFEST_READ_GAS", 1000000, 50000, 2)
                    )
                ))
        );
        StreamArchivalTypes.Observer[] memory observers = assemblyCheckpointVerifier.observers();
        assemblyObjectVerifier = StreamArweaveObjectCheckpointVerifier(
            payable(_assemblyCreate(
                    StreamCurrentGraphKinds.Kind.StreamArweaveObjectCheckpointVerifier,
                    abi.encode(
                        address(assemblyExecutor),
                        observers,
                        assemblyCheckpointVerifier.quorum(),
                        _gas("ARCHIVAL_ERC1271_VERIFY_GAS", 400000, 90000, 2)
                    )
                ))
        );
        assemblyExternal = StreamExternalArtifactCoverage(
            payable(_assemblyCreate(
                    StreamCurrentGraphKinds.Kind.StreamExternalArtifactCoverage,
                    abi.encode(
                        address(assemblyCore),
                        address(assemblyExecutor),
                        address(assemblyRoles),
                        address(assemblyObjectVerifier),
                        _gas("EXTERNAL_ARCHIVE_READ_GAS", 500000, 150000, 2),
                        _gas("EXTERNAL_ARCHIVE_SIGNATURE_GAS", 400000, 90000, 2)
                    )
                ))
        );
    }

    function _deployCurrentGraphSourceHosts(bytes memory rendererCatalog) internal {
        StreamSnapshotTypes.Dependencies memory d;
        d.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblySchemas),
            address(assemblyStore),
            address(assemblyRouter),
            address(assemblyLeaves),
            address(assemblyContentCheckpoint),
            address(assemblyMembership),
            address(assemblyCoordinators)
        ];
        for (uint256 i; i < 9; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.sourceGas = 2000000;
        d.evidenceGas = 2000000;
        d.inventoryGas = 3000000;
        IStreamGasParameterHost.GasParameterConfig[4] memory configs;
        configs[0] = _gas("SNAPSHOT_READ_GAS", d.readGas, 50000, 1);
        configs[1] = _gas("SNAPSHOT_SOURCE_GAS", d.sourceGas, 50000, 1);
        configs[2] = _gas("SNAPSHOT_EVIDENCE_GAS", d.evidenceGas, 50000, 1);
        configs[3] = _gas("SNAPSHOT_INVENTORY_GAS", d.inventoryGas, 50000, 1);
        assemblySnapshots = StreamCollectionSnapshots(
            payable(_assemblyCreate(
                    StreamCurrentGraphKinds.Kind.StreamCollectionSnapshots,
                    abi.encode(d, address(assemblyExecutor), configs)
                ))
        );
        _deployAssemblyReference(rendererCatalog);
    }

    function _gas(string memory name, uint256 value, uint256 floor, uint8 failure)
        internal
        pure
        returns (IStreamGasParameterHost.GasParameterConfig memory)
    {
        return IStreamGasParameterHost.GasParameterConfig(name, value, floor, failure);
    }

    function _deployAssemblyReference(bytes memory catalog) private {
        // The caller derives these exact catalog bytes from the configured original renderer.
        // They are admitted by schema governance before publication, without placeholder data.
        require(catalog.length != 0, "actual renderer catalog bytes");
        StreamReferenceRenderTypes.Dependencies memory d;
        d.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblySchemas),
            address(assemblyStore),
            address(assemblyRouter),
            address(assemblySnapshots),
            address(assemblyExternal)
        ];
        for (uint256 i; i < 7; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.rendererCatalogId = graphRendererCatalogId;
        d.rendererCatalogHash = keccak256(catalog);
        d.rendererCatalogBytes = uint32(catalog.length);
        d.readGas = 500000;
        d.sourceGas = 4000000;
        d.snapshotGas = 6000000;
        d.archiveGas = 2000000;
        IStreamGasParameterHost.GasParameterConfig[4] memory configs;
        configs[0] = _gas("REFERENCE_READ_GAS", d.readGas, 50000, 1);
        configs[1] = _gas("REFERENCE_SOURCE_GAS", d.sourceGas, 50000, 1);
        configs[2] = _gas("REFERENCE_SNAPSHOT_GAS", d.snapshotGas, 50000, 1);
        configs[3] = _gas("REFERENCE_ARCHIVE_GAS", d.archiveGas, 50000, 1);
        assemblyReference = StreamReferenceRenderPublication(
            payable(_assemblyCreate(
                    StreamCurrentGraphKinds.Kind.StreamReferenceRenderPublication,
                    abi.encode(d, address(assemblyExecutor), configs)
                ))
        );
    }

    function _predictAssemblyLateRuntimes() internal {
        assemblyAuthorityResolverRuntime = _productRuntime(
            "StreamArtistCurrentAuthorityResolver",
            new string[](0),
            _authorityCreation(
                StreamCurrentAuthorityGraphCreation.Kind.StreamArtistCurrentAuthorityResolver
            ),
            new RuntimeValue[](0)
        );
        RuntimeValue[] memory v = new RuntimeValue[](15);
        string memory base = "StreamFinalityRouterEvidenceProvider";
        v[0] = _finalityValue(base, "core", _addressWord(address(assemblyCore)));
        v[1] = _finalityValue(base, "coreCodeHash", address(assemblyCore).codehash);
        v[2] = _finalityValue(base, "metadataHost", _addressWord(address(assemblyMetadata)));
        v[3] = _finalityValue(base, "metadataHostCodeHash", address(assemblyMetadata).codehash);
        v[4] = _finalityValue(base, "metadataRouter", _addressWord(address(assemblyRouter)));
        v[5] = _finalityValue(base, "metadataRouterCodeHash", address(assemblyRouter).codehash);
        v[6] =
            _finalityValue(base, "scopeMembershipHost", _addressWord(address(assemblyMembership)));
        v[7] = _finalityValue(
            base, "scopeMembershipHostCodeHash", address(assemblyMembership).codehash
        );
        v[8] = _finalityValue(base, "deploymentChainId", bytes32(block.chainid));
        v[9] = _finalityValue(base, "readGas", bytes32(uint256(500000)));
        v[10] = _finalityValue(base, "sourceGas", bytes32(_assemblyComponentSourceGas()));
        v[11] = _finalityValue(base, "routerModuleVersion", assemblyRouter.streamModuleVersion());
        (, bytes32 routerManifest) = assemblyRouter.streamModuleManifest();
        (, bytes32 metadataManifest) = assemblyMetadata.streamModuleManifest();
        v[12] = _finalityValue(base, "routerModuleManifestHash", routerManifest);
        v[13] = _finalityValue(
            "StreamCurrentAuthorityNativeEvidenceProvider",
            "metadataModuleVersion",
            assemblyMetadata.streamModuleVersion()
        );
        v[14] = _finalityValue(
            "StreamCurrentAuthorityNativeEvidenceProvider",
            "metadataModuleManifestHash",
            metadataManifest
        );
        (string memory providerName, string[] memory parents, bytes memory providerCreation) =
            _assemblyProviderTemplate();
        assemblyRuntimes[uint256(Late.PROVIDER)] =
            _productRuntime(providerName, parents, providerCreation, v);
        v = new RuntimeValue[](6);
        base = "StreamCoreFinalityAdapter";
        v[0] = _finalityValue(base, "core", _addressWord(address(assemblyCore)));
        v[1] = _finalityValue(base, "collectionMetadata", _addressWord(address(assemblyMetadata)));
        v[2] = _finalityValue(
            base, "evidenceProvider", _addressWord(assemblyLate[uint256(Late.PROVIDER)])
        );
        v[3] = _finalityValue(base, "_coreCodeHash", address(assemblyCore).codehash);
        v[4] = _finalityValue(base, "_metadataCodeHash", address(assemblyMetadata).codehash);
        v[5] = _finalityValue(
            base, "_providerCodeHash", keccak256(assemblyRuntimes[uint256(Late.PROVIDER)])
        );
        assemblyRuntimes[uint256(Late.CORE_ADAPTER)] = _productRuntime(
            base,
            new string[](0),
            _graphCreation(StreamCurrentGraphKinds.Kind.StreamCoreFinalityAdapter),
            v
        );
        (
            string memory discoveryName,
            string[] memory discoveryParents,
            bytes memory discoveryCreation
        ) = _assemblyDiscoveryTemplate();
        base = discoveryName;
        v = new RuntimeValue[](4);
        v[0] = _finalityValue(base, "core", _addressWord(address(assemblyCore)));
        v[1] = _finalityValue(base, "metadataHost", _addressWord(address(assemblyMetadata)));
        v[2] = _finalityValue(
            base, "scopeEvidenceProvider", _addressWord(assemblyLate[uint256(Late.PROVIDER)])
        );
        v[3] = _finalityValue(base, "deploymentChainId", bytes32(block.chainid));
        assemblyRuntimes[uint256(Late.DISCOVERY)] =
            _productRuntime(base, discoveryParents, discoveryCreation, v);
        _predictAssemblyRegistryRuntime();
        _predictAssemblyCoordinatorRuntime();
        assemblyRuntimes[uint256(Late.WORK)] = _selectorRuntime(
            "StreamCurrentAuthorityWorkRecordSelection",
            _authorityCreation(
                StreamCurrentAuthorityGraphCreation.Kind.StreamCurrentAuthorityWorkRecordSelection
            )
        );
        assemblyRuntimes[uint256(Late.RIGHTS)] = _selectorRuntime(
            "StreamCurrentAuthorityRightsRecordSelection",
            _authorityCreation(
                StreamCurrentAuthorityGraphCreation.Kind.StreamCurrentAuthorityRightsRecordSelection
            )
        );
        assemblyRuntimes[uint256(Late.CONSERVATION)] = _selectorRuntime(
            "StreamCurrentAuthorityConservationRecordSelection",
            _authorityCreation(
                StreamCurrentAuthorityGraphCreation.Kind
                    .StreamCurrentAuthorityConservationRecordSelection
            )
        );
        assemblyRuntimes[uint256(Late.INVENTORY)] = _productRuntime(
            "StreamCurrentAuthorityRenderCriticalInventory",
            new string[](0),
            _authorityCreation(
                StreamCurrentAuthorityGraphCreation.Kind
                .StreamCurrentAuthorityRenderCriticalInventory
            ),
            new RuntimeValue[](0)
        );
        assemblyRuntimes[uint256(Late.BUNDLE)] = _productRuntime(
            "StreamCurrentAuthorityBundleArchiveCoverage",
            new string[](0),
            _authorityCreation(
                StreamCurrentAuthorityGraphCreation.Kind.StreamCurrentAuthorityBundleArchiveCoverage
            ),
            new RuntimeValue[](0)
        );
    }

    function _predictAssemblyRegistryRuntime() private {
        string memory name = "StreamLineageArtworkFinalityRegistry";
        RuntimeValue[] memory v = new RuntimeValue[](24);
        v[0] = _finalityValue(name, "coreReads", _addressWord(address(assemblyCore)));
        v[1] = _finalityValue(
            name, "coreFinalityAdapter", _addressWord(assemblyLate[uint256(Late.CORE_ADAPTER)])
        );
        v[2] = _finalityValue(name, "metadataReads", _addressWord(address(assemblyMetadata)));
        v[3] = _finalityValue(
            name, "scopeEvidenceProvider", _addressWord(assemblyLate[uint256(Late.PROVIDER)])
        );
        v[4] = _finalityValue(name, "artifactCoverage", _addressWord(address(assemblyArtifact)));
        v[5] = _finalityValue(name, "_artifactCodeHash", address(assemblyArtifact).codehash);
        v[6] = _finalityValue(name, "sanctionReads", _addressWord(address(assemblyArtists)));
        v[7] = _finalityValue(name, "finalityRoleRegistry", _addressWord(address(assemblyRoles)));
        v[8] = _finalityValue(name, "_executorCodeHash", address(assemblyExecutor).codehash);
        v[9] = _finalityValue(name, "_rolesCodeHash", address(assemblyRoles).codehash);
        v[10] = _finalityValue(name, "_coreCodeHash", address(assemblyCore).codehash);
        v[11] = _finalityValue(name, "_metadataCodeHash", address(assemblyMetadata).codehash);
        v[12] = _finalityValue(
            name, "_providerCodeHash", keccak256(assemblyRuntimes[uint256(Late.PROVIDER)])
        );
        v[13] = _finalityValue(
            name, "_adapterCodeHash", keccak256(assemblyRuntimes[uint256(Late.CORE_ADAPTER)])
        );
        v[14] = _finalityValue(
            name, "_discoveryCodeHash", keccak256(assemblyRuntimes[uint256(Late.DISCOVERY)])
        );
        v[15] = _finalityValue(
            name, "finalityDiscovery", _addressWord(assemblyLate[uint256(Late.DISCOVERY)])
        );
        v[16] = _runtimeValue(
            "parameters",
            "StreamGasParameterHost",
            "governanceAuthority",
            _addressWord(address(assemblyExecutor))
        );
        v[17] = _runtimeValue(
            "modules",
            "StreamModuleBase",
            "_schemaHash",
            keccak256("6529stream.canonical-artwork-finality.schema.v1")
        );
        v[18] = _runtimeValue("modules", "StreamModuleBase", "_supersedes", 0);
        v[19] = _runtimeValue(
            "modules", "StreamModuleBase", "_deploymentManifestHash", graphDeploymentHash
        );
        v[20] = _runtimeValue(
            "modules", "StreamModuleBase", "_manifestHash", graphFinalityManifestHash
        );
        v[21] = _finalityValue(
            name, "currentAuthorityResolver", _addressWord(assemblyAuthorityResolverAddress)
        );
        v[22] = _finalityValue(
            name, "currentAuthorityResolverCodeHash", keccak256(assemblyAuthorityResolverRuntime)
        );
        v[23] = _finalityValue(
            name, "_authorityAnchorsHash", keccak256(abi.encode(_assemblyAuthorityAnchors()))
        );
        string[] memory parents = new string[](2);
        parents[0] = "StreamGasParameterHost";
        parents[1] = "StreamModuleBase";
        assemblyRuntimes[uint256(Late.REGISTRY)] = _productRuntime(
            name,
            parents,
            _authorityCreation(
                StreamCurrentAuthorityGraphCreation.Kind.StreamLineageArtworkFinalityRegistry
            ),
            v
        );
    }

    function _predictAssemblyCoordinatorRuntime() private {
        string memory name = "StreamArtistOnboardingCoordinator";
        RuntimeValue[] memory v = new RuntimeValue[](7);
        v[0] = _runtimeValue("artist", name, "deploymentChainId", bytes32(block.chainid));
        v[1] = _runtimeValue(
            "artist", name, "configurationHash", _assemblyCoordinatorConfigurationHash()
        );
        v[2] = _runtimeValue(
            "artist",
            name,
            "reads",
            _addressWord(graphVm.computeCreateAddress(assemblyCoordinatorAddress, 1))
        );
        v[3] = _runtimeValue(
            "artist", name, "finalityRegistry", _addressWord(assemblyLate[uint256(Late.REGISTRY)])
        );
        v[4] = _runtimeValue(
            "artist",
            name,
            "finalityRegistryCodeHash",
            keccak256(assemblyRuntimes[uint256(Late.REGISTRY)])
        );
        v[5] = _runtimeValue(
            "artist",
            name,
            "finalityEvidenceProvider",
            _addressWord(assemblyLate[uint256(Late.PROVIDER)])
        );
        v[6] = _runtimeValue(
            "artist",
            name,
            "finalityEvidenceProviderCodeHash",
            keccak256(assemblyRuntimes[uint256(Late.PROVIDER)])
        );
        assemblyCoordinatorRuntime = _productRuntime(
            name,
            new string[](0),
            _graphCreation(StreamCurrentGraphKinds.Kind.StreamArtistOnboardingCoordinator),
            v
        );
    }

    function _assemblyCoordinatorConfigurationHash() private view returns (bytes32) {
        T.SuiteConfiguration memory suite = assemblySuite;
        bytes32[16] memory hashes;
        for (uint256 i; i < 7; ++i) {
            hashes[i] = suite.owners[i].codehash;
        }
        address[9] memory tail = [
            suite.registry,
            suite.archive,
            suite.core,
            suite.mintManager,
            suite.roleRegistry,
            suite.metadata,
            suite.primaryResolver,
            suite.royaltyResolver,
            suite.validator
        ];
        for (uint256 i; i < 9; ++i) {
            hashes[i + 7] = tail[i].codehash;
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_CONFIGURATION_V1"),
                block.chainid,
                assemblyCoordinatorAddress,
                suite,
                hashes,
                assemblyLate[uint256(Late.REGISTRY)],
                keccak256(assemblyRuntimes[uint256(Late.REGISTRY)]),
                assemblyLate[uint256(Late.PROVIDER)],
                keccak256(assemblyRuntimes[uint256(Late.PROVIDER)]),
                uint16(1),
                uint16(2),
                uint16(3),
                uint16(4),
                uint16(5),
                uint16(6),
                uint16(7),
                uint16(12),
                uint16(13),
                uint16(14),
                uint16(15),
                uint16(16),
                uint16(17),
                uint16(18),
                uint16(20),
                uint16(21),
                uint16(22),
                uint16(23),
                uint16(24),
                uint16(25),
                uint16(26),
                uint16(27),
                uint16(28),
                uint16(29),
                uint16(30),
                uint16(31),
                uint16(32),
                uint16(33),
                uint16(34),
                uint16(35),
                uint16(36),
                uint16(37),
                uint16(38),
                uint16(39),
                uint16(40),
                uint16(51),
                uint16(52),
                uint16(54),
                uint16(58),
                uint16(65534),
                keccak256("6529STREAM_ARTIST_RECOVERY_PREPARATION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_RECOVERY_GUARDIAN_HISTORY_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_RECOVERY_FIRST_ROTATION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_RECOVERY_HISTORICAL_ROTATION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_GUARDIAN_SUPERSESSION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_GUARDIAN_HEAD_SELECTION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_GUARDIAN_ROOT_APPEAL_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_FIRST_ESTATE_RECOVERY_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_ESTATE_SUCCESSOR_GUARDIAN_RECOVERY_PROFILE_V1")
            )
        );
    }

    function _selectorRuntime(string memory name, bytes memory creation)
        private
        view
        returns (bytes memory)
    {
        RuntimeValue[] memory v = new RuntimeValue[](9);
        v[0] = _runtimeValue("metadata", name, "core", _addressWord(address(assemblyCore)));
        v[1] = _runtimeValue("metadata", name, "metadata", _addressWord(address(assemblyMetadata)));
        v[2] = _runtimeValue(
            "metadata", name, "schemaRegistry", _addressWord(address(assemblySchemas))
        );
        v[3] = _runtimeValue("metadata", name, "chunkStore", _addressWord(address(assemblyStore)));
        v[4] = _runtimeValue("metadata", name, "deploymentChainId", bytes32(block.chainid));
        v[5] = _runtimeValue("metadata", name, "coreCodeHash", address(assemblyCore).codehash);
        v[6] =
            _runtimeValue("metadata", name, "metadataCodeHash", address(assemblyMetadata).codehash);
        v[7] = _runtimeValue(
            "metadata", name, "schemaRegistryCodeHash", address(assemblySchemas).codehash
        );
        v[8] =
            _runtimeValue("metadata", name, "chunkStoreCodeHash", address(assemblyStore).codehash);
        return _productRuntime(name, new string[](0), creation, v);
    }

    function _productRuntime(
        string memory name,
        string[] memory parents,
        bytes memory creation,
        RuntimeValue[] memory values
    ) internal view returns (bytes memory) {
        string[] memory declarations = new string[](parents.length + 1);
        declarations[0] = _artifact(name);
        for (uint256 i; i < parents.length; ++i) {
            declarations[i + 1] = _artifact(parents[i]);
        }
        return _runtime(declarations[0], declarations, creation, values);
    }

    function _artifact(string memory name) internal pure virtual returns (string memory) {
        return string.concat("artifacts/current-graph/compiled/", name, ".json");
    }

    function _finalityValue(string memory name, string memory variable, bytes32 value)
        internal
        pure
        returns (RuntimeValue memory)
    {
        return _runtimeValue("finality", name, variable, value);
    }

    function _runtimeValue(
        string memory domain,
        string memory name,
        string memory variable,
        bytes32 value
    ) internal pure returns (RuntimeValue memory) {
        return RuntimeValue(
            string.concat("smart-contracts/domains/", domain, "/", name, ".sol"),
            name,
            variable,
            value
        );
    }

    function _addressWord(address value) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(value)));
    }

    function _assemblyInventoryDependencies()
        internal
        view
        returns (StreamRenderCriticalSourceTypes.Dependencies memory d)
    {
        d.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblySchemas),
            address(assemblyStore),
            address(assemblyRouter),
            address(assemblySnapshots),
            address(assemblyReference),
            assemblyLate[uint256(Late.WORK)],
            assemblyLate[uint256(Late.RIGHTS)],
            assemblyLate[uint256(Late.CONSERVATION)],
            address(assemblyArtifact),
            address(assemblyExternal)
        ];
        for (uint256 i; i < 12; ++i) {
            d.codeHashes[i] = _assemblyKnownCodeHash(d.targets[i]);
        }
        d.artistTargets = [
            address(assemblyArtists),
            assemblyCoordinatorAddress,
            assemblySuite.owners[2],
            assemblySuite.owners[4],
            assemblySuite.archive
        ];
        for (uint256 i; i < 5; ++i) {
            d.artistCodeHashes[i] = _assemblyKnownCodeHash(d.artistTargets[i]);
        }
        d.artistContentOwner = assemblySuite.owners[6];
        d.artistContentOwnerCodeHash = d.artistContentOwner.codehash;
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.sourceGas = 4000000;
        d.selectionGas = 4000000;
        d.snapshotGas = 6000000;
        d.referenceGas = 12000000;
    }

    function _assemblyKnownCodeHash(address target) internal view returns (bytes32 hash) {
        require(target != address(0), "no zero assembly dependency");
        if (target == assemblyCoordinatorAddress) {
            require(assemblyCoordinatorRuntime.length != 0, "Coordinator runtime already derived");
            hash = keccak256(assemblyCoordinatorRuntime);
        } else {
            for (uint256 i; i < 9; ++i) {
                if (assemblyLate[i] != target) continue;
                require(assemblyRuntimes[i].length != 0, "late runtime already derived");
                hash = keccak256(assemblyRuntimes[i]);
                break;
            }
        }
        if (hash == 0) {
            require(target.code.length != 0, "early dependency is deployed");
            hash = target.codehash;
        } else if (target.code.length != 0) {
            require(target.codehash == hash, "deployed dependency equals prediction");
        }
    }

    function _assemblyAuthorityAnchors() internal view returns (CurrentAuthority.Anchors memory a) {
        a.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblyRouter),
            address(assemblyArtists),
            assemblyLate[uint256(Late.PROVIDER)]
        ];
        for (uint256 i; i < 5; ++i) {
            a.codeHashes[i] = _assemblyKnownCodeHash(a.targets[i]);
        }
        a.finalityRegistry = assemblyLate[uint256(Late.REGISTRY)];
        a.chainId = block.chainid;
        // Matches the original provider getter cap. Metadata's repeated-ancestor worker also
        // consumes this cap; repeated succession therefore remains a runtime acceptance check.
        a.readGas = 500000;
    }

    function _assemblyOriginDependencies()
        internal
        view
        returns (ArchiveOrigin.Dependencies memory)
    {
        return ArchiveOrigin.Dependencies(
            address(assemblyOriginWorker),
            address(assemblyOriginWorker).codehash,
            6000000,
            ArchiveOrigin.PROFILE
        );
    }

    function _assemblyAuthorityDependencies()
        internal
        view
        returns (AuthorityInventory.Dependencies memory)
    {
        require(assemblyAuthorityResolverRuntime.length != 0, "resolver runtime already derived");
        return AuthorityInventory.Dependencies(
            assemblyAuthorityResolverAddress, keccak256(assemblyAuthorityResolverRuntime), 16000000
        );
    }

    function _assemblyProviderConfiguration()
        private
        view
        returns (StreamFinalityNativeProviderReads.Config memory c)
    {
        c.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblyRouter),
            address(assemblyMembership),
            address(assemblySchemas),
            address(assemblyStore),
            address(assemblyLeaves),
            address(assemblyContentCheckpoint),
            address(assemblySnapshots),
            address(assemblyReference),
            address(assemblyEntropyFactory),
            address(assemblyArtists),
            assemblyLate[uint256(Late.REGISTRY)],
            assemblyLate[uint256(Late.DISCOVERY)],
            assemblyLate[uint256(Late.CORE_ADAPTER)],
            assemblyLate[uint256(Late.WORK)],
            assemblyLate[uint256(Late.RIGHTS)],
            assemblyLate[uint256(Late.CONSERVATION)],
            assemblyLate[uint256(Late.INVENTORY)],
            assemblyLate[uint256(Late.BUNDLE)],
            address(assemblyArtifact),
            address(assemblyExternal)
        ];
        for (uint256 i; i < 22; ++i) {
            c.codeHashes[i] = _assemblyKnownCodeHash(c.targets[i]);
        }
        c.chainId = block.chainid;
        c.readGas = 500000;
        c.sourceGas = _assemblyProviderSourceGas();
        c.componentSourceGas = _assemblyComponentSourceGas();
        c.inventoryDependencyHash = AuthorityInventory.dependencyHash(
            AuthorityInventory.INVENTORY_PROFILE,
            _assemblyInventoryDependencies(),
            _assemblyOriginDependencies(),
            _assemblyAuthorityDependencies()
        );
    }

    function _deployAssemblyFinalityGraph() internal {
        StreamFinalityNativeProviderReads.Config memory c = _deployAssemblyFinalityCoordinator();
        _afterCurrentAuthorityCoordinatorDeployment();
        _requireCurrentGraphSelections();
        _deployAssemblyFinalitySelectors(c);
        _afterCurrentAuthoritySelectorsDeployment(c);
    }

    /// @dev Scenario hosts may execute real pointer governance here; the selection guard follows.
    function _afterCurrentAuthorityCoordinatorDeployment() internal virtual { }

    /// @dev Additive original-profile recipes may install their own fixed sources before the
    /// provider, then their late preservation hosts after the original selectors. These hooks
    /// never replace an already deployed provider or an already locked presentation anchor.
    function _afterCurrentAuthoritySelectorsDeployment(
        StreamFinalityNativeProviderReads.Config memory
    ) internal virtual { }

    function _assemblyProviderTemplate()
        internal
        view
        virtual
        returns (string memory name, string[] memory parents, bytes memory creation)
    {
        name = "StreamCurrentAuthorityNativeEvidenceProvider";
        parents = new string[](1);
        parents[0] = "StreamFinalityRouterEvidenceProvider";
        creation = _authorityCreation(
            StreamCurrentAuthorityGraphCreation.Kind.StreamCurrentAuthorityNativeEvidenceProvider
        );
    }

    function _assemblyDiscoveryTemplate()
        internal
        view
        virtual
        returns (string memory name, string[] memory parents, bytes memory creation)
    {
        name = "StreamFinalityLineageCurrentDiscovery";
        parents = new string[](0);
        creation = _authorityCreation(
            StreamCurrentAuthorityGraphCreation.Kind.StreamFinalityLineageCurrentDiscovery
        );
    }

    function _assemblyProviderArguments(StreamFinalityNativeProviderReads.Config memory c)
        internal
        virtual
        returns (bytes memory)
    {
        return abi.encode(c);
    }

    function _assemblyDiscoveryArguments(StreamFinalityDiscoveryTypes.Configuration memory c)
        internal
        virtual
        returns (bytes memory)
    {
        return abi.encode(c);
    }

    function _assemblyProviderSourceGas() internal view virtual returns (uint256) {
        return 16000000;
    }

    function _assemblyComponentSourceGas() internal view virtual returns (uint256) {
        return 4000000;
    }

    function _assemblyDiscoveryComponentGas() internal view virtual returns (uint32) {
        return 12000000;
    }

    function _assemblyFinalityComponentGas() internal view virtual returns (uint256) {
        return 30000000;
    }

    function _deployAssemblyFinalityCoordinator()
        private
        returns (StreamFinalityNativeProviderReads.Config memory c)
    {
        _predictAssemblyLateRuntimes();
        c = _assemblyProviderConfiguration();
        (,, bytes memory providerCreation) = _assemblyProviderTemplate();
        assemblyProvider = StreamCurrentAuthorityNativeEvidenceProvider(
            _deployAssemblyLate(Late.PROVIDER, providerCreation, _assemblyProviderArguments(c))
        );
        assemblyAuthorityResolver = StreamArtistCurrentAuthorityResolver(
            _deploySlot(
                assemblyAuthorityResolverSlot,
                assemblyAuthorityResolverAddress,
                _authorityCreation(
                    StreamCurrentAuthorityGraphCreation.Kind.StreamArtistCurrentAuthorityResolver
                ),
                abi.encode(_assemblyAuthorityAnchors()),
                assemblyAuthorityResolverRuntime
            )
        );
        assemblyCoreAdapter = StreamCoreFinalityAdapter(
            _deployAssemblyLate(
                Late.CORE_ADAPTER,
                _graphCreation(StreamCurrentGraphKinds.Kind.StreamCoreFinalityAdapter),
                abi.encode(
                    address(assemblyCore), address(assemblyMetadata), address(assemblyProvider)
                )
            )
        );
        bytes32[6] memory families = [
            StreamFinalityDomains.COMPONENT_METADATA_ROUTER,
            StreamFinalityDomains.COMPONENT_RENDERER,
            StreamFinalityDomains.COMPONENT_RENDER_CONTEXT,
            StreamFinalityDomains.COMPONENT_MEDIA_MANIFEST,
            StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE,
            StreamFinalityDomains.COMPONENT_DEPENDENCY_SOURCE
        ];
        for (uint256 i; i < 6; ++i) {
            assemblyRouterAdapters[i] = address(
                StreamFinalityServingHostAdapter(
                    payable(_assemblyCreate(
                            StreamCurrentGraphKinds.Kind.StreamFinalityServingHostAdapter,
                            abi.encode(
                                address(assemblyCore),
                                address(assemblyRouter),
                                address(assemblyProvider),
                                families[i]
                            )
                        ))
                )
            );
        }
        assemblyMetadataAdapter = address(
            StreamFinalityServingHostAdapter(
                payable(_assemblyCreate(
                        StreamCurrentGraphKinds.Kind.StreamFinalityServingHostAdapter,
                        abi.encode(
                            address(assemblyCore),
                            address(assemblyMetadata),
                            address(assemblyProvider),
                            StreamFinalityDomains.COMPONENT_COLLECTION_METADATA
                        )
                    ))
            )
        );
        StreamFinalityDiscoveryTypes.Configuration memory d;
        d.core = address(assemblyCore);
        d.metadata = address(assemblyMetadata);
        d.router = address(assemblyRouter);
        d.provider = address(assemblyProvider);
        d.membership = address(assemblyMembership);
        d.entropyFactory = address(assemblyEntropyFactory);
        d.metadataAdapter = assemblyMetadataAdapter;
        d.referenceRender = address(assemblyReference);
        d.artist = address(assemblyArtists);
        d.finalityRegistry = assemblyLate[uint256(Late.REGISTRY)];
        d.finalityRegistryCodeHash = keccak256(assemblyRuntimes[uint256(Late.REGISTRY)]);
        d.routerAdapters = assemblyRouterAdapters;
        d.readGas = 500000;
        d.componentGas = _assemblyDiscoveryComponentGas();
        d.entropyGas = 8000000;
        (,, bytes memory discoveryCreation) = _assemblyDiscoveryTemplate();
        assemblyDiscovery = StreamFinalityLineageCurrentDiscovery(
            _deployAssemblyLate(Late.DISCOVERY, discoveryCreation, _assemblyDiscoveryArguments(d))
        );
        StreamFinalityDeploymentConfiguration memory deployment =
            StreamFinalityDeploymentConfiguration(
                address(assemblyArtifact),
                graphDeploymentHash,
                graphFinalityManifestURI,
                graphFinalityManifestHash
            );
        assemblyFinality = StreamLineageArtworkFinalityRegistry(
            _deployAssemblyLate(
                Late.REGISTRY,
                _authorityCreation(
                    StreamCurrentAuthorityGraphCreation.Kind.StreamLineageArtworkFinalityRegistry
                ),
                abi.encode(
                    address(assemblyCore),
                    address(assemblyMetadata),
                    address(assemblyCoreAdapter),
                    address(assemblyArtists),
                    address(assemblyExecutor),
                    address(assemblyDiscovery),
                    _gas("FINALITY_COMPONENT_READ_GAS", _assemblyFinalityComponentGas(), 50000, 2),
                    deployment,
                    address(assemblyAuthorityResolver)
                )
            )
        );
        assemblyCoordinator = StreamArtistOnboardingCoordinator(
            _deploySlot(
                assemblyCoordinatorSlot,
                assemblyCoordinatorAddress,
                _graphCreation(StreamCurrentGraphKinds.Kind.StreamArtistOnboardingCoordinator),
                abi.encode(assemblySuite, address(assemblyFinality)),
                assemblyCoordinatorRuntime
            )
        );
        require(
            graphVm.getNonce(assemblyCoordinatorAddress) == 2,
            "one original Coordinator reader CREATE"
        );
        require(
            address(assemblyCoordinator.reads())
                == graphVm.computeCreateAddress(assemblyCoordinatorAddress, 1),
            "actual original reader address"
        );
    }

    function _deployAssemblyFinalitySelectors(StreamFinalityNativeProviderReads.Config memory c)
        private
    {
        bytes memory selectorArgs =
            abi.encode(address(assemblyCore), address(assemblyMetadata), address(assemblySchemas));
        assemblyWork = StreamCurrentAuthorityWorkRecordSelection(
            _deployAssemblyLate(
                Late.WORK,
                _authorityCreation(
                    StreamCurrentAuthorityGraphCreation.Kind
                    .StreamCurrentAuthorityWorkRecordSelection
                ),
                selectorArgs
            )
        );
        assemblyRights = StreamCurrentAuthorityRightsRecordSelection(
            _deployAssemblyLate(
                Late.RIGHTS,
                _authorityCreation(
                    StreamCurrentAuthorityGraphCreation.Kind
                    .StreamCurrentAuthorityRightsRecordSelection
                ),
                selectorArgs
            )
        );
        assemblyConservation = StreamCurrentAuthorityConservationRecordSelection(
            _deployAssemblyLate(
                Late.CONSERVATION,
                _authorityCreation(
                    StreamCurrentAuthorityGraphCreation.Kind
                        .StreamCurrentAuthorityConservationRecordSelection
                ),
                selectorArgs
            )
        );
        assemblyInventory = StreamCurrentAuthorityRenderCriticalInventory(
            _deployAssemblyLate(
                Late.INVENTORY,
                _authorityCreation(
                    StreamCurrentAuthorityGraphCreation.Kind
                    .StreamCurrentAuthorityRenderCriticalInventory
                ),
                abi.encode(
                    _assemblyInventoryDependencies(),
                    _assemblyOriginDependencies(),
                    _assemblyAuthorityDependencies()
                )
            )
        );
        StreamBundleArchiveTypes.Dependencies memory b;
        b.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblyInventory),
            address(assemblyArtifact),
            address(assemblyExternal),
            assemblySuite.archive
        ];
        for (uint256 i; i < 6; ++i) {
            b.codeHashes[i] = b.targets[i].codehash;
        }
        b.chainId = block.chainid;
        b.readGas = 500000;
        b.archiveGas = 2000000;
        assemblyBundle = StreamCurrentAuthorityBundleArchiveCoverage(
            _deployAssemblyLate(
                Late.BUNDLE,
                _authorityCreation(
                    StreamCurrentAuthorityGraphCreation.Kind
                    .StreamCurrentAuthorityBundleArchiveCoverage
                ),
                abi.encode(
                    b,
                    _assemblyOriginDependencies(),
                    _assemblyAuthorityDependencies(),
                    AuthorityInventory.INVENTORY_PROFILE
                )
            )
        );
        require(
            assemblyInventory.dependencyHash() == c.inventoryDependencyHash,
            "same exact inventory configuration before and after actual CREATE"
        );
        require(
            keccak256(abi.encode(c))
                == keccak256(abi.encode(assemblyProvider.nativeConfiguration())),
            "unchanged complete provider constructor pins"
        );
        for (uint256 i; i < 22; ++i) {
            require(
                c.targets[i].code.length != 0 && c.targets[i].code.length <= 24576
                    && c.targets[i].codehash == c.codeHashes[i],
                "all actual provider dependencies deployed and fit"
            );
        }
    }

    mapping(StreamCurrentAuthorityGraphCreation.Kind => bool) private
        assemblyVerifiedAuthorityTemplates;

    function _authorityCreate(StreamCurrentAuthorityGraphCreation.Kind kind, bytes memory args)
        private
        returns (address product)
    {
        bytes memory creation = _authorityCreation(kind);
        if (!assemblyVerifiedAuthorityTemplates[kind]) {
            _linkRuntime(
                graphVm.readFile(_artifact(StreamCurrentAuthorityGraphCreation.name(kind))),
                creation
            );
            assemblyVerifiedAuthorityTemplates[kind] = true;
        }
        bytes memory initcode = bytes.concat(creation, args);
        require(initcode.length <= 49152, "actual original product initcode fits");
        assembly ("memory-safe") {
            product := create(0, add(initcode, 32), mload(initcode))
            if iszero(product) {
                let errorData := mload(0x40)
                returndatacopy(errorData, 0, returndatasize())
                revert(errorData, returndatasize())
            }
        }
        require(
            product.code.length != 0 && product.code.length <= 24576,
            "actual original product runtime fits"
        );
    }

    mapping(StreamCurrentGraphKinds.Kind => bool) private assemblyVerifiedTemplates;

    function _assemblyCreate(StreamCurrentGraphKinds.Kind kind, bytes memory args)
        private
        returns (address product)
    {
        bytes memory creation = _graphCreation(kind);
        if (!assemblyVerifiedTemplates[kind]) {
            _linkRuntime(
                graphVm.readFile(_artifact(StreamCurrentGraphKinds.name(kind))), creation
            );
            assemblyVerifiedTemplates[kind] = true;
        }
        bytes memory initcode = bytes.concat(creation, args);
        require(initcode.length <= 49152, "actual original product initcode fits");
        assembly ("memory-safe") {
            product := create(0, add(initcode, 32), mload(initcode))
            if iszero(product) {
                let errorData := mload(0x40)
                returndatacopy(errorData, 0, returndatasize())
                revert(errorData, returndatasize())
            }
        }
        require(
            product.code.length != 0 && product.code.length <= 24576,
            "actual original product runtime fits"
        );
    }

    function _deployAssemblyLate(Late id, bytes memory creation, bytes memory args)
        private
        returns (address)
    {
        uint256 index = uint256(id);
        return _deploySlot(
            assemblySlots[index], assemblyLate[index], creation, args, assemblyRuntimes[index]
        );
    }

    function _slot() internal returns (StreamDeploymentSlot slot, address expected) {
        slot = new StreamDeploymentSlot(graphOperator);
        expected = slot.product();
        require(
            slot.operator() == graphOperator && !slot.consumed()
                && graphVm.getNonce(address(slot)) == 1,
            "fresh operator-owned CREATE coordinate"
        );
        require(
            expected == graphVm.computeCreateAddress(address(slot), 1), "exact product reservation"
        );
    }

    function _deploySlot(
        StreamDeploymentSlot slot,
        address expected,
        bytes memory creation,
        bytes memory args,
        bytes memory runtime
    ) internal returns (address product) {
        require(
            slot.operator() == graphOperator && slot.product() == expected && !slot.consumed(),
            "original operator reservation"
        );
        require(graphVm.getNonce(address(slot)) == 1, "only first CREATE admitted");
        product = slot.deploy(bytes.concat(creation, args), keccak256(runtime));
        require(
            product == expected && graphVm.getNonce(address(slot)) == 2 && slot.consumed(),
            "one original product CREATE"
        );
        require(keccak256(product.code) == keccak256(runtime), "full actual runtime bytes");
    }

    // Each factory call is a separate broadcast transaction; only the original slot creates the host.
    function _deploySplitArtistFacade(
        bytes memory creation,
        address operator_,
        address factory_,
        address[5] memory p,
        bytes32 deploymentHash,
        string memory uri,
        bytes32 manifestHash
    ) internal returns (StreamArtistOnboardingRegistry) {
        StreamDeploymentSlot slot = new StreamDeploymentSlot(operator_);
        address[3] memory children;
        for (uint8 i; i < 3; ++i) {
            children[i] =
                StreamCurrentArtistFactoryCalls(factory_).deployRegistry(i + 4, slot.product(), p[2]);
        }
        RuntimeValue[] memory v = new RuntimeValue[](14);
        string memory name = "StreamArtistOnboardingRegistry";
        v[0] = _runtimeValue("artist", name, "core", _addressWord(p[0]));
        v[1] = _runtimeValue("artist", name, "mintManager", _addressWord(p[1]));
        v[2] = _runtimeValue("artist", name, "operationCoordinator", _addressWord(p[2]));
        v[3] = _runtimeValue("artist", name, "registryWriterExtension", _addressWord(children[0]));
        v[4] = _runtimeValue("artist", name, "registryReadExtension", _addressWord(children[1]));
        v[5] = _runtimeValue(
            "artist", name, "registryFinalityReadExtension", _addressWord(children[2])
        );
        v[6] = _runtimeValue("artist", name, "archivalCoverage", _addressWord(p[4]));
        v[7] = _runtimeValue("artist", name, "archivalCoverageCodeHash", p[4].codehash);
        v[8] = _runtimeValue(
            "artist",
            name,
            "archivalCoverageConfigurationHash",
            StreamArtistEstateCoverage.admit(p[0], p[1], p[3], p[4])
        );
        v[9] = _runtimeValue(
            "parameters", "StreamGasParameterHost", "governanceAuthority", _addressWord(p[3])
        );
        v[10] = _runtimeValue(
            "modules",
            "StreamModuleBase",
            "_schemaHash",
            keccak256("6529stream.artist-onboarding.v1")
        );
        v[11] = _runtimeValue("modules", "StreamModuleBase", "_supersedes", bytes32(0));
        v[12] =
            _runtimeValue("modules", "StreamModuleBase", "_deploymentManifestHash", deploymentHash);
        v[13] = _runtimeValue("modules", "StreamModuleBase", "_manifestHash", manifestHash);
        string[] memory parents = new string[](2);
        parents[0] = "StreamGasParameterHost";
        parents[1] = "StreamModuleBase";
        bytes memory runtime = _productRuntime(name, parents, creation, v);
        address host = slot.deploy(
            bytes.concat(
                creation,
                abi.encode(
                    p[0],
                    p[1],
                    p[2],
                    p[3],
                    p[4],
                    deploymentHash,
                    uri,
                    manifestHash,
                    factory_,
                    children
                )
            ),
            keccak256(runtime)
        );
        require(
            host == slot.product() && keccak256(host.code) == keccak256(runtime),
            "complete split facade runtime"
        );
        return StreamArtistOnboardingRegistry(payable(host));
    }

    function _deploySplitArtistIdentity(
        bytes memory creation,
        address operator_,
        address factory_,
        address[5] memory p
    ) internal returns (address host) {
        StreamDeploymentSlot slot = new StreamDeploymentSlot(operator_);
        address[3] memory children;
        address[6] memory pins = [slot.product(), p[0], p[1], p[2], p[3], p[4]];
        for (uint8 i; i < 3; ++i) {
            children[i] = StreamCurrentArtistFactoryCalls(factory_).deployIdentity(i + 1, pins);
        }
        RuntimeValue[] memory v = new RuntimeValue[](13);
        string memory name = "StreamArtistIdentityAuthority";
        v[0] = _runtimeValue("artist", "StreamArtistOwner", "artistRegistry", _addressWord(p[0]));
        v[1] = _runtimeValue(
            "artist", "StreamArtistOwner", "operationCoordinator", _addressWord(p[1])
        );
        v[2] = _runtimeValue("artist", "StreamArtistOwner", "archiveV2", _addressWord(p[2]));
        v[3] = _runtimeValue("artist", "StreamArtistOwner", "core", _addressWord(p[3]));
        v[4] = _runtimeValue("artist", "StreamArtistOwner", "mintManager", _addressWord(p[4]));
        v[5] = _runtimeValue(
            "artist", "StreamArtistOwner", "deploymentChainId", bytes32(block.chainid)
        );
        v[6] = _runtimeValue(
            "artist", "StreamArtistOwner", "domainId", keccak256("domain:identity_authority")
        );
        v[7] = _runtimeValue(
            "artist",
            name,
            "artistWindowAuthority",
            _addressWord(StreamArtistTimingState.canonicalAuthority(p[3], p[4]))
        );
        v[8] = _runtimeValue("artist", name, "identityWriterExtension", _addressWord(children[0]));
        v[9] = _runtimeValue("artist", name, "identityEstateExtension", _addressWord(children[1]));
        v[10] =
            _runtimeValue("artist", name, "identityRecoveryExtension", _addressWord(children[2]));
        // The real Identity constructor creates these children in order through fixed
        // delegatecalled deployment libraries. Both CREATEs execute in the new host.
        v[11] = _runtimeValue(
            "artist",
            name,
            "identityAdjudicationExtension",
            _addressWord(graphVm.computeCreateAddress(slot.product(), 1))
        );
        v[12] = _runtimeValue(
            "artist",
            name,
            "identityRewindExtension",
            _addressWord(graphVm.computeCreateAddress(slot.product(), 2))
        );
        string[] memory parents = new string[](1);
        parents[0] = "StreamArtistOwner";
        bytes memory runtime = _productRuntime(name, parents, creation, v);
        host = slot.deploy(
            bytes.concat(creation, abi.encode(p[0], p[1], p[2], p[3], p[4], factory_, children)),
            keccak256(runtime)
        );
        require(
            host == slot.product() && keccak256(host.code) == keccak256(runtime),
            "complete split Identity runtime"
        );
    }
}
