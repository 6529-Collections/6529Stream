// SPDX-License-Identifier: MIT

/**
 *
 *  @title: Drops Contract for 6529 stream
 *  @date: 28-June-2024
 *  @version: 0.9
 *  @author: 6529 team
 */

pragma solidity ^0.8.19;

import "./IStreamMinter.sol";
import "./Ownable.sol";
import "./Strings.sol";
import "./IStreamAdmins.sol";

contract StreamDrops is Ownable {

    using Strings for uint256;
    using Strings for address;

    // struct that holds a drop's info
    struct dropInfoStruct {
        uint256 tokenid;
        address signerAddress;
        address posterAddress;
        address executionAddress;
    }

    // mapping of dropInfo struct
    mapping (bytes32 => dropInfoStruct) private dropInfo;

    // other variables
    IStreamMinter public minterContract;
    IStreamAdmins public adminsContract;
    address public tdhSigner;
    mapping (bytes32 => bool) dropExecuted;
    mapping (uint256 => address) posterAuctionAddress;
    mapping (uint256 => uint256) auctionPrice;
    mapping (uint256 => bytes32) tokenDropID;
    bytes32[] public allDrops;
    address public payOutAddress;
    address public curatorsPoolAddress;
    uint256 public tdhThreshold;
    uint256 public activeTime;

    // certain functions can only be called by a global or function admin
    modifier FunctionAdminRequired(bytes4 _selector) {
      require(adminsContract.retrieveFunctionAdmin(msg.sender, _selector) == true || adminsContract.retrieveGlobalAdmin(msg.sender) == true , "Not allowed");
      _;
    }

    // modifiers
    modifier authorized() {
        require(msg.sender == tdhSigner, "Not Allowed");
        _;
    }

    // constructor
    constructor(address _tdhSignerContract, address _minterContract, address _adminsContract, address _payOutAddress, address _curatorsPoolAddress) {
        tdhSigner = _tdhSignerContract;
        minterContract = IStreamMinter(_minterContract);
        adminsContract = IStreamAdmins(_adminsContract);
        payOutAddress = _payOutAddress;
        curatorsPoolAddress = _curatorsPoolAddress;
    }

    // mint a drop
    // opt = 1 --> Fixed price
    // opt = 2 --> Auction
    function mintDrop(address _poster, string memory _tokenData, uint256 _collectionID, uint256 _opt, uint256 _price, uint256 _endDate) public payable authorized {
        bytes32 dropId = keccak256(abi.encodePacked(string(abi.encodePacked(Strings.toHexString(uint256(uint160(_poster)), 20), _tokenData, _collectionID.toString(), _opt.toString(), _price.toString(), _endDate.toString()))));
        require(dropExecuted[dropId] == false, "Drop Executed");
        dropExecuted[dropId] = true;
        uint256 tokenid;
        address poster = _poster;
        string memory tokData = _tokenData;
        uint256 colID = _collectionID;
        if (_opt == 1) {
            require(msg.value == _price, "price");
            uint256[] memory salt = new uint256[](1);
            uint256[] memory num = new uint256[](1);
            string[] memory tokenData = new string[](1);
            address[] memory receiver = new address[](1);
            receiver[0] = tx.origin;
            salt[0] = 0;
            num[0] = 1;
            tokenData[0] = tokData;
            (bool success1, ) = payable(poster).call{value: (msg.value / 2)}("");
            (bool success2, ) = payable(payOutAddress).call{value: (msg.value / 4)}("");
            (bool success3, ) = payable(curatorsPoolAddress).call{value: (msg.value / 4)}("");
            require(success1, "ETH failed");
            require(success2, "ETH failed");
            require(success3, "ETH failed");
            tokenid = minterContract.mint(receiver, tokenData, salt, colID, num);
        } else if (_opt == 2) {
            tokenid = minterContract.mintAndAuction(payOutAddress, tokData, 0, colID, _endDate);
            posterAuctionAddress[tokenid] = poster;
            auctionPrice[tokenid] = _price;
        } else {
            revert("Not found");
        }
        tokenDropID[tokenid] = dropId;
        dropInfo[dropId].tokenid = tokenid;
        dropInfo[dropId].signerAddress = tdhSigner;
        dropInfo[dropId].posterAddress = poster;
        dropInfo[dropId].executionAddress = tx.origin;
        allDrops.push(dropId);
    }

    // Update signer contract address
    function updateTDHsigner(address _tsigner) public FunctionAdminRequired(this.updateTDHsigner.selector) {
        tdhSigner = _tsigner;
    }

    // update payout address
    function updatePayOutAddress(address _payOutAddress) public FunctionAdminRequired(this.updatePayOutAddress.selector) {
        payOutAddress = _payOutAddress;
    }

    // update curators pool address
    function updateCuratorsPoolAddress(address _curatorsPoolAddress) public FunctionAdminRequired(this.updateCuratorsPoolAddress.selector) {
        curatorsPoolAddress = _curatorsPoolAddress;
    }

    // function to update admin contract
    function updateAdminContract(address _newContract) public FunctionAdminRequired(this.updateAdminContract.selector) {
        require(IStreamAdmins(_newContract).isAdminContract() == true, "Contract is not Admin");
        adminsContract = IStreamAdmins(_newContract);
    }

    // function to update admin contract
    function updateMinterContract(address _newContract) public FunctionAdminRequired(this.updateMinterContract.selector) {
        require(IStreamMinter(_newContract).isMinterContract() == true, "Contract is not Admin");
        minterContract = IStreamMinter(_newContract);
    }

    // retrieve executed drops
    function retrieveDrops() public view returns (bytes32[] memory) {
        return (allDrops);
    }

    // retrieve auction poster address given a token id
    function retrieveAuctionPoster(uint256 _tokenid) public view returns(address) {
        return posterAuctionAddress[_tokenid];
    }

    // retrieve auction starting price given a token id
    function retrieveAuctionPrice(uint256 _tokenid) public view returns(uint256) {
        return auctionPrice[_tokenid];
    }

    // retrieve drop info
    function retrieveDropInfo(bytes32 _dropId) public view returns(uint256, address, address, address) {
        return (dropInfo[_dropId].tokenid, dropInfo[_dropId].signerAddress, dropInfo[_dropId].posterAddress, dropInfo[_dropId].executionAddress);
    }

    // retrieve token id given a drop id
    function retrieveTokenID(bytes32 _dropId) public view returns(uint256) {
        return (dropInfo[_dropId].tokenid);
    }

    // retrieve drop id given a token id
    function retrieveDropID(uint256 _tokenid) public view returns(bytes32) {
        return tokenDropID[_tokenid];
    }

    // retrieve execution address 
    function retrieveExecutionAddress(uint256 _tokenid) public view returns(address) {
        return dropInfo[retrieveDropID(_tokenid)].executionAddress;
    }

    // retrieve message and hashed message (drop id)
    function retrieveMessageAndDropID(address _poster, string memory _tokenData, uint256 _collectionID, uint256 _opt, uint256 _price, uint256 _endDate) public pure returns(string memory, bytes32) {
        string memory message = string(abi.encodePacked(Strings.toHexString(uint256(uint160(_poster)), 20), _tokenData, _collectionID.toString(), _opt.toString(), _price.toString(), _endDate.toString()));
        bytes32 hashedMessage = keccak256(abi.encodePacked(message));
        return (message, hashedMessage);
    }

}