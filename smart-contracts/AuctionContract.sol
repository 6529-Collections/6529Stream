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
import "./IERC721Receiver.sol";
import "./IStreamAdmins.sol";
import "./ReentrancyGuard.sol";
import "./StreamPauseDomains.sol";

contract StreamAuctions is ReentrancyGuard, IERC721Receiver {
    enum AuctionStatus {
        None,
        Created,
        Active,
        EndedNoBid,
        EndedWithBid,
        SettledNoBid,
        SettledWithBid,
        Cancelled
    }

    enum ProceedsCreditType {
        Poster,
        Protocol,
        Curator
    }

    struct AuctionRecord {
        bytes32 dropId;
        uint256 tokenId;
        uint256 collectionId;
        address poster;
        address custody;
        uint256 reservePrice;
        uint256 endTime;
        bool custodyConfirmed;
        AuctionStatus terminalStatus;
        address pendingNoBidNftClaimant;
    }

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
        require(_isFunctionOrGlobalAdmin(msg.sender, _selector), "Not allowed");
        _;
    }

    // events
    event AuctionRegistered(
        bytes32 indexed dropId,
        uint256 indexed tokenid,
        uint256 indexed collectionId,
        address poster,
        address custody,
        uint256 reservePrice,
        uint256 endTime
    );
    event AuctionCustodyConfirmed(uint256 indexed tokenid, address indexed custody);
    event AuctionStatusChanged(uint256 indexed tokenid, uint8 indexed status);
    event AuctionExtended(
        uint256 indexed tokenid, uint256 indexed oldEndTime, uint256 indexed newEndTime
    );
    event AuctionCancelled(uint256 indexed tokenid, address indexed poster);
    event NoBidSettlementPending(uint256 indexed tokenid, address indexed claimant);
    event NoBidTokenClaimed(
        uint256 indexed tokenid, address indexed claimant, address indexed recipient
    );
    event Participate(address indexed _add, uint256 indexed tokenid, uint256 indexed bid);
    event OutbidCreditCreated(
        address indexed _add, uint256 indexed tokenid, uint256 indexed credit
    );
    event BidderCreditWithdrawn(
        address indexed _add, address indexed _recipient, uint256 indexed funds
    );
    event AuctionProceedsCreditCreated(
        address indexed _add, uint256 indexed tokenid, uint8 indexed creditType, uint256 funds
    );
    event ProceedsCreditWithdrawn(
        address indexed _add, address indexed _recipient, uint256 indexed funds
    );
    event ClaimAuction(uint256 indexed tokenid, uint256 indexed bid);
    event Withdraw(address indexed _add, bool status, uint256 indexed funds);
    event EmergencyWithdrawal(
        address indexed _admin,
        address indexed _recipient,
        bytes32 indexed _domain,
        uint256 funds,
        uint256 resultingSurplus
    );

    // constructor
    constructor(
        address _minterContract,
        address _gencore,
        address _adminsContract,
        address _dropsContract,
        address _payOutAddress,
        address _curatorsPoolAddress
    ) {
        require(_payOutAddress != address(0), "Zero payout");
        require(_curatorsPoolAddress != address(0), "Zero curator");
        minterContract = IStreamMinter(_minterContract);
        gencore = _gencore;
        adminsContract = IStreamAdmins(_adminsContract);
        dropsContract = IStreamDrops(_dropsContract);
        payOutAddress = _payOutAddress;
        curatorsPoolAddress = _curatorsPoolAddress;
        incPercent = 5;
        extensionTime = 300;
    }

    mapping(uint256 => AuctionRecord) public auctionRecords;

    // auction highest bid
    mapping(uint256 => uint256) public auctionHighestBid;

    // aduction highest bidder
    mapping(uint256 => address) public auctionHighestBidder;

    // auction claim
    mapping(uint256 => bool) public auctionClaim;

    // withdrawable credits owed to outbid bidders
    mapping(address => uint256) public auctionBidderCredits;

    // withdrawable final auction proceeds
    mapping(address => uint256) public auctionPosterCredits;
    mapping(address => uint256) public auctionProtocolCredits;
    mapping(address => uint256) public auctionCuratorCredits;

    // total withdrawable bidder credits
    uint256 public totalBidderOwed;

    // active highest bids held until outbid or auction settlement
    uint256 public totalAuctionBidEscrow;

    // total withdrawable final auction proceeds by category
    uint256 public totalPosterOwed;
    uint256 public totalProtocolOwed;
    uint256 public totalCuratorOwed;

    function isStreamAuctionsContract() external pure returns (bool) {
        return true;
    }

    function registerAuction(
        bytes32 _dropId,
        uint256 _tokenid,
        uint256 _collectionId,
        address _poster,
        uint256 _reservePrice,
        uint256 _auctionEndTime
    ) external {
        require(msg.sender == address(dropsContract), "Not drops");
        require(_dropId != bytes32(0), "Zero drop");
        require(auctionRecords[_tokenid].dropId == bytes32(0), "Auction exists");
        require(_poster != address(0), "Zero poster");
        require(_auctionEndTime > block.timestamp, "Ended");

        address custody = address(this);
        require(IERC721(gencore).ownerOf(_tokenid) == custody, "Custody missing");

        auctionRecords[_tokenid] = AuctionRecord({
            dropId: _dropId,
            tokenId: _tokenid,
            collectionId: _collectionId,
            poster: _poster,
            custody: custody,
            reservePrice: _reservePrice,
            endTime: _auctionEndTime,
            custodyConfirmed: true,
            terminalStatus: AuctionStatus.None,
            pendingNoBidNftClaimant: address(0)
        });

        emit AuctionRegistered(
            _dropId, _tokenid, _collectionId, _poster, custody, _reservePrice, _auctionEndTime
        );
        emit AuctionCustodyConfirmed(_tokenid, custody);
        emit AuctionStatusChanged(_tokenid, uint8(AuctionStatus.Active));
    }

    function retrieveAuctionStatus(uint256 _tokenid) public view returns (AuctionStatus) {
        AuctionRecord storage record = auctionRecords[_tokenid];
        if (record.dropId == bytes32(0)) {
            return AuctionStatus.None;
        }
        if (record.terminalStatus != AuctionStatus.None) {
            return record.terminalStatus;
        }
        // Current drop execution confirms custody atomically and enters Active
        // directly; Created is reserved for any future non-atomic custody flow.
        if (record.custodyConfirmed == false) {
            return AuctionStatus.Created;
        }
        if (block.timestamp > record.endTime) {
            if (auctionHighestBid[_tokenid] == 0) {
                return AuctionStatus.EndedNoBid;
            }
            return AuctionStatus.EndedWithBid;
        }
        return AuctionStatus.Active;
    }

    function retrieveAuctionEndTime(uint256 _tokenid) public view returns (uint256) {
        return auctionRecords[_tokenid].endTime;
    }

    function pendingNoBidNftClaimant(uint256 _tokenid) public view returns (address) {
        return auctionRecords[_tokenid].pendingNoBidNftClaimant;
    }

    // participate to auction
    function participateToAuction(uint256 _tokenid) public payable nonReentrant {
        require(adminsContract.isPaused(StreamPauseDomains.AUCTION_BID) == false, "Bid paused");
        require(retrieveAuctionStatus(_tokenid) == AuctionStatus.Active, "Ended");

        AuctionRecord storage record = auctionRecords[_tokenid];
        uint256 previousBid = auctionHighestBid[_tokenid];
        address previousBidder = auctionHighestBidder[_tokenid];
        if (previousBid == 0) {
            // bid can be equal to the starting bid
            require(msg.value >= record.reservePrice, "Equal or Higher than starting bid");
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
        if (record.endTime - block.timestamp <= extensionTime) {
            uint256 oldEndTime = record.endTime;
            record.endTime = oldEndTime + extensionTime;
            emit AuctionExtended(_tokenid, oldEndTime, record.endTime);
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

    function withdrawAuctionProceedsCredit() external {
        withdrawAuctionProceedsCreditTo(payable(msg.sender));
    }

    function withdrawAuctionProceedsCreditTo(address payable _recipient) public nonReentrant {
        require(_recipient != address(0), "Zero recipient");
        uint256 posterCredit = auctionPosterCredits[msg.sender];
        uint256 protocolCredit = auctionProtocolCredits[msg.sender];
        uint256 curatorCredit = auctionCuratorCredits[msg.sender];
        uint256 credit = posterCredit + protocolCredit + curatorCredit;
        require(credit != 0, "No credit");

        auctionPosterCredits[msg.sender] = 0;
        auctionProtocolCredits[msg.sender] = 0;
        auctionCuratorCredits[msg.sender] = 0;
        totalPosterOwed -= posterCredit;
        totalProtocolOwed -= protocolCredit;
        totalCuratorOwed -= curatorCredit;

        (bool success,) = _recipient.call{ value: credit }("");
        require(success, "ETH failed");
        emit ProceedsCreditWithdrawn(msg.sender, _recipient, credit);
    }

    // claim token after auction end
    function claimAuction(uint256 _tokenid) public nonReentrant {
        require(
            adminsContract.isPaused(StreamPauseDomains.AUCTION_SETTLEMENT) == false,
            "Settlement paused"
        );
        AuctionStatus status = retrieveAuctionStatus(_tokenid);
        require(
            status == AuctionStatus.EndedNoBid || status == AuctionStatus.EndedWithBid, "Not ended"
        );

        uint256 highestBid = auctionHighestBid[_tokenid];
        if (highestBid == 0) {
            _settleNoBidAuction(_tokenid);
        } else {
            _settleWithBidAuction(_tokenid, highestBid);
        }
    }

    function claimNoBidAuctionToken(uint256 _tokenid, address _recipient) public nonReentrant {
        require(
            adminsContract.isPaused(StreamPauseDomains.AUCTION_SETTLEMENT) == false,
            "Settlement paused"
        );
        require(_recipient != address(0), "Zero recipient");
        AuctionRecord storage record = auctionRecords[_tokenid];
        require(record.pendingNoBidNftClaimant == msg.sender, "Not claimant");

        record.pendingNoBidNftClaimant = address(0);
        record.terminalStatus = AuctionStatus.SettledNoBid;
        auctionClaim[_tokenid] = true;
        IERC721(gencore).safeTransferFrom(address(this), _recipient, _tokenid);

        emit NoBidTokenClaimed(_tokenid, msg.sender, _recipient);
        emit AuctionStatusChanged(_tokenid, uint8(AuctionStatus.SettledNoBid));
        emit ClaimAuction(_tokenid, 0);
    }

    function cancelAuction(uint256 _tokenid) public nonReentrant {
        AuctionRecord storage record = auctionRecords[_tokenid];
        require(record.dropId != bytes32(0), "No auction");
        require(
            msg.sender == record.poster
                || _isFunctionOrGlobalAdmin(msg.sender, this.cancelAuction.selector),
            "Not allowed"
        );
        require(retrieveAuctionStatus(_tokenid) == AuctionStatus.Active, "Ended");
        require(auctionHighestBid[_tokenid] == 0, "Bid exists");

        record.terminalStatus = AuctionStatus.Cancelled;
        auctionClaim[_tokenid] = true;
        IERC721(gencore).safeTransferFrom(address(this), record.poster, _tokenid);

        emit AuctionCancelled(_tokenid, record.poster);
        emit AuctionStatusChanged(_tokenid, uint8(AuctionStatus.Cancelled));
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        view
        override
        returns (bytes4)
    {
        require(msg.sender == gencore, "Wrong NFT");
        return IERC721Receiver.onERC721Received.selector;
    }

    function _settleNoBidAuction(uint256 _tokenid) private {
        AuctionRecord storage record = auctionRecords[_tokenid];
        require(record.pendingNoBidNftClaimant == address(0), "Pending claim");

        if (record.poster.code.length != 0) {
            record.pendingNoBidNftClaimant = record.poster;
            emit NoBidSettlementPending(_tokenid, record.poster);
            return;
        }

        record.terminalStatus = AuctionStatus.SettledNoBid;
        auctionClaim[_tokenid] = true;
        IERC721(gencore).safeTransferFrom(address(this), record.poster, _tokenid);

        emit AuctionStatusChanged(_tokenid, uint8(AuctionStatus.SettledNoBid));
        emit ClaimAuction(_tokenid, 0);
    }

    function _settleWithBidAuction(uint256 _tokenid, uint256 _highestBid) private {
        AuctionRecord storage record = auctionRecords[_tokenid];
        address highestBidder = auctionHighestBidder[_tokenid];
        require(highestBidder != address(0), "No bidder");

        record.terminalStatus = AuctionStatus.SettledWithBid;
        auctionClaim[_tokenid] = true;
        totalAuctionBidEscrow -= _highestBid;
        _creditAuctionProceeds(_tokenid, record.poster, _highestBid);
        IERC721(gencore).safeTransferFrom(address(this), highestBidder, _tokenid);

        emit AuctionStatusChanged(_tokenid, uint8(AuctionStatus.SettledWithBid));
        emit ClaimAuction(_tokenid, _highestBid);
    }

    function _creditAuctionProceeds(uint256 _tokenid, address _poster, uint256 _highestBid)
        private
    {
        uint256 posterCredit = _highestBid / 2;
        uint256 protocolCredit = _highestBid / 4;
        // Integer remainders accrue to the curator credit so all wei remain owed.
        uint256 curatorCredit = _highestBid - posterCredit - protocolCredit;

        auctionPosterCredits[_poster] += posterCredit;
        auctionProtocolCredits[payOutAddress] += protocolCredit;
        auctionCuratorCredits[curatorsPoolAddress] += curatorCredit;

        totalPosterOwed += posterCredit;
        totalProtocolOwed += protocolCredit;
        totalCuratorOwed += curatorCredit;

        emit AuctionProceedsCreditCreated(
            _poster, _tokenid, uint8(ProceedsCreditType.Poster), posterCredit
        );
        emit AuctionProceedsCreditCreated(
            payOutAddress, _tokenid, uint8(ProceedsCreditType.Protocol), protocolCredit
        );
        emit AuctionProceedsCreditCreated(
            curatorsPoolAddress, _tokenid, uint8(ProceedsCreditType.Curator), curatorCredit
        );
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
        require(_payOutAddress != address(0), "Zero payout");
        payOutAddress = _payOutAddress;
    }

    // update curators pool address
    function updateCuratorsPoolAddress(address _curatorsPoolAddress)
        public
        FunctionAdminRequired(this.updateCuratorsPoolAddress.selector)
    {
        require(_curatorsPoolAddress != address(0), "Zero curator");
        curatorsPoolAddress = _curatorsPoolAddress;
    }

    function totalProceedsOwed() public view returns (uint256) {
        return totalPosterOwed + totalProtocolOwed + totalCuratorOwed;
    }

    function totalOwed() public view returns (uint256) {
        return totalBidderOwed + totalAuctionBidEscrow + totalProceedsOwed();
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
        address recipient = adminsContract.emergencyRecipient();
        emit Withdraw(msg.sender, true, balance);
        emit EmergencyWithdrawal(msg.sender, recipient, StreamPauseDomains.EMERGENCY, balance, 0);
        if (balance > 0) {
            (bool success,) = payable(recipient).call{ value: balance }("");
            require(success, "ETH failed");
        }
    }

    function _isFunctionOrGlobalAdmin(address _admin, bytes4 _selector)
        private
        view
        returns (bool)
    {
        return adminsContract.retrieveFunctionAdmin(_admin, address(this), _selector) == true
            || adminsContract.retrieveGlobalAdmin(_admin) == true;
    }
}
