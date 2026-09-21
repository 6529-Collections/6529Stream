// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFullV1ActivationFixture.sol";
import "../../script/current/StreamCurrentFullPreservationPolicyGraph.sol";
import {
    StreamFullV1ActivationPolicies
} from "../../script/current/StreamFullV1ActivationPolicies.sol";
import { StreamFullV1ActivationPlan } from "../../script/current/StreamFullV1ActivationPlan.sol";
import {
    StreamGovernanceCatalogStagePlan
} from "../../script/current/StreamGovernanceCatalogStagePlan.sol";
import { NativeAssemblyVm } from "./StreamNativeFinalityAssemblyFixture.sol";
import {
    StreamMintArtistConsent
} from "../../smart-contracts/domains/mint/StreamMintArtistConsent.sol";
import {
    IStreamArtistContentRatification
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistContentRatification.sol";
import {
    StreamArtistEstateCoverage
} from "../../smart-contracts/domains/artist/StreamArtistEstateCoverage.sol";
import {
    StreamArtistTimingState
} from "../../smart-contracts/domains/artist/StreamArtistTimingState.sol";
import {
    StreamArtistExtensionFactory
} from "../../smart-contracts/domains/artist/StreamArtistExtensionFactory.sol";
import "../../script/current/StreamDeploymentSlot.sol";

import { StreamNativeAssemblyCreation } from "./StreamNativeAssemblyCreation.sol";

import "./OfficialSafeFixture.sol";
import "../../script/current/StreamGovernanceGenesisPlan.sol";
import "../../script/current/StreamRevealActivationPlan.sol";
import "../../smart-contracts/domains/mint/StreamFixedPriceSaleAdapter.sol";
import { StreamRevenueEscrow } from "../../smart-contracts/domains/revenue/StreamRevenueEscrow.sol";
import "../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";
import "../mocks/MockStreamEntropyProvider.sol";
import {
    StreamArchivalTypes as OcA
} from "../../smart-contracts/interfaces/stream/preservation/StreamArchivalTypes.sol";
import {
    StreamFinalityArtifactTypes as OcF
} from "../../smart-contracts/interfaces/stream/preservation/StreamFinalityArtifactTypes.sol";
import {
    StreamArtistContentTypes as AssemblyContent
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    StreamArtistRecordPublicationTypes as AssemblyPublication
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRecordPublicationTypes.sol";
import {
    IStreamArtistRecordPublicationOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import { StreamMintManager } from "../../smart-contracts/domains/mint/StreamMintManager.sol";
import "../../smart-contracts/domains/mint/StreamMintLedger.sol";
import "../../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol";
import "../../smart-contracts/domains/revenue/StreamSplitFactory.sol";
import "../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";
import "../../smart-contracts/domains/revenue/StreamRoyaltyResolver.sol";
import "../../smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol";
import "../../smart-contracts/domains/artist/StreamArtistOnboardingCoordinator.sol";
import "../../smart-contracts/domains/artist/StreamArtistArchiveV2.sol";
import "../../smart-contracts/domains/artist/StreamArtistBindingLifecycle.sol";
import "../../smart-contracts/domains/artist/StreamArtistCollaboratorLifecycle.sol";
import "../../smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol";
import "../../smart-contracts/domains/artist/StreamArtistAcceptanceLifecycle.sol";
import "../../smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol";
import "../../smart-contracts/domains/artist/StreamArtistPayoutLifecycle.sol";
import "../../smart-contracts/domains/artist/StreamArtistConsentFinalityLifecycle.sol";
import {
    StreamMetadataRouter
} from "../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import "../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";
import "../../smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol";
import "../../smart-contracts/domains/preservation/StreamArchivalCoverage.sol";
import "../../smart-contracts/domains/preservation/StreamArweaveCheckpointVerifier.sol";
import "../../smart-contracts/domains/preservation/StreamArweaveObjectCheckpointVerifier.sol";
import "../../smart-contracts/domains/preservation/StreamExternalArtifactCoverage.sol";
import "../../smart-contracts/domains/preservation/StreamFinalityArtifactCoverage.sol";
import "../../smart-contracts/domains/finality/StreamCollectionTokenInventory.sol";
import "../../smart-contracts/domains/finality/StreamOnchainContentCheckpoint.sol";
import "../../smart-contracts/domains/finality/StreamContentLeafManifest.sol";
import "../../smart-contracts/domains/finality/StreamFinalityScopeMembership.sol";
import "../../smart-contracts/domains/finality/StreamFinalityCoordinatorInventory.sol";
import "../../smart-contracts/domains/finality/StreamFinalityEntropySourceFactory.sol";
import "../../smart-contracts/domains/finality/StreamFinalityNativeEvidenceProvider.sol";
import "../../smart-contracts/domains/finality/StreamFinalityCurrentDiscovery.sol";
import "../../smart-contracts/domains/finality/StreamCoreFinalityAdapter.sol";
import "../../smart-contracts/domains/finality/StreamArtworkFinalityRegistry.sol";
import "../../smart-contracts/domains/finality/StreamFinalityServingHostAdapter.sol";
import "../../smart-contracts/domains/metadata/StreamCollectionSnapshots.sol";
import "../../smart-contracts/domains/metadata/StreamWorkRecordSelection.sol";
import "../../smart-contracts/domains/metadata/StreamRightsRecordSelection.sol";
import "../../smart-contracts/domains/metadata/StreamConservationRecordSelection.sol";
import "../../smart-contracts/domains/preservation/StreamReferenceRenderPublication.sol";
import {
    StreamRenderCriticalInventory
} from "../../smart-contracts/domains/preservation/StreamRenderCriticalInventory.sol";
import {
    StreamBundleArchiveCoverage
} from "../../smart-contracts/domains/preservation/StreamBundleArchiveCoverage.sol";
import "../../smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamPreservationDocumentReads
} from "../../smart-contracts/domains/preservation/StreamPreservationDocumentReads.sol";
import {
    StreamPreservationInventoryChains
} from "../../smart-contracts/domains/preservation/StreamPreservationInventoryChains.sol";
import {
    StreamPreservationInventoryTypes as AssemblyInventory
} from "../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamExternalArtifactTypes as AxE
} from "../../smart-contracts/interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    StreamArchivalTypes as AxA
} from "../../smart-contracts/interfaces/stream/preservation/StreamArchivalTypes.sol";

