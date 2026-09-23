// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorAttributionProof as Proof
} from "./StreamArtistPrimaryCollaboratorAttributionProof.sol";
import {
    StreamArtistPrimaryCollaboratorProofFrame as Frame
} from "./StreamArtistPrimaryCollaboratorProofFrame.sol";
import {
    StreamArtistPrimaryCollaboratorProofDecode as Decode
} from "./StreamArtistPrimaryCollaboratorProofDecode.sol";

/// @notice Complete third canonical/local proof check before the original full current validation.
library StreamArtistPrimaryCollaboratorAttributionEncoded {
    function validate(
        M.State calldata scope,
        RH.OwnerProvenance calldata provenance,
        bytes calldata raw
    ) public view returns (Proof.Result memory) {
        Decode.requireValid(Decode.Context(4, raw, provenance));
        PC.Proof calldata inventory = Frame.proof(raw);
        if (keccak256(raw) != keccak256(abi.encode(inventory))) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        bytes memory result = Proof.encoded(scope, provenance, raw);
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }
}
