// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/contracts/StreamMinter.sol";
import "../smart-contracts/contracts/StreamAdmins.sol";
import "./helpers/Vm.sol";

contract MockStreamCoreForMinter {
    bool public dataAdded = true;
    uint256 public minIndex = 10_000_000_000;
    uint256 public maxIndex = 10_000_000_010;
    uint256 public cirSupply;
    uint256 public mintCallCount;
    uint256 public lastMintIndex;

    function retrievewereDataAdded(uint256) external view returns (bool) { return dataAdded; }
    function viewTokensIndexMin(uint256) external view returns (uint256) { return minIndex; }
    function viewTokensIndexMax(uint256) external view returns (uint256) { return maxIndex; }
    function viewCirSupply(uint256) external view returns (uint256) { return cirSupply; }
    function collectionFreezeStatus(uint256) external pure returns (bool) { return false; }
    function viewMaxAllowance(uint256) external pure returns (uint256) { return 0; }
    function retrieveTokensMintedALPerAddress(uint256, address) external pure returns (uint256) { return 0; }
    function retrieveTokensMintedPublicPerAddress(uint256, address) external pure returns (uint256) { return 0; }
    function viewColIDforTokenID(uint256) external pure returns (uint256) { return 0; }
    function retrieveArtistAddress(uint256) external pure returns (address) { return address(0); }
    function setTokenHash(uint256, uint256, bytes32) external pure {}
    function retrieveTokenHash(uint256) external pure returns (bytes32) { return bytes32(0); }
    function setDataAdded(bool value) external { dataAdded = value; }
    function setMaxIndex(uint256 value) external { maxIndex = value; }
    function setCirSupply(uint256 value) external { cirSupply = value; }

    function mint(uint256 mintIndex, address, string memory, uint256, uint256) external {
        mintCallCount += 1;
        lastMintIndex = mintIndex;
        cirSupply += 1;
    }
}

