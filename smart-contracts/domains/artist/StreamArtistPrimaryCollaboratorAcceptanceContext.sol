// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredAcceptedGenerationTypes as T
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";

/// @notice Complete original eager acceptance array decoder, including all unused rows.
library StreamArtistPrimaryCollaboratorAcceptanceContext {
    function canonical(bytes calldata raw) public pure returns (bytes memory) {
        T.AcceptanceBundle[] memory rows = abi.decode(raw, (T.AcceptanceBundle[]));
        return abi.encode(rows);
    }
}
