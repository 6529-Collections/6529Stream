// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../../smart-contracts/vendor/openzeppelin/Base64.sol";

contract StreamBase64MemoryTailTest is CharacterizationTestBase {
    function testOneByteDirtyTailProducesCanonicalPadding() public pure {
        bytes memory input = new bytes(33);
        input[0] = 0xff;
        assembly {
            mstore(input, 1)
            mstore(add(input, 33), not(0))
        }
        require(
            keccak256(bytes(Base64.encode(input))) == keccak256(bytes("/w==")), "one byte pad bits"
        );
        bytes32 tail;
        assembly { tail := mload(add(input, 33)) }
        require(tail == bytes32(type(uint256).max), "caller tail restored");
    }

    function testTwoByteDirtyTailProducesCanonicalPadding() public pure {
        bytes memory input = hex"ffff";
        assembly { mstore(add(input, 34), not(0)) }
        require(
            keccak256(bytes(Base64.encode(input))) == keccak256(bytes("//8=")), "two byte pad bits"
        );
    }

    function testAdjacentObjectHeaderAndDataArePreserved() public pure {
        bytes memory input = new bytes(32);
        bytes memory adjacent = new bytes(32);
        for (uint256 i; i < 32; ++i) {
            input[i] = bytes1(uint8(i));
            adjacent[i] = 0xff;
        }
        bytes32 beforeHash = keccak256(adjacent);
        require(
            keccak256(bytes(Base64.encode(input)))
                == keccak256(bytes("AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=")),
            "32 byte literal"
        );
        require(
            adjacent.length == 32 && keccak256(adjacent) == beforeHash, "adjacent object unchanged"
        );
    }

    function testObservedFortyByteImageCounterexample() public pure {
        bytes memory input =
            hex"89504e470d0a1a0a00000000000000000000000000000000000000000000000000000000ee05abd9";
        assembly { mstore(add(add(input, 32), mload(input)), not(0)) }
        require(
            keccak256(bytes(Base64.encode(input)))
                == keccak256(bytes("iVBORw0KGgoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA7gWr2Q==")),
            "observed image counterexample"
        );
    }

    function testFuzzDirtyTailMatchesIndependentByteEncoder(bytes memory input, bytes32 tail)
        public
        pure
    {
        if (input.length == 0 || input.length > 512) return;
        string memory expected = _reference(input);
        // Reserve scratch space so poisoning does not touch an unrelated live object.
        bytes memory scratch = new bytes(input.length + 32);
        for (uint256 i; i < input.length; ++i) {
            scratch[i] = input[i];
        }
        assembly {
            mstore(scratch, mload(input))
            mstore(add(add(scratch, 32), mload(scratch)), tail)
        }
        require(
            keccak256(bytes(Base64.encode(scratch))) == keccak256(bytes(expected)),
            "independent exact bytes"
        );
        bytes32 afterTail;
        assembly { afterTail := mload(add(add(scratch, 32), mload(scratch))) }
        require(afterTail == tail, "tail unchanged");
    }

    function _reference(bytes memory input) private pure returns (string memory) {
        bytes memory alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        bytes memory output = new bytes(4 * ((input.length + 2) / 3));
        uint256 j;
        for (uint256 i; i < input.length; i += 3) {
            uint256 a = uint8(input[i]);
            uint256 b = i + 1 < input.length ? uint8(input[i + 1]) : 0;
            uint256 c = i + 2 < input.length ? uint8(input[i + 2]) : 0;
            output[j++] = alphabet[a >> 2];
            output[j++] = alphabet[((a & 3) << 4) | (b >> 4)];
            output[j++] = i + 1 < input.length ? alphabet[((b & 15) << 2) | (c >> 6)] : bytes1("=");
            output[j++] = i + 2 < input.length ? alphabet[c & 63] : bytes1("=");
        }
        return string(output);
    }
}
