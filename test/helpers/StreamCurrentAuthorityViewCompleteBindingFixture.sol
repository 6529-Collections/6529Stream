// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityPreservationPolicyAssemblyFixture
} from "./StreamCurrentAuthorityPreservationPolicyAssemblyFixture.sol";
import { CurrentAuthorityAssemblyVm } from "./StreamCurrentAuthorityNativeAssemblyFixture.sol";
import {
    StreamStaticAttributionCompanion as AVStaticAttribution
} from "../../smart-contracts/domains/metadata/StreamStaticAttributionCompanion.sol";
import {
    StreamPreservationAttributionCompanion as AVAttribution
} from "../../smart-contracts/domains/metadata/StreamPreservationAttributionCompanion.sol";
import {
    StreamViewPreservationRendererV1 as AVRenderer
} from "../../smart-contracts/domains/metadata/StreamViewPreservationRendererV1.sol";
import {
    IStreamViewPreservationRendererV1 as AVRendererAPI
} from "../../smart-contracts/interfaces/stream/metadata/IStreamViewPreservationRendererV1.sol";
import {
    StreamViewPreservationContentCheckpointV1 as AVCheckpoint
} from "../../smart-contracts/domains/finality/StreamViewPreservationContentCheckpointV1.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as AVCheckpointTypes
} from "../../smart-contracts/interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    StreamViewPreservationOutputManifestV1 as AVOutput
} from "../../smart-contracts/domains/finality/StreamViewPreservationOutputManifestV1.sol";
import {
    StreamViewPreservationManifestTypesV1 as AVOutputTypes
} from "../../smart-contracts/interfaces/stream/finality/StreamViewPreservationManifestTypesV1.sol";
import {
    StreamViewPreservationSnapshotPublicationV1 as AVSnapshot
} from "../../smart-contracts/domains/metadata/StreamViewPreservationSnapshotPublicationV1.sol";
import {
    StreamViewPreservationSnapshotTypesV1 as AVSnapshotTypes
} from "../../smart-contracts/interfaces/stream/metadata/StreamViewPreservationSnapshotTypesV1.sol";
import {
    StreamViewPreservationReferencePublicationV1 as AVReference
} from "../../smart-contracts/domains/preservation/StreamViewPreservationReferencePublicationV1.sol";
import {
    StreamViewPreservationReferenceTypesV1 as AVReferenceTypes
} from "../../smart-contracts/interfaces/stream/preservation/StreamViewPreservationReferenceTypesV1.sol";
import {
    StreamViewPreservationRenderCriticalInventoryV1 as AVInventory
} from "../../smart-contracts/domains/preservation/StreamViewPreservationRenderCriticalInventoryV1.sol";
import {
    StreamViewRetrievalWitnessV1 as AVRetrieval
} from "../../smart-contracts/domains/preservation/StreamViewRetrievalWitnessV1.sol";
import {
    StreamViewRetrievalWitnessTypesV1 as AVRetrievalTypes
} from "../../smart-contracts/interfaces/stream/preservation/StreamViewRetrievalWitnessTypesV1.sol";
import {
    StreamViewPreservationBundleArchiveCoverageV1 as AVBundle
} from "../../smart-contracts/domains/preservation/StreamViewPreservationBundleArchiveCoverageV1.sol";
import {
    StreamCollectionViews as AVViews
} from "../../smart-contracts/domains/metadata/StreamCollectionViews.sol";
import {
    IStreamCollectionViews as AVViewsAPI
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionViews.sol";
import {
    IStreamFinalityViewPreservationBindingV1 as AVBasic
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityViewPreservationBindingV1.sol";
import {
    IStreamFinalityViewPreservationCompleteBindingV1 as AVComplete
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityViewPreservationCompleteBindingV1.sol";
import {
    StreamFinalityViewPreservationBindingTypesV1 as AVBasicTypes
} from "../../smart-contracts/interfaces/stream/finality/StreamFinalityViewPreservationBindingTypesV1.sol";
import {
    StreamFinalityViewPreservationCompleteBindingTypesV1 as AVCompleteTypes
} from "../../smart-contracts/interfaces/stream/finality/StreamFinalityViewPreservationCompleteBindingTypesV1.sol";
import {
    IStreamViewPreservationFinalitySourcesV1 as AVSources
} from "../../smart-contracts/interfaces/stream/finality/IStreamViewPreservationFinalitySourcesV1.sol";
import {
    IStreamFinalityProfileSources as AVCatalogue
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    StreamViewAdoptionTypes as AVDeclaration
} from "../../smart-contracts/interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import {
    StreamRenderCriticalSourceTypes as AVS
} from "../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as AVD
} from "../../smart-contracts/interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamArtistArchiveOriginTypes as AVO
} from "../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamBundleArchiveTypes as AVBundleTypes
} from "../../smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    IStreamGasParameterHost as AVGas
} from "../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    IStreamSchemaRegistry as AVSchema
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    StreamModuleRegistration as AVModuleRegistration,
    StreamModuleRecord as AVModuleRecord,
    ModuleRegistryStatus as AVModuleStatus
} from "../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";
import {
    GovernanceCall as AVCall,
    GovernanceActionStatus as AVActionStatus
} from "../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";
import {
    GenesisBatch as AVBatch
} from "../../smart-contracts/interfaces/stream/governance/IStreamGenesisInitializer.sol";
import { StreamCurrentStackPlan as AVStack } from "../../script/current/StreamCurrentStackPlan.sol";
import {
    StreamFinalityScope as AVScope,
    StreamFinalityScopeType as AVScopeType
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Actual current-authority original graph and one complete VIEW source binding.
/// @dev Root-free identity admission only. No mocks, mint, adoption, rendering, observations,
/// checkpoint/root publication or terminal Finality here. The original VIEW attribution capability
/// is deliberately retained. Diagnostic constructor caps and runtime limits need native execution.
abstract contract StreamCurrentAuthorityViewCompleteBindingFixture is
    StreamCurrentAuthorityPreservationPolicyAssemblyFixture
{
    /// @dev Constructor-only inputs for a new graph. The default preserves the original
    /// diagnostic profile exactly; overriding this does not mutate governed deployed hosts.
    struct AuthorityViewConstructionBudgets {
        uint32 rendererGas;
        uint32 attributionGas;
        uint32 checkpointReadGas;
        uint32 checkpointServingGas;
        uint32 outputReadGas;
        uint32 outputValidationGas;
        uint32 snapshotReadGas;
        uint32 snapshotSourceGas;
        uint32 snapshotInventoryGas;
        uint32 boundSnapshotValidationGas;
        uint32 referenceReadGas;
        uint32 referenceSourceGas;
        uint32 referenceSnapshotGas;
        uint32 referenceArchiveGas;
    }

    function _authorityViewConstructionBudgets()
        internal
        pure
        virtual
        returns (AuthorityViewConstructionBudgets memory)
    {
        return AuthorityViewConstructionBudgets({
            rendererGas: 3000000,
            attributionGas: 4000000,
            checkpointReadGas: 2000000,
            checkpointServingGas: 9000000,
            outputReadGas: 2000000,
            outputValidationGas: 12000000,
            snapshotReadGas: 2000000,
            snapshotSourceGas: 14000000,
            snapshotInventoryGas: 4000000,
            boundSnapshotValidationGas: 16000000,
            referenceReadGas: 1000000,
            referenceSourceGas: 16000000,
            referenceSnapshotGas: 16000000,
            referenceArchiveGas: 1000000
        });
    }

    /// @dev The witness calls the checkpoint source directly. Preserve the original diagnostic
    /// snapshot allowance by default; a new graph may choose its witness allowance independently.
    function _authorityViewRetrievalSourceGas(uint256 snapshotSourceGas)
        internal
        pure
        virtual
        returns (uint256)
    {
        return snapshotSourceGas;
    }

    AVStaticAttribution internal avOriginalAttribution;
    AVAttribution internal avAttribution;
    AVRenderer internal avRenderer;
    AVCheckpoint internal avCheckpoint;
    AVOutput internal avOutput;
    AVSnapshot internal avSnapshot;
    AVViews internal avViews;
    AVReference internal avReference;
    AVInventory internal avInventory;
    AVRetrieval internal avRetrieval;
    AVBundle internal avBundle;
    AVBasicTypes.Configuration internal avConfiguration;
    AVDeclaration.Binding internal avDeclaration;
    AVSources.Selection internal avSelection;
    AVBasicTypes.Transition internal avTransition;
    AVSources.Receipt internal avReceipt;
    bytes32 internal avAction;
    bytes32 internal avOriginalSourceHash;
    bytes32 internal avOriginalRosterHash;

    function _authorityConstructViewBindingSources() internal {
        require(address(avRenderer) == address(0), "one source graph");
        _deployAssemblyGraph();
        avOriginalSourceHash =
            AVCatalogue(address(assemblyProvider)).finalitySourceConfigurationHash();
        avOriginalRosterHash = _authorityOriginalRosterHash();
        _authorityRequireCompositeAnchor();
        _avDeployOutputSources();
        _avDeployDeclaration();
        _avDeployReference();
        _avDeployInventoryAndBundle();
        avConfiguration = AVBasicTypes.Configuration(
            address(avSnapshot),
            address(avSnapshot).codehash,
            _authorityViewConstructionBudgets().boundSnapshotValidationGas,
            address(avCheckpoint),
            address(avCheckpoint).codehash,
            address(avOutput),
            address(avOutput).codehash
        );
        avDeclaration = AVDeclaration.Binding(
            address(avViews),
            address(avViews).codehash,
            address(assemblyMembership),
            address(assemblyMembership).codehash,
            2000000,
            4000000
        );
        avSelection = AVSources.Selection(
            address(avReference),
            address(avReference).codehash,
            address(avInventory),
            address(avInventory).codehash,
            address(avBundle),
            address(avBundle).codehash
        );
        AVBasicTypes.Capability memory cap =
            AVBasic(address(assemblyProvider)).viewPreservationBindingCapability();
        require(
            AVComplete(address(assemblyProvider)).completeViewPreservationBindingProfile()
                == keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_BINDING_V1"),
            "actual complete source capability"
        );
        require(
            cap.authority == address(assemblyExecutor)
                && cap.authorityCodeHash == address(assemblyExecutor).codehash
                && cap.originalHash == keccak256(abi.encode(scopedGraphOriginal))
                && cap.capabilityHash
                    == AVBasicTypes.hashCapability(block.chainid, address(assemblyProvider), cap),
            "actual original provider capability"
        );
        _authorityRequireViewPending();
    }

    function _avDeployOutputSources() private {
        AuthorityViewConstructionBudgets memory budget = _authorityViewConstructionBudgets();
        _avInit(
            type(AVStaticAttribution).creationCode,
            abi.encode(
                address(assemblyCore),
                address(assemblyRouter),
                address(assemblyArtists),
                address(assemblyFinality),
                address(assemblyExecutor)
            )
        );
        avOriginalAttribution = new AVStaticAttribution(
            address(assemblyCore),
            address(assemblyRouter),
            address(assemblyArtists),
            address(assemblyFinality),
            address(assemblyExecutor)
        );
        _avRuntime(address(avOriginalAttribution));
        _avInit(
            type(AVAttribution).creationCode,
            abi.encode(
                address(avOriginalAttribution),
                address(avOriginalAttribution),
                address(assemblyExecutor)
            )
        );
        avAttribution = new AVAttribution(
            address(avOriginalAttribution),
            address(avOriginalAttribution),
            address(assemblyExecutor)
        );
        _avRuntime(address(avAttribution));
        require(
            avAttribution.preservationAttributionProfile()
                == keccak256("6529STREAM_NON_SANCTION_ATTRIBUTION_V1"),
            "exact original VIEW projection"
        );
        AVRendererAPI.Configuration memory render = AVRendererAPI.Configuration(
            address(assemblyCore),
            address(assemblyCore).codehash,
            address(assemblyRouter),
            address(assemblyRouter).codehash,
            address(avAttribution),
            address(avAttribution).codehash,
            block.chainid,
            budget.rendererGas,
            budget.attributionGas
        );
        _avInit(type(AVRenderer).creationCode, abi.encode(render));
        avRenderer = new AVRenderer(render);
        _avRuntime(address(avRenderer));
        require(
            keccak256(abi.encode(avRenderer.configuration())) == keccak256(abi.encode(render)),
            "actual VIEW producer config"
        );
        AVCheckpointTypes.Configuration memory cp = AVCheckpointTypes.Configuration(
            address(assemblyCore),
            address(assemblyCore).codehash,
            address(assemblyRouter),
            address(assemblyRouter).codehash,
            address(assemblyExecutor),
            address(assemblyExecutor).codehash,
            address(avRenderer),
            address(avRenderer).codehash,
            avRenderer.configurationHash(),
            block.chainid,
            budget.checkpointReadGas,
            budget.checkpointServingGas
        );
        _avInit(type(AVCheckpoint).creationCode, abi.encode(cp));
        avCheckpoint = new AVCheckpoint(cp);
        _avRuntime(address(avCheckpoint));
        require(
            keccak256(abi.encode(avCheckpoint.configuration())) == keccak256(abi.encode(cp)),
            "actual VIEW checkpoint config"
        );
        AVOutputTypes.Configuration memory output = AVOutputTypes.Configuration(
            address(assemblyCore),
            address(assemblyCore).codehash,
            address(avCheckpoint),
            address(avCheckpoint).codehash,
            avCheckpoint.configurationHash(),
            address(assemblyArtifact),
            address(assemblyArtifact).codehash,
            address(assemblySchemas),
            address(assemblySchemas).codehash,
            block.chainid,
            budget.outputReadGas,
            budget.outputValidationGas
        );
        _avInit(type(AVOutput).creationCode, abi.encode(output));
        avOutput = new AVOutput(output);
        _avRuntime(address(avOutput));
        require(
            keccak256(abi.encode(avOutput.configuration())) == keccak256(abi.encode(output)),
            "actual VIEW output config"
        );
        _avDeploySnapshot();
    }

    function _avDeploySnapshot() private {
        AuthorityViewConstructionBudgets memory budget = _authorityViewConstructionBudgets();
        AVSnapshotTypes.Dependencies memory d;
        d.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblySchemas),
            address(assemblyStore),
            address(assemblyRouter),
            address(assemblyMembership),
            address(avCheckpoint),
            address(avOutput),
            address(assemblyArtifact),
            address(assemblyExecutor)
        ];
        for (uint256 i; i < d.targets.length; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = budget.snapshotReadGas;
        d.sourceGas = budget.snapshotSourceGas;
        d.inventoryGas = budget.snapshotInventoryGas;
        AVGas.GasParameterConfig[3] memory caps = [
            AVGas.GasParameterConfig("VIEW_PRESERVATION_SNAPSHOT_READ_GAS", d.readGas, 100000, 2),
            AVGas.GasParameterConfig(
                "VIEW_PRESERVATION_SNAPSHOT_SOURCE_GAS", d.sourceGas, 100000, 2
            ),
            AVGas.GasParameterConfig(
                    "VIEW_PRESERVATION_SNAPSHOT_INVENTORY_GAS", d.inventoryGas, 100000, 2
                )
        ];
        _avInit(type(AVSnapshot).creationCode, abi.encode(d, address(assemblyExecutor), caps));
        avSnapshot = new AVSnapshot(d, address(assemblyExecutor), caps);
        _avRuntime(address(avSnapshot));
        require(
            keccak256(abi.encode(avSnapshot.dependencies())) == keccak256(abi.encode(d)),
            "actual VIEW snapshot config"
        );
    }

    function _avDeployDeclaration() private {
        AVViews.Configuration memory c = AVViews.Configuration(
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblyExecutor),
            ASSEMBLY_DEPLOYMENT,
            "urn:fixture:authority:view-declarations",
            keccak256("original current-authority VIEW declarations"),
            AVGas.GasParameterConfig("METADATA_DEPENDENCY_READ_GAS", 2000000, 50000, 2)
        );
        _avInit(type(AVViews).creationCode, abi.encode(c));
        avViews = new AVViews(c);
        _avRuntime(address(avViews));
        uint256 beforeCount = assemblyModules.moduleCount();
        AVModuleRegistration[] memory rows = new AVModuleRegistration[](1);
        rows[0] = AVModuleRegistration(
            address(avViews),
            avViews.streamModuleType(),
            avViews.streamModuleVersion(),
            type(AVViewsAPI).interfaceId,
            4000000,
            address(avViews).codehash,
            ASSEMBLY_DEPLOYMENT,
            c.manifestHash,
            c.manifestURI
        );
        (AVCall[] memory calls, bytes[] memory inputs) =
            AVStack.registrationCalls(assemblyModules, rows);
        _assemblyGovernanceCall(
            1,
            calls[0].target,
            inputs[0],
            calls[0].scopeHash,
            calls[0].oldValueHash,
            calls[0].newValueHash
        );
        AVModuleRecord memory record = assemblyModules.moduleRecord(address(avViews));
        require(
            assemblyModules.moduleCount() == beforeCount + 1
                && assemblyModules.moduleAt(beforeCount) == address(avViews)
                && assemblyModules.isModuleEligible(
                    address(avViews), keccak256("COLLECTION_VIEWS"), type(AVViewsAPI).interfaceId
                ) && record.status == AVModuleStatus.ACTIVE && record.revision == 1
                && record.runtimeCodeHash == address(avViews).codehash
                && record.moduleManifestHash == c.manifestHash
                && record.deploymentManifestHash == ASSEMBLY_DEPLOYMENT,
            "actual declaration module admission"
        );
        if (!assemblySchemas.document(assemblySchemas.RAW_BYTES()).exists) {
            _assemblyRegisterDocument(
                "RAW_BYTES",
                AVSchema.DocumentKind.CANONICALIZATION,
                bytes(assemblySchemas.RAW_BYTES_DEFINITION()),
                assemblySchemas.RAW_BYTES()
            );
        }
        (bytes32 id, bytes32 hash, bytes memory raw) = avViews.viewSchema();
        require(
            id == keccak256("STREAM_COLLECTION_VIEW_MANIFEST_ABI_V1") && hash == keccak256(raw),
            "actual declaration schema"
        );
        require(
            _assemblyRegisterDocument(
                    "STREAM_COLLECTION_VIEW_MANIFEST_ABI_V1",
                    AVSchema.DocumentKind.SCHEMA,
                    raw,
                    assemblySchemas.RAW_BYTES()
                ) == id && assemblySchemas.document(id).specification.contentHash == hash,
            "real Schema/Store declaration admission"
        );
    }

    function _avDeployReference() private {
        AuthorityViewConstructionBudgets memory budget = _authorityViewConstructionBudgets();
        AVReferenceTypes.Dependencies memory d;
        d.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblySchemas),
            address(assemblyStore),
            address(assemblyRouter),
            address(avSnapshot),
            address(assemblyExternal)
        ];
        for (uint256 i; i < d.targets.length; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = budget.referenceReadGas;
        d.sourceGas = budget.referenceSourceGas;
        d.snapshotGas = budget.referenceSnapshotGas;
        d.archiveGas = budget.referenceArchiveGas;
        AVGas.GasParameterConfig[4] memory caps = [
            AVGas.GasParameterConfig("VIEW_PRESERVATION_REFERENCE_READ_GAS", d.readGas, 50000, 1),
            AVGas.GasParameterConfig(
                "VIEW_PRESERVATION_REFERENCE_SOURCE_GAS", d.sourceGas, 50000, 1
            ),
            AVGas.GasParameterConfig(
                    "VIEW_PRESERVATION_REFERENCE_SNAPSHOT_GAS", d.snapshotGas, 50000, 1
                ),
            AVGas.GasParameterConfig(
                "VIEW_PRESERVATION_REFERENCE_ARCHIVE_GAS", d.archiveGas, 50000, 1
            )
        ];
        _avInit(type(AVReference).creationCode, abi.encode(d, address(assemblyExecutor), caps));
        avReference = new AVReference(d, address(assemblyExecutor), caps);
        _avRuntime(address(avReference));
        require(
            keccak256(abi.encode(avReference.dependencies())) == keccak256(abi.encode(d)),
            "actual VIEW reference config"
        );
    }

    function _avDeployInventoryAndBundle() private {
        AVS.Dependencies memory d = assemblyInventory.originalAnchor();
        d.targets[5] = address(avSnapshot);
        d.codeHashes[5] = address(avSnapshot).codehash;
        d.targets[6] = address(avReference);
        d.codeHashes[6] = address(avReference).codehash;
        d.readGas = 2000000;
        d.sourceGas = 18000000;
        d.selectionGas = 8000000;
        d.snapshotGas = 18000000;
        d.referenceGas = 24000000;
        _avDeployRetrieval(d);
        _avInit(
            type(AVInventory).creationCode,
            abi.encode(d, address(avRetrieval), address(avRetrieval).codehash)
        );
        avInventory = new AVInventory(d, address(avRetrieval), address(avRetrieval).codehash);
        _avRuntime(address(avInventory));
        require(
            keccak256(abi.encode(avInventory.dependencies())) == keccak256(abi.encode(d))
                && avInventory.dependencyHash() == keccak256(abi.encode(d)),
            "selected VIEW keeps its genuine raw commitment"
        );
        (address witness, bytes32 witnessCodeHash) = avInventory.retrievalWitnessBinding();
        require(
            witness == address(avRetrieval) && witnessCodeHash == address(avRetrieval).codehash,
            "actual immutable VIEW retrieval companion"
        );
        AVBundleTypes.Dependencies memory b;
        b.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(avInventory),
            address(assemblyArtifact),
            address(assemblyExternal),
            d.artistTargets[4]
        ];
        for (uint256 i; i < b.targets.length; ++i) {
            b.codeHashes[i] = b.targets[i].codehash;
        }
        b.chainId = block.chainid;
        b.readGas = 2000000;
        b.archiveGas = 8000000;
        _avInit(type(AVBundle).creationCode, abi.encode(b));
        avBundle = new AVBundle(b);
        _avRuntime(address(avBundle));
        require(
            keccak256(abi.encode(avBundle.dependencies())) == keccak256(abi.encode(b))
                && avBundle.dependencyHash() == keccak256(abi.encode(b)),
            "actual VIEW bundle configuration"
        );
    }

    function _avDeployRetrieval(AVS.Dependencies memory d) private {
        AVSnapshotTypes.Dependencies memory snapshot = avSnapshot.dependencies();
        uint256 sourceGas = _authorityViewRetrievalSourceGas(snapshot.sourceGas);
        require(
            snapshot.targets[6] == address(avCheckpoint)
                && snapshot.codeHashes[6] == address(avCheckpoint).codehash,
            "retrieval uses the actual snapshot checkpoint"
        );
        require(
            d.readGas <= type(uint32).max && sourceGas <= type(uint32).max,
            "retrieval constructor gas widths"
        );
        // Identity-only construction: no unpublished adoption or checkpoint head is read.
        // These diagnostic caps do not establish operative bundle/transaction capacity.
        AVRetrievalTypes.Configuration memory c = AVRetrievalTypes.Configuration(
            d.targets[0],
            d.codeHashes[0],
            d.targets[4],
            d.codeHashes[4],
            snapshot.targets[6],
            snapshot.codeHashes[6],
            d.targets[11],
            d.codeHashes[11],
            d.chainId,
            uint32(d.readGas),
            uint32(sourceGas),
            uint32(d.readGas),
            400000
        );
        _avInit(type(AVRetrieval).creationCode, abi.encode(c));
        avRetrieval = new AVRetrieval(c);
        _avRuntime(address(avRetrieval));
        require(
            keccak256(abi.encode(avRetrieval.configuration())) == keccak256(abi.encode(c))
                && avRetrieval.configurationHash()
                    == keccak256(abi.encode(AVRetrievalTypes.PROFILE, c))
                && avRetrieval.retrievalProfile() == AVRetrievalTypes.PROFILE,
            "actual VIEW retrieval configuration"
        );
    }

    function _authorityRequireCompositeAnchor() internal view {
        AVS.Dependencies memory d = assemblyInventory.dependencies();
        AVO.Dependencies memory o = assemblyInventory.originDependencies();
        AVD.Dependencies memory a = assemblyInventory.authorityDependencies();
        bytes32 profile = assemblyInventory.originProfile();
        bytes32 committed = AVD.dependencyHash(profile, d, o, a);
        require(
            profile == AVD.INVENTORY_PROFILE && committed == assemblyInventory.dependencyHash()
                && committed == scopedGraphOriginal.inventoryDependencyHash
                && committed != keccak256(abi.encode(d))
                && keccak256(abi.encode(d))
                    == keccak256(abi.encode(assemblyInventory.originalAnchor()))
                && scopedGraphOriginal.targets[18] == address(assemblyInventory)
                && d.artistTargets[0] == address(assemblyArtists)
                && d.artistTargets[4] == assemblySuite.archive,
            "genuine original current-authority commitment, never raw-hash substitution"
        );
    }

    function _authorityOriginalRosterHash() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                scopedGraphOriginal,
                assemblyInventory.dependencies(),
                assemblyInventory.originProfile(),
                assemblyInventory.originDependencies(),
                assemblyInventory.authorityDependencies(),
                assemblyInventory.dependencyHash()
            )
        );
    }

    function _authorityRequireViewPending() internal view {
        AVBasic binding_ = AVBasic(address(assemblyProvider));
        AVBasicTypes.Receipt memory empty;
        require(
            binding_.viewPreservationBindingStatus() == 0
                && keccak256(abi.encode(binding_.viewPreservationBindingReceipt()))
                    == keccak256(abi.encode(empty)),
            "entire basic receipt remains empty"
        );
        (bool ok, bytes memory reason) = address(assemblyProvider)
            .staticcall(abi.encodeCall(AVSources.viewFinalitySourcesReceipt, ()));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            AVCompleteTypes.ViewPreservationCompleteBindingUnavailable.selector
                        )
                    ),
            "complete receipt unavailable while pending"
        );
    }

    function _authorityViewPreview() internal view returns (AVBasicTypes.Transition memory) {
        return AVComplete(address(assemblyProvider))
            .completeViewPreservationBindingTransition(avConfiguration, avDeclaration, avSelection);
    }

    function _authorityViewBindingBatch() internal returns (AVBatch memory batch) {
        avTransition = _authorityViewPreview();
        batch.actionClass = 2;
        batch.calls = new AVCall[](1);
        batch.callDatas = new bytes[](1);
        batch.callDatas[0] = abi.encodeCall(
            AVComplete.bindCompleteViewPreservation, (avConfiguration, avDeclaration, avSelection)
        );
        batch.calls[0] = AVStack.call(
            address(assemblyProvider),
            batch.callDatas[0],
            avTransition.scopeHash,
            avTransition.oldValueHash,
            avTransition.newValueHash
        );
    }

    function _authorityBindCompleteView() internal {
        AVBatch memory batch = _authorityViewBindingBatch();
        // Policy admission may itself schedule actions; the observed class2 action below is the binding.
        _admitAssemblyBatch(batch);
        avAction = _assemblyScheduleGovernance(batch, "urn:fixture:authority:complete-view-binding");
        _authorityExecuteCompleteView(batch);
    }

    function _authorityExecuteCompleteView(AVBatch memory batch) internal {
        assemblyVm.recordLogs();
        _assemblyExecuteGovernance(avAction, batch);
        avReceipt = AVSources(address(assemblyProvider)).viewFinalitySourcesReceipt();
        require(avReceipt.boundAt == block.timestamp, "actual execution timestamp");
        CurrentAuthorityAssemblyVm.Log[] memory logs = assemblyVm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(assemblyProvider) || logs[i].topics.length == 0
                    || logs[i].topics[0]
                        != keccak256(
                            "ViewPreservationCompleteBound(bytes32,bytes32,bytes32,bytes32)"
                        )
            ) continue;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == avReceipt.recordHash
                    && logs[i].topics[2] == avReceipt.basicBindingRecordHash
                    && logs[i].topics[3] == avAction
                    && keccak256(logs[i].data) == keccak256(abi.encode(avTransition.newValueHash)),
                "exact actual complete event"
            );
            ++count;
        }
        require(count == 1, "one complete source admission");
        _authorityRequireCompleteView();
    }

    function _authorityRequireCompleteView() internal view {
        AVBasicTypes.Receipt memory basic =
            AVBasic(address(assemblyProvider)).viewPreservationBindingReceipt();
        AVSources.Receipt memory complete =
            AVSources(address(assemblyProvider)).viewFinalitySourcesReceipt();
        require(
            keccak256(abi.encode(basic.configuration)) == keccak256(abi.encode(avConfiguration))
                && keccak256(abi.encode(basic.declaration)) == keccak256(abi.encode(avDeclaration))
                && keccak256(abi.encode(basic.dependencies))
                    == keccak256(abi.encode(avSnapshot.dependencies()))
                && basic.dependenciesHash == keccak256(abi.encode(basic.dependencies))
                && basic.workersHash != 0
                && basic.capabilityHash
                    == AVBasic(address(assemblyProvider))
                    .viewPreservationBindingCapability()
                    .capabilityHash,
            "exact basic receipt configuration, original declaration and source workers"
        );
        require(
            AVBasic(address(assemblyProvider)).viewPreservationBindingStatus() == 1
                && basic.recordHash == AVBasicTypes.receiptHash(basic) && complete.recordHash != 0
                && complete.actionId == avAction && complete.actionId == basic.actionId
                && complete.boundAt == basic.boundAt
                && complete.basicBindingRecordHash == basic.recordHash
                && complete.referenceDependenciesHash
                    == keccak256(abi.encode(avReference.dependencies()))
                && complete.inventoryDependenciesHash
                    == keccak256(abi.encode(avInventory.dependencies()))
                && complete.bundleDependenciesHash == keccak256(abi.encode(avBundle.dependencies()))
                && keccak256(abi.encode(complete.selection)) == keccak256(abi.encode(avSelection))
                && keccak256(abi.encode(AVSources(address(assemblyProvider)).viewFinalitySources()))
                == keccak256(abi.encode(avSelection)),
            "same actual action and all complete source commitments"
        );
        require(
            complete.recordHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_RECEIPT_V1"),
                        block.chainid,
                        address(assemblyProvider),
                        complete.selection,
                        complete.referenceDependenciesHash,
                        complete.inventoryDependenciesHash,
                        complete.bundleDependenciesHash,
                        complete.basicBindingRecordHash,
                        complete.actionId,
                        complete.boundAt
                    )
                ),
            "literal complete receipt preimage"
        );
        require(
            avTransition.newValueHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_PROPOSAL_V1"),
                            AVBasicTypes.proposalHash(basic),
                            complete.selection,
                            complete.referenceDependenciesHash,
                            complete.inventoryDependenciesHash,
                            complete.bundleDependenciesHash
                        )
                    )
                && keccak256(abi.encode(avTransition))
                    == keccak256(
                        abi.encode(
                            AVCompleteTypes.transition(
                                block.chainid, address(assemblyProvider), basic, complete
                            )
                        )
                    ),
            "full class2 proposal, not basic-only admission"
        );
        require(
            assemblyExecutor.governanceAction(avAction).status == AVActionStatus.EXECUTED
                && AVCatalogue(address(assemblyProvider)).finalitySourceConfigurationHash()
                    == avOriginalSourceHash
                && _authorityOriginalRosterHash() == avOriginalRosterHash,
            "original source configuration and roster retained"
        );
        _authorityRequireCompositeAnchor();
    }

    function _authorityViewScope() internal pure returns (AVScope memory) {
        // Canonical, unpublished VIEW. Catalogue proves source identities, not membership/evidence.
        return
            AVScope(AVScopeType.VIEW, 1, 0, keccak256("unpublished actual source catalogue VIEW"));
    }

    function _authorityRequireViewCatalogue() internal view returns (bytes32 resultHash) {
        AVScope memory scope = _authorityViewScope();
        AVCatalogue.Sources memory selected =
            AVCatalogue(address(assemblyProvider)).finalitySourcesForScope(scope);
        bytes32 profile = keccak256("6529STREAM_VIEW_PRESERVATION_FINALITY_V1");
        AVCatalogue.Profile memory expected = AVCatalogue.Profile(
            profile,
            address(avReference),
            address(avReference).codehash,
            address(avSnapshot),
            address(avSnapshot).codehash,
            sourceScopedPolicyEntropyFactory,
            sourceScopedPolicyEntropyFactory.codehash,
            keccak256(
                abi.encode(
                    profile,
                    block.chainid,
                    address(assemblyProvider),
                    keccak256(abi.encode(scopedGraphOriginal)),
                    avReceipt.recordHash
                )
            )
        );
        require(
            keccak256(abi.encode(selected))
                == keccak256(abi.encode(AVCatalogue.Sources(scope, expected))),
            "actual current graph VIEW catalogue"
        );
        return keccak256(abi.encode(selected));
    }

    function _authorityViewHistoryHash() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                AVBasic(address(assemblyProvider)).viewPreservationBindingReceipt(),
                AVSources(address(assemblyProvider)).viewFinalitySourcesReceipt()
            )
        );
    }

    function _avInit(bytes memory creation, bytes memory arguments) private pure {
        require(creation.length + arguments.length <= 49152, "actual initcode limit");
    }

    function _avRuntime(address product) private view {
        require(product.code.length != 0 && product.code.length <= 24576, "actual runtime limit");
    }
}
