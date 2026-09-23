// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import { StreamArtistCompleteHistoryTypes as CT } from "./StreamArtistCompleteHistoryTypes.sol";
import { StreamArtistCompleteHistoryCodec as Codec } from "./StreamArtistCompleteHistoryCodec.sol";
import {
    StreamArtistCompleteHistorySource as Source
} from "./StreamArtistCompleteHistorySource.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as Clocks
} from "./StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";

/// @notice Canonical owner envelope and re-observed original shared binding/Archive inventory.
/// @dev Owner workers additionally validate their family rows. The Coordinator must prove
/// the full principal, dispute, consent and grant joins before the original atomic operation60.
/// This source phase neither selects the reserved profile nor authorizes import on its own.
library StreamArtistCompleteHistoryDecode {
    function collect(uint8 owner, AH.Query memory anchor, bytes memory outer)
        public
        view
        returns (
            M.State memory scope,
            Payload.Payload memory payload,
            CT.Inventory memory inventory,
            Clocks.Result memory clocks
        )
    {
        (scope, payload) = Codec.outer(owner, anchor, outer);
        (, bytes memory raw) =
            Codec.decodeAuxiliary(owner, payload.semanticState, payload.provenance);
        inventory = Codec.inventory(owner, raw, payload.provenance);
        clocks = Source.requireCurrent(scope, inventory);
    }
}
