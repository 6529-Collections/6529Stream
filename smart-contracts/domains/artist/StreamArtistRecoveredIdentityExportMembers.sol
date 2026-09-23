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
library StreamArtistRecoveredIdentityExportMembers {
    function collect(uint256[17] memory r, bytes calldata canonical)
        public
        view
        returns (bytes memory)
    {
        IH.Bundle calldata b = Frame.bundle(canonical);
        uint256 capacity;
        for (uint256 i; i < b.guardians.length; ++i) {
            capacity += b.guardians[i].record.terms.guardians.length;
        }
        address[] memory keys = new address[](capacity);
        uint256 n;
        for (uint256 i; i < b.guardians.length; ++i) {
            for (uint256 j; j < b.guardians[i].record.terms.guardians.length; ++j) {
                n = _address(keys, n, b.guardians[i].record.terms.guardians[j]);
            }
        }
        IH.MembershipRow[] memory rows = new IH.MembershipRow[](n);
        for (uint256 i; i < n; ++i) {
            rows[i] = IH.MembershipRow(
                keys[i],
                X.recovery(r).guardianHistory.firstMembership[b.artistId][keys[i]],
                X.recovery(r).guardianSupersession.memberships[b.artistId][keys[i]]
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
