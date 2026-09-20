// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationPrepared as Prepared
} from "./StreamArtistRecoveredHydrationPrepared.sol";
import {
    StreamArtistRecoveredHydrationCommit as Commit
} from "./StreamArtistRecoveredHydrationCommit.sol";

/// @notice Additive operation60 profile selected only by the original guarded Coordinator.
library StreamArtistRecoveredHydrationOperations {
    function hydrate(D.CoordinatorContext memory x, address actor, RH.Request memory request)
        public
        returns (bytes32)
    {
        Commit.Prepared memory prepared = Prepared.collect(x.suite, request);
        return Commit.execute(x.suite, x.configurationHash, actor, request, prepared);
    }
}
