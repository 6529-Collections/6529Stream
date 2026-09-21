// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

import {
    StreamArtistRecoveredHydrationChronology as Chronology
} from "./StreamArtistRecoveredHydrationChronology.sol";

/// @notice Fixed original Identity source validation stage.
library StreamArtistRecoveredIdentitySourceNative {
    function validate(IH.Bundle calldata b, RH.OwnerProvenance calldata p) public pure {
        uint256[62] memory counts;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory j = p.journal[i];
            if (j.receipt.artistId != b.artistId) continue;
            uint16 op = j.receipt.operation;
            // Collaborator/class4 hydration is a separate profile; it cannot be silently dropped.
            if (
                op == 44 || op == 45 || op == 46 || op == 47 || op == 49 || op == 50
                    || op == 59
            ) revert IH.InvalidRecoveredIdentity(j.receipt.recordHash);
            ++counts[op];
        }
        if (
            counts[1] != 1 || counts[19] != b.sanctionGrants.length
                || counts[23] != b.findings.length || counts[25] != b.revisions.length
                || counts[26] != b.delegations.length || counts[28] != b.guardians.length
                || counts[29] != b.rotations.length || counts[33] + counts[48] != b.contests.length * 2
                || counts[33] % 2 != 0 || counts[48] % 2 != 0
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
            IH.DelegationRow calldata r = b.delegations[i];
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
            uint16 operation = _contestOperation(p, b.contests[i].record.recordHash);
            uint256 at =
                _native(p, b.artistId, b.contests[i].position, operation, b.contests[i].record.recordHash);
            if (i != 0) {
                _ordered(p, b.contests[i - 1].position.point, b.contests[i].position.point);
            }
            if (
                at + 1 >= p.journal.length || p.journal[at + 1].receipt.operation != operation
                    || p.journal[at + 1].receipt.artistId != b.artistId
                    || !_samePoint(p.journal[at + 1].position.point, b.contests[i].position.point)
                    || !_causeReference(
                        b, p.journal[at + 1].receipt.recordHash, b.contests[i].record.recordHash
                    )
            ) revert IH.InvalidRecoveredIdentity(b.contests[i].record.recordHash);
        }
        for (uint256 i; i < b.recoveries.length; ++i) {
            IH.RecoveryRow calldata r = b.recoveries[i];
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
            IH.NoticeRow calldata r = b.notices[i];
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

    /// @dev Original48 appends the same canonical Contest then Cause pair under its own ID.
    function _contestOperation(RH.OwnerProvenance calldata p, bytes32 record)
        private pure returns (uint16 operation)
    {
        for (uint256 i; i < p.journal.length; ++i) {
            if (p.journal[i].receipt.recordHash != record) continue;
            uint16 op = p.journal[i].receipt.operation;
            if (operation != 0 || (op != 33 && op != 48)) revert IH.InvalidRecoveredIdentity(record);
            operation = op;
        }
        if (operation == 0) revert IH.InvalidRecoveredIdentity(record);
    }

    function _native(
        RH.OwnerProvenance calldata p,
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

    function _occurrence(RH.OwnerProvenance calldata p, bytes32 artist, uint16 op, bytes32 key)
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

    function _point(RH.OwnerProvenance calldata p, RH.Point memory point) private pure {
        if (point.ownerIndex != 2) revert IH.InvalidRecoveredIdentity(point.environmentHash);
        Chronology.validateOwnerPoint(p, 2, point);
    }

    function _ordered(RH.OwnerProvenance calldata p, RH.Point memory a, RH.Point memory b)
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

    function _causeReference(IH.Bundle calldata b, bytes32 cause, bytes32 record)
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
}
