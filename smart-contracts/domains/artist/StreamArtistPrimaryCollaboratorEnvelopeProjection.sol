// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice Fixed typed owner-provenance projection after complete original payload admission.
library StreamArtistPrimaryCollaboratorEnvelopeProjection {
    /// @dev Complete payload was decoded and canonicalized by Codec.prepareSource before
    /// this projection. All nonce/publication fields remain validated even for owner6.
    function provenance(bytes calldata raw) public pure returns (RH.OwnerProvenance memory) {
        if (raw.length < 160 || raw.length % 32 != 0) assembly ("memory-safe") { revert(0, 0) }
        uint256 at;
        assembly ("memory-safe") { at := calldataload(raw.offset) }
        if (at != 32) assembly ("memory-safe") { revert(0, 0) }
        return abi.decode(raw[32:], (RH.OwnerProvenance));
    }
}
