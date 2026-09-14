// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPreparedNativeSettlementTypes.sol";

/// @notice Explicit rights mode for the new paid prepared entry; old PROFILE tuples are unchanged.
library StreamPreparedNativeRightsTypes {
    uint8 internal constant COLLECTION_TEMPLATE = 1;

    /// @dev Signed at auction opening, before any sequential token identity exists.
    /// ALLOW_CURRENT retains this evidence without requiring the current assignment to equal it.
    struct OriginalPolicy {
        uint8 mode;
        bytes32 assignmentHash;
        bytes32 templateId;
    }

    struct Intent {
        StreamPreparedNativeSettlementTypes.Intent sale;
        OriginalPolicy original;
    }

    /// @dev Only the currently executing Manager constructs these facts after actual preparation.
    struct Facts {
        StreamPreparedNativeSettlementTypes.Facts mint;
        OriginalPolicy original;
    }
}
