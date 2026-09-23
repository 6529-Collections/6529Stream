// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistGuardianVestingTypes as V } from "./StreamArtistGuardianVestingTypes.sol";

/// @notice Fixed Identity owner's immutable original vesting evidence; unknown records reject.
interface IStreamArtistGuardianVestingHistory {
    function guardianVestingSnapshot(bytes32 artistId, bytes32 transitionRecordHash)
        external
        view
        returns (V.Snapshot memory);
}
