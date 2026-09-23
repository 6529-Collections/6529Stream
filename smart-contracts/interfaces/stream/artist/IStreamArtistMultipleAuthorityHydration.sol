// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamArtistAuthorityHydration.sol";

/// @notice Complete original living identities and generation-one collections; distinct op60 profile.
library StreamArtistMultipleHydrationTypes {
    bytes32 internal constant PROFILE = keccak256("6529STREAM_ARTIST_MULTIPLE_LIVING_HYDRATION_V1");
    bytes32 internal constant SCHEMA = keccak256("6529STREAM_ARTIST_MULTIPLE_LIVING_STATE_V1");

    struct Collection {
        bytes32 artistId;
        uint256 collectionId;
        StreamArtistAuthorityHydrationTypes.PolicyKey[] policies;
    }

    struct Request {
        uint256 bindingIndex;
        bytes32[] artistIds;
        Collection[] collections;
        IStreamArtistAuthorityCheckpoint.Checkpoint[7] expectedSource;
        StreamArtistAuthorityHydrationTypes.Origin[][7] replayOrigins;
    }

    struct Row {
        StreamArtistAuthorityHydrationTypes.Query query;
        bytes state;
        StreamArtistAuthorityHydrationTypes.NonceWord[] nonces;
    }

    struct Bundle {
        Row[] rows;
        bytes32[] artistIds;
        uint256[] collectionIds;
        uint256 registrationCount;
    }
}

interface IStreamArtistMultipleAuthorityHydration is IERC165 {
    function hydrateMultipleArtistAuthority(
        StreamArtistMultipleHydrationTypes.Request calldata request
    ) external returns (bytes32);
}

interface IStreamArtistMultipleHydrationCoordinator {
    function coordinateHydrateMultipleArtistAuthority(
        address actor,
        StreamArtistMultipleHydrationTypes.Request calldata request
    ) external returns (bytes32);
}

interface IStreamArtistMultipleHydrationIdentity {
    function authorityLivingIdentityHydrationState(
        StreamArtistAuthorityHydrationTypes.Query calldata query
    ) external view returns (bytes memory);
}
