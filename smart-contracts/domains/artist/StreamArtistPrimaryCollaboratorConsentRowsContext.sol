// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleGenerationTypes as T
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";

/// @notice Complete original eager consent array decoder, including all unused rows.
library StreamArtistPrimaryCollaboratorConsentRowsContext {
    function canonical(bytes calldata raw) public pure returns (bytes memory) {
        T.Consents[] memory rows = abi.decode(raw, (T.Consents[]));
        return abi.encode(rows);
    }
}
