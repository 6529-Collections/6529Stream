// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";

import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";

/// @notice Fixed original Identity source validation stage.
library StreamArtistRecoveredIdentitySourceClosures {
    function validate(IH.Bundle calldata b) public pure {
        uint256 expected = b.rotations.length + b.recoveries.length + b.estates.length;
        for (uint256 i; i < b.notices.length; ++i) {
            if (b.notices[i].phase == 3) {
                ++expected;
                _closure(b, b.notices[i].terminal.recordHash);
            }
        }
        if (expected != b.closures.length) revert IH.InvalidRecoveredIdentity(b.artistId);
        for (uint256 i; i < b.rotations.length; ++i) {
            _closure(b, b.rotations[i].record.recordHash);
        }
        for (uint256 i; i < b.recoveries.length; ++i) {
            _closure(b, b.recoveries[i].record.recordHash);
        }
        for (uint256 i; i < b.estates.length; ++i) {
            _closure(b, b.estates[i].request.recordHash);
        }
        for (uint256 i; i < b.closures.length; ++i) {
            D.Closure memory c = b.closures[i].closure;
            if (c.dismissalRecordHash == 0) {
                D.Closure memory empty;
                if (keccak256(abi.encode(c)) != keccak256(abi.encode(empty))) {
                    revert IH.InvalidRecoveredIdentity(b.closures[i].transition);
                }
            } else {
                if (c.artistId != b.artistId || c.transitionRecordHash != b.closures[i].transition) revert IH.InvalidRecoveredIdentity(c.transitionRecordHash);
                bool found;
                for (uint256 j; j < b.dismissals.length; ++j) {
                    if (b.dismissals[j].record.recordHash == c.dismissalRecordHash) found = true;
                }
                if (!found) revert IH.InvalidRecoveredIdentity(c.dismissalRecordHash);
            }
        }
    }

    function _closure(IH.Bundle calldata b, bytes32 key) private pure {
        uint256 found;
        for (uint256 i; i < b.closures.length; ++i) {
            if (b.closures[i].transition == key && key != 0) ++found;
        }
        if (found != 1) revert IH.InvalidRecoveredIdentity(key);
    }
}
