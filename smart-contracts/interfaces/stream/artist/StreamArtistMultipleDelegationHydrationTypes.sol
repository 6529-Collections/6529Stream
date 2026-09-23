// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamArtistMultipleAuthorityHydration.sol";
import "./IStreamArtistDelegationAuthorityHydration.sol";
import "./IStreamArtistHistory.sol";

/// @notice Compact, complete combined profile under the existing multiplicity request/selector.
library StreamArtistMultipleDelegationHydrationTypes {
    bytes32 internal constant PROFILE =
        keccak256("6529STREAM_ARTIST_MULTIPLE_LIVING_DELEGATION_V1");
    bytes32 internal constant IDENTITY =
        keccak256("6529STREAM_ARTIST_MULTIPLE_DELEGATION_IDENTITIES_V1");
    bytes32 internal constant BINDING =
        keccak256("6529STREAM_ARTIST_MULTIPLE_DELEGATION_BINDINGS_V1");
    bytes32 internal constant ACCEPTANCE =
        keccak256("6529STREAM_ARTIST_MULTIPLE_DELEGATION_ACCEPTANCES_V1");
    bytes32 internal constant ATTRIBUTION =
        keccak256("6529STREAM_ARTIST_MULTIPLE_DELEGATION_ATTRIBUTIONS_V1");
    bytes32 internal constant CONSENT =
        keccak256("6529STREAM_ARTIST_MULTIPLE_DELEGATION_CONSENTS_V1");

    struct IdentityRow {
        bytes32 artistId;
        bytes32[] records;
        bytes state;
        StreamArtistAuthorityHydrationTypes.NonceWord[] nonces;
    }

    struct Identities {
        IdentityRow[] rows;
        uint256[] collectionIds;
    }

    struct BindingRow {
        uint256 collectionId;
        StreamArtistAuthorityHydrationTypes.Binding state;
    }

    struct AcceptanceRow {
        bytes32 bindingHash;
        StreamArtistAuthorityHydrationTypes.Acceptance state;
    }

    struct AttributionRow {
        uint256 collectionId;
        uint8 state;
        uint64 generation;
    }

    struct ConsentRow {
        uint256 collectionId;
        StreamArtistAuthorityHydrationTypes.PolicyKey[] policies;
        StreamArtistDelegationHydrationTypes.Consent state;
    }

    struct Inventory {
        StreamArtistAuthorityHydrationTypes.Query[] artists;
        StreamArtistAuthorityHydrationTypes.Query[] collections;
        StreamArtistHistoryTypes.Receipt[][7] receipts;
    }

    struct Collections {
        BindingRow[] bindings;
        AcceptanceRow[] acceptances;
        AttributionRow[] attributions;
        ConsentRow[] consents;
    }
}
