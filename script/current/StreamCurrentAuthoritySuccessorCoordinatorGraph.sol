// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamCurrentGraphKinds } from "./StreamCurrentGraphKinds.sol";

import "./StreamCurrentFinalityGraph.sol";
import {
    StreamRecordArtistIdentityReads as PrefixIdentity
} from "../../smart-contracts/domains/records/StreamRecordArtistIdentityReads.sol";

/// @notice Authentic ordinary Finality/Coordinator counterparts for a recovered successor.
/// @dev Retains the selected original generic Metadata and rendering Router. Only constructor
/// counterparts are built: the successor's five preservation coordinates remain unconsumed.
/// No global pointer is installed and no complete successor Finality/provider graph is claimed.
/// Original current-authority Finality and selectors remain separate immutable anchors.
abstract contract StreamCurrentAuthoritySuccessorCoordinatorGraph is StreamCurrentFinalityGraph {
    struct PrefixSource {
        address registry;
        bytes32 registryCodeHash;
        address coordinator;
        bytes32 coordinatorCodeHash;
        address finality;
        bytes32 finalityCodeHash;
        address provider;
        bytes32 providerCodeHash;
        bytes32 suiteHash;
        bytes32 artistPointerHash;
        bytes32 metadataPointerHash;
        bytes32 routerPointerHash;
    }
    PrefixSource private _prefixSource;

    function _bindCurrentAuthoritySuccessorGraph(
        T.SuiteConfiguration memory suite,
        address predecessor,
        bytes32 expectedPredecessorHash,
        address modules_,
        address executor_,
        address manifest_,
        address archive_,
        address checkpoint_,
        bytes32 deploymentHash
    ) internal {
        require(
            address(assemblyCore) == address(0) && graphOperator != address(0)
                && _prefixSource.registry == address(0),
            "fresh successor prefix binding"
        );
        require(
            predecessor != address(0) && predecessor != suite.registry
                && predecessor.code.length != 0 && expectedPredecessorHash != 0
                && predecessor.codehash == expectedPredecessorHash
                && suite.registry.code.length != 0 && suite.core.code.length != 0
                && deploymentHash != 0,
            "actual predecessor and successor"
        );
        require(
            StreamArtistOnboardingRegistry(payable(suite.registry)).operationCoordinator()
                    == assemblyCoordinatorAddress && assemblyCoordinatorAddress.code.length == 0,
            "original reserved successor Coordinator"
        );
        address previousCoordinator =
            StreamArtistOnboardingRegistry(payable(predecessor)).operationCoordinator();
        require(previousCoordinator.code.length != 0, "actual predecessor Coordinator");
        StreamArtistOnboardingCoordinator previous =
            StreamArtistOnboardingCoordinator(previousCoordinator);
        // The genuine Coordinator getter rechecks all sixteen constructor-saved suite runtimes.
        T.SuiteConfiguration memory prior = previous.suiteConfiguration();
        require(
            prior.registry == predecessor && previous.deploymentChainId() == block.chainid
                && prior.core == suite.core && prior.mintManager == suite.mintManager
                && prior.roleRegistry == suite.roleRegistry && prior.metadata == suite.metadata
                && prior.primaryResolver == suite.primaryResolver
                && prior.royaltyResolver == suite.royaltyResolver
                && prior.primaryRevenueClass == suite.primaryRevenueClass
                && prior.validator == suite.validator,
            "unchanged original non-Artist suite"
        );
        address priorFinality = previous.finalityRegistry();
        (address priorProvider, bytes32 priorProviderHash) =
            StreamArtistFinalityAdmission.admit(prior, priorFinality);
        require(
            priorFinality.codehash == previous.finalityRegistryCodeHash()
                && priorProvider == previous.finalityEvidenceProvider()
                && priorProviderHash == previous.finalityEvidenceProviderCodeHash()
                && IStreamGasParameterHost(predecessor).governanceAuthority() == executor_
                && IStreamGasParameterHost(suite.registry).governanceAuthority() == executor_,
            "actual predecessor Finality and governance"
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
        StreamCorePointerState memory selectedMetadata =
            StreamCurrentStackPlan.readPointer(assemblyCore, keccak256("COLLECTION_METADATA"));
        require(
            selectedMetadata.target.code.length != 0
                && selectedMetadata.target.codehash == selectedMetadata.codeHash
                && selectedMetadata.registryStatus == 1,
            "actual selected retained Metadata"
        );
        assemblyMetadata = StreamCollectionMetadataV1(payable(selectedMetadata.target));
        assemblySchemas = StreamSchemaRegistry(payable(assemblyMetadata.schemaRegistry()));
        assemblyStore = StreamSchemaDocumentStore(assemblyMetadata.chunkStore());
        require(
            address(StreamArtworkFinalityRegistry(priorFinality).metadataReads())
                    == address(assemblyMetadata)
                && StreamFinalityNativeEvidenceProvider(priorProvider).metadataHost()
                    == address(assemblyMetadata) && assemblyMetadata.core() == suite.core
                && assemblyMetadata.coreCodeHash() == suite.core.codehash
                && address(assemblySchemas).code.length != 0
                && address(assemblyStore).code.length != 0
                && assemblyMetadata.schemaRegistryCodeHash() == address(assemblySchemas).codehash
                && assemblyMetadata.chunkStoreCodeHash() == address(assemblyStore).codehash
                && assemblySchemas.chunkStore() == address(assemblyStore)
                && assemblyMetadata.governanceAuthority() == executor_
                && assemblyMetadata.executorCodeHash() == executor_.codehash
                && assemblySchemas.governanceAuthority() == executor_,
            "retained original Metadata baseline"
        );
        graphDeploymentHash = deploymentHash;
        graphFinalityManifestHash = keccak256("current-stack native finality module v1");
        graphFinalityManifestURI = "https://engineering.example.invalid/6529stream/current/finality";
        graphRendererCatalogId = keccak256("STREAM_CURRENT_REFERENCE_RENDERER_CLASS_V1");
        PrefixSource storage pinned = _prefixSource;
        pinned.registry = predecessor;
        pinned.registryCodeHash = expectedPredecessorHash;
        pinned.coordinator = previousCoordinator;
        pinned.coordinatorCodeHash = previousCoordinator.codehash;
        pinned.finality = priorFinality;
        pinned.finalityCodeHash = priorFinality.codehash;
        pinned.provider = priorProvider;
        pinned.providerCodeHash = priorProviderHash;
        pinned.suiteHash = keccak256(abi.encode(prior));
        pinned.artistPointerHash = keccak256(
            abi.encode(
                StreamCurrentStackPlan.readPointer(assemblyCore, keccak256("ARTIST_REGISTRY"))
            )
        );
        pinned.metadataPointerHash = keccak256(abi.encode(selectedMetadata));
        pinned.routerPointerHash = keccak256(
            abi.encode(
                StreamCurrentStackPlan.readPointer(assemblyCore, keccak256("METADATA_ROUTER"))
            )
        );
        _requireAuthorityPrefixSource();
        _deployCurrentGraphPrerequisites();
    }

    function _completeCurrentAuthoritySuccessorCoordinator(bytes memory rendererCatalog) internal {
        require(
            address(assemblyCoordinator) == address(0)
                && assemblyCoordinatorAddress.code.length == 0,
            "successor Coordinator not yet deployed"
        );
        _requireAuthorityPrefixSource();
        _deployAuthorityPrefixSourceHosts(rendererCatalog);
        _deployAuthorityPrefixCoordinator();
        _requireAuthorityPrefixSource();
        for (uint256 i = uint256(Late.WORK); i < 9; ++i) {
            require(
                !assemblySlots[i].consumed() && assemblyLate[i].code.length == 0,
                "preservation descendants intentionally unconsumed"
            );
        }
    }

    function _requireAuthorityPrefixSource() private view {
        PrefixSource storage p = _prefixSource;
        require(
            p.registry != address(0) && p.registry.codehash == p.registryCodeHash
                && p.coordinator.codehash == p.coordinatorCodeHash
                && p.finality.codehash == p.finalityCodeHash
                && p.provider.codehash == p.providerCodeHash
                && keccak256(
                    abi.encode(
                        StreamArtistOnboardingCoordinator(p.coordinator).suiteConfiguration()
                    )
                ) == p.suiteHash,
            "unchanged authentic predecessor prefix"
        );
        _requireAuthorityPrefixFoundation();
        StreamCorePointerState memory selected =
            StreamCurrentStackPlan.readPointer(assemblyCore, keccak256("ARTIST_REGISTRY"));
        require(
            selected.target == p.registry && selected.codeHash == p.registryCodeHash
                && selected.registryStatus == 1 && selected.registry == address(assemblyModules)
                && selected.moduleType == keccak256("ARTIST_REGISTRY")
                && selected.interfaceId == type(IStreamArtistMintConsent).interfaceId
                && keccak256(abi.encode(selected)) == p.artistPointerHash
                && assemblyModules.isModuleEligible(
                    p.registry,
                    keccak256("ARTIST_REGISTRY"),
                    type(IStreamArtistMintConsent).interfaceId
                ),
            "actual admitted selected predecessor"
        );
        (bool cutover,,) = IStreamArtistHistory(p.registry).artistRegistryCutover();
        require(!cutover, "predecessor not yet cut over");
        StreamCorePointerState memory metadataPointer =
            StreamCurrentStackPlan.readPointer(assemblyCore, keccak256("COLLECTION_METADATA"));
        StreamCorePointerState memory routerPointer =
            StreamCurrentStackPlan.readPointer(assemblyCore, keccak256("METADATA_ROUTER"));
        require(
            metadataPointer.target == address(assemblyMetadata)
                && metadataPointer.codeHash == address(assemblyMetadata).codehash
                && metadataPointer.registryStatus == 1
                && keccak256(abi.encode(metadataPointer)) == p.metadataPointerHash
                && routerPointer.target == address(assemblyRouter)
                && routerPointer.codeHash == address(assemblyRouter).codehash
                && routerPointer.registryStatus == 1
                && keccak256(abi.encode(routerPointer)) == p.routerPointerHash,
            "unchanged selected original source hosts"
        );
        PrefixIdentity.Pins memory current = PrefixIdentity.resolveCurrent(
            address(assemblyMetadata), address(assemblyCore), block.chainid, 500000
        );
        require(
            current.targets[0] == p.registry && current.codeHashes[0] == p.registryCodeHash
                && current.targets[1] == p.coordinator
                && current.codeHashes[1] == p.coordinatorCodeHash,
            "actual original Metadata ancestry to current predecessor"
        );
    }

    function _requireAuthorityPrefixFoundation() private view {
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

    function _deployAuthorityPrefixSourceHosts(bytes memory rendererCatalog) private {
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
            payable(_authorityPrefixCreate(
                    StreamCurrentGraphKinds.Kind.StreamCollectionSnapshots,
                    abi.encode(d, address(assemblyExecutor), configs)
                ))
        );
        _deployAuthorityPrefixReference(rendererCatalog);
    }

    function _deployAuthorityPrefixReference(bytes memory catalog) private {
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
            payable(_authorityPrefixCreate(
                    StreamCurrentGraphKinds.Kind.StreamReferenceRenderPublication,
                    abi.encode(d, address(assemblyExecutor), configs)
                ))
        );
    }

    function _authorityPrefixKnownCodeHash(address target) private view returns (bytes32 hash) {
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

    function _authorityPrefixProviderConfiguration()
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
            c.codeHashes[i] = _authorityPrefixKnownCodeHash(c.targets[i]);
        }
        c.chainId = block.chainid;
        c.readGas = 500000;
        c.sourceGas = 16000000;
        c.componentSourceGas = 4000000;
        c.inventoryDependencyHash = keccak256(abi.encode(_assemblyInventoryDependencies()));
    }

    function _deployAuthorityPrefixCoordinator()
        private
        returns (StreamFinalityNativeProviderReads.Config memory c)
    {
        _predictAssemblyLateRuntimes();
        c = _authorityPrefixProviderConfiguration();
        assemblyProvider = StreamFinalityNativeEvidenceProvider(
            _deployAuthorityPrefixLate(
                Late.PROVIDER,
                _graphCreation(
                    StreamCurrentGraphKinds.Kind.StreamFinalityNativeEvidenceProvider
                ),
                abi.encode(c)
            )
        );
        assemblyCoreAdapter = StreamCoreFinalityAdapter(
            _deployAuthorityPrefixLate(
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
                    payable(_authorityPrefixCreate(
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
                payable(_authorityPrefixCreate(
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
        d.componentGas = 12000000;
        d.entropyGas = 8000000;
        assemblyDiscovery = StreamFinalityCurrentDiscovery(
            _deployAuthorityPrefixLate(
                Late.DISCOVERY,
                _graphCreation(StreamCurrentGraphKinds.Kind.StreamFinalityCurrentDiscovery),
                abi.encode(d)
            )
        );
        StreamFinalityDeploymentConfiguration memory deployment =
            StreamFinalityDeploymentConfiguration(
                address(assemblyArtifact),
                graphDeploymentHash,
                graphFinalityManifestURI,
                graphFinalityManifestHash
            );
        assemblyFinality = StreamArtworkFinalityRegistry(
            _deployAuthorityPrefixLate(
                Late.REGISTRY,
                _graphCreation(StreamCurrentGraphKinds.Kind.StreamArtworkFinalityRegistry),
                abi.encode(
                    address(assemblyCore),
                    address(assemblyMetadata),
                    address(assemblyCoreAdapter),
                    address(assemblyArtists),
                    address(assemblyExecutor),
                    address(assemblyDiscovery),
                    _gas("FINALITY_COMPONENT_READ_GAS", 30000000, 50000, 2),
                    deployment
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

    function _authorityPrefixCreate(StreamCurrentGraphKinds.Kind kind, bytes memory args)
        private
        returns (address product)
    {
        bytes memory creation = _graphCreation(kind);
        if (!_authorityPrefixVerifiedTemplates[kind]) {
            _linkRuntime(
                graphVm.readFile(_artifact(StreamCurrentGraphKinds.name(kind))), creation
            );
            _authorityPrefixVerifiedTemplates[kind] = true;
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

    function _deployAuthorityPrefixLate(Late id, bytes memory creation, bytes memory args)
        private
        returns (address)
    {
        uint256 index = uint256(id);
        return _deploySlot(
            assemblySlots[index], assemblyLate[index], creation, args, assemblyRuntimes[index]
        );
    }

    mapping(StreamCurrentGraphKinds.Kind => bool) private _authorityPrefixVerifiedTemplates;
}
