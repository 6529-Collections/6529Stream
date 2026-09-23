// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPrimarySettlementTypes.sol";

/// @notice Positive public Dutch settlement, with mode 2 and no seller authorization digest.
/// @dev Retains the original token candidate, twelve-word result and settlement-key domains.
interface IStreamERC20PublicDutchPrimarySaleSettlement {
    function settleERC20PublicDutchPrimarySaleFromAdapter(
        address paymentAdapter,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata candidate
    ) external returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory);
}
