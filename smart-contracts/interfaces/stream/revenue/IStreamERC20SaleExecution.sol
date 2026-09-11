// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPrimarySettlementTypes.sol";

/// @notice The sole callback of the first universal, one-token sale execution profile.
interface IStreamERC20SaleExecution {
    function executeERC20PreRevenueSingleStep(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata candidate,
        bytes calldata saleExecutionData
    ) external returns (bytes4 magic, StreamPrimarySettlementTypes.PrimarySettlementResult memory);
}
