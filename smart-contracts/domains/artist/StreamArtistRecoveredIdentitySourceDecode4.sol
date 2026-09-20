// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";

import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Complete original Bundle fields 23 through 23, decoded in declaration order.
/// @dev The skipped uint256 head words preserve original ABI offsets and impose no new checks.
library StreamArtistRecoveredIdentitySourceDecode4 {
    function decode(bytes calldata raw, bool withSchema) public pure returns (bytes memory) {
        (, IH.ActionRow[] memory actions) =
            abi.decode(Frame.body(raw, withSchema), (uint256[63], IH.ActionRow[]));
        return abi.encode(actions);
    }
}
