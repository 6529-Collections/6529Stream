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

/// @notice Original complete Proof field 0, typed decode then typed re-encode.
library StreamArtistPrimaryCollaboratorProofPart0 {
    function decode(bytes calldata raw) public pure returns (bytes memory) {
        (RH.Provenance memory value) = abi.decode(Frame.body(raw), (RH.Provenance));
        return abi.encode(value);
    }
}
