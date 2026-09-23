// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredBindingGenerations as Original
} from "./StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistBindingCorrectionState as State
} from "./StreamArtistBindingCorrectionState.sol";

/// @notice Complete original generation rows plus their immutable original op1 approvals.
library StreamArtistRecoveredBindingCorrectionTypes {
    bytes32 internal constant SCHEMA =
        keccak256("6529STREAM_ARTIST_RECOVERED_BINDING_CORRECTIONS_V1");
    bytes32 internal constant ACTION = keccak256("binding_lifecycle.replay.correction_action");

    struct Bundle {
        Original.Bundle bindings;
        State.Correction[] corrections;
    }

    function tagged(bytes memory raw) internal pure returns (bool) {
        return raw.length >= 32 && abi.decode(raw, (bytes32)) == SCHEMA;
    }
}
