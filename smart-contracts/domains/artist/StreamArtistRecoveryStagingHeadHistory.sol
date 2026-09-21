// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveryStagingEstateHistory as Worker
} from "./StreamArtistRecoveryStagingEstateHistory.sol";

import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import { StreamArtistRotationHashes } from "./StreamArtistRotationHashes.sol";
import { StreamArtistEstateHashes } from "./StreamArtistEstateHashes.sol";
import { StreamArtistIdentityRecoveryHashes } from "./StreamArtistIdentityRecoveryHashes.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistNativeReceipts,
    StreamArtistHistoryTypes as H
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    IStreamArtistEstateOwner
} from "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistIdentityContestOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import {
    IStreamArtistGuardianVestingHistory
} from "../../interfaces/stream/artist/IStreamArtistGuardianVestingHistory.sol";
import {
    IStreamArtistDormancyOwner,
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistEstateTypes as Estate
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistIdentityContestTypes as C
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";

import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

import {
    StreamArtistRecoveryStagingHistory as Original
} from "./StreamArtistRecoveryStagingHistory.sol";

/// @notice Fixed typed historical checks at their original call positions.
library StreamArtistRecoveryStagingHeadHistory {
    function _head(Original.Environment memory e, bytes32 artistId, H.Receipt memory row)
        public
        view
        returns (Original.Head memory h)
    {
        h.recordHash = row.recordHash;
        h.operation = row.operation;
        if (h.recordHash == 0) return h;
        if (e.imported) {
            h.point =
            Recovered.nativeFact(e.clock, row.operation, artistId, row.recordHash).position.point;
        }
        if (row.operation == 29) {
            (, T.ReplayCell memory cell, bytes32 proof) = _rotation(e, artistId, row.recordHash);
            h.ownerRevision = cell.touchedRevision;
            h.proof = proof;
        } else if (row.operation == 38) {
            (Estate.RequestRecord memory r,,) =
                IStreamArtistEstateOwner(e.owner).estateActivationRecord(row.recordHash);
            _request(e, artistId, row.recordHash, r);
            T.ReplayCell memory cell = _replay(
                e,
                artistId,
                keccak256("identity_authority.replay.activation_request_key"),
                row.recordHash,
                row.recordHash
            );
            h.ownerRevision = cell.touchedRevision;
            h.proof = keccak256(abi.encode(row, r, cell));
        } else {
            V.Snapshot memory v = IStreamArtistGuardianVestingHistory(e.owner)
                .guardianVestingSnapshot(artistId, row.recordHash);
            if (
                (row.operation != 35 && row.operation != 43) || v.artistId != artistId
                    || v.transitionRecordHash != row.recordHash || v.operationId != row.operation
                    || v.ownerRevision == 0 || (!e.imported && v.ownerRevision > e.revision)
                    || v.executedAt == 0 || v.commitment == 0 || v.commitment != _vestingHash(e, v)
            ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            R.TransitionState memory t =
                IStreamArtistRotationReads(e.owner).artistTransitionState(row.recordHash);
            if (
                t.artistId != artistId || t.recordHash != row.recordHash || t.phase != 2
                    || t.executedAt != v.executedAt
            ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            h.ownerRevision = v.ownerRevision;
            h.proof = keccak256(abi.encode(row, v));
        }
        if (e.imported && h.point.ownerRevision != h.ownerRevision) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
    }

    function _rotation(Original.Environment memory e, bytes32 artistId, bytes32 hash)
        public
        view
        returns (R.RotationRecord memory r, T.ReplayCell memory cell, bytes32 proof)
    {
        r = IStreamArtistRotationReads(e.owner).rotationRecord(hash);
        R.TransitionState memory t = r.transition;
        if (
            hash == 0 || r.recordHash != hash || r.terms.artistId != artistId
                || t.artistId != artistId || t.recordHash != hash || t.stagedAt == 0
                || r.terms.oldAddress == address(0) || r.terms.newAddress == address(0)
                || r.terms.oldAddress == r.terms.newAddress
                || uint256(t.contestEndsAt) != uint256(t.stagedAt) + r.effectiveWindow
                || hash
                    != StreamArtistRotationHashes.rotationRecord(
                        _recordEnvironment(e, artistId, 29, hash),
                        r.terms,
                        r.oldNonce,
                        t.stagedAt,
                        t.contestEndsAt
                    )
                || keccak256(abi.encode(t))
                    != keccak256(
                        abi.encode(IStreamArtistRotationReads(e.owner).artistTransitionState(hash))
                    )
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        cell = _replay(
            e,
            artistId,
            keccak256("identity_authority.replay.rotation_key"),
            keccak256(abi.encode(artistId, hash)),
            hash
        );
        if (e.imported) {
            Runtime.ReplayFact memory admitted = _replayAt(
                e,
                keccak256("identity_authority.replay.rotation_key"),
                keccak256(abi.encode(artistId, hash)),
                hash
            );
            if (!Recovered.samePoint(
                    admitted.admission.point,
                    Recovered.nativeFact(e.clock, 29, artistId, hash).position.point
                )) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
        }
        proof = keccak256(
            abi.encode(
                r.recordHash,
                r.terms,
                r.guardianSetRecordHash,
                r.approvalThreshold,
                r.oldNonce,
                r.newNonce,
                r.effectiveWindow,
                r.standingTail,
                r.timingRevision,
                t.stagedAt,
                t.contestEndsAt,
                cell
            )
        );
    }

    function _request(
        Original.Environment memory e,
        bytes32 artistId,
        bytes32 hash,
        Estate.RequestRecord memory r
    ) public view {
        if (
            hash == 0 || r.recordHash != hash || r.terms.artistId != artistId
                || r.incumbent == address(0) || r.terms.successor == address(0)
                || r.terms.successor == r.incumbent || r.terms.evidenceHash == 0
                || r.requestedAt == 0 || r.noticeRevision == 0 || r.rotationTimingRevision == 0
                || uint256(r.noticeEndsAt) != uint256(r.requestedAt) + r.noticeSeconds
                || r.designationRecordHash == 0
                || r.terms.expectedDesignationRecordHash != r.designationRecordHash
                || r.terms.selectedCoverageHash == 0 || r.envelopeHash == 0
                || hash
                    != StreamArtistEstateHashes.record(
                        _recordEnvironment(e, artistId, 38, hash),
                        r.terms,
                        r.authorization.nonce,
                        r.requestedAt,
                        r.noticeEndsAt
                    )
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function _replay(
        Original.Environment memory e,
        bytes32 artistId,
        bytes32 surface,
        bytes32 scope,
        bytes32 commitment
    ) private view returns (T.ReplayCell memory cell) {
        if (e.imported) return _replayAt(e, surface, scope, commitment).cell;
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                e.chainId,
                e.registry,
                e.coordinator,
                e.archive,
                e.owner,
                e.domain,
                surface,
                scope
            )
        );
        cell = IStreamArtistOwner(e.owner).replayCell(key);
        if (
            cell.commitment != commitment || cell.kind != 1 || cell.status != 2
                || cell.touchedRevision == 0 || cell.touchedRevision > e.revision
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function _replayAt(
        Original.Environment memory e,
        bytes32 surface,
        bytes32 scope,
        bytes32 commitment
    ) private view returns (Runtime.ReplayFact memory f) {
        f = Runtime.replay(e.clock, RH.originHash(e.clock.current), surface, scope);
        if (
            commitment == 0 || f.cell.commitment != commitment || f.cell.kind != 1
                || f.cell.status != 2
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(commitment);
        }
    }

    function _recordEnvironment(
        Original.Environment memory e,
        bytes32 artistId,
        uint16 operation,
        bytes32 record
    ) private view returns (StreamArtistHashes.Environment memory) {
        if (!e.imported) return _hashEnvironment(e);
        return
            Recovered.hashes(Recovered.nativeFact(e.clock, operation, artistId, record).environment);
    }

    function _hashEnvironment(Original.Environment memory e)
        private
        pure
        returns (StreamArtistHashes.Environment memory)
    {
        return StreamArtistHashes.Environment(e.chainId, e.registry, address(0), address(0));
    }

    function _vestingHash(Original.Environment memory e, V.Snapshot memory v)
        private
        view
        returns (bytes32)
    {
        if (e.imported) {
            Runtime.OriginFact memory origin = Recovered.vesting(e.clock, v);
            return Recovered.vestingHash(origin.environment, v);
        }
        return keccak256(
            bytes.concat(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_V1"),
                    e.chainId,
                    e.registry,
                    e.owner
                ),
                abi.encode(
                    v.artistId,
                    v.transitionRecordHash,
                    v.operationId,
                    v.ownerRevision,
                    v.executedAt,
                    v.oldAddress,
                    v.newAddress,
                    v.authorityClass,
                    v.guardians,
                    v.previousTransitionRecordHash,
                    v.previousCommitment
                )
            )
        );
    }

    function _select(
        Original.Environment memory e,
        bytes32 artistId,
        bytes32 target,
        uint16 targetOperation
    ) public view returns (H.Receipt memory selected) {
        IStreamArtistNativeReceipts source = IStreamArtistNativeReceipts(e.owner);
        uint256 count =
            e.imported ? Runtime.logicalCount(e.clock) : source.artistNativeReceiptCount();
        for (uint256 i; i < count; ++i) {
            H.Receipt memory row = _row(e, i);
            if (row.artistId != artistId) continue;
            if (target != 0 && row.operation == targetOperation && row.recordHash == target) {
                if (row.collectionId != 0) {
                    revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
                }
                return selected;
            }
            if (row.operation == 35) {
                Recovery.Record memory r = IStreamArtistIdentityRecoveryOwner(e.owner)
                    .identityRecoveryRecord(row.recordHash);
                _recovery(e, artistId, row.recordHash, r);
                if (++i >= count) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
                H.Receipt memory secondary = _row(e, i);
                if (
                    secondary.operation != 35 || secondary.artistId != artistId
                        || secondary.collectionId != 0
                        || secondary.recordHash != r.fields.supersededRecordsHash
                ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            } else if (row.operation != 29 && row.operation != 38 && row.operation != 43) {
                continue;
            }
            if (row.collectionId != 0 || row.recordHash == 0) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
            selected = row;
        }
        if (target != 0) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function _recovery(
        Original.Environment memory e,
        bytes32 artistId,
        bytes32 hash,
        Recovery.Record memory r
    ) private view {
        StreamArtistHashes.Environment memory original = _recordEnvironment(e, artistId, 35, hash);
        if (
            hash == 0 || r.recordHash != hash || r.fields.artistId != artistId
                || hash
                    != StreamArtistIdentityRecoveryHashes.record(
                        original.chainId, original.registry, r.fields
                    )
                || r.fields.supersededRecordsHash
                    != StreamArtistIdentityRecoveryHashes.supersession(
                        r.terms.supersededRecordHashes
                    )
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function _row(Original.Environment memory e, uint256 index)
        private
        view
        returns (H.Receipt memory)
    {
        return e.imported
            ? Runtime.receiptAt(e.clock, index).receipt
            : IStreamArtistNativeReceipts(e.owner).artistNativeReceiptAt(index);
    }
}
