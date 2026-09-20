// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecoveryRewindState as Rewind } from "./StreamArtistRecoveryRewindState.sol";
import { StreamArtistIdentityState as Identity } from "./StreamArtistIdentityState.sol";
import { StreamArtistEstateState as Estate } from "./StreamArtistEstateState.sol";
import { StreamArtistDormancyState as Dormancy } from "./StreamArtistDormancyState.sol";
import { StreamArtistHashes as H } from "./StreamArtistHashes.sol";
import {
    StreamArtistRecoveryFamilyAncestry as Ancestry
} from "./StreamArtistRecoveryFamilyAncestry.sol";
import { StreamArtistLivingRecoveryReads as Living } from "./StreamArtistLivingRecoveryReads.sol";
import {
    StreamArtistRecoveryRewindEnvironment as Environment
} from "./StreamArtistRecoveryRewindEnvironment.sol";
import {
    StreamArtistRecoveryRewindRecordReads as Records
} from "./StreamArtistRecoveryRewindRecordReads.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistEstateTypes as E
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistRecoveryActionTypes as Action
} from "../../interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";
import {
    IStreamArtistRecoveryActionOwner
} from "../../interfaces/stream/artist/IStreamArtistRecoveryAction.sol";
import {
    IStreamArtistRecoveryRewindEvidence
} from "../../interfaces/stream/artist/IStreamArtistRecoveryRewindEvidence.sol";
import {
    IStreamArtistRecoveryRewindSelection
} from "../../interfaces/stream/artist/IStreamArtistRecoveryRewindSelection.sol";
import {
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";

import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";

/// @notice Current estate bounds restored by an actual V3 recovery, with the original origin intact.
/// @dev The cheap owner read uses its own committed state. The full history proof independently
/// joins the original35 and its immutable completed plan; it never re-runs a current selection.
library StreamArtistRecoveryRewindCapabilityReads {
    struct SavedPlan {
        W.CapabilityContinuationV3 continuation;
        W.EvidenceStateV3 evidence;
        W.ResolutionManifestV3 manifest;
        W.ResultV3 selected;
        W.BasisV3 basis;
        W.ProgressV3 progress;
        Living.Facts recovered;
        Runtime.OriginFact original;
        Runtime.OriginFact preparation;
        W.EnvironmentV3 sourceEnvironment;
        bool imported;
    }

    function current(
        Rewind.State storage rewind,
        Identity.State storage identity,
        Estate.State storage estate,
        Dormancy.State storage dormancy,
        bytes32 artistId
    ) public view returns (E.AuthorityCapabilities memory f) {
        T.Identity storage p = identity.identities[artistId];
        if (
            p.authorityClass != 3 || (p.status != 3 && p.status != 4)
                || p.authorityAddress == address(0)
                || identity.activeIdentity[p.authorityAddress] != artistId
        ) {
            revert T.InvalidIdentity(artistId);
        }
        f = E.AuthorityCapabilities(p.authorityAddress, 3, p.status, 0, bytes32(0));
        bytes32 origin = dormancy.activation[artistId];
        if (origin != 0) {
            Dorm.Terminal storage terminal = dormancy.terminals[origin];
            Dorm.Notice storage notice = dormancy.notices[terminal.noticeHash];
            if (
                terminal.recordHash != origin || terminal.authorityClass != 3
                    || terminal.plan.authorityClass != 3 || terminal.plan.authority == address(0)
                    || notice.terms.artistId != artistId
                    || dormancy.phases[terminal.noticeHash] != 3
                    || dormancy.terminalForNotice[terminal.noticeHash] != origin
                    || terminal.observedAt == 0 || terminal.delegationEpoch == 0
            ) revert T.InvalidIdentity(artistId);
            f.effectiveCapabilities = terminal.plan.capabilities;
        } else {
            origin = estate.authorityActivation[artistId];
            E.RequestRecord storage request = estate.requests[origin];
            E.ExecutionFacts storage execution = estate.executions[origin];
            if (
                origin == 0 || estate.phases[origin] != 2 || request.recordHash != origin
                    || request.terms.artistId != artistId
                    || execution.activationRecordHash != origin || execution.executedAt == 0
                    || execution.delegationEpoch == 0
            ) revert T.InvalidIdentity(artistId);
            f.effectiveCapabilities = execution.effectiveCapabilities;
        }
        f.activationRecordHash = origin;
        bytes32 head = rewind.capabilityHead[artistId];
        if (head == 0) return f;
        W.CapabilityContinuationV3 memory c = rewind.capabilityContinuations[head];
        W.EnvironmentV3 memory e = _environment();
        if (Imported.commitment() != 0) {
            e = Runtime.rewindEnvironment(_origin(e, head).environment);
        }
        if (
            c.artistId != artistId || c.recoveryRecordHash != head || c.actionId == 0
                || c.manifestHash == 0 || c.planCommitment == 0 || c.designationRecordHash == 0
                || c.originalActivationRecordHash != origin
                || c.originalActivationCapabilities != f.effectiveCapabilities
                || c.effectiveCapabilities & ~uint32(4095) != 0 || c.authorityAddress == address(0)
                || c.commitment == 0 || W.capabilityContinuationHash(e, c) != c.commitment
        ) {
            revert W.InvalidRecoveryRewindRecord(head);
        }
        // A later rotation changes the live address, not the restored capability ceiling.
        f.effectiveCapabilities = c.effectiveCapabilities;
    }

    function proof(
        H.Environment memory originalEnvironment,
        bytes32 artistId,
        V.Snapshot memory origin,
        uint32 originalMask,
        E.AuthorityCapabilities memory live,
        Ancestry.Member[] memory members
    ) public view returns (bytes32) {
        IStreamArtistIdentityRecoveryOwnerV3 owner =
            IStreamArtistIdentityRecoveryOwnerV3(address(this));
        bytes32 head = owner.latestRecoveryCapabilityContinuationV3(artistId);
        uint256 member = _latest(artistId, head, members);
        if (head == 0) {
            if (live.effectiveCapabilities != originalMask) {
                revert W.InvalidRecoveryRewindRecord(origin.transitionRecordHash);
            }
            return 0;
        }
        W.EnvironmentV3 memory e = _environment();
        if (
            originalEnvironment.chainId != e.chainId || originalEnvironment.registry != e.registry
                || originalEnvironment.core != e.core || originalEnvironment.manager != e.manager
                || origin.artistId != artistId || origin.authorityClass != 3
                || (origin.operationId != 40 && origin.operationId != 43)
                || live.authorityClass != 3
                || live.activationRecordHash != origin.transitionRecordHash
        ) {
            revert W.InvalidRecoveryRewindRecord(head);
        }
        SavedPlan memory s;
        s.imported = Imported.commitment() != 0;
        s.sourceEnvironment = e;
        if (s.imported) {
            s.original = _origin(e, head);
            s.sourceEnvironment = Runtime.rewindEnvironment(s.original.environment);
        }
        s.continuation = owner.recoveryCapabilityContinuationV3(head);
        W.CapabilityContinuationV3 memory c = s.continuation;
        s.recovered = Living.readFamily(address(this), e.registry, e.chainId, artistId, head);
        if (
            c.artistId != artistId || c.recoveryRecordHash != head
                || c.originalActivationRecordHash != origin.transitionRecordHash
                || c.originalActivationCapabilities != originalMask
                || c.authorityAddress != s.recovered.record.fields.newAddress
                || c.actionId != s.recovered.record.fields.governanceActionId
                || s.recovered.record.fields.vestedAuthorityClass != 3 || c.commitment == 0
                || c.commitment != W.capabilityContinuationHash(s.sourceEnvironment, c)
                || c.effectiveCapabilities != live.effectiveCapabilities
                || c.effectiveCapabilities & ~uint32(4095) != 0 || !_afterOrigin(e, s, origin)
                || keccak256(abi.encode(s.recovered.vesting, s.recovered.transition))
                    != keccak256(abi.encode(members[member].vesting, members[member].transition))
        ) {
            revert W.InvalidRecoveryRewindRecord(head);
        }
        s.evidence = owner.identityRecoveryEvidenceStateV3(artistId, c.actionId);
        _saved(s.sourceEnvironment, s);
        bytes32 selectedProof = _bounds(e, s);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_CAPABILITY_HISTORY_V3"),
                uint16(3),
                e,
                origin,
                originalMask,
                c,
                s.evidence,
                s.manifest,
                s.selected,
                s.basis,
                s.progress,
                s.recovered.proof,
                selectedProof
            )
        );
    }

    function _latest(bytes32 artistId, bytes32 head, Ancestry.Member[] memory members)
        private
        view
        returns (uint256 chosen)
    {
        IStreamArtistIdentityRecoveryOwnerV3 owner =
            IStreamArtistIdentityRecoveryOwnerV3(address(this));
        bool found;
        for (uint256 i; i < members.length; ++i) {
            V.Snapshot memory v = members[i].vesting;
            if (v.operationId != 35 || v.authorityClass != 3) continue;
            W.CapabilityContinuationV3 memory c =
                owner.recoveryCapabilityContinuationV3(v.transitionRecordHash);
            Recovery.Record memory r = IStreamArtistIdentityRecoveryOwner(address(this))
                .identityRecoveryRecord(v.transitionRecordHash);
            W.EvidenceStateV3 memory evidence =
                owner.identityRecoveryEvidenceStateV3(artistId, r.fields.governanceActionId);
            if (c.commitment == 0) {
                W.CapabilityContinuationV3 memory empty;
                if (
                    keccak256(abi.encode(c)) != keccak256(abi.encode(empty))
                        || evidence.manifestHash != 0
                ) revert W.InvalidRecoveryRewindRecord(v.transitionRecordHash);
                continue;
            }
            if (
                evidence.manifestHash == 0 || c.artistId != artistId
                    || c.recoveryRecordHash != v.transitionRecordHash
            ) revert W.InvalidRecoveryRewindRecord(v.transitionRecordHash);
            if (!found) {
                if (head != v.transitionRecordHash) revert W.InvalidRecoveryRewindRecord(head);
                chosen = i;
                found = true;
            }
        }
        if ((head != 0) != found) revert W.InvalidRecoveryRewindRecord(head);
    }

    function _saved(W.EnvironmentV3 memory e, SavedPlan memory s) private view {
        W.CapabilityContinuationV3 memory c = s.continuation;
        W.EvidenceStateV3 memory evidence = s.evidence;
        if (
            evidence.manifestHash != c.manifestHash
                || evidence.selectionCommitment != c.planCommitment || evidence.sourceKey == 0
                || evidence.sourceCommitment == 0 || evidence.associationHash == 0
                || evidence.effectiveCapabilities != c.effectiveCapabilities
        ) revert W.InvalidRecoveryRewindRecord(c.recoveryRecordHash);
        (Action.Association memory association,, bytes32 executed,) = IStreamArtistRecoveryActionOwner(
                address(this)
            ).identityRecoveryActionState(c.artistId, c.actionId);
        if (
            association.associationHash != evidence.associationHash
                || executed != c.recoveryRecordHash
                || evidence.sources.associationHash != evidence.associationHash
        ) revert W.InvalidRecoveryRewindRecord(c.recoveryRecordHash);
        if (s.imported) {
            Runtime.Context memory clock =
                Recovered.load(address(this), _environment().registry, e.chainId);
            s.preparation = Recovered.preparation(clock, association);
            if (
                s.preparation.point.environmentHash != s.original.point.environmentHash
                    || !Runtime.before(clock, s.preparation.point, s.original.point)
            ) {
                revert W.InvalidRecoveryRewindRecord(c.recoveryRecordHash);
            }
        }
        if (e.identityOwner.code.length == 0 || e.identityOwner.codehash != e.identityCodeHash) {
            revert W.RecoveryRewindDependencyChanged(e.identityOwner);
        }
        (address target, bytes32 pin) =
            IStreamArtistIdentityRecoveryOwnerV3(e.identityOwner).recoveryRewindSelectionBinding();
        if (target.code.length == 0 || pin == 0 || target.codehash != pin) {
            revert W.RecoveryRewindDependencyChanged(target);
        }
        IStreamArtistRecoveryRewindSelection selector = IStreamArtistRecoveryRewindSelection(target);
        if (
            selector.owner() != e.identityOwner || selector.payoutOwner() != e.payoutOwner
                || selector.artistRegistry() != e.registry
                || selector.deploymentChainId() != e.chainId
                || selector.coordinator() != e.coordinator
        ) revert W.RecoveryRewindDependencyChanged(target);
        s.selected = selector.selectionResultV3(evidence.sourceKey);
        (s.basis, s.progress) = selector.selectionV3(evidence.sourceKey);
        if (
            s.selected.sourceKey != evidence.sourceKey || s.selected.manifestHash != c.manifestHash
                || s.selected.sourceCommitment != evidence.sourceCommitment
                || s.selected.commitment != c.planCommitment
                || s.selected.commitment != W.selectionResultHash(e, s.selected)
                || s.selected.sourceKey != W.selectionKey(e, s.basis)
                || s.selected.inventoryCommitment
                    != W.selectionInventoryHash(
                        e, s.basis.identity.inventory, s.basis.payoutInventory
                    ) || !s.progress.complete || s.progress.resultCommitment != c.planCommitment
                || s.progress.identityProcessed != s.basis.identity.identity.receiptCount
                || s.progress.payoutProcessed != s.basis.payout.receiptCount
                || s.progress.guardiansProcessed != s.basis.identity.guardianHistory.count
                || s.basis.identity.artistId != c.artistId
                || s.basis.identity.manifestHash != c.manifestHash
                || s.basis.sourceCommitment != evidence.sourceCommitment
                || s.basis.sourceCommitment != W.selectionSourceHash(e, s.basis)
                || s.basis.identity.ownerCodeHash != e.identityCodeHash
                || s.basis.payoutCodeHash != e.payoutCodeHash
                || keccak256(abi.encode(s.basis.identity.identity, s.basis.payout))
                    != keccak256(
                        abi.encode(evidence.sources.identityBefore, evidence.sources.payout)
                    )
        ) {
            revert W.InvalidRecoveryRewindRecord(c.recoveryRecordHash);
        }
        IStreamArtistRecoveryRewindEvidence publisher = _publisher(e);
        bytes32 identityPin;
        bytes32 payoutPin;
        (s.manifest, identityPin, payoutPin) = publisher.resolutionManifestV3(c.manifestHash);
        if (
            identityPin != e.identityCodeHash || payoutPin != e.payoutCodeHash
                || W.manifestHash(e, s.manifest) != c.manifestHash
                || s.manifest.artistId != c.artistId
                || s.manifest.requestCommitment != W.requestCommitment(s.recovered.record.terms)
                || s.manifest.causeHash != s.recovered.record.terms.expectedCauseHash
                || s.manifest.resolutionHash != s.recovered.record.terms.expectedResolutionHash
                || s.manifest.executedHead != s.recovered.vesting.previousTransitionRecordHash
                || association.ownerRevision != s.manifest.identity.snapshot.revision + 1
                || s.manifest.identity.snapshot.revision >= s.recovered.vesting.ownerRevision
                || keccak256(abi.encode(s.manifest.identity, s.manifest.payout))
                    != keccak256(abi.encode(s.basis.identity.identity, s.basis.payout))
        ) {
            revert W.InvalidRecoveryRewindRecord(c.recoveryRecordHash);
        }
    }

    function _bounds(W.EnvironmentV3 memory e, SavedPlan memory s) private view returns (bytes32) {
        W.CapabilityContinuationV3 memory c = s.continuation;
        if (
            c.designationRecordHash == 0
                || s.selected.designation.operative.recordHash != c.designationRecordHash
                || s.selected.directive.operative.recordHash != c.forbiddenDirectiveRecordHash
        ) revert W.InvalidRecoveryRewindRecord(c.recoveryRecordHash);
        Records.Facts memory designation =
            _selected(e, s, W.RecordKind.SUCCESSOR_DESIGNATION, s.selected.designation.operative);
        if (designation.pairedDirective != c.pairedDirectiveRecordHash) {
            revert W.InvalidRecoveryRewindRecord(c.recoveryRecordHash);
        }
        uint32 caps = designation.grantedCapabilities;
        bytes32 pairedProof;
        if (c.pairedDirectiveRecordHash != 0) {
            (uint32 granted, bytes32 p) = _paired(e, s, c.pairedDirectiveRecordHash);
            caps &= granted;
            pairedProof = p;
        }
        Records.Facts memory forbidden;
        if (c.forbiddenDirectiveRecordHash != 0) {
            forbidden =
                _selected(e, s, W.RecordKind.ESTATE_DIRECTIVE, s.selected.directive.operative);
            caps &= ~forbidden.forbiddenCapabilities;
        } else {
            W.SelectedRecordV3 memory empty;
            if (
                keccak256(abi.encode(s.selected.directive.operative))
                    != keccak256(abi.encode(empty))
            ) revert W.InvalidRecoveryRewindRecord(c.recoveryRecordHash);
        }
        if (caps != c.effectiveCapabilities || caps & ~uint32(4095) != 0) {
            revert W.InvalidRecoveryRewindRecord(c.recoveryRecordHash);
        }
        return keccak256(
            abi.encode(
                designation.selected.originalDataHash,
                pairedProof,
                forbidden.selected.originalDataHash,
                caps
            )
        );
    }

    function _selected(
        W.EnvironmentV3 memory e,
        SavedPlan memory s,
        W.RecordKind kind,
        W.SelectedRecordV3 memory expected
    ) private view returns (Records.Facts memory f) {
        if (
            expected.recordHash == 0 || expected.admissionProof == 0
                || expected.nativeIndex >= s.manifest.identity.receiptCount
        ) {
            revert W.InvalidRecoveryRewindRecord(expected.recordHash);
        }
        f = Records.read(e, kind, s.continuation.artistId, expected.nativeIndex);
        if (
            f.selected.recordHash != expected.recordHash
                || f.selected.originalDataHash != expected.originalDataHash
                || f.selected.nonce != expected.nonce
                || !_admittedBefore(e, s, expected.nativeIndex, f.admissionRevision)
                || !R.eligible(
                    s.continuation.artistId,
                    f.association,
                    f.transition,
                    s.recovered.record.fields.recoveredAt
                )
        ) revert W.InvalidRecoveryRewindRecord(expected.recordHash);
        // Mutable later closures are authenticated by Records.read, but do not alter the frozen
        // admissionProof in this historical completed result or select a different old winner.
    }

    function _paired(W.EnvironmentV3 memory e, SavedPlan memory s, bytes32 hash)
        private
        view
        returns (uint32 granted, bytes32 proof_)
    {
        (address target,) = IStreamArtistIdentityRecoveryOwnerV3(s.sourceEnvironment.identityOwner)
            .recoveryRewindSelectionBinding();
        (W.RecordKind kind, W.SelectedRecordV3 memory selected, bool retained, bool eligible) = IStreamArtistRecoveryRewindSelection(
                target
            ).selectionRecordV3(s.selected.sourceKey, hash);
        if (
            kind != W.RecordKind.ESTATE_DIRECTIVE || selected.recordHash != hash || !retained
                || !eligible
        ) revert W.InvalidRecoveryRewindRecord(hash);
        Records.Facts memory f = _selected(e, s, kind, selected);
        return (f.grantedCapabilities, keccak256(abi.encode(kind, selected, retained, eligible)));
    }

    function _origin(W.EnvironmentV3 memory e, bytes32 head)
        private
        view
        returns (Runtime.OriginFact memory original)
    {
        Runtime.Context memory clock = Runtime.load(e, 2);
        original = Runtime.auxiliary(
            clock, keccak256("identity_authority.hydration.capability_continuation_v3"), head
        );
        Recovery.Record memory r =
            IStreamArtistIdentityRecoveryOwner(address(this)).identityRecoveryRecord(head);
        Runtime.ReceiptFact memory receipt =
            Recovered.nativeFact(clock, 35, r.fields.artistId, head);
        if (!Recovered.samePoint(receipt.position.point, original.point)) {
            revert W.InvalidRecoveryRewindRecord(head);
        }
    }

    function _afterOrigin(W.EnvironmentV3 memory e, SavedPlan memory s, V.Snapshot memory origin)
        private
        view
        returns (bool)
    {
        if (!s.imported) return s.recovered.vesting.ownerRevision > origin.ownerRevision;
        Runtime.Context memory clock = Runtime.load(e, 2);
        return Runtime.before(clock, Recovered.vesting(clock, origin).point, s.original.point);
    }

    function _admittedBefore(
        W.EnvironmentV3 memory e,
        SavedPlan memory s,
        uint256 index,
        uint64 revision
    ) private view returns (bool) {
        if (!s.imported) return revision <= s.manifest.identity.snapshot.revision;
        // A complete imported prefix keeps every original logical index unchanged.
        // The original preparation immediately follows its saved before-snapshot.
        Runtime.Context memory clock = Runtime.load(e, 2);
        Runtime.ReceiptFact memory receipt = Runtime.receiptAt(clock, index);
        return receipt.position.point.ownerRevision == revision
            && Runtime.before(clock, receipt.position.point, s.preparation.point);
    }

    function _environment() private view returns (W.EnvironmentV3 memory) {
        IStreamArtistOwner owner = IStreamArtistOwner(address(this));
        return Environment.fromFixed(
            address(this),
            owner.artistRegistry(),
            owner.operationCoordinator(),
            owner.archiveV2(),
            owner.core(),
            owner.mintManager()
        );
    }

    function _publisher(W.EnvironmentV3 memory e)
        private
        view
        returns (IStreamArtistRecoveryRewindEvidence p)
    {
        (address target, bytes32 pin) = IStreamArtistIdentityRecoveryOwnerV3(e.identityOwner)
            .recoveryRewindEvidenceBinding();
        if (target.code.length == 0 || pin == 0 || target.codehash != pin) {
            revert W.RecoveryRewindDependencyChanged(target);
        }
        p = IStreamArtistRecoveryRewindEvidence(target);
        if (
            p.owner() != e.identityOwner || p.payoutOwner() != e.payoutOwner
                || p.artistRegistry() != e.registry || p.deploymentChainId() != e.chainId
                || p.coordinator() != e.coordinator || p.archive() != e.archive
                || p.core() != e.core || p.mintManager() != e.manager
        ) revert W.RecoveryRewindDependencyChanged(target);
    }
}
