// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/StaticMetadataRoutingFixture.sol";
import {
    StreamStaticText as Text
} from "../../../smart-contracts/domains/metadata/StreamStaticText.sol";
import {
    StreamMetadataRenderer as OriginalText
} from "../../../smart-contracts/domains/metadata/StreamMetadataRenderer.sol";

/// @dev Uses actual fixed formatter and renderer; shared governance/Core/Artist boundaries remain explicit.
contract StreamStaticFormattingTransportTest is StaticMetadataRoutingFixture {
    function testPureFormatterRuntimePinAndExactRestoration() public {
        _activate();
        _mint();
        bytes32 prior = keccak256(bytes(router.tokenJSON(91)));
        (address encoding, bytes32 hash) = renderer.encodingBinding();
        bytes memory code = encoding.code;
        require(keccak256(code) == hash);
        vm.etch(encoding, hex"60006000fd");
        vm.expectRevert();
        router.tokenJSON(91);
        vm.etch(encoding, code);
        require(keccak256(bytes(router.tokenJSON(91))) == prior);
    }

    function testUTF8AndEscapingAcrossEveryWordBoundary() public pure {
        for (uint256 n; n < 65; ++n) {
            bytes memory prefix = new bytes(n);
            for (uint256 j; j < n; ++j) {
                prefix[j] = 0x61;
            }
            _parity(string(bytes.concat(prefix, hex"f09f8ea8c2a2e282ac225c0a00")));
            _parity(string(bytes.concat(prefix, hex"f09f")));
            _parity(string(bytes.concat(prefix, hex"eda080")));
        }
    }

    function testFuzzOriginalUTF8AndJSONParity(string memory value) public pure {
        if (bytes(value).length <= 4096) _parity(value);
    }

    function _parity(string memory value) private pure {
        require(Text.isValidUtf8(value) == OriginalText.isValidUtf8(value), "original UTF8 rules");
        require(
            keccak256(bytes(Text.escapeJsonString(value)))
                == keccak256(bytes(OriginalText.escapeJsonString(value))),
            "original escaping bytes"
        );
    }
}
