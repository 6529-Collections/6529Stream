// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice Complete original eager owner/scope tuple decoding, including unused nested fields.
library StreamArtistPrimaryCollaboratorArgumentContext {
    function scope(bytes calldata raw) public pure returns (bytes memory) {
        M.State memory x = abi.decode(raw, (M.State));
        return abi.encode(x);
    }

    function owner(bytes calldata raw) public pure returns (bytes memory) {
        RH.OwnerProvenance memory x = abi.decode(raw, (RH.OwnerProvenance));
        return abi.encode(x);
    }
}
