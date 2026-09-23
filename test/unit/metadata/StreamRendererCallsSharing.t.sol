// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamRendererCalls
} from "../../../smart-contracts/domains/metadata/StreamRendererCalls.sol";

import { OriginalRendererCallsForSharing } from "../../helpers/OriginalRendererCallsForSharing.sol";

contract RendererCallsSharingHarness {
    function current(address target, bytes memory input, uint256 maximum, bool exact, uint256 cap)
        external
        view
        returns (bytes memory)
    {
        return StreamRendererCalls.read(
            target, input, StreamRendererCalls.ReadOptions(maximum, exact), cap
        );
    }

    function original(address target, bytes memory input, uint256 maximum, bool exact, uint256 cap)
        external
        view
        returns (bytes memory)
    {
        return OriginalRendererCallsForSharing.read(target, input, maximum, exact, cap);
    }
}

contract RendererCallsSharingTarget {
    uint256 private _length;
    uint8 private _mode;
    uint256 public writes;

    function configure(uint256 length, uint8 mode) external {
        _length = length;
        _mode = mode;
    }

    fallback() external {
        if (_mode == 2) writes += 1;
        if (_mode == 3) {
            assembly ("memory-safe") {
                mstore(0, gas())
                return(0, 32)
            }
        }
        bytes memory result = new bytes(_length);
        bytes32 pattern = keccak256(msg.data);
        uint256 length = _length;
        bool fail = _mode == 1;
        assembly ("memory-safe") {
            let start := add(result, 32)
            for { let offset := 0 } lt(offset, length) { offset := add(offset, 32) } {
                mstore(add(start, offset), pattern)
            }
            if fail { revert(start, length) }
            return(start, length)
        }
    }
}

contract StreamRendererCallsSharingTest {
    RendererCallsSharingHarness private _harness;
    RendererCallsSharingTarget private _target;
    uint256 private constant CAP = 2000000;

    function setUp() public {
        _harness = new RendererCallsSharingHarness();
        _target = new RendererCallsSharingTarget();
    }

    function testExactAndBoundedRawReturnsPreserveInputAndAllBytes() public {
        bytes memory input = hex"12345678abcdef";
        _target.configure(97, 0);
        bytes memory raw = _pair(address(_target), input, 97, true, CAP, true);
        require(raw.length == 97);
        bytes32 expected = keccak256(input);
        for (uint256 i; i < raw.length; ++i) {
            require(raw[i] == expected[i % 32]);
        }
        require(keccak256(_pair(address(_target), input, 128, false, CAP, true)) == keccak256(raw));
    }

    function testEmptyAndNonWordAlignedReturns() public {
        _target.configure(0, 0);
        require(_pair(address(_target), hex"12", 0, true, CAP, true).length == 0);
        require(_pair(address(_target), hex"", 128, false, CAP, true).length == 0);
        _target.configure(31, 0);
        require(_pair(address(_target), hex"1234", 32, false, CAP, true).length == 31);
    }

    function testShortOversizedAndRevertedResultsKeepExactError() public {
        bytes memory input = hex"12345678";
        _target.configure(31, 0);
        _pair(address(_target), input, 32, true, CAP, false);
        _target.configure(33, 0);
        _pair(address(_target), input, 32, false, CAP, false);
        _target.configure(65536, 0);
        _pair(address(_target), input, 32, false, CAP, false);
        _target.configure(65536, 1);
        _pair(address(_target), input, 65536, false, CAP, false);
        _target.configure(0, 1);
        _pair(address(_target), input, 32, false, CAP, false);
    }

    function testMissingCodeZeroCapAndShortSelectorKeepExactError() public {
        _pair(address(0x1234), hex"12", 32, true, CAP, false);
        _pair(address(_target), hex"", 32, true, 0, false);
        _pair(address(_target), hex"12345678", 32, true, 1, false);
    }

    function testStaticReadCannotMutateTarget() public {
        _target.configure(32, 2);
        bytes memory input = hex"12345678";
        (bool writable,) = address(_target).call(input);
        require(writable && _target.writes() == 1, "ordinary call can write");
        (bool currentOk, bytes memory current) = address(_harness)
            .call(abi.encodeCall(_harness.current, (address(_target), input, 32, true, CAP)));
        require(!currentOk && _target.writes() == 1, "current helper enforces STATIC");
        require(keccak256(current) == keccak256(_error(address(_target), input)));
        (bool originalOk, bytes memory original) = address(_harness)
            .call(abi.encodeCall(_harness.original, (address(_target), input, 32, true, CAP)));
        require(!originalOk && _target.writes() == 1, "original helper enforces STATIC");
        require(keccak256(original) == keccak256(current));
    }

    function testRequestedGasCapIsRespected() public {
        _target.configure(32, 3);
        bytes memory input = hex"12345678";
        uint256 cap = 50000;
        bytes memory current = _harness.current(address(_target), input, 32, true, cap);
        bytes memory original = _harness.original(address(_target), input, 32, true, cap);
        uint256 currentGas = abi.decode(current, (uint256));
        uint256 originalGas = abi.decode(original, (uint256));
        require(currentGas > 0 && currentGas <= cap);
        require(originalGas > 0 && originalGas <= cap);
    }

    function testLowCallerGasKeepsBoundedRefusal() public view {
        bytes memory input = hex"12345678";
        (bool currentOk, bytes memory current) = address(_harness).staticcall{ gas: 11000 }(
            abi.encodeCall(_harness.current, (address(_target), input, 32, true, CAP))
        );
        (bool originalOk, bytes memory original) = address(_harness).staticcall{ gas: 11000 }(
            abi.encodeCall(_harness.original, (address(_target), input, 32, true, CAP))
        );
        require(!currentOk && !originalOk);
        require(keccak256(current) == keccak256(_error(address(_target), input)));
        require(keccak256(original) == keccak256(current));
    }

    function testFuzzReturnBounds(uint16 length_, uint16 maximum_, bool exact) public {
        uint256 length = uint256(length_) % 4097;
        uint256 maximum = uint256(maximum_) % 4097;
        _target.configure(length, 0);
        bool accepted = length <= maximum && (!exact || length == maximum);
        bytes memory result = _pair(address(_target), hex"12345678", maximum, exact, CAP, accepted);
        if (accepted) require(result.length == length);
    }

    function _pair(
        address target,
        bytes memory input,
        uint256 maximum,
        bool exact,
        uint256 cap,
        bool accepted
    ) private view returns (bytes memory) {
        (bool currentOk, bytes memory current) = address(_harness)
            .staticcall(abi.encodeCall(_harness.current, (target, input, maximum, exact, cap)));
        (bool originalOk, bytes memory original) = address(_harness)
            .staticcall(abi.encodeCall(_harness.original, (target, input, maximum, exact, cap)));
        require(currentOk == accepted && originalOk == accepted, "acceptance");
        require(keccak256(current) == keccak256(original), "exact original result");
        if (accepted) return abi.decode(current, (bytes));
        require(keccak256(current) == keccak256(_error(target, input)), "exact bounded refusal");
        return "";
    }

    function _error(address target, bytes memory input) private pure returns (bytes memory) {
        return abi.encodeWithSelector(
            StreamRendererCalls.RendererReadFailed.selector, target, bytes4(input)
        );
    }
}
