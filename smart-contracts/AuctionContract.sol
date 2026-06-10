// SPDX-License-Identifier: MIT

/**
 *
 *  @title: Auction Contract for 6529 Stream (Not final)
 *  @date: 22-June-2024
 *  @version: 1.7
 *  @author: 6529 team
 */

pragma solidity ^0.8.19;

import "./IStreamMinter.sol";
import "./IStreamDrops.sol";
import "./IERC721.sol";
import "./IStreamAdmins.sol";
import "./ReentrancyGuard.sol";

contract StreamAuctions is ReentrancyGuard {
    // variables declaration
    IStreamMinter public minterContract;
    IStreamAdmins public adminsContract;
    IStreamDrops public dropsContract;
    address public gencore;
    address public payOutAddress;
    address public curatorsPoolAddress;
    uint256 public incPercent;
    uint256 public extensionTime;

    // certain functions can only be called by a global or function admin
    modifier FunctionAdminRequired(bytes4 _selector) {
        require(
            adminsContract.retrieveFunctionAdmin(msg.sender, _selector) == true
                || adminsContract.retrieveGlobalAdmin(msg.sender) == true,
            "Not allowed"
        );
        _;
    }

    // events
    event Participate(address indexed _add, uint256 indexed tokenid, uint256 indexed bid);
    event OutbidCreditCreated(
        address indexed _add, uint256 indexed tokenid, uint256 indexed credit
    );
    event BidderCreditWithdrawn(
        address indexed _add, address indexed _recipient, uint256 indexed funds
    );
    event ClaimAuction(uint256 indexed tokenid, uint256 indexed bid);
    event Withdraw(address indexed _add, bool status, uint256 indexed funds);

    // constructor
    constructor(
        address _minterContract,
        address _gencore,
        address _adminsContract,
        address _dropsContract,
        address _payOutAddress,
        address _curatorsPoolAddress
    ) {
        minterContract = IStreamMinter(_minterContract);
        gencore = _gencore;
        adminsContract = IStreamAdmins(_adminsContract);
        dropsContract = IStreamDrops(_dropsContract);
        payOutAddress = _payOutAddress;
        curatorsPoolAddress = _curatorsPoolAddress;
        incPercent = 5;
        extensionTime = 300;
    }

    // auction highest bid
    mapping(uint256 => uint256) public auctionHighestBid;

    // aduction highest bidder
    mapping(uint256 => address) public auctionHighestBidder;

    // auction claim
    mapping(uint256 => bool) public auctionClaim;

    // withdrawable credits owed to outbid bidders
    mapping(address => uint256) public auctionBidderCredits;

    // total withdrawable bidder credits
    uint256 public totalBidderOwed;

    // active highest bids held until outbid or auction settlement
    uint256 public totalAuctionBidEscrow;

    // participate to auction
    function participateToAuction(uint256 _tokenid) public payable nonReentrant {
        require(
            block.timestamp <= minterContract.getAuctionEndTime(_tokenid)
                && minterContract.getAuctionStatus(_tokenid) == true,
            "Ended"
        );
        uint256 previousBid = auctionHighestBid[_tokenid];
        address previousBidder = auctionHighestBidder[_tokenid];
        if (previousBid == 0) {
            uint256 bid;
            bid = dropsContract.retrieveAuctionPrice(_tokenid);
            // bid can be equal to the starting bid
            require(msg.value >= bid, "Equal or Higher than starting bid");
        } else {
            // bid must be equal or larger than current highest bid by a %
            require(
                msg.value >= previousBid + (previousBid * incPercent / 100),
                "% more than highest bid"
            );
        }
        // register the new bid;
        auctionHighestBid[_tokenid] = msg.value;
        auctionHighestBidder[_tokenid] = msg.sender;
        totalAuctionBidEscrow = totalAuctionBidEscrow - previousBid + msg.value;
        if (previousBid != 0) {
            auctionBidderCredits[previousBidder] += previousBid;
            totalBidderOwed += previousBid;
            emit OutbidCreditCreated(previousBidder, _tokenid, previousBid);
        }
        // extend auction if less than 5 mins remain
        if (minterContract.getAuctionEndTime(_tokenid) - block.timestamp <= extensionTime) {
            minterContract.updateAuctionEndTime(
                _tokenid, minterContract.getAuctionEndTime(_tokenid) + extensionTime
            );
        }
        emit Participate(msg.sender, _tokenid, msg.value);
    }

    function withdrawBidderCredit() external {
        withdrawBidderCreditTo(payable(msg.sender));
    }

    function withdrawBidderCreditTo(address payable _recipient) public nonReentrant {
        require(_recipient != address(0), "Zero recipient");
        uint256 credit = auctionBidderCredits[msg.sender];
        require(credit != 0, "No credit");
        auctionBidderCredits[msg.sender] = 0;
        totalBidderOwed -= credit;
        (bool success,) = _recipient.call{ value: credit }("");
        require(success, "ETH failed");
        emit BidderCreditWithdrawn(msg.sender, _recipient, credit);
    }

    // claim token after auction end
    function claimAuction(uint256 _tokenid) public nonReentrant {
        require(
            block.timestamp > minterContract.getAuctionEndTime(_tokenid)
                && minterContract.getAuctionStatus(_tokenid) == true
                && auctionClaim[_tokenid] == false,
            "err"
        );
        auctionClaim[_tokenid] = true;
        uint256 highestBid = auctionHighestBid[_tokenid];
        address ownerOfToken = IERC721(gencore).ownerOf(_tokenid);
        address highestBidder = auctionHighestBidder[_tokenid];
        if (highestBid == 0) {
            IERC721(gencore)
                .safeTransferFrom(
                    ownerOfToken, dropsContract.retrieveExecutionAddress(_tokenid), _tokenid
                );
        } else {
            totalAuctionBidEscrow -= highestBid;
            (bool success1,) = payable(dropsContract.retrieveAuctionPoster(_tokenid))
            .call{ value: (highestBid / 2) }(
                ""
            );
            require(success1, "ETH failed");
            (bool success2,) = payable(payOutAddress).call{ value: (highestBid / 4) }("");
            require(success2, "ETH failed");
            (bool success3,) = payable(curatorsPoolAddress).call{ value: (highestBid / 4) }("");
            require(success3, "ETH failed");
            IERC721(gencore).safeTransferFrom(ownerOfToken, highestBidder, _tokenid);
            emit ClaimAuction(_tokenid, highestBid);
        }
    }

    // function to add a minter contract
    function updateMinterContract(address _minterContract)
        public
        FunctionAdminRequired(this.updateMinterContract.selector)
    {
        require(IStreamMinter(_minterContract).isMinterContract() == true, "Contract is not Minter");
        minterContract = IStreamMinter(_minterContract);
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

    // function to add a minter contract
    function updateDropsContract(address _dropsContract)
        public
        FunctionAdminRequired(this.updateDropsContract.selector)
    {
        dropsContract = IStreamDrops(_dropsContract);
    }

    // function to update increment bid percentage and extension time
    function updatePercentAndExtensionTime(uint256 _opt, uint256 _value)
        public
        FunctionAdminRequired(this.updatePercentAndExtensionTime.selector)
    {
        if (_opt == 1) {
            incPercent = _value;
        } else {
            extensionTime = _value;
        }
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

    function totalOwed() public view returns (uint256) {
        return totalBidderOwed + totalAuctionBidEscrow;
    }

    function emergencyWithdrawable() public view returns (uint256) {
        uint256 balance = address(this).balance;
        uint256 owed = totalOwed();
        if (balance <= owed) {
            return 0;
        }
        return balance - owed;
    }

    // function to withdraw any balance from the smart contract
    function emergencyWithdraw() public FunctionAdminRequired(this.emergencyWithdraw.selector) {
        uint256 balance = emergencyWithdrawable();
        if (balance == 0) {
            emit Withdraw(msg.sender, true, 0);
            return;
        }
        address admin = adminsContract.owner();
        (bool success,) = payable(admin).call{ value: balance }("");
        require(success, "ETH failed");
        emit Withdraw(msg.sender, success, balance);
    }
}
