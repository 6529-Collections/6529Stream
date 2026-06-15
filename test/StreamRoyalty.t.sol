// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";
import "./helpers/StreamFixture.sol";

contract StreamRoyaltyTest is CharacterizationTestBase, StreamFixture {
    using Assertions for address;
    using Assertions for bool;
    using Assertions for uint256;

    bytes4 private constant ERC2981_INTERFACE_ID = 0x2a55205a;
    address private constant ROYALTY_RECEIVER = 0xC8ed02aFEBD9aCB14c33B5330c803feacAF01377;

    function testSupportsErc2981Interface() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));

        deployed.core.supportsInterface(ERC2981_INTERFACE_ID).assertTrue("missing ERC-2981");
    }

    function testDefaultRoyaltyIsFixedAt690BasisPoints() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));

        (address receiver, uint256 royaltyAmount) =
            deployed.core.royaltyInfo(10_000_000_000, 1 ether);

        receiver.assertEq(ROYALTY_RECEIVER, "royalty receiver");
        royaltyAmount.assertEq(0.069 ether, "royalty amount");
    }

    function testDefaultRoyaltyAppliesToArbitraryTokenIds() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));

        (address firstReceiver, uint256 firstAmount) = deployed.core.royaltyInfo(1, 10_000);
        (address secondReceiver, uint256 secondAmount) = deployed.core.royaltyInfo(999_999, 10_000);

        firstReceiver.assertEq(ROYALTY_RECEIVER, "first receiver");
        secondReceiver.assertEq(ROYALTY_RECEIVER, "second receiver");
        firstAmount.assertEq(690, "first amount");
        secondAmount.assertEq(690, "second amount");
    }

    function testZeroSalePriceHasZeroRoyaltyAmount() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));

        (address receiver, uint256 royaltyAmount) = deployed.core.royaltyInfo(1, 0);

        receiver.assertEq(ROYALTY_RECEIVER, "royalty receiver");
        royaltyAmount.assertEq(0, "zero sale royalty");
    }
}
