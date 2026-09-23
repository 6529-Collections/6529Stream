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

import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

import {
    StreamArtistRecoveryAdjudicationHistory as Original
} from "./StreamArtistRecoveryAdjudicationHistory.sol";

/// @notice Fixed typed worker preserving the original validation and caller context.
library StreamArtistRecoveryAdjudicationOrigins {
    function _estate(
        Rotations.State storage rotations,
        Hashes.Environment memory e,
        Ancestry.Member memory m
    ) public view returns (Original.OriginFacts memory f) {
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
                        _original(e, 38, v.artistId, r.recordHash),
                        r.terms,
                        r.authorization.nonce,
                        r.requestedAt,
                        r.noticeEndsAt
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
        f = Original.OriginFacts(
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
    ) public view returns (Original.OriginFacts memory f) {
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
        Hashes.Environment memory completion = _original(e, 43, v.artistId, terminalHash);
        address completionOwner = _originalOwner(e, 43, v.artistId, terminalHash);
        t.recordHash = 0;
        if (
            terminalHash
                != keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_DORMANCY_COMPLETION_V1"),
                        completion.chainId,
                        completion.registry,
                        completionOwner,
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
        f = Original.OriginFacts(
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
                        _original(e, 36, v.artistId, designation),
                        d.terms,
                        T.Authorization(d.nonce, d.signedAt, bytes(""))
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
                        _original(e, 37, v.artistId, hash),
                        d.terms,
                        T.Authorization(d.nonce, d.signedAt, bytes(""))
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
        address originalOwner = _originalOwner(e, 41, n.terms.artistId, n.recordHash);
        e = _original(e, 41, n.terms.artistId, n.recordHash);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_NOTICE_V1"),
                e.chainId,
                e.registry,
                originalOwner,
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

    function _original(
        Hashes.Environment memory e,
        uint16 operation,
        bytes32 artistId,
        bytes32 record
    ) private view returns (Hashes.Environment memory) {
        if (Imported.commitment() == 0) return e;
        Runtime.Context memory clock = Recovered.load(address(this), e.registry, e.chainId);
        return
            Recovered.hashes(Recovered.nativeFact(clock, operation, artistId, record).environment);
    }

    function _originalOwner(
        Hashes.Environment memory e,
        uint16 operation,
        bytes32 artistId,
        bytes32 record
    ) private view returns (address) {
        if (Imported.commitment() == 0) return address(this);
        Runtime.Context memory clock = Recovered.load(address(this), e.registry, e.chainId);
        return Recovered.nativeFact(clock, operation, artistId, record).environment.owners[2];
    }

    function _native(bytes32 artistId, bytes32 record, uint16 operation)
        public
        view
        returns (bytes32 proof)
    {
        if (Imported.commitment() != 0) {
            IStreamArtistOwner source = IStreamArtistOwner(address(this));
            Runtime.Context memory clock =
                Recovered.load(address(this), source.artistRegistry(), source.deploymentChainId());
            return keccak256(abi.encode(Recovered.nativeFact(clock, operation, artistId, record)));
        }
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
    ) public view returns (bytes32) {
        IStreamArtistOwner owner = IStreamArtistOwner(address(this));
        if (Imported.commitment() != 0) {
            Runtime.Context memory clock = Recovered.load(address(this), e.registry, e.chainId);
            Runtime.ReplayFact memory replay =
                Runtime.replay(clock, RH.originHash(clock.current), surface, scope);
            Runtime.OriginFact memory original = Runtime.auxiliary(
                clock, keccak256("identity_authority.hydration.guardian_vesting"), record
            );
            if (
                replay.cell.kind != 1 || replay.cell.status != 2 || replay.cell.commitment != record
                    || revision == 0 || original.point.ownerRevision != revision
                    || !Recovered.samePoint(replay.admission.point, original.point)
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(artistId);
            }
            return keccak256(abi.encode(replay, original));
        }
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
