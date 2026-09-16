// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice In-memory complete operation60 preparation; no new storage or authority flag.
library StreamArtistHydrationPrepared {
    struct Bundle {
        bytes32 profile;
        address prior;
        address sourceCoordinator;
        T.SuiteConfiguration source;
        AH.Query q;
        AH.OwnerData[7] data;
        T.Snapshot[7] before_;
    }
}
