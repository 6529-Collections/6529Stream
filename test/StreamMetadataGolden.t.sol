// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/StreamCore.sol";
import "../smart-contracts/Strings.sol";
import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";
import "./helpers/StreamFixture.sol";
// MockRandomizer.sol also defines NoopRandomizer, used here to hold pending state.
import "./mocks/MockRandomizer.sol";

contract StreamMetadataGoldenTest is CharacterizationTestBase, StreamFixture {
    using Assertions for bool;
    using Assertions for bytes32;
    using Assertions for string;

    uint256 private constant COLLECTION_ID = 1;
    uint256 private constant TOKEN_ID = 10_000_000_000;
    address private constant RECIPIENT = address(0xA11CE);
    string private constant TOKEN_DATA = "1,2,3";
    uint256 private constant TOKEN_SALT = 7;

    function testOffchainPendingTokenUriMatchesGoldenFile() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        NoopRandomizer noopRandomizer = new NoopRandomizer();
        deployed.core.addRandomizer(COLLECTION_ID, address(noopRandomizer));

        _mintGoldenToken(deployed);

        deployed.core.retrieveTokenHash(TOKEN_ID).assertEq(bytes32(0), "pending hash changed");
        _assertMatchesFixture(
            deployed.core.tokenURI(TOKEN_ID),
            "test/fixtures/metadata/offchain-pending-token-uri.txt",
            "off-chain pending tokenURI"
        );
    }

    function testOffchainFinalTokenUriMatchesGoldenFile() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));

        _mintGoldenToken(deployed);

        (deployed.core.retrieveTokenHash(TOKEN_ID) != bytes32(0)).assertTrue("expected final hash");
        _assertMatchesFixture(
            deployed.core.tokenURI(TOKEN_ID),
            "test/fixtures/metadata/offchain-final-token-uri.txt",
            "off-chain final tokenURI"
        );
    }

    function testCurrentOnchainPendingTokenUriMatchesGoldenFile() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        NoopRandomizer noopRandomizer = new NoopRandomizer();
        deployed.core.addRandomizer(COLLECTION_ID, address(noopRandomizer));

        _mintGoldenToken(deployed);
        _setGoldenTokenMetadataInputs(deployed.core);
        deployed.core.changeMetadataView(COLLECTION_ID, true);

        deployed.core.retrieveTokenHash(TOKEN_ID).assertEq(bytes32(0), "pending hash changed");
        _assertMatchesFixture(
            deployed.core.tokenURI(TOKEN_ID),
            "test/fixtures/metadata/current-onchain-pending-token-uri.txt",
            "current on-chain pending tokenURI"
        );
    }

    function testCurrentOnchainFinalTokenUriMatchesGoldenFile() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));

        _mintGoldenToken(deployed);
        _setGoldenTokenMetadataInputs(deployed.core);
        deployed.core.changeMetadataView(COLLECTION_ID, true);

        (deployed.core.retrieveTokenHash(TOKEN_ID) != bytes32(0)).assertTrue("expected final hash");
        _assertMatchesFixture(
            deployed.core.tokenURI(TOKEN_ID),
            "test/fixtures/metadata/current-onchain-final-token-uri.txt",
            "current on-chain final tokenURI"
        );
    }

    function _mintGoldenToken(DeployedStream memory deployed) private {
        vm.prank(address(deployed.minter));
        deployed.core.mint(TOKEN_ID, RECIPIENT, TOKEN_DATA, TOKEN_SALT, COLLECTION_ID);
    }

    function _setGoldenTokenMetadataInputs(StreamCore core) private {
        uint256[] memory tokenIds = new uint256[](1);
        string[] memory images = new string[](1);
        string[] memory attributes = new string[](1);

        tokenIds[0] = TOKEN_ID;
        images[0] = string.concat("ipfs://image/", Strings.toString(TOKEN_ID), ".png");
        attributes[0] = "{\"trait_type\":\"Mood\",\"value\":\"Calm\"}";

        core.updateImagesAndAttributes(tokenIds, images, attributes);
    }

    function _assertMatchesFixture(
        string memory actual,
        string memory fixturePath,
        string memory message
    ) private view {
        _trimTrailingLineEnding(vm.readFile(fixturePath)).assertEq(actual, message);
    }

    function _trimTrailingLineEnding(string memory raw) private pure returns (string memory) {
        bytes memory rawBytes = bytes(raw);
        uint256 trimmedLength = rawBytes.length;

        while (
            trimmedLength > 0
                && (rawBytes[trimmedLength - 1] == 0x0a || rawBytes[trimmedLength - 1] == 0x0d)
        ) {
            trimmedLength--;
        }

        bytes memory trimmed = new bytes(trimmedLength);
        for (uint256 i = 0; i < trimmedLength; i++) {
            trimmed[i] = rawBytes[i];
        }

        return string(trimmed);
    }
}
