// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistAuthorityHydrationTypes as AH } from "./IStreamArtistAuthorityHydration.sol";

/// @notice Explicit complete recovered base graph; all rows share one original owner provenance.
/// @dev Owner index fixes each row codec: Binding, no Collaborator rows, Identity, Acceptance,
/// Attribution, Payout, Policy. Bytes cannot select a method, destination or storage location.
library StreamArtistRecoveredMultipleTypes {
    bytes32 internal constant SCHEMA = keccak256("6529STREAM_ARTIST_RECOVERED_MULTIPLE_BASE_V1");
    uint16 internal constant VERSION = 1;

    struct State {
        AH.Query[] artists;
        AH.Query[] collections;
        bytes[] rows;
    }
}
