// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/StreamDrops.sol";
import "./helpers/Assertions.sol";
import "./mocks/MockStreamMinter.sol";

contract StreamDropsCharacterizationTest {
    using Assertions for address;
    using Assertions for bool;
    using Assertions for bytes32;
    using Assertions for string;
    using Assertions for uint256;

    address private constant POSTER = address(0x1001);
    address private constant RECIPIENT = address(0x5005);
    address private constant PAYOUT = address(0x2002);
    address private constant CURATORS_POOL = address(0x3003);
    address private constant ADMINS = address(0x4004);

    function testRetrieveMessageAndDropIdUsesCurrentPackedEncoding() public {
        MockStreamMinter minter = new MockStreamMinter();
        StreamDrops drops =
            new StreamDrops(address(this), address(minter), ADMINS, PAYOUT, CURATORS_POOL);

        (string memory message, bytes32 dropId) =
            drops.retrieveMessageAndDropID(POSTER, RECIPIENT, "data", 1, 1, 10, 999);

        string memory expectedMessage =
            "0x00000000000000000000000000000000000010010x0000000000000000000000000000000000005005data1110999";
        message.assertEq(expectedMessage, "message changed");
        dropId.assertEq(keccak256(abi.encodePacked(expectedMessage)), "drop id changed");
    }

    function testMintDropRequiresCurrentTdhSignerCaller() public {
        MockStreamMinter minter = new MockStreamMinter();
        StreamDrops drops =
            new StreamDrops(address(0xBEEF), address(minter), ADMINS, PAYOUT, CURATORS_POOL);

        (bool success,) = address(drops)
            .call(
                abi.encodeWithSelector(
                    drops.mintDrop.selector,
                    POSTER,
                    RECIPIENT,
                    "data",
                    uint256(1),
                    uint256(1),
                    uint256(0),
                    uint256(999)
                )
            );

        success.assertFalse("non-signer minted drop");
        drops.retrieveDrops().length.assertEq(0, "drop should not be recorded");
    }

    function testFixedPriceDropRecordsExplicitRecipientAndExecutionAddress() public {
        MockStreamMinter minter = new MockStreamMinter();
        StreamDrops drops =
            new StreamDrops(address(this), address(minter), ADMINS, PAYOUT, CURATORS_POOL);

        (, bytes32 expectedDropId) =
            drops.retrieveMessageAndDropID(POSTER, RECIPIENT, "data", 1, 1, 0, 999);

        drops.mintDrop(POSTER, RECIPIENT, "data", 1, 1, 0, 999);

        uint256 tokenId = 1_000_000_000;
        bytes32[] memory allDrops = drops.retrieveDrops();
        allDrops.length.assertEq(1, "drop count changed");
        allDrops[0].assertEq(expectedDropId, "stored drop id changed");
        drops.retrieveDropID(tokenId).assertEq(expectedDropId, "token drop id changed");
        drops.retrieveTokenID(expectedDropId).assertEq(tokenId, "drop token id changed");
        drops.retrieveExecutionAddress(tokenId).assertEq(RECIPIENT, "execution address changed");
        minter.lastRecipient().assertEq(RECIPIENT, "fixed-price recipient changed");
        minter.lastTokenData().assertEq("data", "token data changed");
        minter.lastMintBatchLength().assertEq(1, "mint batch length changed");
        minter.lastTotalNumberOfTokens().assertEq(1, "mint token count changed");

        (uint256 storedTokenId, address signer, address poster, address execution) =
            drops.retrieveDropInfo(expectedDropId);
        storedTokenId.assertEq(tokenId, "drop info token id changed");
        signer.assertEq(address(this), "drop signer changed");
        poster.assertEq(POSTER, "drop poster changed");
        execution.assertEq(RECIPIENT, "drop execution changed");
    }

    function testFixedPriceDropRejectsZeroRecipient() public {
        MockStreamMinter minter = new MockStreamMinter();
        StreamDrops drops =
            new StreamDrops(address(this), address(minter), ADMINS, PAYOUT, CURATORS_POOL);

        (bool success,) = address(drops)
            .call(
                abi.encodeWithSelector(
                    drops.mintDrop.selector,
                    POSTER,
                    address(0),
                    "data",
                    uint256(1),
                    uint256(1),
                    uint256(0),
                    uint256(999)
                )
            );

        success.assertFalse("zero recipient minted fixed-price drop");
        drops.retrieveDrops().length.assertEq(0, "zero recipient recorded drop");
    }

    function testDropIdReplayIsRejectedAfterFirstExecution() public {
        MockStreamMinter minter = new MockStreamMinter();
        StreamDrops drops =
            new StreamDrops(address(this), address(minter), ADMINS, PAYOUT, CURATORS_POOL);

        drops.mintDrop(POSTER, RECIPIENT, "data", 1, 1, 0, 999);
        (bool success,) = address(drops)
            .call(
                abi.encodeWithSelector(
                    drops.mintDrop.selector,
                    POSTER,
                    RECIPIENT,
                    "data",
                    uint256(1),
                    uint256(1),
                    uint256(0),
                    uint256(999)
                )
            );

        success.assertFalse("drop replay succeeded");
        drops.retrieveDrops().length.assertEq(1, "replay changed drop count");
    }

    function testAuctionDropMintsCurrentCustodyToPayoutAndStoresPosterPrice() public {
        MockStreamMinter minter = new MockStreamMinter();
        StreamDrops drops =
            new StreamDrops(address(this), address(minter), ADMINS, PAYOUT, CURATORS_POOL);
        uint256 auctionEndTime = block.timestamp + 1 days;

        (, bytes32 expectedDropId) = drops.retrieveMessageAndDropID(
            POSTER, address(0), "auction-data", 7, 2, 5 ether, auctionEndTime
        );

        drops.mintDrop(POSTER, address(0), "auction-data", 7, 2, 5 ether, auctionEndTime);

        uint256 tokenId = 1_000_000_000;
        minter.lastAuctionRecipient().assertEq(PAYOUT, "auction custody recipient changed");
        minter.lastAuctionTokenData().assertEq("auction-data", "auction token data changed");
        minter.lastAuctionCollectionId().assertEq(7, "auction collection changed");
        minter.lastAuctionEndTime().assertEq(auctionEndTime, "auction end time changed");
        drops.retrieveAuctionPoster(tokenId).assertEq(POSTER, "auction poster changed");
        drops.retrieveAuctionPrice(tokenId).assertEq(5 ether, "auction starting price changed");
        drops.retrieveDropID(tokenId).assertEq(expectedDropId, "auction drop id changed");
        drops.retrieveExecutionAddress(tokenId).assertEq(POSTER, "auction execution changed");
    }

    function testAuctionDropRejectsNonZeroRecipient() public {
        MockStreamMinter minter = new MockStreamMinter();
        StreamDrops drops =
            new StreamDrops(address(this), address(minter), ADMINS, PAYOUT, CURATORS_POOL);
        uint256 auctionEndTime = block.timestamp + 1 days;

        (bool success,) = address(drops)
            .call(
                abi.encodeWithSelector(
                    drops.mintDrop.selector,
                    POSTER,
                    RECIPIENT,
                    "auction-data",
                    uint256(7),
                    uint256(2),
                    uint256(5 ether),
                    auctionEndTime
                )
            );

        success.assertFalse("non-zero auction recipient minted");
        drops.retrieveDrops().length.assertEq(0, "non-zero auction recipient recorded drop");
    }
}
