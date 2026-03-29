// SPDX-License-Identifier: MIT

/**
 *
 *  @title: Modified version of NextGen 6529 - Admin Contract to support 6529 Stream
 *  @date: 27-June-2024
 *  @version: 1.1
 *  @author: 6529 team
 */

pragma solidity ^0.8.19;

import "../utils/Ownable.sol";

contract StreamAdmins is Ownable {

    // sets global admins
    mapping(address => bool) public adminPermissions;

    // sets permission on specific function
    mapping (address => mapping (bytes4 => bool)) private functionAdmin;

    // other variables
    address public tdhSigner;

    // certain functions can only be called by the TDHSigner contract
    modifier authorized() {
        require(msg.sender == tdhSigner, "Not Allowed");
        _;
    }

    // constructor
    constructor(address _tdhSigner) {
        tdhSigner = _tdhSigner;
        adminPermissions[tdhSigner] = true;
    }

    // function to register a global admin
    function registerAdmin(address _admin, bool _status) public authorized {
        adminPermissions[_admin] = _status;
    }

    // function to register function admin
    function registerFunctionAdmin(address _address, bytes4 _selector, bool _status) public authorized {
        functionAdmin[_address][_selector] = _status;
    }

    // function to batch register functions admin
    function registerBatchFunctionAdmin(address _address, bytes4[] memory _selector, bool _status) public authorized {
        for (uint256 i=0; i<_selector.length; i++) {
            functionAdmin[_address][_selector[i]] = _status;
        }
    }

    // function to retrieve global admin
    function retrieveGlobalAdmin(address _address) public view returns(bool) {
        return adminPermissions[_address];
    }

    // function to retrieve collection admin
    function retrieveFunctionAdmin(address _address, bytes4 _selector) public view returns(bool) {
        return functionAdmin[_address][_selector];
    }

    // get admin contract status
    function isAdminContract() external view returns (bool) {
        return true;
    }

}
