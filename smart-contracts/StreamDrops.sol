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
import "./IStreamAdmins.sol";

contract StreamDrops is Ownable {
    uint8 public constant SALE_MODE_FIXED_PRICE = 1;
    uint8 public constant SALE_MODE_AUCTION = 2;
    string public constant EIP712_NAME = "6529StreamDrops";
    string public constant EIP712_VERSION = "1";
    bytes32 public constant EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 public constant DROP_ID_TYPEHASH =
        keccak256("DropId(address signer,uint256 signerEpoch,uint256 nonce,uint256 salt)");
    bytes32 public constant DROP_AUTHORIZATION_TYPEHASH = keccak256(
        "DropAuthorization(bytes32 dropId,address poster,address recipient,address payer,uint256 collectionId,uint8 saleMode,bytes32 tokenDataHash,uint256 price,uint256 quantity,uint256 auctionReservePrice,uint256 auctionEndTime,uint256 salt,uint256 nonce,uint256 deadline,uint256 signerEpoch)"
    );

    bytes32 private constant EIP2098_S_MASK =
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    uint256 private constant SECP256K1_N_DIV_2 =
        0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;

    struct DropAuthorization {
        bytes32 dropId;
        address poster;
        address recipient;
        address payer;
        uint256 collectionId;
        uint8 saleMode;
        bytes32 tokenDataHash;
        uint256 price;
        uint256 quantity;
        uint256 auctionReservePrice;
        uint256 auctionEndTime;
        uint256 salt;
        uint256 nonce;
        uint256 deadline;
        uint256 signerEpoch;
    }

    // struct that holds a drop's info
    struct dropInfoStruct {
        uint256 tokenid;
        address signerAddress;
        address posterAddress;
        address executionAddress;
    }

    // mapping of dropInfo struct
    mapping(bytes32 => dropInfoStruct) private dropInfo;

    // other variables
    IStreamMinter public minterContract;
    IStreamAdmins public adminsContract;
    address public tdhSigner;
    uint256 public signerEpoch;
    mapping(bytes32 => bool) private consumedDropIds;
    mapping(bytes32 => bool) private cancelledDropIds;
    mapping(uint256 => address) posterAuctionAddress;
    mapping(uint256 => uint256) auctionPrice;
    mapping(uint256 => bytes32) tokenDropID;
    bytes32[] public allDrops;
    address public payOutAddress;
    address public curatorsPoolAddress;
    uint256 public tdhThreshold;
    uint256 public activeTime;

    event DropAuthorizationConsumed(
        bytes32 indexed dropId,
        address indexed signer,
        address indexed poster,
        address recipient,
        address payer,
        uint256 collectionId,
        uint8 saleMode,
        bytes32 tokenDataHash,
        uint256 deadline,
        uint256 signerEpoch
    );
    event DropAuthorizationCancelled(bytes32 indexed dropId, address indexed admin);
    event SignerEpochChanged(uint256 indexed oldEpoch, uint256 indexed newEpoch);
    event DropSignerChanged(
        address indexed oldSigner, address indexed newSigner, uint256 indexed signerEpoch
    );

    // certain functions can only be called by a global or function admin
    modifier FunctionAdminRequired(bytes4 _selector) {
        require(
            adminsContract.retrieveFunctionAdmin(msg.sender, _selector) == true
                || adminsContract.retrieveGlobalAdmin(msg.sender) == true,
            "Not allowed"
        );
        _;
    }

    // constructor
    constructor(
        address _tdhSignerContract,
        address _minterContract,
        address _adminsContract,
        address _payOutAddress,
        address _curatorsPoolAddress
    ) {
        require(_tdhSignerContract != address(0), "Zero signer");
        tdhSigner = _tdhSignerContract;
        signerEpoch = 1;
        minterContract = IStreamMinter(_minterContract);
        adminsContract = IStreamAdmins(_adminsContract);
        payOutAddress = _payOutAddress;
        curatorsPoolAddress = _curatorsPoolAddress;
    }

    // mint a drop
    // opt = 1 --> Fixed price
    // opt = 2 --> Auction
    function mintDrop(
        DropAuthorization calldata _authorization,
        string calldata _tokenData,
        bytes calldata _signature
    ) public payable {
        require(tdhSigner.code.length == 0, "ERC1271 pending");
        bytes32 digest = hashDropAuthorization(_authorization);
        address signer = _recoverEOASigner(digest, _signature);
        _validateAuthorization(_authorization, signer, _tokenData);

        bytes32 dropId = _authorization.dropId;
        consumedDropIds[dropId] = true;
        _emitAuthorizationConsumed(_authorization, signer);

        uint256 tokenid = 0;
        address executionAddress = address(0);
        if (_authorization.saleMode == SALE_MODE_FIXED_PRICE) {
            tokenid = _executeFixedPriceDrop(_authorization, _tokenData);
            executionAddress = _authorization.recipient;
        } else if (_authorization.saleMode == SALE_MODE_AUCTION) {
            tokenid = _executeAuctionDrop(_authorization, _tokenData);
            executionAddress = _authorization.poster;
        } else {
            revert("Not found");
        }
        tokenDropID[tokenid] = dropId;
        dropInfo[dropId].tokenid = tokenid;
        dropInfo[dropId].signerAddress = signer;
        dropInfo[dropId].posterAddress = _authorization.poster;
        dropInfo[dropId].executionAddress = executionAddress;
        allDrops.push(dropId);
    }

    // Update signer contract address
    function updateTDHsigner(address _tsigner)
        public
        FunctionAdminRequired(this.updateTDHsigner.selector)
    {
        require(_tsigner != address(0), "Zero signer");
        address oldSigner = tdhSigner;
        tdhSigner = _tsigner;
        _incrementSignerEpoch();
        emit DropSignerChanged(oldSigner, _tsigner, signerEpoch);
    }

    function incrementSignerEpoch()
        public
        FunctionAdminRequired(this.incrementSignerEpoch.selector)
    {
        _incrementSignerEpoch();
    }

    function cancelDrop(bytes32 _dropId) public FunctionAdminRequired(this.cancelDrop.selector) {
        require(consumedDropIds[_dropId] == false, "Drop consumed");
        require(cancelledDropIds[_dropId] == false, "Already cancelled");
        cancelledDropIds[_dropId] = true;
        emit DropAuthorizationCancelled(_dropId, msg.sender);
    }

    // update payout address
    function updatePayOutAddress(address _payOutAddress)
        public
        FunctionAdminRequired(this.updatePayOutAddress.selector)
    {
        payOutAddress = _payOutAddress;
    }

    // update curators pool address
    function updateCuratorsPoolAddress(address _curatorsPoolAddress)
        public
        FunctionAdminRequired(this.updateCuratorsPoolAddress.selector)
    {
        curatorsPoolAddress = _curatorsPoolAddress;
    }

    // function to update admin contract
    function updateAdminContract(address _newContract)
        public
        FunctionAdminRequired(this.updateAdminContract.selector)
    {
        require(IStreamAdmins(_newContract).isAdminContract() == true, "Contract is not Admin");
        adminsContract = IStreamAdmins(_newContract);
    }

    // function to update admin contract
    function updateMinterContract(address _newContract)
        public
        FunctionAdminRequired(this.updateMinterContract.selector)
    {
        require(IStreamMinter(_newContract).isMinterContract() == true, "Contract is not Admin");
        minterContract = IStreamMinter(_newContract);
    }

    // retrieve executed drops
    function retrieveDrops() public view returns (bytes32[] memory) {
        return (allDrops);
    }

    // retrieve auction poster address given a token id
    function retrieveAuctionPoster(uint256 _tokenid) public view returns (address) {
        return posterAuctionAddress[_tokenid];
    }

    // retrieve auction starting price given a token id
    function retrieveAuctionPrice(uint256 _tokenid) public view returns (uint256) {
        return auctionPrice[_tokenid];
    }

    // retrieve drop info
    function retrieveDropInfo(bytes32 _dropId)
        public
        view
        returns (uint256, address, address, address)
    {
        return (
            dropInfo[_dropId].tokenid,
            dropInfo[_dropId].signerAddress,
            dropInfo[_dropId].posterAddress,
            dropInfo[_dropId].executionAddress
        );
    }

    // retrieve token id given a drop id
    function retrieveTokenID(bytes32 _dropId) public view returns (uint256) {
        return (dropInfo[_dropId].tokenid);
    }

    // retrieve drop id given a token id
    function retrieveDropID(uint256 _tokenid) public view returns (bytes32) {
        return tokenDropID[_tokenid];
    }

    // retrieve execution address
    function retrieveExecutionAddress(uint256 _tokenid) public view returns (address) {
        return dropInfo[retrieveDropID(_tokenid)].executionAddress;
    }

    function domainSeparator() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(EIP712_NAME)),
                keccak256(bytes(EIP712_VERSION)),
                block.chainid,
                address(this)
            )
        );
    }

    function deriveDropId(address _signer, uint256 _signerEpoch, uint256 _nonce, uint256 _salt)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(DROP_ID_TYPEHASH, _signer, _signerEpoch, _nonce, _salt));
    }

    function hashDropAuthorization(DropAuthorization calldata _authorization)
        public
        view
        returns (bytes32)
    {
        bytes32 structHash = keccak256(abi.encode(DROP_AUTHORIZATION_TYPEHASH, _authorization));
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator(), structHash));
    }

    function isDropConsumed(bytes32 _dropId) public view returns (bool) {
        return consumedDropIds[_dropId];
    }

    function isDropCancelled(bytes32 _dropId) public view returns (bool) {
        return cancelledDropIds[_dropId];
    }

    function _validateAuthorization(
        DropAuthorization calldata _authorization,
        address _signer,
        string calldata _tokenData
    ) private view {
        require(_signer == tdhSigner, "Wrong signer");
        require(_authorization.signerEpoch == signerEpoch, "Bad epoch");
        require(_authorization.deadline >= block.timestamp, "Expired");
        require(_authorization.dropId != bytes32(0), "Zero drop");
        require(
            _authorization.dropId
                == deriveDropId(
                    _signer, _authorization.signerEpoch, _authorization.nonce, _authorization.salt
                ),
            "Bad dropId"
        );
        require(consumedDropIds[_authorization.dropId] == false, "Drop Executed");
        require(cancelledDropIds[_authorization.dropId] == false, "Drop cancelled");
        require(_authorization.poster != address(0), "Zero poster");
        require(_authorization.quantity == 1, "Bad quantity");
        require(keccak256(bytes(_tokenData)) == _authorization.tokenDataHash, "Token data");

        if (_authorization.saleMode == SALE_MODE_FIXED_PRICE) {
            require(_authorization.recipient != address(0), "Zero recipient");
            require(_authorization.auctionReservePrice == 0, "Auction price");
            require(_authorization.auctionEndTime == 0, "Auction end");
            require(msg.value == _authorization.price, "price");
            if (_authorization.price == 0) {
                require(_authorization.payer == address(0), "payer");
            } else {
                require(_authorization.payer == msg.sender, "payer");
            }
        } else if (_authorization.saleMode == SALE_MODE_AUCTION) {
            require(_authorization.recipient == address(0), "Auction recipient");
            require(_authorization.payer == address(0), "payer");
            require(_authorization.price == 0, "Fixed price");
            require(msg.value == 0, "price");
        } else {
            revert("Not found");
        }
    }

    function _incrementSignerEpoch() private {
        uint256 oldEpoch = signerEpoch;
        signerEpoch = oldEpoch + 1;
        emit SignerEpochChanged(oldEpoch, signerEpoch);
    }

    function _executeFixedPriceDrop(
        DropAuthorization calldata _authorization,
        string calldata _tokenData
    ) private returns (uint256) {
        uint256[] memory salt = new uint256[](1);
        uint256[] memory num = new uint256[](1);
        string[] memory tokenData = new string[](1);
        address[] memory receiver = new address[](1);
        receiver[0] = _authorization.recipient;
        salt[0] = 0;
        num[0] = 1;
        tokenData[0] = _tokenData;
        (bool success1,) = payable(_authorization.poster).call{ value: (msg.value / 2) }("");
        (bool success2,) = payable(payOutAddress).call{ value: (msg.value / 4) }("");
        (bool success3,) = payable(curatorsPoolAddress).call{ value: (msg.value / 4) }("");
        require(success1, "ETH failed");
        require(success2, "ETH failed");
        require(success3, "ETH failed");
        return minterContract.mint(receiver, tokenData, salt, _authorization.collectionId, num);
    }

    function _executeAuctionDrop(
        DropAuthorization calldata _authorization,
        string calldata _tokenData
    ) private returns (uint256) {
        uint256 tokenid = minterContract.mintAndAuction(
            payOutAddress, _tokenData, 0, _authorization.collectionId, _authorization.auctionEndTime
        );
        posterAuctionAddress[tokenid] = _authorization.poster;
        auctionPrice[tokenid] = _authorization.auctionReservePrice;
        return tokenid;
    }

    function _emitAuthorizationConsumed(DropAuthorization calldata _authorization, address _signer)
        private
    {
        emit DropAuthorizationConsumed(
            _authorization.dropId,
            _signer,
            _authorization.poster,
            _authorization.recipient,
            _authorization.payer,
            _authorization.collectionId,
            _authorization.saleMode,
            _authorization.tokenDataHash,
            _authorization.deadline,
            _authorization.signerEpoch
        );
    }

    function _recoverEOASigner(bytes32 _digest, bytes calldata _signature)
        private
        pure
        returns (address)
    {
        bytes32 r;
        bytes32 s;
        uint8 v;
        if (_signature.length == 65) {
            assembly {
                r := calldataload(_signature.offset)
                s := calldataload(add(_signature.offset, 32))
                v := byte(0, calldataload(add(_signature.offset, 64)))
            }
        } else if (_signature.length == 64) {
            bytes32 vs;
            assembly {
                r := calldataload(_signature.offset)
                vs := calldataload(add(_signature.offset, 32))
            }
            s = vs & EIP2098_S_MASK;
            v = uint8((uint256(vs) >> 255) + 27);
        } else {
            revert("Bad signature");
        }

        require(uint256(s) <= SECP256K1_N_DIV_2, "High s");
        require(v == 27 || v == 28, "Bad v");
        address signer = ecrecover(_digest, v, r, s);
        require(signer != address(0), "Zero signer");
        return signer;
    }
}
