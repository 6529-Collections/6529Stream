// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistAttributionOwner as Attribution
} from "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    StreamArtistRecoveredBindingGenerations as Generations
} from "./StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredPreparationGenerationFacts as Facts
} from "./StreamArtistRecoveredPreparationGenerationFacts.sol";
import {
    StreamArtistRecoveredPreparationTuple as Tuple
} from "./StreamArtistRecoveredPreparationTuple.sol";

/// @notice Original bounded generation selection and complete source joins before attestations.
library StreamArtistRecoveredPreparationGenerations {
    function collect(
        T.SuiteConfiguration memory source,
        AH.Query memory query,
        RH.Provenance memory provenance,
        bytes memory identity,
        bool hasIdentityDelegations,
        uint256 witnessCount,
        uint256 royaltyFreezeCount
    ) public view returns (bytes memory encoded, uint8 consentMode, bool hasGenerations) {
        T.Binding memory current = Binding(source.owners[0]).binding(query.collectionId);
        consentMode = current.consentMode;
        hasGenerations = current.generation > 1;
        if (!hasGenerations) return (encoded, consentMode, false);
        if (
            consentMode != 1 || hasIdentityDelegations || witnessCount != 0
                || royaltyFreezeCount != 0
        ) {
            revert T.UnsupportedProfile();
        }
        for (uint256 i; i < provenance.journals[6].length; ++i) {
            if (provenance.journals[6][i].receipt.operation != 14) revert T.UnsupportedProfile();
        }
        Generations.Bundle memory generations =
            Generations.collect(source.owners[0], query, RH.ownerProvenance(provenance, 0));
        encoded = abi.encode(generations);
        if (address(Facts).code.length == 0) assembly ("memory-safe") { revert(0, 0) }
        (bool ok, bytes memory result) = address(Facts)
            .staticcall(
                bytes.concat(
                    Facts.validate.selector,
                    Tuple.four(identity, encoded, abi.encode(query), abi.encode(provenance))
                )
            );
        Tuple.result(ok, result);
        (uint8 state, uint64 generation) =
            Attribution(source.owners[4]).attributionState(query.collectionId);
        if (state != 2 || generation != generations.current.generation) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
    }

    /// @dev Called only at owner0's semantic step after its original capability and guard checks.
    function encode(
        bytes memory encoded,
        AH.Query memory query,
        RH.OwnerProvenance memory provenance
    ) public pure returns (bytes memory) {
        return Generations.encode(abi.decode(encoded, (Generations.Bundle)), query, provenance);
    }
}
