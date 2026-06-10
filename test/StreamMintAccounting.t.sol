// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";
import "./helpers/StreamFixture.sol";

contract StreamMintAccountingTest is CharacterizationTestBase, StreamFixture {
    using Assertions for bool;
    using Assertions for uint256;

    function testRetainedAirdropMintCounterStartsAtZeroAndIncrements() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        address recipient = address(0xA11CE);
        uint256 collectionId = 1;

        deployed.core.retrieveTokensAirdroppedPerAddress(collectionId, recipient)
            .assertEq(0, "unexpected initial airdrop count");

        vm.prank(address(deployed.minter));
        deployed.core.mint(10_000_000_000, recipient, "token-a", 111, collectionId);

        deployed.core.retrieveTokensAirdroppedPerAddress(collectionId, recipient)
            .assertEq(1, "first mint not counted");

        vm.prank(address(deployed.minter));
        deployed.core.mint(10_000_000_001, recipient, "token-b", 222, collectionId);

        deployed.core.retrieveTokensAirdroppedPerAddress(collectionId, recipient)
            .assertEq(2, "second mint not counted");
    }

    function testUnauthorizedMintDoesNotIncrementRetainedAirdropCounter() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        address recipient = address(0xA11CE);
        uint256 collectionId = 1;

        vm.prank(address(0xB0B));
        (bool success,) = address(deployed.core)
            .call(
                abi.encodeWithSelector(
                    deployed.core.mint.selector,
                    10_000_000_000,
                    recipient,
                    "token-a",
                    111,
                    collectionId
                )
            );
        success.assertFalse("unauthorized mint succeeded");

        deployed.core.retrieveTokensAirdroppedPerAddress(collectionId, recipient)
            .assertEq(0, "failed mint changed airdrop count");
    }
}
