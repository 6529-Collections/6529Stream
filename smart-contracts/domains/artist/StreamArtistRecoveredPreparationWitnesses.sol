// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistMultipleRecordsTypes as MR
} from "../../interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredRecordWitnesses as Witnesses
} from "./StreamArtistRecoveredRecordWitnesses.sol";

/// @notice Complete original witness selection before Identity collection.
/// @dev Retains every attestation input as canonical typed bytes for its later fixed collector.
library StreamArtistRecoveredPreparationWitnesses {
    function collect(
        T.SuiteConfiguration memory source,
        RH.Provenance memory provenance,
        AH.Query memory query,
        MR.CollectionWitness[] memory witnesses
    )
        public
        pure
        returns (
            T.EconomicsConsent[] memory economics,
            bytes memory attestationInputs,
            bool hasAttestations
        )
    {
        MR.CollectionWitness memory selected = Witnesses.collect(
            source, provenance, query, witnesses
        );
        return (
            selected.economics, abi.encode(selected.attestations), selected.attestations.length != 0
        );
    }
}
