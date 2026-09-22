// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact typed calls used by the local export host against its genuinely created Scenario.
/// @dev The preparation() getter remains a raw STATICCALL so its unchanged return bytes are
/// retained without importing the Scenario implementation and its full preparation graph.
interface IStreamCurrentAuthorityPreservationCallerScenario {
    function prepare() external;

    function preparationComplete() external view returns (bool);

    function writerState()
        external
        view
        returns (address writer, address[] memory owners, uint256 threshold, uint256 nonce);
}
