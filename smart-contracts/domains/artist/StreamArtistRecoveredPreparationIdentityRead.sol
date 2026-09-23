// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredIdentityHydrationSource as Identity
} from "./StreamArtistRecoveredIdentityHydrationSource.sol";

import {
    StreamArtistRecoveredPreparationTuple as Tuple
} from "./StreamArtistRecoveredPreparationTuple.sol";

/// @notice Fixed typed stage of recovered-authority preparation.
/// @dev Intermediate bytes are ABI encodings of the named complete bundle, never caller-selected calls.
library StreamArtistRecoveredPreparationIdentityRead {
    function collect(address source, AH.Query memory query, RH.OwnerProvenance memory provenance)
        public
        view
        returns (bytes memory)
    {
        // The original fixed view library authenticates the entire bundle before returning it.
        // Its read closure is caller-independent. Preserve its single-tuple return bytes.
        (bool ok, bytes memory raw) = address(Identity)
            .staticcall(
                abi.encodeWithSelector(Identity.collect.selector, source, query, provenance)
            );
        raw = Tuple.result(ok, raw);
        Tuple.requireSingle(raw); // Require the complete single-dynamic-argument envelope.
        return raw;
    }
}
