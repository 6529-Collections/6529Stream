// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredTimingTypes as TM
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistRecoveredHydrationOwner as Source
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationState as X
} from "./StreamArtistRecoveredIdentityHydrationState.sol";
import {
    StreamArtistRecoveredIdentityHydrationContinuations as Continuations
} from "./StreamArtistRecoveredIdentityHydrationContinuations.sol";
import {
    StreamArtistRecoveredHydrationChronology as Chronology
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredTimingInventory as Timing
} from "./StreamArtistRecoveredTimingInventory.sol";
import {
    StreamArtistEntropyUnavailabilityStore as Entropy
} from "./StreamArtistEntropyUnavailabilityStore.sol";
import {
    StreamArtistIdentityRecoveryReceipts as Receipts
} from "./StreamArtistIdentityRecoveryReceipts.sol";
import {
    StreamArtistRecoveredHydrationState as ProvenanceState
} from "./StreamArtistRecoveredHydrationState.sol";
import { StreamArtistNativeReceipts as Native } from "./StreamArtistNativeReceipts.sol";

import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";

/// @notice Fixed linked raw-export worker. Every key is derived from authenticated original inventories.
/// @dev The host supplies only its declared roots; its external read accepts Query and owner provenance.
library StreamArtistRecoveredIdentityHydrationExportRows {
    bytes32 private constant PREPARATION =
        keccak256("identity_authority.replay.recovery_preparation");
    bytes32 private constant VESTING = keccak256("identity_authority.hydration.guardian_vesting");
    bytes32 private constant ORIGINAL_CONTINUATION =
        keccak256("identity_authority.hydration.dismissal_continuation");
    bytes32 private constant REVISION_CONTINUATION =
        keccak256("identity_authority.hydration.revision_continuation_v3");
    bytes32 private constant STANDING_CONTINUATION =
        keccak256("identity_authority.hydration.standing_continuation_v3");
    bytes32 private constant CAPABILITY_CONTINUATION =
        keccak256("identity_authority.hydration.capability_continuation_v3");

    struct Repudiation {
        uint64 seconds_;
        uint64 revision;
        mapping(bytes32 => bool) actions;
    }

    function exportBundle(
        uint256[17] memory roots,
        AH.Query memory query,
        RH.OwnerProvenance memory local
    ) public view returns (IH.Bundle memory b) {
        Provenance.validateOwnerSource(local, 2, address(this));
        if (query.artistId == 0) revert IH.InvalidRecoveredIdentity(query.artistId);
        b.artistId = query.artistId;
        b.sourceSnapshot = IStreamArtistOwner(address(this)).ownerStateSnapshotV2();
        b.identity = X.identity(roots).identities[b.artistId];
        b.identityDocument = X.identity(roots).documents[b.identity.identityRecordHash];
        b.nextRegistrationNonce = X.identity(roots).nextRegistrationNonce;
        _heads(roots, b);
        b.signatures = new IH.SignatureRow[](query.records.length);
        for (uint256 i; i < query.records.length; ++i) {
            b.signatures[i] =
                IH.SignatureRow(query.records[i], X.identity(roots).signatures[query.records[i]]);
        }
        _records(roots, b, local);
        _vestings(roots, b, local);
        _members(roots, b);
        _actions(roots, b, local);
        _closures(roots, b);
        _standing(roots, b);
        _documents(roots, b);
        _nonces(roots, b);
        b.timing = Timing.collect(configuration(roots));
        b = Continuations.collect(roots, b, local);
    }

    function actionArtist(uint256[17] memory roots, bytes32 action) public view returns (bytes32) {
        return X.recovery(roots).actions[action].artistId;
    }

    /// @notice Resolve only the six declared auxiliary surfaces from their actual producer state.
    /// @dev An imported artifact must retain its saved point. A missing override is admissible
    /// only for a proved local write after the import boundary; raw revisions are never rebased.
    function auxiliaryPoint(
        uint256[17] memory roots,
        bytes32 kind,
        bytes32 key,
        bytes32 currentOriginHash
    ) public view returns (RH.Point memory) {
        uint64 revision;
        RH.Point memory producer;
        if (kind == VESTING) {
            V.Snapshot memory v = X.recovery(roots).vestingHistory.snapshots[key];
            if (v.transitionRecordHash != key) revert IH.InvalidRecoveredIdentity(key);
            revision = v.ownerRevision;
            if (v.operationId == 32 || v.operationId == 40) {
                producer = _replayPoint(
                    roots,
                    v.operationId == 32
                        ? keccak256("identity_authority.replay.rotation_execution_key")
                        : keccak256("identity_authority.replay.activation_execution_key"),
                    key,
                    key,
                    revision
                );
            } else if (v.operationId == 35 || v.operationId == 43) {
                producer = _nativePoint(v.operationId, key, currentOriginHash);
            } else {
                revert IH.InvalidRecoveredIdentity(key);
            }
        } else if (kind == PREPARATION) {
            if (X.recovery(roots).actions[key].action.actionId != key) {
                revert IH.InvalidRecoveredIdentity(key);
            }
            revision = X.recovery(roots).actions[key].ownerRevision;
            producer = _replayPoint(
                roots, PREPARATION, key, X.recovery(roots).actions[key].associationHash, revision
            );
        } else if (kind == REVISION_CONTINUATION) {
            if (X.rewinds(roots).revisionContinuations[key].continuationHash != key) {
                revert IH.InvalidRecoveredIdentity(key);
            }
            revision = X.rewinds(roots).revisionContinuations[key].ownerRevision;
            producer = _nativePoint(
                35,
                X.rewinds(roots).revisionContinuations[key].recoveryRecordHash,
                currentOriginHash
            );
        } else if (kind == STANDING_CONTINUATION) {
            if (X.rewinds(roots).standingContinuations[key].continuationHash != key) {
                revert IH.InvalidRecoveredIdentity(key);
            }
            revision = X.rewinds(roots).standingContinuations[key].ownerRevision;
            producer = _nativePoint(
                35,
                X.rewinds(roots).standingContinuations[key].recoveryRecordHash,
                currentOriginHash
            );
        } else if (kind == ORIGINAL_CONTINUATION) {
            bytes32 dismissal = X.resolutions(roots).continuations[key].dismissalRecordHash;
            if (
                key == 0 || X.resolutions(roots).continuations[key].continuationHash != key
                    || dismissal == 0
                    || X.resolutions(roots).records[dismissal].recordHash != dismissal
            ) revert IH.InvalidRecoveredIdentity(key);
            producer = _nativePoint(58, dismissal, currentOriginHash);
            revision = producer.ownerRevision;
        } else if (kind == CAPABILITY_CONTINUATION) {
            if (
                key == 0 || X.rewinds(roots).capabilityContinuations[key].recoveryRecordHash != key
                    || X.rewinds(roots).capabilityContinuations[key].commitment == 0
                    || X.recovery(roots).records[key].recordHash != key
            ) revert IH.InvalidRecoveredIdentity(key);
            producer = _nativePoint(35, key, currentOriginHash);
            revision = producer.ownerRevision;
        } else {
            revert IH.InvalidRecoveredIdentity(key);
        }
        RH.Point memory retained = ProvenanceState.artifactPoint(
            kind, key, revision, RH.Point(currentOriginHash, 2, revision)
        );
        if (
            producer.environmentHash != retained.environmentHash || producer.ownerIndex != 2
                || producer.ownerRevision != retained.ownerRevision
        ) revert IH.InvalidRecoveredIdentity(key);
        if (kind == VESTING && retained.environmentHash == currentOriginHash) {
            V.Snapshot memory v = X.recovery(roots).vestingHistory.snapshots[key];
            IStreamArtistOwner owner = IStreamArtistOwner(address(this));
            bytes32 currentHash = keccak256(
                bytes.concat(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_V1"),
                        owner.deploymentChainId(),
                        owner.artistRegistry(),
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
            if (v.commitment != currentHash) revert IH.InvalidRecoveredIdentity(key);
        }
        return retained;
    }

    function _replayPoint(
        uint256[17] memory roots,
        bytes32 surface,
        bytes32 scope,
        bytes32 commitment,
        uint64 revision
    ) private view returns (RH.Point memory) {
        IStreamArtistOwner owner = IStreamArtistOwner(address(this));
        bytes32 replayKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                owner.deploymentChainId(),
                owner.artistRegistry(),
                owner.operationCoordinator(),
                owner.archiveV2(),
                address(this),
                owner.domainId(),
                surface,
                scope
            )
        );
        if (
            commitment == 0 || X.replay(roots).cells[replayKey].commitment != commitment
                || X.replay(roots).cells[replayKey].kind != 1
                || X.replay(roots).cells[replayKey].status != 2
                || X.replay(roots).cells[replayKey].touchedRevision != revision
        ) {
            revert IH.InvalidRecoveredIdentity(scope);
        }
        return Source(address(this)).recoveredHydrationReplayPoint(replayKey);
    }

    function _nativePoint(uint16 operation, bytes32 key, bytes32 currentOriginHash)
        private
        view
        returns (RH.Point memory point)
    {
        bytes32 kind = keccak256(
            abi.encode(keccak256("6529STREAM_ARTIST_RECOVERED_NATIVE_RECORD_V1"), operation)
        );
        uint256 count = Native.count();
        for (uint256 i; i < count; ++i) {
            if (Native.at(i).operation != operation || Native.at(i).recordHash != key) continue;
            if (point.ownerRevision != 0) revert IH.InvalidRecoveredIdentity(key);
            uint64 revision = Native.revisionAt(i);
            point = ProvenanceState.artifactPoint(
                kind, key, revision, RH.Point(currentOriginHash, 2, revision)
            );
        }
        // Imported semantic rows are not duplicated in this owner's native receipt array.
        if (point.ownerRevision == 0) point = ProvenanceState.artifact(kind, key);
    }

    function timingCheckpoint(uint256[17] memory roots) public view returns (TM.Checkpoint memory) {
        return Timing.checkpoint(configuration(roots));
    }

    function configuration(uint256[17] memory roots)
        public
        view
        returns (TM.Configuration memory c)
    {
        c.values = [
            X.rotations(roots).rotationContestSeconds,
            X.rotations(roots).priorStandingTailSeconds,
            X.estate(roots).noticeSeconds,
            X.dormancy(roots).inactivitySeconds,
            X.dormancy(roots).noticeSeconds,
            X.findings(roots).noticeSeconds,
            _repudiation().seconds_
        ];
        c.revisions = [
            X.rotations(roots).timingRevision,
            X.estate(roots).noticeRevision,
            X.dormancy(roots).timingRevision,
            X.findings(roots).timingRevision,
            _repudiation().revision
        ];
    }

    function _heads(uint256[17] memory r, IH.Bundle memory b) private view {
        bytes32 id = b.artistId;
        b.heads.latestTransition = X.rotations(r).latestTransition[id];
        b.heads.latestExecution = X.rotations(r).latestExecution[id];
        b.heads.pendingRotation = X.rotations(r).pending[id];
        b.heads.latestContest = X.contests(r).latest[id];
        b.heads.currentCause = X.resolutions(r).currentCause[id];
        b.heads.latestDismissal = X.resolutions(r).latestResolution[id];
        b.heads.originalRevisionContinuation = X.resolutions(r).continuationHead[id];
        b.heads.latestRecovery = X.recovery(r).latest[id];
        b.heads.pendingRecoveryAction = X.recovery(r).pendingAction[id];
        b.heads.latestVesting = X.recovery(r).vestingHistory.latest[id];
        b.heads.pendingEstate = X.estate(r).pending[id];
        b.heads.estateActivation = X.estate(r).authorityActivation[id];
        b.heads.dormancyActivation = X.dormancy(r).activation[id];
        b.heads.latestNotice = X.dormancy(r).latestNotice[id];
        b.heads.livingActivity = X.estate(r).livingActivity[id];
        b.heads.dormancyActivity = X.dormancy(r).activity[id];
        b.heads.findingActivity = X.findings(r).activityEpoch[id];
        b.heads.hasUncancelledFindings = X.findings(r).hasUncancelledFindings[id];
        b.heads.delegationEpoch = X.estate(r).delegationEpoch[id];
        b.heads.guardianRecordsSeen = X.recovery(r).guardianRecordsSeen[id];
        b.heads.guardianHistory = X.recovery(r).guardianHistory.heads[id];
        b.heads.guardianIndex = X.recovery(r).guardianSupersession.indexedHeads[id];
        b.heads.inventory =
            IStreamArtistIdentityRecoveryOwnerV3(address(this)).recoveryRewindInventoryV3(id);
        b.heads.capabilityContinuation = X.rewinds(r).capabilityHead[id];
    }

    function _records(uint256[17] memory r, IH.Bundle memory b, RH.OwnerProvenance memory p)
        private
        view
    {
        uint256[62] memory n;
        for (uint256 i; i < p.journal.length; ++i) {
            if (p.journal[i].receipt.artistId == b.artistId) ++n[p.journal[i].receipt.operation];
        }
        b.revisions = new IH.RevisionRow[](n[25]);
        b.delegations = new IH.DelegationRow[](n[26]);
        b.guardians = new IH.GuardianRow[](n[28]);
        b.rotations = new IH.RotationRow[](n[29]);
        b.contests = new IH.ContestRow[](n[33] / 2);
        b.causes = new IH.CauseRow[](n[33] / 2 + n[31]);
        b.dismissals = new IH.DismissalRow[](n[58]);
        b.standingRecords = new IH.StandingRecordRow[](n[51]);
        b.recoveries = new IH.RecoveryRow[](n[35] / 2);
        b.designations = new IH.DesignationRow[](n[36]);
        b.directives = new IH.DirectiveRow[](n[37]);
        b.sanctionGrants = new IH.GrantRow[](n[19]);
        b.estates = new IH.EstateRow[](n[38]);
        b.notices = new IH.NoticeRow[](n[41]);
        b.findings = new IH.FindingRow[](n[23]);
        uint256[62] memory at;
        uint256 causeAt;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory j = p.journal[i];
            if (j.receipt.artistId != b.artistId) continue;
            uint16 op = j.receipt.operation;
            bytes32 key = j.receipt.recordHash;
            if (op == 25) {
                IH.RevisionRow memory row;
                row.position = j.position;
                row.record = X.revisions(r).records[key];
                row.document = X.identity(r).documents[row.record.revisedRecordHash];
                row.association = X.revisions(r).associations[key];
                row.status = X.rewinds(r).statuses[key];
                row.rewindContinuation = X.rewinds(r).revisionRecordContinuations[key];
                b.revisions[at[op]++] = row;
            } else if (op == 26) {
                IH.DelegationRow memory row;
                row.position = j.position;
                row.recordHash = key;
                row.record = X.delegations(r).records[key];
                row.current = X.delegations(r)
                .current[keccak256(abi.encode(b.artistId, row.record.grant.delegate))];
                row.epoch = X.estate(r).grantEpoch[key];
                b.delegations[at[op]++] = row;
            } else if (op == 28) {
                b.guardians[at[op]++] = IH.GuardianRow(
                    j.position,
                    X.rotations(r).guardians[key],
                    X.recovery(r).guardianHistory.entries[key],
                    X.recovery(r).guardianSupersession.statuses[key]
                );
            } else if (op == 29) {
                IH.RotationRow memory row;
                row.position = j.position;
                row.record = X.rotations(r).rotations[key];
                address[] memory members =
                X.rotations(r).guardians[row.record.guardianSetRecordHash].terms.guardians;
                row.approvals = new bool[](members.length);
                for (uint256 k; k < members.length; ++k) {
                    row.approvals[k] = X.rotations(r).approvals[key][members[k]];
                }
                b.rotations[at[op]++] = row;
            } else if (op == 31 || op == 33) {
                if (X.resolutions(r).causes[key].causeHash != 0) {
                    b.causes[causeAt++] = IH.CauseRow(
                        j.position.point,
                        X.resolutions(r).causes[key],
                        X.dormancy(r).causeNotice[key]
                    );
                } else if (op == 33) {
                    b.contests[at[op]++] = IH.ContestRow(j.position, X.contests(r).records[key]);
                } else {
                    revert IH.InvalidRecoveredIdentity(key);
                }
            } else if (op == 35) {
                if (X.recovery(r).records[key].recordHash == 0) continue;
                IH.RecoveryRow memory row;
                row.position = j.position;
                row.record = X.recovery(r).records[key];
                row.transition = X.recovery(r).transitions[key];
                row.guardian = X.recovery(r).recoveryGuardians[key];
                row.primaryReceipt = X.recovery(r).receipts.receipts[Receipts.PRIMARY][key];
                row.secondaryOccurrence =
                    Receipts.occurrenceKey(key, row.record.fields.supersededRecordsHash);
                row.secondaryReceipt =
                    X.recovery(r).receipts.secondaryOccurrences[row.secondaryOccurrence];
                b.recoveries[at[op]++] = row;
            } else if (op == 36) {
                b.designations[at[op]++] = IH.DesignationRow(
                    j.position, X.succession(r).designations[key], X.rewinds(r).statuses[key]
                );
            } else if (op == 37) {
                b.directives[at[op]++] = IH.DirectiveRow(
                    j.position,
                    X.succession(r).directives[key],
                    X.succession(r).payloads[key],
                    X.rewinds(r).statuses[key]
                );
            } else if (op == 19) {
                b.sanctionGrants[at[op]++] = IH.GrantRow(
                    j.position, X.sanctions(r).records[key], X.rewinds(r).statuses[key]
                );
            } else if (op == 38) {
                b.estates[at[op]++] = IH.EstateRow(
                    j.position,
                    X.estate(r).requests[key],
                    X.estate(r).phases[key],
                    X.estate(r).executions[key],
                    X.estate(r).transitions[key]
                );
            } else if (op == 41) {
                IH.NoticeRow memory row;
                row.position = j.position;
                row.notice = X.dormancy(r).notices[key];
                row.phase = X.dormancy(r).phases[key];
                row.terminal = X.dormancy(r).terminals[X.dormancy(r).terminalForNotice[key]];
                row.transition = X.dormancy(r).transitions[row.terminal.recordHash];
                b.notices[at[op]++] = row;
            } else if (op == 51) {
                b.standingRecords[at[op]++] = IH.StandingRecordRow(
                    j.position,
                    X.rotations(r).standingRecords[key],
                    X.rewinds(r).statuses[key],
                    X.rewinds(r).standingRecordContinuations[key]
                );
            } else if (op == 58) {
                b.dismissals[at[op]++] = IH.DismissalRow(j.position, X.resolutions(r).records[key]);
            } else if (op == 23) {
                IH.FindingRow memory row;
                row.position = j.position;
                row.record = X.findings(r).records[key];
                row.admission = X.findings(r).admissions[key];
                row.entropyAdmission = Entropy.state().admissions[key];
                row.entropyOrigin = Entropy.state().origins[key];
                if (
                    row.entropyOrigin == address(0)
                        && row.entropyAdmission.target.coordinator != address(0)
                ) row.entropyOrigin = IStreamArtistOwner(address(this)).artistRegistry();
                row.latestForCollection = X.findings(r)
                .latest[keccak256(abi.encode(b.artistId, row.record.terms.collectionId))];
                b.findings[at[op]++] = row;
            }
        }
        if (
            causeAt != b.causes.length || at[33] != b.contests.length
                || at[35] != b.recoveries.length
        ) revert IH.InvalidRecoveredIdentity(b.artistId);
    }

    function _vestings(uint256[17] memory r, IH.Bundle memory b, RH.OwnerProvenance memory p)
        private
        view
    {
        bytes32 cursor = b.heads.latestVesting;
        uint256 count;
        while (cursor != 0) {
            if (++count > p.journal.length) revert IH.InvalidRecoveredIdentity(cursor);
            cursor = X.recovery(r).vestingHistory.snapshots[cursor].previousTransitionRecordHash;
        }
        b.vestings = new IH.VestingRow[](count);
        cursor = b.heads.latestVesting;
        while (cursor != 0) {
            IH.VestingRow memory row;
            row.snapshot = X.recovery(r).vestingHistory.snapshots[cursor];
            if (row.snapshot.transitionRecordHash != cursor || row.snapshot.artistId != b.artistId)
            {
                revert IH.InvalidRecoveredIdentity(cursor);
            }
            row.point = Source(address(this)).recoveredHydrationAuxiliaryPoint(VESTING, cursor);
            b.vestings[--count] = row;
            cursor = row.snapshot.previousTransitionRecordHash;
        }
    }

    function _members(uint256[17] memory r, IH.Bundle memory b) private view {
        uint256 capacity;
        for (uint256 i; i < b.guardians.length; ++i) {
            capacity += b.guardians[i].record.terms.guardians.length;
        }
        address[] memory keys = new address[](capacity);
        uint256 n;
        for (uint256 i; i < b.guardians.length; ++i) {
            for (uint256 j; j < b.guardians[i].record.terms.guardians.length; ++j) {
                n = _address(keys, n, b.guardians[i].record.terms.guardians[j]);
            }
        }
        b.memberships = new IH.MembershipRow[](n);
        for (uint256 i; i < n; ++i) {
            b.memberships[i] = IH.MembershipRow(
                keys[i],
                X.recovery(r).guardianHistory.firstMembership[b.artistId][keys[i]],
                X.recovery(r).guardianSupersession.memberships[b.artistId][keys[i]]
            );
        }
    }

    function _actions(uint256[17] memory r, IH.Bundle memory b, RH.OwnerProvenance memory p)
        private
        view
    {
        bytes32[] memory keys = new bytes32[](p.aliases.length);
        uint256 n;
        for (uint256 i; i < p.aliases.length; ++i) {
            if (
                p.aliases[i].surface == PREPARATION
                    && X.recovery(r).actions[p.aliases[i].scope].artistId == b.artistId
            ) {
                bytes32 key = p.aliases[i].scope;
                bool found;
                for (uint256 j; j < n; ++j) {
                    if (keys[j] == key) found = true;
                }
                if (!found) keys[n++] = key;
            }
        }
        b.actions = new IH.ActionRow[](n);
        for (uint256 i; i < n; ++i) {
            bytes32 key = keys[i];
            IH.ActionRow memory row;
            row.association = X.recovery(r).actions[key];
            row.veto = X.recovery(r).vetoes[key];
            row.execution = X.recovery(r).actionExecutions[key];
            row.guardianSnapshot = X.recovery(r).guardianHistory.snapshots[key];
            row.plan = X.recovery(r).guardianSupersession.plans[key];
            row.election = X.recovery(r).guardianSupersession.elections[key];
            row.restoredGuardian = X.recovery(r).guardianSupersession.restoredGuardians[key];
            row.excludedMemberships = new uint64[](b.memberships.length);
            for (uint256 j; j < b.memberships.length; ++j) {
                row.excludedMemberships[j] = X.recovery(r).guardianSupersession
                    .excludedMemberships[key][b.memberships[j].actor];
            }
            row.evidenceV2 = X.adjudication(r).actions[key];
            row.evidenceV3 = X.rewinds(r).actions[key];
            row.manifestActionV2 = X.adjudication(r).manifestActions[row.evidenceV2.manifestHash];
            row.manifestActionV3 = X.rewinds(r).manifestActions[row.evidenceV3.manifestHash];
            bool point;
            for (uint256 j; j < p.aliases.length; ++j) {
                if (
                    p.aliases[j].surface == PREPARATION && p.aliases[j].scope == key
                        && p.aliases[j].cell.commitment == row.association.associationHash
                ) {
                    if (
                        point
                            && keccak256(abi.encode(row.point))
                                != keccak256(abi.encode(p.aliases[j].admittedAt))
                    ) revert IH.InvalidRecoveredIdentity(key);
                    row.point = p.aliases[j].admittedAt;
                    point = true;
                }
            }
            if (!point) revert IH.InvalidRecoveredIdentity(key);
            b.actions[i] = row;
        }
        // Prefix enumeration is key-ordered; restore actual chronology without comparing raw cross-owner revisions.
        for (uint256 i = 1; i < b.actions.length; ++i) {
            IH.ActionRow memory row = b.actions[i];
            uint256 j = i;
            while (j != 0 && Chronology.beforeOwner(p, 2, row.point, b.actions[j - 1].point)) {
                b.actions[j] = b.actions[j - 1];
                --j;
            }
            b.actions[j] = row;
        }
    }

    function _closures(uint256[17] memory r, IH.Bundle memory b) private view {
        uint256 n = b.rotations.length + b.estates.length + b.recoveries.length;
        for (uint256 i; i < b.notices.length; ++i) {
            if (b.notices[i].phase == 3) ++n;
        }
        b.closures = new IH.ClosureRow[](n);
        uint256 at;
        for (uint256 i; i < b.rotations.length; ++i) {
            b.closures[at++] = IH.ClosureRow(
                b.rotations[i].record.recordHash,
                X.resolutions(r).closures[b.rotations[i].record.recordHash]
            );
        }
        for (uint256 i; i < b.estates.length; ++i) {
            b.closures[at++] = IH.ClosureRow(
                b.estates[i].request.recordHash,
                X.resolutions(r).closures[b.estates[i].request.recordHash]
            );
        }
        for (uint256 i; i < b.recoveries.length; ++i) {
            b.closures[at++] = IH.ClosureRow(
                b.recoveries[i].record.recordHash,
                X.resolutions(r).closures[b.recoveries[i].record.recordHash]
            );
        }
        for (uint256 i; i < b.notices.length; ++i) {
            if (b.notices[i].phase == 3) {
                b.closures[at++] = IH.ClosureRow(
                    b.notices[i].terminal.recordHash,
                    X.resolutions(r).closures[b.notices[i].terminal.recordHash]
                );
            }
        }
    }

    function _standing(uint256[17] memory r, IH.Bundle memory b) private view {
        address[] memory keys = new address[](b.vestings.length + b.standingRecords.length);
        uint256 n;
        for (uint256 i; i < b.vestings.length; ++i) {
            n = _address(keys, n, b.vestings[i].snapshot.oldAddress);
        }
        for (uint256 i; i < b.standingRecords.length; ++i) {
            n = _address(keys, n, b.standingRecords[i].record.terms.revokedAddress);
        }
        b.standing = new IH.StandingRow[](n);
        for (uint256 i; i < n; ++i) {
            b.standing[i] = IH.StandingRow(
                keys[i],
                X.rotations(r).retirement[b.artistId][keys[i]],
                X.rotations(r).standingRevocation[b.artistId][keys[i]],
                X.resolutions(r).standingJudgments[b.artistId][keys[i]]
            );
        }
    }

    function _documents(uint256[17] memory r, IH.Bundle memory b) private view {
        bytes32[] memory keys = new bytes32[](1 + b.revisions.length * 2);
        uint256 n = _key(keys, 0, b.identity.identityRecordHash);
        for (uint256 i; i < b.revisions.length; ++i) {
            n = _key(keys, n, b.revisions[i].record.previousRecordHash);
            n = _key(keys, n, b.revisions[i].record.revisedRecordHash);
        }
        b.documents = new IH.DocumentRow[](n);
        for (uint256 i; i < n; ++i) {
            b.documents[i] = IH.DocumentRow(keys[i], X.identity(r).documents[keys[i]]);
        }
    }

    function _nonces(uint256[17] memory r, IH.Bundle memory b) private view {
        CP owner = CP(address(this));
        uint256 all = owner.authorityCheckpoint().nonceIndexCount;
        if (all > RH.MAX_NONCE_INDICES) revert IH.InvalidRecoveredIdentity(b.artistId);
        b.nonces = new IH.NonceLane[](all);
        uint256 count;
        for (uint256 i; i < all; ++i) {
            CP.NonceIndex memory index = owner.authorityNonceIndexAt(i);
            if (!_lane(b, index.kind, index.key)) continue;
            if (index.prefixCount == 0 || index.prefixCount > RH.MAX_NONCE_PREFIXES) {
                revert IH.InvalidRecoveredIdentity(index.key);
            }
            IH.NonceLane memory row;
            row.kind = index.kind;
            row.key = index.key;
            if (index.kind == 1) row.hint = b.identity.nonceHint;
            else if (index.kind == 2) row.hint = X.delegations(r).hints[index.key];
            else if (index.kind == 4) row.hint = X.rotations(r).acceptanceHint[index.key];
            else row.hint = X.estate(r).nonceHints[index.key];
            row.words = new AH.NonceWord[](index.prefixCount);
            for (uint256 j; j < index.prefixCount; ++j) {
                (row.words[j].prefix, row.words[j].words, row.words[j].exhausted) =
                    owner.authorityNonceWordAt(index.kind, index.key, j);
            }
            b.nonces[count++] = row;
        }
        IH.NonceLane[] memory rows = b.nonces;
        assembly ("memory-safe") { mstore(rows, count) }
    }

    function _lane(IH.Bundle memory b, uint8 kind, bytes32 key) private pure returns (bool) {
        if (kind == 1) return key == b.artistId;
        if (kind == 2) {
            for (uint256 i; i < b.delegations.length; ++i) {
                if (
                    key
                        == keccak256(
                            abi.encode(
                                keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"),
                                b.artistId,
                                b.delegations[i].record.grant.delegate
                            )
                        )
                ) {
                    return true;
                }
            }
        }
        if (kind == 4) {
            for (uint256 i; i < b.rotations.length; ++i) {
                if (
                    key
                        == keccak256(
                            abi.encode(
                                keccak256("rotation_acceptance"),
                                b.artistId,
                                b.rotations[i].record.terms.newAddress
                            )
                        )
                ) return true;
            }
            for (uint256 i; i < b.recoveries.length; ++i) {
                if (
                    key
                        == keccak256(
                            abi.encode(
                                keccak256("rotation_acceptance"),
                                b.artistId,
                                b.recoveries[i].record.terms.newAddress
                            )
                        )
                ) return true;
            }
        }
        if (kind == 5) {
            for (uint256 i; i < b.estates.length; ++i) {
                if (
                    key
                        == keccak256(
                            abi.encode(
                                "estate_activation",
                                b.artistId,
                                b.estates[i].request.terms.successor
                            )
                        )
                ) return true;
            }
        }
        return false;
    }

    function _key(bytes32[] memory keys, uint256 n, bytes32 value) private pure returns (uint256) {
        if (value == 0) revert IH.InvalidRecoveredIdentity(value);
        uint256 at;
        while (at < n && keys[at] < value) ++at;
        if (at < n && keys[at] == value) return n;
        for (uint256 j = n; j > at; --j) {
            keys[j] = keys[j - 1];
        }
        keys[at] = value;
        return n + 1;
    }

    function _address(address[] memory keys, uint256 n, address value)
        private
        pure
        returns (uint256)
    {
        if (value == address(0)) revert IH.InvalidRecoveredIdentity(bytes32(0));
        uint256 at;
        while (at < n && keys[at] < value) ++at;
        if (at < n && keys[at] == value) return n;
        for (uint256 j = n; j > at; --j) {
            keys[j] = keys[j - 1];
        }
        keys[at] = value;
        return n + 1;
    }

    function _repudiation() private pure returns (Repudiation storage s) {
        bytes32 slot = keccak256("6529STREAM_ARTIST_REPUDIATION_TIMING_V1");
        assembly ("memory-safe") { s.slot := slot }
    }
}
