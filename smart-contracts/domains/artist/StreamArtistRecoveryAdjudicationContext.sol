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
    StreamArtistRecoveryAdjudicationState as Supplemental
} from "./StreamArtistRecoveryAdjudicationState.sol";
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
    StreamArtistRecoveryAdjudicationGuardians as Guardians
} from "./StreamArtistRecoveryAdjudicationGuardians.sol";
import {
    StreamArtistRecoveryEvidenceReads as Evidence
} from "./StreamArtistRecoveryEvidenceReads.sol";
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

/// @notice Complete V2 source admission, separate from every original context hash path.
library StreamArtistRecoveryAdjudicationContext {
    struct Base {
        E.ResolutionManifest manifest;
        T.Identity principal;
        D.Cause cause;
        Ancestry.Facts ancestry;
        SelectionV2.Basis selectionBasis;
        CurrentNotice.Facts notice;
    }

    struct Facts {
        Base source;
        Guardians.Facts guardians;
        Selection.Result selection;
        R.GuardianRecord selected;
        I.Context context;
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
        E.ResolutionManifest memory m = b.manifest;
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
        b.selectionBasis = SelectionV2.Basis(
            manifestHash,
            m.artistId,
            address(this).codehash,
            History.requireComplete(
                s.guardianHistory, m.artistId, s.guardianRecordsSeen[m.artistId]
            ),
            bytes32(0)
        );
        b.selectionBasis.sourceCommitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_SELECTION_SOURCE_FACTS_V2"),
                manifestHash,
                b.principal,
                b.cause,
                b.ancestry.historyProof,
                b.ancestry.capabilities,
                b.ancestry.delegationEpoch,
                b.selectionBasis.history
            )
        );
        if (b.notice.notice.recordHash != 0) {
            b.selectionBasis.sourceCommitment = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_RECOVERY_CURRENT_NOTICE_SOURCE_V1"),
                    b.selectionBasis.sourceCommitment,
                    b.notice
                )
            );
        }
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
        bytes32 manifestHash
    ) public view returns (Facts memory f) {
        f.source = base(
            s, supplemental, identity, rotations, resolutions, estate, dormancy, o, manifestHash
        );
        E.ResolutionManifest memory m = f.source.manifest;
        if (
            p.artistId != m.artistId || p.expectedCauseHash != m.causeHash
                || p.expectedResolutionHash != m.resolutionHash || p.newAddress == address(0)
                || p.newAddress == f.source.principal.authorityAddress
                || p.vestedAuthorityClass != f.source.principal.authorityClass
                || p.evidenceHash == 0 || p.reasonHash == 0
                || m.requestCommitment != E.requestCommitment(p)
                || keccak256(abi.encode(p.supersededRecordHashes))
                    != keccak256(abi.encode(m.supersededRecordHashes))
                || acceptance.signature.length > 4096
        ) revert E.InvalidRecoveryManifest(manifestHash);
        if (identity.activeIdentity[p.newAddress] != 0) {
            revert T.AddressAlreadyRegistered(p.newAddress);
        }
        f.guardians = Guardians.read(s, rotations, o, m, manifestHash, p, f.source.ancestry);
        f.selection = _selection(o, manifestHash);
        if (f.selection.commitment == 0 || f.selection.sourceKey == 0) {
            revert E.InvalidRecoveryManifest(manifestHash);
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
                keccak256("6529STREAM_ARTIST_IDENTITY_RECOVERY_SCOPE_V2"),
                o.environment.chainId,
                o.environment.registry,
                address(this),
                p.artistId
            )
        );
        c.oldValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_CONTEXT_V2"),
                c.scopeHash,
                manifestHash,
                m,
                f.source.principal,
                f.source.cause,
                f.source.ancestry.historyProof,
                f.source.ancestry.capabilities,
                f.guardians.commitment,
                f.selection,
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
                keccak256("6529STREAM_ARTIST_IDENTITY_RECOVERY_INTENT_V2"),
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
        E.ResolutionManifest memory m
    ) private view {
        bytes32 action = supplemental.manifestActions[manifestHash];
        if (action == 0) {
            if (m.ownerRevision != o.revision) revert E.InvalidRecoveryManifest(manifestHash);
            return;
        }
        E.EvidenceStateV2 memory saved = supplemental.actions[action];
        if (
            saved.manifestHash != manifestHash || saved.preparedFromOwnerRevision != m.ownerRevision
                || saved.associationHash == 0
                || saved.associationHash != s.actions[action].associationHash
                || s.actions[action].artistId != m.artistId
                || s.actions[action].action.actionId != action
                || s.actions[action].ownerRevision != m.ownerRevision + 1
                || o.revision != s.actions[action].ownerRevision
                || s.pendingAction[m.artistId] != action || s.actionExecutions[action] != 0
        ) revert E.InvalidRecoveryManifest(manifestHash);
    }

    function _selection(Identity.OwnerContext memory o, bytes32 manifestHash)
        private
        view
        returns (Selection.Result memory)
    {
        (address target, bytes32 codeHash) = IStreamArtistRecoverySelectionBinding(address(this))
            .recoverySelectionPreparationBinding();
        if (target.code.length == 0 || codeHash == 0 || target.codehash != codeHash) {
            revert E.RecoveryEvidenceDependencyChanged(target);
        }
        IStreamArtistRecoverySelectionPreparation p =
            IStreamArtistRecoverySelectionPreparation(target);
        if (
            p.owner() != address(this) || p.artistRegistry() != o.environment.registry
                || p.deploymentChainId() != o.environment.chainId
        ) revert E.RecoveryEvidenceDependencyChanged(target);
        return p.requireSelectionV2(manifestHash);
    }
}
