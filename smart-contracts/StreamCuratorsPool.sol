// SPDX-License-Identifier: MIT

/**
 *
 *  @title: Stream 6529 Curators Pool
 *  @date: 27-June-2024
 *  @version: 0.3
 *  @author: 6529 team
 */

pragma solidity ^0.8.19;

import "./IStreamAdmins.sol";
import "./MerkleProof.sol";
import "./IDelegationManagementContract.sol";

contract StreamCuratorsPool {

    // variables declaration

    mapping (uint256 => bytes32) public collectionMerkleRoot;
    mapping (uint256 => mapping (address => uint256)) public rewardsPerAddress;
    mapping (uint256 => mapping (address => bool)) public rewardsClaimPerAddress;

    IStreamAdmins adminsContract;
    IDelegationManagementContract dmc;

    modifier FunctionAdminRequired(bytes4 _selector) {
      require(adminsContract.retrieveFunctionAdmin(msg.sender, _selector) == true || adminsContract.retrieveGlobalAdmin(msg.sender) == true , "Not allowed");
      _;
    }

    // events
    event Reward(address indexed _add, uint256 indexed collectionID, uint256 indexed amount);
    event Withdraw(address indexed _add, bool status, uint256 indexed funds);

    constructor(address _adminsContract, address _del) {
        adminsContract = IStreamAdmins(_adminsContract);
        dmc = IDelegationManagementContract(_del);
    }

    // function to set merkle root for each collection
    function setMerkleRoot(uint256 _collectionID, bytes32 _merkleRoot) public FunctionAdminRequired(this.setMerkleRoot.selector) {
        collectionMerkleRoot[_collectionID] = _merkleRoot;
    }

    // function to set merkle root for each drop
    function setMultipleMerkleRoots(uint256[] memory _collectionIDs, bytes32[] memory _merkleRoot) public FunctionAdminRequired(this.setMerkleRoot.selector) {
        for (uint256 i=0; i < _collectionIDs.length; i ++) {
            collectionMerkleRoot[_collectionIDs[i]] = _merkleRoot[i];
        }
    }

    // function to claim rewards
    function claimRewards(uint256 _collectionID, uint256 _amount, bytes32[] calldata merkleProof, address _delegator) public {
        address rewardAddress;
        bytes32 node;
        if (_delegator != 0x0000000000000000000000000000000000000000) {
            bool isAllowedToClaim;
            isAllowedToClaim = dmc.retrieveGlobalStatusOfDelegation(_delegator, 0x8888888888888888888888888888888888888888, msg.sender, 1);
            require(isAllowedToClaim == true, "No delegation");
            node = keccak256(bytes.concat(keccak256((abi.encodePacked(_delegator, _collectionID, _amount)))));
            rewardAddress = _delegator;
        } else {
            node = keccak256(bytes.concat(keccak256((abi.encodePacked(msg.sender, _collectionID, _amount)))));
            rewardAddress = msg.sender;
        }
        require(rewardsClaimPerAddress[_collectionID][rewardAddress] == false, "Rewards Claimed");
        require(MerkleProof.verifyCalldata(merkleProof, collectionMerkleRoot[_collectionID], node), 'invalid proof');
        rewardsPerAddress[_collectionID][rewardAddress] = _amount;
        rewardsClaimPerAddress[_collectionID][rewardAddress] = true;
        (bool success1, ) = payable(rewardAddress).call{value: _amount}("");
        require(success1, "ETH failed");
        emit Reward(rewardAddress, _collectionID, _amount);
    }

    // function to update admin contract
    function updateAdminContracts(address _newContract) public FunctionAdminRequired(this.updateAdminContracts.selector) { 
        require(IStreamAdmins(_newContract).isAdminContract() == true, "Contract is not Admin");
        adminsContract = IStreamAdmins(_newContract);
    }

    // function to withdraw any balance from the smart contract
    function emergencyWithdraw() public FunctionAdminRequired(this.emergencyWithdraw.selector) {
        uint balance = address(this).balance;
        address admin = adminsContract.owner();
        (bool success, ) = payable(admin).call{value: balance}("");
        require(success, "ETH failed");
        emit Withdraw(msg.sender, success, balance);
    }

    receive() external payable {

    }

}