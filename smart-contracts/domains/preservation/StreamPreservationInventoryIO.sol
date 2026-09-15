// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

library StreamPreservationInventoryIO {
    function pin(address target, bytes32 expected) internal view {
        if (target.code.length == 0 || expected == 0 || target.codehash != expected) {
            revert T.InventoryRead(target);
        }
    }

    function read(address target, bytes memory input, uint256 maximum, uint256 cap)
        internal
        view
        returns (bytes memory output)
    {
        if (
            cap < 50000 || cap > type(uint64).max || maximum > 1048576
                || gasleft() <= cap + cap / 63 + 10000
        ) revert T.InventoryRead(target);
        bool ok;
        uint256 size;
        // Do not allocate a maximum-sized buffer or copy attacker-sized returndata.
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), 0, 0)
            size := returndatasize()
        }
        if (!ok || size > maximum) revert T.InventoryRead(target);
        output = new bytes(size);
        assembly ("memory-safe") { returndatacopy(add(output, 32), 0, size) }
    }

    function fixedRead(address target, bytes memory input, uint256 size, uint256 cap)
        internal
        view
        returns (bytes memory output)
    {
        output = read(target, input, size, cap);
        if (output.length != size) revert T.InventoryRead(target);
    }

    function canonical(address target, bytes memory actual, bytes memory expected) internal pure {
        if (actual.length != expected.length || keccak256(actual) != keccak256(expected)) {
            revert T.InventoryRead(target);
        }
    }

    function word(address target, bytes memory input, uint256 cap) internal view returns (bytes32) {
        return abi.decode(fixedRead(target, input, 32, cap), (bytes32));
    }

    function addressWord(address target, bytes memory input, uint256 cap)
        internal
        view
        returns (address result)
    {
        bytes32 value = word(target, input, cap);
        if (uint256(value) > type(uint160).max) revert T.InventoryRead(target);
        return address(uint160(uint256(value)));
    }
}
