// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopeMembershipFacts
} from "../../interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import "./StreamFinalityScopedProviderReads.sol";
import {
    StreamScopedSnapshotTypes as Snapshot
} from "../../interfaces/stream/metadata/StreamScopedSnapshotTypes.sol";
import {
    IStreamScopedSnapshotPublication as Snap
} from "../../interfaces/stream/metadata/IStreamScopedSnapshotPublication.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamFinalityScopeMembership as Membership
} from "../../interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import "./StreamFinalityDescriptionReads.sol";
import "./StreamFinalityConservationReads.sol";
import "../../interfaces/stream/metadata/IStreamRecordSelectionLock.sol";

/// @notice Local selected-record commitments; never recursively calls complete inputs/discovery.
/// @dev WORK/RIGHTS seals fix selected heads, not the generic append-only dossier. Source records
/// remain historical. Scoped freeze additionally requires the exact intent/snapshot locks and
/// original scoped root/membership. Whole-collection freeze is not a scoped prerequisite.
library StreamFinalityScopedMetadataFacts {
    struct LocalFacts {
        bytes32 subject;
        bytes32 rootRecordHash;
        Root.Record rootRecord;
        StreamScopeMembershipFacts membership;
        bytes32 rootSchemaId;
        StreamFinalityDescriptionEvidence descriptions;
        StreamFinalityConservationEvidence conservation;
        IStreamRecordSelectionLock.SelectionLock workLock;
        IStreamRecordSelectionLock.SelectionLock rightsLock;
        Snapshot.Receipt snapshot;
        Snapshot.Lock snapshotLock;
    }
    error NativeMetadataScope();
    error NativeMetadataSource();

    function facts(
        StreamFinalityScopedProviderReads.Config memory c,
        StreamFinalityScope memory scope
    ) public view returns (bool frozen, bytes32 dataHash) {
        if (
            scope.collectionId == 0 || block.chainid != c.chainId
                || (scope.scopeType == StreamFinalityScopeType.TOKEN
                        ? scope.tokenId == 0 || scope.scopeId != 0
                        : (scope.scopeType != StreamFinalityScopeType.RELEASE
                            && scope.scopeType != StreamFinalityScopeType.SEASON)
                        || scope.tokenId != 0 || scope.scopeId == 0)
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
        bytes memory membership = StreamFinalityBoundedReads.read(
            c.targets[3],
            abi.encodeCall(Membership.requireScopeMembership, (scope)),
            256,
            c.componentSourceGas
        );
        f.membership = abi.decode(membership, (StreamScopeMembershipFacts));
        if (
            keccak256(membership) != keccak256(abi.encode(f.membership))
                || f.membership.scopeSubject != f.subject || f.membership.membershipHash == 0
                || f.membership.tokenCount == 0 || f.membership.tokenCount > type(uint64).max
                || (scope.scopeType == StreamFinalityScopeType.TOKEN
                    && f.membership.tokenCount != 1)
        ) revert NativeMetadataSource();

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
        _root(c, scope, f);
        bool snapshotLocked = _snapshot(c, scope, f);
        // Scope-specific seals freeze this subject in an open series. The independent Core
        // component/Preparation proves its terminal scope; no whole-collection freeze is inferred.
        frozen = f.workLock.locked && f.rightsLock.locked && f.conservation.intentLock.locked
            && snapshotLocked;
        // Bind only this family's fixed graph and historical inputs, never sanction/current key,
        // complete input-manifest hash, external inventory or a self-referential component array.
        dataHash = _dataHash(c, scope, f);
    }

    function _dataHash(
        StreamFinalityScopedProviderReads.Config memory c,
        StreamFinalityScope memory scope,
        LocalFacts memory f
    ) private pure returns (bytes32 dataHash) {
        dataHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_SELECTED_METADATA_COMPONENT_V1"),
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
        StreamFinalityScopedProviderReads.Config memory c,
        StreamFinalityScope memory scope,
        LocalFacts memory f
    ) private view {
        f.rootRecordHash = abi.decode(
            _read(c, 2, abi.encodeCall(Root.scopedContentRootHead, (scope)), 32), (bytes32)
        );
        if (f.rootRecordHash == 0) revert NativeMetadataSource();
        bytes memory raw = StreamFinalityRouterEvidence.dynamicRead(
            c.targets[2],
            abi.encodeCall(Root.scopedContentRootRecord, (f.rootRecordHash)),
            8192,
            c.readGas
        );
        f.rootRecord = abi.decode(raw, (Root.Record));
        if (keccak256(raw) != keccak256(abi.encode(f.rootRecord))) revert NativeMetadataSource();
        raw = _read(c, 2, abi.encodeCall(Root.scopedTokenContentRoot, (scope)), 96);
        (bytes32 value, uint64 count, bytes32 schema) = abi.decode(raw, (bytes32, uint64, bytes32));
        if (
            keccak256(raw) != keccak256(abi.encode(value, count, schema)) || value == 0
                || value != f.rootRecord.contentRoot || count != f.rootRecord.leafCount
                || count != f.membership.tokenCount || schema == 0
                || keccak256(abi.encode(f.rootRecord.publication.scope))
                    != keccak256(abi.encode(scope)) || f.rootRecord.snapshotHost != c.targets[8]
                || f.rootRecord.snapshotCodeHash != c.codeHashes[8] || f.rootRecord.stateHash == 0
                || f.rootRecord.outputManifestHash == 0 || f.rootRecord.artistConsent == 0
                || f.rootRecord.snapshotSourceHash == 0
        ) revert NativeMetadataSource();
        f.rootSchemaId = schema;
    }

    function _seal(
        StreamFinalityScopedProviderReads.Config memory c,
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
        StreamFinalityScopedProviderReads.Config memory c,
        StreamFinalityScope memory scope,
        LocalFacts memory f
    ) private view returns (bool locked) {
        bytes memory raw = _read(c, 8, abi.encodeCall(Snap.currentSnapshot, (scope)), 544);
        f.snapshot = abi.decode(raw, (Snapshot.Receipt));
        if (
            keccak256(raw) != keccak256(abi.encode(f.snapshot)) || f.snapshot.recordHash == 0
                || f.snapshot.scopeSubject != f.subject || f.snapshot.manifestHash == 0
                || f.snapshot.recordHash != f.rootRecord.publication.snapshotRecordHash
                || f.snapshot.revision != f.rootRecord.publication.snapshotRevision
                || f.snapshot.manifestHash != f.rootRecord.snapshotManifestHash
                || f.snapshot.sourceHash != f.rootRecord.snapshotSourceHash
        ) revert NativeMetadataSource();
        raw = _read(c, 8, abi.encodeCall(Snap.snapshotLock, (scope)), 128);
        Snapshot.Lock memory l = abi.decode(raw, (Snapshot.Lock));
        if (keccak256(raw) != keccak256(abi.encode(l))) revert NativeMetadataSource();
        f.snapshotLock = l;
        if (l.actionId == 0) {
            if (l.recordHash != 0 || l.revision != 0 || l.lockedAt != 0) {
                revert NativeMetadataSource();
            }
        } else {
            if (
                l.recordHash != f.snapshot.recordHash || l.revision != f.snapshot.revision
                    || l.lockedAt < f.snapshot.recordedAt || l.lockedAt > block.timestamp
            ) revert NativeMetadataSource();
            locked = true;
        }
    }

    function _read(
        StreamFinalityScopedProviderReads.Config memory c,
        uint256 i,
        bytes memory input,
        uint256 size
    ) private view returns (bytes memory) {
        return StreamFinalityBoundedReads.read(c.targets[i], input, size, c.readGas);
    }
}
