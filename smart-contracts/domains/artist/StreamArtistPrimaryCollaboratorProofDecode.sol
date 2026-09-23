// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPrimaryCollaboratorTypes as G
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistPrimaryCollaboratorProofCanonical as Canonical
} from "./StreamArtistPrimaryCollaboratorProofCanonical.sol";
import {
    StreamArtistPrimaryCollaboratorProofFrame as Frame
} from "./StreamArtistPrimaryCollaboratorProofFrame.sol";
import {
    StreamArtistPrimaryCollaboratorProofLocal as Local
} from "./StreamArtistPrimaryCollaboratorProofLocal.sol";

/// @notice All original fields decode before canonical equality and exact selected-owner comparison.
library StreamArtistPrimaryCollaboratorProofDecode {
    struct Context {
        uint8 owner;
        bytes raw;
        RH.OwnerProvenance local;
    }

    function requireValid(Context calldata x) public pure {
        bytes memory canonical = Canonical.canonical(x.raw);
        if (keccak256(x.raw) != keccak256(canonical)) revert RH.InvalidRecoveredHydrationProfile();
        G.Proof calldata result = Frame.proof(x.raw);
        if (keccak256(abi.encode(x.local)) != keccak256(Local.encoded(result.provenance, x.owner)))
        {
            revert RH.InvalidRecoveredHydrationProfile();
        }
    }
}
