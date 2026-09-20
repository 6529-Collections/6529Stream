// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredBindingGenerations as Generations
} from "./StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredRatificationHydration as Ratified
} from "./StreamArtistRecoveredRatificationHydration.sol";
import {
    StreamArtistRecoveredRatificationFacts as Facts
} from "./StreamArtistRecoveredRatificationFacts.sol";
import {
    StreamArtistRecoveredPreparationTuple as Tuple
} from "./StreamArtistRecoveredPreparationTuple.sol";

/// @notice Fixed complete52 preparation branch, using the existing Request and seven-owner seal.
library StreamArtistRecoveredRatificationStage {
    function selected(RH.JournalEntry[] memory journal) public pure returns (bool) {
        for (uint256 i; i < journal.length; ++i) {
            if (journal[i].receipt.operation == 52) return true;
        }
        return false;
    }

    function collect(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        T.EconomicsConsent[] memory economics,
        T.RoyaltyFreeze[] memory royalties,
        bytes memory rawGenerations,
        uint8 mode
    ) public view returns (bytes memory) {
        uint64 generation = 1;
        if (rawGenerations.length != 0) {
            Generations.Bundle memory bindings = abi.decode(rawGenerations, (Generations.Bundle));
            if (
                bindings.current.bindingHash != q.bindingHash
                    || bindings.current.consentMode != mode || !bindings.current.accepted
                    || bindings.current.generation != bindings.rows.length
            ) revert RH.InvalidRecoveredHydrationProfile();
            generation = bindings.current.generation;
        }
        return Ratified.collect(source, q, p, economics, royalties, generation, mode);
    }

    function facts(
        bytes memory identity,
        bytes memory consent,
        AH.Query memory q,
        RH.Provenance memory p,
        uint8 mode,
        bytes memory records
    ) public view {
        if (address(Facts).code.length == 0) {
            assembly ("memory-safe") { revert(0, 0) }
        }
        (bool ok, bytes memory result) = address(Facts)
            .staticcall(
                bytes.concat(
                    Facts.validate.selector,
                    Tuple.fourModeAndRows(
                        identity, abi.encode(consent), abi.encode(q), abi.encode(p), mode, records
                    )
                )
            );
        Tuple.result(ok, result);
    }

    function encode(bytes memory raw, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        pure
        returns (bytes memory)
    {
        (Ratified.Bundle memory b, uint64 generation, uint8 mode) = Ratified.decode(q, p, raw);
        return Ratified.encode(b, q, p, generation, mode);
    }
}
