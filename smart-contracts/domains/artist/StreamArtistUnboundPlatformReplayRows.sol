// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice Fixed replay-alias checks for unbound Platform collection imports.
library StreamArtistUnboundPlatformReplayRows {
    function validate(
        RH.OwnerProvenance memory p,
        RH.JournalEntry memory j,
        bytes32 surface,
        bytes32 scope,
        bytes32 record
    ) public pure {
        uint256 start = era(p, j.position.point.environmentHash);
        bytes32 actualScope = scope;
        for (uint256 e = start; e < p.eras.length; ++e) {
            uint256 matches;
            for (uint256 i; i < p.aliases.length; ++i) {
                RH.ReplayAlias memory a = p.aliases[i];
                if (
                    a.originHash != p.eras[e].originHash || a.surface != surface
                        || a.cell.commitment != record
                ) continue;
                if (actualScope == 0) actualScope = a.scope;
                if (
                    a.scope == 0 || a.scope != actualScope || a.cell.kind != 1 || a.cell.status != 2
                        || keccak256(abi.encode(a.admittedAt))
                            != keccak256(abi.encode(j.position.point))
                ) _invalid();
                ++matches;
            }
            if (matches != 1) _invalid();
        }
    }

    function era(RH.OwnerProvenance memory p, bytes32 origin) private pure returns (uint256) {
        for (uint256 i; i < p.eras.length; ++i) {
            if (p.eras[i].originHash == origin) return i;
        }
        _invalid();
        return 0;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
