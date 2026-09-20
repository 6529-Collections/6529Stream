// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistRecoveredHydrationCoordinator
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    IStreamArtistRecoveredConsentHydrationCoordinator
} from "../../interfaces/stream/artist/IStreamArtistRecoveredConsentHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as Recovered
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationOperations
} from "./StreamArtistRecoveredHydrationOperations.sol";
import "../../interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";
import "./StreamArtistMultipleRecordsOperations.sol";
import "./StreamArtistMultipleHydrationOperations.sol";
import "./StreamArtistDelegationHydrationOperations.sol";
import "./StreamArtistAuthorityHydrationOperations.sol";
import "./StreamArtistEntropyFindingHydrationOperations.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutAuthorityHydration.sol";
import "../../interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";

/// @notice Fixed original operation60 transport decoder; explicit host routes retain their operation lock.
library StreamArtistCoordinatorHydration {
    function executeSelected(D.CoordinatorContext memory x, bytes calldata data)
        public
        returns (bytes32)
    {
        bytes4 selector = bytes4(data[:4]);
        uint8 profile;
        if (
            selector
                == IStreamArtistAuthorityHydrationCoordinator.coordinateHydrateArtistAuthority
                .selector
        ) {
            profile = 1;
        } else if (
            selector
                == IStreamArtistPayoutAuthorityHydrationCoordinator.coordinateHydrateArtistAuthorityWithPayout
                    .selector
        ) {
            profile = 2;
        } else if (
            selector
                == IStreamArtistEconomicsAuthorityHydrationCoordinator.coordinateHydrateArtistAuthorityWithEconomics
                    .selector
        ) {
            profile = 3;
        } else if (
            selector
                == IStreamArtistReadinessAuthorityHydrationCoordinator.coordinateHydrateArtistAuthorityWithReadiness
                    .selector
        ) {
            profile = 4;
        } else if (
            selector
                == IStreamArtistPublicationAuthorityHydrationCoordinator.coordinateHydrateArtistAuthorityWithPublications
                    .selector
        ) {
            profile = 5;
        } else if (
            selector
                == IStreamArtistEntropyFindingHydrationCoordinator.coordinateHydrateArtistAuthorityWithEntropyFindings
                    .selector
        ) {
            profile = 6;
        } else if (
            selector
                == IStreamArtistMultipleHydrationCoordinator.coordinateHydrateMultipleArtistAuthority
                .selector
        ) {
            profile = 7;
        } else if (
            selector
                == IStreamArtistDelegationHydrationCoordinator.coordinateHydrateArtistAuthorityWithDelegations
                    .selector
        ) {
            profile = 8;
        } else if (
            selector
                == IStreamArtistMultipleRecordsHydrationCoordinator.coordinateHydrateMultipleArtistAuthorityWithRecords
                    .selector
        ) {
            profile = 9;
        } else if (
            selector
                    == IStreamArtistRecoveredHydrationCoordinator.coordinateHydrateRecoveredArtistAuthority
                        .selector
                || selector
                    == IStreamArtistRecoveredConsentHydrationCoordinator.coordinateHydrateRecoveredArtistAuthorityWithConsents
                        .selector
        ) {
            profile = 10;
        } else {
            revert T.UnsupportedProfile();
        }
        return execute(x, data, profile);
    }

    function execute(D.CoordinatorContext memory x, bytes calldata data, uint8 profile)
        public
        returns (bytes32)
    {
        if (profile == 10) {
            if (
                bytes4(data[:4])
                    == IStreamArtistRecoveredConsentHydrationCoordinator.coordinateHydrateRecoveredArtistAuthorityWithConsents
                        .selector
            ) {
                (
                    address actor,
                    Recovered.Request memory p,
                    T.RoyaltyFreeze[] memory royaltyFreezes
                ) = abi.decode(data[4:], (address, Recovered.Request, T.RoyaltyFreeze[]));
                return StreamArtistRecoveredHydrationOperations.hydrate(x, actor, p, royaltyFreezes);
            }
            (address actor, Recovered.Request memory p) =
                abi.decode(data[4:], (address, Recovered.Request));
            return StreamArtistRecoveredHydrationOperations.hydrate(x, actor, p);
        }
        if (profile == 9) {
            (address actor, MR.Request memory p) = abi.decode(data[4:], (address, MR.Request));
            return StreamArtistMultipleRecordsOperations.hydrate(x, actor, p);
        }
        if (profile == 1 || profile == 2) {
            (address actor, AH.Request memory p) = abi.decode(data[4:], (address, AH.Request));
            return profile == 1
                ? StreamArtistAuthorityHydrationOperations.hydrate(x, actor, p)
                : StreamArtistAuthorityHydrationOperations.hydrateWithPayout(x, actor, p);
        }
        if (profile == 3) {
            (address actor, EH.Request memory p) = abi.decode(data[4:], (address, EH.Request));
            return StreamArtistAuthorityHydrationOperations.hydrateWithEconomics(x, actor, p);
        }
        if (profile == 4) {
            (address actor, RH.Request memory p) = abi.decode(data[4:], (address, RH.Request));
            return StreamArtistAuthorityHydrationOperations.hydrateWithReadiness(x, actor, p);
        }
        if (profile == 5) {
            (address actor, RH.Request memory p) = abi.decode(data[4:], (address, RH.Request));
            return StreamArtistAuthorityHydrationOperations.hydrateWithPublications(x, actor, p);
        }
        if (profile == 6) {
            (address actor, FH.Request memory p) = abi.decode(data[4:], (address, FH.Request));
            return StreamArtistEntropyFindingHydrationOperations.hydrate(x, actor, p);
        }
        if (profile == 7) {
            (address actor, MH.Request memory p) = abi.decode(data[4:], (address, MH.Request));
            return StreamArtistMultipleHydrationOperations.hydrate(x, actor, p);
        }
        if (profile == 8) {
            (address actor, AH.Request memory p) = abi.decode(data[4:], (address, AH.Request));
            return StreamArtistDelegationHydrationOperations.hydrate(x, actor, p);
        }
        revert T.UnsupportedProfile();
    }
}
