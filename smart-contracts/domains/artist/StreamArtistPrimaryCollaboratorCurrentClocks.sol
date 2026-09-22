// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as Clocks
} from "./StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistPrimaryCollaboratorSourceCollection as Collection
} from "./StreamArtistPrimaryCollaboratorSourceCollection.sol";
import {
    StreamArtistPrimaryCollaboratorSourceResultClocks as ResultClocks
} from "./StreamArtistPrimaryCollaboratorSourceResultClocks.sol";
import {
    StreamArtistPrimaryCollaboratorProofPart0 as Provenance
} from "./StreamArtistPrimaryCollaboratorProofPart0.sol";

/// @notice Full original current source proof before returning its authenticated clocks.
library StreamArtistPrimaryCollaboratorCurrentClocks {
    function requireCurrent(M.State memory scope, PC.Proof memory proof)
        public
        view
        returns (Clocks.Result memory)
    {
        (bytes memory actual, bytes memory observed) = Collection.encoded(scope, proof.provenance);
        if (keccak256(actual) != keccak256(abi.encode(proof))) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        return ResultClocks.decode(observed);
    }

    /// @dev Complete canonical raw Proof from the fixed caller; the full fresh source must match it.
    function requireEncoded(M.State memory scope, bytes memory raw)
        public
        view
        returns (Clocks.Result memory)
    {
        RH.Provenance memory p = abi.decode(Provenance.decode(raw), (RH.Provenance));
        (bytes memory actual, bytes memory observed) = Collection.encoded(scope, p);
        if (keccak256(actual) != keccak256(raw)) revert RH.InvalidRecoveredHydrationProfile();
        return ResultClocks.decode(observed);
    }
}
