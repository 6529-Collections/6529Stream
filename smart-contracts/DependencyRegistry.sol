// SPDX-License-Identifier: MIT

/**
 *
 *  @title: NextGen 6529 - Dependency Registry Contract
 *  @date: 29-January-2023
 *  @version: 1.1
 *  @author: 6529 team
 */

pragma solidity ^0.8.19;

import "./IStreamAdmins.sol";

contract DependencyRegistry {

    // struct that holds a collection's info
    struct dependencyInfoStructure {
        bytes32 _collectionDependencyName;
        string[] libraryScript;
    }

    // mapping of collectionInfo struct
    mapping (bytes32 => dependencyInfoStructure) private dependencyInfo;

    IStreamAdmins private adminsContract;

    // certain functions can only be called by a global or function admin

    modifier FunctionAdminRequired(bytes4 _selector) {
      require(adminsContract.retrieveFunctionAdmin(msg.sender, _selector) == true || adminsContract.retrieveGlobalAdmin(msg.sender) == true , "Not allowed");
      _;
    }

    // constructor
    constructor(address _adminsContract) {
        adminsContract = IStreamAdmins(_adminsContract);
    }

    function addDependency(bytes32 _collectionDependencyName, string[] memory _libraryScript) public FunctionAdminRequired(this.addDependency.selector) {
        dependencyInfo[_collectionDependencyName]._collectionDependencyName = _collectionDependencyName;
        dependencyInfo[_collectionDependencyName].libraryScript = _libraryScript;
    }

    function addDependencyScriptIndex(bytes32 _collectionDependencyName, uint256 index, string memory _libraryScript) public FunctionAdminRequired(this.addDependencyScriptIndex.selector) {
        dependencyInfo[_collectionDependencyName].libraryScript[index] = _libraryScript;
    }

    // function to update admin contract

    function updateAdminContract(address _newadminsContract) public FunctionAdminRequired(this.updateAdminContract.selector) {
        require(IStreamAdmins(_newadminsContract).isAdminContract() == true, "Contract is not Admin");
        adminsContract = IStreamAdmins(_newadminsContract);
    }

    function getDependencyScriptCount(bytes32 dependencyNameAndVersion) external view returns (uint256) {
        return (dependencyInfo[dependencyNameAndVersion].libraryScript.length);
    }

    function getDependencyScript(bytes32 dependencyNameAndVersion, uint256 index) external view returns (string memory){
        return (dependencyInfo[dependencyNameAndVersion].libraryScript[index]);
    }

}