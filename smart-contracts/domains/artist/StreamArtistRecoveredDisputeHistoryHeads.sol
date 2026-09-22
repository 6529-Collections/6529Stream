// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";

/// @notice Fixed resolution-chain and latest-head validation for original disputes.
/// @dev Called after opening/counter/withdrawal checks. This pure boundary retains the
/// original resolution and head/current-state order; it does not authenticate source records or confer authority.
library StreamArtistRecoveredDisputeHistoryHeads {
    function validate(
        D.Bundle memory b,
        RH.OwnerProvenance memory p,
        bool sanctioned,
        bool checkCurrent
    ) public pure {
        for (uint256 i; i < b.resolutions.length; ++i) {
            D.ResolutionRow memory r = b.resolutions[i];
            uint256 opening = _opening(b, r.record.terms.disputeRecordHash);
            D.DisputeRow memory o = b.disputes[opening];
            if (
                o.record.terms.bindingGeneration != r.record.terms.bindingGeneration
                    || !Clock.beforeOwner(p, 4, o.point, r.point)
                    || r.record.resolvedAt < o.record.recordedAt || o.withdrawal.recordHash != 0
                    || r.record.terms.counterStatementRecordHash
                        != _counterBefore(b, o.record.recordHash, r.point, p)
                    || (_reopened(b, o, p) && r.record.actionClass != 2)
            ) _invalid();
            bytes32 previous;
            for (uint256 j; j < i; ++j) {
                if (
                    b.resolutions[j].record.terms.bindingGeneration
                        == r.record.terms.bindingGeneration
                ) {
                    previous = b.resolutions[j].record.actionId;
                }
            }
            if (r.record.previousResolutionActionId != previous) _invalid();
        }
        for (uint256 g; g < b.generations.length; ++g) {
            _head(b, uint64(g + 1), p, sanctioned, checkCurrent);
        }
    }

    function _head(
        D.Bundle memory b,
        uint64 generation,
        RH.OwnerProvenance memory p,
        bool sanctioned,
        bool checkCurrent
    ) private pure {
        AD.Head memory h = b.heads[generation - 1];
        uint256 latest = type(uint256).max;
        bytes32 resolution;
        for (uint256 i; i < b.disputes.length; ++i) {
            if (
                b.disputes[i].record.terms.bindingGeneration == generation
                    && b.disputes[i].record.terms.disputeAction == 1
            ) latest = i;
        }
        for (uint256 i; i < b.resolutions.length; ++i) {
            if (b.resolutions[i].record.terms.bindingGeneration == generation) {
                resolution = b.resolutions[i].record.actionId;
            }
        }
        if (latest == type(uint256).max) {
            AD.Head memory expected;
            expected.revocationReason = h.revocationReason;
            if (
                (h.revocationReason != 0 && h.revocationReason != 3)
                    || keccak256(abi.encode(h)) != keccak256(abi.encode(expected))
            ) _invalid();
        } else {
            D.DisputeRow memory o = b.disputes[latest];
            bytes32 counter;
            bool resolved;
            bool open = o.withdrawal.recordHash == 0;
            for (uint256 i; i < b.disputes.length; ++i) {
                if (
                    b.disputes[i].record.terms.disputeAction == 3
                        && b.disputes[i].record.disputeRecordHash == o.record.recordHash
                ) counter = b.disputes[i].record.recordHash;
            }
            for (uint256 i; i < b.resolutions.length; ++i) {
                if (b.resolutions[i].record.terms.disputeRecordHash == o.record.recordHash) {
                    resolved = true;
                    open = false;
                    if (
                        h.revocationReason != 3
                            && h.revocationReason
                                != (b.resolutions[i].record.terms.resolution == 2 ? 4 : 0)
                    ) _invalid();
                    if (
                        b.resolutions[i].record.terms.resolution == 1
                            && h.restoreState != b.resolutions[i].record.restoredState
                    ) _invalid();
                }
            }
            if (
                h.disputeRecordHash != o.record.recordHash
                    || h.counterStatementRecordHash != counter || h.resolutionActionId != resolution
                    || h.open != open || h.reopened != _reopened(b, o, p) || h.restoreState < 1
                    || h.restoreState > (sanctioned ? 3 : 2)
                    || (o.withdrawal.recordHash != 0
                        && (h.restoreState != o.withdrawal.restoredState
                            || (h.revocationReason != 0 && h.revocationReason != 3)))
                    || (open && h.revocationReason != (h.reopened ? 4 : 0))
                    || (!open && !resolved && o.withdrawal.recordHash == 0)
            ) _invalid();
        }
        if (h.revocationReason == 3) {
            bool executed;
            for (uint256 i; i < b.repudiations.length; ++i) {
                if (
                    b.repudiations[i].record.terms.bindingGeneration == generation
                        && b.repudiations[i].terminal.phase == 4
                ) executed = true;
            }
            if (!executed || h.open) _invalid();
        }
        if (checkCurrent && generation == b.current.generation) {
            if (
                (b.current.state == 4) != h.open
                    || (b.current.state == 5 && h.revocationReason != 3 && h.revocationReason != 4)
                    || ((b.current.state == 2 || (sanctioned && b.current.state == 3))
                        && h.revocationReason != 0)
            ) _invalid();
        }
    }

    function _opening(D.Bundle memory b, bytes32 key) private pure returns (uint256) {
        for (uint256 i; i < b.disputes.length; ++i) {
            if (
                b.disputes[i].record.recordHash == key
                    && b.disputes[i].record.terms.disputeAction == 1
            ) return i;
        }
        _invalid();
    }

    function _counterBefore(
        D.Bundle memory b,
        bytes32 opening,
        RH.Point memory point,
        RH.OwnerProvenance memory p
    ) private pure returns (bytes32 key) {
        for (uint256 i; i < b.disputes.length; ++i) {
            D.DisputeRow memory r = b.disputes[i];
            if (
                r.record.terms.disputeAction == 3 && r.record.disputeRecordHash == opening
                    && Clock.beforeOwner(p, 4, r.point, point)
            ) key = r.record.recordHash;
        }
    }

    function _reopened(D.Bundle memory b, D.DisputeRow memory opening, RH.OwnerProvenance memory p)
        private
        pure
        returns (bool)
    {
        uint8 last;
        for (uint256 i; i < b.resolutions.length; ++i) {
            D.ResolutionRow memory r = b.resolutions[i];
            if (
                r.record.terms.bindingGeneration == opening.record.terms.bindingGeneration
                    && Clock.beforeOwner(p, 4, r.point, opening.point)
            ) last = r.record.terms.resolution;
        }
        return last == 2;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
