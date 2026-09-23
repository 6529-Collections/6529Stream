// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";

import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Complete original Bundle fields 17 through 22, decoded in declaration order.
/// @dev The skipped uint256 head words preserve original ABI offsets and impose no new checks.
library StreamArtistRecoveredIdentitySourceDecode3 {
    function decode(bytes calldata raw, bool withSchema) public pure returns (bytes memory) {
        (
            ,
            IH.DismissalRow[] memory dismissals,
            IH.ClosureRow[] memory closures,
            IH.StandingRow[] memory standing,
            IH.StandingRecordRow[] memory standingRecords,
            IH.RecoveryRow[] memory recoveries,
            IH.VestingRow[] memory vestings
        ) = abi.decode(
            Frame.body(raw, withSchema),
            (
                uint256[57],
                IH.DismissalRow[],
                IH.ClosureRow[],
                IH.StandingRow[],
                IH.StandingRecordRow[],
                IH.RecoveryRow[],
                IH.VestingRow[]
            )
        );
        return abi.encode(dismissals, closures, standing, standingRecords, recoveries, vestings);
    }
}
