// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";

import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Complete original Bundle fields 12 through 16, decoded in declaration order.
/// @dev The skipped uint256 head words preserve original ABI offsets and impose no new checks.
library StreamArtistRecoveredIdentitySourceDecode2 {
    function decode(bytes calldata raw, bool withSchema) public pure returns (bytes memory) {
        (
            ,
            IH.GuardianRow[] memory guardians,
            IH.MembershipRow[] memory memberships,
            IH.RotationRow[] memory rotations,
            IH.ContestRow[] memory contests,
            IH.CauseRow[] memory causes
        ) = abi.decode(
            Frame.body(raw, withSchema),
            (
                uint256[52],
                IH.GuardianRow[],
                IH.MembershipRow[],
                IH.RotationRow[],
                IH.ContestRow[],
                IH.CauseRow[]
            )
        );
        return abi.encode(guardians, memberships, rotations, contests, causes);
    }
}
