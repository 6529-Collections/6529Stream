// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev Test-only stateless delegate target. The real Safe executes this code, so the
/// downstream ordinary CALL has the Safe as msg.sender. It writes no Safe storage.
contract PreservationSafeCallProbe {
    event SafeReturnChecked(address indexed target, bytes4 indexed selector, bytes32 resultHash);

    function check(
        address expectedSafe,
        address target,
        bytes calldata input,
        bytes calldata expected
    ) external {
        require(address(this) == expectedSafe && target != address(0), "actual Safe context");
        (bool ok, bytes memory result) = target.call(input);
        require(ok, "target success");
        require(
            result.length == expected.length && keccak256(result) == keccak256(expected),
            "exact return"
        );
        emit SafeReturnChecked(target, bytes4(input[:4]), keccak256(result));
    }
}
