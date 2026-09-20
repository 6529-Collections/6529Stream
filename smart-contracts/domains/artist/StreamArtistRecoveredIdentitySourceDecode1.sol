// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";

import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Complete original Bundle fields 8 through 11, decoded in declaration order.
/// @dev The skipped uint256 head words preserve original ABI offsets and impose no new checks.
library StreamArtistRecoveredIdentitySourceDecode1 {
    function decode(bytes calldata raw, bool withSchema) public pure returns (bytes memory) {
        (
            ,
            IH.SignatureRow[] memory signatures,
            IH.NonceLane[] memory nonces,
            IH.RevisionRow[] memory revisions,
            IH.DelegationRow[] memory delegations
        ) = abi.decode(
            Frame.body(raw, withSchema),
            (uint256[48], IH.SignatureRow[], IH.NonceLane[], IH.RevisionRow[], IH.DelegationRow[])
        );
        return abi.encode(signatures, nonces, revisions, delegations);
    }
}
