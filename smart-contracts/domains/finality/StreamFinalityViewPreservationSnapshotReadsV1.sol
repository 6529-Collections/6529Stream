// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import {
    StreamViewPreservationSnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamViewPreservationSnapshotTypesV1.sol";
import {
    IStreamViewPreservationSnapshotPublicationV1 as I
} from "../../interfaces/stream/metadata/IStreamViewPreservationSnapshotPublicationV1.sol";
import {
    StreamViewPreservationSnapshotDefinitionsV1 as Definitions
} from "../records/StreamViewPreservationSnapshotDefinitionsV1.sol";
import { StreamFinalityRouterEvidence as Reads } from "./StreamFinalityRouterEvidence.sol";

/// @notice Distinct root-free current/locked VIEW preservation snapshot evidence for the selected provider.
/// @dev The immutable host proves complete policy/output/current payload; this is not a V1 receipt.
library StreamFinalityViewPreservationSnapshotReadsV1 {
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

    struct Evidence {
        bytes32 inputHash;
        S.Receipt receipt;
        bytes32 adoptionRecord;
        bytes32 outputManifestRecord;
        S.Source source;
        bool locked;
        bytes32 lockHash;
    }
    error InvalidViewPreservationSnapshotEvidence();

    function requireCurrent(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 hash,
        uint64 revision
    ) public view returns (Evidence memory e) {
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.validationGas < d.readGas
                || scope.scopeType != StreamFinalityScopeType.VIEW || scope.collectionId == 0
                || scope.tokenId != 0 || scope.scopeId == 0 || hash == 0 || revision == 0
        ) revert InvalidViewPreservationSnapshotEvidence();
        _pin(d.core, d.coreCodeHash);
        _pin(d.metadata, d.metadataCodeHash);
        _pin(d.snapshots, d.snapshotsCodeHash);
        if (
            _word(d, abi.encodeCall(I.core, ())) != bytes32(uint256(uint160(d.core)))
                || _word(d, abi.encodeCall(I.metadataHost, ()))
                    != bytes32(uint256(uint160(d.metadata)))
        ) revert InvalidViewPreservationSnapshotEvidence();
        bytes memory raw = Reads.dynamicRead(
            d.snapshots, abi.encodeCall(I.snapshotRecord, (hash)), 4096, d.readGas
        );
        (S.Publication memory p, S.Receipt memory r) = abi.decode(raw, (S.Publication, S.Receipt));
        _canonical(raw, abi.encode(p, r));
        _original(d, scope, p, r, hash, revision);
        raw = Reads.read(
            d.snapshots,
            abi.encodeCall(I.requireCurrent, (scope, hash, revision)),
            544,
            d.validationGas
        );
        _canonical(raw, abi.encode(r));
        raw = Reads.read(d.snapshots, abi.encodeCall(I.snapshotLock, (scope)), 128, d.readGas);
        S.Lock memory locked = abi.decode(raw, (S.Lock));
        _canonical(raw, abi.encode(locked));
        if (locked.actionId == 0) {
            if (locked.recordHash != 0 || locked.revision != 0 || locked.lockedAt != 0) {
                revert InvalidViewPreservationSnapshotEvidence();
            }
        } else {
            if (
                locked.recordHash != hash || locked.revision != revision
                    || locked.lockedAt < r.recordedAt
            ) revert InvalidViewPreservationSnapshotEvidence();
            e.locked = true;
        }
        e.receipt = r;
        e.adoptionRecord = p.expectedAdoptionRecord;
        e.outputManifestRecord = p.outputManifestRecord;
        e.source = _payload(d, p, r);
        e.lockHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_SNAPSHOT_LOCK_V1"),
                d.chainId,
                d.snapshots,
                scope,
                locked
            )
        );
        e.inputHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_SNAPSHOT_INPUT_V1"),
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
        bytes32 hash,
        uint64 revision
    ) public view returns (Evidence memory e) {
        e = requireCurrent(d, scope, hash, revision);
        if (!e.locked) revert InvalidViewPreservationSnapshotEvidence();
    }

    function _original(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        S.Publication memory p,
        S.Receipt memory r,
        bytes32 hash,
        uint64 revision
    ) private pure {
        if (
            keccak256(abi.encode(p.scope)) != keccak256(abi.encode(scope))
                || r.scopeSubject != StreamMetadataSubjects.scopeSubject(d.chainId, d.core, scope)
                || r.recordHash != hash || r.revision != revision
                || p.expectedRevision == type(uint64).max || r.revision != p.expectedRevision + 1
                || r.predecessor != p.expectedHead || p.snapshotId == 0
                || p.expectedAdoptionRecord == 0 || p.outputManifestRecord == 0
                || r.manifestHash == 0 || r.manifestBytes == 0 || r.manifestBytes > 524288
                || r.sourceHash == 0 || r.sourceHash != p.expectedSourceHash || r.chainHash == 0
                || r.publisher == address(0)
                || (r.authorizationClass != 7 && r.authorizationClass != 8)
                || (r.displayAuthorizationClass != 7 && r.displayAuthorizationClass != 8)
                || r.grantRevision == 0 || r.displayGrantRevision == 0 || r.recordedAt == 0
                || p.effectiveAt == 0 || p.effectiveAt > r.recordedAt || p.reasonHash == 0
                || bytes(p.manifestURI).length > 2048 || r.schemaHash != Definitions.SCHEMA_HASH
                || r.profileHash != Definitions.PROFILE_HASH
                || r.canonicalizationHash != Definitions.CANON_HASH
        ) revert InvalidViewPreservationSnapshotEvidence();
        bytes32 chainHash = r.chainHash;
        r.recordHash = 0;
        r.chainHash = 0;
        if (
            keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_SNAPSHOT_RECORD_V1"),
                        d.chainId,
                        d.snapshots,
                        d.core,
                        d.metadata,
                        p,
                        r
                    )
                ) != hash
        ) revert InvalidViewPreservationSnapshotEvidence();
        // memory arguments alias: restore caller's authenticated receipt before later comparisons.
        r.recordHash = hash;
        r.chainHash = chainHash;
    }

    function _payload(Dependencies memory d, S.Publication memory p, S.Receipt memory r)
        private
        view
        returns (S.Source memory source)
    {
        bytes memory carrier = Reads.dynamicRead(
            d.snapshots,
            abi.encodeCall(I.snapshotPayload, (r.recordHash)),
            uint256(r.manifestBytes) + 96,
            d.validationGas
        );
        bytes memory raw = abi.decode(carrier, (bytes));
        _canonical(carrier, abi.encode(raw));
        if (raw.length != r.manifestBytes || keccak256(raw) != r.manifestHash) {
            revert InvalidViewPreservationSnapshotEvidence();
        }
        bytes32 domain;
        uint256 chain;
        address host;
        address[10] memory targets;
        bytes32[10] memory pins;
        S.Publication memory saved;
        S.Receipt memory fields;
        (domain, chain, host, targets, pins, saved, fields, source) = abi.decode(
            raw,
            (
                bytes32,
                uint256,
                address,
                address[10],
                bytes32[10],
                S.Publication,
                S.Receipt,
                S.Source
            )
        );
        _canonical(raw, abi.encode(domain, chain, host, targets, pins, saved, fields, source));
        S.Dependencies memory dependencies = abi.decode(
            Reads.read(d.snapshots, abi.encodeCall(I.dependencies, ()), 768, d.readGas),
            (S.Dependencies)
        );
        if (
            domain != keccak256("6529STREAM_VIEW_PRESERVATION_SNAPSHOT_PAYLOAD_V1")
                || chain != d.chainId || host != d.snapshots || targets[0] != d.core
                || targets[1] != d.metadata || pins[0] != d.coreCodeHash
                || pins[1] != d.metadataCodeHash || dependencies.chainId != chain
                || keccak256(abi.encode(targets, pins))
                    != keccak256(abi.encode(dependencies.targets, dependencies.codeHashes))
                || keccak256(abi.encode(source.scope)) != keccak256(abi.encode(p.scope))
                || source.adoption.adoption.recordHash != p.expectedAdoptionRecord
                || source.outputs.recordHash != p.outputManifestRecord
                || source.checkpoint.contentRoot == 0 || source.checkpoint.outputRoot == 0
                || sourceHash(d.snapshots, chain, targets, pins, source) != r.sourceHash
        ) {
            revert InvalidViewPreservationSnapshotEvidence();
        }
        // All five post-retention fields and only the circular expected source input are zero
        // in the original canonical payload. Deep-copy to preserve the caller's receipt.
        S.Receipt memory expected = abi.decode(abi.encode(r), (S.Receipt));
        expected.recordHash = 0;
        expected.chainHash = 0;
        expected.manifestHash = 0;
        expected.manifestBytes = 0;
        expected.recordedAt = 0;
        S.Publication memory normalized = abi.decode(abi.encode(p), (S.Publication));
        normalized.expectedSourceHash = 0;
        _canonical(abi.encode(saved, fields), abi.encode(normalized, expected));
    }

    function sourceHash(
        address snapshots,
        uint256 chain,
        address[10] memory targets,
        bytes32[10] memory pins,
        S.Source memory source
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_SNAPSHOT_SOURCES_V1"),
                chain,
                snapshots,
                targets,
                pins,
                source
            )
        );
    }

    function _word(Dependencies memory d, bytes memory input) private view returns (bytes32) {
        return abi.decode(Reads.read(d.snapshots, input, 32, d.readGas), (bytes32));
    }

    function _pin(address target, bytes32 hash) private view {
        if (target.code.length == 0 || hash == 0 || target.codehash != hash) {
            revert InvalidViewPreservationSnapshotEvidence();
        }
    }

    function _canonical(bytes memory a, bytes memory b) private pure {
        if (a.length != b.length || keccak256(a) != keccak256(b)) {
            revert InvalidViewPreservationSnapshotEvidence();
        }
    }
}
