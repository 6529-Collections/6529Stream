// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPreparedNativeSettlementTypes.sol";

/// @notice Explicit rights mode for the new paid prepared entry; old PROFILE tuples are unchanged.
library StreamPreparedNativeRightsTypes {
    uint8 internal constant COLLECTION_TEMPLATE = 1;
    /// @dev Explicitly signed positive-share template mode; current low-take consent is mandatory.
    uint8 internal constant CONSENTED_COLLECTION_TEMPLATE = 2;
    /// @dev Symbolic Artist consent plus authenticated sale poster and typed paid collaborators.
    uint8 internal constant DYNAMIC_COLLECTION_TEMPLATE = 3;
    /// @dev Explicit contract-default PROFILE selected under actual resolver precedence.
    uint8 internal constant DEFAULT_PROFILE = 4;

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
