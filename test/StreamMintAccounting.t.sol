// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";
import "./helpers/StreamFixture.sol";

contract StreamMintAccountingTest is CharacterizationTestBase, StreamFixture {
    using Assertions for bool;
    using Assertions for uint256;

    uint256 private constant COLLECTION_ID = 1;
    uint256 private constant TOKEN_ID = 10_000_000_000;
    address private constant RECIPIENT = address(0xA11CE);

    function testRetainedAirdropMintCounterStartsAtZeroAndIncrements() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));

        deployed.core.retrieveTokensAirdroppedPerAddress(COLLECTION_ID, RECIPIENT)
            .assertEq(0, "unexpected initial airdrop count");

        vm.prank(address(deployed.minter));
        deployed.core.mint(TOKEN_ID, RECIPIENT, "token-a", 111, COLLECTION_ID);

        deployed.core.retrieveTokensAirdroppedPerAddress(COLLECTION_ID, RECIPIENT)
            .assertEq(1, "first mint not counted");

        vm.prank(address(deployed.minter));
        deployed.core.mint(TOKEN_ID + 1, RECIPIENT, "token-b", 222, COLLECTION_ID);

        deployed.core.retrieveTokensAirdroppedPerAddress(COLLECTION_ID, RECIPIENT)
            .assertEq(2, "second mint not counted");
    }

    function testUnauthorizedMintDoesNotIncrementRetainedAirdropCounter() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));

        vm.prank(address(0xB0B));
        (bool success,) = address(deployed.core)
            .call(
                abi.encodeWithSelector(
                    deployed.core.mint.selector, TOKEN_ID, RECIPIENT, "token-a", 111, COLLECTION_ID
                )
            );
        success.assertFalse("unauthorized mint succeeded");

        deployed.core.retrieveTokensAirdroppedPerAddress(COLLECTION_ID, RECIPIENT)
            .assertEq(0, "failed mint changed airdrop count");
    }

    function testSupplyExhaustedMintAfterBurnDoesNotAdvanceUncheckedCounters() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        for (uint256 i = 0; i < 10; i++) {
            _mintToken(deployed, TOKEN_ID + i, i + 1);
        }

        vm.prank(RECIPIENT);
        deployed.core.burn(COLLECTION_ID, TOKEN_ID);

        vm.expectRevert(abi.encodeWithSelector(StreamCore.CollectionSupplyReached.selector));
        _mintToken(deployed, TOKEN_ID + 10, 11);

        deployed.core.viewCirSupply(COLLECTION_ID).assertEq(10, "failed mint advanced circulation");
        deployed.core.totalSupplyOfCollection(COLLECTION_ID)
            .assertEq(9, "failed mint changed live supply");
        deployed.core.burnAmount(COLLECTION_ID).assertEq(1, "burn count drifted");
        deployed.core.retrieveTokensAirdroppedPerAddress(COLLECTION_ID, RECIPIENT)
            .assertEq(10, "failed mint advanced airdrop count");
    }

    function testFinalSupplyUsesMintedEverNotLiveSupplyAfterBurn() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        _mintToken(deployed, TOKEN_ID, 1);
        _mintToken(deployed, TOKEN_ID + 1, 2);

        vm.prank(RECIPIENT);
        deployed.core.burn(COLLECTION_ID, TOKEN_ID);
        _warpPastFinalSupplyWindow();

        deployed.core.setFinalSupply(COLLECTION_ID);

        (,, uint256 circulationSupply, uint256 collectionTotalSupply,,) =
            deployed.core.retrieveCollectionAdditionalData(COLLECTION_ID);
        circulationSupply.assertEq(2, "circulation should remain minted-ever");
        collectionTotalSupply.assertEq(2, "final supply should use minted-ever");
        deployed.core.viewTokensIndexMax(COLLECTION_ID)
            .assertEq(TOKEN_ID + 1, "max token id should remain minted-ever boundary");
        deployed.core.totalSupplyOfCollection(COLLECTION_ID)
            .assertEq(1, "live supply should exclude burned token");
    }

    function testRepeatedFinalSupplyDoesNotDriftUncheckedBounds() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        _mintToken(deployed, TOKEN_ID, 1);
        _mintToken(deployed, TOKEN_ID + 1, 2);

        vm.prank(RECIPIENT);
        deployed.core.burn(COLLECTION_ID, TOKEN_ID);
        _warpPastFinalSupplyWindow();

        deployed.core.setFinalSupply(COLLECTION_ID);
        deployed.core.setFinalSupply(COLLECTION_ID);

        (,, uint256 circulationSupply, uint256 collectionTotalSupply,,) =
            deployed.core.retrieveCollectionAdditionalData(COLLECTION_ID);
        circulationSupply.assertEq(2, "circulation drifted");
        collectionTotalSupply.assertEq(2, "final supply drifted");
        deployed.core.viewTokensIndexMax(COLLECTION_ID).assertEq(TOKEN_ID + 1, "max drifted");
        deployed.core.totalSupplyOfCollection(COLLECTION_ID).assertEq(1, "live supply drifted");
        deployed.core.burnAmount(COLLECTION_ID).assertEq(1, "burn count drifted");
    }

    function _mintToken(DeployedStream memory deployed, uint256 tokenId, uint256 salt) private {
        vm.prank(address(deployed.minter));
        deployed.core.mint(tokenId, RECIPIENT, "token", salt, COLLECTION_ID);
    }

    function _warpPastFinalSupplyWindow() private {
        vm.warp(block.timestamp + 31 days + 1);
    }
}
