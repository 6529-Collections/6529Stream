// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationSource as Identity
} from "./StreamArtistRecoveredIdentityHydrationSource.sol";

import {
    StreamArtistRecoveredPreparationTuple as Tuple
} from "./StreamArtistRecoveredPreparationTuple.sol";
import {
    StreamArtistRecoveredPreparationIdentityFacts as Facts
} from "./StreamArtistRecoveredPreparationIdentityFacts.sol";

/// @notice Original ordered nonce equality followed by the unchanged complete Identity encoder.
library StreamArtistRecoveredPreparationIdentityEncode {
    function encode(
        bytes memory raw,
        RH.OwnerProvenance memory provenance,
        RH.NonceInventory[] memory nonces
    ) public view returns (bytes memory) {
        if (address(Facts).code.length == 0) {
            assembly ("memory-safe") { revert(0, 0) }
        }
        (bool ok, bytes memory result) = address(Facts)
            .staticcall(bytes.concat(Facts.nonces.selector, Tuple.two(raw, abi.encode(nonces))));
        Tuple.result(ok, result);
        (ok, result) = address(Identity)
            .staticcall(
                bytes.concat(Identity.encode.selector, Tuple.two(raw, abi.encode(provenance)))
            );
        return abi.decode(Tuple.result(ok, result), (bytes));
    }
}
