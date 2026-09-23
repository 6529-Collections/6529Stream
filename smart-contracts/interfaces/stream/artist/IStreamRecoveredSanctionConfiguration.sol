// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IStreamRecoveredSanctionConfiguration {
    function configurationHash() external view returns (bytes32);
}
