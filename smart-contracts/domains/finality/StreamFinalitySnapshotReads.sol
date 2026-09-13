// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/finality/StreamFinalitySnapshotTypes.sol";
import "../../interfaces/stream/finality/IStreamArtworkFinalityRegistry.sol";
import "../../interfaces/stream/metadata/IStreamCollectionSnapshots.sol";
import "../records/StreamSnapshotDefinitions.sol";
import "./StreamFinalityRouterEvidence.sol";

/// @notice Current native snapshot evidence from a fixed actual authenticated producer.
/// @dev The producer revalidates complete source/manifest bytes. This is not archive coverage,
///      entropy-output proof, arbitrary JavaScript closure or full aggregate finality readiness.
library StreamFinalitySnapshotReads {
    struct Dependencies {
        address core;
        address metadata;
        address snapshots;
        bytes32 coreCodeHash;
        bytes32 metadataCodeHash;
        bytes32 snapshotsCodeHash;
        uint256 chainId;
        uint256 readGas;
        uint256 validationGas;
    }
    error InvalidSnapshotEvidence();

    function requireCurrent(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 recordHash,
        uint64 revision
    ) public view returns (StreamFinalitySnapshotEvidence memory e) {
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.validationGas < d.readGas
                || scope.scopeType != StreamFinalityScopeType.COLLECTION || scope.collectionId == 0
                || scope.tokenId != 0 || scope.scopeId != 0 || recordHash == 0 || revision == 0
        ) {
            revert InvalidSnapshotEvidence();
        }
        _pin(d.core, d.coreCodeHash);
        _pin(d.metadata, d.metadataCodeHash);
        _pin(d.snapshots, d.snapshotsCodeHash);
        if (
            _word(d, abi.encodeCall(IStreamCollectionSnapshots.core, ()))
                    != bytes32(uint256(uint160(d.core)))
                || _word(d, abi.encodeCall(IStreamCollectionSnapshots.metadataHost, ()))
                    != bytes32(uint256(uint160(d.metadata)))
        ) {
            revert InvalidSnapshotEvidence();
        }
        bytes memory raw = StreamFinalityRouterEvidence.dynamicRead(
            d.snapshots,
            abi.encodeCall(IStreamCollectionSnapshots.snapshotRecord, (recordHash)),
            4096,
            d.readGas
        );
        (StreamSnapshotTypes.Publication memory p, StreamSnapshotTypes.Receipt memory r) =
            abi.decode(raw, (StreamSnapshotTypes.Publication, StreamSnapshotTypes.Receipt));
        _canonical(raw, abi.encode(p, r));
        _original(d, scope, p, r, recordHash, revision);
        raw = StreamFinalityRouterEvidence.read(
            d.snapshots,
            abi.encodeCall(
                IStreamCollectionSnapshots.requireCurrent,
                (scope.collectionId, recordHash, revision)
            ),
            672,
            d.validationGas
        );
        if (keccak256(raw) != keccak256(abi.encode(r))) revert InvalidSnapshotEvidence();
        (bool locked, bytes32 locksHash) = _locks(d, r);
        e = StreamFinalitySnapshotEvidence(
            0,
            recordHash,
            r.manifestHash,
            r.sourceHash,
            r.inventoryPlan,
            r.schemaDefinitionHash,
            r.profileDefinitionHash,
            r.canonicalizationDefinitionHash,
            revision,
            r.manifestBytes,
            r.publisher,
            r.authorizationClass,
            r.grantRevision,
            r.displayAuthorizationClass,
            r.displayGrantRevision,
            locked,
            locksHash
        );
        e.inputHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_NATIVE_SNAPSHOT_INPUT_V1"),
                d.chainId,
                d.core,
                d.metadata,
                d.snapshots,
                d.snapshotsCodeHash,
                scope,
                e
            )
        );
    }

    function requireLocked(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 recordHash,
        uint64 revision
    ) public view returns (StreamFinalitySnapshotEvidence memory e) {
        e = requireCurrent(d, scope, recordHash, revision);
        if (!e.locked) revert InvalidSnapshotEvidence();
    }

    function _original(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        StreamSnapshotTypes.Publication memory p,
        StreamSnapshotTypes.Receipt memory r,
        bytes32 recordHash,
        uint64 revision
    ) private pure {
        if (
            r.recordHash != recordHash || r.collectionId != scope.collectionId
                || p.collectionId != r.collectionId || r.revision != revision
                || r.revision != p.expectedRevision + 1 || r.predecessor != p.expectedHead
                || r.snapshotId == 0 || r.snapshotId != p.snapshotId || r.manifestHash == 0
                || r.manifestBytes == 0 || r.manifestBytes > 524288 || r.sourceHash == 0
                || r.sourceHash != p.expectedSourceHash || r.inventoryPlan == 0
                || r.inventoryPlan != p.inventoryPlan || r.publisher == address(0)
                || (r.authorizationClass != 7 && r.authorizationClass != 8)
                || (r.displayAuthorizationClass != 7 && r.displayAuthorizationClass != 8)
                || r.grantRevision == 0 || r.displayGrantRevision == 0 || r.recordedAt == 0
                || r.effectiveAt == 0 || r.effectiveAt != p.effectiveAt
                || r.effectiveAt > r.recordedAt || r.reasonHash == 0 || r.reasonHash != p.reasonHash
                || r.recordChainHash == 0 || bytes(p.manifestURI).length > 2048
                || r.schemaDefinitionHash != StreamSnapshotDefinitions.SCHEMA_HASH
                || r.profileDefinitionHash != StreamSnapshotDefinitions.PROFILE_HASH
                || r.canonicalizationDefinitionHash != StreamSnapshotDefinitions.CANON_HASH
        ) {
            revert InvalidSnapshotEvidence();
        }
        bytes32 savedHash = r.recordHash;
        bytes32 savedChain = r.recordChainHash;
        r.recordHash = 0;
        r.recordChainHash = 0;
        bytes32 computed = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_SNAPSHOT_RECORD_V1"),
                d.chainId,
                d.snapshots,
                d.core,
                d.metadata,
                p,
                r
            )
        );
        r.recordHash = savedHash;
        r.recordChainHash = savedChain;
        if (computed != recordHash) revert InvalidSnapshotEvidence();
    }

    function _locks(Dependencies memory d, StreamSnapshotTypes.Receipt memory r)
        private
        view
        returns (bool locked, bytes32 hash)
    {
        bytes32[3] memory ids = [
            keccak256("SNAPSHOTS"), keccak256("METADATA_ALL"), keccak256("SNAPSHOT_NATIVE_ONCHAIN")
        ];
        StreamSnapshotTypes.Lock[3] memory rows;
        for (uint256 i; i < 3; ++i) {
            bytes memory raw = StreamFinalityRouterEvidence.read(
                d.snapshots,
                abi.encodeCall(IStreamCollectionSnapshots.snapshotLock, (r.collectionId, ids[i])),
                128,
                d.readGas
            );
            rows[i] = abi.decode(raw, (StreamSnapshotTypes.Lock));
            _canonical(raw, abi.encode(rows[i]));
            if (rows[i].actionId == 0) {
                if (rows[i].recordHash != 0 || rows[i].revision != 0 || rows[i].lockedAt != 0) {
                    revert InvalidSnapshotEvidence();
                }
            } else {
                if (
                    rows[i].recordHash != r.recordHash || rows[i].revision != r.revision
                        || rows[i].lockedAt < r.recordedAt
                ) revert InvalidSnapshotEvidence();
                locked = true;
            }
        }
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_NATIVE_SNAPSHOT_LOCKS_V1"),
                d.chainId,
                d.snapshots,
                r.collectionId,
                r.recordHash,
                r.revision,
                ids,
                rows
            )
        );
    }

    function _word(Dependencies memory d, bytes memory input) private view returns (bytes32) {
        return abi.decode(
            StreamFinalityRouterEvidence.read(d.snapshots, input, 32, d.readGas), (bytes32)
        );
    }

    function _pin(address target, bytes32 codeHash) private view {
        if (target.code.length == 0 || codeHash == 0 || target.codehash != codeHash) {
            revert InvalidSnapshotEvidence();
        }
    }

    function _canonical(bytes memory a, bytes memory b) private pure {
        if (a.length != b.length || keccak256(a) != keccak256(b)) revert InvalidSnapshotEvidence();
    }
}
