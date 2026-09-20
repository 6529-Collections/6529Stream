// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationCommit as Commit
} from "./StreamArtistRecoveredHydrationCommit.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredPreparationInventory as Inventory
} from "./StreamArtistRecoveredPreparationInventory.sol";

/// @notice Final exact-inventory check and original single-tuple return encoding.
/// @dev Called only after every source and owner check by the fixed preparation stage.
library StreamArtistRecoveredPreparationSeal {
    function encode(Commit.Prepared calldata prepared, bool requireInventory, bytes32 expected)
        public
        pure
        returns (bytes memory)
    {
        if (requireInventory && (expected == 0 || expected != Inventory.inventory(prepared))) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        return abi.encode(prepared);
    }
}
