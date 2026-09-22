// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";

/// @notice Separate complete-history carrier; existing profile tuples and tags remain unchanged.
/// @dev Constants reserve an encoding. They do not advertise owner capabilities or select a route.
library StreamArtistCompleteHistoryTypes {
    bytes32 internal constant SCHEMA = keccak256("6529STREAM_ARTIST_COMPLETE_HISTORY_V1");
    uint16 internal constant VERSION = 1;
    uint256 internal constant FEATURE = 33554432;

    struct Inventory {
        RH.Provenance provenance;
        PC.BindingInventory bindings;
        PC.Inventory archive;
        P.Platform[] platforms;
        A.AcceptanceBundle[] accepted;
        IH.NonceLane[] accounts;
    }

    /// @dev Every slot names the same authentic principal across complete Identity/Payout rows.
    /// An authority supplement is interpreted only by the fixed original-state family adapter.
    struct Principals {
        bytes[] identities;
        bytes[] payouts;
        bytes[] authoritySupplement;
    }
}
