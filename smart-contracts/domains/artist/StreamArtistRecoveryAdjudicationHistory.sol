// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistIdentityRecoveryState as State
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistRotationState as Rotations } from "./StreamArtistRotationState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import { StreamArtistDormancyState as Dormancy } from "./StreamArtistDormancyState.sol";
import {
    StreamArtistCurrentNoticeRecoveryReads as CurrentNotice
} from "./StreamArtistCurrentNoticeRecoveryReads.sol";
import {
    StreamArtistCurrentCompromiseReads as Current
} from "./StreamArtistCurrentCompromiseReads.sol";
import {
    StreamArtistRecoveryFamilyAncestry as Ancestry
} from "./StreamArtistRecoveryFamilyAncestry.sol";
import {
    StreamArtistRecoveryFamilyHistory as Family
} from "./StreamArtistRecoveryFamilyHistory.sol";
import { StreamArtistLivingRecoveryReads as Admitted } from "./StreamArtistLivingRecoveryReads.sol";
import { StreamArtistGuardianHistory as Guardians } from "./StreamArtistGuardianHistory.sol";
import { StreamArtistEstateHashes } from "./StreamArtistEstateHashes.sol";
import {
    StreamArtistRecoveryStagingHistory as Stages
} from "./StreamArtistRecoveryStagingHistory.sol";
import { StreamArtistSuccessionHashes } from "./StreamArtistSuccessionHashes.sol";
import {
    StreamArtistRecoveryRewindCapabilityReads as RewindCapabilities
} from "./StreamArtistRecoveryRewindCapabilityReads.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    IStreamArtistEstateOwner
} from "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import {
    IStreamArtistSuccessionReads
} from "../../interfaces/stream/artist/IStreamArtistSuccessionRecords.sol";
import {
    IStreamArtistNativeReceipts,
    StreamArtistHistoryTypes as Native
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistDormancyOwner,
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
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as I
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistEstateTypes as E
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    StreamArtistSuccessionTypes as Succ
} from "../../interfaces/stream/artist/StreamArtistSuccessionTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Complete original class1/class3 history for explicitly selected V2 adjudication.
/// @dev No V1 context, synthetic cause, cutoff or transition. Original native sources and
/// consumed causes are authenticated before manifest membership or guardian classification.
library StreamArtistRecoveryAdjudicationHistory {
    struct Facts {
        Current.Facts capture;
        Ancestry.Member[] members;
        D.Closure[] closures;
        V.Snapshot origin;
        E.AuthorityCapabilities capabilities;
        uint64 delegationEpoch;
        bytes32 nativeCauseProof;
        bytes32 historyProof;
    }

    struct OriginFacts {
        uint64 epoch;
        uint32 capabilities;
        bytes32 proof;
    }

    /// @dev The context separately checks the principal/new address and compares the returned
    /// exact epoch with live Estate storage. Output members contain only genuine executions.
    function read(
        State.State storage recovery,
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        Hashes.Environment memory e,
        D.Cause memory current
    ) public view returns (Facts memory f) {
        return _read(recovery, rotations, resolutions, e, current, false);
    }

    /// @notice Additive current-notice and consumed-notice source family; ordinary proofs stay exact.
    function readWithNotice(
        State.State storage recovery,
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        Dormancy.State storage dormancy,
        Hashes.Environment memory e,
        D.Cause memory current
    ) public view returns (Facts memory f, CurrentNotice.Facts memory notice) {
        if (current.facts.priorStatus == 2) notice = CurrentNotice.read(dormancy, e, current);
        f = _read(recovery, rotations, resolutions, e, current, true);
    }

    function _read(
        State.State storage recovery,
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        Hashes.Environment memory e,
        D.Cause memory current,
        bool withNotice
    ) private view returns (Facts memory f) {
        bytes32 artistId = current.facts.artistId;
        IStreamArtistOwner owner = IStreamArtistOwner(address(this));
        if (
            e.chainId != block.chainid || e.registry == address(0)
                || owner.deploymentChainId() != e.chainId || owner.artistRegistry() != e.registry
                || owner.core() != e.core || owner.mintManager() != e.manager
                || owner.domainId() != keccak256("domain:identity_authority")
                || current.causeHash == 0 || resolutions.currentCause[artistId] != current.causeHash
                || resolutions.latestResolution[artistId] != current.facts.previousResolutionHash
                || rotations.pending[artistId] != 0
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(artistId);
        }
        R.TransitionState memory executed = IStreamArtistRotationReads(address(this))
            .artistTransitionState(rotations.latestExecution[artistId]);
        f.capture = withNotice && current.facts.priorStatus == 2
            ? Current.readNotice(address(this), e.registry, e.chainId, current, executed)
            : Current.readFamily(address(this), e.registry, e.chainId, current, executed);
        f.nativeCauseProof = keccak256(
            abi.encode(
                f.capture.proof,
                _native(artistId, current.causeHash, current.facts.kind == 1 ? 33 : 31),
                current.facts.kind == 1
                    ? Stages.compromiseRevision(
                        address(this), e.registry, e.chainId, artistId, current.facts.referenceHash
                    )
                    : uint64(0)
            )
        );
        uint64 before = f.capture.pending.recordHash == 0
            ? current.facts.enteredAt
            : f.capture.pending.transition.stagedAt;
        Ancestry.Facts memory ancestry =
            Ancestry.readComplete(recovery, rotations, e, current, before);
        GH.Head memory guardians = Guardians.requireComplete(
            recovery.guardianHistory, artistId, recovery.guardianRecordsSeen[artistId]
        );
        uint64 revision = owner.ownerStateSnapshotV2().revision;
        bytes32 sources;
        bytes32 latestRecovery;
        uint64 newerEpoch;
        R.TransitionState memory originTransition;
        for (uint256 i; i + 1 < ancestry.members.length; ++i) {
            Ancestry.Member memory m = ancestry.members[i];
            V.Snapshot memory v = m.vesting;
            if (v.ownerRevision > revision || v.guardians.count > guardians.count) {
                revert I.UnsupportedIdentityRecoveryProfile(artistId);
            }
            uint64 epoch;
            bytes32 source;
            if (v.operationId == 35) {
                Admitted.Facts memory r = Admitted.readFamily(
                    address(this), e.registry, e.chainId, artistId, v.transitionRecordHash
                );
                if (
                    keccak256(abi.encode(r.vesting, r.transition))
                            != keccak256(abi.encode(v, m.transition))
                        || resolutions.causes[r.record.terms.expectedCauseHash].facts
                            .executedTransitionHash != v.previousTransitionRecordHash
                        || keccak256(abi.encode(recovery.records[v.transitionRecordHash]))
                            != keccak256(abi.encode(r.record))
                ) {
                    revert I.UnsupportedIdentityRecoveryProfile(artistId);
                }
                if (latestRecovery == 0) latestRecovery = v.transitionRecordHash;
                epoch = r.record.delegationEpoch;
                source = keccak256(
                    abi.encode(
                        r.proof,
                        _replay(
                            e,
                            artistId,
                            keccak256("identity_authority.replay.contest_resolution"),
                            keccak256(abi.encode(artistId, r.record.terms.expectedCauseHash)),
                            r.record.recordHash,
                            v.ownerRevision
                        )
                    )
                );
            } else if (v.operationId == 40 || v.operationId == 43) {
                if (f.origin.transitionRecordHash != 0 || current.facts.authorityClass != 3) {
                    revert I.UnsupportedIdentityRecoveryProfile(artistId);
                }
                OriginFacts memory origin =
                    v.operationId == 40 ? _estate(rotations, e, m) : _dormancy(rotations, e, m);
                f.origin = v;
                originTransition = m.transition;
                epoch = origin.epoch;
                source = origin.proof;
                f.capabilities.effectiveCapabilities = origin.capabilities;
            } else {
                source = _replay(
                    e,
                    artistId,
                    keccak256("identity_authority.replay.rotation_execution_key"),
                    v.transitionRecordHash,
                    v.transitionRecordHash,
                    v.ownerRevision
                );
            }
            if (epoch != 0) {
                if (newerEpoch == 0) {
                    f.delegationEpoch = epoch;
                } else if (uint256(epoch) + 1 != newerEpoch) {
                    revert I.UnsupportedIdentityRecoveryProfile(artistId);
                }
                newerEpoch = epoch;
            }
            sources = keccak256(
                abi.encode(
                    sources,
                    v.transitionRecordHash,
                    source,
                    _native(
                        artistId,
                        v.transitionRecordHash,
                        v.operationId == 32 ? 29 : v.operationId == 40 ? 38 : v.operationId
                    )
                )
            );
        }
        if (latestRecovery != recovery.latest[artistId] || (newerEpoch != 0 && newerEpoch != 1)) {
            revert I.UnsupportedIdentityRecoveryProfile(artistId);
        }
        uint32 originalCapabilities = f.capabilities.effectiveCapabilities;
        f.capabilities =
            IStreamArtistEstateOwner(address(this)).currentAuthorityCapabilities(artistId);
        bytes32 capabilityProof;
        if (current.facts.authorityClass == 3) {
            capabilityProof = RewindCapabilities.proof(
                e, artistId, f.origin, originalCapabilities, f.capabilities, ancestry.members
            );
        }
        if (
            f.capabilities.authorityAddress != current.facts.incumbent
                || f.capabilities.authorityClass != current.facts.authorityClass
                || f.capabilities.status != 4
                || (current.facts.authorityClass == 3
                        ? f.origin.transitionRecordHash == 0
                        || f.capabilities.activationRecordHash != f.origin.transitionRecordHash
                        : f.origin.transitionRecordHash != 0
                        || f.capabilities.activationRecordHash != 0)
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(artistId);
        }
        (address successor, uint64 noticeEnds, bytes32 pendingEstate) =
            IStreamArtistEstateOwner(address(this)).estateActivationState(artistId);
        if (successor != address(0) || noticeEnds != 0 || pendingEstate != 0) {
            revert I.UnsupportedIdentityRecoveryProfile(artistId);
        }
        bytes32 history = withNotice
            ? Family.readAdjudicationWithNotice(
                recovery, rotations, resolutions, e, current, ancestry, f.origin, originTransition
            )
            : Family.readAdjudication(
                recovery, rotations, resolutions, e, current, ancestry, f.origin, originTransition
            );
        // The internal final zero member proves the genuine initial authority boundary. It is
        // deliberately absent from the public manifest-membership set and cannot be declared.
        f.members = new Ancestry.Member[](ancestry.members.length - 1);
        f.closures = new D.Closure[](f.members.length);
        for (uint256 i; i < f.members.length; ++i) {
            f.members[i] = ancestry.members[i];
            f.closures[i] = resolutions.closures[f.members[i].transition.recordHash];
        }
        f.historyProof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_ADJUDICATION_HISTORY_V2"),
                e.chainId,
                e.registry,
                address(this),
                current,
                f.nativeCauseProof,
                ancestry.proof,
                sources,
                history,
                f.origin,
                f.capabilities,
                f.delegationEpoch,
                f.closures
            )
        );
        if (capabilityProof != 0) {
            f.historyProof = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_RECOVERY_CAPABILITY_ADJUDICATION_HISTORY_V3"),
                    f.historyProof,
                    capabilityProof
                )
            );
        }
    }

    function _estate(
        Rotations.State storage rotations,
        Hashes.Environment memory e,
        Ancestry.Member memory m
    ) private view returns (OriginFacts memory f) {
        V.Snapshot memory v = m.vesting;
        R.TransitionState memory t = m.transition;
        (E.RequestRecord memory r, uint8 phase, E.ExecutionFacts memory x) =
            IStreamArtistEstateOwner(address(this)).estateActivationRecord(v.transitionRecordHash);
        if (
            phase != 2 || r.recordHash != v.transitionRecordHash || r.terms.artistId != v.artistId
                || r.incumbent != v.oldAddress || r.terms.successor != v.newAddress
                || r.terms.evidenceHash == 0 || r.terms.selectedCoverageHash == 0
                || r.envelopeHash == 0 || r.requestedAt == 0 || r.noticeRevision == 0
                || r.rotationTimingRevision == 0
                || uint256(r.noticeEndsAt) != uint256(r.requestedAt) + r.noticeSeconds
                || r.postContestSeconds < 72 hours || r.standingTailSeconds < 30 days
                || StreamArtistEstateHashes.record(
                        e, r.terms, r.authorization.nonce, r.requestedAt, r.noticeEndsAt
                    ) != r.recordHash || x.activationRecordHash != r.recordHash
                || x.coverageRecordHash == 0 || x.delegationEpoch == 0
                || x.executedAt != v.executedAt || x.executedAt < r.requestedAt
                || t.stagedAt != r.requestedAt || t.contestEndsAt != r.noticeEndsAt
                || uint256(t.postWindowEndsAt) != uint256(x.executedAt) + r.postContestSeconds
                || (x.executedAt < r.noticeEndsAt
                        ? x.governanceActionId == 0 || x.governanceWitnessHash == 0
                        : x.governanceActionId != 0 || x.governanceWitnessHash != 0)
                || r.designationRecordHash == 0
                || r.terms.expectedDesignationRecordHash != r.designationRecordHash
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(v.artistId);
        }
        (uint32 caps, bytes32 plan) = _plan(
            rotations,
            e,
            v,
            r.requestedAt,
            r.designationRecordHash,
            r.pairedDirectiveRecordHash,
            r.forbiddenDirectiveRecordHash
        );
        if (caps != x.effectiveCapabilities) {
            revert I.UnsupportedIdentityRecoveryProfile(v.artistId);
        }
        f = OriginFacts(
            x.delegationEpoch,
            caps,
            keccak256(
                abi.encode(
                    r,
                    x,
                    t,
                    v,
                    plan,
                    _replay(
                        e,
                        v.artistId,
                        keccak256("identity_authority.replay.activation_execution_key"),
                        v.transitionRecordHash,
                        v.transitionRecordHash,
                        v.ownerRevision
                    )
                )
            )
        );
    }

    function _dormancy(
        Rotations.State storage rotations,
        Hashes.Environment memory e,
        Ancestry.Member memory m
    ) private view returns (OriginFacts memory f) {
        V.Snapshot memory v = m.vesting;
        R.TransitionState memory transition = m.transition;
        (bytes32 noticeHash, uint8 phase, bytes32 terminalHash) =
            IStreamArtistDormancyOwner(address(this)).dormancyNotice(v.artistId);
        (Dorm.Notice memory n, uint8 savedPhase, Dorm.Terminal memory t) =
            IStreamArtistDormancyOwner(address(this)).dormancyRecord(noticeHash);
        if (
            phase != 3 || savedPhase != 3 || terminalHash != v.transitionRecordHash
                || n.recordHash != noticeHash || n.terms.artistId != v.artistId
                || n.incumbent != v.oldAddress || n.terms.evidenceHash == 0 || n.initiatedAt == 0
                || n.actionId == 0 || n.witnessHash == 0 || n.inactivitySeconds < 365 days
                || n.noticeSeconds < 180 days || n.timingRevision == 0
                || uint256(n.noticeEndsAt) != uint256(n.initiatedAt) + n.noticeSeconds
                || uint256(n.initiatedAt) < uint256(n.priorLivenessAt) + n.inactivitySeconds
                || noticeHash != _noticeHash(e, n) || t.recordHash != terminalHash
                || t.noticeHash != noticeHash || t.authorityClass != 3 || t.plan.authorityClass != 3
                || t.plan.authority != v.newAddress || t.appointmentBlock != 0
                || t.actor == address(0) || t.evidenceHash == 0 || t.actionId == 0
                || t.witnessHash == 0 || t.observedAt < n.noticeEndsAt
                || t.observedAt != v.executedAt || t.delegationEpoch == 0 || t.plan.designation == 0
                || t.plan.stewardGrantRecordHash != 0 || t.plan.postSeconds < 72 hours
                || t.plan.standingTail < 30 days || transition.stagedAt != n.initiatedAt
                || transition.contestEndsAt != n.noticeEndsAt
                || uint256(transition.postWindowEndsAt)
                    != uint256(t.observedAt) + t.plan.postSeconds
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(v.artistId);
        }
        t.recordHash = 0;
        if (
            terminalHash
                != keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_DORMANCY_COMPLETION_V1"),
                        e.chainId,
                        e.registry,
                        address(this),
                        t
                    )
                )
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(v.artistId);
        }
        t.recordHash = terminalHash;
        Succ.DesignationRecord memory d = IStreamArtistSuccessionReads(address(this))
            .successorDesignationRecord(t.plan.designation);
        (uint32 caps, bytes32 plan) = _plan(
            rotations,
            e,
            v,
            n.initiatedAt,
            t.plan.designation,
            d.terms.directiveHash,
            t.plan.directive
        );
        if (caps != t.plan.capabilities) revert I.UnsupportedIdentityRecoveryProfile(v.artistId);
        f = OriginFacts(
            t.delegationEpoch,
            caps,
            keccak256(
                abi.encode(
                    n,
                    t,
                    transition,
                    v,
                    plan,
                    _replay(
                        e,
                        v.artistId,
                        keccak256("identity_authority.replay.dormancy_execution_key"),
                        n.recordHash,
                        v.transitionRecordHash,
                        v.ownerRevision
                    )
                )
            )
        );
    }

    function _plan(
        Rotations.State storage rotations,
        Hashes.Environment memory e,
        V.Snapshot memory v,
        uint64 before,
        bytes32 designation,
        bytes32 paired,
        bytes32 forbidden
    ) private view returns (uint32 caps, bytes32 proof) {
        IStreamArtistSuccessionReads owner = IStreamArtistSuccessionReads(address(this));
        Succ.DesignationRecord memory d = owner.successorDesignationRecord(designation);
        bool restored = IStreamArtistIdentityRecoveryOwnerV3(address(this))
            .latestRecoveryCapabilityContinuationV3(v.artistId) != 0;
        if (
            d.recordHash != designation || d.terms.artistId != v.artistId || d.authorityClass != 1
                || d.terms.successor != v.newAddress || d.terms.directiveHash != paired
                || d.signer == address(0) || d.signedAt > before
                || (v.previousTransitionRecordHash == 0 && d.signer != v.oldAddress)
                || !Rotations.eligible(rotations, v.artistId, d.provisional)
                || (!restored
                    && (owner.operativeSuccessorRecord(v.artistId) != designation
                        || owner.operativeEstateDirective(v.artistId) != forbidden))
                || StreamArtistSuccessionHashes.designationRecord(
                        e, d.terms, T.Authorization(d.nonce, d.signedAt, bytes(""))
                    ) != designation
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(v.artistId);
        }
        Succ.DirectiveRecord memory p = _directive(rotations, e, v, before, paired);
        Succ.DirectiveRecord memory x = _directive(rotations, e, v, before, forbidden);
        caps = d.terms.grantedCapabilities;
        if (paired != 0) caps &= p.terms.grantedCapabilities;
        if (forbidden != 0) caps &= ~x.terms.forbiddenCapabilities;
        if (caps & ~uint32(4095) != 0) revert I.UnsupportedIdentityRecoveryProfile(v.artistId);
        proof = keccak256(abi.encode(d, p, x, caps));
    }

    function _directive(
        Rotations.State storage rotations,
        Hashes.Environment memory e,
        V.Snapshot memory v,
        uint64 before,
        bytes32 hash
    ) private view returns (Succ.DirectiveRecord memory d) {
        d = IStreamArtistSuccessionReads(address(this)).estateDirectiveRecord(hash);
        if (hash == 0) {
            Succ.DirectiveRecord memory empty;
            if (keccak256(abi.encode(d)) != keccak256(abi.encode(empty))) {
                revert I.UnsupportedIdentityRecoveryProfile(v.artistId);
            }
        } else if (
            d.recordHash != hash || d.terms.artistId != v.artistId || d.authorityClass != 1
                || d.signer == address(0) || d.signedAt > before
                || (v.previousTransitionRecordHash == 0 && d.signer != v.oldAddress)
                || !Rotations.eligible(rotations, v.artistId, d.provisional)
                || StreamArtistSuccessionHashes.directiveRecord(
                        e, d.terms, T.Authorization(d.nonce, d.signedAt, bytes(""))
                    ) != hash
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(v.artistId);
        }
    }

    function _noticeHash(Hashes.Environment memory e, Dorm.Notice memory n)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_NOTICE_V1"),
                e.chainId,
                e.registry,
                address(this),
                n.terms,
                n.incumbent,
                n.initiatedAt,
                n.noticeEndsAt,
                n.inactivitySeconds,
                n.noticeSeconds,
                n.timingRevision,
                n.priorLivenessAt,
                n.priorActivity,
                n.actionId,
                n.witnessHash
            )
        );
    }

    function _native(bytes32 artistId, bytes32 record, uint16 operation)
        private
        view
        returns (bytes32 proof)
    {
        IStreamArtistNativeReceipts owner = IStreamArtistNativeReceipts(address(this));
        uint256 count = owner.artistNativeReceiptCount();
        bool found;
        for (uint256 i; i < count; ++i) {
            Native.Receipt memory row = owner.artistNativeReceiptAt(i);
            if (row.artistId != artistId || row.recordHash != record || row.operation != operation) continue;
            if (found || row.collectionId != 0) {
                revert I.UnsupportedIdentityRecoveryProfile(artistId);
            }
            found = true;
            proof = keccak256(abi.encode(i, row));
        }
        if (!found) revert I.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function _replay(
        Hashes.Environment memory e,
        bytes32 artistId,
        bytes32 surface,
        bytes32 scope,
        bytes32 record,
        uint64 revision
    ) private view returns (bytes32) {
        IStreamArtistOwner owner = IStreamArtistOwner(address(this));
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                e.chainId,
                e.registry,
                owner.operationCoordinator(),
                owner.archiveV2(),
                address(this),
                owner.domainId(),
                surface,
                scope
            )
        );
        T.ReplayCell memory cell = owner.replayCell(key);
        if (
            cell.commitment != record || cell.kind != 1 || cell.status != 2 || revision == 0
                || cell.touchedRevision != revision
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(artistId);
        }
        return keccak256(abi.encode(key, cell));
    }
}
