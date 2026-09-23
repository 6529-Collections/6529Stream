// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistLivingRecoveryReads } from "./StreamArtistLivingRecoveryReads.sol";
import { StreamArtistRotationHashes } from "./StreamArtistRotationHashes.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistGuardianVestingHistory
} from "../../interfaces/stream/artist/IStreamArtistGuardianVestingHistory.sol";
import {
    IStreamArtistGuardianHistory
} from "../../interfaces/stream/artist/IStreamArtistGuardianHistory.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";

/// @notice Fixed-owner living recovery ancestry of an original designated dormancy appointment.
/// @dev The caller authenticates the original notice/completion/snapshot and any required closures.
/// This reader follows actual vesting links; it does not infer ancestry from mutable retirement.
library StreamArtistLivingDormancyReads {
    struct Environment {
        address owner;
        address registry;
        uint256 chainId;
        bool imported;
        Runtime.Context clock;
    }

    function beforeDormancy(
        address owner,
        address registry,
        uint256 chainId,
        Dorm.Notice memory n,
        Dorm.Terminal memory t,
        V.Snapshot memory v,
        bytes32 expectedLatestLiving
    ) public view returns (StreamArtistLivingRecoveryReads.Facts memory living, bytes32 proof) {
        return _beforeDormancy(owner, registry, chainId, n, t, v, expectedLatestLiving, false);
    }

    /// @notice Full ancestry proof, including the original zero/rotation-only family.
    /// @dev Only new cancelled-notice history uses this additional proof. Existing callers keep
    /// the original zero result for that family through beforeDormancy().
    function withInitialHistory(
        address owner,
        address registry,
        uint256 chainId,
        Dorm.Notice memory n,
        Dorm.Terminal memory t,
        V.Snapshot memory v,
        bytes32 expectedLatestLiving
    ) public view returns (StreamArtistLivingRecoveryReads.Facts memory living, bytes32 proof) {
        return _beforeDormancy(owner, registry, chainId, n, t, v, expectedLatestLiving, true);
    }

    function _beforeDormancy(
        address owner,
        address registry,
        uint256 chainId,
        Dorm.Notice memory n,
        Dorm.Terminal memory t,
        V.Snapshot memory v,
        bytes32 expectedLatestLiving,
        bool includeInitial
    ) private view returns (StreamArtistLivingRecoveryReads.Facts memory living, bytes32 proof) {
        bytes32 artistId = n.terms.artistId;
        Environment memory e;
        e.owner = owner;
        e.registry = registry;
        e.chainId = chainId;
        e.imported = Recovered.active(owner);
        if (e.imported) e.clock = Recovered.load(owner, registry, chainId);
        if (
            chainId != block.chainid || owner.code.length == 0 || registry == address(0)
                || IStreamArtistOwner(owner).deploymentChainId() != chainId
                || IStreamArtistOwner(owner).artistRegistry() != registry || artistId == 0
                || n.recordHash == 0 || n.incumbent == address(0) || n.initiatedAt == 0
                || t.noticeHash != n.recordHash || t.recordHash == 0 || t.authorityClass != 3
                || t.plan.authorityClass != 3 || t.delegationEpoch == 0 || v.artistId != artistId
                || v.transitionRecordHash != t.recordHash || v.operationId != 43
                || v.authorityClass != 3 || v.oldAddress != n.incumbent
                || v.newAddress != t.plan.authority || v.executedAt != t.observedAt
                || v.ownerRevision == 0 || v.commitment == 0 || v.commitment != _vestingHash(e, v)
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        bytes32 history = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_LIVING_DORMANCY_ANCESTRY_V1"),
                chainId,
                registry,
                owner,
                n,
                t,
                v
            )
        );
        V.Snapshot memory child = v;
        uint64 before = n.initiatedAt;
        while (child.previousTransitionRecordHash != 0) {
            V.Snapshot memory previous = IStreamArtistGuardianVestingHistory(owner)
                .guardianVestingSnapshot(artistId, child.previousTransitionRecordHash);
            _link(e, child, previous, before);
            if (previous.operationId == 35) {
                living = StreamArtistLivingRecoveryReads.read(
                    owner, registry, chainId, artistId, previous.transitionRecordHash
                );
                if (
                    keccak256(abi.encode(living.vesting)) != keccak256(abi.encode(previous))
                        || (expectedLatestLiving != 0
                            && living.record.recordHash != expectedLatestLiving)
                        || uint256(living.record.delegationEpoch) + 1 != uint256(t.delegationEpoch)
                        || living.record.fields.recoveredAt > n.initiatedAt
                ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
                return (living, keccak256(abi.encode(history, living.proof)));
            }
            if (previous.operationId != 32) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
            R.RotationRecord memory rotation =
                IStreamArtistRotationReads(owner).rotationRecord(previous.transitionRecordHash);
            _rotation(e, previous, rotation);
            history = keccak256(abi.encode(history, previous, rotation));
            before = rotation.transition.stagedAt;
            child = previous;
            // _link requires strictly decreasing authenticated owner points, so this walk
            // cannot cycle and needs no arbitrary ceiling on legitimate rotation history.
        }
        if (child.previousCommitment != 0 || expectedLatestLiving != 0) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
        // Old zero/rotation-only ancestry has no living-recovery wrapper.
        return (living, includeInitial ? history : bytes32(0));
    }

    function _link(
        Environment memory e,
        V.Snapshot memory child,
        V.Snapshot memory previous,
        uint64 before
    ) private view {
        if (
            previous.artistId != child.artistId
                || previous.transitionRecordHash != child.previousTransitionRecordHash
                || previous.commitment == 0 || previous.commitment != child.previousCommitment
                || previous.commitment != _vestingHash(e, previous) || previous.authorityClass != 1
                || previous.oldAddress == address(0) || previous.newAddress != child.oldAddress
                || previous.oldAddress == previous.newAddress || previous.executedAt == 0
                || previous.executedAt > before || previous.executedAt > child.executedAt
                || previous.ownerRevision == 0 || !_before(e, previous, child)
                || (!e.imported && previous.ownerRevision <= previous.guardians.ownerRevision)
                || previous.guardians.count > child.guardians.count
                || (!e.imported && previous.guardians.ownerRevision > child.guardians.ownerRevision)
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(child.artistId);
        }
        _prefix(e, previous);
    }

    function _rotation(Environment memory e, V.Snapshot memory v, R.RotationRecord memory r)
        private
        view
    {
        R.TransitionState memory t = r.transition;
        StreamArtistHashes.Environment memory original =
            StreamArtistHashes.Environment(e.chainId, e.registry, address(0), address(0));
        if (e.imported) {
            Runtime.ReceiptFact memory stage =
                Recovered.nativeFact(e.clock, 29, v.artistId, r.recordHash);
            if (!Runtime.before(e.clock, stage.position.point, Recovered.vesting(e.clock, v).point))
            {
                revert Recovery.UnsupportedIdentityRecoveryProfile(v.artistId);
            }
            original = Recovered.hashes(stage.environment);
        }
        if (
            r.recordHash != v.transitionRecordHash || r.terms.artistId != v.artistId
                || r.terms.oldAddress != v.oldAddress || r.terms.newAddress != v.newAddress
                || t.artistId != v.artistId || t.recordHash != r.recordHash || t.phase != 2
                || t.stagedAt == 0 || t.executedAt != v.executedAt || t.executedAt < t.stagedAt
                || r.effectiveWindow < 72 hours || r.standingTail < 30 days || r.timingRevision == 0
                || uint256(t.contestEndsAt) != uint256(t.stagedAt) + r.effectiveWindow
                || uint256(t.postWindowEndsAt) != uint256(t.executedAt) + r.effectiveWindow
                || (t.executedAt < t.contestEndsAt
                    && (r.approvalThreshold == 0 || r.guardianApprovals < r.approvalThreshold))
                || StreamArtistRotationHashes.rotationRecord(
                        original, r.terms, r.oldNonce, t.stagedAt, t.contestEndsAt
                    ) != r.recordHash
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(v.artistId);
        // An early original compromise is legitimate if later closed. The caller proves that
        // closure at the next authority boundary; this ancestry reader must not reject its marker.
    }

    function _prefix(Environment memory e, V.Snapshot memory v) private view {
        (GH.Head memory head, GH.Entry memory last,,) = IStreamArtistGuardianHistory(e.owner)
            .guardianHistoryState(v.artistId, v.guardians.count, address(0), bytes32(0));
        // The fixed getter requires the complete current head and resolves the exact saved index.
        if (v.guardians.count > head.count) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(v.artistId);
        }
        if (v.guardians.count == 0) {
            if (v.guardians.ownerRevision != 0 || v.guardians.commitment != 0) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(v.artistId);
            }
        } else if (
            v.guardians.ownerRevision == 0 || v.guardians.commitment == 0
                || (!e.imported && v.guardians.ownerRevision > head.ownerRevision)
                || last.artistId != v.artistId || last.index != v.guardians.count
                || last.ownerRevision != v.guardians.ownerRevision
                || last.commitment != v.guardians.commitment || last.recordHash == 0
                || last.recordDataHash == 0
                || (!e.imported
                    && last.commitment
                        != keccak256(
                            abi.encode(
                                keccak256("6529STREAM_ARTIST_GUARDIAN_ADMISSION_HISTORY_V1"),
                                e.chainId,
                                e.registry,
                                e.owner,
                                last.artistId,
                                last.index,
                                last.ownerRevision,
                                last.recordHash,
                                last.recordDataHash,
                                last.previousCommitment
                            )
                        ))
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(v.artistId);
        }
    }

    function _vestingHash(Environment memory e, V.Snapshot memory v)
        private
        view
        returns (bytes32)
    {
        if (e.imported) {
            Recovered.vesting(e.clock, v);
            return v.commitment;
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

    function _before(Environment memory e, V.Snapshot memory a, V.Snapshot memory b)
        private
        view
        returns (bool)
    {
        if (!e.imported) return a.ownerRevision < b.ownerRevision;
        return Runtime.before(
            e.clock, Recovered.vesting(e.clock, a).point, Recovered.vesting(e.clock, b).point
        );
    }
}
