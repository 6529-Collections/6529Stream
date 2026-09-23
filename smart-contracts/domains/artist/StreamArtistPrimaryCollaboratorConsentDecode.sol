// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredAggregateConsentProof as SupplementProof
} from "./StreamArtistRecoveredAggregateConsentProof.sol";
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
    StreamArtistPrimaryCollaboratorSourceProof as Source
} from "./StreamArtistPrimaryCollaboratorSourceProof.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationConsentValidation as Validation
} from "./StreamArtistRecoveredMultipleGenerationConsentValidation.sol";
import {
    StreamArtistPrimaryCollaboratorEnvelopeProjection as Envelope
} from "./StreamArtistPrimaryCollaboratorEnvelopeProjection.sol";

/// @notice Complete original Consent envelope/source/row validation before importing storage maps.
library StreamArtistPrimaryCollaboratorConsentDecode {
    struct Result {
        AH.Query[] collections;
        G.Consents[] rows;
    }

    function collect(AH.Query memory anchor, bytes memory outer)
        public
        view
        returns (Result memory result)
    {
        (bytes memory scopeBytes, bytes memory payloadBytes, bytes memory proofBytes) =
            Codec.prepareSource(6, anchor, outer);
        M.State memory s = abi.decode(scopeBytes, (M.State));
        Source.requireEncoded(s, proofBytes);
        RH.OwnerProvenance memory provenance = Envelope.provenance(payloadBytes);
        result.collections = s.collections;
        result.rows = SupplementProof.validate(s.rows, s.collections, provenance, outer);
    }
}
