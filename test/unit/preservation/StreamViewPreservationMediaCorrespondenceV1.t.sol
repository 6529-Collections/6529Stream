// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    CharacterizationTestBase
} from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    StreamViewPreservationMediaCorrespondenceV1 as Media
} from "../../../smart-contracts/domains/preservation/StreamViewPreservationMediaCorrespondenceV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

contract StreamViewPreservationMediaCorrespondenceV1Test is CharacterizationTestBase {
    string private constant URI =
        "ipfs://bafkreifjghpwdjrr5mgxn5pdwr52mivwmzphuoo7oy7qxajv27di3hggj4";

    function testLiteralRawFileDigestAndUnknownLengthDoNotClaimAvailability() public pure {
        T.Item memory r = Media.item(address(123), bytes32(uint256(456)), URI);
        require(r.kind == T.Kind.EXTERNAL_REFERENCE && r.algorithm == 2 && r.byteSize == 0);
        require(r.source == address(123) && r.sourceRecord == bytes32(uint256(456)));
        require(
            keccak256(r.digest)
                == keccak256(
                    abi.encodePacked(
                        bytes32(0xa931df61a631eb0d76f5e3b47ba622b6665e7a39df763f0b8135d7c68d9cc64f)
                    )
                )
        );
        require(
            r.canonicalizationId == keccak256("RAW_BYTES")
                && keccak256(bytes(r.uri)) == keccak256(bytes(URI))
        );
        require(r.objectHash == 0 && r.originalCoverageHash == 0 && r.provenanceHash == 0);
    }

    function testEmptyImageIsExplicitAbsence() public pure {
        T.Item memory r = Media.item(address(123), bytes32(uint256(456)), "");
        require(
            r.kind == T.Kind.ABSENT && r.digest.length == 0 && r.algorithm == 0 && r.byteSize == 0
                && bytes(r.uri).length == 0
        );
    }

    function testHttpArDAGPBAndInlineAreExplicitlyUnsupported() public {
        _refuses("https://example.invalid/image.png");
        _refuses("ar://transaction-id");
        _refuses("ipfs://QmYwAPJzv5CZsnAzt8auVZRnGi2CrtmBBknJEhGJZGRCwD");
        _refuses("data:image/png;base64,iVBORw0KGgo=");
        bytes memory wrong = bytes(URI);
        wrong[10] = "y";
        _refuses(string(wrong));
    }

    function testPathQueryUppercaseAndTrailingPaddingCannotAlias() public {
        _refuses(string.concat(URI, "/image"));
        _refuses(string.concat(URI, "?x=1"));
        bytes memory wrong = bytes(URI);
        wrong[8] = "B";
        _refuses(string(wrong));
        wrong = bytes(URI);
        wrong[65] = "b";
        _refuses(string(wrong));
        wrong = bytes(URI);
        wrong[30] = "0";
        _refuses(string(wrong));
    }

    function _refuses(string memory uri) private {
        vm.expectRevert(
            abi.encodeWithSelector(Media.UnsupportedViewMediaURI.selector, keccak256(bytes(uri)))
        );
        Media.item(address(123), bytes32(uint256(456)), uri);
    }
}
