// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPrimarySettlementTypes.sol";

/// @notice Positive signed Dutch settlement through the closed Dutch producer admission path.
/// @dev Retains the original token candidate, twelve-word result and settlement-key domains.
interface IStreamERC20DutchPrimarySaleSettlement {
    function settleERC20DutchPrimarySaleFromAdapter(
        address paymentAdapter,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata candidate
    ) external returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory);
}
