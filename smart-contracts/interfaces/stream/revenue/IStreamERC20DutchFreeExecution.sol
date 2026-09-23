// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPrimarySettlementTypes.sol";

/// @notice A declared-zero Dutch execution has no official payment or settlement result.
interface IStreamERC20DutchFreeExecution {
    function executeERC20DutchFreeMint(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata candidate,
        bytes calldata executionData
    ) external payable returns (bytes4 magic, bytes32 executionId);
}
