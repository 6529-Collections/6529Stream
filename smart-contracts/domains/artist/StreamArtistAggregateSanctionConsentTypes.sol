// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistSanctionTypes as S
} from "../../interfaces/stream/artist/StreamArtistSanctionTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";

/// @notice Small original Consent facts after the fixed worker authenticates the global Archive inventory.
/// @dev These are validation inputs, not another transport schema or an alternate provenance certificate.
library StreamArtistAggregateSanctionConsentTypes {
    struct Record {
        RH.Point point;
        S.Record record;
    }

    struct Facts {
        Record[] sanctions;
        H.ConfirmationRow[] confirmations;
    }
}
