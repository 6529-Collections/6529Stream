// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistDormancyState as Dormancy } from "./StreamArtistDormancyState.sol";
import {
    StreamArtistCurrentNoticeRecoveryReads as CurrentNotice
} from "./StreamArtistCurrentNoticeRecoveryReads.sol";

import {
    StreamArtistIdentityRecoveryState as Recovery
} from "./StreamArtistIdentityRecoveryState.sol";
import {
    StreamArtistRecoveryRewindState as Supplemental
} from "./StreamArtistRecoveryRewindState.sol";
import { StreamArtistIdentityState as Identity } from "./StreamArtistIdentityState.sol";
import { StreamArtistRotationState as Rotations } from "./StreamArtistRotationState.sol";
import {
    StreamArtistIdentityResolutionState as Resolutions
} from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistEstateState as Estate } from "./StreamArtistEstateState.sol";
import {
    StreamArtistRecoveryAdjudicationHistory as Ancestry
} from "./StreamArtistRecoveryAdjudicationHistory.sol";
import {
    StreamArtistRecoveryRewindGuardians as Guardians
} from "./StreamArtistRecoveryRewindGuardians.sol";
import {
    StreamArtistRecoveryRewindEvidenceReads as Evidence
} from "./StreamArtistRecoveryRewindEvidenceReads.sol";
import { StreamArtistGuardianHistory as History } from "./StreamArtistGuardianHistory.sol";
import {
    StreamArtistGuardianSupersession as Supersession
} from "./StreamArtistGuardianSupersession.sol";
import {
    StreamArtistRecoveryEvidenceTypes as E
} from "../../interfaces/stream/artist/StreamArtistRecoveryEvidenceTypes.sol";
import {
    StreamArtistRecoverySelectionTypesV2 as SelectionV2
} from "../../interfaces/stream/artist/StreamArtistRecoverySelectionTypesV2.sol";
import {
    IStreamArtistRecoverySelectionPreparation,
    IStreamArtistRecoverySelectionBinding
} from "../../interfaces/stream/artist/IStreamArtistRecoverySelectionPreparation.sol";
import {
    StreamArtistGuardianSelectionTypes as Selection
} from "../../interfaces/stream/artist/StreamArtistGuardianSelectionTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as I
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Whole-owner V3 source admission, frozen typed policy and one cross-owner plan.
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV3 as Owner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";
import {
    IStreamArtistRecoveryRewindSelection as Worker
} from "../../interfaces/stream/artist/IStreamArtistRecoveryRewindSelection.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistNativeReceipts
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import { StreamArtistRecoveryRewindPolicy as Policy } from "./StreamArtistRecoveryRewindPolicy.sol";

