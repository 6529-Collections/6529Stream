// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamStaticText as Text
} from "../../../smart-contracts/domains/metadata/StreamStaticText.sol";
import {
    StreamStaticContentBytes as Fields
} from "../../../smart-contracts/domains/finality/StreamStaticContentBytes.sol";
import { FrozenStreamStaticText as OldText } from "./helpers/FrozenStreamStaticText.sol";
import {
    FrozenStreamStaticContentBytes as OldFields
} from "./helpers/FrozenStreamStaticContentBytes.sol";
import { Base64 } from "../../../smart-contracts/vendor/openzeppelin/Base64.sol";

contract StreamStaticScanParityTest {
    function testUtf8EveryBoundaryAndMalformedSequence() public pure {
        bytes[16] memory samples;
        samples[0] = hex"00";
        samples[1] = hex"7f";
        samples[2] = hex"c280";
        samples[3] = hex"e280a8";
        samples[4] = hex"e280a9";
        samples[5] = hex"f09f8ea8";
        samples[6] = hex"c0af";
        samples[7] = hex"c1bf";
        samples[8] = hex"eda080";
        samples[9] = hex"f4908080";
        samples[10] = hex"f5808080";
        samples[11] = hex"80";
        samples[12] = hex"e2";
        samples[13] = hex"e280";
        samples[14] = hex"e228a8";
        samples[15] = hex"f09080";

        for (uint256 i; i < 65; ++i) {
            bytes memory prefix = _fill(i, 0x61);
            for (uint256 j; j < samples.length; ++j) {
                bytes memory value = bytes.concat(prefix, samples[j], _fill(67, 0x61));
                require(
                    Text.isValidUtf8(string(value)) == OldText.isValidUtf8(string(value)),
                    "UTF8 word crossing"
                );
                value = bytes.concat(prefix, samples[j]);
                require(
                    Text.isValidUtf8(string(value)) == OldText.isValidUtf8(string(value)),
                    "UTF8 end"
                );
            }
        }
        for (uint256 b; b < 256; ++b) {
            bytes memory value = _fill(96, 0x61);
            value[31] = bytes1(uint8(b));
            value[64] = bytes1(uint8(b));
            require(
                Text.isValidUtf8(string(value)) == OldText.isValidUtf8(string(value)), "every byte"
            );
        }
        require(
            !Text.isValidUtf8(string(samples[8])) && !Text.isValidUtf8(string(samples[9])),
            "surrogate and above ceiling"
        );
        require(Text.isValidUtf8(string(hex"e280a8e280a9f48fbfbf")), "valid Unicode endpoints");
    }

    function testFieldsAtAllPositionsAndExactFalsePositives() public pure {
        bytes memory html = bytes("</scriptX\x00\"arbitrary");
        bytes memory data = hex"00ff6529";
        bytes memory animation = _animation(html);
        bytes memory token = _token(data);
        for (uint256 i; i < 65; ++i) {
            bytes memory prefix = _fill(i, 0x61);
            bytes memory json = bytes.concat(prefix, animation, _fill(33, 0x61), token);
            require(
                Fields.matches(json, html, data) && OldFields.matches(json, html, data),
                "exact final position"
            );
            // Keep the first32 bytes equal and mutate the compared full field near its end.
            bytes memory bad = bytes.concat(animation);
            bad[bad.length - 2] = 0x58;
            json = bytes.concat(prefix, bad, token);
            require(
                !Fields.matches(json, html, data) && !OldFields.matches(json, html, data),
                "prefix alone insufficient"
            );
            json = bytes.concat(
                prefix, bytes(",\\\"animation_url\\\":\\\"data:text/html;base64,"), token
            );
            require(!Fields.matches(json, html, data), "escaped key is not field");
            json = bytes.concat(prefix, bad, _fill(32, 0x2c), animation, token);
            require(
                Fields.matches(json, html, data) == OldFields.matches(json, html, data),
                "later exact match retained"
            );
            json = bytes.concat(prefix, animation, _fill(33, 0x61), _token(hex"00ff6528"));
            require(!Fields.matches(json, html, data), "token bytes mismatch");
        }
        require(!Fields.matches("", "", ""), "empty absent");
    }

    function testFuzzUtf8(bytes memory raw) public pure {
        require(
            Text.isValidUtf8(string(raw)) == OldText.isValidUtf8(string(raw)), "UTF8 differential"
        );
    }

    function testFuzzFields(
        bytes memory prefix,
        bytes memory html,
        bytes memory data,
        bytes memory suffix
    ) public pure {
        bytes memory json = bytes.concat(prefix, _animation(html), suffix, _token(data));
        require(
            Fields.matches(json, html, data) == OldFields.matches(json, html, data),
            "positive differential"
        );
        require(
            Fields.matches(bytes.concat(prefix, suffix), html, data)
                == OldFields.matches(bytes.concat(prefix, suffix), html, data),
            "arbitrary differential"
        );
    }

    function _fill(uint256 n, bytes1 value) private pure returns (bytes memory out) {
        out = new bytes(n);
        for (uint256 i; i < n; ++i) {
            out[i] = value;
        }
    }

    function _animation(bytes memory html) private pure returns (bytes memory) {
        return abi.encodePacked(
            ',"animation_url":"data:text/html;base64,', Base64.encode(html), '","metadata_state":"'
        );
    }

    function _token(bytes memory data) private pure returns (bytes memory) {
        return abi.encodePacked(
            ',"token_data_base64":"', Base64.encode(data), '","properties":{"stream":'
        );
    }
}
