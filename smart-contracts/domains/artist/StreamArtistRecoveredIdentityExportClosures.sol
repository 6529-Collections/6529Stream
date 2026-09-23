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
library StreamArtistRecoveredIdentityExportClosures {
    function collect(uint256[17] memory r, bytes calldata canonical)
        public
        view
        returns (bytes memory)
    {
        IH.Bundle calldata b = Frame.bundle(canonical);
        uint256 n = b.rotations.length + b.estates.length + b.recoveries.length;
        for (uint256 i; i < b.notices.length; ++i) {
            if (b.notices[i].phase == 3) ++n;
        }
        IH.ClosureRow[] memory rows = new IH.ClosureRow[](n);
        uint256 at;
        for (uint256 i; i < b.rotations.length; ++i) {
            rows[at++] = IH.ClosureRow(
                b.rotations[i].record.recordHash,
                X.resolutions(r).closures[b.rotations[i].record.recordHash]
            );
        }
        for (uint256 i; i < b.estates.length; ++i) {
            rows[at++] = IH.ClosureRow(
                b.estates[i].request.recordHash,
                X.resolutions(r).closures[b.estates[i].request.recordHash]
            );
        }
        for (uint256 i; i < b.recoveries.length; ++i) {
            rows[at++] = IH.ClosureRow(
                b.recoveries[i].record.recordHash,
                X.resolutions(r).closures[b.recoveries[i].record.recordHash]
            );
        }
        for (uint256 i; i < b.notices.length; ++i) {
            if (b.notices[i].phase == 3) {
                rows[at++] = IH.ClosureRow(
                    b.notices[i].terminal.recordHash,
                    X.resolutions(r).closures[b.notices[i].terminal.recordHash]
                );
            }
        }
        return abi.encode(rows);
    }
}
