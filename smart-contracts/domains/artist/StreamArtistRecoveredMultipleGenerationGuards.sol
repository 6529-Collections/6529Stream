// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";

/// @notice One original semantic replay key and every retained era alias, at its unchanged admission point.
library StreamArtistRecoveredMultipleGenerationGuards {
    function mark(
        RH.OwnerProvenance memory p,
        bool[] memory used,
        bytes32 surface,
        bytes32 scope,
        bytes32 commitment,
        RH.Point memory point
    ) internal pure {
        uint256 start = A.era(p, point.environmentHash);
        for (uint256 e = start; e < p.eras.length; ++e) {
            uint256 count;
            for (uint256 i; i < p.aliases.length; ++i) {
                RH.ReplayAlias memory a = p.aliases[i];
                if (
                    a.originHash != p.eras[e].originHash || a.surface != surface || a.scope != scope
                ) continue;
                if (
                    used[i] || a.cell.kind != 1 || a.cell.status != 2
                        || a.cell.commitment != commitment
                        || keccak256(abi.encode(a.admittedAt)) != keccak256(abi.encode(point))
                ) _invalid();
                used[i] = true;
                ++count;
            }
            if (count != 1) _invalid();
        }
    }

    function resolved(
        RH.OwnerProvenance memory p,
        bytes32 surface,
        bytes32 scope,
        bytes32 commitment
    ) internal pure returns (RH.Point memory point) {
        bool found;
        for (uint256 i; i < p.aliases.length; ++i) {
            RH.ReplayAlias memory a = p.aliases[i];
            if (a.surface != surface || a.scope != scope || a.cell.commitment != commitment) {
                continue;
            }
            if (found && keccak256(abi.encode(point)) != keccak256(abi.encode(a.admittedAt))) {
                _invalid();
            }
            point = RH.Point(
                a.admittedAt.environmentHash, a.admittedAt.ownerIndex, a.admittedAt.ownerRevision
            );
            found = true;
        }
        if (!found) _invalid();
        Clock.validateOwnerPoint(p, point.ownerIndex, point);
    }

    function complete(bool[] memory used) internal pure {
        for (uint256 i; i < used.length; ++i) {
            if (!used[i]) _invalid();
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
