// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityPolicyStaticSourceV2 as Projection
} from "./StreamFinalityPolicyStaticSourceV2.sol";
import {
    StreamFinalityPolicySnapshotReadsV2 as SnapshotReads
} from "./StreamFinalityPolicySnapshotReadsV2.sol";
import {
    IStreamPolicySnapshotPublicationV2 as Snapshot
} from "../../interfaces/stream/metadata/IStreamPolicySnapshotPublicationV2.sol";
import {
    StreamPolicySnapshotTypesV2 as S2
} from "../../interfaces/stream/metadata/StreamPolicySnapshotTypesV2.sol";
import {
    IStreamPolicyContentRootPublicationV2 as RootV2
} from "../../interfaces/stream/metadata/IStreamPolicyContentRootPublicationV2.sol";
import { StreamPolicyOutputSchemasV2 as Definitions } from "./StreamPolicyOutputSchemasV2.sol";
import "./StreamFinalityDescriptionReads.sol";
import "./StreamFinalityConservationReads.sol";
import "../../interfaces/stream/metadata/IStreamRecordSelectionLock.sol";

/// @notice Local selected-record commitments; never recursively calls complete inputs/discovery.
/// @dev WORK/RIGHTS seals fix selected heads, not the generic append-only dossier. Source records
/// remain historical. Component freeze additionally requires original intent and snapshot locks.
library StreamFinalityPolicyMetadataFactsV2 {
    struct LocalFacts {
        bytes32 subject;
        bytes32 rootRecordHash;
        IStreamContentRootPublication.Record rootRecord;
        bytes32 rootSchemaId;
        StreamFinalityDescriptionEvidence descriptions;
        StreamFinalityConservationEvidence conservation;
        IStreamRecordSelectionLock.SelectionLock workLock;
        IStreamRecordSelectionLock.SelectionLock rightsLock;
        S2.Receipt snapshot;
        S2.Lock snapshotLock;
        RootV2.Binding binding;
        Projection.Projection source;
    }
    error NativeMetadataScope();
    error NativeMetadataSource();

    function facts(
        StreamFinalityNativeProviderReads.Config memory c,
        StreamFinalityScope memory scope
    ) public view returns (bool frozen, bytes32 dataHash) {
        if (
            scope.scopeType != StreamFinalityScopeType.COLLECTION || scope.collectionId == 0
                || scope.tokenId != 0 || scope.scopeId != 0 || block.chainid != c.chainId
        ) revert NativeMetadataScope();
        uint256[10] memory indexes = [uint256(0), 1, 2, 4, 5, 8, 15, 16, 17, 3];
        for (uint256 i; i < indexes.length; ++i) {
            uint256 j = indexes[i];
            if (c.targets[j].code.length == 0 || c.targets[j].codehash != c.codeHashes[j]) {
                revert NativeMetadataSource();
            }
        }
        LocalFacts memory f;
        f.subject = StreamMetadataSubjects.scopeSubject(c.chainId, c.targets[0], scope);
        StreamFinalityDescriptionReads.Dependencies memory d;
        uint256[6] memory di = [uint256(0), 1, 4, 5, 15, 16];
        for (uint256 i; i < 6; ++i) {
            d.targets[i] = c.targets[di[i]];
            d.codeHashes[i] = c.codeHashes[di[i]];
        }
        d.chainId = c.chainId;
        d.readGas = c.readGas;
        d.selectionGas = c.componentSourceGas;
        f.descriptions = StreamFinalityDescriptionReads.requireCurrent(d, scope);
        StreamFinalityConservationReads.Dependencies memory v;
        uint256[5] memory vi = [uint256(0), 1, 4, 5, 17];
        for (uint256 i; i < 5; ++i) {
            v.targets[i] = c.targets[vi[i]];
            v.codeHashes[i] = c.codeHashes[vi[i]];
        }
        v.chainId = c.chainId;
        v.readGas = c.readGas;
        v.selectionGas = c.componentSourceGas;
        f.conservation = StreamFinalityConservationReads.requireCurrent(v, scope);
        f.workLock = _seal(
            c,
            15,
            scope.collectionId,
            f.subject,
            f.descriptions.workDescriptionRecordHash,
            f.descriptions.workRevision,
            f.descriptions.workSelectionHash
        );
        f.rightsLock = _seal(
            c,
            16,
            scope.collectionId,
            f.subject,
            f.descriptions.rightsStatementRecordHash,
            f.descriptions.rightsRevision,
            f.descriptions.rightsSelectionHash
        );
        _root(c, scope.collectionId, f);
        bool snapshotLocked = _snapshot(c, scope.collectionId, f);
        bool coreFrozen = abi.decode(
            _read(
                c,
                0,
                abi.encodeCall(
                    IStreamCoreFinalitySource.collectionFreezeStatus, (scope.collectionId)
                ),
                32
            ),
            (bool)
        );
        frozen = coreFrozen && f.workLock.locked && f.rightsLock.locked
            && f.conservation.intentLock.locked && snapshotLocked;
        // Bind only this family's fixed graph and historical inputs, never sanction/current key,
        // complete input-manifest hash, external inventory or a self-referential component array.
        dataHash = _dataHash(c, scope, f);
    }

    function _dataHash(
        StreamFinalityNativeProviderReads.Config memory c,
        StreamFinalityScope memory scope,
        LocalFacts memory f
    ) private pure returns (bytes32 dataHash) {
        dataHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_POLICY_SELECTED_METADATA_COMPONENT_V2"),
                c.chainId,
                c.targets[0],
                c.targets[1],
                c.targets[2],
                c.targets[8],
                c.targets[15],
                c.targets[16],
                c.targets[17],
                scope,
                f
            )
        );
    }

    function _root(
        StreamFinalityNativeProviderReads.Config memory c,
        uint256 cid,
        LocalFacts memory f
    ) private view {
        f.rootRecordHash = abi.decode(
            _read(
                c,
                2,
                abi.encodeCall(IStreamContentRootPublication.collectionContentRootHead, (cid)),
                32
            ),
            (bytes32)
        );
        if (f.rootRecordHash == 0) revert NativeMetadataSource();
        bytes memory raw = StreamFinalityRouterEvidence.dynamicRead(
            c.targets[2],
            abi.encodeCall(IStreamContentRootPublication.contentRootRecord, (f.rootRecordHash)),
            4096,
            c.readGas
        );
        f.rootRecord = abi.decode(raw, (IStreamContentRootPublication.Record));
        if (keccak256(raw) != keccak256(abi.encode(f.rootRecord))) revert NativeMetadataSource();
        (bytes32 root, uint64 leaves, bytes32 schema) = abi.decode(
            _read(
                c,
                2,
                abi.encodeCall(IStreamContentRootPublication.tokenContentRoot, (cid, f.subject)),
                96
            ),
            (bytes32, uint64, bytes32)
        );
        if (
            root == 0 || root != f.rootRecord.contentRoot || leaves == 0
                || leaves != f.rootRecord.leafCount || schema == 0
                || f.rootRecord.publication.collectionId != cid || f.rootRecord.stateHash == 0
                || f.rootRecord.manifestHash == 0 || f.rootRecord.artistConsent == 0
        ) revert NativeMetadataSource();
        if (schema != Definitions.LEAF_SCHEMA) revert NativeMetadataSource();
        raw = _read(c, 2, abi.encodeCall(RootV2.policyContentRootBinding, (f.rootRecordHash)), 544);
        f.binding = abi.decode(raw, (RootV2.Binding));
        if (
            keccak256(raw) != keccak256(abi.encode(f.binding))
                || f.binding.profileId != keccak256("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2")
                || f.binding.outputRoot == 0 || f.binding.entropySourceSet == address(0)
                || f.binding.inventoryHash == 0 || f.binding.policyChainHash == 0
        ) revert NativeMetadataSource();
        f.rootSchemaId = schema;
    }

    function _seal(
        StreamFinalityNativeProviderReads.Config memory c,
        uint256 i,
        uint256 cid,
        bytes32 subject,
        bytes32 record,
        uint64 revision,
        bytes32 selectionHash
    ) private view returns (IStreamRecordSelectionLock.SelectionLock memory l) {
        bytes memory raw = _read(
            c, i, abi.encodeCall(IStreamRecordSelectionLock.selectionLock, (cid, subject)), 576
        );
        l = abi.decode(raw, (IStreamRecordSelectionLock.SelectionLock));
        if (keccak256(raw) != keccak256(abi.encode(l))) revert NativeMetadataSource();
        if (!l.locked) {
            IStreamRecordSelectionLock.SelectionLock memory empty;
            if (keccak256(raw) != keccak256(abi.encode(empty))) revert NativeMetadataSource();
        } else if (
            l.recordHash != record || l.revision != revision || l.selectionHash != selectionHash
                || l.actionId == 0 || l.lockHash == 0 || l.lockedAt == 0
                || l.lockedAt > block.timestamp
        ) {
            revert NativeMetadataSource();
        }
    }

    function _snapshot(
        StreamFinalityNativeProviderReads.Config memory c,
        uint256 cid,
        LocalFacts memory f
    ) private view returns (bool locked) {
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, cid, 0, 0);
        SnapshotReads.Dependencies memory d = SnapshotReads.Dependencies(
            c.targets[0],
            c.targets[1],
            c.targets[8],
            c.codeHashes[0],
            c.codeHashes[1],
            c.codeHashes[8],
            c.chainId,
            c.readGas,
            c.componentSourceGas
        );
        f.source = Projection.current(d, c.targets[2], c.codeHashes[2], scope);
        if (f.source.contentRootRecordHash != f.rootRecordHash) revert NativeMetadataSource();
        bytes memory raw = _read(c, 8, abi.encodeCall(Snapshot.currentSnapshot, (scope)), 544);
        f.snapshot = abi.decode(raw, (S2.Receipt));
        if (
            keccak256(raw) != keccak256(abi.encode(f.snapshot))
                || f.snapshot.recordHash != f.source.snapshotRecordHash
                || f.snapshot.scopeSubject != f.subject || f.snapshot.manifestHash == 0
        ) revert NativeMetadataSource();
        raw = _read(c, 8, abi.encodeCall(Snapshot.snapshotLock, (scope)), 128);
        f.snapshotLock = abi.decode(raw, (S2.Lock));
        if (keccak256(raw) != keccak256(abi.encode(f.snapshotLock))) revert NativeMetadataSource();
        if (f.snapshotLock.actionId == 0) {
            if (
                f.snapshotLock.recordHash != 0 || f.snapshotLock.revision != 0
                    || f.snapshotLock.lockedAt != 0
            ) revert NativeMetadataSource();
        } else {
            if (
                f.snapshotLock.recordHash != f.snapshot.recordHash
                    || f.snapshotLock.revision != f.snapshot.revision
                    || f.snapshotLock.lockedAt < f.snapshot.recordedAt
                    || f.snapshotLock.lockedAt > block.timestamp
            ) revert NativeMetadataSource();
            locked = true;
        }
    }

    function _read(
        StreamFinalityNativeProviderReads.Config memory c,
        uint256 i,
        bytes memory input,
        uint256 size
    ) private view returns (bytes memory) {
        return StreamFinalityBoundedReads.read(c.targets[i], input, size, c.readGas);
    }
}
