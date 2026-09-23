// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentFullPreservationPolicyViewRetrieval.t.sol";

/// @notice Fresh constructor budgets for measuring the unchanged actual retrieval recipe.
/// @dev Inherits both actual-source cases and both export/continuation entry points unchanged.
/// The 6m/7m/8m nesting is a measurement configuration, not a capacity assertion.
contract StreamCurrentFullPreservationPolicyViewRetrievalFreshBudgetTest is
    StreamCurrentFullPreservationPolicyViewRetrievalTest
{
    function _fullPolicyViewCheckpointServingGas() internal pure override returns (uint32) {
        return 6000000;
    }

    function _viewCompleteRetrievalSourceGas(uint256) internal pure override returns (uint256) {
        return 7000000;
    }
}
