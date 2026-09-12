// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../../smart-contracts/domains/metadata/StreamMetadataImageURI.sol";

/// @notice Tests raster admission signatures and encoding, not complete image-file validity.
contract StreamMetadataImageURITest is CharacterizationTestBase {
    function validate(string calldata uri) external pure {
        StreamMetadataImageURI.requireImageURI(uri);
    }

    function testExistingExternalSchemesAndEmptyRemainAdmitted() public pure {
        StreamMetadataImageURI.requireImageURI("");
        StreamMetadataImageURI.requireImageURI("https://example.com/image.png");
        StreamMetadataImageURI.requireImageURI("ipfs://bafyexample/image");
        StreamMetadataImageURI.requireImageURI("ar://example-image");
    }

    function testAllFourRasterSignaturesAreAdmitted() public pure {
        _accept("png", hex"89504e470d0a1a0a");
        _accept("jpeg", hex"ffd8ff");
        _accept("gif", bytes("GIF87a"));
        _accept("gif", bytes("GIF89a"));
        _accept("webp", hex"524946460000000057454250");
    }

    function testNoPaddingOnePaddingAndTwoPaddingAreCanonical() public pure {
        _accept("png", hex"89504e470d0a1a0a00");
        _accept("png", hex"89504e470d0a1a0a");
        _accept("png", hex"89504e470d0a1a0a0000");
    }

    function testNoncanonicalPaddingBitsAndPaddingPlacementReject() public {
        _reject("data:image/png;base64,iVBORw0KGgp=");
        _reject("data:image/png;base64,iVBORw0KGgo");
        _reject("data:image/png;base64,iVBORw0KGgo==");
        _reject("data:image/png;base64,iV=ORw0KGgo=");
        _reject("data:image/png;base64,iVBORw0KGg=o");
        _reject("data:image/png;base64,iVBORw0KGgo=AAAA");
    }

    function testWhitespaceInvalidAlphabetAndEmptyReject() public {
        _reject("data:image/png;base64,");
        _reject("data:image/png;base64,iVBORw0KGgo= ");
        _reject("data:image/png;base64,iVBORw0K\nGgo=");
        _reject("data:image/png;base64,iVBORw0KGg_=");
        _reject("data:image/png;base64,iVBORw0KGgo\x00");
    }

    function testSvgHtmlMimeParametersAndWrongCaseReject() public {
        _reject("data:image/svg+xml;base64,iVBORw0KGgo=");
        _reject("data:text/html;base64,iVBORw0KGgo=");
        _reject("data:image/png;charset=utf-8;base64,iVBORw0KGgo=");
        _reject("data:IMAGE/PNG;base64,iVBORw0KGgo=");
        _reject("data:image/png;BASE64,iVBORw0KGgo=");
        _reject("javascript:alert(1)");
    }

    function testWrongOrTruncatedSignatureRejects() public {
        _reject("data:image/png;base64,/9j/");
        _reject("data:image/jpeg;base64,iVBORw0KGgo=");
        _reject("data:image/png;base64,iVBORw0KGg==");
        _reject(string.concat("data:image/webp;base64,", Base64.encode(bytes("RIFF0000HTML"))));
        _reject(string.concat("data:image/gif;base64,", Base64.encode(bytes("GIF90a"))));
    }

    function testOriginal2048ByteLimitIsPreserved() public {
        // 1,518 decoded bytes yield a 2,046-byte PNG URI. The next 3-byte quantum exceeds 2,048.
        bytes memory payload = new bytes(1518);
        bytes memory signature = hex"89504e470d0a1a0a";
        for (uint256 i; i < signature.length; ++i) {
            payload[i] = signature[i];
        }
        _accept("png", payload);
        string memory oversized = string.concat(
            "data:image/png;base64,", Base64.encode(bytes.concat(payload, hex"000000"))
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRenderer.MetadataFieldTooLarge.selector,
                bytes32("image"),
                uint256(2050),
                uint256(2048)
            )
        );
        this.validate(oversized);
    }

    function testFuzzRasterBase64RoundTrip(bytes memory suffix) public pure {
        if (suffix.length > 512) return;
        _accept("png", bytes.concat(hex"89504e470d0a1a0a", suffix));
    }

    function _accept(string memory kind, bytes memory payload) private pure {
        StreamMetadataImageURI.requireImageURI(
            string.concat("data:image/", kind, ";base64,", Base64.encode(payload))
        );
    }

    function _reject(string memory uri) private {
        vm.expectRevert(abi.encodeWithSelector(StreamMetadataRenderer.UnsafeMetadataURI.selector));
        this.validate(uri);
    }
}
