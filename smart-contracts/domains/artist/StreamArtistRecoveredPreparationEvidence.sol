// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredExternalGuards as External
} from "./StreamArtistRecoveredExternalGuards.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    IStreamArtistRecoveredTimingInventory
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import {
    StreamArtistRecoveredTimingTypes as TM
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";

import {
    StreamArtistRecoveredPreparationTuple as Tuple
} from "./StreamArtistRecoveredPreparationTuple.sol";
import {
    StreamArtistRecoveredPreparationIdentityFacts as Facts
} from "./StreamArtistRecoveredPreparationIdentityFacts.sol";

/// @notice Original external, timing and feature checks over the complete fixed Identity bytes.
library StreamArtistRecoveredPreparationEvidence {
    function collect(
        bytes memory raw,
        RH.Provenance memory provenance,
        address source,
        bool payoutContinuations
    )
        public
        view
        returns (
            External.Snapshot memory externalGuards,
            TM.Checkpoint memory timing,
            uint256 features,
            bool hasDelegations
        )
    {
        (bool ok, bytes memory result) = address(External)
            .staticcall(
                bytes.concat(External.collect.selector, Tuple.two(abi.encode(provenance), raw))
            );
        externalGuards = abi.decode(Tuple.result(ok, result), (External.Snapshot));
        (ok, result) = address(Facts).staticcall(bytes.concat(Facts.timing.selector, raw));
        timing = abi.decode(Tuple.result(ok, result), (TM.Checkpoint));
        if (
            keccak256(abi.encode(timing))
                != keccak256(
                    abi.encode(
                        IStreamArtistRecoveredTimingInventory(source).recoveredTimingCheckpoint()
                    )
                )
        ) revert RH.InvalidRecoveredHydrationProvenance();
        (ok, result) = address(Facts)
            .staticcall(
                bytes.concat(
                    Facts.features.selector,
                    Tuple.oneWithTwoWords(raw, payoutContinuations ? 1 : 0, provenance.eras.length)
                )
            );
        (features, hasDelegations) = abi.decode(Tuple.result(ok, result), (uint256, bool));
    }
}
