// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityBoundedReads.sol";
import "./StreamScopedFinalityInputManifestReads.sol";
import "./StreamFinalityHashes.sol";
import "../metadata/StreamMetadataSubjects.sol";
import "../../interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import "../../interfaces/stream/finality/IStreamCoreFinalityAdapter.sol";
import "../../interfaces/stream/finality/IStreamCoreFinalitySource.sol";
import {
    IStreamScopedPolicyRenderCriticalInventoryV2
} from "../../interfaces/stream/preservation/IStreamScopedPolicyRenderCriticalInventoryV2.sol";
import {
    IStreamScopedPolicyBundleArchiveCoverageV2
} from "../../interfaces/stream/preservation/IStreamScopedPolicyBundleArchiveCoverageV2.sol";
import {
    IStreamScopedPolicySnapshotPublicationV2
} from "../../interfaces/stream/metadata/IStreamScopedPolicySnapshotPublicationV2.sol";
import {
    IStreamScopedContentRootPublication
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPolicyReferencePublicationV2
} from "../../interfaces/stream/preservation/IStreamScopedPolicyReferencePublicationV2.sol";
import "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamReferenceRenderTypes
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";

import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import {
    StreamFinalityScopedPolicyProviderMetadataV2 as Metadata
} from "./StreamFinalityScopedPolicyProviderMetadataV2.sol";
import {
    StreamFinalityScopedPolicySnapshotReadsV2 as Snapshots
} from "./StreamFinalityScopedPolicySnapshotReadsV2.sol";
import {
    IStreamScopedPolicyContentCheckpointV2 as Checkpoint
} from "../../interfaces/stream/finality/IStreamScopedPolicyContentCheckpointV2.sol";
import {
    IStreamScopedPolicyOutputManifestV2 as Outputs
} from "../../interfaces/stream/finality/IStreamScopedPolicyOutputManifestV2.sol";
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
    StreamScopedPolicyBundleArchiveTypesV2 as Bundle
} from "../../interfaces/stream/preservation/StreamScopedPolicyBundleArchiveTypesV2.sol";
import {
    StreamBundleArchiveTypes as Archive
} from "../../interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamScopedPolicyOutputSchemasV2 as OutputSchemas
} from "./StreamScopedPolicyOutputSchemasV2.sol";

import {
    StreamFinalityScopedPolicyProviderPinsV2 as Pins
} from "./StreamFinalityScopedPolicyProviderPinsV2.sol";

/// @notice Distinct TOKEN/RELEASE/SEASON inputs from the complete authenticated scoped inventory.
/// @dev Inventory is a semantic producer, not a caller-supplied list. Its exact constructor
/// configuration is pinned as well as runtime. Original headers only project already-validated
/// current records; component-state validation independently proves terminal locks and entropy.
library StreamFinalityScopedPolicyProviderReadsV2 {
    struct Config {
        // Core, Metadata, Router, membership, schemas, Store, leaf manifest, checkpoint,
        // scoped snapshots, scoped reference publisher, entropy factory, Artist, original Registry,
        // Discovery, Core adapter, WORK, RIGHTS, conservation, inventory, bundle,
        // onchain artifact coverage, external artifact coverage.
        address[22] targets;
        bytes32[22] codeHashes;
        uint256 chainId;
        uint256 readGas;
        uint256 sourceGas;
        // Nested component callbacks use a smaller leaf budget than the outer source read.
        uint256 componentSourceGas;
        bytes32 inventoryDependencyHash;
    }
    error NativeProviderConfiguration();
    error NativeProviderDependency(address target);
    error NativeProviderScope();
    error NativeProviderSource();
    error NativeProviderComponent(uint256 index);
    error NativeProviderTerminal();

    function requirePins(Config memory c) public view {
        Pins.requirePins(c);
    }

    function statement(
        Config memory c,
        StreamFinalityScope memory scope,
        StreamFinalityComponentExpectation[] memory components
    ) public view returns (StreamScopedFinalityInputManifestTypes.Statement memory s) {
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
            abi.encodeCall(IStreamScopedPolicyRenderCriticalInventoryV2.requireCurrent, (scope)),
            736,
            c.sourceGas
        );
        StreamScopedPolicyRenderCriticalTypesV2.Evidence memory scoped =
            abi.decode(raw, (StreamScopedPolicyRenderCriticalTypesV2.Evidence));
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

    function currentComponents(Config memory c, StreamFinalityScope memory scope)
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

    function manifestDependencies(Config memory c)
        public
        pure
        returns (StreamScopedFinalityInputManifestReads.Dependencies memory d)
    {
        uint256[5] memory indexes = [uint256(0), 1, 4, 5, 12];
        for (uint256 i; i < 5; ++i) {
            d.targets[i] = c.targets[indexes[i]];
            d.codeHashes[i] = c.codeHashes[indexes[i]];
        }
        d.chainId = c.chainId;
        d.readGas = c.readGas;
    }

    function _coverage(
        Config memory c,
        StreamPreservationInventoryTypes.Evidence memory e,
        StreamScopedFinalityInputManifestTypes.Statement memory s
    ) private view {
        bytes memory raw = _read(
            c,
            19,
            abi.encodeCall(
                IStreamScopedPolicyBundleArchiveCoverageV2.requireCoverage,
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
        Config memory c,
        StreamPreservationInventoryTypes.Evidence memory e,
        StreamScopedFinalityInputManifestTypes.Statement memory s
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
            false
        );
        StreamScopedPolicySnapshotTypesV2.Receipt memory snapshot = f.snapshot;
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
            abi.encodeCall(IStreamScopedPolicyReferencePublicationV2.currentReference, (s.scope)),
            672,
            c.readGas
        );
        StreamScopedPolicyReferenceTypesV2.Receipt memory reference_ =
            abi.decode(raw, (StreamScopedPolicyReferenceTypesV2.Receipt));
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

    function _core(Config memory c, StreamScopedFinalityInputManifestTypes.Statement memory s)
        private
        view
    {
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

    function _read(Config memory c, uint256 i, bytes memory input, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory)
    {
        return StreamFinalityBoundedReads.read(c.targets[i], input, size, cap);
    }
}

import {
    StreamScopedPolicyRenderCriticalTypesV2
} from "../../interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";

import {
    StreamScopedPolicyReferenceTypesV2
} from "../../interfaces/stream/preservation/StreamScopedPolicyReferenceTypesV2.sol";

import {
    StreamScopedPolicySnapshotTypesV2
} from "../../interfaces/stream/metadata/StreamScopedPolicySnapshotTypesV2.sol";
