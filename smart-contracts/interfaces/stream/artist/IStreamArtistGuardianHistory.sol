// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistGuardianHistoryTypes as H } from "./StreamArtistGuardianHistoryTypes.sol";

/// @notice Identity-owner read bundle. Index0/action0 return absent entry/snapshot; actor membership is per artist.
interface IStreamArtistGuardianHistory {
    function guardianHistoryState(bytes32 artistId, uint64 index, address actor, bytes32 actionId)
        external
        view
        returns (H.Head memory, H.Entry memory, H.Snapshot memory, uint64);
}
