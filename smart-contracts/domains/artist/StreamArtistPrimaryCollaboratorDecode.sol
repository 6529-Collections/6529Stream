// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorCodec as Codec
} from "./StreamArtistPrimaryCollaboratorCodec.sol";
import {
    StreamArtistPrimaryCollaboratorSourceProof as Source
} from "./StreamArtistPrimaryCollaboratorSourceProof.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";

/// @notice Canonical owner envelope and exact local/full provenance relation before source re-observation.
library StreamArtistPrimaryCollaboratorDecode {
    function collect(uint8 owner, AH.Query memory anchor, bytes memory outer)
        public
        view
        returns (M.State memory scope, Payload.Payload memory payload, PC.Proof memory proof)
    {
        (scope, payload) = Codec.outer(owner, anchor, outer);
        (, bytes memory raw) =
            Codec.decodeAuxiliary(owner, payload.semanticState, payload.provenance);
        proof = Codec.proof(owner, raw, payload.provenance);
        Source.requireCurrent(scope, proof);
    }
}
