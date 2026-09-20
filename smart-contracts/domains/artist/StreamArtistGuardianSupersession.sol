// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";

import {
    StreamArtistGuardianSupersessionTypes as S
} from "../../interfaces/stream/artist/StreamArtistGuardianSupersessionTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityContestTypes as C
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    IStreamArtistIdentityContestOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import { StreamArtistGuardianHistory as History } from "./StreamArtistGuardianHistory.sol";
import {
    StreamArtistGuardianVestingHistory as Vesting
} from "./StreamArtistGuardianVestingHistory.sol";
import { StreamArtistRotationState as Rotations } from "./StreamArtistRotationState.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistCurrentCompromiseReads as Current
} from "./StreamArtistCurrentCompromiseReads.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    StreamArtistGuardianAppealTypes as Appeal
} from "../../interfaces/stream/artist/StreamArtistGuardianAppealTypes.sol";
import { StreamArtistGuardianAppealReads } from "./StreamArtistGuardianAppealReads.sol";
import { StreamArtistGuardianSelectionReads } from "./StreamArtistGuardianSelectionReads.sol";
import {
    StreamArtistGuardianSelectionTypes as Selection
} from "../../interfaces/stream/artist/StreamArtistGuardianSelectionTypes.sol";

import {
    StreamArtistGuardianSupersessionCutoff as Cutoff
} from "./StreamArtistGuardianSupersessionCutoff.sol";

import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";

