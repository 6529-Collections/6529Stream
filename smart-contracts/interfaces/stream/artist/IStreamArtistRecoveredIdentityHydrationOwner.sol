// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "./StreamArtistRecoveredHydrationTypes.sol";
import { StreamArtistAuthorityHydrationTypes as AH } from "./IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "./StreamArtistRecoveredIdentityHydrationTypes.sol";

/// @notice Fixed-source storage export, including private maps absent from original read interfaces.
/// @dev The owner derives complete rows from its authenticated journal, replay/action inventory and
/// imported provenance. Query is a subject selector, never supplied record bodies or raw slots.
interface IStreamArtistRecoveredIdentityHydrationOwner {
    function recoveredIdentityHydrationRaw(
        AH.Query calldata query,
        RH.OwnerProvenance calldata local
    ) external view returns (IH.Bundle memory);
    /// @notice Actual keyed preparation owner, including actions with no operation35.
    function recoveredIdentityHydrationActionArtist(bytes32 actionId)
        external
        view
        returns (bytes32);
}
