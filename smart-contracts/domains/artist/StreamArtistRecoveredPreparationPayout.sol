// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredPayoutTypes as P
} from "../../interfaces/stream/artist/StreamArtistRecoveredPayoutTypes.sol";
import {
    StreamArtistRecoveredPayoutHydration as Payout
} from "./StreamArtistRecoveredPayoutHydration.sol";

/// @notice Fixed typed stage of recovered-authority preparation.
/// @dev Intermediate bytes are ABI encodings of the named complete bundle, never caller-selected calls.
library StreamArtistRecoveredPreparationPayout {
    function collect(address source, bytes32 artistId, RH.Provenance memory provenance)
        public
        view
        returns (bytes memory raw, bool hasContinuations)
    {
        P.Bundle memory bundle = Payout.collect(source, artistId, provenance);
        return (abi.encode(bundle), bundle.continuations.length != 0);
    }

    function encode(bytes memory raw, RH.Provenance memory provenance)
        public
        pure
        returns (bytes memory)
    {
        return Payout.encode(abi.decode(raw, (P.Bundle)), provenance);
    }
}
