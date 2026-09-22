// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";

/// @notice Complete original sanction argument decoding before any family phase.
library StreamArtistPrimaryCollaboratorSanctionContext {
    function canonical(bytes calldata raw) public pure returns (bytes memory) {
        H.Inventory memory history = abi.decode(raw, (H.Inventory));
        return abi.encode(history);
    }
}
