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
    address private constant PAYOUT = address(0x2002);
    address private constant CURATORS_POOL = address(0x3003);
    address private constant ADMINS = address(0x4004);

    function testRetrieveMessageAndDropIdUsesCurrentPackedEncoding() public {
        MockStreamMinter minter = new MockStreamMinter();
        StreamDrops drops =
            new StreamDrops(address(this), address(minter), ADMINS, PAYOUT, CURATORS_POOL);

        (string memory message, bytes32 dropId) =
            drops.retrieveMessageAndDropID(POSTER, "data", 1, 1, 10, 999);

        string memory expectedMessage = "0x0000000000000000000000000000000000001001data1110999";
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

    function testFixedPriceDropRecordsCurrentExecutionAndMintsToTxOrigin() public {
        MockStreamMinter minter = new MockStreamMinter();
        StreamDrops drops =
            new StreamDrops(address(this), address(minter), ADMINS, PAYOUT, CURATORS_POOL);

        (, bytes32 expectedDropId) = drops.retrieveMessageAndDropID(POSTER, "data", 1, 1, 0, 999);

        drops.mintDrop(POSTER, "data", 1, 1, 0, 999);

        uint256 tokenId = 1_000_000_000;
        bytes32[] memory allDrops = drops.retrieveDrops();
        allDrops.length.assertEq(1, "drop count changed");
        allDrops[0].assertEq(expectedDropId, "stored drop id changed");
        drops.retrieveDropID(tokenId).assertEq(expectedDropId, "token drop id changed");
        drops.retrieveTokenID(expectedDropId).assertEq(tokenId, "drop token id changed");
        drops.retrieveExecutionAddress(tokenId).assertEq(tx.origin, "execution address changed");
        minter.lastRecipient().assertEq(tx.origin, "fixed-price recipient changed");
        minter.lastTokenData().assertEq("data", "token data changed");
        minter.lastMintBatchLength().assertEq(1, "mint batch length changed");
        minter.lastTotalNumberOfTokens().assertEq(1, "mint token count changed");

        (uint256 storedTokenId, address signer, address poster, address execution) =
            drops.retrieveDropInfo(expectedDropId);
        storedTokenId.assertEq(tokenId, "drop info token id changed");
        signer.assertEq(address(this), "drop signer changed");
        poster.assertEq(POSTER, "drop poster changed");
        execution.assertEq(tx.origin, "drop execution changed");
    }

    function testDropIdReplayIsRejectedAfterFirstExecution() public {
        MockStreamMinter minter = new MockStreamMinter();
        StreamDrops drops =
            new StreamDrops(address(this), address(minter), ADMINS, PAYOUT, CURATORS_POOL);

        drops.mintDrop(POSTER, "data", 1, 1, 0, 999);
        (bool success,) = address(drops)
            .call(
                abi.encodeWithSelector(
                    drops.mintDrop.selector,
                    POSTER,
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

        (, bytes32 expectedDropId) =
            drops.retrieveMessageAndDropID(POSTER, "auction-data", 7, 2, 5 ether, auctionEndTime);

        drops.mintDrop(POSTER, "auction-data", 7, 2, 5 ether, auctionEndTime);

        uint256 tokenId = 1_000_000_000;
        minter.lastAuctionRecipient().assertEq(PAYOUT, "auction custody recipient changed");
        minter.lastAuctionTokenData().assertEq("auction-data", "auction token data changed");
        minter.lastAuctionCollectionId().assertEq(7, "auction collection changed");
        minter.lastAuctionEndTime().assertEq(auctionEndTime, "auction end time changed");
        drops.retrieveAuctionPoster(tokenId).assertEq(POSTER, "auction poster changed");
        drops.retrieveAuctionPrice(tokenId).assertEq(5 ether, "auction starting price changed");
        drops.retrieveDropID(tokenId).assertEq(expectedDropId, "auction drop id changed");
    }
}
