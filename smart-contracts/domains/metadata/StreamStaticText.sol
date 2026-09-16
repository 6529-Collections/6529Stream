// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Original UTF-8 and escaping algorithms, internally compiled with no external call.
library StreamStaticText {
    function escapeJsonString(string memory raw) internal pure returns (string memory) {
        // Six bytes is the worst case for each input byte (\u00xx). Keep the checked
        // allocation, write only within it, and retain its allocation after shortening.
        // UTF-8 validation remains the caller's separate responsibility, as before.
        bytes memory output = new bytes(bytes(raw).length * 6);
        assembly ("memory-safe") {
            let cursor := add(raw, 32)
            let end := add(cursor, mload(raw))
            let start := add(output, 32)
            let destination := start
            let hexDigits := 0x3031323334353637383961626364656600000000000000000000000000000000
            for { } lt(cursor, end) { cursor := add(cursor, 1) } {
                let character := byte(0, mload(cursor))
                let escaped := 0
                switch character
                case 0x22 { escaped := 0x22 }
                case 0x5c { escaped := 0x5c }
                case 0x08 { escaped := 0x62 }
                case 0x0c { escaped := 0x66 }
                case 0x0a { escaped := 0x6e }
                case 0x0d { escaped := 0x72 }
                case 0x09 { escaped := 0x74 }
                switch iszero(escaped)
                case 0 {
                    mstore8(destination, 0x5c)
                    mstore8(add(destination, 1), escaped)
                    destination := add(destination, 2)
                }
                default {
                    switch lt(character, 0x20)
                    case 1 {
                        mstore8(destination, 0x5c)
                        mstore8(add(destination, 1), 0x75)
                        mstore8(add(destination, 2), 0x30)
                        mstore8(add(destination, 3), 0x30)
                        mstore8(add(destination, 4), byte(shr(4, character), hexDigits))
                        mstore8(add(destination, 5), byte(and(character, 15), hexDigits))
                        destination := add(destination, 6)
                    }
                    default {
                        mstore8(destination, character)
                        destination := add(destination, 1)
                    }
                }
            }
            mstore(output, sub(destination, start))
        }
        return string(output);
    }

    function isValidUtf8(string memory raw) internal pure returns (bool valid) {
        assembly {
            let cursor := add(raw, 0x20)
            let end := add(cursor, mload(raw))
            valid := 1

            for { } lt(cursor, end) { cursor := add(cursor, 1) } {
                let lead := byte(0, mload(cursor))

                if iszero(lt(lead, 0x80)) {
                    if or(lt(lead, 0xc2), gt(lead, 0xf4)) {
                        valid := 0
                        break
                    }

                    cursor := add(cursor, 1)
                    if iszero(lt(cursor, end)) {
                        valid := 0
                        break
                    }

                    let second := byte(0, mload(cursor))
                    if iszero(eq(and(second, 0xc0), 0x80)) {
                        valid := 0
                        break
                    }

                    if lt(lead, 0xe0) {
                        continue
                    }

                    if or(
                        and(eq(lead, 0xe0), lt(second, 0xa0)),
                        and(eq(lead, 0xed), gt(second, 0x9f))
                    ) {
                        valid := 0
                        break
                    }

                    cursor := add(cursor, 1)
                    if iszero(lt(cursor, end)) {
                        valid := 0
                        break
                    }
                    if iszero(eq(and(byte(0, mload(cursor)), 0xc0), 0x80)) {
                        valid := 0
                        break
                    }

                    if lt(lead, 0xf0) {
                        continue
                    }

                    if or(
                        and(eq(lead, 0xf0), lt(second, 0x90)),
                        and(eq(lead, 0xf4), gt(second, 0x8f))
                    ) {
                        valid := 0
                        break
                    }

                    cursor := add(cursor, 1)
                    if iszero(lt(cursor, end)) {
                        valid := 0
                        break
                    }
                    if iszero(eq(and(byte(0, mload(cursor)), 0xc0), 0x80)) {
                        valid := 0
                        break
                    }
                }
            }
        }
    }
}
