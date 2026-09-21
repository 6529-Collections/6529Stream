// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredDisputeHistorySource as Source
} from "./StreamArtistRecoveredDisputeHistorySource.sol";

/// @notice Original collection entries, sharing one fixed read body without constant specialization.
library StreamArtistRecoveredDisputeHistoryCollection {
    // Retain the published facade error ABI after moving its original read body.
    error InvalidRecoveredHydrationProfile();

    function collect(
        address source,
        AH.Query memory q,
        RH.Provenance memory p,
        CB.Bundle memory bindings
    ) public view returns (D.Bundle memory b) {
        return Source.collect(source, q, p, bindings, false);
    }

    /// @notice Typed source facts for the new profile; its complete Archive/state proof is mandatory.
    /// @dev This read never imports. The caller must validate returned facts before any owner write.
    function collectForSanctionHistory(
        address source,
        AH.Query memory q,
        RH.Provenance memory p,
        CB.Bundle memory bindings
    ) public view returns (D.Bundle memory b) {
        return Source.collect(source, q, p, bindings, true);
    }
}
