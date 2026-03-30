// SPDX-License-Identifier: MIT
//
// =============================================================================
// INextGenAdmins — ELI5
// =============================================================================
// Same idea as IStreamAdmins: admin checks + owner, for NextGen-named randomizers.
// =============================================================================

pragma solidity ^0.8.19;

interface INextGenAdmins {
    function retrieveFunctionAdmin(address _address, bytes4 _selector) external view returns (bool);
    function retrieveGlobalAdmin(address _address) external view returns (bool);
    function owner() external view returns (address);
    function isAdminContract() external view returns (bool);
}
