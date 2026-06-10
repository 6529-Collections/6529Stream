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
    bytes32 public constant DEPENDENCY_SCRIPT_CONTENT_TYPEHASH = keccak256(
        "6529StreamDependencyScript(bytes32 dependencyNameAndVersion,uint256 chunkCount,bytes32 chunksHash)"
    );
    bytes32 public constant DEPENDENCY_SCRIPT_CHUNK_TYPEHASH = keccak256(
        "6529StreamDependencyScriptChunk(uint256 index,bytes32 chunkHash,uint256 byteLength)"
    );

    // struct that holds a collection's info
    struct dependencyInfoStructure {
        bytes32 _collectionDependencyName;
        string[] libraryScript;
    }

    // mapping of collectionInfo struct
    mapping(bytes32 => dependencyInfoStructure) private dependencyInfo;

    IStreamAdmins private adminsContract;

    // certain functions can only be called by a global or function admin

    modifier FunctionAdminRequired(bytes4 _selector) {
        require(
            adminsContract.retrieveFunctionAdmin(msg.sender, address(this), _selector) == true
                || adminsContract.retrieveGlobalAdmin(msg.sender) == true,
            "Not allowed"
        );
        _;
    }

    // constructor
    constructor(address _adminsContract) {
        adminsContract = IStreamAdmins(_adminsContract);
    }

    function addDependency(bytes32 _collectionDependencyName, string[] memory _libraryScript)
        public
        FunctionAdminRequired(this.addDependency.selector)
    {
        dependencyInfo[_collectionDependencyName]._collectionDependencyName =
        _collectionDependencyName;
        dependencyInfo[_collectionDependencyName].libraryScript = _libraryScript;
    }

    function addDependencyScriptIndex(
        bytes32 _collectionDependencyName,
        uint256 index,
        string memory _libraryScript
    ) public FunctionAdminRequired(this.addDependencyScriptIndex.selector) {
        dependencyInfo[_collectionDependencyName].libraryScript[index] = _libraryScript;
    }

    // function to update admin contract

    function updateAdminContract(address _newadminsContract)
        public
        FunctionAdminRequired(this.updateAdminContract.selector)
    {
        require(
            IStreamAdmins(_newadminsContract).isAdminContract() == true, "Contract is not Admin"
        );
        adminsContract = IStreamAdmins(_newadminsContract);
    }

    function getDependencyScriptCount(bytes32 dependencyNameAndVersion)
        external
        view
        returns (uint256)
    {
        return (dependencyInfo[dependencyNameAndVersion].libraryScript.length);
    }

    function getDependencyScript(bytes32 dependencyNameAndVersion, uint256 index)
        external
        view
        returns (string memory)
    {
        return (dependencyInfo[dependencyNameAndVersion].libraryScript[index]);
    }

    function getDependencyScriptChunkHash(bytes32 dependencyNameAndVersion, uint256 index)
        public
        view
        returns (bytes32)
    {
        return _hashDependencyScriptChunk(
            index, dependencyInfo[dependencyNameAndVersion].libraryScript[index]
        );
    }

    function getDependencyScriptContentHash(bytes32 dependencyNameAndVersion)
        external
        view
        returns (bytes32)
    {
        uint256 chunkCount = dependencyInfo[dependencyNameAndVersion].libraryScript.length;
        bytes32 chunksHash = bytes32(0);

        for (uint256 i = 0; i < chunkCount; i++) {
            chunksHash = keccak256(
                abi.encode(chunksHash, getDependencyScriptChunkHash(dependencyNameAndVersion, i))
            );
        }

        return keccak256(
            abi.encode(
                DEPENDENCY_SCRIPT_CONTENT_TYPEHASH, dependencyNameAndVersion, chunkCount, chunksHash
            )
        );
    }

    function _hashDependencyScriptChunk(uint256 index, string memory chunk)
        private
        pure
        returns (bytes32)
    {
        bytes memory chunkBytes = bytes(chunk);
        return keccak256(
            abi.encode(
                DEPENDENCY_SCRIPT_CHUNK_TYPEHASH, index, keccak256(chunkBytes), chunkBytes.length
            )
        );
    }
}
