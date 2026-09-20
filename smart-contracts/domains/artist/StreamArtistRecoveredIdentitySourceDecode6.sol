// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";

import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Complete original Bundle fields 29 through 29, decoded in declaration order.
/// @dev The skipped uint256 head words preserve original ABI offsets and impose no new checks.
library StreamArtistRecoveredIdentitySourceDecode6 {
    function decode(bytes calldata raw, bool withSchema) public pure returns (bytes memory) {
        (, IH.FindingRow[] memory findings) =
            abi.decode(Frame.body(raw, withSchema), (uint256[69], IH.FindingRow[]));
        return abi.encode(findings);
    }
}
