// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamArtistAuthorityHydration.sol";
import "./IStreamArtistIdentityRevision.sol";
import "./StreamArtistDelegationTypes.sol";
import "./StreamArtistSaleTypes.sol";

library StreamArtistDelegationHydrationTypes {
    bytes32 internal constant PROFILE =
        keccak256("6529STREAM_ARTIST_LIVING_DELEGATION_HYDRATION_V1");
    bytes32 internal constant IDENTITY =
        keccak256("6529STREAM_ARTIST_LIVING_DELEGATION_IDENTITY_V1");
    bytes32 internal constant BINDING = keccak256("6529STREAM_ARTIST_LIVING_DELEGATION_BINDING_V1");
    bytes32 internal constant CONSENT = keccak256("6529STREAM_ARTIST_LIVING_DELEGATION_CONSENT_V1");

    struct Revision {
        StreamArtistIdentityRevisionTypes.Record item;
        bytes document;
    }

    struct Grant {
        bytes32 recordHash;
        StreamArtistDelegationTypes.Record item;
        uint64 epoch;
        bytes32 current;
    }

    struct NonceLane {
        bytes32 key;
        uint256 hint;
        StreamArtistAuthorityHydrationTypes.NonceWord[] words;
    }

    struct Identity {
        bytes baseline;
        uint64 epoch;
        Revision[] revisions;
        Grant[] grants;
        NonceLane[] delegateNonces;
    }

    struct Policy {
        bytes32 recordHash;
        bytes32 grant;
    }

    struct Sale {
        StreamArtistSaleTypes.Record item;
        bytes32 grant;
        bytes32 current;
    }

    struct Consent {
        Policy[] policies;
        Sale[] sales;
    }
}

/// @notice Distinct complete original-living op60 profile; original selectors remain strict.
interface IStreamArtistDelegationAuthorityHydration is IERC165 {
    function hydrateArtistAuthorityWithDelegations(
        StreamArtistAuthorityHydrationTypes.Request calldata request
    ) external returns (bytes32);
}

interface IStreamArtistDelegationHydrationCoordinator {
    function coordinateHydrateArtistAuthorityWithDelegations(
        address actor,
        StreamArtistAuthorityHydrationTypes.Request calldata request
    ) external returns (bytes32);
}

/// @notice Fixed owner export. Identity derives all record selectors from its actual native journal.
interface IStreamArtistDelegationHydrationOwner {
    function authorityDelegationHydrationState(
        StreamArtistAuthorityHydrationTypes.Query calldata query
    ) external view returns (bytes memory);
}
