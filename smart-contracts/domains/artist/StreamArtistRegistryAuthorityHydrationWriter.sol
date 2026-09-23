// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistEntropyFindingHydrationTypes as Entropy,
    IStreamArtistEntropyFindingHydrationCoordinator
} from "../../interfaces/stream/artist/IStreamArtistEntropyFindingHydration.sol";

import {
    StreamArtistReadinessHydrationTypes as Readiness,
    IStreamArtistReadinessAuthorityHydrationCoordinator
} from "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    IStreamArtistPublicationAuthorityHydrationCoordinator
} from "../../interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";

import {
    StreamArtistAuthorityHydrationTypes as Authority,
    IStreamArtistAuthorityHydrationCoordinator
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistEconomicsHydrationTypes as Economics,
    IStreamArtistEconomicsAuthorityHydrationCoordinator
} from "../../interfaces/stream/artist/IStreamArtistEconomicsAuthorityHydration.sol";
import {
    IStreamArtistDelegationHydrationCoordinator
} from "../../interfaces/stream/artist/IStreamArtistDelegationAuthorityHydration.sol";
import {
    IStreamArtistPayoutAuthorityHydrationCoordinator
} from "../../interfaces/stream/artist/IStreamArtistPayoutAuthorityHydration.sol";

/// @notice Fixed typed encodings for the facade's original authority-hydration writers.
/// @dev The original extension checks its immutable host before entering this worker.
/// Delegated execution preserves the facade as the Coordinator caller.
library StreamArtistRegistryAuthorityHydrationWriter {
    function authority(address coordinator, address actor, bytes calldata arguments)
        public
        returns (bytes32)
    {
        Authority.Request memory request = abi.decode(arguments, (Authority.Request));
        return IStreamArtistAuthorityHydrationCoordinator(coordinator)
            .coordinateHydrateArtistAuthority(actor, request);
    }

    function delegations(address coordinator, address actor, bytes calldata arguments)
        public
        returns (bytes32)
    {
        Authority.Request memory request = abi.decode(arguments, (Authority.Request));
        return IStreamArtistDelegationHydrationCoordinator(coordinator)
            .coordinateHydrateArtistAuthorityWithDelegations(actor, request);
    }

    function payout(address coordinator, address actor, bytes calldata arguments)
        public
        returns (bytes32)
    {
        Authority.Request memory request = abi.decode(arguments, (Authority.Request));
        return IStreamArtistPayoutAuthorityHydrationCoordinator(coordinator)
            .coordinateHydrateArtistAuthorityWithPayout(actor, request);
    }

    function economics(address coordinator, address actor, bytes calldata arguments)
        public
        returns (bytes32)
    {
        Economics.Request memory request = abi.decode(arguments, (Economics.Request));
        return IStreamArtistEconomicsAuthorityHydrationCoordinator(coordinator)
            .coordinateHydrateArtistAuthorityWithEconomics(actor, request);
    }

    function readiness(address coordinator, address actor, bytes calldata arguments)
        public
        returns (bytes32)
    {
        Readiness.Request memory request = abi.decode(arguments, (Readiness.Request));
        return IStreamArtistReadinessAuthorityHydrationCoordinator(coordinator)
            .coordinateHydrateArtistAuthorityWithReadiness(actor, request);
    }

    function publications(address coordinator, address actor, bytes calldata arguments)
        public
        returns (bytes32)
    {
        Readiness.Request memory request = abi.decode(arguments, (Readiness.Request));
        return IStreamArtistPublicationAuthorityHydrationCoordinator(coordinator)
            .coordinateHydrateArtistAuthorityWithPublications(actor, request);
    }

    function hydrate(address coordinator, address actor, bytes calldata arguments)
        public
        returns (bytes32)
    {
        Entropy.Request memory request = abi.decode(arguments, (Entropy.Request));
        return IStreamArtistEntropyFindingHydrationCoordinator(coordinator)
            .coordinateHydrateArtistAuthorityWithEntropyFindings(actor, request);
    }
}
