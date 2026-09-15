// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeSettlementTypes.sol";

/// @notice Structurally separate native-only contract9 settlement entry.
interface IStreamNativePrimarySaleSettlement {
    function settleNativePrimarySaleFromAdapter(
        StreamNativeSettlementTypes.NativeSettlementCandidate calldata candidate
    ) external payable returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory);
}
