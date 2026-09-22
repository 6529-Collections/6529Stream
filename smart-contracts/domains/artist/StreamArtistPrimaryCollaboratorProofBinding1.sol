// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistPrimaryCollaboratorProofFrame as Frame
} from "./StreamArtistPrimaryCollaboratorProofFrame.sol";

/// @notice Complete original BindingInventory field 1; original typed decode and re-encode.
library StreamArtistPrimaryCollaboratorProofBinding1 {
    function decode(bytes calldata raw) public pure returns (bytes memory) {
        (, A.Generation[][] memory value) =
            abi.decode(Frame.bindingBody(raw), (uint256[1], A.Generation[][]));
        return abi.encode(value);
    }
}
