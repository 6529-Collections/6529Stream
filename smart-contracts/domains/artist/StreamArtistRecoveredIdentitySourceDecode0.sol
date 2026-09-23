// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredTimingTypes as TM
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Complete original Bundle fields 0 through 7, decoded in declaration order.
/// @dev The skipped uint256 head words preserve original ABI offsets and impose no new checks.
library StreamArtistRecoveredIdentitySourceDecode0 {
    function decode(bytes calldata raw, bool withSchema) public pure returns (bytes memory) {
        (
            bytes32 artistId,
            T.Snapshot memory sourceSnapshot,
            uint256 nextRegistrationNonce,
            T.Identity memory identity,
            bytes memory identityDocument,
            IH.DocumentRow[] memory documents,
            IH.Heads memory heads,
            TM.Bundle memory timing
        ) = abi.decode(
            Frame.body(raw, withSchema),
            (bytes32, T.Snapshot, uint256, T.Identity, bytes, IH.DocumentRow[], IH.Heads, TM.Bundle)
        );
        return abi.encode(
            artistId,
            sourceSnapshot,
            nextRegistrationNonce,
            identity,
            identityDocument,
            documents,
            heads,
            timing
        );
    }
}
