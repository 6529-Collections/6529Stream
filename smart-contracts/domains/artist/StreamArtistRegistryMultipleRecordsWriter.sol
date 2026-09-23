// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistMultipleRecordsTypes,
    IStreamArtistMultipleRecordsHydrationCoordinator
} from "../../interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";
import {
    StreamArtistMultipleHydrationTypes,
    IStreamArtistMultipleHydrationCoordinator
} from "../../interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";

/// @notice Fixed typed encodings for the facade's multiple-authority hydration writers.
/// @dev The original extension checks its immutable host before entering this worker.
/// The original Request is decoded in full; there is no selector or dispatch input.
library StreamArtistRegistryMultipleRecordsWriter {
    function hydrateAuthority(address coordinator, address actor, bytes calldata arguments)
        public
        returns (bytes32)
    {
        StreamArtistMultipleHydrationTypes.Request memory request =
            abi.decode(arguments, (StreamArtistMultipleHydrationTypes.Request));
        return IStreamArtistMultipleHydrationCoordinator(coordinator)
            .coordinateHydrateMultipleArtistAuthority(actor, request);
    }

    function hydrate(address coordinator, address actor, bytes calldata arguments)
        public
        returns (bytes32)
    {
        StreamArtistMultipleRecordsTypes.Request memory request =
            abi.decode(arguments, (StreamArtistMultipleRecordsTypes.Request));
        return IStreamArtistMultipleRecordsHydrationCoordinator(coordinator)
            .coordinateHydrateMultipleArtistAuthorityWithRecords(actor, request);
    }
}
