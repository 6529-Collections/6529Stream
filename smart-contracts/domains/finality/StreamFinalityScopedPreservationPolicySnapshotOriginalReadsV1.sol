// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityScopedPreservationPolicySnapshotReadsV1 as SnapshotReads
} from "./StreamFinalityScopedPreservationPolicySnapshotReadsV1.sol";
import {
    StreamPreservationPolicySnapshotFamiliesV2 as SnapshotFamilies
} from "../records/StreamPreservationPolicySnapshotFamiliesV2.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as Snapshot
} from "../../interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import { StreamFinalityRouterEvidence as Reads } from "./StreamFinalityRouterEvidence.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @dev Fixed linked worker for original scoped snapshot validation. The public reader owns the
/// nominal dependency type; this worker retains its exact source reads and validation order.
library StreamFinalityScopedPreservationPolicySnapshotOriginalReadsV1 {
    error InvalidScopedPreservationPolicySnapshotEvidence();

    function original(
        SnapshotReads.Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 recordHash,
        uint64 revision,
        bytes32 family
    ) public view returns (S.Publication memory p, S.Receipt memory r) {
        SnapshotFamilies.version2(family);
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.validationGas < d.readGas
                || recordHash == 0 || revision == 0
                || (scope.scopeType != StreamFinalityScopeType.TOKEN
                    && scope.scopeType != StreamFinalityScopeType.RELEASE
                    && scope.scopeType != StreamFinalityScopeType.SEASON)
        ) revert InvalidScopedPreservationPolicySnapshotEvidence();
        bytes32 subject = StreamMetadataSubjects.scopeSubject(d.chainId, d.core, scope);
        _pin(d.core, d.coreCodeHash);
        _pin(d.metadata, d.metadataCodeHash);
        _pin(d.router, d.routerCodeHash);
        _pin(d.snapshots, d.snapshotsCodeHash);
        if (
            _word(d, abi.encodeCall(Snapshot.core, ())) != bytes32(uint256(uint160(d.core)))
                || _word(d, abi.encodeCall(Snapshot.metadataHost, ()))
                    != bytes32(uint256(uint160(d.metadata)))
                || _word(d, abi.encodeCall(Snapshot.scopedPreservationPolicySnapshotProfile, ()))
                    != SnapshotFamilies.profile(family, true)
                || _word(d, abi.encodeCall(IERC165.supportsInterface, (type(Snapshot).interfaceId)))
                    != bytes32(uint256(1))
        ) revert InvalidScopedPreservationPolicySnapshotEvidence();
        bytes memory raw =
            Reads.read(d.snapshots, abi.encodeCall(Snapshot.dependencies, ()), 832, d.readGas);
        S.Dependencies memory source = abi.decode(raw, (S.Dependencies));
        _canonical(raw, abi.encode(source));
        if (
            source.chainId != d.chainId || source.targets[0] != d.core
                || source.targets[1] != d.metadata || source.targets[4] != d.router
                || source.codeHashes[0] != d.coreCodeHash
                || source.codeHashes[1] != d.metadataCodeHash
                || source.codeHashes[4] != d.routerCodeHash
        ) revert InvalidScopedPreservationPolicySnapshotEvidence();
        raw = Reads.dynamicRead(
            d.snapshots, abi.encodeCall(Snapshot.snapshotRecord, (recordHash)), 4096, d.readGas
        );
        (p, r) = abi.decode(raw, (S.Publication, S.Receipt));
        _canonical(raw, abi.encode(p, r));
        if (
            keccak256(abi.encode(p.scope)) != keccak256(abi.encode(scope))
                || r.scopeSubject != subject || r.recordHash != recordHash || r.revision != revision
                || p.expectedRevision == type(uint64).max || revision != p.expectedRevision + 1
                || r.predecessor != p.expectedHead
                || (revision == 1 ? r.predecessor != 0 : r.predecessor == 0) || r.chainHash == 0
                || p.snapshotId == 0 || p.outputManifestRecord == 0
                || p.coordinatorInventoryPlan == 0 || p.expectedSourceHash == 0
                || p.expectedSourceHash != r.sourceHash || r.manifestHash == 0
                || r.manifestBytes == 0 || r.manifestBytes > 524288 || r.publisher == address(0)
                || (r.authorizationClass != 7 && r.authorizationClass != 8)
                || (r.displayAuthorizationClass != 7 && r.displayAuthorizationClass != 8)
                || r.grantRevision == 0 || r.displayGrantRevision == 0 || r.recordedAt == 0
                || r.recordedAt > block.timestamp || p.effectiveAt == 0
                || p.effectiveAt > r.recordedAt || p.reasonHash == 0
                || bytes(p.manifestURI).length > 2048
                || r.schemaHash != SnapshotFamilies.hashes(family, true)[0]
                || r.profileHash != SnapshotFamilies.hashes(family, true)[1]
                || r.canonicalizationHash != SnapshotFamilies.hashes(family, true)[2]
        ) revert InvalidScopedPreservationPolicySnapshotEvidence();
        S.Receipt memory committed = abi.decode(abi.encode(r), (S.Receipt));
        committed.recordHash = 0;
        committed.chainHash = 0;
        if (
            keccak256(
                    abi.encode(
                        SnapshotFamilies.recordDomain(family, true),
                        d.chainId,
                        d.snapshots,
                        d.core,
                        d.metadata,
                        p,
                        committed
                    )
                ) != recordHash
        ) revert InvalidScopedPreservationPolicySnapshotEvidence();
    }

    function _word(SnapshotReads.Dependencies memory d, bytes memory input)
        private
        view
        returns (bytes32)
    {
        return abi.decode(Reads.read(d.snapshots, input, 32, d.readGas), (bytes32));
    }

    function _pin(address target, bytes32 expected) private view {
        if (target.code.length == 0 || target.codehash != expected) {
            revert InvalidScopedPreservationPolicySnapshotEvidence();
        }
    }

    function _canonical(bytes memory supplied, bytes memory expected) private pure {
        if (keccak256(supplied) != keccak256(expected)) {
            revert InvalidScopedPreservationPolicySnapshotEvidence();
        }
    }
}
