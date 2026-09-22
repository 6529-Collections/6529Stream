// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPrimaryCollaboratorAttributionProof as Proof
} from "./StreamArtistPrimaryCollaboratorAttributionProof.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistPrimaryCollaboratorCodec as Codec
} from "./StreamArtistPrimaryCollaboratorCodec.sol";
import {
    StreamArtistRecoveredMultipleGenerationClocks as Clocks
} from "./StreamArtistRecoveredMultipleGenerationClocks.sol";
import {
    StreamArtistRecoveredMultipleGenerationRevocations as Revocations
} from "./StreamArtistRecoveredMultipleGenerationRevocations.sol";
import {
    StreamArtistRecoveredMultipleGenerationAttestationValidation as Attestations
} from "./StreamArtistRecoveredMultipleGenerationAttestationValidation.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistPrimaryCollaboratorCatalogue as Catalogue
} from "./StreamArtistPrimaryCollaboratorCatalogue.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
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

/// @notice Post-write revalidation of the complete generation envelope and all seven original Archive cutoffs.
library StreamArtistPrimaryCollaboratorCurrent {
    function requireCurrent(RH.Provenance memory full, AH.Query memory anchor, bytes memory outer)
        public
        view
    {
        (M.State memory scope, Payload.Payload memory p) = Codec.outer(4, anchor, outer);
        if (
            keccak256(abi.encode(p.provenance))
                != keccak256(abi.encode(RH.ownerProvenance(full, 4)))
        ) _invalid();
        (, bytes memory raw) = Codec.decodeAuxiliary(4, p.semanticState, p.provenance);
        PC.Proof memory inventory = Codec.proof(4, raw, p.provenance);
        if (
            keccak256(raw) != keccak256(abi.encode(inventory))
                || keccak256(abi.encode(full)) != keccak256(abi.encode(inventory.provenance))
        ) _invalid();
        Proof.requireValid(scope, p.provenance, inventory);
        Catalogue.requireCurrent(full, inventory.archive.catalogues, inventory.archive.operations);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