import {
    StreamFinalityInputManifestSchemas
} from "../../smart-contracts/domains/finality/StreamFinalityInputManifestSchemas.sol";
import {
    StreamFinalitySanctionSchemas
} from "../../smart-contracts/domains/finality/StreamFinalitySanctionSchemas.sol";
import {
    StreamArtistSanctionHashes
} from "../../smart-contracts/domains/artist/StreamArtistSanctionHashes.sol";
import {
    StreamArtistSanctionTypes as AssemblySanction
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionTypes.sol";
import {
    StreamArtistSanctionRequestTypes as AssemblySanctionRequest
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionRequestTypes.sol";

import {
    IStreamSchemaRegistry as Schema
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamStaticMetadataRouter as StaticRouter
} from "../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamStaticMetadataSource as StaticSource
} from "../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataSource.sol";
import {
    IStreamStaticEntropySource
} from "../../smart-contracts/interfaces/stream/metadata/IStreamStaticEntropySource.sol";
import { IStreamCoreMint } from "../../smart-contracts/interfaces/stream/core/IStreamCoreMint.sol";
import {
    StreamStaticRenderEncoding
} from "../../smart-contracts/domains/metadata/StreamStaticRenderEncoding.sol";
import { StreamRendererV1 } from "../../smart-contracts/domains/metadata/StreamRendererV1.sol";

import {
    IStreamArtistContentAuthority
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistContentAuthority.sol";
import {
    StreamArtistContentTypes as Content
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import { Strings } from "../../smart-contracts/vendor/openzeppelin/Strings.sol";
import { Base64 } from "../../smart-contracts/vendor/openzeppelin/Base64.sol";
import {
    IStreamCurrentCitationRegistry as TokenCitationRegistry
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCurrentCitationRegistry.sol";
import {
    IStreamCurrentCitationRenderer as TokenCitationRenderer
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCurrentCitationRenderer.sol";

import {
    StreamMetadataPolicyPublicationGraphReadsV2 as RootGraph
} from "../../smart-contracts/domains/metadata/StreamMetadataPolicyPublicationGraphReadsV2.sol";

import {
    StreamPreservationRendererV1
} from "../../smart-contracts/domains/metadata/StreamPreservationRendererV1.sol";
import {
    StreamPreservationAttributionCompanion
} from "../../smart-contracts/domains/metadata/StreamPreservationAttributionCompanion.sol";
import {
    IStreamPreservationRegistryV1 as PreservationRegistry
} from "../../smart-contracts/interfaces/stream/metadata/IStreamPreservationRegistryV1.sol";
import {
    IStreamPreservationRendererV1 as PreservationRenderer
} from "../../smart-contracts/interfaces/stream/metadata/IStreamPreservationRendererV1.sol";
import {
    IStreamPreservationAttributionV1 as PreservationAttribution
} from "../../smart-contracts/interfaces/stream/metadata/IStreamPreservationAttributionV1.sol";
import {
    StreamNativeFullPreservationPolicyCreation as NativePreservationCreation
} from "./StreamNativeFullPreservationPolicyCreation.sol";
import {
    StreamViewPreservationRendererV1
} from "../../smart-contracts/domains/metadata/StreamViewPreservationRendererV1.sol";
import {
    IStreamViewPreservationRendererV1 as ViewPreservationRenderer
} from "../../smart-contracts/interfaces/stream/metadata/IStreamViewPreservationRendererV1.sol";
import {
    StreamViewPreservationContentCheckpointV1
} from "../../smart-contracts/domains/finality/StreamViewPreservationContentCheckpointV1.sol";
import {
    StreamViewPreservationOutputManifestV1
} from "../../smart-contracts/domains/finality/StreamViewPreservationOutputManifestV1.sol";
import {
    StreamViewPreservationSnapshotPublicationV1
} from "../../smart-contracts/domains/metadata/StreamViewPreservationSnapshotPublicationV1.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as ViewPreservationCheckpointTypes
} from "../../smart-contracts/interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    StreamViewPreservationManifestTypesV1 as ViewPreservationManifestTypes
} from "../../smart-contracts/interfaces/stream/finality/StreamViewPreservationManifestTypesV1.sol";
import {
    StreamViewPreservationSnapshotTypesV1 as ViewPreservationSnapshotTypes
} from "../../smart-contracts/interfaces/stream/metadata/StreamViewPreservationSnapshotTypesV1.sol";
import {
    StreamFinalityViewPreservationBindingTypesV1 as ViewPreservationBindingTypes
} from "../../smart-contracts/interfaces/stream/finality/StreamFinalityViewPreservationBindingTypesV1.sol";
import {
    IStreamFinalityViewPreservationBindingV1 as ViewPreservationBinding
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityViewPreservationBindingV1.sol";
import {
    IStreamViewPreservationEvidenceBindingV1 as ViewPreservationEvidence
} from "../../smart-contracts/interfaces/stream/finality/IStreamViewPreservationEvidenceBindingV1.sol";
import {
    StreamCollectionViews
} from "../../smart-contracts/domains/metadata/StreamCollectionViews.sol";
import {
    IStreamCollectionViews as CollectionViews
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionViews.sol";
import {
    StreamViewAdoptionTypes as ViewAdoption
} from "../../smart-contracts/interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import {
    IStreamViewSourceBinding as ViewSource
} from "../../smart-contracts/interfaces/stream/finality/IStreamViewSourceBinding.sol";

/// @notice Actual 37-role fixed-factory graph with real threshold Artist/governor Safes.
/// @dev Renderer admission documents and observer keys are explicit local fixtures, not a
/// performed conformance audit or public archive attestation. Production authority is actual.
abstract contract StreamCurrentFullPreservationPolicyPublicationBase is
    StreamFullV1ActivationFixture,
    StreamCurrentFullPreservationPolicyGraph
{
    NativeAssemblyVm internal constant assemblyVm =
        NativeAssemblyVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 internal constant ASSEMBLY_DEPLOYMENT = DEPLOYMENT_HASH;
    OfficialSafe internal assemblyRoot;
    OfficialSafe internal assemblyArtist;
    uint256[] internal assemblyRootKeys;
    uint256[] internal assemblyArtistKeys;
    GovernanceActionPolicyEntry[] private assemblyPolicies;
    bytes32 internal assemblyArtistId;
    Versions.Registration internal registration;
    Versions.Read[] internal declaredReads;
    bytes32 internal versionKey;
    StreamPreservationAttributionCompanion internal assemblyPreservationAttribution;
    StreamPreservationRendererV1 internal assemblyPreservationRenderer;
    uint256[] internal assemblyPreservationTokens;
    bytes32 internal assemblyPreservationKey;
    PreservationRegistry.PreservationRecord internal assemblyPreservationRegistration;
    StreamViewPreservationRendererV1 internal assemblyViewPreservationRenderer;
    StreamViewPreservationContentCheckpointV1 internal assemblyViewPreservationCheckpoint;
    StreamViewPreservationOutputManifestV1 internal assemblyViewPreservationManifest;
    StreamViewPreservationSnapshotPublicationV1 internal assemblyViewPreservationSnapshot;
    StreamCollectionViews internal assemblyViewDeclarations;
    bytes32 internal assemblyViewPreservationBindingReceiptHash;

    function _constructFullPolicyPublication() internal {
        assemblyArtistKeys.push(0x65297011);
        assemblyArtistKeys.push(0x65297012);
        SafeComponents memory safe = deploySafeComponents("1.4.1");
        assemblyArtist = createOfficialSafe(safe, safeOwnerAddresses(assemblyArtistKeys), 2, 7011);
        _deployCurrentStack(address(assemblyArtist), vm.addr(PLATFORM_KEY));
        _foundation();
        _commerce();
        _independent();
        _records();
        _constructOriginalRenderer();
        _providers();
        _continuity();
        savedInventoryHash = StreamFullV1Candidate.inventoryHash(
            StreamFullV1Candidate.capture(foundation, configuration, products)
        );
        assemblyRootKeys.push(0x65297021);
        assemblyRootKeys.push(0x65297022);
        assemblyRoot = createOfficialSafe(safe, safeOwnerAddresses(assemblyRootKeys), 2, 7021);
        _installGovernorSafe(assemblyRoot, assemblyRootKeys);
        assemblyArtistId = fixtureArtistId;
        GovernanceActionPolicyEntry[] memory retained = _retainedFoundationPolicies();
        for (uint256 i; i < retained.length; ++i) {
            assemblyPolicies.push(retained[i]);
        }
        _admitAssemblyPolicies(StreamFullV1ActivationPolicies.desired(_context()));
        _registerFullPolicyProducts();
        _fixtureDocuments();
        (GovernanceCall memory call_, bytes memory data) = StreamFullV1StaticRendererPlan.admission(
            configuration.rendering, products.rendering, registration, declaredReads
        );
        _assemblyGovernanceCall(
            1, call_.target, data, call_.scopeHash, call_.oldValueHash, call_.newValueHash
        );
        _constructAndBindFullPolicyViewPreservation();
        _requireFullPolicyCompanionsUnchanged(_fullPolicyCompanionState());
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return _assemblyArtistProof(digest);
    }

    function _assemblyArtistProof(bytes32 digest) internal returns (bytes memory) {
        return safeThresholdSignature(
            assemblyArtistKeys, safeMessageDigest(assemblyArtist, abi.encode(digest))
        );
    }

    function _assemblyAuthorization(bool signedAt) internal returns (T.Authorization memory) {
        return _artistAuthorization(signedAt);
    }

    function _document(string memory name, Schema.DocumentKind kind, bytes memory payload)
        internal
        returns (bytes32)
    {
        return _assemblyRegisterDocument(name, kind, payload, assemblySchemas.RAW_BYTES());
    }

    function _publicationSlice(bytes memory raw, uint256 offset, uint256 length)
        private
        pure
        returns (bytes memory value)
    {
        value = new bytes(length);
        for (uint256 i; i < length; ++i) {
            value[i] = raw[offset + i];
        }
    }

    function _assemblyGovernance(GenesisBatch memory batch, string memory reasonURI)
        internal
        returns (bytes32 actionId)
    {
        assemblyExecutor.publishGovernanceCallData(batch.callDatas);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            batch.calls, StreamGovernanceBootstrap.governanceCallsHash(batch.calls)
        );
        uint64 at = uint64(block.timestamp + assemblyExecutor.minimumDelay(batch.actionClass));
        bytes memory data = abi.encodeCall(
            assemblyExecutor.scheduleGovernanceBatch,
            (
                batch.actionClass,
                batch.calls,
                scope,
                oldHash,
                newHash,
                at,
                at + 7 days,
                keccak256(bytes(reasonURI)),
                reasonURI,
                ASSEMBLY_DEPLOYMENT
            )
        );
        uint256 nonce = assemblyRoot.nonce();
        assemblyVm.recordLogs();
        require(
            executeSafe(assemblyRoot, assemblyRootKeys, address(assemblyExecutor), 0, data, 0),
            "actual root Safe schedules"
        );
        require(assemblyRoot.nonce() == nonce + 1, "root Safe consumed its transaction");
        NativeAssemblyVm.Log[] memory logs = assemblyVm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(assemblyExecutor) || logs[i].topics.length != 4
                    || logs[i].topics[0]
                        != keccak256(
                            "GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)"
                        )
            ) continue;
            GovernanceAction memory candidate = assemblyExecutor.governanceAction(logs[i].topics[1]);
            if (
                candidate.status != GovernanceActionStatus.SCHEDULED
                    || candidate.proposer != address(assemblyRoot) || candidate.scopeHash != scope
                    || candidate.oldValueHash != oldHash || candidate.newValueHash != newHash
                    || candidate.notBefore != at
                    || candidate.reasonHash != keccak256(bytes(reasonURI))
            ) continue;
            require(actionId == 0 || actionId == logs[i].topics[1], "one exact scheduled action");
            actionId = logs[i].topics[1];
        }
        require(actionId != 0, "actual saved action identified");
        assemblyVm.warp(at);
        assemblyExecutor.executeGovernanceBatch(actionId, batch.calls, batch.callDatas);
        require(
            assemblyExecutor.governanceAction(actionId).status == GovernanceActionStatus.EXECUTED,
            "actual delayed action executed"
        );
    }

    function _assemblyGovernanceCall(
        uint8 actionClass,
        address target,
        bytes memory data,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 newHash
    ) internal returns (bytes32 actionId) {
        GenesisBatch memory batch;
        batch.actionClass = actionClass;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.calls[0] = StreamCurrentStackPlan.call(target, data, scope, oldHash, newHash);
        batch.callDatas[0] = data;
        _admitAssemblyBatch(batch);
        return _assemblyGovernance(
            batch, "https://fixtures.example.invalid/native-assembly/governed-transition"
        );
    }

    function _admitAssemblyPolicies(GovernanceActionPolicyEntry[] memory candidates) internal {
        uint256 count;
        for (uint256 i; i < candidates.length; ++i) {
            bool existing;
            for (uint256 j; j < assemblyPolicies.length; ++j) {
                if (
                    _publicationPolicyKey(candidates[i])
                        != _publicationPolicyKey(assemblyPolicies[j])
                ) continue;
                require(
                    keccak256(abi.encode(candidates[i]))
                        == keccak256(abi.encode(assemblyPolicies[j])),
                    "original exact policy retained"
                );
                existing = true;
            }
            if (!existing) candidates[count++] = candidates[i];
        }
        if (count == 0) return;
        GovernanceActionPolicyEntry[] memory additions = new GovernanceActionPolicyEntry[](count);
        for (uint256 i; i < count; ++i) {
            additions[i] = candidates[i];
        }
        for (uint256 i = 1; i < count; ++i) {
            for (
                uint256 j = i;
                j > 0
                    && _publicationPolicyKey(additions[j - 1])
                        > _publicationPolicyKey(additions[j]);
                --j
            ) {
                (additions[j - 1], additions[j]) = (additions[j], additions[j - 1]);
            }
        }
        (bytes32 candidate, bytes32 catalog, uint256 oldCount, uint64 revision) =
            assemblyExecutor.governanceActionPolicyState();
        require(oldCount == assemblyPolicies.length, "actual complete policy catalog");
        (bytes32 next, bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceActionPolicy.extensionTransition(
            address(assemblyExecutor), candidate, catalog, oldCount, revision, additions
        );
        GenesisBatch memory batch;
        batch.actionClass = 3;
        batch.calls = new GovernanceCall[](2);
        batch.callDatas = new bytes[](2);
        batch.callDatas[0] = abi.encodeCall(
            assemblyExecutor.extendGovernanceActionPolicy, (revision, catalog, next, additions)
        );
        batch.calls[0] = StreamCurrentStackPlan.call(
            address(assemblyExecutor), batch.callDatas[0], scope, oldHash, newHash
        );
        (batch.calls[1], batch.callDatas[1]) = _assemblyPublication(
            StreamGenesisManifestPlan.readAggregate(assemblyManifest).modules, next
        );
        _assemblyGovernance(
            batch, "https://fixtures.example.invalid/native-assembly/policy-extension"
        );
        for (uint256 i; i < count; ++i) {
            assemblyPolicies.push(additions[i]);
        }
    }

    function _assemblyPublication(
        StreamSystemManifest.ModuleAddresses memory modules,
        bytes32 reason
    ) internal returns (GovernanceCall memory call_, bytes memory data) {
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(assemblyManifest);
        (address payload, bytes32 hash) = StreamGenesisManifestPlan.writePayload(
            abi.encodePacked(
                '{"purpose":"native finality assembly","commitment":"',
                Strings.toHexString(uint256(reason), 32),
                '"}'
            )
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            hash,
            "https://fixtures.example.invalid/native-assembly/manifest",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
        return StreamGenesisManifestPlan.publicationCall(assemblyManifest, payload, update, modules);
    }

    function _publicationPolicyKey(GovernanceActionPolicyEntry memory p)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(p.actionClass, p.target, p.selector));
    }

    function _admitAssemblyBatch(GenesisBatch memory batch) internal {
        GovernanceActionPolicyEntry[] memory rows =
            new GovernanceActionPolicyEntry[](batch.calls.length);
        uint256 count;
        for (uint256 i; i < batch.calls.length; ++i) {
            GovernanceCall memory c = batch.calls[i];
            GovernanceActionPolicyEntry memory row = GovernanceActionPolicyEntry(
                batch.actionClass,
                c.target,
                c.selector,
                c.target.codehash,
                keccak256(abi.encode(ASSEMBLY_DEPLOYMENT, c.target)),
                1,
                0,
                0,
                0
            );
            // Preserve the exact already-admitted target profile and constraints.
            // Different construction planners legitimately use different profile domains.
            for (uint256 j; j < assemblyPolicies.length; ++j) {
                GovernanceActionPolicyEntry memory known = assemblyPolicies[j];
                if (_publicationPolicyKey(known) != _publicationPolicyKey(row)) continue;
                require(
                    known.targetCodeHash == c.target.codehash && known.callType == 1
                        && known.valuePolicy == 0 && known.valueLimit == 0,
                    "retained exact zero-value CALL policy"
                );
                row = known;
                break;
            }
            bool duplicate;
            for (uint256 j; j < count; ++j) {
                if (_publicationPolicyKey(row) == _publicationPolicyKey(rows[j])) duplicate = true;
            }
            if (!duplicate) rows[count++] = row;
        }
        GovernanceActionPolicyEntry[] memory unique = new GovernanceActionPolicyEntry[](count);
        for (uint256 i; i < count; ++i) {
            unique[i] = rows[i];
        }
        _admitAssemblyPolicies(unique);
    }

    function _assemblyRegisterDocument(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory raw,
        bytes32 canonicalization
    ) internal returns (bytes32 documentHash) {
        bytes32[] memory chunks = _assemblyUpload(raw);
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name, kind, keccak256(raw), canonicalization, bytes32(0), "", uint32(raw.length)
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            assemblySchemas.registrationTransition(spec, chunks);
        _assemblyGovernanceCall(
            1,
            address(assemblySchemas),
            abi.encodeCall(assemblySchemas.registerDocument, (spec, chunks)),
            scope,
            oldHash,
            newHash
        );
        return keccak256(bytes(name));
    }

    function _assemblyUpload(bytes memory raw) internal returns (bytes32[] memory chunks) {
        require(raw.length != 0, "nonempty retained document");
        chunks = new bytes32[]((raw.length + 8191) / 8192);
        for (uint256 i; i < chunks.length; ++i) {
            uint256 length = raw.length - i * 8192;
            if (length > 8192) length = 8192;
            bytes memory part = _publicationSlice(raw, i * 8192, length);
            address pointer;
            (chunks[i], pointer) = assemblyStore.publishChunk(part);
            require(
                chunks[i] == keccak256(part) && pointer.code.length == length + 1,
                "exact retained original chunk"
            );
        }
    }

    function _assemblyGrantFamily(bytes32 family, uint8 authorizationClass, address actor)
        internal
    {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = assemblyMetadata.familyWriterTransition(
            1, family, authorizationClass, actor, true
        );
        _assemblyGovernanceCall(
            1,
            address(assemblyMetadata),
            abi.encodeCall(
                assemblyMetadata.setFamilyWriter, (1, family, authorizationClass, actor, true)
            ),
            scope,
            oldHash,
            newHash
        );
    }

    function _assemblyScope() internal pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, bytes32(0));
    }

    function _assemblyEnsureRawDefinition() internal {
        if (!assemblySchemas.document(assemblySchemas.RAW_BYTES()).exists) {
            _assemblyRegisterDocument(
                "RAW_BYTES",
                IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
                bytes(assemblySchemas.RAW_BYTES_DEFINITION()),
                assemblySchemas.RAW_BYTES()
            );
        }
    }

    function _constructOriginalRenderer() internal {
        configuration.rendering.core = address(core);
        configuration.rendering.executor = address(executor);
        configuration.rendering.router = address(router);
        configuration.rendering.metadata = address(assemblyMetadata);
        configuration.rendering.schemas = address(assemblySchemas);
        configuration.rendering.entropy = address(entropy);
        configuration.rendering.artist = address(artists);
        configuration.rendering.finality = address(assemblyFinality);
        configuration.rendering.deploymentHash = DEPLOYMENT_HASH;
        configuration.rendering.registryManifestURI = "urn:fixture:original-renderer-registry";
        configuration.rendering.registryManifestHash =
            keccak256("fixture renderer registry manifest");
        configuration.rendering.rendererManifest = Render.RendererManifest(
            keccak256("6529STREAM_RENDERER_V1"),
            keccak256("6529STREAM_STATIC_RENDERER_V1"),
            keccak256("STREAM_CONTEXT_V1"),
            keccak256("STATIC"),
            keccak256(_schema()),
            "urn:fixture:renderer-output-schema",
            "urn:fixture:renderer-manifest",
            keccak256(_manifestDocument()),
            16777216,
            16777216,
            false
        );
        configuration.rendering.readGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 2000000, 100000, 2
        );
        configuration.rendering.attributionGas = IStreamGasParameterHost.GasParameterConfig(
            "STATIC_ATTRIBUTION_GAS", 8000000, 8000000, 1
        );
        configuration.rendering.goldenGas = IStreamGasParameterHost.GasParameterConfig(
            "RENDERER_GOLDEN_VECTOR_GAS", 20000000, 100000, 2
        );
        products.rendering = StreamFullV1StaticRendererPlan.deployRenderer(configuration.rendering);
        // Genuine projection products exist before the Registry freezes its target set.
        _requirePreservationInitcode(
            type(StreamPreservationAttributionCompanion).creationCode,
            abi.encode(
                address(products.rendering.attribution),
                address(products.rendering.attribution),
                address(executor)
            )
        );
        assemblyPreservationAttribution = new StreamPreservationAttributionCompanion(
            address(products.rendering.attribution),
            address(products.rendering.attribution),
            address(executor)
        );
        _requirePreservationRuntime(address(assemblyPreservationAttribution));
        _requirePreservationInitcode(
            type(StreamPreservationRendererV1).creationCode,
            abi.encode(
                address(products.rendering.renderer),
                address(assemblyPreservationAttribution),
                address(executor),
                configuration.rendering.readGas,
                configuration.rendering.attributionGas
            )
        );
        assemblyPreservationRenderer = new StreamPreservationRendererV1(
            address(products.rendering.renderer),
            address(assemblyPreservationAttribution),
            address(executor),
            configuration.rendering.readGas,
            configuration.rendering.attributionGas
        );
        _requirePreservationRuntime(address(assemblyPreservationRenderer));
        products.rendering = StreamFullV1StaticRendererPlan.deployRegistry(
            configuration.rendering, products.rendering, _assemblyRendererTargets()
        );
        versionKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_RENDERER_VERSION_V1"),
                configuration.rendering.rendererManifest.rendererId,
                configuration.rendering.rendererManifest.rendererVersion
            )
        );
        _directReads();
    }

    function _directReads() internal {
        Versions.Target[] memory targets = _assemblyRendererTargets();
        for (uint16 i; i < targets.length; ++i) {
            address target = targets[i].target;
            // Preserve the original version's six-target direct-read subset.
            if (
                target == address(assemblyPreservationRenderer)
                    || target == address(assemblyPreservationAttribution)
            ) continue;
            if (target == address(core)) {
                declaredReads.push(
                    Versions.Read(i, IStreamCoreMint.tokenData.selector, 16448, false)
                );
            } else if (target == address(assemblyMetadata)) {
                declaredReads.push(Versions.Read(i, StaticSource.staticBundle.selector, 384, true));
                declaredReads.push(
                    Versions.Read(i, StaticSource.staticBundleChunk.selector, 128, true)
                );
                declaredReads.push(
                    Versions.Read(i, StaticSource.staticScriptManifest.selector, 9504, false)
                );
            } else if (target == address(router)) {
                declaredReads.push(
                    Versions.Read(
                        i, StaticRouter.staticRenderSourceForConfig.selector, 20736, false
                    )
                );
            } else if (target == address(entropy)) {
                declaredReads.push(
                    Versions.Read(
                        i, IStreamStaticEntropySource.staticTokenRenderFacts.selector, 96, true
                    )
                );
            } else if (target == address(products.rendering.attribution)) {
                declaredReads.push(
                    Versions.Read(
                        i, products.rendering.attribution.attribution.selector, 32832, false
                    )
                );
            } else {
                declaredReads.push(
                    Versions.Read(i, StreamStaticRenderEncoding.render.selector, 16777216, false)
                );
            }
        }
        for (uint256 i = 1; i < declaredReads.length; ++i) {
            for (
                uint256 j = i;
                j > 0 && _readOrder(declaredReads[j - 1]) > _readOrder(declaredReads[j]);
                --j
            ) {
                Versions.Read memory previous = declaredReads[j - 1];
                declaredReads[j - 1] = declaredReads[j];
                declaredReads[j] = previous;
            }
        }
    }

    function _readOrder(Versions.Read memory read) internal pure returns (uint256) {
        return (uint256(read.targetIndex) << 32) | uint32(read.selector);
    }

    function _fixtureDocuments() internal {
        if (!assemblySchemas.document(assemblySchemas.RAW_BYTES()).exists) {
            _document(
                "RAW_BYTES",
                Schema.DocumentKind.CANONICALIZATION,
                bytes(assemblySchemas.RAW_BYTES_DEFINITION())
            );
        }
        registration.renderer = address(products.rendering.renderer);
        registration.manifest = configuration.rendering.rendererManifest;
        registration.schemaDocument =
            _document("GENESIS_RENDERER_SCHEMA_FIXTURE_V1", Schema.DocumentKind.SCHEMA, _schema());
        registration.contextDocument = _document(
            "STREAM_CONTEXT_V1",
            Schema.DocumentKind.SCHEMA,
            bytes("{\"fixture\":true,\"name\":\"STREAM_CONTEXT_V1\"}")
        );
        registration.manifestDocument = _document(
            "GENESIS_RENDERER_MANIFEST_FIXTURE_V1", Schema.DocumentKind.CATALOG, _manifestDocument()
        );
        Versions.Analysis memory analysis = Versions.Analysis(
            products.rendering.versions.ANALYSIS_PROFILE(),
            address(products.rendering.renderer),
            address(products.rendering.renderer).codehash,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_RENDERER_READ_SET_V1"),
                    products.rendering.versions.targetSetHash(),
                    declaredReads
                )
            ),
            registration.manifest.rendererVersion,
            registration.manifest.contextVersion,
            registration.manifest.schemaHash,
            keccak256("SYNTHETIC FIXTURE: no analysis tool executed"),
            keccak256("SYNTHETIC FIXTURE: partial direct reads, not a conformance report"),
            true
        );
        registration.analysisDocument = _document(
            "GENESIS_ANALYSIS_JOIN_FIXTURE_V1", Schema.DocumentKind.CATALOG, abi.encode(analysis)
        );
        Versions.GoldenVector[] memory vectors = new Versions.GoldenVector[](1);
        vectors[0].request.core = address(core);
        vectors[0].request.mode = Render.MetadataMode.ONCHAIN;
        vectors[0].outputHash =
            keccak256(bytes(products.rendering.renderer.tokenURI(vectors[0].request)));
        registration.goldenDocument = _document(
            "GENESIS_EMPTY_GOLDEN_FIXTURE_V1", Schema.DocumentKind.CATALOG, abi.encode(vectors)
        );
    }

    function _schema() internal pure returns (bytes memory) {
        return bytes(
            "{\"fixture\":true,\"type\":\"object\",\"purpose\":\"current renderer admission join\"}"
        );
    }

    function _manifestDocument() internal pure returns (bytes memory) {
        return bytes(
            "{\"fixture\":true,\"renderer\":\"6529STREAM_STATIC_RENDERER_V1\",\"reviewed\":false}"
        );
    }

    function _input() internal view returns (StaticRouter.ConfigInput memory) {
        return StaticRouter.ConfigInput(
            address(products.rendering.versions),
            versionKey,
            Render.MetadataConfig(
                Render.MetadataMode.ONCHAIN,
                address(products.rendering.renderer),
                "",
                "",
                Render.OffchainURIIdMode.TOKEN_ID,
                false
            )
        );
    }

    function _context() internal view returns (StreamFullV1ActivationPlan.Context memory) {
        return StreamFullV1ActivationPlan.Context(
            foundation, configuration, products, savedInventoryHash
        );
    }

    function _inputs()
        private
        pure
        returns (StreamFullV1ActivationPlan.RegistrationInputs memory r)
    {
        r.gateGas = 1000000;
        r.readGas = 1000000;
        r.commerceGas = 500000;
        r.providerGas = 1000000;
        r.fixedSale = StreamFullV1ActivationPlan.Manifest(
            keccak256("fixture fixed"), "urn:fixture:activation:fixed"
        );
        r.dutch = StreamFullV1ActivationPlan.Manifest(
            keccak256("fixture Dutch"), "urn:fixture:activation:dutch"
        );
        r.privateSale = StreamFullV1ActivationPlan.Manifest(
            keccak256("fixture private"), "urn:fixture:activation:private"
        );
        r.erc20 = StreamFullV1ActivationPlan.Manifest(
            keccak256("fixture ERC20"), "urn:fixture:activation:erc20"
        );
    }

    function _fullPolicyActivationPublication()
        internal
        returns (StreamFullV1ActivationPlan.Publication memory p)
    {
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        (p.payload, p.update.manifestHash) = StreamGenesisManifestPlan.writePayload(
            bytes("{\"fixture\":true,\"scope\":\"authored activation stage only\"}")
        );
        p.update.manifestURI = "urn:fixture:activation-stage";
        p.update.eventCatalogHash = current.discovery.eventCatalogHash;
        p.update.compatibilityMatrixHash = current.discovery.compatibilityMatrixHash;
        p.update.numericIdCatalogHash = current.discovery.numericIdCatalogHash;
        p.update.schemaCatalogHash = current.discovery.schemaCatalogHash;
        p.update.canonicalizationCatalogHash = current.discovery.canonicalizationCatalogHash;
        p.update.specBundleHash = current.discovery.specBundleHash;
        p.update.reconstructionClientHash = current.discovery.reconstructionClientHash;
    }

    function _registerFullPolicyProducts() internal {
        while (StreamFullV1ActivationPlan.pendingRegistrations(_context(), _inputs()).length != 0) {
            GenesisBatch memory batch = StreamFullV1ActivationPlan.registrationBatch(
                _context(), _inputs(), 7, _fullPolicyActivationPublication()
            );
            require(
                batch.calls[batch.calls.length - 1].target == address(manifest),
                "original manifest tail"
            );
            _assemblyGovernance(batch, "urn:fixture:full-policy:register37");
        }
    }

    function _fullPolicyMint(uint256 nonce) internal returns (uint256 tokenId) {
        vm.deal(address(this), 1 ether);
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a =
            IStreamFixedPriceSaleAdapter.SaleAuthorization({
                collectionId: 1,
                phaseId: PHASE,
                payer: address(this),
                recipient: BUYER,
                artist: artist,
                profileId: profile,
                expectedPrimaryPolicyHash: _nativePrimaryPolicyHash(),
                tokenDataHash: keccak256(TOKEN_DATA),
                mintCommitment: keccak256(abi.encode("full-policy", nonce)),
                mintPolicyHash: manager.phasePolicyHash(1, PHASE),
                price: 0.01 ether,
                nonce: keccak256(abi.encode("full-policy-sale", nonce)),
                deadline: uint64(block.timestamp + 1 days),
                signerEpoch: sale.signerEpoch()
            });
        bytes32 digest = sale.authorizationDigest(a);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        bytes memory platformSignature = abi.encodePacked(r, s, v);
        bytes memory artistSignature = _artistProof(digest);
        (tokenId,) = sale.buy{ value: a.price }(a, TOKEN_DATA, platformSignature, artistSignature);
        require(
            core.ownerOf(tokenId) == BUYER && core.coordinatorAtMint(tokenId) == address(entropy)
        );
        (, uint256 request) = entropy.requestEntropy(tokenId);
        provider.fulfill(request, keccak256(abi.encode("full-policy-entropy", nonce)));
        require(entropy.tokenEntropyStatus(tokenId) == StreamEntropyStatus.FINALIZED);
        assemblyPreservationTokens.push(tokenId);
    }

    function _fullPolicyIndex(StreamFinalityScope memory scope) internal returns (bytes32 plan) {
        assemblyTokens.scanCollectionTokens(scope.collectionId, 256);
        plan = assemblyCoordinators.beginInventory(scope);
        assemblyCoordinators.appendInventory(plan, 256);
        require(assemblyCoordinators.requireCompleteInventory(plan).complete);
    }

    function _collectionScope() internal pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
    }

    function _rootContext() internal view returns (RootGraph.Context memory) {
        return RootGraph.Context(
            address(assemblyProvider),
            address(core),
            address(assemblyMetadata),
            address(router),
            address(assemblySchemas),
            1,
            500000
        );
    }

    function _assemblyProviderName()
        internal
        pure
        override(StreamCurrentFinalityGraph, StreamCurrentFullPreservationPolicyGraph)
        returns (string memory)
    {
        return StreamCurrentFullPreservationPolicyGraph._assemblyProviderName();
    }

    function _assemblyProviderParents()
        internal
        pure
        override(StreamCurrentFinalityGraph, StreamCurrentFullPreservationPolicyGraph)
        returns (string[] memory)
    {
        return StreamCurrentFullPreservationPolicyGraph._assemblyProviderParents();
    }

    function _assemblyProviderCreation()
        internal
        view
        override(StreamCurrentFinalityGraph, StreamCurrentFullPreservationPolicyGraph)
        returns (bytes memory)
    {
        return StreamCurrentFullPreservationPolicyGraph._assemblyProviderCreation();
    }

    function _assemblyProviderArguments(StreamFinalityNativeProviderReads.Config memory c)
        internal
        view
        override(StreamCurrentFinalityGraph, StreamCurrentFullPreservationPolicyGraph)
        returns (bytes memory)
    {
        return StreamCurrentFullPreservationPolicyGraph._assemblyProviderArguments(c);
    }

    function _assemblyDiscoveryName()
        internal
        pure
        override(StreamCurrentFinalityGraph, StreamCurrentFullPreservationPolicyGraph)
        returns (string memory)
    {
        return StreamCurrentFullPreservationPolicyGraph._assemblyDiscoveryName();
    }

    function _assemblyDiscoveryCreation()
        internal
        view
        override(StreamCurrentFinalityGraph, StreamCurrentFullPreservationPolicyGraph)
        returns (bytes memory)
    {
        return StreamCurrentFullPreservationPolicyGraph._assemblyDiscoveryCreation();
    }

    function _assemblyDiscoveryArguments(StreamFinalityDiscoveryTypes.Configuration memory d)
        internal
        view
        override(StreamCurrentFinalityGraph, StreamCurrentFullPreservationPolicyGraph)
        returns (bytes memory)
    {
        return StreamCurrentFullPreservationPolicyGraph._assemblyDiscoveryArguments(d);
    }

    function _assemblyComponentSourceGas()
        internal
        pure
        override(StreamCurrentFinalityGraph, StreamCurrentFullPreservationPolicyGraph)
        returns (uint256)
    {
        return 40000000;
    }

    function _assemblyManifestSourceGas()
        internal
        pure
        override(StreamCurrentFinalityGraph, StreamCurrentFullPreservationPolicyGraph)
        returns (uint256)
    {
        return 48000000;
    }

    /// @dev Explicit construction/ceremony budgets, NOT acceptance under the 16,777,216
    /// transaction envelope. Strict nested reservation checks need composed measurement.
    function _assemblyRegistryComponentGas() internal pure virtual override returns (uint256) {
        return 56000000;
    }

    function _fullPolicyDiscoveryComponentGas() internal pure override returns (uint32) {
        return 44000000;
    }

    function _fullPolicyCollectionRecipe()
        internal
        view
        override
        returns (StreamPreservationPolicyPublicationGraphTypesV1.Recipe memory r)
    {
        r = StreamCurrentFullPreservationPolicyGraph._fullPolicyCollectionRecipe();
        r.inventory.sourceGas = 16000000;
        r.inventory.snapshotGas = 32000000;
        r.inventory.referenceGas = 40000000;
        r.checkpointGas[1].genesisValue = 16000000;
        r.outputGas.genesisValue = 20000000;
        r.snapshotGas[1].genesisValue = 24000000;
        r.referenceGas[1].genesisValue = 16000000;
        r.referenceGas[2].genesisValue = 28000000;
    }

    function _prepareAssemblyProviderCompanions()
        internal
        override(StreamCurrentFinalityGraph, StreamCurrentFullPreservationPolicyGraph)
    {
        StreamCurrentFullPreservationPolicyGraph._prepareAssemblyProviderCompanions();
    }

    function _preservationGraphCreation(PreservationCreation.Kind kind)
        internal
        pure
        override
        returns (bytes memory)
    {
        return NativePreservationCreation.creation(NativePreservationCreation.Kind(uint256(kind)));
    }

    function _requirePreservationInitcode(bytes memory creation, bytes memory arguments)
        private
        pure
    {
        require(
            creation.length != 0 && creation.length + arguments.length <= 49152,
            "actual preservation product initcode fits"
        );
    }

    function _requirePreservationRuntime(address product) private view {
        require(
            product.code.length != 0 && product.code.length <= 24576,
            "actual preservation product runtime fits"
        );
    }

    function _fullPolicyViewCheckpointServingGas() internal pure virtual returns (uint32) {
        return 9000000;
    }

    /// @dev Construct only after original selected Metadata/Router and the real Finality graph
    /// are active. Constructor checks validate bindings, not a nonexistent VIEW adoption.
    /// Declared cap ladder: snapshot outer 16m > manifest source 14m > checkpoint 12m >
    /// serving 9m > renderer 3m / attribution 4m. Each edge leaves more than the original
    /// strict child + child/63 + 10k transport reserve, including fixed worker hops.
    /// Repeated source/row work and returned-byte costs still require measured capacity.
    function _deployFullPolicyViewPreservation() private {
        require(address(assemblyViewPreservationRenderer) == address(0), "one genuine VIEW graph");
        ViewPreservationRenderer.Configuration memory serving =
            ViewPreservationRenderer.Configuration(
                address(core),
                address(core).codehash,
                address(router),
                address(router).codehash,
                address(assemblyPreservationAttribution),
                address(assemblyPreservationAttribution).codehash,
                block.chainid,
                3000000,
                4000000
            );
        _requirePreservationInitcode(
            type(StreamViewPreservationRendererV1).creationCode, abi.encode(serving)
        );
        assemblyViewPreservationRenderer = new StreamViewPreservationRendererV1(serving);
        _requirePreservationRuntime(address(assemblyViewPreservationRenderer));
        require(
            keccak256(abi.encode(assemblyViewPreservationRenderer.configuration()))
                == keccak256(abi.encode(serving)),
            "exact actual C producer"
        );
        ViewPreservationCheckpointTypes.Configuration memory checkpoint =
            ViewPreservationCheckpointTypes.Configuration(
                address(core),
                address(core).codehash,
                address(router),
                address(router).codehash,
                address(executor),
                address(executor).codehash,
                address(assemblyViewPreservationRenderer),
                address(assemblyViewPreservationRenderer).codehash,
                assemblyViewPreservationRenderer.configurationHash(),
                block.chainid,
                2000000,
                _fullPolicyViewCheckpointServingGas()
            );
        _requirePreservationInitcode(
            type(StreamViewPreservationContentCheckpointV1).creationCode, abi.encode(checkpoint)
        );
        assemblyViewPreservationCheckpoint =
            new StreamViewPreservationContentCheckpointV1(checkpoint);
        _requirePreservationRuntime(address(assemblyViewPreservationCheckpoint));
        require(
            keccak256(abi.encode(assemblyViewPreservationCheckpoint.configuration()))
                == keccak256(abi.encode(checkpoint)),
            "exact actual C checkpoint"
        );
        ViewPreservationManifestTypes.Configuration memory manifest_ =
            ViewPreservationManifestTypes.Configuration(
                address(core),
                address(core).codehash,
                address(assemblyViewPreservationCheckpoint),
                address(assemblyViewPreservationCheckpoint).codehash,
                assemblyViewPreservationCheckpoint.configurationHash(),
                address(assemblyArtifact),
                address(assemblyArtifact).codehash,
                address(assemblySchemas),
                address(assemblySchemas).codehash,
                block.chainid,
                2000000,
                12000000
            );
        _requirePreservationInitcode(
            type(StreamViewPreservationOutputManifestV1).creationCode, abi.encode(manifest_)
        );
        assemblyViewPreservationManifest = new StreamViewPreservationOutputManifestV1(manifest_);
        _requirePreservationRuntime(address(assemblyViewPreservationManifest));
        require(
            keccak256(abi.encode(assemblyViewPreservationManifest.configuration()))
                == keccak256(abi.encode(manifest_)),
            "exact actual C manifest"
        );
        _deployFullPolicyViewPreservationSnapshot();
    }

    function _deployFullPolicyViewPreservationSnapshot() private {
        ViewPreservationSnapshotTypes.Dependencies memory d;
        d.targets = [
            address(core),
            address(assemblyMetadata),
            address(assemblySchemas),
            address(assemblyStore),
            address(router),
            address(assemblyMembership),
            address(assemblyViewPreservationCheckpoint),
            address(assemblyViewPreservationManifest),
            address(assemblyArtifact),
            address(executor)
        ];
        for (uint256 i; i < d.targets.length; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 2000000;
        d.sourceGas = 14000000;
        d.inventoryGas = 4000000;
        IStreamGasParameterHost.GasParameterConfig[3] memory gas_ = [
            IStreamGasParameterHost.GasParameterConfig(
                "VIEW_PRESERVATION_SNAPSHOT_READ_GAS", d.readGas, 100000, 2
            ),
            IStreamGasParameterHost.GasParameterConfig(
                "VIEW_PRESERVATION_SNAPSHOT_SOURCE_GAS", d.sourceGas, 100000, 2
            ),
            IStreamGasParameterHost.GasParameterConfig(
                "VIEW_PRESERVATION_SNAPSHOT_INVENTORY_GAS", d.inventoryGas, 100000, 2
            )
        ];
        _requirePreservationInitcode(
            type(StreamViewPreservationSnapshotPublicationV1).creationCode,
            abi.encode(d, address(executor), gas_)
        );
        assemblyViewPreservationSnapshot =
            new StreamViewPreservationSnapshotPublicationV1(d, address(executor), gas_);
        _requirePreservationRuntime(address(assemblyViewPreservationSnapshot));
        require(
            keccak256(abi.encode(assemblyViewPreservationSnapshot.dependencies()))
                == keccak256(abi.encode(d)),
            "exact actual C root-free snapshot"
        );
    }

    /// @dev COLLECTION_VIEWS has no Core satellite pointer. Original admission is actual
    /// Registry eligibility; the provider's committed original Binding selects this host.
    /// Declaring a view still needs its original Metadata IDENTITY writer grant and an open
    /// collection. This root-free source setup supplies neither a declaration nor adoption.
    function _deployFullPolicyViewDeclarations() private {
        require(address(assemblyViewDeclarations) == address(0), "one genuine declaration host");
        StreamCollectionViews.Configuration memory c = StreamCollectionViews.Configuration(
            address(core),
            address(assemblyMetadata),
            address(executor),
            DEPLOYMENT_HASH,
            "urn:fixture:preservation:original-collection-views",
            keccak256("fixture original collection views for preservation"),
            IStreamGasParameterHost.GasParameterConfig(
                "METADATA_DEPENDENCY_READ_GAS", 2000000, 50000, 2
            )
        );
        _requirePreservationInitcode(type(StreamCollectionViews).creationCode, abi.encode(c));
        assemblyViewDeclarations = new StreamCollectionViews(c);
        _requirePreservationRuntime(address(assemblyViewDeclarations));
        uint256 beforeCount = assemblyModules.moduleCount();
        StreamModuleRegistration[] memory registrations = new StreamModuleRegistration[](1);
        registrations[0] = StreamModuleRegistration(
            address(assemblyViewDeclarations),
            assemblyViewDeclarations.streamModuleType(),
            assemblyViewDeclarations.streamModuleVersion(),
            type(CollectionViews).interfaceId,
            4000000,
            address(assemblyViewDeclarations).codehash,
            DEPLOYMENT_HASH,
            c.manifestHash,
            c.manifestURI
        );
        (GovernanceCall[] memory calls, bytes[] memory inputs) =
            StreamCurrentStackPlan.registrationCalls(assemblyModules, registrations);
        GovernanceCall memory call_ = calls[0];
        _assemblyGovernanceCall(
            1, call_.target, inputs[0], call_.scopeHash, call_.oldValueHash, call_.newValueHash
        );
        StreamModuleRecord memory registered =
            assemblyModules.moduleRecord(address(assemblyViewDeclarations));
        require(
            assemblyModules.moduleCount() == beforeCount + 1
                && assemblyModules.moduleAt(beforeCount) == address(assemblyViewDeclarations)
                && assemblyModules.isModuleEligible(
                    address(assemblyViewDeclarations),
                    keccak256("COLLECTION_VIEWS"),
                    type(CollectionViews).interfaceId
                ) && registered.status == ModuleRegistryStatus.ACTIVE && registered.revision == 1
                && registered.runtimeCodeHash == address(assemblyViewDeclarations).codehash
                && registered.moduleManifestHash == c.manifestHash
                && registered.deploymentManifestHash == DEPLOYMENT_HASH,
            "actual post-activation declaration module registration"
        );
        require(
            assemblyViewDeclarations.core() == address(core)
                && assemblyViewDeclarations.metadataHost() == address(assemblyMetadata)
                && assemblyViewDeclarations.schemaRegistry() == address(assemblySchemas)
                && assemblyViewDeclarations.chunkStore() == address(assemblyStore),
            "original declaration host reciprocal sources"
        );
        (bytes32 schema, bytes32 hash, bytes memory definition) =
            assemblyViewDeclarations.viewSchema();
        require(
            schema == keccak256("STREAM_COLLECTION_VIEW_MANIFEST_ABI_V1")
                && hash == keccak256(definition),
            "original declaration schema bytes"
        );
        bytes32 saved = _assemblyRegisterDocument(
            "STREAM_COLLECTION_VIEW_MANIFEST_ABI_V1",
            Schema.DocumentKind.SCHEMA,
            definition,
            assemblySchemas.RAW_BYTES()
        );
        require(
            saved == schema && assemblySchemas.document(saved).specification.contentHash == hash,
            "actual original declaration schema admission"
        );
    }

    function _constructAndBindFullPolicyViewPreservation() private {
        FullPolicyCompanionState memory original = _fullPolicyCompanionState();
        ViewPreservationBinding binding_ = ViewPreservationBinding(address(assemblyProvider));
        require(binding_.viewPreservationBindingStatus() == 0, "original provider VIEW pending");
        (bool ready, bytes memory failure) = address(assemblyProvider)
            .staticcall(abi.encodeCall(ViewPreservationEvidence.viewPreservationSnapshotHost, ()));
        require(
            !ready
                && keccak256(failure)
                    == keccak256(
                        abi.encodeWithSelector(
                            ViewPreservationBindingTypes.ViewPreservationPending.selector
                        )
                    ),
            "pending VIEW getter fails closed"
        );
        _deployFullPolicyViewDeclarations();
        _deployFullPolicyViewPreservation();
        ViewAdoption.Binding memory declaration = ViewAdoption.Binding(
            address(assemblyViewDeclarations),
            address(assemblyViewDeclarations).codehash,
            address(assemblyMembership),
            address(assemblyMembership).codehash,
            2000000,
            4000000
        );
        ViewPreservationBindingTypes.Configuration memory c =
            ViewPreservationBindingTypes.Configuration(
                address(assemblyViewPreservationSnapshot),
                address(assemblyViewPreservationSnapshot).codehash,
                16000000,
                address(assemblyViewPreservationCheckpoint),
                address(assemblyViewPreservationCheckpoint).codehash,
                address(assemblyViewPreservationManifest),
                address(assemblyViewPreservationManifest).codehash
            );
        ViewPreservationBindingTypes.Capability memory capability =
            binding_.viewPreservationBindingCapability();
        require(
            capability.authority == address(assemblyExecutor)
                && capability.authorityCodeHash == address(assemblyExecutor).codehash
                && capability.capabilityHash
                    == ViewPreservationBindingTypes.hashCapability(
                        block.chainid, address(assemblyProvider), capability
                    ),
            "actual fixed original authority capability"
        );
        bytes32 action = _executeFullPolicyViewBinding(c, declaration);
        ViewPreservationBindingTypes.Receipt memory receipt =
            binding_.viewPreservationBindingReceipt();
        require(
            binding_.viewPreservationBindingStatus() == 1 && receipt.recordHash != 0
                && receipt.recordHash == ViewPreservationBindingTypes.receiptHash(receipt)
                && receipt.actionId == action && receipt.boundAt == block.timestamp
                && receipt.capabilityHash == capability.capabilityHash
                && receipt.dependenciesHash == keccak256(abi.encode(receipt.dependencies))
                && receipt.workersHash != 0
                && keccak256(abi.encode(receipt.configuration)) == keccak256(abi.encode(c))
                && keccak256(abi.encode(receipt.declaration)) == keccak256(abi.encode(declaration))
                && keccak256(abi.encode(receipt.dependencies))
                    == keccak256(abi.encode(assemblyViewPreservationSnapshot.dependencies())),
            "exact one-time class2 VIEW receipt and complete dependencies"
        );
        ViewPreservationEvidence evidence = ViewPreservationEvidence(address(assemblyProvider));
        require(
            evidence.viewPreservationSnapshotHost() == c.snapshotHost
                && evidence.viewPreservationSnapshotCodeHash() == c.snapshotCodeHash
                && evidence.viewPreservationSnapshotValidationGas() == c.validationGas,
            "actual bound C getter tuple"
        );
        assemblyViewPreservationBindingReceiptHash = receipt.recordHash;
        require(
            keccak256(abi.encode(ViewSource(address(assemblyProvider)).viewSourceBinding()))
                == keccak256(abi.encode(declaration)),
            "same provider exact original VIEW source capability"
        );
        _requireFullPolicyCompanionsUnchanged(original);
    }

    /// @dev A complete VIEW fixture can construct all fixed children before its single bind.
    /// The default retains the exact original basic proposal and class2 action readback.
    function _executeFullPolicyViewBinding(
        ViewPreservationBindingTypes.Configuration memory c,
        ViewAdoption.Binding memory declaration
    ) internal virtual returns (bytes32 action) {
        ViewPreservationBinding binding_ = ViewPreservationBinding(address(assemblyProvider));
        ViewPreservationBindingTypes.Transition memory transition_ =
            binding_.viewPreservationBindingTransition(c, declaration);
        action = _assemblyGovernanceCall(
            2,
            address(binding_),
            abi.encodeCall(ViewPreservationBinding.bindViewPreservation, (c, declaration)),
            transition_.scopeHash,
            transition_.oldValueHash,
            transition_.newValueHash
        );
        require(
            keccak256(abi.encode(transition_))
                == keccak256(
                    abi.encode(
                        ViewPreservationBindingTypes.transition(
                            block.chainid,
                            address(assemblyProvider),
                            binding_.viewPreservationBindingReceipt()
                        )
                    )
                ),
            "executed original scheduled proposal"
        );
    }

    /// @dev Both extra roles name actual independent products in the immutable Registry roster.
    function _assemblyRendererTargets() internal view returns (Versions.Target[] memory targets) {
        Versions.Target[] memory original = _targets();
        targets = new Versions.Target[](original.length + 2);
        for (uint256 i; i < original.length; ++i) {
            targets[i] = original[i];
        }
        targets[original.length] = Versions.Target(
            address(assemblyPreservationRenderer),
            address(assemblyPreservationRenderer).codehash,
            keccak256("PRESERVATION_RENDERER")
        );
        targets[original.length + 1] = Versions.Target(
            address(assemblyPreservationAttribution),
            address(assemblyPreservationAttribution).codehash,
            keccak256("PRESERVATION_ATTRIBUTION")
        );
        for (uint256 i = 1; i < targets.length; ++i) {
            for (uint256 j = i; j > 0 && targets[j - 1].target > targets[j].target; --j) {
                (targets[j - 1], targets[j]) = (targets[j], targets[j - 1]);
            }
        }
    }

    /// @dev Requires real mint/freeze and original current-citation admission. Analysis remains
    /// an explicitly synthetic fixture document. Governance, producers and golden execution
    /// are actual; computed vectors do not constitute independent opcode/conformance review.
    function _admitFullPolicyPreservation() internal {
        require(
            assemblyPreservationKey == 0 && assemblyPreservationTokens.length == 2,
            "fresh actual preservation admission"
        );
        PreservationRegistry registry_ = PreservationRegistry(address(products.rendering.versions));
        Versions.Read[] memory reads_ = _assemblyPreservationReads();
        PreservationRegistry.PreservationRegistration memory r =
            _preservationRegistrationInput(reads_);
        bytes32 originalVersion =
            keccak256(abi.encode(products.rendering.versions.version(versionKey)));
        bytes32 originalCitation =
            keccak256(abi.encode(products.rendering.versions.currentCitationRecord(versionKey)));
        (bytes32 scope, bytes32 previous, bytes32 next) =
            registry_.preservationTransition(r, reads_);
        _assemblyGovernanceCall(
            1,
            address(registry_),
            abi.encodeCall(PreservationRegistry.registerPreservation, (r, reads_)),
            scope,
            previous,
            next
        );
        assemblyPreservationKey = registry_.preservationKey(
            versionKey, address(assemblyPreservationRenderer), r.binding.profile
        );
        assemblyPreservationRegistration = registry_.preservationRecord(assemblyPreservationKey);
        _assertPreservationAdmission(r, reads_);
        require(
            keccak256(abi.encode(products.rendering.versions.version(versionKey)))
                    == originalVersion
                && keccak256(
                    abi.encode(products.rendering.versions.currentCitationRecord(versionKey))
                ) == originalCitation,
            "original live version and citation unchanged"
        );
    }

    function _preservationRegistrationInput(Versions.Read[] memory reads_)
        private
        returns (PreservationRegistry.PreservationRegistration memory r)
    {
        r.versionKey = versionKey;
        r.binding = PreservationRegistry.ProducerBinding(
            address(assemblyPreservationRenderer),
            address(assemblyPreservationRenderer).codehash,
            keccak256("6529STREAM_PRESERVATION_RENDER_V1"),
            address(core),
            address(router),
            address(products.rendering.renderer),
            address(products.rendering.renderer).codehash,
            address(assemblyPreservationAttribution),
            address(assemblyPreservationAttribution).codehash
        );
        bytes memory schema = bytes(
            "{\"fixture\":true,\"profile\":\"6529STREAM_PRESERVATION_RENDER_V1\",\"output\":\"complete original MARKETPLACE JSON and HTML; sanction-only attribution fields excluded\"}"
        );
        r.schemaDocument =
            _document("FULL_PRESERVATION_SCHEMA_FIXTURE_V1", Schema.DocumentKind.SCHEMA, schema);
        PreservationRegistry.PreservationAnalysis memory analysis =
            PreservationRegistry.PreservationAnalysis(
                keccak256("6529STREAM_PRESERVATION_ANALYSIS_ABI_V1"),
                r.binding,
                products.rendering.versions.version(versionKey).registrationHash,
                keccak256(schema),
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_RENDERER_READ_SET_V1"),
                        products.rendering.versions.targetSetHash(),
                        reads_
                    )
                ),
                keccak256("SYNTHETIC FIXTURE: no preservation opcode analysis executed"),
                keccak256(
                    "SYNTHETIC FIXTURE: original finite direct roster plus fixed preservation producers; not complete transitive analysis"
                ),
                true
            );
        r.analysisDocument = _document(
            "FULL_PRESERVATION_ANALYSIS_FIXTURE_V1",
            Schema.DocumentKind.CATALOG,
            abi.encode(analysis)
        );
        PreservationRegistry.PreservationGoldenVector[] memory vectors =
            new PreservationRegistry.PreservationGoldenVector[](4);
        for (uint256 i; i < 2; ++i) {
            uint256 token = assemblyPreservationTokens[i];
            string memory json = assemblyPreservationRenderer.preservationTokenJSON(token);
            string memory html = assemblyPreservationRenderer.preservationTokenHTML(token);
            require(
                bytes(json).length != 0 && bytes(html).length != 0,
                "genuine complete preservation output"
            );
            vectors[2 * i] = PreservationRegistry.PreservationGoldenVector(
                _collectionScope(), token, 0, 2, keccak256(bytes(json))
            );
            vectors[2 * i + 1] = PreservationRegistry.PreservationGoldenVector(
                _collectionScope(), token, 0, 3, keccak256(bytes(html))
            );
        }
        r.goldenDocument = _document(
            "FULL_PRESERVATION_TWO_TOKEN_GOLDEN_FIXTURE_V1",
            Schema.DocumentKind.CATALOG,
            abi.encode(vectors)
        );
    }

    function _assertPreservationAdmission(
        PreservationRegistry.PreservationRegistration memory r,
        Versions.Read[] memory reads_
    ) private view {
        PreservationRegistry registry_ = PreservationRegistry(address(products.rendering.versions));
        PreservationRegistry.PreservationRecord memory saved = assemblyPreservationRegistration;
        require(
            saved.registrationHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRESERVATION_REGISTRATION_V1"),
                        block.chainid,
                        address(registry_),
                        address(assemblySchemas),
                        address(assemblySchemas).codehash,
                        products.rendering.versions.targetSetHash(),
                        products.rendering.versions.version(versionKey).registrationHash,
                        r,
                        reads_
                    )
                ),
            "literal original preservation declaration"
        );
        require(
            keccak256(abi.encode(saved.registration)) == keccak256(abi.encode(r))
                && saved.readSetHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_RENDERER_READ_SET_V1"),
                            products.rendering.versions.targetSetHash(),
                            reads_
                        )
                    )
                && saved.analysisHash
                    == keccak256(assemblySchemas.documentBytes(r.analysisDocument))
                && saved.goldenHash == keccak256(assemblySchemas.documentBytes(r.goldenDocument))
                && saved.actionId != 0,
            "exact governed preservation evidence"
        );
        require(
            keccak256(abi.encode(registry_.preservationReads(assemblyPreservationKey)))
                == keccak256(abi.encode(reads_)),
            "complete original plus preservation reads retained"
        );
        (
            PreservationRegistry.ProducerBinding memory binding_,
            PreservationRegistry.Admission memory admission_
        ) = registry_.requirePreservation(
            versionKey, address(assemblyPreservationRenderer), r.binding.profile
        );
        require(
            keccak256(abi.encode(binding_)) == keccak256(abi.encode(r.binding))
                && keccak256(abi.encode(admission_))
                    == keccak256(
                        abi.encode(
                            PreservationRegistry.Admission(
                                address(registry_),
                                address(registry_).codehash,
                                versionKey,
                                saved.registrationHash,
                                saved.readSetHash,
                                saved.analysisHash,
                                saved.goldenHash
                            )
                        )
                    ),
            "exact producer and admission tuple"
        );
    }

    function _assemblyPreservationReads() internal view returns (Versions.Read[] memory reads_) {
        // The actual current-citation declaration is a superset of all original version reads.
        Versions.Read[] memory current =
            products.rendering.versions.currentCitationReads(versionKey);
        reads_ = new Versions.Read[](current.length + 5);
        for (uint256 i; i < current.length; ++i) {
            reads_[i] = current[i];
        }
        Versions.Target[] memory targets = _assemblyRendererTargets();
        uint256 next = current.length;
        for (uint16 i; i < targets.length; ++i) {
            if (targets[i].target == address(assemblyPreservationRenderer)) {
                reads_[next++] =
                    Versions.Read(i, PreservationRenderer.preservationProfile.selector, 32, true);
                reads_[next++] =
                    Versions.Read(i, PreservationRenderer.preservationBinding.selector, 192, true);
                reads_[next++] = Versions.Read(
                    i, PreservationRenderer.preservationTokenJSON.selector, 16777216, false
                );
                reads_[next++] = Versions.Read(
                    i, PreservationRenderer.preservationTokenHTML.selector, 16777216, false
                );
            } else if (targets[i].target == address(assemblyPreservationAttribution)) {
                reads_[next++] = Versions.Read(
                    i, PreservationAttribution.preservationAttribution.selector, 32832, false
                );
            }
        }
        require(current.length != 0 && next == reads_.length, "both immutable preservation targets");
        for (uint256 i = 1; i < reads_.length; ++i) {
            for (uint256 j = i; j > 0 && _readOrder(reads_[j - 1]) > _readOrder(reads_[j]); --j) {
                (reads_[j - 1], reads_[j]) = (reads_[j], reads_[j - 1]);
            }
        }
    }
}
