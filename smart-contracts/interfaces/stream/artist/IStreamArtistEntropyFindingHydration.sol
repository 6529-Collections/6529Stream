// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamArtistReadinessAuthorityHydration.sol";
import "./IStreamArtistEntropyUnavailability.sol";
import { StreamArtistRecoveryTypes } from "./StreamArtistRecoveryTypes.sol";

library StreamArtistEntropyFindingHydrationTypes {
    bytes32 internal constant PROFILE = keccak256("6529STREAM_ARTIST_ENTROPY_FINDING_HYDRATION_V1");

    struct Request {
        StreamArtistAuthorityHydrationTypes.Request authority;
        bool includePayout;
        bool publications;
        StreamArtistOnboardingTypes.EconomicsConsent[] economics;
        StreamArtistReadinessHydrationTypes.AttestationInput[] attestations;
    }

    struct Row {
        StreamArtistRecoveryTypes.FindingRecord record;
        StreamArtistEntropyUnavailabilityTypes.Admission admission;
    }

    struct Bundle {
        address sourceRegistry;
        bytes identityState;
        Row[] records;
        bytes32 latest;
        uint256 activityEpoch;
        bool hasUncancelledFindings;
    }
}

/// @notice Complete living source profile with original entropy finding admissions and activity.
interface IStreamArtistEntropyFindingHydration is IERC165 {
    function hydrateArtistAuthorityWithEntropyFindings(
        StreamArtistEntropyFindingHydrationTypes.Request calldata request
    ) external returns (bytes32);
}

interface IStreamArtistEntropyFindingHydrationCoordinator {
    function coordinateHydrateArtistAuthorityWithEntropyFindings(
        address actor,
        StreamArtistEntropyFindingHydrationTypes.Request calldata request
    ) external returns (bytes32);
}

interface IStreamArtistEntropyFindingHydrationOwner {
    function authorityEntropyFindingHydrationState(
        StreamArtistAuthorityHydrationTypes.Query calldata q
    ) external view returns (bytes memory);
    /// @notice Original immutable record domain; zero for an unknown or non-entropy finding.
    function entropyUnavailabilityFindingOrigin(bytes32 recordHash) external view returns (address);
}
