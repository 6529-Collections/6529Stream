// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistHistoryState as History } from "./StreamArtistHistoryState.sol";
import { StreamArtistUnboundPlatformTypes as U } from "./StreamArtistUnboundPlatformTypes.sol";

/// @notice Original verified-lane activation checks with a distinct collection-only domain.
library StreamArtistUnboundPlatformActivation {
    function activateMultiple(bytes32[] memory artists, uint256[] memory collections, bytes32 value)
        public
    {
        if (value == 0 || collections.length == 0) {
            revert History.InvalidArtistHistory();
        }
        History.State storage s = History.state();
        if (s.cutover) revert History.InvalidArtistHistory();
        for (uint256 i; i < artists.length; ++i) {
            if (artists[i] == 0 || (i != 0 && artists[i] <= artists[i - 1])) {
                revert History.InvalidArtistHistory();
            }
            _activateMultipleLane(s, 1, artists[i], value);
        }
        for (uint256 i; i < collections.length; ++i) {
            if (collections[i] == 0 || (i != 0 && collections[i] <= collections[i - 1])) {
                revert History.InvalidArtistHistory();
            }
            _activateMultipleLane(s, 2, bytes32(collections[i]), value);
        }
        s.commitment =
            keccak256(abi.encode(s.commitment, uint16(60), U.TAG, artists, collections, value));
    }

    function _activateMultipleLane(History.State storage s, uint8 kind, bytes32 id, bytes32 value)
        private
    {
        bytes32 lane = History.key(kind, id);
        if (!s.verified[lane].done || s.hydrated[lane] != 0 || s.lanes[lane].length != 0) {
            revert History.InvalidArtistHistory();
        }
        s.hydrated[lane] = value;
    }
}
