// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistRecoveredHydrationCoordinator
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    IStreamArtistRecoveredConsentHydrationCoordinator
} from "../../interfaces/stream/artist/IStreamArtistRecoveredConsentHydration.sol";

/// @notice Fixed typed encoders for the facade's two recovered-authority writers.
/// @dev The original extension checks its immutable host first. Both methods decode their
/// complete original arguments and select one fixed Coordinator method.
library StreamArtistRegistryRecoveredWriter {
    function hydrate(address coordinator, address actor, bytes calldata arguments)
        public
        returns (bytes32)
    {
        RH.Request memory request = abi.decode(arguments, (RH.Request));
        return IStreamArtistRecoveredHydrationCoordinator(coordinator)
            .coordinateHydrateRecoveredArtistAuthority(actor, request);
    }

    function hydrateWithConsents(address coordinator, address actor, bytes calldata arguments)
        public
        returns (bytes32)
    {
        (RH.Request memory request, T.RoyaltyFreeze[] memory royaltyFreezes) =
            abi.decode(arguments, (RH.Request, T.RoyaltyFreeze[]));
        return IStreamArtistRecoveredConsentHydrationCoordinator(coordinator)
            .coordinateHydrateRecoveredArtistAuthorityWithConsents(actor, request, royaltyFreezes);
    }
}
