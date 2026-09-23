// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice One normalized chronology for original local clocks across authenticated import eras.
/// @dev Callers first authenticate complete provenance and the actual producer evidence for each
/// point. Membership in a revision interval alone does not prove a record or auxiliary mutation.
/// Raw revisions from different semantic owners are never ordered by this helper.
library StreamArtistRecoveredHydrationChronology {
    function validatePoint(RH.Provenance memory p, RH.Point memory point) public pure {
        if (point.ownerIndex >= 7) _invalid(point);
        _rank(RH.ownerProvenance(p, point.ownerIndex), point.ownerIndex, point);
    }

    function before(RH.Provenance memory p, RH.Point memory a, RH.Point memory b)
        public
        pure
        returns (bool)
    {
        return compare(p, a, b) < 0;
    }

    function compare(RH.Provenance memory p, RH.Point memory a, RH.Point memory b)
        public
        pure
        returns (int8)
    {
        if (a.ownerIndex != b.ownerIndex) revert RH.InvalidRecoveredHydrationProvenance();
        if (a.ownerIndex >= 7) _invalid(a);
        return compareOwner(RH.ownerProvenance(p, a.ownerIndex), a.ownerIndex, a, b);
    }

    function validateOwnerPoint(
        RH.OwnerProvenance memory p,
        uint8 ownerIndex,
        RH.Point memory point
    ) public pure {
        _rank(p, ownerIndex, point);
    }

    function beforeOwner(
        RH.OwnerProvenance memory p,
        uint8 ownerIndex,
        RH.Point memory a,
        RH.Point memory b
    ) public pure returns (bool) {
        return compareOwner(p, ownerIndex, a, b) < 0;
    }

    function compareOwner(
        RH.OwnerProvenance memory p,
        uint8 ownerIndex,
        RH.Point memory a,
        RH.Point memory b
    ) public pure returns (int8) {
        uint256 first = _rank(p, ownerIndex, a);
        uint256 second = _rank(p, ownerIndex, b);
        if (first < second) return -1;
        if (first > second) return 1;
        if (a.ownerRevision < b.ownerRevision) return -1;
        if (a.ownerRevision > b.ownerRevision) return 1;
        return 0;
    }

    function _rank(RH.OwnerProvenance memory p, uint8 ownerIndex, RH.Point memory point)
        private
        pure
        returns (uint256 rank)
    {
        if (
            point.environmentHash == 0 || ownerIndex >= 7 || point.ownerIndex != ownerIndex
                || point.ownerRevision == 0 || p.origins.length == 0
                // A destination may operate after importing the maximum transport prefix.
                // Its current local era adds one clock entry; it is not an import certificate.
                || p.origins.length != p.eras.length || p.eras.length > RH.MAX_ERAS + 1
        ) _invalid(point);
        bool found;
        for (uint256 i; i < p.eras.length; ++i) {
            if (p.eras[i].originHash != point.environmentHash) continue;
            if (
                found || RH.originHash(p.origins[i]) != point.environmentHash
                    || p.origins[i].owners[point.ownerIndex] == address(0)
                    || p.origins[i].ownerCodeHashes[point.ownerIndex] == 0
                    || p.eras[i].checkpoint.schema != RH.CHECKPOINT
                    || p.eras[i].checkpoint.ownerState.domainId != RH.ownerDomain(point.ownerIndex)
                    || point.ownerRevision > p.eras[i].checkpoint.ownerState.revision
            ) _invalid(point);
            found = true;
            rank = i;
        }
        if (!found) _invalid(point);
    }

    function _invalid(RH.Point memory point) private pure {
        revert RH.InvalidRecoveredHydrationPoint(
            point.environmentHash, point.ownerIndex, point.ownerRevision
        );
    }
}
