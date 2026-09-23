// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistIdentityRecoveryState as RecoveryState
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistRotationState as Rotations } from "./StreamArtistRotationState.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import { StreamArtistRotationHashes } from "./StreamArtistRotationHashes.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";
import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    IStreamArtistGuardianHistory
} from "../../interfaces/stream/artist/IStreamArtistGuardianHistory.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
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
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as I
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

/// @notice Exact executed ancestry for current recovery-family staging and closure proofs.
/// @dev The fixed caller separately authenticates each supplied original35/40/43 source and
/// capability origin. This reader binds their actual owner records and every intervening32.
library StreamArtistRecoveryFamilyAncestry {
    struct Member {
        V.Snapshot vesting;
        R.TransitionState transition;
        address incumbent;
        uint64 before;
    }

    struct Facts {
        Member[] members;
        bytes32 proof;
    }

    /// @notice Complete original chain for explicit V2 adjudication, including earlier35s.
    /// @dev The final zero tuple is an internal authority boundary, never a declared vesting.
    /// The caller authenticates each non32 source and all cause/closure/staging history.
    function readComplete(
        RecoveryState.State storage recovery,
        Rotations.State storage rotations,
        Hashes.Environment memory e,
        D.Cause memory current,
        uint64 terminalBefore
    ) public view returns (Facts memory f) {
        bytes32 artistId = current.facts.artistId;
        bytes32 head = rotations.latestExecution[artistId];
        if (
            e.chainId != block.chainid || e.registry == address(0) || artistId == 0
                || (current.facts.authorityClass != 1 && current.facts.authorityClass != 3)
                || current.facts.incumbent == address(0)
                || current.facts.executedTransitionHash != head
                || recovery.vestingHistory.latest[artistId] != head || terminalBefore == 0
                || terminalBefore > current.facts.enteredAt
                || current.facts.enteredAt > block.timestamp
        ) revert I.UnsupportedIdentityRecoveryProfile(artistId);
        uint256 count = 1;
        bytes32 cursor = head;
        bytes32 child;
        while (cursor != 0) {
            V.Snapshot memory v = recovery.vestingHistory.snapshots[cursor];
            if (
                v.transitionRecordHash != cursor || v.artistId != artistId || v.ownerRevision == 0
                    || (child != 0 && !_before(e, v, recovery.vestingHistory.snapshots[child]))
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(artistId);
            }
            child = cursor;
            cursor = v.previousTransitionRecordHash;
            ++count;
        }
        f.members = new Member[](count);
        cursor = head;
        address incumbent = current.facts.incumbent;
        uint8 authorityClass = current.facts.authorityClass;
        uint64 before_ = terminalBefore;
        bytes32 proof;
        for (uint256 i; i < count; ++i) {
            Member memory m;
            bytes32 source;
            if (cursor == 0) {
                V.Snapshot memory emptyV;
                R.TransitionState memory emptyT;
                if (
                    authorityClass != 1 || (recovery.latest[artistId] != 0 && i == 0)
                        || keccak256(abi.encode(recovery.vestingHistory.snapshots[bytes32(0)]))
                            != keccak256(abi.encode(emptyV))
                        || keccak256(
                                abi.encode(
                                    IStreamArtistRotationReads(address(this))
                                        .artistTransitionState(0)
                                )
                            ) != keccak256(abi.encode(emptyT))
                ) {
                    revert I.UnsupportedIdentityRecoveryProfile(artistId);
                }
                m.incumbent = incumbent;
            } else {
                V.Snapshot memory v = recovery.vestingHistory.snapshots[cursor];
                if (v.operationId == 32) {
                    (m, source) = _rotation(recovery, rotations, e, artistId, cursor);
                } else {
                    R.TransitionState memory t =
                        IStreamArtistRotationReads(address(this)).artistTransitionState(cursor);
                    _anchor(recovery, e, v, t, artistId);
                    m.vesting = v;
                    m.transition = t;
                    m.incumbent = v.newAddress;
                    source = keccak256(abi.encode(v, t));
                }
                if (
                    v.authorityClass != authorityClass || m.incumbent != incumbent
                        || m.transition.executedAt > before_
                        || (i == 0 && rotations.retirement[artistId][v.oldAddress] != head)
                ) {
                    revert I.UnsupportedIdentityRecoveryProfile(artistId);
                }
                if (v.operationId == 40 || v.operationId == 43) authorityClass = 1;
                bytes32 parentHash = v.previousTransitionRecordHash;
                if (parentHash != 0) {
                    V.Snapshot memory parent = recovery.vestingHistory.snapshots[parentHash];
                    _snapshot(recovery, e, parent, artistId);
                    if (
                        parent.transitionRecordHash != parentHash
                            || parent.commitment != v.previousCommitment
                            || parent.authorityClass != authorityClass
                            || parent.newAddress != v.oldAddress || !_before(e, parent, v)
                            || parent.executedAt > m.transition.stagedAt
                            || parent.guardians.count > v.guardians.count
                            || !_prefixOrder(e, artistId, parent.guardians, v.guardians)
                    ) {
                        revert I.UnsupportedIdentityRecoveryProfile(artistId);
                    }
                } else if (v.previousCommitment != 0 || authorityClass != 1) {
                    revert I.UnsupportedIdentityRecoveryProfile(artistId);
                }
                cursor = parentHash;
                incumbent = v.oldAddress;
            }
            m.before = before_;
            f.members[i] = m;
            proof = keccak256(abi.encode(proof, source, m));
            before_ = m.vesting.operationId == 43 ? m.transition.executedAt : m.transition.stagedAt;
        }
        f.proof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_COMPLETE_ANCESTRY_V2"),
                e.chainId,
                e.registry,
                address(this),
                current,
                terminalBefore,
                proof
            )
        );
    }

    function read(
        RecoveryState.State storage recovery,
        Rotations.State storage rotations,
        Hashes.Environment memory e,
        D.Cause memory current,
        V.Snapshot memory origin,
        R.TransitionState memory originTransition,
        uint64 terminalBefore
    ) public view returns (Facts memory) {
        V.Snapshot memory bridge;
        R.TransitionState memory bridgeTransition;
        return _read(
            recovery,
            rotations,
            e,
            current,
            origin,
            originTransition,
            bridge,
            bridgeTransition,
            terminalBefore
        );
    }

    function readWithBridge(
        RecoveryState.State storage recovery,
        Rotations.State storage rotations,
        Hashes.Environment memory e,
        D.Cause memory current,
        V.Snapshot memory origin,
        R.TransitionState memory originTransition,
        V.Snapshot memory bridge,
        R.TransitionState memory bridgeTransition,
        uint64 terminalBefore
    ) public view returns (Facts memory) {
        return _read(
            recovery,
            rotations,
            e,
            current,
            origin,
            originTransition,
            bridge,
            bridgeTransition,
            terminalBefore
        );
    }

    function _read(
        RecoveryState.State storage recovery,
        Rotations.State storage rotations,
        Hashes.Environment memory e,
        D.Cause memory current,
        V.Snapshot memory origin,
        R.TransitionState memory originTransition,
        V.Snapshot memory bridge,
        R.TransitionState memory bridgeTransition,
        uint64 terminalBefore
    ) private view returns (Facts memory f) {
        bytes32 artistId = current.facts.artistId;
        bytes32 head = rotations.latestExecution[artistId];
        if (
            e.chainId != block.chainid || e.registry == address(0) || artistId == 0
                || (current.facts.authorityClass != 1 && current.facts.authorityClass != 3)
                || current.facts.incumbent == address(0)
                || current.facts.executedTransitionHash != head
                || recovery.vestingHistory.latest[artistId] != head || terminalBefore == 0
                || terminalBefore > current.facts.enteredAt
                || current.facts.enteredAt > block.timestamp
        ) revert I.UnsupportedIdentityRecoveryProfile(artistId);

        bytes32 root = origin.transitionRecordHash;
        bytes32 crossing = bridge.transitionRecordHash;
        if (root == 0) {
            _empty(origin, originTransition, artistId);
            if (
                recovery.latest[artistId] != 0
                    || (crossing == 0 && current.facts.authorityClass != 1)
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(artistId);
            }
        } else {
            _anchor(recovery, e, origin, originTransition, artistId);
            if (origin.operationId == 35 && recovery.latest[artistId] != root) {
                revert I.UnsupportedIdentityRecoveryProfile(artistId);
            }
        }
        if (crossing == 0) {
            _empty(bridge, bridgeTransition, artistId);
            if (root != 0 && origin.authorityClass != current.facts.authorityClass) {
                revert I.UnsupportedIdentityRecoveryProfile(artistId);
            }
        } else {
            _anchor(recovery, e, bridge, bridgeTransition, artistId);
            if (
                current.facts.authorityClass != 3 || bridge.authorityClass != 3 || crossing == root
                    || (bridge.operationId != 40 && bridge.operationId != 43)
                    || (root != 0 && (origin.operationId != 35 || origin.authorityClass != 1))
            ) revert I.UnsupportedIdentityRecoveryProfile(artistId);
        }

        f.members = new Member[](
            _length(recovery, e, artistId, head, root, crossing, current.facts.authorityClass)
        );
        bytes32 cursor = head;
        address incumbent = current.facts.incumbent;
        uint64 before_ = terminalBefore;
        bytes32 chain;
        for (uint256 i; i < f.members.length; ++i) {
            Member memory m;
            bytes32 item;
            if (cursor == 0) {
                // There was no execution here. Retain actual zero tuples, not a fabricated vesting.
                if (root != 0 || i + 1 != f.members.length || incumbent == address(0)) {
                    revert I.UnsupportedIdentityRecoveryProfile(artistId);
                }
                m.incumbent = incumbent;
            } else if (cursor == root) {
                m.vesting = origin;
                m.transition = originTransition;
                m.incumbent = origin.newAddress;
                item = keccak256(abi.encode(origin, originTransition));
            } else if (cursor == crossing) {
                m.vesting = bridge;
                m.transition = bridgeTransition;
                m.incumbent = bridge.newAddress;
                item = keccak256(abi.encode(bridge, bridgeTransition));
            } else {
                (m, item) = _rotation(recovery, rotations, e, artistId, cursor);
                if (i == 0 && rotations.retirement[artistId][m.vesting.oldAddress] != head) {
                    revert I.UnsupportedIdentityRecoveryProfile(artistId);
                }
            }
            m.before = before_;
            if (m.incumbent != incumbent || m.transition.executedAt > before_) {
                revert I.UnsupportedIdentityRecoveryProfile(artistId);
            }
            f.members[i] = m;
            chain = keccak256(abi.encode(chain, item, m));
            if (i + 1 == f.members.length) {
                if (cursor != root) revert I.UnsupportedIdentityRecoveryProfile(artistId);
            } else {
                _parent(recovery, e, m, root, crossing);
                cursor = m.vesting.previousTransitionRecordHash;
                incumbent = m.vesting.oldAddress;
                // A completed43 can retain genuine notice-period class1/status2 episodes.
                // Their membership bound is completion; notice-entry eligibility is proved
                // independently by the family history. An estate request cannot survive33.
                before_ = m.vesting.transitionRecordHash == crossing && m.vesting.operationId == 43
                    ? m.transition.executedAt
                    : m.transition.stagedAt;
            }
        }
        f.proof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_FAMILY_ANCESTRY_V1"),
                e.chainId,
                e.registry,
                address(this),
                current,
                origin,
                originTransition,
                bridge,
                bridgeTransition,
                terminalBefore,
                chain
            )
        );
    }

    /// @dev Count only actual linked records. Strictly decreasing revisions bound both passes
    /// and reject cycles; no supplied prefix or arbitrary maximum can truncate the ancestry.
    function _length(
        RecoveryState.State storage recovery,
        Hashes.Environment memory e,
        bytes32 artistId,
        bytes32 head,
        bytes32 root,
        bytes32 bridge,
        uint8 authorityClass
    ) private view returns (uint256 count) {
        count = 1;
        bytes32 cursor = head;
        bytes32 child;
        bool crossed = bridge == 0;
        while (cursor != root) {
            V.Snapshot memory v = recovery.vestingHistory.snapshots[cursor];
            if (
                cursor == 0 || v.artistId != artistId || v.transitionRecordHash != cursor
                    || v.ownerRevision == 0
                    || (child != 0 && !_before(e, v, recovery.vestingHistory.snapshots[child]))
                    || v.authorityClass != authorityClass
            ) revert I.UnsupportedIdentityRecoveryProfile(artistId);
            if (cursor == bridge) {
                if (crossed || (v.operationId != 40 && v.operationId != 43)) {
                    revert I.UnsupportedIdentityRecoveryProfile(artistId);
                }
                crossed = true;
                authorityClass = 1;
            } else if (v.operationId != 32) {
                revert I.UnsupportedIdentityRecoveryProfile(artistId);
            }
            child = cursor;
            cursor = v.previousTransitionRecordHash;
            ++count;
        }
        if (!crossed || (root == 0 && authorityClass != 1)) {
            revert I.UnsupportedIdentityRecoveryProfile(artistId);
        }
    }

    function _anchor(
        RecoveryState.State storage recovery,
        Hashes.Environment memory e,
        V.Snapshot memory v,
        R.TransitionState memory t,
        bytes32 artistId
    ) private view {
        _snapshot(recovery, e, v, artistId);
        if (
            (v.operationId != 35 && v.operationId != 40 && v.operationId != 43)
                || (v.operationId != 35 && v.authorityClass != 3)
                || keccak256(abi.encode(recovery.vestingHistory.snapshots[v.transitionRecordHash]))
                    != keccak256(abi.encode(v))
                || keccak256(
                        abi.encode(
                            IStreamArtistRotationReads(address(this))
                                .artistTransitionState(v.transitionRecordHash)
                        )
                    ) != keccak256(abi.encode(t)) || t.artistId != artistId
                || t.recordHash != v.transitionRecordHash || t.phase != 2
                || t.executedAt != v.executedAt || t.stagedAt == 0 || t.executedAt < t.stagedAt
        ) revert I.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function _rotation(
        RecoveryState.State storage recovery,
        Rotations.State storage rotations,
        Hashes.Environment memory e,
        bytes32 artistId,
        bytes32 hash
    ) private view returns (Member memory m, bytes32 proof) {
        V.Snapshot memory v = recovery.vestingHistory.snapshots[hash];
        R.RotationRecord memory r = rotations.rotations[hash];
        R.TransitionState memory t = r.transition;
        _snapshot(recovery, e, v, artistId);
        Hashes.Environment memory original = e;
        if (Imported.commitment() != 0) {
            Runtime.Context memory clock = Recovered.load(address(this), e.registry, e.chainId);
            Runtime.ReceiptFact memory stage = Recovered.nativeFact(clock, 29, artistId, hash);
            Runtime.OriginFact memory vested = Recovered.vesting(clock, v);
            if (!Runtime.before(clock, stage.position.point, vested.point)) {
                revert I.UnsupportedIdentityRecoveryProfile(artistId);
            }
            original = Recovered.hashes(stage.environment);
        }
        if (
            v.transitionRecordHash != hash || v.operationId != 32 || r.recordHash != hash
                || r.terms.artistId != artistId || r.terms.oldAddress != v.oldAddress
                || r.terms.newAddress != v.newAddress || t.artistId != artistId
                || t.recordHash != hash || t.phase != 2 || t.stagedAt == 0
                || t.executedAt != v.executedAt || t.executedAt < t.stagedAt
                || r.effectiveWindow < 72 hours || r.standingTail < 30 days || r.timingRevision == 0
                || uint256(t.contestEndsAt) != uint256(t.stagedAt) + r.effectiveWindow
                || uint256(t.postWindowEndsAt) != uint256(t.executedAt) + r.effectiveWindow
                || (t.executedAt < t.contestEndsAt
                    && (r.approvalThreshold == 0 || r.guardianApprovals < r.approvalThreshold))
                || StreamArtistRotationHashes.rotationRecord(
                        original, r.terms, r.oldNonce, t.stagedAt, t.contestEndsAt
                    ) != hash
        ) revert I.UnsupportedIdentityRecoveryProfile(artistId);
        // expectedPrevious may be zero for the first32, or an original cancelled staging record.
        // The family staging proof independently selects that exact original staging predecessor.
        m.vesting = v;
        m.transition = t;
        m.incumbent = v.newAddress;
        proof = keccak256(abi.encode(r, v));
    }

    function _parent(
        RecoveryState.State storage recovery,
        Hashes.Environment memory e,
        Member memory child,
        bytes32 root,
        bytes32 bridge
    ) private view {
        V.Snapshot memory v = child.vesting;
        bytes32 hash = v.previousTransitionRecordHash;
        uint8 authorityClass = v.transitionRecordHash == bridge ? 1 : v.authorityClass;
        if (hash == 0) {
            if (root != 0 || authorityClass != 1 || v.previousCommitment != 0) {
                revert I.UnsupportedIdentityRecoveryProfile(v.artistId);
            }
            return;
        }
        V.Snapshot memory parent = recovery.vestingHistory.snapshots[hash];
        _snapshot(recovery, e, parent, v.artistId);
        if (
            parent.transitionRecordHash != hash || parent.commitment != v.previousCommitment
                || parent.newAddress != v.oldAddress || !_before(e, parent, v)
                || parent.executedAt > child.transition.stagedAt
                || parent.guardians.count > v.guardians.count
                || !_prefixOrder(e, v.artistId, parent.guardians, v.guardians)
                || parent.authorityClass != authorityClass
                || (hash != root && hash != bridge && parent.operationId != 32)
        ) revert I.UnsupportedIdentityRecoveryProfile(v.artistId);
    }

    function _snapshot(
        RecoveryState.State storage recovery,
        Hashes.Environment memory e,
        V.Snapshot memory v,
        bytes32 artistId
    ) private view {
        if (
            v.artistId != artistId || v.transitionRecordHash == 0 || v.ownerRevision == 0
                || v.executedAt == 0 || v.oldAddress == address(0) || v.newAddress == address(0)
                || v.oldAddress == v.newAddress || (v.authorityClass != 1 && v.authorityClass != 3)
                || (Imported.commitment() == 0 && v.ownerRevision <= v.guardians.ownerRevision)
                || v.commitment == 0 || v.commitment != _vesting(e, v)
                || (v.previousTransitionRecordHash == 0) != (v.previousCommitment == 0)
        ) revert I.UnsupportedIdentityRecoveryProfile(artistId);
        GH.Head memory h = v.guardians;
        if (h.count == 0) {
            if (h.ownerRevision != 0 || h.commitment != 0) {
                revert I.UnsupportedIdentityRecoveryProfile(artistId);
            }
        } else {
            bytes32 last = recovery.guardianHistory.records[artistId][h.count];
            GH.Entry memory entry = recovery.guardianHistory.entries[last];
            if (
                last == 0 || entry.artistId != artistId || entry.recordHash != last
                    || entry.index != h.count || entry.ownerRevision != h.ownerRevision
                    || entry.commitment != h.commitment || h.commitment == 0
                    || h.count > recovery.guardianRecordsSeen[artistId]
            ) revert I.UnsupportedIdentityRecoveryProfile(artistId);
        }
    }

    function _before(Hashes.Environment memory e, V.Snapshot memory first, V.Snapshot memory second)
        private
        view
        returns (bool)
    {
        if (Imported.commitment() == 0) return first.ownerRevision < second.ownerRevision;
        Runtime.Context memory clock = Recovered.load(address(this), e.registry, e.chainId);
        Runtime.OriginFact memory a = Recovered.vesting(clock, first);
        Runtime.OriginFact memory b = Recovered.vesting(clock, second);
        return Runtime.before(clock, a.point, b.point);
    }

    function _prefixOrder(
        Hashes.Environment memory e,
        bytes32 artistId,
        GH.Head memory first,
        GH.Head memory second
    ) private view returns (bool) {
        if (Imported.commitment() == 0) {
            return first.ownerRevision <= second.ownerRevision;
        }
        if (first.count > second.count) return false;
        if (first.count == second.count) {
            return keccak256(abi.encode(first)) == keccak256(abi.encode(second));
        }
        if (first.count == 0) return first.ownerRevision == 0 && first.commitment == 0;
        Runtime.Context memory clock = Recovered.load(address(this), e.registry, e.chainId);
        (, GH.Entry memory earlier,,) = IStreamArtistGuardianHistory(address(this))
            .guardianHistoryState(artistId, first.count, address(0), 0);
        (, GH.Entry memory later,,) = IStreamArtistGuardianHistory(address(this))
            .guardianHistoryState(artistId, second.count, address(0), 0);
        Runtime.OriginFact memory a = Recovered.guardianEntry(clock, earlier);
        Runtime.OriginFact memory b = Recovered.guardianEntry(clock, later);
        return Runtime.before(clock, a.point, b.point);
    }

    function _empty(V.Snapshot memory v, R.TransitionState memory t, bytes32 artistId)
        private
        pure
    {
        V.Snapshot memory emptyV;
        R.TransitionState memory emptyT;
        if (keccak256(abi.encode(v, t)) != keccak256(abi.encode(emptyV, emptyT))) {
            revert I.UnsupportedIdentityRecoveryProfile(artistId);
        }
    }

    function _vesting(Hashes.Environment memory e, V.Snapshot memory v)
        private
        view
        returns (bytes32)
    {
        if (Imported.commitment() != 0) {
            Runtime.Context memory clock = Recovered.load(address(this), e.registry, e.chainId);
            Runtime.OriginFact memory original = Recovered.vesting(clock, v);
            return Recovered.vestingHash(original.environment, v);
        }
        return keccak256(
            bytes.concat(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_V1"),
                    e.chainId,
                    e.registry,
                    address(this)
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
}
