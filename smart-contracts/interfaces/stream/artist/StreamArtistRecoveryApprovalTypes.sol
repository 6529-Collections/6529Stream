// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecoveryTypes as Recovery } from "./StreamArtistRecoveryTypes.sol";
import "../finality/IStreamArtistRecoveryIntent.sol";

/// @notice Admission context kept outside the permanent recovery signature and record preimages.
library StreamArtistRecoveryApprovalTypes {
    struct Request {
        address recoveryRegistry;
        StreamFinalityScope scope;
        Recovery.ApprovalTerms terms;
    }

    /// @notice Immutable observations at approval admission, not a current-readiness cache.
    /// @dev An approval is not action-bound. The companion separately snapshots it for execution.
    struct Admission {
        StreamFinalityScope scope;
        address recoveryRegistry;
        bytes32 recoveryRegistryCodeHash;
        bytes32 originalFinalityCodeHash;
        IStreamArtistRecoveryIntent.Facts intent;
    }
}
