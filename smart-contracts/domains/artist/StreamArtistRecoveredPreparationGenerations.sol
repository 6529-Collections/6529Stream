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

import {
    StreamArtistRecoveredAttestationFacts as AttestationFacts
} from "./StreamArtistRecoveredAttestationFacts.sol";

import {
    StreamArtistRecoveredAttestationHydration as Attestations
} from "./StreamArtistRecoveredAttestationHydration.sol";

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
        if (consentMode != 1 || hasIdentityDelegations || royaltyFreezeCount != 0) {
            revert T.UnsupportedProfile();
        }
        // Witnesses.collect already proves exact counts and source subjects. This stage
        // admits only the single exhaustive op24 witness, never economics or an empty extra.
        if (witnessCount != (provenance.journals[4].length == 0 ? 0 : 1)) {
            revert T.UnsupportedProfile();
        }
        for (uint256 i; i < provenance.journals[4].length; ++i) {
            if (provenance.journals[4][i].receipt.operation != 24) revert T.UnsupportedProfile();
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

    /// @dev Called after both full collectors and before any owner payload/import. Existing
    /// single-tuple framing preserves all original Identity signatures and nonce provenance.
    function attestations(
        bytes memory identity,
        bytes memory rawAttestations,
        AH.Query memory query,
        RH.Provenance memory provenance
    ) public view {
        Attestations.Bundle memory b = abi.decode(rawAttestations, (Attestations.Bundle));
        Attestations.validate(b, query, RH.ownerProvenance(provenance, 4));
        // collect already authenticated every original generation and matched its current
        // generation to this same Attribution source. Revalidate the complete collected
        // attestation bundle here; no caller supplies a generation or partial row projection.
        uint64 generation = b.item.generation;
        if (generation < 2 || generation > 128) revert RH.InvalidRecoveredHydrationProfile();
        if (address(AttestationFacts).code.length == 0) assembly ("memory-safe") { revert(0, 0) }
        (bool ok, bytes memory result) = address(AttestationFacts)
            .staticcall(
                bytes.concat(
                    AttestationFacts.validateGeneration.selector,
                    // uint8 and uint64 have the same canonical ABI word for this checked 2..128 range.
                    Tuple.fourAndMode(
                        identity,
                        abi.encode(b.records),
                        abi.encode(query),
                        abi.encode(provenance),
                        uint8(generation)
                    )
                )
            );
        abi.decode(Tuple.result(ok, result), (uint256[]));
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
