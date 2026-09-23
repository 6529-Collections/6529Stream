// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamArtistMultipleAuthorityHydration.sol";
import "./IStreamArtistReadinessAuthorityHydration.sol";
import "./IStreamArtistPayoutAuthorityHydration.sol";
import "./IStreamArtistPublicationAuthorityHydration.sol";
import "./IStreamArtistDelegationAuthorityHydration.sol";

/// @notice Complete original living records. Witnesses are ordered by the complete source journals.
library StreamArtistMultipleRecordsTypes {
    bytes32 internal constant PROFILE = keccak256("6529STREAM_ARTIST_MULTIPLE_LIVING_RECORDS_V1");
    bytes32 internal constant PAYOUT = keccak256("6529STREAM_ARTIST_MULTIPLE_RECORDS_PAYOUT_V1");
    bytes32 internal constant CONSENT = keccak256("6529STREAM_ARTIST_MULTIPLE_RECORDS_CONSENT_V1");
    bytes32 internal constant ATTRIBUTION =
        keccak256("6529STREAM_ARTIST_MULTIPLE_RECORDS_ATTRIBUTION_V1");

    struct CollectionWitness {
        uint256 collectionId;
        StreamArtistOnboardingTypes.EconomicsConsent[] economics;
        StreamArtistReadinessHydrationTypes.AttestationInput[] attestations;
    }

    struct Request {
        StreamArtistMultipleHydrationTypes.Request authority;
        CollectionWitness[] witnesses;
    }

    struct PayoutRow {
        bytes32 artistId;
        StreamArtistPayoutHydrationTypes.Bundle state;
    }

    struct ConsentRow {
        StreamArtistAuthorityHydrationTypes.Query query;
        StreamArtistDelegationHydrationTypes.Consent delegation;
        StreamArtistEconomicsHydrationTypes.Row[] economics;
        StreamArtistOnboardingTypes.RatificationRecord[] ratifications;
        IStreamArtistContentRecordsOwner.ConsentRecord[] content;
    }

    // Records remain in GLOBAL original Attribution-owner receipt order. This also preserves
    // a credential chain shared by one artist across several collections.
    struct Attribution {
        address sourceRegistry;
        StreamArtistAuthorityHydrationTypes.Query[] collections;
        StreamArtistPublicationHydrationTypes.Row[] records;
    }
}

interface IStreamArtistMultipleRecordsHydration is IERC165 {
    function hydrateMultipleArtistAuthorityWithRecords(
        StreamArtistMultipleRecordsTypes.Request calldata request
    ) external returns (bytes32);
}

interface IStreamArtistMultipleRecordsHydrationCoordinator {
    function coordinateHydrateMultipleArtistAuthorityWithRecords(
        address actor,
        StreamArtistMultipleRecordsTypes.Request calldata request
    ) external returns (bytes32);
}
