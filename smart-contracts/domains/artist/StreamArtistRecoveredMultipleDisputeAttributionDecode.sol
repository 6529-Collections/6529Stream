// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredMultipleDisputeCodec as Codec
} from "./StreamArtistRecoveredMultipleDisputeCodec.sol";
import {
    StreamArtistRecoveredMultipleDisputeAttributionProof as Proof
} from "./StreamArtistRecoveredMultipleDisputeAttributionProof.sol";
import {
    StreamArtistRecoveredMultipleDisputeAttributionValidation as Validation
} from "./StreamArtistRecoveredMultipleDisputeAttributionValidation.sol";
import {
    StreamArtistRecoveredMultipleDisputeAttributionBindings as Bindings
} from "./StreamArtistRecoveredMultipleDisputeAttributionBindings.sol";

/// @notice Exact owner4 dispute attribution decode and proof before storage checks.
library StreamArtistRecoveredMultipleDisputeAttributionDecode {
    struct Result {
        M.State scope;
        RH.OwnerProvenance provenance;
        bytes inventory;
    }

    function prepare(AH.Query memory anchor, bytes memory outer)
        public
        pure
        returns (M.State memory scope, RH.OwnerProvenance memory provenance, bytes memory inventory)
    {
        return Codec.attributionPrelude(anchor, outer);
    }

    function validate(M.State memory scope, RH.OwnerProvenance memory provenance, bytes calldata raw)
        public
        view
        returns (Proof.Result memory proof)
    {
        proof = Validation.validate(scope, provenance, raw);
    }

    /// @dev Projects rows after complete proof and dispute installs, matching import order.
    function bindingHashes(bytes calldata raw) public pure returns (bytes32[][] memory hashes) {
        hashes = Bindings.bindingHashes(raw);
    }

}