contract StreamMinterTest {
    Vm internal constant vm = Vm(HEVM_ADDRESS);

    address internal constant TDH_SIGNER = address(0x1111);
    address internal constant STREAM_DROPS = address(0x2222);
    address internal constant OTHER = address(0x2223);
    address internal constant RECIPIENT = address(0x3333);

    function _deployMinter() internal returns (StreamMinter, MockStreamCoreForMinter, StreamAdmins) {
        StreamAdmins admins = new StreamAdmins(TDH_SIGNER);
        MockStreamCoreForMinter core = new MockStreamCoreForMinter();
        StreamMinter minter = new StreamMinter(address(core), address(admins), STREAM_DROPS);
        return (minter, core, admins);
    }

    function test_setCollectionPhasesAndMintFromStreamDrops() external {
        (StreamMinter minter, MockStreamCoreForMinter core,) = _deployMinter();

        vm.prank(TDH_SIGNER);
        minter.setCollectionPhases(1, 1, block.timestamp + 1 days);

        address[] memory recipients = new address[](1);
        recipients[0] = RECIPIENT;
        string[] memory tokenData = new string[](1);
        tokenData[0] = "{\"trait\":\"value\"}";
        uint256[] memory salts = new uint256[](1);
        salts[0] = 0;
        uint256[] memory qty = new uint256[](1);
        qty[0] = 2;

        vm.prank(STREAM_DROPS);
        uint256 mintedIndex = minter.mint(recipients, tokenData, salts, 1, qty);

        require(core.mintCallCount() == 2, "must mint requested quantity");
        require(mintedIndex == core.lastMintIndex(), "return value must be last mint index");
    }

    function test_mintRevertsBeforeStart() external {
        (StreamMinter minter,,) = _deployMinter();

        vm.prank(TDH_SIGNER);
        minter.setCollectionPhases(1, block.timestamp + 1 days, block.timestamp + 2 days);

        address[] memory recipients = new address[](1);
        recipients[0] = RECIPIENT;
        string[] memory tokenData = new string[](1);
        tokenData[0] = "{}";
        uint256[] memory salts = new uint256[](1);
        salts[0] = 0;
        uint256[] memory qty = new uint256[](1);
        qty[0] = 1;

        vm.prank(STREAM_DROPS);
        vm.expectRevert(bytes("Not started"));
        minter.mint(recipients, tokenData, salts, 1, qty);
    }

    function test_onlyStreamDropsCanMint() external {
        (StreamMinter minter,,) = _deployMinter();

        vm.prank(TDH_SIGNER);
        minter.setCollectionPhases(1, 1, block.timestamp + 1 days);

        address[] memory recipients = new address[](1);
        recipients[0] = RECIPIENT;
        string[] memory tokenData = new string[](1);
        tokenData[0] = "{}";
        uint256[] memory salts = new uint256[](1);
        salts[0] = 0;
        uint256[] memory qty = new uint256[](1);
        qty[0] = 1;

        vm.prank(OTHER);
        vm.expectRevert(bytes("Not allowed"));
        minter.mint(recipients, tokenData, salts, 1, qty);
    }

    function test_setCollectionPhasesRequiresDataAdded() external {
        (StreamMinter minter, MockStreamCoreForMinter core,) = _deployMinter();
        core.setDataAdded(false);

        vm.prank(TDH_SIGNER);
        vm.expectRevert(bytes("Add data"));
        minter.setCollectionPhases(1, 1, block.timestamp + 1 days);
    }

    function test_mintRevertsWhenEnded() external {
        (StreamMinter minter,,) = _deployMinter();

        vm.prank(TDH_SIGNER);
        minter.setCollectionPhases(1, 1, block.timestamp + 10);

        vm.warp(block.timestamp + 11);
        address[] memory recipients = new address[](1);
        recipients[0] = RECIPIENT;
        string[] memory tokenData = new string[](1);
        tokenData[0] = "{}";
        uint256[] memory salts = new uint256[](1);
        salts[0] = 0;
        uint256[] memory qty = new uint256[](1);
        qty[0] = 1;

        vm.prank(STREAM_DROPS);
        vm.expectRevert(bytes("Ended"));
        minter.mint(recipients, tokenData, salts, 1, qty);
    }

    function test_mintRevertsWhenNoSupply() external {
        (StreamMinter minter, MockStreamCoreForMinter core,) = _deployMinter();
        core.setMaxIndex(core.minIndex());
        core.setCirSupply(1);

        vm.prank(TDH_SIGNER);
        minter.setCollectionPhases(1, 1, block.timestamp + 1 days);

        address[] memory recipients = new address[](1);
        recipients[0] = RECIPIENT;
        string[] memory tokenData = new string[](1);
        tokenData[0] = "{}";
        uint256[] memory salts = new uint256[](1);
        salts[0] = 0;
        uint256[] memory qty = new uint256[](1);
        qty[0] = 1;

        vm.prank(STREAM_DROPS);
        vm.expectRevert(bytes("No supply"));
        minter.mint(recipients, tokenData, salts, 1, qty);
    }

    function test_mintAndAuctionSetsAuctionState() external {
        (StreamMinter minter, MockStreamCoreForMinter core,) = _deployMinter();

        vm.prank(TDH_SIGNER);
        minter.setCollectionPhases(1, 1, block.timestamp + 1 days);

        uint256 endTime = block.timestamp + 700;
        vm.prank(STREAM_DROPS);
        uint256 tokenId = minter.mintAndAuction(RECIPIENT, "{}", 0, 1, endTime);

        require(minter.getAuctionStatus(tokenId), "auction status should be true");
        require(minter.getAuctionEndTime(tokenId) == endTime, "auction end time should be set");
        require(tokenId == core.minIndex(), "first token should use min index");
    }

    function test_mintAndAuctionRequiresMinAuctionDuration() external {
        (StreamMinter minter,,) = _deployMinter();

        vm.prank(TDH_SIGNER);
        minter.setCollectionPhases(1, 1, block.timestamp + 1 days);

        vm.prank(STREAM_DROPS);
        vm.expectRevert(bytes(""));
        minter.mintAndAuction(RECIPIENT, "{}", 0, 1, block.timestamp + 599);
    }
}