library StreamArtistRecoveryRewindContext {
    struct Base {
        W.ResolutionManifestV3 manifest;
        T.Identity principal;
        D.Cause cause;
        Ancestry.Facts ancestry;
        W.IdentityBasisV3 selectionBasis;
        CurrentNotice.Facts notice;
    }

    struct Facts {
        Base source;
        Guardians.Facts guardians;
        Selection.Result selection;
        R.GuardianRecord selected;
        I.Context context;
        W.ResultV3 plan;
        bytes32[] guardianExclusions;
        uint32 effectiveCapabilities;
    }

    function base(
        Recovery.State storage s,
        Supplemental.State storage supplemental,
        Identity.State storage identity,
        Rotations.State storage rotations,
        Resolutions.State storage resolutions,
        Estate.State storage estate,
        Dormancy.State storage dormancy,
        Identity.OwnerContext memory o,
        bytes32 manifestHash
    ) public view returns (Base memory b) {
        b.manifest = Evidence.manifest(o, manifestHash);
        W.ResolutionManifestV3 memory m = b.manifest;
        _anchor(s, supplemental, o, manifestHash, m);
        b.cause = resolutions.causes[resolutions.currentCause[m.artistId]];
        b.principal = identity.identities[m.artistId];
        if (
            m.artistId == 0 || m.causeHash == 0 || b.cause.causeHash != m.causeHash
                || b.cause.facts.artistId != m.artistId
                || (b.cause.facts.kind != 1 && b.cause.facts.kind != 2)
                || b.cause.facts.referenceHash == 0 || b.cause.facts.actor == address(0)
                || b.principal.status != 4 || b.cause.facts.incumbent == address(0)
                || b.principal.authorityAddress != b.cause.facts.incumbent
                || b.principal.authorityClass != b.cause.facts.authorityClass
                || (b.principal.authorityClass != 1 && b.principal.authorityClass != 3)
                || (b.cause.facts.priorStatus != b.principal.authorityClass
                    && !(b.principal.authorityClass == 1
                        && b.cause.facts.kind == 1
                        && b.cause.facts.priorStatus == 2
                        && b.cause.facts.pendingTransitionHash == 0))
                || identity.activeIdentity[b.principal.authorityAddress] != m.artistId
                || resolutions.latestResolution[m.artistId] != m.resolutionHash
                || b.cause.facts.previousResolutionHash != m.resolutionHash
                || rotations.latestExecution[m.artistId] != m.executedHead
                || b.cause.facts.executedTransitionHash != m.executedHead
                || rotations.pending[m.artistId] != 0
        ) revert E.InvalidRecoveryManifest(manifestHash);
        (b.ancestry, b.notice) =
            Ancestry.readWithNotice(s, rotations, resolutions, dormancy, o.environment, b.cause);
        if (b.ancestry.delegationEpoch != estate.delegationEpoch[m.artistId]) {
            revert E.InvalidRecoveryManifest(manifestHash);
        }
        if (b.principal.authorityClass == 3) {
            if (
                b.ancestry.origin.transitionRecordHash == 0
                    || b.ancestry.capabilities.authorityAddress != b.principal.authorityAddress
                    || b.ancestry.capabilities.authorityClass != 3
                    || b.ancestry.capabilities.status != 4
                    || b.ancestry.capabilities.activationRecordHash
                        != b.ancestry.origin.transitionRecordHash
            ) revert E.InvalidRecoveryManifest(manifestHash);
        }
        Supersession.requireHeads(s.guardianSupersession, rotations, m.artistId);
        b.selectionBasis = W.IdentityBasisV3(
            manifestHash,
            m.artistId,
            address(this).codehash,
            m.identity,
            Owner(address(this)).recoveryRewindInventoryV3(m.artistId),
            History.requireComplete(
                s.guardianHistory, m.artistId, s.guardianRecordsSeen[m.artistId]
            ),
            bytes32(0)
        );
        b.selectionBasis.sourceCommitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_REWIND_IDENTITY_SOURCE_V3"),
                uint16(3),
                Evidence.environment(o),
                manifestHash,
                m,
                b.principal,
                b.cause,
                b.ancestry.historyProof,
                b.ancestry.capabilities,
                b.ancestry.delegationEpoch,
                b.selectionBasis.inventory,
                b.selectionBasis.guardianHistory,
                b.notice
            )
        );
    }

    function read(
        Recovery.State storage s,
        Supplemental.State storage supplemental,
        Identity.State storage identity,
        Rotations.State storage rotations,
        Resolutions.State storage resolutions,
        Estate.State storage estate,
        Dormancy.State storage dormancy,
        Identity.OwnerContext memory o,
        I.Request memory p,
        T.Authorization memory acceptance,
        bytes32 manifestHash,
        W.CrossOwnerFactsV3 memory cross
    ) public view returns (Facts memory f) {
        f.source = base(
            s, supplemental, identity, rotations, resolutions, estate, dormancy, o, manifestHash
        );
        W.ResolutionManifestV3 memory m = f.source.manifest;
        if (
            p.artistId != m.artistId || p.expectedCauseHash != m.causeHash
                || p.expectedResolutionHash != m.resolutionHash || p.newAddress == address(0)
                || p.newAddress == f.source.principal.authorityAddress
                || p.vestedAuthorityClass != f.source.principal.authorityClass
                || p.evidenceHash == 0 || p.reasonHash == 0
                || m.requestCommitment != E.requestCommitment(p)
                || p.supersededRecordHashes.length != m.supersededRecords.length
                || acceptance.signature.length > 4096
        ) revert E.InvalidRecoveryManifest(manifestHash);
        if (identity.activeIdentity[p.newAddress] != 0) {
            revert T.AddressAlreadyRegistered(p.newAddress);
        }
        for (uint256 index; index < p.supersededRecordHashes.length; ++index) {
            if (p.supersededRecordHashes[index] != m.supersededRecords[index].recordHash) {
                revert W.InvalidRecoveryRewindManifest(manifestHash);
            }
        }
        Worker worker = Evidence.worker(Evidence.environment(o));
        f.plan = worker.requireSelectionV3(manifestHash);
        (W.BasisV3 memory basis, W.ProgressV3 memory progress) =
            worker.selectionV3(f.plan.sourceKey);
        if (
            !progress.complete
                || keccak256(abi.encode(basis.identity))
                    != keccak256(abi.encode(f.source.selectionBasis))
                || keccak256(abi.encode(cross.selection)) != keccak256(abi.encode(f.plan))
                || keccak256(abi.encode(cross.payout)) != keccak256(abi.encode(m.payout))
                || keccak256(abi.encode(cross.payoutInventory))
                    != keccak256(abi.encode(basis.payoutInventory))
        ) {
            revert W.InvalidRecoveryRewindSelection(f.plan.sourceKey);
        }
        f.effectiveCapabilities =
            Policy.capabilities(worker, f.plan, p.artistId, p.vestedAuthorityClass);
        f.guardianExclusions = Policy.exclusions(m, W.RecordKind.GUARDIAN_SET);
        f.guardians = Guardians.read(
            s,
            rotations,
            o,
            m,
            manifestHash,
            p,
            f.source.ancestry,
            f.guardianExclusions,
            f.plan.directive.operative.recordHash
        );
        f.selection = f.plan.guardians;
        if (f.plan.commitment == 0 || f.plan.sourceKey == 0 || f.selection.commitment == 0) {
            revert W.InvalidRecoveryRewindSelection(f.plan.sourceKey);
        }
        f.selected = rotations.guardians[f.selection.selectedRecordHash];
        if (f.selection.selectedRecordHash == 0) {
            R.GuardianRecord memory empty;
            if (
                f.selection.selectedDataHash != 0 || f.selection.selectedNonce != 0
                    || keccak256(abi.encode(f.selected)) != keccak256(abi.encode(empty))
            ) {
                revert E.InvalidRecoveryManifest(manifestHash);
            }
        } else if (
            f.selected.recordHash != f.selection.selectedRecordHash
                || f.selected.terms.artistId != p.artistId
                || f.selected.nonce != f.selection.selectedNonce
                || keccak256(abi.encode(f.selected)) != f.selection.selectedDataHash
                || s.guardianSupersession.statuses[f.selected.recordHash].recoveryRecordHash != 0
        ) {
            revert E.InvalidRecoveryManifest(manifestHash);
        }
        I.Context memory c;
        c.causeHash = m.causeHash;
        c.incumbent = f.source.principal.authorityAddress;
        c.postContestSeconds = Rotations.rotationSeconds(rotations);
        if (f.selected.terms.minContestSeconds > c.postContestSeconds) {
            c.postContestSeconds = f.selected.terms.minContestSeconds;
        }
        c.standingTailSeconds = Rotations.standingSeconds(rotations);
        c.timingRevision = rotations.timingRevision == 0 ? 1 : rotations.timingRevision;
        c.delegationEpoch = estate.delegationEpoch[p.artistId];
        c.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_RECOVERY_SCOPE_V3"),
                o.environment.chainId,
                o.environment.registry,
                address(this),
                p.artistId
            )
        );
        c.oldValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_CONTEXT_V3"),
                c.scopeHash,
                manifestHash,
                m,
                f.source.principal,
                f.source.cause,
                f.source.ancestry.historyProof,
                f.source.ancestry.capabilities,
                f.guardians.commitment,
                f.plan,
                cross.payoutInventory,
                f.effectiveCapabilities,
                f.selected,
                c.postContestSeconds,
                c.standingTailSeconds,
                c.timingRevision,
                c.delegationEpoch
            )
        );
        if (f.source.notice.notice.recordHash != 0) {
            c.oldValueHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_RECOVERY_CURRENT_NOTICE_CONTEXT_V1"),
                    c.oldValueHash,
                    f.source.notice
                )
            );
        }
        c.newValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_RECOVERY_INTENT_V3"),
                c.scopeHash,
                c.oldValueHash,
                p,
                acceptance.nonce,
                acceptance.time
            )
        );
        f.context = c;
    }

    function _anchor(
        Recovery.State storage s,
        Supplemental.State storage supplemental,
        Identity.OwnerContext memory o,
        bytes32 manifestHash,
        W.ResolutionManifestV3 memory m
    ) private view {
        T.Snapshot memory current = IStreamArtistOwner(address(this)).ownerStateSnapshotV2();
        if (
            IStreamArtistNativeReceipts(address(this)).artistNativeReceiptCount()
                != m.identity.receiptCount
        ) {
            revert W.InvalidRecoveryRewindManifest(manifestHash);
        }
        bytes32 action = supplemental.manifestActions[manifestHash];
        if (action == 0) {
            if (keccak256(abi.encode(current)) != keccak256(abi.encode(m.identity.snapshot))) {
                revert W.InvalidRecoveryRewindManifest(manifestHash);
            }
            return;
        }
        W.EvidenceStateV3 memory saved = supplemental.actions[action];
        if (
            saved.manifestHash != manifestHash || saved.associationHash == 0
                || saved.associationHash != s.actions[action].associationHash
                || saved.sources.associationHash != saved.associationHash
                || keccak256(abi.encode(saved.sources.identityBefore))
                    != keccak256(abi.encode(m.identity))
                || keccak256(abi.encode(saved.sources.payout)) != keccak256(abi.encode(m.payout))
                || s.actions[action].artistId != m.artistId
                || s.actions[action].action.actionId != action
                || s.actions[action].ownerRevision != m.identity.snapshot.revision + 1
                || o.revision != s.actions[action].ownerRevision
                || s.pendingAction[m.artistId] != action || s.actionExecutions[action] != 0
        ) {
            revert W.InvalidRecoveryRewindManifest(manifestHash);
        }
        // The fixed worker separately requires the exact sealed post-preparation snapshot.
        // Its seal call reads this basis immediately after owner commit, so this hook must
        // authenticate the saved association without recursively requiring that seal.
    }
}
