// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice Exact disjoint original owner4 mutation clocks after complete authenticated timelines.
library StreamArtistRecoveredPlatformOrdering {
    function distinct(
        D.Bundle memory b,
        RH.Point[] memory confirmations,
        D.Guard[] memory native_,
        RH.Point[] memory proposals,
        RH.Point[] memory completions
    ) public pure {
        RH.Point[] memory clocks = new RH
            .Point[](
            confirmations.length + native_.length + proposals.length + completions.length
                + b.disputes.length + b.resolutions.length + 2 * b.repudiations.length
        );
        uint256 n;
        for (uint256 i; i < confirmations.length; ++i) {
            clocks[n++] = confirmations[i];
        }
        for (uint256 i; i < native_.length; ++i) {
            clocks[n++] = native_[i].point;
        }
        for (uint256 i; i < proposals.length; ++i) {
            clocks[n++] = proposals[i];
            if (completions[i].ownerRevision != 0) clocks[n++] = completions[i];
        }
        for (uint256 i; i < b.disputes.length; ++i) {
            clocks[n++] = b.disputes[i].point;
        }
        for (uint256 i; i < b.resolutions.length; ++i) {
            clocks[n++] = b.resolutions[i].point;
        }
        for (uint256 i; i < b.repudiations.length; ++i) {
            clocks[n++] = b.repudiations[i].point;
            if (b.repudiations[i].terminal.phase >= 2 && b.repudiations[i].terminal.phase <= 4) {
                clocks[n++] = b.repudiations[i].terminalPoint;
            }
        }
        for (uint256 i; i < n; ++i) {
            if (clocks[i].ownerRevision == 0 || clocks[i].ownerIndex != 4) _invalid();
            for (uint256 j; j < i; ++j) {
                if (D.samePoint(clocks[i], clocks[j])) _invalid();
            }
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
