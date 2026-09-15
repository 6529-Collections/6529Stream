// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamArtistAuthorityHydration.sol";

library StreamArtistPayoutHydrationTypes {
    struct Row {
        bytes32 recordHash;
        StreamArtistOnboardingTypes.PayoutDesignation terms;
    }

    struct Bundle {
        StreamArtistOnboardingTypes.Payout current;
        Row[] records;
    }
}

/// @notice Explicit operation60 profile with complete original unprovisional living payout history.
interface IStreamArtistPayoutAuthorityHydration is IERC165 {
    function hydrateArtistAuthorityWithPayout(
        StreamArtistAuthorityHydrationTypes.Request calldata request
    ) external returns (bytes32);
}

interface IStreamArtistPayoutAuthorityHydrationCoordinator {
    function coordinateHydrateArtistAuthorityWithPayout(
        address actor,
        StreamArtistAuthorityHydrationTypes.Request calldata request
    ) external returns (bytes32);
}
