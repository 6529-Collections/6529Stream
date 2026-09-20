// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityBoundedReads.sol";
import "./StreamScopedFinalityInputManifestReads.sol";
import "./StreamFinalityHashes.sol";
import "../metadata/StreamMetadataSubjects.sol";
import "../../interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import "../../interfaces/stream/finality/IStreamCoreFinalityAdapter.sol";
import "../../interfaces/stream/finality/IStreamCoreFinalitySource.sol";
import "../../interfaces/stream/metadata/IStreamContentRootPublication.sol";
import "../../interfaces/stream/metadata/IStreamCollectionSnapshots.sol";
import "../../interfaces/stream/preservation/IStreamReferenceRenderPublication.sol";
import {
    IStreamScopedRenderCriticalInventory
} from "../../interfaces/stream/preservation/IStreamScopedRenderCriticalInventory.sol";
import {
    IStreamScopedBundleArchiveCoverage
} from "../../interfaces/stream/preservation/IStreamScopedBundleArchiveCoverage.sol";
import {
    IStreamScopedSnapshotPublication
} from "../../interfaces/stream/metadata/IStreamScopedSnapshotPublication.sol";
import {
    IStreamScopedContentRootPublication
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedReferencePublication
} from "../../interfaces/stream/preservation/IStreamScopedReferencePublication.sol";
import "../../interfaces/stream/preservation/IStreamBundleArchiveCoverage.sol";
import "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";

/// @notice Distinct TOKEN/RELEASE/SEASON inputs from the complete authenticated scoped inventory.
/// @dev Inventory is a semantic producer, not a caller-supplied list. Its exact constructor
/// configuration is pinned as well as runtime. Original headers only project already-validated
/// current records; component-state validation independently proves terminal locks and entropy.
library StreamFinalityScopedProviderReads {
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
        _address(c, 19, "core()", 0);
        _address(c, 19, "metadataHost()", 1);
        _address(c, 19, "renderCriticalInventory()", 18);
        _address(c, 19, "artifactCoverage()", 20);
        _address(c, 19, "externalCoverage()", 21);
        _address(c, 14, "core()", 0);
        _address(c, 14, "collectionMetadata()", 1);
        _address(c, 12, "coreReads()", 0);
        _address(c, 12, "metadataReads()", 1);
        _self(c, 12, "scopeEvidenceProvider()");
        _self(c, 13, "scopeEvidenceProvider()");
        _self(c, 14, "evidenceProvider()");
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
            abi.encodeCall(IStreamScopedRenderCriticalInventory.requireCurrent, (scope)),
            736,
            c.sourceGas
        );
        StreamScopedRenderCriticalTypes.Evidence memory scoped =
            abi.decode(raw, (StreamScopedRenderCriticalTypes.Evidence));
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

    function _inventoryConfiguration(Config memory c) private view {
        bytes memory raw = _read(c, 18, abi.encodeWithSignature("dependencies()"), 1344, c.readGas);
        StreamRenderCriticalSourceTypes.Dependencies memory d =
            abi.decode(raw, (StreamRenderCriticalSourceTypes.Dependencies));
        if (
            keccak256(raw) != keccak256(abi.encode(d))
                || keccak256(raw) != c.inventoryDependencyHash || d.chainId != c.chainId
                || d.artistTargets[0] != c.targets[11] || d.artistCodeHashes[0] != c.codeHashes[11]
        ) {
            revert NativeProviderDependency(c.targets[18]);
        }
        uint256[12] memory index = [uint256(0), 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21];
        for (uint256 i; i < 12; ++i) {
            if (d.targets[i] != c.targets[index[i]] || d.codeHashes[i] != c.codeHashes[index[i]]) {
                revert NativeProviderDependency(c.targets[18]);
            }
        }
    }

    function _snapshotConfiguration(Config memory c) private view {
        bytes memory raw = _read(
            c, 8, abi.encodeCall(IStreamScopedSnapshotPublication.dependencies, ()), 832, c.readGas
        );
        StreamScopedSnapshotTypes.Dependencies memory d =
            abi.decode(raw, (StreamScopedSnapshotTypes.Dependencies));
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
                || _word(c, 10, abi.encodeWithSignature("coordinatorInventory()"))
                    != bytes32(uint256(uint160(d.targets[10]))) || d.targets[10].code.length == 0
                || d.targets[10].codehash != d.codeHashes[10]
        ) {
            revert NativeProviderDependency(c.targets[8]);
        }
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
                IStreamScopedBundleArchiveCoverage.requireCoverage,
                (s.scope, e.planId, e.renderCriticalEvidenceHash)
            ),
            288,
            c.sourceGas
        );
        StreamScopedRenderCriticalTypes.BundleEvidence memory scoped =
            abi.decode(raw, (StreamScopedRenderCriticalTypes.BundleEvidence));
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
        if (
            _word(
                    c,
                    2,
                    abi.encodeCall(
                        IStreamScopedContentRootPublication.scopedContentRootHead, (s.scope)
                    )
                ) != e.originals.rootRecordHash
        ) {
            revert NativeProviderSource();
        }
        bytes memory raw = _read(
            c,
            2,
            abi.encodeCall(IStreamScopedContentRootPublication.scopedTokenContentRoot, (s.scope)),
            96,
            c.readGas
        );
        (s.contentRoot, s.leafCount, s.contentRootSchemaId) =
            abi.decode(raw, (bytes32, uint64, bytes32));
        if (s.contentRoot == 0 || s.leafCount != e.tokenCount || s.contentRootSchemaId == 0) {
            revert NativeProviderSource();
        }
        raw = _read(
            c,
            8,
            abi.encodeCall(IStreamScopedSnapshotPublication.currentSnapshot, (s.scope)),
            544,
            c.readGas
        );
        StreamScopedSnapshotTypes.Receipt memory snapshot =
            abi.decode(raw, (StreamScopedSnapshotTypes.Receipt));
        if (
            keccak256(raw) != keccak256(abi.encode(snapshot))
                || snapshot.recordHash != e.originals.snapshotRecordHash
                || snapshot.scopeSubject != e.scopeSubject || snapshot.manifestHash == 0
        ) {
            revert NativeProviderSource();
        }
        s.snapshotManifestHash = snapshot.manifestHash;
        raw = _read(
            c,
            9,
            abi.encodeCall(IStreamScopedReferencePublication.currentReference, (s.scope)),
            672,
            c.readGas
        );
        StreamScopedReferenceTypes.Receipt memory reference_ =
            abi.decode(raw, (StreamScopedReferenceTypes.Receipt));
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

    function _word(Config memory c, uint256 i, bytes memory input) private view returns (bytes32) {
        return abi.decode(_read(c, i, input, 32, c.readGas), (bytes32));
    }

    function _address(Config memory c, uint256 from, string memory selector, uint256 to)
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

    function _self(Config memory c, uint256 from, string memory selector) private view {
        if (
            _word(c, from, abi.encodeWithSignature(selector))
                != bytes32(uint256(uint160(address(this))))
        ) {
            revert NativeProviderDependency(c.targets[from]);
        }
    }
}

import {
    StreamScopedRenderCriticalTypes
} from "../../interfaces/stream/preservation/StreamScopedRenderCriticalTypes.sol";

import {
    StreamScopedReferenceTypes
} from "../../interfaces/stream/preservation/StreamScopedReferenceTypes.sol";

import {
    StreamScopedSnapshotTypes
} from "../../interfaces/stream/metadata/StreamScopedSnapshotTypes.sol";
