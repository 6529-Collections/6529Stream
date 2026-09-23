// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamArtistReadinessAuthorityHydration.sol";
import "./IStreamArtistRecordPublicationOwner.sol";

library StreamArtistPublicationHydrationTypes {
    struct Row {
        StreamArtistReadinessHydrationTypes.AttestationRow attestation;
        IStreamArtistRecordPublicationOwner.Record publication;
    }

    struct Bundle {
        bytes32 schema;
        address sourceRegistry;
        uint8 state;
        uint64 generation;
        Row[] records;
    }
}

/// @notice Complete direct living readiness plus the original detached publication evidence.
interface IStreamArtistPublicationAuthorityHydration is IERC165 {
    function hydrateArtistAuthorityWithPublications(
        StreamArtistReadinessHydrationTypes.Request calldata request
    ) external returns (bytes32);
}

interface IStreamArtistPublicationAuthorityHydrationCoordinator {
    function coordinateHydrateArtistAuthorityWithPublications(
        address actor,
        StreamArtistReadinessHydrationTypes.Request calldata request
    ) external returns (bytes32);
}

interface IStreamArtistPublicationHydrationOwner {
    function authorityPublicationHydrationState(
        StreamArtistAuthorityHydrationTypes.Query calldata q,
        StreamArtistReadinessHydrationTypes.AttestationInput[] calldata inputs
    ) external view returns (bytes memory);
}
