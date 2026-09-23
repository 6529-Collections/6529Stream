// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

import {
    IStreamArtistRecoveredHydrationOwner as Source
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";

import {
    StreamArtistRecoveredIdentityHydrationState as X
} from "./StreamArtistRecoveredIdentityHydrationState.sol";

import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Fixed Identity export stage in the original owner storage context.
library StreamArtistRecoveredIdentityExportVestings {
    bytes32 private constant VESTING = keccak256("identity_authority.hydration.guardian_vesting");

    function collect(uint256[17] memory r, bytes calldata canonical, RH.OwnerProvenance memory p)
        public
        view
        returns (bytes memory)
    {
        IH.Bundle calldata b = Frame.bundle(canonical);
        bytes32 cursor = b.heads.latestVesting;
        uint256 count;
        while (cursor != 0) {
            if (++count > p.journal.length) revert IH.InvalidRecoveredIdentity(cursor);
            cursor = X.recovery(r).vestingHistory.snapshots[cursor].previousTransitionRecordHash;
        }
        IH.VestingRow[] memory rows = new IH.VestingRow[](count);
        cursor = b.heads.latestVesting;
        while (cursor != 0) {
            IH.VestingRow memory row;
            row.snapshot = X.recovery(r).vestingHistory.snapshots[cursor];
            if (row.snapshot.transitionRecordHash != cursor || row.snapshot.artistId != b.artistId)
            {
                revert IH.InvalidRecoveredIdentity(cursor);
            }
            row.point = Source(address(this)).recoveredHydrationAuxiliaryPoint(VESTING, cursor);
            rows[--count] = row;
            cursor = row.snapshot.previousTransitionRecordHash;
        }
        return abi.encode(rows);
    }

    function _address(address[] memory keys, uint256 n, address value)
        private
        pure
        returns (uint256)
    {
        if (value == address(0)) revert IH.InvalidRecoveredIdentity(bytes32(0));
        uint256 at;
        while (at < n && keys[at] < value) ++at;
        if (at < n && keys[at] == value) return n;
        for (uint256 j = n; j > at; --j) {
            keys[j] = keys[j - 1];
        }
        keys[at] = value;
        return n + 1;
    }
}
