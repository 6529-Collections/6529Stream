// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamCurrentAuthorityInventoryTypes as CurrentInventoryTypes
} from "../../interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamCurrentAuthorityConfiguration as AuthorityConfiguration
} from "./StreamCurrentAuthorityConfiguration.sol";
import {
    IStreamCurrentAuthorityInventory as AuthorityInventory
} from "../../interfaces/stream/preservation/IStreamCurrentAuthorityInventory.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import {
    StreamFinalityScopedPreservationPolicyProviderReadsV1 as Original
} from "./StreamFinalityScopedPreservationPolicyProviderReadsV1.sol";
import "./StreamFinalityBoundedReads.sol";
import "./StreamFinalityScopedPreservationPolicyInputManifestReadsV1.sol";
import "./StreamFinalityHashes.sol";
import "../metadata/StreamMetadataSubjects.sol";
import "../../interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import "../../interfaces/stream/finality/IStreamCoreFinalityAdapter.sol";
import "../../interfaces/stream/finality/IStreamCoreFinalitySource.sol";
import {
    IStreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1
} from "../../interfaces/stream/preservation/IStreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1.sol";
import {
    IStreamScopedPreservationPolicyBundleArchiveCoverageV1
} from "../../interfaces/stream/preservation/IStreamScopedPreservationPolicyBundleArchiveCoverageV1.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1
} from "../../interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    IStreamScopedContentRootPublication
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPreservationPolicyReferencePublicationV1
} from "../../interfaces/stream/preservation/IStreamScopedPreservationPolicyReferencePublicationV1.sol";
import "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamReferenceRenderTypes
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";

import {
    StreamFinalityScopedPreservationPolicyProviderMetadataV1 as Metadata
} from "./StreamFinalityScopedPreservationPolicyProviderMetadataV1.sol";
import {
    StreamFinalityScopedPreservationPolicySnapshotReadsV1 as Snapshots
} from "./StreamFinalityScopedPreservationPolicySnapshotReadsV1.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as Checkpoint
} from "../../interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as Outputs
} from "../../interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import {
    IStreamFinalityScopedEntropyPolicySourceFactoryV2 as Factory
} from "../../interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as SourceSet
} from "../../interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as Policies
} from "./StreamFinalityCoordinatorPolicyReadsV2.sol";
import {
    StreamScopedPreservationPolicyBundleArchiveTypesV1 as Bundle
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyBundleArchiveTypesV1.sol";
import {
    StreamBundleArchiveTypes as Archive
} from "../../interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamPreservationPolicyOutputSchemasV2 as OutputSchemas
} from "./StreamPreservationPolicyOutputSchemasV2.sol";

