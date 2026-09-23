// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistSanctionOperations } from "./StreamArtistSanctionOperations.sol";
import { StreamArtistSanctionCandidate } from "./StreamArtistSanctionCandidate.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistSanctionRequestTypes as Q
} from "../../interfaces/stream/artist/StreamArtistSanctionRequestTypes.sol";

/// @notice Fixed typed forwarding of the original sanction recipe after host admission and pin reads.
library StreamArtistCoordinatorSanctionRecord {
    function record(
        T.SuiteConfiguration storage suite,
        address reads,
        bytes32 configurationHash,
        StreamArtistSanctionCandidate.Pins memory pins,
        address actor,
        Q.Request memory p,
        T.Authorization memory a
    ) public returns (bytes32) {
        return StreamArtistSanctionOperations.record(
            D.CoordinatorContext(suite, reads, configurationHash), pins, actor, p, a
        );
    }
}
