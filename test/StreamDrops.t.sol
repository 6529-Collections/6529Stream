// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/contracts/StreamDrops.sol";
import "../smart-contracts/contracts/StreamAdmins.sol";
import "./helpers/Vm.sol";

contract MockMinterForDrops {
    uint256 public lastMintReturn = 1_000_000_000;
    uint256 public lastMintAndAuctionReturn = 2_000_000_000;
    bool public minterStatus = true;
    address public lastAuctionRecipient;
    uint256 public lastAuctionCollectionId;
    uint256 public lastAuctionEndTime;

    function isMinterContract() external view returns (bool) { return minterStatus; }
    function getEndTime(uint256) external pure returns (uint) { return 0; }
    function getAuctionEndTime(uint256) external pure returns (uint) { return 0; }
    function getAuctionStatus(uint256) external pure returns (bool) { return false; }
    function updateAuctionEndTime(uint256, uint256) external pure {}

    function mint(address[] memory, string[] memory, uint256[] memory, uint256, uint256[] memory) external view returns (uint256) {
        return lastMintReturn;
    }

    function mintAndAuction(address recipient, string memory, uint256, uint256 collectionId, uint auctionEndTime) external returns (uint256) {
        lastAuctionRecipient = recipient;
        lastAuctionCollectionId = collectionId;
        lastAuctionEndTime = auctionEndTime;
        return lastMintAndAuctionReturn;
    }
}

contract StreamDropsTest {
    Vm internal constant vm = Vm(HEVM_ADDRESS);

    address internal constant TDH_SIGNER = address(0xAA01);
    address payable internal constant POSTER = payable(address(0xAA02));
    address internal constant CALLER = address(0xAA03);
    address payable internal constant PAYOUT = payable(address(0xAA04));
    address payable internal constant CURATORS = payable(address(0xAA05));
    address internal constant ADMIN = address(0xAA06);

    function _deployDrops() internal returns (StreamDrops, MockMinterForDrops, StreamAdmins) {
        StreamAdmins admins = new StreamAdmins(TDH_SIGNER);
        MockMinterForDrops mockMinter = new MockMinterForDrops();
        StreamDrops drops = new StreamDrops(
            TDH_SIGNER,
            address(mockMinter),
            address(admins),
            PAYOUT,
            CURATORS
        );
        return (drops, mockMinter, admins);
    }

    function test_mintDropFixedPriceStoresDropAndSplitsFunds() external {
        vm.deal(TDH_SIGNER, 2 ether);

        (StreamDrops drops, MockMinterForDrops mockMinter,) = _deployDrops();

        uint256 price = 1 ether;
        uint256 posterBefore = POSTER.balance;
        uint256 payoutBefore = PAYOUT.balance;
        uint256 curatorsBefore = CURATORS.balance;

        vm.prank(TDH_SIGNER);
        drops.mintDrop{value: price}(POSTER, "{\"k\":\"v\"}", 1, 1, price, 0);

        require(POSTER.balance == posterBefore + (price / 2), "poster split");
        require(PAYOUT.balance == payoutBefore + (price / 4), "payout split");
        require(CURATORS.balance == curatorsBefore + (price / 4), "curators split");

        bytes32[] memory allDrops = drops.retrieveDrops();
        require(allDrops.length == 1, "drop should be stored");
        require(drops.retrieveTokenID(allDrops[0]) == mockMinter.lastMintReturn(), "token should map to drop");
    }

    function test_onlySignerCanMintDrop() external {
        (StreamDrops drops,,) = _deployDrops();

        vm.expectRevert(bytes("Not Allowed"));
        drops.mintDrop(POSTER, "{}", 1, 1, 0.1 ether, 0);
    }

    function test_constructorRejectsZeroAddresses() external {
        StreamAdmins admins = new StreamAdmins(TDH_SIGNER);
        MockMinterForDrops mockMinter = new MockMinterForDrops();

        vm.expectRevert(bytes("invalid signer"));
        new StreamDrops(address(0), address(mockMinter), address(admins), PAYOUT, CURATORS);

        vm.expectRevert(bytes("invalid minter"));
        new StreamDrops(TDH_SIGNER, address(0), address(admins), PAYOUT, CURATORS);

        vm.expectRevert(bytes("invalid admin"));
        new StreamDrops(TDH_SIGNER, address(mockMinter), address(0), PAYOUT, CURATORS);
    }

    function test_mintDropRejectsWrongPriceAndDuplicateDrop() external {
        vm.deal(TDH_SIGNER, 2 ether);
        (StreamDrops drops,,) = _deployDrops();

        vm.prank(TDH_SIGNER);
        vm.expectRevert(bytes("price"));
        drops.mintDrop{value: 0.5 ether}(POSTER, "dup", 1, 1, 1 ether, 0);

        vm.prank(TDH_SIGNER);
        drops.mintDrop{value: 1 ether}(POSTER, "dup", 1, 1, 1 ether, 0);

        vm.prank(TDH_SIGNER);
        vm.expectRevert(bytes("Drop Executed"));
        drops.mintDrop{value: 1 ether}(POSTER, "dup", 1, 1, 1 ether, 0);
    }

    function test_mintDropAuctionPathStoresAuctionMetadata() external {
        vm.deal(TDH_SIGNER, 1 ether);
        (StreamDrops drops, MockMinterForDrops mockMinter,) = _deployDrops();

        uint256 auctionPrice = 2 ether;
        uint256 endDate = block.timestamp + 1 days;
        vm.prank(TDH_SIGNER);
        drops.mintDrop(POSTER, "auction", 7, 2, auctionPrice, endDate);

        uint256 tokenId = mockMinter.lastMintAndAuctionReturn();
        require(drops.retrieveAuctionPoster(tokenId) == POSTER, "poster should be recorded");
        require(drops.retrieveAuctionPrice(tokenId) == auctionPrice, "auction price should be recorded");
        require(mockMinter.lastAuctionRecipient() == PAYOUT, "auction mint recipient should be payout");
        require(mockMinter.lastAuctionCollectionId() == 7, "collection id should be forwarded");
        require(mockMinter.lastAuctionEndTime() == endDate, "end date should be forwarded");
    }

    function test_mintDropUsesMsgSenderAsExecutionAddress() external {
        vm.deal(TDH_SIGNER, 1 ether);
        vm.deal(ADMIN, 1 ether);
        (StreamDrops drops,, StreamAdmins admins) = _deployDrops();

        vm.prank(TDH_SIGNER);
        admins.registerAdmin(ADMIN, true);
        vm.prank(TDH_SIGNER);
        drops.updateTDHsigner(ADMIN);

        vm.prank(ADMIN);
        drops.mintDrop{value: 1 ether}(POSTER, "exec", 3, 1, 1 ether, 0);

        bytes32[] memory allDrops = drops.retrieveDrops();
        require(allDrops.length == 1, "drop should exist");
        (, , , address executionAddress) = drops.retrieveDropInfo(allDrops[0]);
        require(executionAddress == ADMIN, "execution address must be msg.sender");
    }
}

