// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredAcceptedBindingHydration as Binding
} from "./StreamArtistRecoveredAcceptedBindingHydration.sol";
import {
    StreamArtistRecoveredAcceptanceHistory as Acceptance
} from "./StreamArtistRecoveredAcceptanceHistory.sol";
import {
    StreamArtistRecoveredRevokedAttribution as Attribution
} from "./StreamArtistRecoveredRevokedAttribution.sol";
import {
    StreamArtistRecoveredAcceptedGenerationFacts as Facts
} from "./StreamArtistRecoveredAcceptedGenerationFacts.sol";
import {
    StreamArtistRecoveredPreparationTuple as Tuple
} from "./StreamArtistRecoveredPreparationTuple.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredBindingGenerations as G
} from "./StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

import {
    StreamArtistRecoveredPreparationGenerations as OriginalGenerations
} from "./StreamArtistRecoveredPreparationGenerations.sol";

/// @notice Complete source-authenticated accepted-generation composition before any owner write.
library StreamArtistRecoveredAcceptedGenerationStage {
    /// @notice Fixed new-profile routing; the original generation collector remains byte-exact.
    function select(
        T.SuiteConfiguration memory source,
        AH.Query memory query,
        RH.Provenance memory provenance,
        bytes memory identity,
        bool hasIdentityDelegations,
        uint256 witnessCount,
        uint256 royaltyFreezeCount
    ) public view returns (bytes memory encoded, uint8 consentMode, bool hasGenerations) {
        if (provenance.journals[3].length > 1) {
            return collect(source, query, provenance, identity, witnessCount, royaltyFreezeCount);
        }
        return OriginalGenerations.collect(
            source,
            query,
            provenance,
            identity,
            hasIdentityDelegations,
            witnessCount,
            royaltyFreezeCount
        );
    }

    function collect(
        T.SuiteConfiguration memory source,
        AH.Query memory q,
        RH.Provenance memory p,
        bytes memory identity,
        uint256 witnesses,
        uint256 royalties
    ) public view returns (bytes memory raw, uint8 mode, bool hasGenerations) {
        uint256 expectedWitness;
        uint256 expectedRoyalties;
        for (uint256 i; i < p.journals[4].length; ++i) {
            if (p.journals[4][i].receipt.operation != 44) revert T.UnsupportedProfile();
        }
        for (uint256 i; i < p.journals[6].length; ++i) {
            uint16 op = p.journals[6][i].receipt.operation;
            if (op == 15) expectedWitness = 1;
            if (op == 20) ++expectedRoyalties;
            if (op != 14 && op != 15 && op != 16 && op != 17 && op != 20 && op != 21 && op != 52) {
                revert T.UnsupportedProfile();
            }
        }
        if (witnesses != expectedWitness || royalties != expectedRoyalties) {
            revert T.UnsupportedProfile();
        }
        CB.Bundle memory b = Binding.collect(source.owners[0], q, RH.ownerProvenance(p, 0));
        Acceptance.collect(source.owners[3], q, RH.ownerProvenance(p, 3), b.bindings);
        Attribution.collect(source.owners[4], q, p, b);
        raw = abi.encode(b.bindings);
        mode = b.bindings.current.consentMode;
        hasGenerations = true;
        if (address(Facts).code.length == 0) assembly ("memory-safe") { revert(0, 0) }
        (bool ok, bytes memory out) = address(Facts)
            .staticcall(
                bytes.concat(
                    Facts.validate.selector, Tuple.four(identity, raw, abi.encode(q), abi.encode(p))
                )
            );
        Tuple.result(ok, out);
    }

    function ownerState(
        T.SuiteConfiguration memory source,
        AH.Query memory q,
        RH.Provenance memory p,
        bytes memory raw,
        uint8 ownerIndex
    ) public view returns (bytes memory) {
        CB.Bundle memory b = Binding.collect(source.owners[0], q, RH.ownerProvenance(p, 0));
        if (keccak256(raw) != keccak256(abi.encode(b.bindings))) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        if (ownerIndex == 3) {
            return Acceptance.encode(
                Acceptance.collect(source.owners[3], q, RH.ownerProvenance(p, 3), b.bindings),
                q,
                RH.ownerProvenance(p, 3)
            );
        }
        if (ownerIndex == 4) {
            return Attribution.encode(
                Attribution.collect(source.owners[4], q, p, b), q, RH.ownerProvenance(p, 4)
            );
        }
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
