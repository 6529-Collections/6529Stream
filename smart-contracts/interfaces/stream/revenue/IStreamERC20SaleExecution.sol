// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPrimarySettlementTypes.sol";

/// @notice The sole callback of the first universal, one-token sale execution profile.
/// @dev The authenticated payment adapter forwards only the bound executor's native allowance.
///      Shared ABI payability does not grant native-fee support to every sale profile.
///      Profiles without such support must reject nonzero value before sale effects.
interface IStreamERC20SaleExecution {
    function executeERC20PreRevenueSingleStep(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata candidate,
        bytes calldata saleExecutionData
    ) external payable returns (bytes4 magic, StreamPrimarySettlementTypes.PrimarySettlementResult memory);
}
