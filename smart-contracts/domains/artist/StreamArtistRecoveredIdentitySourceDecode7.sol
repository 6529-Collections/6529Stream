// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";

import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Complete original Bundle fields 30 through 33, decoded in declaration order.
/// @dev The skipped uint256 head words preserve original ABI offsets and impose no new checks.
library StreamArtistRecoveredIdentitySourceDecode7 {
    function decode(bytes calldata raw, bool withSchema) public pure returns (bytes memory) {
        (
            ,
            IH.OriginalContinuationRow[] memory originalContinuations,
            IH.RevisionContinuationRow[] memory revisionContinuations,
            IH.StandingContinuationRow[] memory standingContinuations,
            IH.CapabilityContinuationRow[] memory capabilityContinuations
        ) = abi.decode(
            Frame.body(raw, withSchema),
            (
                uint256[70],
                IH.OriginalContinuationRow[],
                IH.RevisionContinuationRow[],
                IH.StandingContinuationRow[],
                IH.CapabilityContinuationRow[]
            )
        );
        return abi.encode(
            originalContinuations,
            revisionContinuations,
            standingContinuations,
            capabilityContinuations
        );
    }
}
