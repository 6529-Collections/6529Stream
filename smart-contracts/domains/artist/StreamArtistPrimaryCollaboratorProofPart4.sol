// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPrimaryCollaboratorTypes as G
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistPrimaryCollaboratorProofFrame as Frame
} from "./StreamArtistPrimaryCollaboratorProofFrame.sol";

/// @notice Original complete Proof field 4, typed decode then typed re-encode.
library StreamArtistPrimaryCollaboratorProofPart4 {
    function decode(bytes calldata raw) public pure returns (bytes memory) {
        (, IH.NonceLane[] memory value) = abi.decode(Frame.body(raw), (uint256[4], IH.NonceLane[]));
        return abi.encode(value);
    }
}
