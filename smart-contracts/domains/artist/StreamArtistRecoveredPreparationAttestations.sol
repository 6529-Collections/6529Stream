// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredAttestationHydration as Attestations
} from "./StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistReadinessHydrationTypes as ReadinessH
} from "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistPublicationHydrationTypes as PubH
} from "../../interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";

/// @notice Fixed typed stage of recovered-authority preparation.
/// @dev Intermediate bytes are ABI encodings of the named complete bundle, never caller-selected calls.
library StreamArtistRecoveredPreparationAttestations {
    function collect(
        address source,
        AH.Query memory query,
        RH.OwnerProvenance memory provenance,
        bytes memory terms
    ) public view returns (bytes memory raw, bytes memory records) {
        Attestations.Bundle memory bundle = Attestations.collect(
            source, query, provenance, abi.decode(terms, (ReadinessH.AttestationInput[]))
        );
        return (abi.encode(bundle), abi.encode(bundle.records));
    }

    function emptyRecords() public pure returns (bytes memory) {
        return abi.encode(new PubH.Row[](0));
    }

    function encode(bytes memory raw, AH.Query memory query, RH.OwnerProvenance memory provenance)
        public
        pure
        returns (bytes memory)
    {
        return Attestations.encode(abi.decode(raw, (Attestations.Bundle)), query, provenance);
    }
}
