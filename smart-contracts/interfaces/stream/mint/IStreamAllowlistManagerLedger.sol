// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev Existing public getter outside Manager's retained compatibility interface.
interface IStreamAllowlistManagerLedger {
    function mintLedger() external view returns (address);
}
