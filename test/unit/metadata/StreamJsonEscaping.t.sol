// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/metadata/StreamMetadataRenderer.sol";
import "../../helpers/LegacyJsonEscapingOracle.sol";

/// @notice Byte-level regression and cost checks against the exact prior implementation.
/// @dev Escaping deliberately preserves arbitrary non-control bytes; UTF-8 validation is separate.
contract StreamJsonEscapingTest {
    event log_named_uint(string key, uint256 value);

    function _equal(bytes memory actual, bytes memory expected) private pure {
        require(actual.length == expected.length, "escaped length changed");
        require(keccak256(actual) == keccak256(expected), "escaped bytes changed");
    }

    function _compare(bytes memory raw) private pure returns (bytes memory escaped) {
        bytes32 beforeHash = keccak256(raw);
        uint256 beforeLength = raw.length;
        escaped = bytes(StreamMetadataRenderer.escapeJsonString(string(raw)));
        _equal(escaped, bytes(LegacyJsonEscapingOracle.escapeJsonString(string(raw))));
        require(raw.length == beforeLength && keccak256(raw) == beforeHash, "input modified");
    }

    function _repeated(uint256 length, bytes1 character) private pure returns (bytes memory raw) {
        raw = new bytes(length);
        for (uint256 i; i < length; ++i) {
            raw[i] = character;
        }
    }

    function testEmpty() public pure {
        _equal(_compare(""), "");
    }

    function testIndependentGoldenControlEscapesAndUnicode() public pure {
        _equal(
            _compare(hex"225c080c0a0d09001f202fe29883"),
            hex"5c225c5c5c625c665c6e5c725c745c75303030305c7530303166202fe29883"
        );
    }

    function testEveryByteIndividuallyAndTogether() public pure {
        bytes memory all = new bytes(256);
        for (uint256 i; i < 256; ++i) {
            all[i] = bytes1(uint8(i));
            _compare(abi.encodePacked(bytes1(uint8(i))));
        }
        _compare(all);
    }

    function testInvalidUtf8RemainsUnchanged() public pure {
        bytes memory raw = hex"ff80c0afe080aff4908080eda080fe";
        _equal(_compare(raw), raw);
        require(
            !StreamMetadataRenderer.isValidUtf8(string(raw)), "independent UTF-8 rejection retained"
        );
    }

    function testAllocationAndProtocolSizeBoundaries() public pure {
        uint256[14] memory lengths =
            [uint256(0), 1, 31, 32, 33, 63, 64, 65, 255, 256, 2047, 2048, 8191, 8192];
        for (uint256 j; j < lengths.length; ++j) {
            bytes memory raw = new bytes(lengths[j]);
            for (uint256 i; i < raw.length; ++i) {
                raw[i] = bytes1(uint8(i));
            }
            _compare(raw);
        }
    }

    function testMaximumSixfoldExpansion() public pure {
        bytes memory escaped = _compare(new bytes(8192));
        require(escaped.length == 49152, "full sixfold expansion");
        for (uint256 i; i < escaped.length; i += 6) {
            require(
                escaped[i] == 0x5c && escaped[i + 1] == 0x75 && escaped[i + 2] == 0x30
                    && escaped[i + 3] == 0x30 && escaped[i + 4] == 0x30 && escaped[i + 5] == 0x30,
                "independent zero-byte escape"
            );
        }
    }

    function testRepeatedCallsAndSubsequentAllocationsPreserveValues() public pure {
        bytes memory input = hex"00225c1f2021ff";
        bytes memory first = _compare(input);
        bytes32 inputHash = keccak256(input);
        bytes32 firstHash = keccak256(first);
        bytes memory canary = _repeated(513, 0xab);
        bytes memory second = _compare(_repeated(33, 0x22));
        bytes memory packed = abi.encode(input, first, canary, second);
        (bytes memory a, bytes memory b, bytes memory c, bytes memory d) =
            abi.decode(packed, (bytes, bytes, bytes, bytes));
        require(keccak256(input) == inputHash && keccak256(first) == firstHash, "retained values");
        _equal(a, input);
        _equal(b, first);
        _equal(c, _repeated(513, 0xab));
        _equal(d, second);
    }

    function _measure(uint256 length) private {
        bytes memory raw = _repeated(length, 0x61);
        // Warm both linked libraries before measuring equivalent same-caller invocations.
        StreamMetadataRenderer.escapeJsonString("warm");
        LegacyJsonEscapingOracle.escapeJsonString("warm");
        uint256 start = gasleft();
        bytes memory current = bytes(StreamMetadataRenderer.escapeJsonString(string(raw)));
        uint256 currentGas = start - gasleft();
        start = gasleft();
        bytes memory previous = bytes(LegacyJsonEscapingOracle.escapeJsonString(string(raw)));
        uint256 previousGas = start - gasleft();
        _equal(current, previous);
        emit log_named_uint("input bytes", length);
        emit log_named_uint("previous escaping call gas", previousGas);
        emit log_named_uint("optimized escaping call gas", currentGas);
        require(currentGas < previousGas / 2, "material cost reduction required");
    }

    function testGas2048ByteReference() public {
        _measure(2048);
    }

    function testGas8192ByteText() public {
        _measure(8192);
    }

    function testFuzzArbitraryBytesMatchOriginal(bytes memory raw) public pure {
        _compare(raw);
    }

    function testFuzzConcatenationPreservesExactByteMeaning(bytes memory a, bytes memory b)
        public
        pure
    {
        bytes memory joined = _compare(bytes.concat(a, b));
        _equal(joined, bytes.concat(_compare(a), _compare(b)));
    }
}
