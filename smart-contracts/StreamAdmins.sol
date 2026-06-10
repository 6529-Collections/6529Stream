// SPDX-License-Identifier: MIT

/**
 *
 *  @title: Modified version of NextGen 6529 - Admin Contract to support 6529 Stream
 *  @date: 27-June-2024
 *  @version: 1.1
 *  @author: 6529 team
 */

pragma solidity ^0.8.19;

import "./Ownable.sol";

contract StreamAdmins is Ownable {
    // sets global admins
    mapping(address => bool) public adminPermissions;

    // sets permission on a specific target contract function
    mapping(address => mapping(address => mapping(bytes4 => bool))) private functionAdmin;

    // other variables
    address public tdhSigner;

    event GlobalAdminUpdated(address indexed account, bool enabled, address indexed admin);
    event FunctionAdminUpdated(
        address indexed account,
        address indexed target,
        bytes4 indexed selector,
        bool enabled,
        address admin
    );

    // certain functions can only be called by the TDHSigner contract or owner root
    modifier authorized() {
        require(msg.sender == tdhSigner || msg.sender == owner(), "Not Allowed");
        _;
    }

    // constructor
    constructor(address _tdhSigner) {
        require(_tdhSigner != address(0), "Zero tdh signer");
        tdhSigner = _tdhSigner;
        // The signer starts as a global admin for compatibility, but registrar
        // authority follows `authorized()` and is independent of this bypass.
        adminPermissions[tdhSigner] = true;
    }

    // function to register a global admin
    function registerAdmin(address _admin, bool _status) public authorized {
        require(_admin != address(0), "Zero admin");
        adminPermissions[_admin] = _status;
        emit GlobalAdminUpdated(_admin, _status, msg.sender);
    }

    // function to register function admin
    function registerFunctionAdmin(
        address _address,
        address _target,
        bytes4 _selector,
        bool _status
    ) public authorized {
        _setFunctionAdmin(_address, _target, _selector, _status);
    }

    // function to batch register functions admin
    function registerBatchFunctionAdmin(
        address _address,
        address _target,
        bytes4[] memory _selector,
        bool _status
    ) public authorized {
        for (uint256 i = 0; i < _selector.length; i++) {
            _setFunctionAdmin(_address, _target, _selector[i], _status);
        }
    }

    // function to retrieve global admin
    function retrieveGlobalAdmin(address _address) public view returns (bool) {
        return adminPermissions[_address];
    }

    // function to retrieve function admin
    function retrieveFunctionAdmin(address _address, address _target, bytes4 _selector)
        public
        view
        returns (bool)
    {
        return functionAdmin[_address][_target][_selector];
    }

    // collection-admin support is intentionally deferred for P0-ADMIN-001
    function retrieveCollectionAdmin(address, uint256) public pure returns (bool) {
        return false;
    }

    // get admin contract status
    function isAdminContract() external pure returns (bool) {
        return true;
    }

    function _setFunctionAdmin(address _address, address _target, bytes4 _selector, bool _status)
        private
    {
        require(_address != address(0), "Zero admin");
        require(_target != address(0), "Zero target");
        require(_selector != bytes4(0), "Zero selector");
        functionAdmin[_address][_target][_selector] = _status;
        emit FunctionAdminUpdated(_address, _target, _selector, _status, msg.sender);
    }
}
