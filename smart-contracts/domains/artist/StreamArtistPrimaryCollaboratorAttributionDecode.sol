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
    StreamArtistPrimaryCollaboratorCodec as Codec
} from "./StreamArtistPrimaryCollaboratorCodec.sol";
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
    StreamArtistPrimaryCollaboratorAttributionEncoded as Encoded
} from "./StreamArtistPrimaryCollaboratorAttributionEncoded.sol";

/// @notice Exact owner4 decode and full current proof before storage-reference import.
library StreamArtistPrimaryCollaboratorAttributionDecode {
    struct Result {
        M.State scope;
        RH.OwnerProvenance provenance;
        Proof.Result proof;
        bytes inventory;
    }

    function collect(AH.Query memory anchor, bytes memory outer)
        public
        view
        returns (Result memory c)
    {
        (c.scope, c.provenance, c.inventory) = Codec.prepareAttribution(anchor, outer);
        c.proof = Encoded.validate(c.scope, c.provenance, c.inventory);
    }

    /// @dev Only projects rows after collect has authenticated the complete canonical Proof.
    /// Called after the original Revocation.install, matching the original import order.
    function bindingHashes(bytes calldata raw) public pure returns (bytes32[][] memory hashes) {
        PC.Proof calldata inventory = Frame.proof(raw);
        hashes = new bytes32[][](inventory.bindings.bindings.length);
        for (uint256 k; k < hashes.length; ++k) {
            hashes[k] = new bytes32[](inventory.bindings.bindings[k].bindings.rows.length);
            for (uint256 g; g < hashes[k].length; ++g) {
                hashes[k][g] = inventory.bindings.bindings[k].bindings.rows[g].item.bindingHash;
            }
        }
    }
}
