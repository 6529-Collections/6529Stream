// SPDX-License-Identifier: MIT

/**
 *
 *  @title: NextGen 6529 - RNG Randomizer Contract
 *  @date: 20-December-2023
 *  @version: 1.8
 *  @author: 6529 team
 */

pragma solidity ^0.8.19;

import "./ArrngConsumer.sol";
import "./IStreamCore.sol";
import "./IStreamAdmins.sol";
import "./StreamPauseDomains.sol";
import "./StreamRandomizerLifecycle.sol";

contract NextGenRandomizerRNG is ArrngConsumer, StreamRandomizerLifecycle {
    address gencore;
    IStreamCore public gencoreContract;
    IStreamAdmins private adminsContract;
    event Withdraw(address indexed _add, bool status, uint256 indexed funds);
    uint256 ethRequired;
    bool private randomnessRequestInProgress;

    error RandomizerRequestReentrancy();

    constructor(address _gencore, address _adminsContract, address _arRNG) ArrngConsumer(_arRNG) {
        gencore = _gencore;
        gencoreContract = IStreamCore(_gencore);
        adminsContract = IStreamAdmins(_adminsContract);
    }

    modifier FunctionAdminRequired(bytes4 _selector) {
        require(
            adminsContract.retrieveFunctionAdmin(msg.sender, address(this), _selector) == true
                || adminsContract.retrieveGlobalAdmin(msg.sender) == true,
            "Not allowed"
        );
        _;
    }

    // arRNG returns the provider request ID from the external payable call, so
    // recording request state must happen after the call. The local guard blocks
    // reentrant fulfillment during that window and has a regression test.
    // slither-disable-start reentrancy-eth,write-after-write
    function requestRandomWords(uint256 tokenid, uint256 _ethRequired) public payable {
        require(msg.sender == gencore);
        require(
            adminsContract.isPaused(StreamPauseDomains.RANDOMNESS_REQUEST) == false,
            "Randomness paused"
        );
        if (randomnessRequestInProgress) {
            revert RandomizerRequestReentrancy();
        }
        randomnessRequestInProgress = true;
        uint256 collectionId = tokenIdToCollection[tokenid];
        uint256 requestId =
            arrngController.requestRandomWords{ value: _ethRequired }(1, (address(this)));
        randomnessRequestInProgress = false;
        _recordRandomnessRequest(
            requestId, collectionId, tokenid, gencoreContract.viewRandomizerEpoch(collectionId)
        );
    }
    // slither-disable-end reentrancy-eth,write-after-write

    function fulfillRandomWords(uint256 id, uint256[] memory numbers) internal override {
        if (randomnessRequestInProgress) {
            revert RandomizerRequestReentrancy();
        }
        (uint256 collectionId, uint256 tokenId, bytes32 derivedSeed) =
            _fulfillRandomnessRequest(gencoreContract, id, numbers);
        gencoreContract.setTokenHash(collectionId, tokenId, derivedSeed);
    }

    // function that calculates the random hash and returns it to the gencore contract
    function calculateTokenHash(uint256 _collectionID, uint256 _mintIndex, uint256 _saltfun_o)
        public
    {
        require(msg.sender == gencore);
        require(
            adminsContract.isPaused(StreamPauseDomains.RANDOMNESS_REQUEST) == false,
            "Randomness paused"
        );
        tokenIdToCollection[_mintIndex] = _collectionID;
        requestRandomWords(_mintIndex, ethRequired);
    }

    function markStaleRequest(uint256 _requestId)
        public
        FunctionAdminRequired(this.markStaleRequest.selector)
    {
        _markRandomnessRequestStale(_requestId);
    }

    // function to update contracts

    function updateAdminContract(address _newadminsContract)
        public
        FunctionAdminRequired(this.updateAdminContract.selector)
    {
        require(
            IStreamAdmins(_newadminsContract).isAdminContract() == true, "Contract is not Admin"
        );
        adminsContract = IStreamAdmins(_newadminsContract);
    }

    function updateCoreContract(address _gencore)
        public
        FunctionAdminRequired(this.updateCoreContract.selector)
    {
        gencore = _gencore;
        gencoreContract = IStreamCore(_gencore);
    }

    // function to update cost

    function updateRNGCost(uint256 _ethRequired)
        public
        FunctionAdminRequired(this.updateRNGCost.selector)
    {
        ethRequired = _ethRequired;
    }

    function totalRandomnessReserved() public view returns (uint256) {
        return address(this).balance;
    }

    function totalOwed() public view returns (uint256) {
        return totalRandomnessReserved();
    }

    function emergencyWithdrawable() public pure returns (uint256) {
        return 0;
    }

    // function to report the emergency-withdrawal boundary for reserved funds

    function emergencyWithdraw() public FunctionAdminRequired(this.emergencyWithdraw.selector) {
        emit Withdraw(msg.sender, true, emergencyWithdrawable());
    }

    receive() external payable { }

    // get randomizer contract status
    function isRandomizerContract() external view returns (bool) {
        return true;
    }
}
