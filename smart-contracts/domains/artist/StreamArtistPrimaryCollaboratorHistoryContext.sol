// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredAcceptedGenerationTypes as C
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";

/// @notice Complete original eager typed decode and canonical re-encoding at a fixed compiler boundary.
library StreamArtistPrimaryCollaboratorHistoryContext {
    function canonical(bytes calldata raw) public pure returns (bytes memory) {
        C.AttributionBundle[] memory value = abi.decode(raw, (C.AttributionBundle[]));
        return abi.encode(value);
    }
}
