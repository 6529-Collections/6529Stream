// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IStreamRecoveredEconomicsDelegation {
    function recordDelegation(bytes32 record) external view returns (bytes32);
}
