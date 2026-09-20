// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../revenue/StreamDirectPrimarySaleTypes.sol";

/// @notice Permanent floor evidence for DIRECT products; never a universal settlement projection.
library StreamDirectPrimaryConservationTypes {
    struct Receipt {
        bytes32 receiptHash;
        address adapter;
        bytes32 adapterCodeHash;
        bytes32 directKey;
        bytes32 authorizationId;
        bytes32 originalReceiptHash;
        StreamDirectPrimarySaleTypes.Bindings bindings;
        StreamDirectPrimarySaleTypes.Receipt sale;
        bytes32 effectiveTier;
        bytes32 firstSaleReceiptHash;
        bytes32 releaseReceiptHash;
        uint64 recordedAt;
    }
}
