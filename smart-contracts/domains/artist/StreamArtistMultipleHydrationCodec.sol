// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";
import {
    StreamArtistMultipleHydrationTypes as MH
} from "../../interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Explicit typed envelope, never an arbitrary storage or call transport.
library StreamArtistMultipleHydrationCodec {
    function isState(bytes memory raw) internal pure returns (bool) {
        bytes32 tag;
        if (raw.length >= 32) assembly ("memory-safe") { tag := mload(add(raw, 32)) }
        return tag == MH.SCHEMA;
    }

    function decode(bytes memory raw) internal pure returns (MH.Bundle memory b) {
        bytes32 tag;
        (tag, b) = abi.decode(raw, (bytes32, MH.Bundle));
        if (
            tag != MH.SCHEMA || b.rows.length == 0 || b.rows.length > 128
                || keccak256(raw) != keccak256(abi.encode(tag, b))
        ) revert T.InvalidRecord();
    }
}
