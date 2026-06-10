// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/StreamCore.sol";
import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";
import "./helpers/StreamFixture.sol";
import "./mocks/MockRandomizer.sol";

contract StreamDropsIntegrationCharacterizationTest is CharacterizationTestBase, StreamFixture {
    using Assertions for address;
    using Assertions for bool;
    using Assertions for bytes32;
    using Assertions for string;
    using Assertions for uint256;

    address private constant POSTER = address(0x1001);
    address private constant PAYOUT = address(0x2002);
    address private constant CURATORS_POOL = address(0x3003);

    function testFixedPriceDropCurrentlyPaysSynchronouslyAndMintsToTxOrigin() public {
        DeployedStream memory deployed = deployStream(PAYOUT, CURATORS_POOL);
        vm.deal(address(this), 10 ether);

        (, bytes32 expectedDropId) =
            deployed.drops.retrieveMessageAndDropID(POSTER, "data", 1, 1, 4 ether, 999);

        deployed.drops.mintDrop{ value: 4 ether }(POSTER, "data", 1, 1, 4 ether, 999);

        uint256 tokenId = 10_000_000_000;
        POSTER.balance.assertEq(2 ether, "poster payout changed");
        PAYOUT.balance.assertEq(1 ether, "protocol payout changed");
        CURATORS_POOL.balance.assertEq(1 ether, "curator payout changed");
        deployed.core.ownerOf(tokenId).assertEq(tx.origin, "recipient is no longer tx.origin");
        deployed.core.retrieveTokenHash(tokenId)
            .assertEq(keccak256(abi.encode(uint256(1), tokenId, uint256(0))), "token hash changed");
        deployed.core.tokenURI(tokenId).assertEq("ipfs://base/10000000000", "tokenURI changed");
        deployed.drops.retrieveDropID(tokenId).assertEq(expectedDropId, "drop id changed");
    }

    function testFixedPriceDropCurrentlyRevertsWhenPosterRejectsETH() public {
        RejectETH rejectPoster = new RejectETH();
        DeployedStream memory deployed = deployStream(PAYOUT, CURATORS_POOL);
        vm.deal(address(this), 10 ether);

        (bool success,) = address(deployed.drops).call{ value: 4 ether }(
            abi.encodeWithSelector(
                deployed.drops.mintDrop.selector,
                address(rejectPoster),
                "data",
                uint256(1),
                uint256(1),
                uint256(4 ether),
                uint256(999)
            )
        );

        success.assertFalse("rejecting poster did not revert");
        deployed.core.totalSupply().assertEq(0, "mint happened despite rejected poster payout");
    }

    function testFixedPriceDropCurrentlyRevertsWhenPayoutAddressRejectsETH() public {
        RejectETH rejectPayout = new RejectETH();
        DeployedStream memory deployed = deployStream(address(rejectPayout), CURATORS_POOL);
        vm.deal(address(this), 10 ether);

        (bool success,) = address(deployed.drops).call{ value: 4 ether }(
            abi.encodeWithSelector(
                deployed.drops.mintDrop.selector,
                POSTER,
                "data",
                uint256(1),
                uint256(1),
                uint256(4 ether),
                uint256(999)
            )
        );

        success.assertFalse("rejecting payout address did not revert");
        deployed.core.totalSupply().assertEq(0, "mint happened despite rejected payout");
    }

    function testFixedPriceDropCurrentlyRevertsWhenCuratorsPoolRejectsETH() public {
        RejectETH rejectCuratorsPool = new RejectETH();
        DeployedStream memory deployed = deployStream(PAYOUT, address(rejectCuratorsPool));
        vm.deal(address(this), 10 ether);

        (bool success,) = address(deployed.drops).call{ value: 4 ether }(
            abi.encodeWithSelector(
                deployed.drops.mintDrop.selector,
                POSTER,
                "data",
                uint256(1),
                uint256(1),
                uint256(4 ether),
                uint256(999)
            )
        );

        success.assertFalse("rejecting curators pool did not revert");
        deployed.core.totalSupply().assertEq(0, "mint happened despite rejected curator payout");
    }

    function testAuctionDropCurrentlyMintsCustodyToPayoutAndRecordsAuctionState() public {
        DeployedStream memory deployed = deployStream(PAYOUT, CURATORS_POOL);
        uint256 auctionEndTime = block.timestamp + 1 days;

        (, bytes32 expectedDropId) = deployed.drops
            .retrieveMessageAndDropID(POSTER, "auction-data", 1, 2, 5 ether, auctionEndTime);

        deployed.drops.mintDrop(POSTER, "auction-data", 1, 2, 5 ether, auctionEndTime);

        uint256 tokenId = 10_000_000_000;
        deployed.core.ownerOf(tokenId).assertEq(PAYOUT, "auction custody recipient changed");
        deployed.minter.getAuctionStatus(tokenId).assertTrue("auction status changed");
        deployed.minter.getAuctionEndTime(tokenId)
            .assertEq(auctionEndTime, "auction end time changed");
        deployed.drops.retrieveAuctionPoster(tokenId).assertEq(POSTER, "auction poster changed");
        deployed.drops.retrieveAuctionPrice(tokenId)
            .assertEq(5 ether, "auction starting price changed");
        deployed.drops.retrieveDropID(tokenId).assertEq(expectedDropId, "auction drop id changed");
        deployed.drops.retrieveExecutionAddress(tokenId)
            .assertEq(tx.origin, "auction execution changed");
    }

    function testPendingMetadataCurrentlyUsesPendingSuffixWhenRandomizerDoesNothing() public {
        DeployedStream memory deployed = deployStream(PAYOUT, CURATORS_POOL);
        NoopRandomizer noopRandomizer = new NoopRandomizer();
        deployed.core.addRandomizer(1, address(noopRandomizer));
        vm.deal(address(this), 1 ether);

        deployed.drops.mintDrop(POSTER, "data", 1, 1, 0, 999);

        uint256 tokenId = 10_000_000_000;
        deployed.core.retrieveTokenHash(tokenId).assertEq(bytes32(0), "noop hash changed");
        deployed.core.tokenURI(tokenId).assertEq("ipfs://base/pending", "pending URI changed");
    }

    function testSetTokenHashCurrentlyAllowsConfiguredRandomizerOnlyAndOnlyOnce() public {
        DeployedStream memory deployed = deployStream(PAYOUT, CURATORS_POOL);
        NoopRandomizer noopRandomizer = new NoopRandomizer();
        deployed.core.addRandomizer(1, address(noopRandomizer));
        uint256 tokenId = 10_000_000_000;

        vm.deal(address(this), 1 ether);
        deployed.drops.mintDrop(POSTER, "data", 1, 1, 0, 999);
        deployed.core.retrieveTokenHash(tokenId).assertEq(bytes32(0), "noop hash changed");

        (bool nonRandomizerSuccess,) = address(deployed.core)
            .call(
                abi.encodeWithSelector(
                    deployed.core.setTokenHash.selector, uint256(1), tokenId, bytes32(uint256(1))
                )
            );
        nonRandomizerSuccess.assertFalse("non-randomizer set token hash");
        deployed.core.retrieveTokenHash(tokenId).assertEq(bytes32(0), "non-randomizer changed hash");

        deployed.core.addRandomizer(1, address(deployed.randomizer));
        deployed.randomizer.calculateTokenHash(1, tokenId, 123);
        bytes32 firstHash = deployed.core.retrieveTokenHash(tokenId);
        (firstHash == bytes32(0)).assertFalse("randomizer did not set hash");

        (bool secondSetSuccess,) = address(deployed.randomizer)
            .call(
                abi.encodeWithSelector(
                    deployed.randomizer.calculateTokenHash.selector,
                    uint256(1),
                    tokenId,
                    uint256(123)
                )
            );
        secondSetSuccess.assertFalse("token hash was overwritten");
        deployed.core.retrieveTokenHash(tokenId)
            .assertEq(firstHash, "hash changed after second set");
    }
}
