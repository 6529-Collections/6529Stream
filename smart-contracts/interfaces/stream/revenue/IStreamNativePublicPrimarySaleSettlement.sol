// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeSettlementTypes.sol";

/// @notice Native public-record settlement; mode 2 with no seller authorization digest.
/// @dev Retains the original native candidate, result and settlement-key domains.
interface IStreamNativePublicPrimarySaleSettlement {
    function settleNativePublicPrimarySaleFromAdapter(
        StreamNativeSettlementTypes.NativeSettlementCandidate calldata candidate
    ) external payable returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory);
}
