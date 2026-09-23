// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";

import {
    StreamArtistRecoveredIdentityHydrationState as X
} from "./StreamArtistRecoveredIdentityHydrationState.sol";

import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Fixed Identity export stage in the original owner storage context.
library StreamArtistRecoveredIdentityExportStanding {
    function collect(uint256[17] memory r, bytes calldata canonical)
        public
        view
        returns (bytes memory)
    {
        IH.Bundle calldata b = Frame.bundle(canonical);
        address[] memory keys = new address[](b.vestings.length + b.standingRecords.length);
        uint256 n;
        for (uint256 i; i < b.vestings.length; ++i) {
            n = _address(keys, n, b.vestings[i].snapshot.oldAddress);
        }
        for (uint256 i; i < b.standingRecords.length; ++i) {
            n = _address(keys, n, b.standingRecords[i].record.terms.revokedAddress);
        }
        IH.StandingRow[] memory rows = new IH.StandingRow[](n);
        for (uint256 i; i < n; ++i) {
            rows[i] = IH.StandingRow(
                keys[i],
                X.rotations(r).retirement[b.artistId][keys[i]],
                X.rotations(r).standingRevocation[b.artistId][keys[i]],
                X.resolutions(r).standingJudgments[b.artistId][keys[i]]
            );
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