/// @notice Distinct TOKEN/RELEASE/SEASON inputs from the complete authenticated scoped inventory.
/// @dev Inventory is a semantic producer, not a caller-supplied list. Its exact constructor
/// configuration is pinned as well as runtime. Original headers only project already-validated
/// current records; component-state validation independently proves terminal locks and entropy.
library StreamCurrentAuthorityScopedPreservationPolicyProviderReadsV1 {
    error NativeProviderConfiguration();
    error NativeProviderDependency(address target);
    error NativeProviderScope();
    error NativeProviderSource();
    error NativeProviderComponent(uint256 index);
    error NativeProviderTerminal();

    function requirePins(Original.Config memory c) public view {
        if (
            c.chainId != block.chainid || c.readGas < 50000 || c.componentSourceGas < c.readGas
                || c.componentSourceGas > type(uint32).max
                || c.sourceGas <= c.componentSourceGas + c.componentSourceGas / 63 + 100000
                || c.inventoryDependencyHash == 0
        ) revert NativeProviderConfiguration();
        for (uint256 i; i < 22; ++i) {
            if (c.targets[i].code.length == 0 || c.targets[i].codehash != c.codeHashes[i]) {
                revert NativeProviderDependency(c.targets[i]);
            }
        }
        _profile(
            c,
            6,
            type(Outputs).interfaceId,
            "outputProfile()",
            keccak256("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2")
        );
        _profile(
            c,
            7,
            type(Checkpoint).interfaceId,
            "preservationPolicyProfile()",
            keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_CHECKPOINT_V2")
        );
        _profile(
            c,
            8,
            type(IStreamScopedPreservationPolicySnapshotPublicationV1).interfaceId,
            "scopedPreservationPolicySnapshotProfile()",
            keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2")
        );
        _profile(
            c,
            9,
            type(IStreamScopedPreservationPolicyReferencePublicationV1).interfaceId,
            "scopedPreservationPolicyReferenceProfile()",
            keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_V2")
        );
        _profile(
            c,
            10,
            type(Factory).interfaceId,
            "scopedPolicyFactoryProfile()",
            keccak256("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2")
        );
        _profile(
            c,
            18,
            type(IStreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1)
            .interfaceId,
            "scopedPreservationPolicyInventoryProfile()",
            CurrentInventoryTypes.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE
        );
        if (
            _word(c, 18, abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)))
                    != bytes32(uint256(1))
                || _word(
                        c,
                        18,
                        abi.encodeCall(
                            IERC165.supportsInterface, (type(AuthorityInventory).interfaceId)
                        )
                    ) != bytes32(uint256(1))
                || _word(c, 18, abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))))
                    != 0
        ) revert NativeProviderDependency(c.targets[18]);
        _address(c, 6, "core()", 0);
        _address(c, 6, "contentCheckpoint()", 7);
        _address(c, 6, "artifactCoverage()", 20);
        _address(c, 7, "core()", 0);
        _address(c, 7, "metadataRouter()", 2);
        _address(c, 7, "sourceFactory()", 10);
        _address(c, 18, "core()", 0);
        _address(c, 18, "metadataHost()", 1);
        _address(c, 18, "metadataRouter()", 2);
        _address(c, 18, "snapshots()", 8);
        _address(c, 18, "referencePublisher()", 9);
        _address(c, 18, "artifactCoverage()", 20);
        _address(c, 18, "externalCoverage()", 21);
        if (_word(c, 18, abi.encodeWithSignature("dependencyHash()")) != c.inventoryDependencyHash)
        {
            revert NativeProviderDependency(c.targets[18]);
        }
        _inventoryConfiguration(c);
        _snapshotConfiguration(c);
        _referenceConfiguration(c);
        _address(c, 19, "core()", 0);
        _address(c, 19, "metadataHost()", 1);
        _address(c, 19, "renderCriticalInventory()", 18);
        _address(c, 19, "artifactCoverage()", 20);
        _address(c, 19, "externalCoverage()", 21);
        _address(c, 14, "core()", 0);
        _address(c, 14, "collectionMetadata()", 1);
        _address(c, 12, "coreReads()", 0);
        _address(c, 12, "metadataReads()", 1);
        _address(c, 12, "coreFinalityAdapter()", 14);
        _address(c, 13, "core()", 0);
        _address(c, 13, "metadataHost()", 1);
        _self(c, 12, "scopeEvidenceProvider()");
        _self(c, 13, "scopeEvidenceProvider()");
        _self(c, 14, "evidenceProvider()");
    }

    function statement(
        Original.Config memory c,
        StreamFinalityScope memory scope,
        StreamFinalityComponentExpectation[] memory components
    )
        public
        view
        returns (StreamFinalityScopedPreservationPolicyInputManifestTypesV1.Statement memory s)
    {
        requirePins(c);
        if (
            scope.collectionId == 0
                || (scope.scopeType != StreamFinalityScopeType.TOKEN
                    && scope.scopeType != StreamFinalityScopeType.RELEASE
                    && scope.scopeType != StreamFinalityScopeType.SEASON)
        ) revert NativeProviderScope();
        s.scope = scope;
        s.nonSanctionComponents = components;
        s.entropyPolicy = 1;
        s.postFreezePolicy = 1;
        s.sanctionPolicy = 1;
        bytes memory raw = _read(
            c,
            18,
            abi.encodeCall(
                IStreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1.requireCurrent,
                (scope)
            ),
            736,
            c.sourceGas
        );
        StreamScopedPreservationPolicyRenderCriticalTypesV1.Evidence memory scoped =
            abi.decode(raw, (StreamScopedPreservationPolicyRenderCriticalTypesV1.Evidence));
        StreamPreservationInventoryTypes.Evidence memory e = scoped.inventory;
        if (
            keccak256(raw) != keccak256(abi.encode(scoped))
                || keccak256(abi.encode(scoped.scope)) != keccak256(abi.encode(scope))
                || e.planId == 0 || e.collectionId != scope.collectionId
                || e.scopeSubject
                    != StreamMetadataSubjects.scopeSubject(c.chainId, c.targets[0], scope)
                || e.artistId == 0 || e.sourceContextHash == 0 || e.tokenInventoryHash == 0
                || e.tokenCount == 0 || e.segmentCount == 0 || e.itemCount == 0
                || e.segmentChainHash == 0 || e.renderCriticalEvidenceHash == 0
        ) {
            revert NativeProviderSource();
        }
        _coverage(c, e, s);
        _headers(c, e, s);
        _core(c, s);
    }

    function currentComponents(Original.Config memory c, StreamFinalityScope memory scope)
        public
        view
        returns (StreamFinalityComponentExpectation[] memory result)
    {
        bytes memory raw = _read(
            c,
            13,
            abi.encodeCall(
                IStreamFinalityCurrentComponentRoutes.requireCurrentRoutes, (scope, false)
            ),
            1216,
            c.sourceGas
        );
        StreamFinalityCurrentComponentRoute[] memory routes =
            abi.decode(raw, (StreamFinalityCurrentComponentRoute[]));
        if (routes.length != 9 || keccak256(raw) != keccak256(abi.encode(routes))) {
            revert NativeProviderSource();
        }
        result = new StreamFinalityComponentExpectation[](9);
        for (uint256 i; i < 9; ++i) {
            StreamFinalityCurrentComponentRoute memory route = routes[i];
            if (
                route.component.code.length == 0 || route.component.codehash != route.codeHash
                    || (i != 0 && routes[i - 1].componentType >= route.componentType)
            ) revert NativeProviderComponent(i);
            raw = StreamFinalityBoundedReads.read(
                route.component,
                abi.encodeCall(
                    IStreamArtworkScopedFinalityComponent.finalityStateForScope, (scope)
                ),
                256,
                c.sourceGas
            );
            StreamFinalityComponentState memory state =
                abi.decode(raw, (StreamFinalityComponentState));
            if (
                !state.frozen || state.componentType != route.componentType
                    || state.component != route.component || state.interfaceId != route.interfaceId
                    || state.codeHash != route.codeHash || state.moduleVersion == 0
                    || state.manifestHash == 0 || state.dataHash == 0
                    || keccak256(raw) != keccak256(abi.encode(state))
            ) revert NativeProviderComponent(i);
            result[i] = StreamFinalityComponentExpectation(
                route.componentType,
                route.component,
                route.interfaceId,
                route.codeHash,
                state.moduleVersion,
                state.manifestHash,
                state.dataHash
            );
        }
    }

    function independentComponents(StreamFinalityComponentExpectation[] calldata rows)
        public
        pure
        returns (StreamFinalityComponentExpectation[] memory result)
    {
        if (rows.length != 9 && rows.length != 10) revert NativeProviderSource();
        result = new StreamFinalityComponentExpectation[](9);
        uint256 n;
        uint256 sanctions;
        for (uint256 i; i < rows.length; ++i) {
            if (rows[i].componentType == StreamFinalityDomains.COMPONENT_ARTIST_SANCTION) {
                ++sanctions;
            } else {
                if (n == 9) revert NativeProviderComponent(i);
                result[n++] = rows[i];
            }
        }
        if (n != 9 || sanctions != rows.length - 9) revert NativeProviderSource();
    }

    function manifestDependencies(Original.Config memory c)
        public
        pure
        returns (StreamFinalityScopedPreservationPolicyInputManifestReadsV1.Dependencies memory d)
    {
        uint256[5] memory indexes = [uint256(0), 1, 4, 5, 12];
        for (uint256 i; i < 5; ++i) {
            d.targets[i] = c.targets[indexes[i]];
            d.codeHashes[i] = c.codeHashes[indexes[i]];
        }
        d.chainId = c.chainId;
        d.readGas = c.readGas;
    }

    function _inventoryConfiguration(Original.Config memory c) private view {
        AuthorityConfiguration.read(
            c.targets,
            c.codeHashes,
            c.chainId,
            c.readGas,
            c.inventoryDependencyHash,
            CurrentInventoryTypes.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE
        );
    }

    function _referenceConfiguration(Original.Config memory c) private view {
        bytes memory raw = _read(
            c,
            9,
            abi.encodeCall(IStreamScopedPreservationPolicyReferencePublicationV1.dependencies, ()),
            608,
            c.readGas
        );
        StreamScopedPreservationPolicyReferenceTypesV1.Dependencies memory d =
            abi.decode(raw, (StreamScopedPreservationPolicyReferenceTypesV1.Dependencies));
        if (keccak256(raw) != keccak256(abi.encode(d)) || d.chainId != c.chainId) {
            revert NativeProviderDependency(c.targets[9]);
        }
        uint256[7] memory indexes = [uint256(0), 1, 4, 5, 2, 8, 21];
        for (uint256 i; i < 7; ++i) {
            if (
                d.targets[i] != c.targets[indexes[i]] || d.codeHashes[i] != c.codeHashes[indexes[i]]
            ) {
                revert NativeProviderDependency(c.targets[9]);
            }
        }
    }

    function _snapshotConfiguration(Original.Config memory c) private view {
        bytes memory raw = _read(
            c,
            8,
            abi.encodeCall(IStreamScopedPreservationPolicySnapshotPublicationV1.dependencies, ()),
            832,
            c.readGas
        );
        StreamScopedPreservationPolicySnapshotTypesV1.Dependencies memory d =
            abi.decode(raw, (StreamScopedPreservationPolicySnapshotTypesV1.Dependencies));
        if (keccak256(raw) != keccak256(abi.encode(d)) || d.chainId != c.chainId) {
            revert NativeProviderDependency(c.targets[8]);
        }
        uint256[9] memory from = [uint256(0), 1, 2, 3, 4, 5, 7, 8, 9];
        uint256[9] memory to = [uint256(0), 1, 4, 5, 2, 3, 7, 6, 20];
        for (uint256 i; i < from.length; ++i) {
            if (
                d.targets[from[i]] != c.targets[to[i]]
                    || d.codeHashes[from[i]] != c.codeHashes[to[i]]
            ) {
                revert NativeProviderDependency(c.targets[8]);
            }
        }
        if (
            _word(c, 7, abi.encodeWithSignature("selectionCheckpoint()"))
                    != bytes32(uint256(uint160(d.targets[6]))) || d.targets[6].code.length == 0
                || d.targets[6].codehash != d.codeHashes[6]
                || _word(c, 7, abi.encodeWithSignature("entropySourceSet()"))
                    != bytes32(uint256(uint160(d.targets[10]))) || d.targets[10].code.length == 0
                || d.targets[10].codehash != d.codeHashes[10]
        ) revert NativeProviderDependency(c.targets[8]);
        address sourceSet = d.targets[10];
        if (
            abi.decode(
                        StreamFinalityBoundedReads.read(
                            sourceSet,
                            abi.encodeCall(
                                IERC165.supportsInterface, (type(SourceSet).interfaceId)
                            ),
                            32,
                            c.readGas
                        ),
                        (uint256)
                    ) != 1
                || abi.decode(
                        StreamFinalityBoundedReads.read(
                            sourceSet,
                            abi.encodeWithSignature("SOURCE_SET_PROFILE()"),
                            32,
                            c.readGas
                        ),
                        (bytes32)
                    ) != keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2")
                || abi.decode(
                        StreamFinalityBoundedReads.read(
                            sourceSet, abi.encodeCall(SourceSet.factory, ()), 32, c.readGas
                        ),
                        (address)
                    ) != c.targets[10]
                || abi.decode(
                        StreamFinalityBoundedReads.read(
                            sourceSet, abi.encodeWithSignature("core()"), 32, c.readGas
                        ),
                        (address)
                    ) != c.targets[0]
        ) {
            revert NativeProviderDependency(sourceSet);
        }
        raw = _read(c, 10, abi.encodeCall(Factory.dependencies, ()), 352, c.readGas);
        Policies.Dependencies memory policies = abi.decode(raw, (Policies.Dependencies));
        if (
            keccak256(raw) != keccak256(abi.encode(policies)) || policies.chainId != c.chainId
                || _word(c, 7, abi.encodeWithSignature("factoryDependenciesHash()"))
                    != keccak256(raw)
                || _word(c, 7, abi.encodeWithSignature("sourceFactoryCodeHash()"))
                    != c.codeHashes[10]
        ) {
            revert NativeProviderDependency(c.targets[10]);
        }
        uint256[3] memory indexes = [uint256(0), 1, 3];
        for (uint256 i; i < 3; ++i) {
            if (
                policies.targets[i] != c.targets[indexes[i]]
                    || policies.codeHashes[i] != c.codeHashes[indexes[i]]
            ) {
                revert NativeProviderDependency(c.targets[10]);
            }
        }
        if (
            policies.targets[3].code.length == 0
                || policies.targets[3].codehash != policies.codeHashes[3]
        ) {
            revert NativeProviderDependency(policies.targets[3]);
        }
    }

    function _coverage(
        Original.Config memory c,
        StreamPreservationInventoryTypes.Evidence memory e,
        StreamFinalityScopedPreservationPolicyInputManifestTypesV1.Statement memory s
    ) private view {
        bytes memory raw = _read(
            c,
            19,
            abi.encodeCall(
                IStreamScopedPreservationPolicyBundleArchiveCoverageV1.requireCoverage,
                (s.scope, e.planId, e.renderCriticalEvidenceHash)
            ),
            288,
            c.sourceGas
        );
        Bundle.BundleEvidence memory scoped = abi.decode(raw, (Bundle.BundleEvidence));
        StreamPreservationInventoryTypes.BundleEvidence memory b = scoped.coverage;
        if (
            keccak256(raw) != keccak256(abi.encode(scoped))
                || keccak256(abi.encode(scoped.scope)) != keccak256(abi.encode(s.scope))
                || b.inventoryPlan != e.planId
                || b.renderCriticalEvidenceHash != e.renderCriticalEvidenceHash
                || b.itemCount != e.itemCount || b.evidenceChainHash == 0
                || b.bundleCoverageHash == 0
        ) {
            revert NativeProviderSource();
        }
        StreamPreservationInventoryTypes.OriginalInputs memory o = e.originals;
        s.inputs = StreamFinalityScopeInputs(
            o.rootRecordHash,
            o.snapshotRecordHash,
            o.referenceRenderRecordHash,
            o.intentRecordHash,
            o.intentWaiverRecordHash,
            o.interviewEvidenceHash,
            o.rightsStatementRecordHash,
            o.workDescriptionRecordHash,
            e.renderCriticalEvidenceHash,
            b.bundleCoverageHash
        );
    }

    function _headers(
        Original.Config memory c,
        StreamPreservationInventoryTypes.Evidence memory e,
        StreamFinalityScopedPreservationPolicyInputManifestTypesV1.Statement memory s
    ) private view {
        // The complete inventory was authenticated immediately above. This projection retains
        // exact V2 root/snapshot identity without repeating the complete source traversal.
        Metadata.RootFacts memory f = Metadata.rootFacts(
            Metadata.Config(
                Snapshots.Dependencies(
                    c.targets[0],
                    c.targets[1],
                    c.targets[2],
                    c.targets[8],
                    c.codeHashes[0],
                    c.codeHashes[1],
                    c.codeHashes[2],
                    c.codeHashes[8],
                    c.chainId,
                    c.readGas,
                    c.componentSourceGas
                ),
                c.targets[3],
                c.codeHashes[3]
            ),
            s.scope,
            false,
            keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2")
        );
        StreamScopedPreservationPolicySnapshotTypesV1.Receipt memory snapshot = f.snapshot;
        if (
            f.recordHash != e.originals.rootRecordHash || f.record.leafCount != e.tokenCount
                || snapshot.recordHash != e.originals.snapshotRecordHash
                || snapshot.scopeSubject != e.scopeSubject
                || f.source.sourceFactory != c.targets[10]
                || f.source.sourceFactoryCodeHash != c.codeHashes[10]
                || f.binding.outputManifest != c.targets[6]
                || f.binding.outputManifestCodeHash != c.codeHashes[6]
                || f.binding.checkpoint != c.targets[7]
                || f.binding.checkpointCodeHash != c.codeHashes[7]
        ) {
            revert NativeProviderSource();
        }
        s.contentRoot = f.record.contentRoot;
        s.leafCount = f.record.leafCount;
        s.contentRootSchemaId = OutputSchemas.LEAF_SCHEMA;
        s.snapshotManifestHash = snapshot.manifestHash;
        bytes memory raw;
        raw = _read(
            c,
            9,
            abi.encodeCall(
                IStreamScopedPreservationPolicyReferencePublicationV1.currentReference, (s.scope)
            ),
            672,
            c.readGas
        );
        StreamScopedPreservationPolicyReferenceTypesV1.Receipt memory reference_ =
            abi.decode(raw, (StreamScopedPreservationPolicyReferenceTypesV1.Receipt));
        StreamReferenceRenderTypes.Receipt memory observed = reference_.observation;
        if (
            keccak256(raw) != keccak256(abi.encode(reference_))
                || reference_.scopeSubject != e.scopeSubject
                || observed.recordHash != e.originals.referenceRenderRecordHash
                || observed.collectionId != s.scope.collectionId || observed.payloadHash == 0
                || observed.snapshotRecordHash != snapshot.recordHash
                || observed.snapshotRevision != snapshot.revision
        ) {
            revert NativeProviderSource();
        }
        s.referenceRenderManifestHash = observed.payloadHash;
    }

    function _core(
        Original.Config memory c,
        StreamFinalityScopedPreservationPolicyInputManifestTypesV1.Statement memory s
    ) private view {
        StreamCoreFinalityScopeQuery memory query = StreamCoreFinalityScopeQuery(
            uint8(s.scope.scopeType), s.scope.collectionId, s.scope.tokenId, s.scope.scopeId
        );
        bytes memory raw = _read(
            c,
            14,
            abi.encodeCall(IStreamCoreFinalityAdapter.scopedCoreFinalityFacts, (query)),
            416,
            c.readGas
        );
        StreamScopedCoreFinalityFacts memory f = abi.decode(raw, (StreamScopedCoreFinalityFacts));
        if (
            keccak256(raw) != keccak256(abi.encode(f)) || !f.scopeExists
                || f.scopeType != uint8(s.scope.scopeType) || f.collectionId != s.scope.collectionId
                || f.tokenId != s.scope.tokenId || f.scopeId != s.scope.scopeId
                || f.collectionStatus > StreamFinalityDomains.CORE_COLLECTION_STATUS_CLOSED
                || f.collectionSupplyMode
                    > StreamFinalityDomains.CORE_COLLECTION_SUPPLY_MODE_UNCAPPED_OPEN
        ) {
            revert NativeProviderTerminal();
        }
        if (s.scope.scopeType == StreamFinalityScopeType.TOKEN) {
            if (
                s.leafCount != 1 || !f.tokenMappingExists
                    || (f.tokenLifecycle != StreamFinalityDomains.TOKEN_LIFECYCLE_MINTED
                        && f.tokenLifecycle != StreamFinalityDomains.TOKEN_LIFECYCLE_BURNED)
                    || f.burned
                        != (f.tokenLifecycle == StreamFinalityDomains.TOKEN_LIFECYCLE_BURNED)
            ) {
                revert NativeProviderTerminal();
            }
        } else if (f.scopeManifestHash == 0) {
            revert NativeProviderTerminal();
        }
        s.coreFactsHash = StreamFinalityHashes.scopedCoreFactsHash(c.targets[0], s.scope, f);
    }

    function _profile(
        Original.Config memory c,
        uint256 index,
        bytes4 interfaceId,
        string memory selector,
        bytes32 profile
    ) private view {
        if (
            _word(c, index, abi.encodeCall(IERC165.supportsInterface, (interfaceId)))
                    != bytes32(uint256(1))
                || _word(c, index, abi.encodeWithSignature(selector)) != profile
        ) {
            revert NativeProviderDependency(c.targets[index]);
        }
    }

    function _read(
        Original.Config memory c,
        uint256 i,
        bytes memory input,
        uint256 size,
        uint256 cap
    ) private view returns (bytes memory) {
        return StreamFinalityBoundedReads.read(c.targets[i], input, size, cap);
    }

    function _word(Original.Config memory c, uint256 i, bytes memory input)
        private
        view
        returns (bytes32)
    {
        return abi.decode(_read(c, i, input, 32, c.readGas), (bytes32));
    }

    function _address(Original.Config memory c, uint256 from, string memory selector, uint256 to)
        private
        view
    {
        if (
            _word(c, from, abi.encodeWithSignature(selector))
                != bytes32(uint256(uint160(c.targets[to])))
        ) {
            revert NativeProviderDependency(c.targets[from]);
        }
    }

    function _self(Original.Config memory c, uint256 from, string memory selector) private view {
        if (
            _word(c, from, abi.encodeWithSignature(selector))
                != bytes32(uint256(uint160(address(this))))
        ) {
            revert NativeProviderDependency(c.targets[from]);
        }
    }
}

import {
    StreamScopedPreservationPolicyRenderCriticalTypesV1
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";

import {
    StreamScopedPreservationPolicyReferenceTypesV1
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";

import {
    StreamScopedPreservationPolicySnapshotTypesV1
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
