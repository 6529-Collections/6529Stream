// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPrimaryCollaboratorFamilyFinalization as Finalization
} from "./StreamArtistPrimaryCollaboratorFamilyFinalization.sol";
import {
    StreamArtistPrimaryCollaboratorFamilyConservation as Conservation
} from "./StreamArtistPrimaryCollaboratorFamilyConservation.sol";
import {
    StreamArtistPrimaryCollaboratorFamilyEncoding as Encoding
} from "./StreamArtistPrimaryCollaboratorFamilyEncoding.sol";

/// @notice Original fixed identity/conservation phase before full result encoding.
library StreamArtistPrimaryCollaboratorFamilyFinish {
    function finish(bytes calldata raw, bytes calldata rows, bytes calldata history)
        public
        view
        returns (bytes memory)
    {
        Conservation.requireValid(raw, rows, history);
        return Finalization.finish(raw, Encoding.encoded(raw, rows), history);
    }
}
