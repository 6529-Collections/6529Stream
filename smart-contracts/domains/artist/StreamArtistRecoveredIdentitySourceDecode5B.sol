// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";

import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Original grant, estate and dormancy fields in their declaration order.
library StreamArtistRecoveredIdentitySourceDecode5B {
    function decode(bytes calldata raw, bool withSchema) public pure returns (bytes memory) {
        (
            ,
            IH.GrantRow[] memory sanctionGrants,
            IH.EstateRow[] memory estates,
            IH.NoticeRow[] memory notices
        ) = abi.decode(
            Frame.body(raw, withSchema),
            (uint256[66], IH.GrantRow[], IH.EstateRow[], IH.NoticeRow[])
        );
        return abi.encode(sanctionGrants, estates, notices);
    }
}
