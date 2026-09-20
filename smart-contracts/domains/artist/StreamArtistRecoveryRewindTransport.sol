// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryRewindOperations as Operations
} from "./StreamArtistRecoveryRewindOperations.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistIdentityRecoveryCoordinatorV3 as Coordinator
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";

/// @dev Closed transport for the two original V3 Coordinator recipes; the host owns the lock.
library StreamArtistRecoveryRewindTransport {
    function execute(D.CoordinatorContext memory context, bytes calldata originalCall)
        public
        returns (bytes32)
    {
        bytes4 selector = bytes4(originalCall[:4]);
        if (selector == Coordinator.coordinateRegisterIdentityRecoveryActionV3.selector) {
            return Operations.prepare(context, originalCall);
        }
        if (selector == Coordinator.coordinateRecoverArtistIdentityV3.selector) {
            return Operations.recoverEncoded(context, originalCall);
        }
        revert T.InvalidBinding();
    }
}
