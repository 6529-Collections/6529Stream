// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityPreservationCallerPreparationFixture
} from "../helpers/StreamCurrentAuthorityPreservationCallerPreparationFixture.sol";

/// @notice Genuine collection and scoped preparation before client-produced publication calls.
/// @dev This setup test supplies no mined receipt, client calldata or state-export acceptance.
contract StreamCurrentAuthorityPreservationCallerPreparationTest is
    StreamCurrentAuthorityPreservationCallerPreparationFixture
{
    function testPrepareCollectionAndScopedGraphsWithFourRealTokensForGrantedSafe() public {
        _preparePreservationCallers();
    }
}
