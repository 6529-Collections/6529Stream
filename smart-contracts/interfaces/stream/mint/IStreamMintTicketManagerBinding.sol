// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev The existing Manager getter is intentionally outside its permanent compatibility ABI.
interface IStreamMintTicketManagerBinding {
    function mintLedger() external view returns (address);
}
