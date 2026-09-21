// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredSanctionStage as Sanctions
} from "./StreamArtistRecoveredSanctionStage.sol";
import {
    StreamArtistRecoveredDisputeSelection as Disputes
} from "./StreamArtistRecoveredDisputeSelection.sol";

/// @notice Closed read-only history selection; original sanction precedence is retained.
library StreamArtistRecoveredHistoryContentSelection {
    /// @return route 0 earlier generation profiles; 1 dispute; 2 sanction; 3 content history.
    /// @return sanctioned Exact original sanction predicate, reused without another full read.
    function select(T.SuiteConfiguration memory source, AH.Query memory q, RH.Provenance memory p)
        public
        view
        returns (uint8 route, bool sanctioned)
    {
        bool content;
        for (uint256 i; i < p.journals[6].length; ++i) {
            uint16 op = p.journals[6][i].receipt.operation;
            if (op == 17 || op == 20 || op == 21 || op == 52) content = true;
        }
        sanctioned = Sanctions.selected(p);
        if (sanctioned) return (content ? 3 : 2, true);
        if (content && p.journals[3].length > 1) return (3, false);
        if (Disputes.selected(source, q, p)) return (content ? 3 : 1, false);
        return (0, false);
    }
}
