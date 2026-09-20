// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredTimingInventory as Timing
} from "./StreamArtistRecoveredTimingInventory.sol";

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistRecoveredIdentityHydrationOwner as Raw
} from "../../interfaces/stream/artist/IStreamArtistRecoveredIdentityHydrationOwner.sol";
import {
    IStreamArtistRecoveredHydrationOwner as Source
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    IStreamArtistIdentityOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationChronology as Chronology
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredIdentityHydrationRecords as Records
} from "./StreamArtistRecoveredIdentityHydrationRecords.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";

/// @notice Exact Identity transport from a fixed source and its complete flattened inventory.
/// @dev The enclosing operation authenticates all seven owner-local certificates.
/// Private-map rows come only from the pinned source's typed export, never from caller bodies.
/// Validation does not reauthorize old signatures or turn an auxiliary write into a native receipt.
library StreamArtistRecoveredIdentityHydrationSource {
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

    function collect(address source, AH.Query memory query, RH.OwnerProvenance memory provenance)
        public
        view
        returns (IH.Bundle memory bundle)
    {
        Provenance.validateOwnerSource(provenance, 2, source);
        uint256 last = provenance.eras.length - 1;
        if (
            query.artistId == 0 || provenance.origins[last].owners[2] != source
                || source.codehash != provenance.origins[last].ownerCodeHashes[2]
        ) {
            revert IH.InvalidRecoveredIdentity(query.artistId);
        }
        bundle = Raw(source).recoveredIdentityHydrationRaw(query, provenance);
        if (
            bundle.artistId != query.artistId || bundle.signatures.length != query.records.length
                || keccak256(abi.encode(bundle.sourceSnapshot))
                    != keccak256(
                        abi.encode(IStreamArtistIdentityOwner(source).ownerStateSnapshotV2())
                    )
        ) {
            revert IH.InvalidRecoveredIdentity(query.artistId);
        }
        for (uint256 i; i < query.records.length; ++i) {
            if (bundle.signatures[i].recordHash != query.records[i]) {
                revert IH.InvalidRecoveredIdentity(query.records[i]);
            }
        }
        Records.validate(source, bundle);
        validate(bundle, provenance);
        _sourceAuxiliary(source, bundle, provenance);
    }

    function encode(IH.Bundle memory bundle, RH.OwnerProvenance memory provenance)
        public
        pure
        returns (bytes memory)
    {
        validate(bundle, provenance);
        return abi.encode(IH.SCHEMA, bundle);
    }

    function decode(bytes memory raw, RH.OwnerProvenance memory provenance)
        public
        pure
        returns (IH.Bundle memory bundle)
    {
        bytes32 schema;
        (schema, bundle) = abi.decode(raw, (bytes32, IH.Bundle));
        if (schema != IH.SCHEMA || keccak256(raw) != keccak256(abi.encode(schema, bundle))) {
            revert IH.InvalidRecoveredIdentity(bytes32(0));
        }
        validate(bundle, provenance);
    }

    /// @dev Structural validation is additional to the enclosing source certificate, not a replacement.
    function validate(IH.Bundle memory b, RH.OwnerProvenance memory p)
        public
        pure
        returns (bytes32)
    {
        Provenance.validateOwner(p, 2);
        if (
            b.artistId == 0 || b.identity.authorityAddress == address(0)
                || (b.identity.authorityClass != 1 && b.identity.authorityClass != 3)
                || b.identity.status == 0 || b.recoveries.length == 0
                || keccak256(abi.encode(b.sourceSnapshot))
                    != keccak256(abi.encode(p.eras[p.eras.length - 1].checkpoint.ownerState))
        ) {
            revert IH.InvalidRecoveredIdentity(b.artistId);
        }
        Timing.validate(b.timing);
        _nativeRows(b, p);
        _causes(b, p);
        _vestings(b, p);
        _guardians(b, p);
        _actions(b, p);
        _closures(b);
        _documents(b);
        return keccak256(abi.encode(IH.SCHEMA, b));
    }

    function _nativeRows(IH.Bundle memory b, RH.OwnerProvenance memory p) private pure {
        uint256[62] memory counts;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory j = p.journal[i];
            if (j.receipt.artistId != b.artistId) continue;
            uint16 op = j.receipt.operation;
            // Collaborator/class4 hydration is a separate profile; it cannot be silently dropped.
            if (
                op == 44 || op == 45 || op == 46 || op == 47 || op == 48 || op == 49 || op == 50
                    || op == 59
            ) revert IH.InvalidRecoveredIdentity(j.receipt.recordHash);
            ++counts[op];
        }
        if (
            counts[1] != 1 || counts[19] != b.sanctionGrants.length
                || counts[23] != b.findings.length || counts[25] != b.revisions.length
                || counts[26] != b.delegations.length || counts[28] != b.guardians.length
                || counts[29] != b.rotations.length || counts[33] != b.contests.length * 2
                || counts[35] != b.recoveries.length * 2 || counts[36] != b.designations.length
                || counts[37] != b.directives.length || counts[38] != b.estates.length
                || counts[41] != b.notices.length || counts[51] != b.standingRecords.length
                || counts[58] != b.dismissals.length
        ) revert IH.InvalidRecoveredIdentity(b.artistId);
        for (uint256 i; i < b.revisions.length; ++i) {
            _native(p, b.artistId, b.revisions[i].position, 25, b.revisions[i].record.recordHash);
            if (i != 0) {
                _ordered(p, b.revisions[i - 1].position.point, b.revisions[i].position.point);
            }
        }
        uint256 revoked;
        for (uint256 i; i < b.delegations.length; ++i) {
            IH.DelegationRow memory r = b.delegations[i];
            _native(p, b.artistId, r.position, 26, r.recordHash);
            if (i != 0) _ordered(p, b.delegations[i - 1].position.point, r.position.point);
            if (r.record.revoked) {
                ++revoked;
                _occurrence(p, b.artistId, 27, r.record.revocationRecordHash);
            } else if (r.record.revocationRecordHash != 0) {
                revert IH.InvalidRecoveredIdentity(r.recordHash);
            }
        }
        if (revoked != counts[27]) revert IH.InvalidRecoveredIdentity(b.artistId);
        for (uint256 i; i < b.guardians.length; ++i) {
            _native(p, b.artistId, b.guardians[i].position, 28, b.guardians[i].record.recordHash);
        }
        for (uint256 i; i < b.rotations.length; ++i) {
            _native(p, b.artistId, b.rotations[i].position, 29, b.rotations[i].record.recordHash);
            if (i != 0) {
                _ordered(p, b.rotations[i - 1].position.point, b.rotations[i].position.point);
            }
        }
        for (uint256 i; i < b.contests.length; ++i) {
            uint256 at =
                _native(p, b.artistId, b.contests[i].position, 33, b.contests[i].record.recordHash);
            if (i != 0) {
                _ordered(p, b.contests[i - 1].position.point, b.contests[i].position.point);
            }
            if (
                at + 1 >= p.journal.length || p.journal[at + 1].receipt.operation != 33
                    || p.journal[at + 1].receipt.artistId != b.artistId
                    || !_samePoint(p.journal[at + 1].position.point, b.contests[i].position.point)
                    || !_causeReference(
                        b, p.journal[at + 1].receipt.recordHash, b.contests[i].record.recordHash
                    )
            ) revert IH.InvalidRecoveredIdentity(b.contests[i].record.recordHash);
        }
        for (uint256 i; i < b.recoveries.length; ++i) {
            IH.RecoveryRow memory r = b.recoveries[i];
            uint256 at = _native(p, b.artistId, r.position, 35, r.record.recordHash);
            if (i != 0) _ordered(p, b.recoveries[i - 1].position.point, r.position.point);
            if (
                at + 1 >= p.journal.length || p.journal[at + 1].receipt.operation != 35
                    || p.journal[at + 1].receipt.artistId != b.artistId
                    || p.journal[at + 1].receipt.recordHash != r.record.fields.supersededRecordsHash
                    || !_samePoint(p.journal[at + 1].position.point, r.position.point)
                    || r.primaryReceipt == 0 || r.secondaryReceipt == 0
                    || r.secondaryOccurrence == 0
            ) revert IH.InvalidRecoveredIdentity(r.record.recordHash);
        }
        for (uint256 i; i < b.designations.length; ++i) {
            _native(
                p, b.artistId, b.designations[i].position, 36, b.designations[i].record.recordHash
            );
            if (i != 0) {
                _ordered(p, b.designations[i - 1].position.point, b.designations[i].position.point);
            }
        }
        for (uint256 i; i < b.directives.length; ++i) {
            _native(p, b.artistId, b.directives[i].position, 37, b.directives[i].record.recordHash);
            if (i != 0) {
                _ordered(p, b.directives[i - 1].position.point, b.directives[i].position.point);
            }
        }
        for (uint256 i; i < b.estates.length; ++i) {
            _native(p, b.artistId, b.estates[i].position, 38, b.estates[i].request.recordHash);
            if (i != 0) _ordered(p, b.estates[i - 1].position.point, b.estates[i].position.point);
        }
        uint256 cancelled;
        uint256 completed;
        for (uint256 i; i < b.notices.length; ++i) {
            IH.NoticeRow memory r = b.notices[i];
            _native(p, b.artistId, r.position, 41, r.notice.recordHash);
            if (i != 0) _ordered(p, b.notices[i - 1].position.point, r.position.point);
            if (r.phase == 2) {
                ++cancelled;
                _occurrence(p, b.artistId, 42, r.terminal.recordHash);
            } else if (r.phase == 3) {
                ++completed;
                _occurrence(p, b.artistId, 43, r.terminal.recordHash);
            } else if (r.phase != 1 || r.terminal.recordHash != 0) {
                revert IH.InvalidRecoveredIdentity(r.notice.recordHash);
            }
        }
        if (cancelled != counts[42] || completed != counts[43]) {
            revert IH.InvalidRecoveredIdentity(b.artistId);
        }
        for (uint256 i; i < b.standingRecords.length; ++i) {
            _native(
                p,
                b.artistId,
                b.standingRecords[i].position,
                51,
                b.standingRecords[i].record.recordHash
            );
            if (i != 0) {
                _ordered(
                    p, b.standingRecords[i - 1].position.point, b.standingRecords[i].position.point
                );
            }
        }
        for (uint256 i; i < b.dismissals.length; ++i) {
            _native(p, b.artistId, b.dismissals[i].position, 58, b.dismissals[i].record.recordHash);
            if (i != 0) {
                _ordered(p, b.dismissals[i - 1].position.point, b.dismissals[i].position.point);
            }
        }
        for (uint256 i; i < b.sanctionGrants.length; ++i) {
            _native(
                p,
                b.artistId,
                b.sanctionGrants[i].position,
                19,
                b.sanctionGrants[i].record.recordHash
            );
            if (i != 0) {
                _ordered(
                    p, b.sanctionGrants[i - 1].position.point, b.sanctionGrants[i].position.point
                );
            }
        }
        for (uint256 i; i < b.findings.length; ++i) {
            _native(p, b.artistId, b.findings[i].position, 23, b.findings[i].record.recordHash);
            if (i != 0) {
                _ordered(p, b.findings[i - 1].position.point, b.findings[i].position.point);
            }
        }
    }

    function _causes(IH.Bundle memory b, RH.OwnerProvenance memory p) private pure {
        uint256 expected;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory row = p.journal[i];
            if (row.receipt.artistId == b.artistId && row.receipt.operation == 31) ++expected;
        }
        if (b.causes.length != expected + b.contests.length) {
            revert IH.InvalidRecoveredIdentity(b.artistId);
        }
        bytes32 previous;
        for (uint256 i; i < b.causes.length; ++i) {
            IH.CauseRow memory r = b.causes[i];
            if (
                r.cause.causeHash == 0 || r.cause.facts.artistId != b.artistId
                    || r.cause.facts.previousCauseHash != previous
            ) revert IH.InvalidRecoveredIdentity(r.cause.causeHash);
            RH.Point memory point = _occurrence(
                p, b.artistId, r.cause.facts.kind == 1 ? uint16(33) : uint16(31), r.cause.causeHash
            );
            if (!_samePoint(point, r.point)) revert IH.InvalidRecoveredIdentity(r.cause.causeHash);
            if (i != 0) _ordered(p, b.causes[i - 1].point, r.point);
            previous = r.cause.causeHash;
        }
        if (previous != b.heads.currentCause) {
            revert IH.InvalidRecoveredIdentity(b.heads.currentCause);
        }
    }

    function _vestings(IH.Bundle memory b, RH.OwnerProvenance memory p) private pure {
        uint256 expected = b.recoveries.length;
        for (uint256 i; i < b.rotations.length; ++i) {
            if (b.rotations[i].record.transition.executedAt != 0) ++expected;
        }
        for (uint256 i; i < b.estates.length; ++i) {
            if (b.estates[i].execution.executedAt != 0) ++expected;
        }
        for (uint256 i; i < b.notices.length; ++i) {
            if (b.notices[i].phase == 3) ++expected;
        }
        if (b.vestings.length != expected) revert IH.InvalidRecoveredIdentity(b.artistId);
        bytes32 previous;
        bytes32 commitment;
        for (uint256 i; i < b.vestings.length; ++i) {
            IH.VestingRow memory r = b.vestings[i];
            _point(p, r.point);
            if (
                r.snapshot.artistId != b.artistId || r.snapshot.transitionRecordHash == 0
                    || r.snapshot.commitment == 0
                    || r.snapshot.previousTransitionRecordHash != previous
                    || r.snapshot.previousCommitment != commitment
                    || r.snapshot.ownerRevision != r.point.ownerRevision
                    || (r.snapshot.authorityClass != 1 && r.snapshot.authorityClass != 3)
            ) revert IH.InvalidRecoveredIdentity(r.snapshot.transitionRecordHash);
            if (i != 0) _ordered(p, b.vestings[i - 1].point, r.point);
            bool actual;
            for (uint256 j; j < b.rotations.length; ++j) {
                if (
                    r.snapshot.operationId == 32
                        && b.rotations[j].record.recordHash == r.snapshot.transitionRecordHash
                        && b.rotations[j].record.transition.executedAt == r.snapshot.executedAt
                        && r.snapshot.executedAt != 0
                ) actual = true;
            }
            for (uint256 j; j < b.recoveries.length; ++j) {
                if (
                    r.snapshot.operationId == 35
                        && b.recoveries[j].record.recordHash == r.snapshot.transitionRecordHash
                        && _samePoint(b.recoveries[j].position.point, r.point)
                ) actual = true;
            }
            for (uint256 j; j < b.estates.length; ++j) {
                if (
                    r.snapshot.operationId == 40
                        && b.estates[j].request.recordHash == r.snapshot.transitionRecordHash
                        && b.estates[j].execution.executedAt == r.snapshot.executedAt
                        && r.snapshot.executedAt != 0
                ) actual = true;
            }
            for (uint256 j; j < b.notices.length; ++j) {
                if (
                    r.snapshot.operationId == 43
                        && b.notices[j].terminal.recordHash == r.snapshot.transitionRecordHash
                        && b.notices[j].phase == 3
                        && _samePoint(
                            _occurrence(p, b.artistId, 43, r.snapshot.transitionRecordHash), r.point
                        )
                ) actual = true;
            }
            if (!actual) revert IH.InvalidRecoveredIdentity(r.snapshot.transitionRecordHash);
            previous = r.snapshot.transitionRecordHash;
            commitment = r.snapshot.commitment;
        }
        if (
            b.heads.latestVesting != previous || b.heads.latestExecution != previous
                || b.heads.latestRecovery != b.recoveries[b.recoveries.length - 1].record.recordHash
        ) revert IH.InvalidRecoveredIdentity(b.artistId);
    }

    function _guardians(IH.Bundle memory b, RH.OwnerProvenance memory p) private pure {
        if (
            b.heads.guardianHistory.count != b.guardians.length
                || b.heads.guardianRecordsSeen != b.guardians.length
                || b.heads.guardianIndex.count != b.guardians.length
                || b.heads.guardianIndex.historyCommitment != b.heads.guardianHistory.commitment
        ) revert IH.InvalidRecoveredIdentity(b.artistId);
        bytes32 previous;
        for (uint256 i; i < b.guardians.length; ++i) {
            IH.GuardianRow memory r = b.guardians[i];
            if (
                r.entry.artistId != b.artistId || r.entry.index != i + 1
                    || r.entry.recordHash != r.record.recordHash
                    || r.entry.ownerRevision != r.position.point.ownerRevision
                    || r.entry.previousCommitment != previous
                    || r.entry.recordDataHash != keccak256(abi.encode(r.record))
            ) revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            if (i != 0) _ordered(p, b.guardians[i - 1].position.point, r.position.point);
            previous = r.entry.commitment;
            for (uint256 j; j < r.record.terms.guardians.length; ++j) {
                bool found;
                for (uint256 k; k < b.memberships.length; ++k) {
                    if (b.memberships[k].actor == r.record.terms.guardians[j]) found = true;
                }
                if (!found) revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            }
        }
        if (previous != b.heads.guardianHistory.commitment) {
            revert IH.InvalidRecoveredIdentity(b.artistId);
        }
        address previousActor;
        for (uint256 i; i < b.memberships.length; ++i) {
            IH.MembershipRow memory r = b.memberships[i];
            if (r.actor <= previousActor || r.indices.length == 0 || r.first != r.indices[0]) {
                revert IH.InvalidRecoveredIdentity(b.artistId);
            }
            previousActor = r.actor;
            uint256 cursor;
            for (uint256 j; j < b.guardians.length; ++j) {
                bool member;
                for (uint256 k; k < b.guardians[j].record.terms.guardians.length; ++k) {
                    if (b.guardians[j].record.terms.guardians[k] == r.actor) member = true;
                }
                if (member) {
                    if (cursor >= r.indices.length || r.indices[cursor++] != j + 1) {
                        revert IH.InvalidRecoveredIdentity(b.artistId);
                    }
                }
            }
            if (cursor != r.indices.length) revert IH.InvalidRecoveredIdentity(b.artistId);
        }
        for (uint256 i; i < b.rotations.length; ++i) {
            IH.RotationRow memory r = b.rotations[i];
            bool found;
            for (uint256 j; j < b.guardians.length; ++j) {
                if (b.guardians[j].record.recordHash == r.record.guardianSetRecordHash) {
                    found = true;
                    if (r.approvals.length != b.guardians[j].record.terms.guardians.length) {
                        revert IH.InvalidRecoveredIdentity(r.record.recordHash);
                    }
                }
            }
            uint256 approved;
            for (uint256 j; j < r.approvals.length; ++j) {
                if (r.approvals[j]) ++approved;
            }
            if (!found || approved != r.record.guardianApprovals) {
                revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            }
        }
    }

    function _actions(IH.Bundle memory b, RH.OwnerProvenance memory p) private pure {
        for (uint256 i; i < b.actions.length; ++i) {
            IH.ActionRow memory r = b.actions[i];
            bytes32 key = r.association.action.actionId;
            _point(p, r.point);
            if (
                key == 0 || r.association.artistId != b.artistId
                    || r.association.ownerRevision != r.point.ownerRevision
                    || r.excludedMemberships.length != b.memberships.length
            ) revert IH.InvalidRecoveredIdentity(key);
            if (i != 0) _ordered(p, b.actions[i - 1].point, r.point);
            bool found;
            for (uint256 j; j < p.aliases.length; ++j) {
                RH.ReplayAlias memory a = p.aliases[j];
                if (
                    a.surface == PREPARATION && a.scope == key
                        && a.cell.commitment == r.association.associationHash
                        && _samePoint(a.admittedAt, r.point)
                ) found = true;
            }
            if (!found) revert IH.InvalidRecoveredIdentity(key);
            if (r.execution != 0) {
                bool executed;
                for (uint256 j; j < b.recoveries.length; ++j) {
                    if (
                        b.recoveries[j].record.recordHash == r.execution
                            && b.recoveries[j].record.fields.governanceActionId == key
                    ) {
                        _ordered(p, r.point, b.recoveries[j].position.point);
                        executed = true;
                    }
                }
                if (!executed) revert IH.InvalidRecoveredIdentity(key);
            }
        }
        for (uint256 i; i < b.recoveries.length; ++i) {
            bool found;
            for (uint256 j; j < b.actions.length; ++j) {
                if (b.actions[j].execution == b.recoveries[i].record.recordHash) found = true;
            }
            if (!found) revert IH.InvalidRecoveredIdentity(b.recoveries[i].record.recordHash);
        }
        if (b.heads.pendingRecoveryAction != 0) {
            bool found;
            for (uint256 i; i < b.actions.length; ++i) {
                if (b.actions[i].association.action.actionId == b.heads.pendingRecoveryAction) {
                    found = true;
                }
            }
            if (!found) revert IH.InvalidRecoveredIdentity(b.heads.pendingRecoveryAction);
        }
    }

    function _closures(IH.Bundle memory b) private pure {
        uint256 expected = b.rotations.length + b.recoveries.length + b.estates.length;
        for (uint256 i; i < b.notices.length; ++i) {
            if (b.notices[i].phase == 3) {
                ++expected;
                _closure(b, b.notices[i].terminal.recordHash);
            }
        }
        if (expected != b.closures.length) revert IH.InvalidRecoveredIdentity(b.artistId);
        for (uint256 i; i < b.rotations.length; ++i) {
            _closure(b, b.rotations[i].record.recordHash);
        }
        for (uint256 i; i < b.recoveries.length; ++i) {
            _closure(b, b.recoveries[i].record.recordHash);
        }
        for (uint256 i; i < b.estates.length; ++i) {
            _closure(b, b.estates[i].request.recordHash);
        }
        for (uint256 i; i < b.closures.length; ++i) {
            D.Closure memory c = b.closures[i].closure;
            if (c.dismissalRecordHash == 0) {
                D.Closure memory empty;
                if (keccak256(abi.encode(c)) != keccak256(abi.encode(empty))) {
                    revert IH.InvalidRecoveredIdentity(b.closures[i].transition);
                }
            } else {
                if (c.artistId != b.artistId || c.transitionRecordHash != b.closures[i].transition) revert IH.InvalidRecoveredIdentity(c.transitionRecordHash);
                bool found;
                for (uint256 j; j < b.dismissals.length; ++j) {
                    if (b.dismissals[j].record.recordHash == c.dismissalRecordHash) found = true;
                }
                if (!found) revert IH.InvalidRecoveredIdentity(c.dismissalRecordHash);
            }
        }
    }

    function _documents(IH.Bundle memory b) private pure {
        if (keccak256(b.identityDocument) != b.identity.identityRecordHash) {
            revert IH.InvalidRecoveredIdentity(b.artistId);
        }
        _document(b, b.identity.identityRecordHash);
        for (uint256 i; i < b.revisions.length; ++i) {
            _document(b, b.revisions[i].record.previousRecordHash);
            _document(b, b.revisions[i].record.revisedRecordHash);
        }
        bytes32 previous;
        for (uint256 i; i < b.documents.length; ++i) {
            IH.DocumentRow memory d = b.documents[i];
            if (d.documentHash <= previous || keccak256(d.document) != d.documentHash) {
                revert IH.InvalidRecoveredIdentity(d.documentHash);
            }
            previous = d.documentHash;
            bool used = d.documentHash == b.identity.identityRecordHash;
            for (uint256 j; j < b.revisions.length; ++j) {
                if (
                    d.documentHash == b.revisions[j].record.previousRecordHash
                        || d.documentHash == b.revisions[j].record.revisedRecordHash
                ) used = true;
            }
            if (!used) revert IH.InvalidRecoveredIdentity(d.documentHash);
        }
    }

    function _sourceAuxiliary(address source, IH.Bundle memory b, RH.OwnerProvenance memory p)
        private
        view
    {
        for (uint256 i; i < p.aliases.length; ++i) {
            RH.ReplayAlias memory a = p.aliases[i];
            if (
                a.surface != PREPARATION
                    || Raw(source).recoveredIdentityHydrationActionArtist(a.scope) != b.artistId
            ) continue;
            bool found;
            for (uint256 j; j < b.actions.length; ++j) {
                if (b.actions[j].association.action.actionId == a.scope) found = true;
            }
            if (!found) revert IH.InvalidRecoveredIdentity(a.scope);
        }
        for (uint256 i; i < b.vestings.length; ++i) {
            _aux(
                source, VESTING, b.vestings[i].snapshot.transitionRecordHash, b.vestings[i].point, p
            );
        }
        for (uint256 i; i < b.actions.length; ++i) {
            _aux(
                source, PREPARATION, b.actions[i].association.action.actionId, b.actions[i].point, p
            );
        }
        for (uint256 i; i < b.originalContinuations.length; ++i) {
            _aux(
                source,
                ORIGINAL_CONTINUATION,
                b.originalContinuations[i].continuation.continuationHash,
                b.originalContinuations[i].point,
                p
            );
        }
        for (uint256 i; i < b.revisionContinuations.length; ++i) {
            _aux(
                source,
                REVISION_CONTINUATION,
                b.revisionContinuations[i].continuation.continuationHash,
                b.revisionContinuations[i].point,
                p
            );
        }
        for (uint256 i; i < b.standingContinuations.length; ++i) {
            _aux(
                source,
                STANDING_CONTINUATION,
                b.standingContinuations[i].continuation.continuationHash,
                b.standingContinuations[i].point,
                p
            );
        }
        for (uint256 i; i < b.capabilityContinuations.length; ++i) {
            _aux(
                source,
                CAPABILITY_CONTINUATION,
                b.capabilityContinuations[i].continuation.recoveryRecordHash,
                b.capabilityContinuations[i].point,
                p
            );
        }
    }

    function _aux(
        address source,
        bytes32 surface,
        bytes32 key,
        RH.Point memory point,
        RH.OwnerProvenance memory p
    ) private view {
        _point(p, point);
        if (
            key == 0
                || !_samePoint(point, Source(source).recoveredHydrationAuxiliaryPoint(surface, key))
        ) revert IH.InvalidRecoveredIdentity(key);
    }

    function _native(
        RH.OwnerProvenance memory p,
        bytes32 artist,
        RH.Position memory position,
        uint16 op,
        bytes32 key
    ) private pure returns (uint256) {
        _point(p, position.point);
        if (key == 0) revert IH.InvalidRecoveredIdentity(key);
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory j = p.journal[i];
            if (
                j.receipt.operation == op && j.receipt.artistId == artist
                    && j.receipt.recordHash == key
                    && keccak256(abi.encode(j.position)) == keccak256(abi.encode(position))
            ) return i;
        }
        revert IH.InvalidRecoveredIdentity(key);
    }

    function _occurrence(RH.OwnerProvenance memory p, bytes32 artist, uint16 op, bytes32 key)
        private
        pure
        returns (RH.Point memory point)
    {
        bool found;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory j = p.journal[i];
            if (
                j.receipt.operation != op || j.receipt.artistId != artist
                    || j.receipt.recordHash != key
            ) continue;
            if (found || key == 0) revert IH.InvalidRecoveredIdentity(key);
            found = true;
            point = j.position.point;
        }
        if (!found) revert IH.InvalidRecoveredIdentity(key);
    }

    function _point(RH.OwnerProvenance memory p, RH.Point memory point) private pure {
        if (point.ownerIndex != 2) revert IH.InvalidRecoveredIdentity(point.environmentHash);
        Chronology.validateOwnerPoint(p, 2, point);
    }

    function _ordered(RH.OwnerProvenance memory p, RH.Point memory a, RH.Point memory b)
        private
        pure
    {
        if (!Chronology.beforeOwner(p, 2, a, b)) {
            revert IH.InvalidRecoveredIdentity(b.environmentHash);
        }
    }

    function _samePoint(RH.Point memory a, RH.Point memory b) private pure returns (bool) {
        return keccak256(abi.encode(a)) == keccak256(abi.encode(b));
    }

    function _causeReference(IH.Bundle memory b, bytes32 cause, bytes32 record)
        private
        pure
        returns (bool)
    {
        for (uint256 i; i < b.causes.length; ++i) {
            if (
                b.causes[i].cause.causeHash == cause && b.causes[i].cause.facts.kind == 1
                    && b.causes[i].cause.facts.referenceHash == record
            ) return true;
        }
        return false;
    }

    function _closure(IH.Bundle memory b, bytes32 key) private pure {
        uint256 found;
        for (uint256 i; i < b.closures.length; ++i) {
            if (b.closures[i].transition == key && key != 0) ++found;
        }
        if (found != 1) revert IH.InvalidRecoveredIdentity(key);
    }

    function _document(IH.Bundle memory b, bytes32 key) private pure {
        for (uint256 i; i < b.documents.length; ++i) {
            if (b.documents[i].documentHash == key) return;
        }
        revert IH.InvalidRecoveredIdentity(key);
    }
}
