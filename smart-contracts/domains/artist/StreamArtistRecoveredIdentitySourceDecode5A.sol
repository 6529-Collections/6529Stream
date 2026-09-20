// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";

import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Original designation/directive fields, preceding the remaining estate-family rows.
library StreamArtistRecoveredIdentitySourceDecode5A {
    function decode(bytes calldata raw, bool withSchema) public pure returns (bytes memory) {
        (, IH.DesignationRow[] memory designations, IH.DirectiveRow[] memory directives) = abi.decode(
            Frame.body(raw, withSchema), (uint256[64], IH.DesignationRow[], IH.DirectiveRow[])
        );
        return abi.encode(designations, directives);
    }
}
