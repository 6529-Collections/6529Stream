// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamArtistAuthorityHydration.sol";
import "./IStreamArtistEconomicsEvidence.sol";

library StreamArtistEconomicsHydrationTypes {
    struct Request {
        StreamArtistAuthorityHydrationTypes.Request authority;
        StreamArtistOnboardingTypes.EconomicsConsent[] economics;
    }

    struct Row {
        bytes32 recordHash;
        StreamArtistOnboardingTypes.EconomicsConsent terms;
        IStreamArtistEconomicsEvidence.Association association;
    }

    struct Bundle {
        bytes32 schema;
        bytes32[] policies;
        Row[] records;
    }
}

/// @notice Complete original direct economics history, with its living payout dependencies.
interface IStreamArtistEconomicsAuthorityHydration is IERC165 {
    function hydrateArtistAuthorityWithEconomics(
        StreamArtistEconomicsHydrationTypes.Request calldata request
    ) external returns (bytes32);
}

interface IStreamArtistEconomicsAuthorityHydrationCoordinator {
    function coordinateHydrateArtistAuthorityWithEconomics(
        address actor,
        StreamArtistEconomicsHydrationTypes.Request calldata request
    ) external returns (bytes32);
}

interface IStreamArtistEconomicsAuthorityHydrationOwner {
    function authorityEconomicsHydrationState(
        StreamArtistAuthorityHydrationTypes.Query calldata query,
        StreamArtistOnboardingTypes.EconomicsConsent[] calldata economics
    ) external view returns (bytes memory);
}