/// @notice Exact current-contest guardian adjudication through admitted living and estate history.
/// @dev Fixed Identity owner authenticates governance, current cause and original rotation.
library StreamArtistGuardianSupersession {
    struct State {
        mapping(bytes32 => S.IndexHead) indexedHeads;
        mapping(bytes32 => mapping(address => uint64[])) memberships;
        mapping(bytes32 => S.Plan) plans;
        mapping(bytes32 => S.Status) statuses;
        mapping(bytes32 => mapping(address => uint64)) excludedMemberships;
        mapping(bytes32 => Selection.Result) elections;
        mapping(bytes32 => R.GuardianRecord) restoredGuardians;
    }

    /// @dev Called only after the same owner's successful original operation28 and History.append.
    function indexAdmission(State storage s, GH.Entry memory entry, R.GuardianRecord memory record)
        public
        returns (bytes32)
    {
        S.IndexHead storage head = s.indexedHeads[entry.artistId];
        if (
            entry.artistId == 0 || entry.recordHash == 0 || entry.index != head.count + 1
                || entry.previousCommitment != head.historyCommitment || entry.commitment == 0
                || record.recordHash != entry.recordHash || record.terms.artistId != entry.artistId
                || entry.recordDataHash != keccak256(abi.encode(record))
        ) {
            revert S.IncompleteGuardianMembershipIndex(entry.artistId);
        }
        for (uint256 i; i < record.terms.guardians.length; ++i) {
            uint64[] storage indices = s.memberships[entry.artistId][record.terms.guardians[i]];
            if (indices.length != 0 && indices[indices.length - 1] >= entry.index) {
                revert S.IncompleteGuardianMembershipIndex(entry.artistId);
            }
            indices.push(entry.index);
        }
        head.count = entry.index;
        head.historyCommitment = entry.commitment;
        return
            keccak256(
                abi.encode(keccak256("6529STREAM_ARTIST_GUARDIAN_MEMBERSHIP_INDEX_V1"), entry)
            );
    }

    function context(
        State storage s,
        History.State storage history,
        Vesting.State storage vesting,
        Rotations.State storage rotations,
        StreamArtistHashes.Environment memory environment,
        D.Cause memory cause,
        Recovery.Request memory request,
        uint64 actualCount
    ) public view returns (bytes32) {
        if (request.supersededRecordHashes.length == 0) return bytes32(0);
        GH.Head memory head = History.requireComplete(history, request.artistId, actualCount);
        _complete(s, request.artistId, head);
        bytes32 transition = rotations.latestExecution[request.artistId];
        V.Snapshot memory cutoff =
            Cutoff.current(vesting, history, rotations, request.artistId, head);
        if (
            request.supersededRecordHashes.length > 64 || cause.facts.kind != 1
                || cause.facts.artistId != request.artistId
                || cause.facts.executedTransitionHash != transition
                || cutoff.newAddress != cause.facts.incumbent
                || cutoff.authorityClass != cause.facts.authorityClass
                || request.vestedAuthorityClass != cutoff.authorityClass
        ) {
            revert S.InvalidGuardianSupersession(transition);
        }
        C.Record memory contest = IStreamArtistIdentityContestOwner(address(this))
            .identityContestRecord(cause.facts.referenceHash);
        Appeal.Finding[] memory findings = _admissions(
            s, history, rotations, request.artistId, request.supersededRecordHashes, cutoff, head
        );
        bool appeal = findings.length != 0;
        bytes32 currentProof;
        if (appeal) {
            // Authenticate the original contest using its own evidence. The new request links the hostile document separately.
            Recovery.Request memory original = Recovery.Request(
                request.artistId,
                request.newAddress,
                request.vestedAuthorityClass,
                request.expectedCauseHash,
                request.expectedResolutionHash,
                contest.terms.evidenceHash,
                request.reasonHash,
                request.supersededRecordHashes
            );
            currentProof = _currentContest(environment, original, cause, contest, transition);
        } else {
            if (
                cutoff.guardians.count >= head.count
                    || !_afterCutoff(
                        environment,
                        cutoff,
                        history.entries[history.records[request.artistId][head.count]]
                    )
            ) {
                revert S.InvalidGuardianSupersession(transition);
            }
            currentProof = _currentContest(environment, request, cause, contest, transition);
        }
        bytes32 selected = Rotations.operativeGuardian(rotations, request.artistId);
        R.GuardianRecord storage operative = rotations.guardians[selected];
        if (selected == 0 || operative.recordHash != selected) {
            revert S.InvalidGuardianSupersession(selected);
        }
        bytes32 commitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_POSTVESTING_GUARDIAN_SUPERSESSION_V1"),
                cutoff,
                contest,
                head,
                selected,
                request.supersededRecordHashes
            )
        );
        if (currentProof != 0) {
            commitment = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_CURRENT_CONTEST_GUARDIAN_SUPERSESSION_V1"),
                    commitment,
                    currentProof
                )
            );
        }
        if (appeal) {
            commitment = keccak256(
                abi.encode(
                    commitment,
                    StreamArtistGuardianAppealReads.requireEvidence(
                        environment, request, cause, contest, cutoff, findings
                    )
                )
            );
        }
        Selection.Result memory chosen =
            election(s, history, rotations, environment, request, actualCount);
        if (chosen.commitment == 0) return commitment;
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_GUARDIAN_HEAD_SUPERSESSION_CONTEXT_V1"),
                commitment,
                chosen
            )
        );
    }

    /// @notice Policy classification only after exact owner-local chronology, record identity and status checks.
    /// @dev Full current cause/context validation precedes the Coordinator's use of this getter.
    function authorityRole(
        State storage s,
        History.State storage history,
        Vesting.State storage vesting,
        Rotations.State storage rotations,
        bytes32 artistId,
        bytes32[] memory records,
        uint64 actualCount
    ) public view returns (bytes32) {
        if (records.length == 0) return Appeal.ARBITER;
        GH.Head memory head = History.requireComplete(history, artistId, actualCount);
        _complete(s, artistId, head);
        bytes32 transition = rotations.latestExecution[artistId];
        V.Snapshot memory cutoff = Cutoff.current(vesting, history, rotations, artistId, head);
        return _admissions(s, history, rotations, artistId, records, cutoff, head).length == 0
            ? Appeal.ARBITER
            : Appeal.APPEAL;
    }

    function _admissions(
        State storage s,
        History.State storage history,
        Rotations.State storage rotations,
        bytes32 artistId,
        bytes32[] memory records,
        V.Snapshot memory cutoff,
        GH.Head memory head
    ) private view returns (Appeal.Finding[] memory findings) {
        if (records.length == 0 || records.length > 64) {
            revert S.InvalidGuardianSupersession(artistId);
        }
        findings = new Appeal.Finding[](records.length);
        bool imported = Imported.commitment() != 0;
        Runtime.Context memory clock;
        Runtime.OriginFact memory cutoffOrigin;
        if (imported) {
            IStreamArtistOwner owner = IStreamArtistOwner(address(this));
            clock = Recovered.load(address(this), owner.artistRegistry(), owner.deploymentChainId());
            cutoffOrigin = Recovered.vesting(clock, cutoff);
        }
        uint256 count;
        bytes32 previous;
        for (uint256 i; i < records.length; ++i) {
            bytes32 hash = records[i];
            GH.Entry storage entry = history.entries[hash];
            R.GuardianRecord storage record = rotations.guardians[hash];
            if (
                hash <= previous || entry.recordHash != hash || entry.artistId != artistId
                    || entry.index == 0 || entry.index > head.count || entry.ownerRevision == 0
                    || (!imported && entry.ownerRevision > head.ownerRevision)
                    || history.records[artistId][entry.index] != hash || entry.commitment == 0
                    || record.recordHash != hash || record.terms.artistId != artistId
                    || (record.authorityClass != 1 && record.authorityClass != 3)
                    || record.signer == address(0)
                    || entry.recordDataHash != keccak256(abi.encode(record))
                    || s.statuses[hash].recoveryRecordHash != 0
            ) {
                revert S.InvalidGuardianSupersession(hash);
            }
            Runtime.OriginFact memory entryOrigin;
            if (imported) entryOrigin = Recovered.guardian(clock, entry, record);
            if (entry.index <= cutoff.guardians.count) {
                if (
                    (!imported
                            && (entry.ownerRevision > cutoff.guardians.ownerRevision
                                || entry.ownerRevision >= cutoff.ownerRevision))
                        || (imported
                            && !Runtime.before(clock, entryOrigin.point, cutoffOrigin.point))
                        || record.terms.guardians.length == 0
                ) revert S.InvalidGuardianSupersession(hash);
                findings[count++] = Appeal.Finding(hash, record.terms.guardians);
            } else if (
                (imported
                            ? !Runtime.before(clock, cutoffOrigin.point, entryOrigin.point)
                            : entry.ownerRevision <= cutoff.ownerRevision)
                    || record.signer != cutoff.newAddress
                    || record.authorityClass != cutoff.authorityClass
            ) {
                revert S.InvalidGuardianSupersession(hash);
            }
            previous = hash;
        }
        assembly ("memory-safe") { mstore(findings, count) }
    }

    function election(
        State storage s,
        History.State storage history,
        Rotations.State storage rotations,
        StreamArtistHashes.Environment memory environment,
        Recovery.Request memory request,
        uint64 actualCount
    ) public view returns (Selection.Result memory result) {
        if (!_requiresElection(rotations, request.artistId, request.supersededRecordHashes)) return result;
        GH.Head memory head = History.requireComplete(history, request.artistId, actualCount);
        _complete(s, request.artistId, head);
        R.TransitionState memory transition =
            Rotations.transitionState(rotations, rotations.latestExecution[request.artistId]);
        result = StreamArtistGuardianSelectionReads.requireSelection(
            environment, request.artistId, head, transition, request.supersededRecordHashes
        );
        if (result.selectedRecordHash != 0) {
            R.GuardianRecord storage record = rotations.guardians[result.selectedRecordHash];
            GH.Entry storage entry = history.entries[result.selectedRecordHash];
            if (
                record.recordHash != result.selectedRecordHash
                    || record.terms.artistId != request.artistId
                    || record.nonce != result.selectedNonce
                    || keccak256(abi.encode(record)) != result.selectedDataHash
                    || entry.recordDataHash != result.selectedDataHash || entry.index == 0
                    || entry.index > head.count
                    || history.records[request.artistId][entry.index] != record.recordHash
                    || s.statuses[record.recordHash].recoveryRecordHash != 0
                    || !Rotations.eligible(rotations, request.artistId, record.provisional)
            ) revert Selection.InvalidGuardianSelection(result.sourceKey);
            for (uint256 i; i < request.supersededRecordHashes.length; ++i) {
                if (request.supersededRecordHashes[i] == record.recordHash) {
                    revert Selection.InvalidGuardianSelection(result.sourceKey);
                }
            }
        }
    }

    function recoveryWindow(
        State storage s,
        History.State storage history,
        Rotations.State storage rotations,
        StreamArtistHashes.Environment memory environment,
        Recovery.Request memory request,
        uint64 actualCount,
        uint64 globalWindow
    ) public view returns (uint64) {
        Selection.Result memory result =
            election(s, history, rotations, environment, request, actualCount);
        bytes32 selected = result.commitment == 0
            ? Rotations.operativeGuardian(rotations, request.artistId)
            : result.selectedRecordHash;
        uint64 minimum = rotations.guardians[selected].terms.minContestSeconds;
        return minimum > globalWindow ? minimum : globalWindow;
    }

    function contextAndWindow(
        State storage s,
        History.State storage history,
        Vesting.State storage vesting,
        Rotations.State storage rotations,
        StreamArtistHashes.Environment memory environment,
        D.Cause memory cause,
        Recovery.Request memory request,
        uint64 actualCount,
        uint64 globalWindow
    ) public view returns (bytes32 commitment, uint64 window) {
        // Adjudicability precedes the new prepared-selection dependency.
        commitment =
            context(s, history, vesting, rotations, environment, cause, request, actualCount);
        window =
            recoveryWindow(s, history, rotations, environment, request, actualCount, globalWindow);
    }

    function _requiresElection(
        Rotations.State storage rotations,
        bytes32 artistId,
        bytes32[] memory list
    ) private view returns (bool) {
        bytes32 operative = Rotations.operativeGuardian(rotations, artistId);
        for (uint256 i; i < list.length; ++i) {
            if (
                list[i] == rotations.stableGuardian[artistId]
                    || list[i] == rotations.provisionalGuardian[artistId]
                    || rotations.guardians[list[i]].nonce >= rotations.guardians[operative].nonce
            ) return true;
        }
        return false;
    }

    function freezeWithSelection(
        State storage s,
        History.State storage history,
        Rotations.State storage rotations,
        StreamArtistHashes.Environment memory environment,
        Recovery.Request memory request,
        uint64 actualCount,
        bytes32 actionId,
        bytes32 associationHash,
        bytes32 commitment
    ) public returns (bytes32 delta) {
        Selection.Result memory result =
            election(s, history, rotations, environment, request, actualCount);
        delta = freeze(
            s,
            history,
            rotations,
            request.artistId,
            actionId,
            associationHash,
            commitment,
            request.supersededRecordHashes
        );
        if (result.commitment == 0) return delta;
        s.elections[actionId] = result;
        if (result.selectedRecordHash != 0) {
            s.restoredGuardians[actionId] = rotations.guardians[result.selectedRecordHash];
        }
        return keccak256(abi.encode(delta, result, s.restoredGuardians[actionId]));
    }

    function requireHeads(State storage s, Rotations.State storage rotations, bytes32 artistId)
        public
        view
    {
        bytes32 stable = rotations.stableGuardian[artistId];
        bytes32 provisional = rotations.provisionalGuardian[artistId];
        if (
            (stable != 0 && s.statuses[stable].recoveryRecordHash != 0)
                || (provisional != 0 && s.statuses[provisional].recoveryRecordHash != 0)
        ) {
            revert S.InvalidGuardianSupersession(artistId);
        }
    }

    function applyWithSelection(
        State storage s,
        Rotations.State storage rotations,
        mapping(bytes32 => bytes32) storage recoveryGuardians,
        bytes32 artistId,
        bytes32 actionId,
        bytes32 associationHash,
        bytes32 recoveryRecord,
        bytes32 commitment,
        bytes32[] memory excluded
    ) public returns (bytes32 delta) {
        delta = applyRecovery(
            s, artistId, actionId, associationHash, recoveryRecord, commitment, excluded
        );
        Selection.Result storage result = s.elections[actionId];
        if (result.commitment == 0) return delta;
        R.GuardianRecord storage selected = s.restoredGuardians[actionId];
        if (
            selected.recordHash != result.selectedRecordHash
                || (selected.recordHash != 0
                    && (keccak256(abi.encode(selected)) != result.selectedDataHash
                        || selected.nonce != result.selectedNonce
                        || s.statuses[selected.recordHash].recoveryRecordHash != 0))
        ) {
            revert Selection.InvalidGuardianSelection(result.sourceKey);
        }
        bytes32 oldStable = rotations.stableGuardian[artistId];
        bytes32 oldCandidate = rotations.provisionalGuardian[artistId];
        rotations.stableGuardian[artistId] = result.selectedRecordHash;
        delete rotations.provisionalGuardian[artistId];
        recoveryGuardians[recoveryRecord] = result.selectedRecordHash;
        requireHeads(s, rotations, artistId);
        return keccak256(
            abi.encode(
                delta,
                result,
                selected,
                oldStable,
                oldCandidate,
                rotations.stableGuardian[artistId],
                rotations.provisionalGuardian[artistId],
                recoveryRecord
            )
        );
    }

    function freeze(
        State storage s,
        History.State storage history,
        Rotations.State storage rotations,
        bytes32 artistId,
        bytes32 actionId,
        bytes32 associationHash,
        bytes32 commitment,
        bytes32[] memory excluded
    ) public returns (bytes32) {
        GH.Snapshot storage snapshot = history.snapshots[actionId];
        if (
            commitment == 0 || associationHash == 0 || excluded.length == 0 || excluded.length > 64
                || snapshot.artistId != artistId || snapshot.associationHash != associationHash
                || s.plans[actionId].associationHash != 0
        ) revert S.InvalidGuardianSupersession(actionId);
        s.plans[actionId] = S.Plan(
            artistId,
            associationHash,
            commitment,
            snapshot.count,
            snapshot.historyCommitment,
            excluded
        );
        for (uint256 i; i < excluded.length; ++i) {
            R.GuardianRecord storage record = rotations.guardians[excluded[i]];
            for (uint256 j; j < record.terms.guardians.length; ++j) {
                ++s.excludedMemberships[actionId][record.terms.guardians[j]];
            }
        }
        return keccak256(abi.encode(s.plans[actionId]));
    }

    function member(
        State storage s,
        History.State storage history,
        bytes32 artistId,
        bytes32 actionId,
        bytes32 associationHash,
        address actor
    ) public view returns (bool) {
        S.Plan storage plan = s.plans[actionId];
        GH.Snapshot storage snapshot = history.snapshots[actionId];
        if (
            plan.artistId != artistId || plan.associationHash != associationHash
                || associationHash == 0 || plan.count != snapshot.count
                || plan.historyCommitment != snapshot.historyCommitment
                || snapshot.artistId != artistId || snapshot.associationHash != associationHash
        ) {
            revert S.InvalidGuardianSupersession(actionId);
        }
        uint64[] storage indices = s.memberships[artistId][actor];
        uint256 low;
        uint256 high = indices.length;
        while (low < high) {
            uint256 mid = low + (high - low) / 2;
            if (indices[mid] <= plan.count) low = mid + 1;
            else high = mid;
        }
        uint256 excludedMemberships = s.excludedMemberships[actionId][actor];
        if (excludedMemberships > low) revert S.IncompleteGuardianMembershipIndex(artistId);
        return actor != address(0) && low > excludedMemberships;
    }

    function applyRecovery(
        State storage s,
        bytes32 artistId,
        bytes32 actionId,
        bytes32 associationHash,
        bytes32 recoveryRecord,
        bytes32 commitment,
        bytes32[] memory excluded
    ) public returns (bytes32) {
        S.Plan storage plan = s.plans[actionId];
        if (
            recoveryRecord == 0 || plan.artistId != artistId
                || plan.associationHash != associationHash || plan.contextCommitment != commitment
                || commitment == 0
                || keccak256(abi.encode(plan.excluded)) != keccak256(abi.encode(excluded))
        ) {
            revert S.InvalidGuardianSupersession(actionId);
        }
        for (uint256 i; i < excluded.length; ++i) {
            if (s.statuses[excluded[i]].recoveryRecordHash != 0) {
                revert S.InvalidGuardianSupersession(excluded[i]);
            }
            s.statuses[excluded[i]] = S.Status(artistId, recoveryRecord, actionId);
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_GUARDIAN_SUPERSESSION_APPLIED_V1"),
                artistId,
                actionId,
                associationHash,
                recoveryRecord,
                commitment,
                excluded
            )
        );
    }

    function _complete(State storage s, bytes32 artistId, GH.Head memory head) private view {
        S.IndexHead storage indexedHead = s.indexedHeads[artistId];
        if (indexedHead.count != head.count || indexedHead.historyCommitment != head.commitment) {
            revert S.IncompleteGuardianMembershipIndex(artistId);
        }
    }

    function _currentContest(
        StreamArtistHashes.Environment memory e,
        Recovery.Request memory p,
        D.Cause memory cause,
        C.Record memory c,
        bytes32 transition
    ) private view returns (bytes32) {
        if (
            Imported.commitment() == 0 && cause.facts.pendingTransitionHash == 0
                && c.terms.subjectRecordHash == transition
        ) {
            _contest(e, p, cause, c, transition);
            return 0;
        }
        if (
            c.terms.artistId != p.artistId || c.terms.evidenceHash != p.evidenceHash
                || c.terms.reasonHash != p.reasonHash || cause.facts.evidenceHash != p.evidenceHash
                || cause.facts.reasonHash != p.reasonHash
        ) revert S.InvalidGuardianSupersession(c.recordHash);
        bytes32 previous =
            IStreamArtistIdentityRecoveryOwner(address(this)).latestIdentityRecovery(p.artistId);
        bool legacyLiving = cause.facts.authorityClass == 1 && previous != 0
            && IStreamArtistIdentityRecoveryOwner(address(this)).identityRecoveryRecord(previous)
                    .fields.vestedAuthorityClass == 1
            && (cause.facts.pendingTransitionHash == 0
                || IStreamArtistRotationReads(address(this))
                    .rotationRecord(cause.facts.pendingTransitionHash)
                    .recordHash == cause.facts.pendingTransitionHash);
        R.TransitionState memory executed =
            IStreamArtistRotationReads(address(this)).artistTransitionState(transition);
        Current.Facts memory current = legacyLiving
            ? Current.read(address(this), e.registry, e.chainId, cause, executed)
            : Current.readFamily(address(this), e.registry, e.chainId, cause, executed);
        if (keccak256(abi.encode(current.contest)) != keccak256(abi.encode(c))) {
            revert S.InvalidGuardianSupersession(c.recordHash);
        }
        return current.proof;
    }

    function _contest(
        StreamArtistHashes.Environment memory e,
        Recovery.Request memory p,
        D.Cause memory cause,
        C.Record memory c,
        bytes32 transition
    ) private pure {
        if (
            c.recordHash == 0 || c.recordHash != cause.facts.referenceHash
                || c.terms.artistId != p.artistId || c.terms.subjectRecordHash != transition
                || c.terms.evidenceHash != p.evidenceHash || c.terms.reasonHash != p.reasonHash
                || cause.facts.evidenceHash != p.evidenceHash
                || cause.facts.reasonHash != p.reasonHash || c.contester != cause.facts.actor
                || c.contestedAt != cause.facts.enteredAt
                || c.priorStatus != cause.facts.priorStatus
                || !((cause.facts.authorityClass == 1 && c.priorStatus == 1)
                    || (cause.facts.authorityClass == 3 && c.priorStatus == 3))
                || c.pendingTransitionRecordHash != 0
                || c.executedTransitionRecordHash != transition
                || c.recordHash
                    != keccak256(
                        abi.encode(
                            bytes32(
                                0x26a4221cd1625ab88b1ac279e1708a73efa176e486242b26832cdc94fe25e6bb
                            ),
                            e.chainId,
                            e.registry,
                            p.artistId,
                            c.contester,
                            transition,
                            p.evidenceHash,
                            p.reasonHash,
                            c.contestedAt
                        )
                    )
        ) {
            revert S.InvalidGuardianSupersession(c.recordHash);
        }
    }

    function _afterCutoff(
        StreamArtistHashes.Environment memory e,
        V.Snapshot memory cutoff,
        GH.Entry memory entry
    ) private view returns (bool) {
        if (Imported.commitment() == 0) {
            return cutoff.ownerRevision < entry.ownerRevision;
        }
        Runtime.Context memory clock = Recovered.load(address(this), e.registry, e.chainId);
        return Runtime.before(
            clock,
            Recovered.vesting(clock, cutoff).point,
            Recovered.guardianEntry(clock, entry).point
        );
    }
}
