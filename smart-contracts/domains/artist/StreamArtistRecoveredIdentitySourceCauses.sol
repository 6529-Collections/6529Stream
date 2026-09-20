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
library StreamArtistRecoveredIdentitySourceCauses {
    function validate(IH.Bundle calldata b, RH.OwnerProvenance calldata p) public pure {
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
            IH.CauseRow calldata r = b.causes[i];
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
}
