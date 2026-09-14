// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityBoundedReads.sol";
import "./StreamFinalityInputManifestReads.sol";
import "./StreamFinalityHashes.sol";
import "../metadata/StreamMetadataSubjects.sol";
import "../../interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import "../../interfaces/stream/finality/IStreamCoreFinalityAdapter.sol";
import "../../interfaces/stream/finality/IStreamCoreFinalitySource.sol";
import "../../interfaces/stream/metadata/IStreamContentRootPublication.sol";
import "../../interfaces/stream/metadata/IStreamCollectionSnapshots.sol";
import "../../interfaces/stream/preservation/IStreamReferenceRenderPublication.sol";
import "../../interfaces/stream/preservation/IStreamRenderCriticalInventory.sol";
import "../../interfaces/stream/preservation/IStreamBundleArchiveCoverage.sol";
import "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";

/// @notice Current native collection inputs from one fixed, fully authenticated source inventory.
/// @dev Inventory is a semantic producer, not a caller-supplied list. Its exact constructor
/// configuration is pinned as well as runtime. Original headers only project already-validated
/// current records; component-state validation independently proves terminal locks and entropy.
library StreamFinalityNativeProviderReads {
    struct Config {
        // Core, Metadata, Router, membership, schemas, Store, leaf manifest, checkpoint,
        // snapshots, reference publisher, entropy factory, Artist, original Registry,
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
    ) public view returns (StreamFinalityInputManifestTypes.Statement memory s) {
        requirePins(c);
        if (
            scope.scopeType != StreamFinalityScopeType.COLLECTION || scope.collectionId == 0
                || scope.tokenId != 0 || scope.scopeId != 0
        ) revert NativeProviderScope();
        s.scope = scope;
        s.nonSanctionComponents = components;
        s.entropyPolicy = 1;
        s.postFreezePolicy = 1;
        s.sanctionPolicy = 1;
        // Exactly one complete current source pass. Coverage consumes the same immutable plan.
        bytes memory raw = _read(
            c,
            18,
            abi.encodeCall(IStreamRenderCriticalInventory.requireCurrent, (scope.collectionId)),
            608,
            c.sourceGas
        );
        StreamPreservationInventoryTypes.Evidence memory e =
            abi.decode(raw, (StreamPreservationInventoryTypes.Evidence));
        if (
            keccak256(raw) != keccak256(abi.encode(e)) || e.planId == 0
                || e.collectionId != scope.collectionId
                || e.scopeSubject
                    != StreamMetadataSubjects.scopeSubject(c.chainId, c.targets[0], scope)
                || e.artistId == 0 || e.sourceContextHash == 0 || e.tokenInventoryHash == 0
                || e.tokenCount == 0 || e.segmentCount == 0 || e.itemCount == 0
                || e.segmentChainHash == 0 || e.renderCriticalEvidenceHash == 0
        ) revert NativeProviderSource();
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
                abi.encodeCall(IStreamArtworkFinalityComponent.finalityState, (scope.collectionId)),
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
        returns (StreamFinalityInputManifestReads.Dependencies memory d)
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
            c, 8, abi.encodeCall(IStreamCollectionSnapshots.dependencies, ()), 736, c.readGas
        );
        StreamSnapshotTypes.Dependencies memory d =
            abi.decode(raw, (StreamSnapshotTypes.Dependencies));
        if (keccak256(raw) != keccak256(abi.encode(d)) || d.chainId != c.chainId) {
            revert NativeProviderDependency(c.targets[8]);
        }
        uint256[8] memory index = [uint256(0), 1, 4, 5, 2, 6, 7, 3];
        for (uint256 i; i < 8; ++i) {
            if (d.targets[i] != c.targets[index[i]] || d.codeHashes[i] != c.codeHashes[index[i]]) {
                revert NativeProviderDependency(c.targets[8]);
            }
        }
        if (
            _word(c, 10, abi.encodeWithSignature("coordinatorInventory()"))
                    != bytes32(uint256(uint160(d.targets[8]))) || d.targets[8].code.length == 0
                || d.targets[8].codehash != d.codeHashes[8]
        ) {
            revert NativeProviderDependency(c.targets[8]);
        }
    }

    function _coverage(
        Config memory c,
        StreamPreservationInventoryTypes.Evidence memory e,
        StreamFinalityInputManifestTypes.Statement memory s
    ) private view {
        bytes memory raw = _read(
            c,
            19,
            abi.encodeCall(
                IStreamBundleArchiveCoverage.requireCoverage,
                (e.planId, e.renderCriticalEvidenceHash)
            ),
            160,
            c.sourceGas
        );
        StreamPreservationInventoryTypes.BundleEvidence memory b =
            abi.decode(raw, (StreamPreservationInventoryTypes.BundleEvidence));
        if (
            keccak256(raw) != keccak256(abi.encode(b)) || b.inventoryPlan != e.planId
                || b.renderCriticalEvidenceHash != e.renderCriticalEvidenceHash
                || b.itemCount != e.itemCount || b.evidenceChainHash == 0
                || b.bundleCoverageHash == 0
        ) revert NativeProviderSource();
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
        StreamFinalityInputManifestTypes.Statement memory s
    ) private view {
        if (
            _word(
                    c,
                    2,
                    abi.encodeCall(
                        IStreamContentRootPublication.collectionContentRootHead,
                        (s.scope.collectionId)
                    )
                ) != e.originals.rootRecordHash
        ) revert NativeProviderSource();
        bytes memory raw = _read(
            c,
            2,
            abi.encodeCall(
                IStreamContentRootPublication.tokenContentRoot,
                (s.scope.collectionId, e.scopeSubject)
            ),
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
            abi.encodeCall(IStreamCollectionSnapshots.currentSnapshot, (s.scope.collectionId)),
            672,
            c.readGas
        );
        StreamSnapshotTypes.Receipt memory snapshot = abi.decode(raw, (StreamSnapshotTypes.Receipt));
        if (
            keccak256(raw) != keccak256(abi.encode(snapshot))
                || snapshot.recordHash != e.originals.snapshotRecordHash
                || snapshot.collectionId != s.scope.collectionId || snapshot.manifestHash == 0
        ) revert NativeProviderSource();
        s.snapshotManifestHash = snapshot.manifestHash;
        raw = _read(
            c,
            9,
            abi.encodeCall(
                IStreamReferenceRenderPublication.currentReference, (s.scope.collectionId)
            ),
            640,
            c.readGas
        );
        StreamReferenceRenderTypes.Receipt memory reference_ =
            abi.decode(raw, (StreamReferenceRenderTypes.Receipt));
        if (
            keccak256(raw) != keccak256(abi.encode(reference_))
                || reference_.recordHash != e.originals.referenceRenderRecordHash
                || reference_.collectionId != s.scope.collectionId || reference_.payloadHash == 0
                || reference_.snapshotRecordHash != snapshot.recordHash
                || reference_.snapshotRevision != snapshot.revision
        ) {
            revert NativeProviderSource();
        }
        s.referenceRenderManifestHash = reference_.payloadHash;
    }

    function _core(Config memory c, StreamFinalityInputManifestTypes.Statement memory s)
        private
        view
    {
        bytes memory raw = _read(
            c,
            14,
            abi.encodeCall(
                IStreamCoreFinalityAdapter.coreCollectionFinalityFacts, (s.scope.collectionId)
            ),
            288,
            c.readGas
        );
        StreamCoreCollectionFinalityFacts memory f =
            abi.decode(raw, (StreamCoreCollectionFinalityFacts));
        if (
            keccak256(raw) != keccak256(abi.encode(f)) || !f.exists
                || f.status != StreamFinalityDomains.CORE_COLLECTION_STATUS_CLOSED
                || f.supplyMode > StreamFinalityDomains.CORE_COLLECTION_SUPPLY_MODE_UNCAPPED_OPEN
                || f.mintedSupply != s.leafCount
                || _word(
                        c,
                        0,
                        abi.encodeCall(
                            IStreamCoreFinalitySource.collectionBurnsBlocked, (s.scope.collectionId)
                        )
                    ) != bytes32(uint256(1))
                || _word(
                        c,
                        0,
                        abi.encodeCall(
                            IStreamCoreFinalitySource.collectionFreezeStatus, (s.scope.collectionId)
                        )
                    ) != bytes32(uint256(1))
        ) {
            revert NativeProviderTerminal();
        }
        s.coreFactsHash =
            StreamFinalityHashes.coreCollectionFactsHash(c.targets[0], s.scope.collectionId, f);
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
