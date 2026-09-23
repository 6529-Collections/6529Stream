// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev External delegate.xyz service boundary only, not a substitute for a genesis product.
contract GenesisDelegationServiceDouble {
    mapping(bytes32 => bool) private grants;

    function delegateContract(address delegate, address token, bytes32 rights, bool enabled)
        external
    {
        grants[keccak256(abi.encode(msg.sender, delegate, token, rights))] = enabled;
    }

    function checkDelegateForContract(
        address delegate,
        address vault,
        address token,
        bytes32 rights
    ) external view returns (bool) {
        return grants[keccak256(abi.encode(vault, delegate, token, rights))];
    }
}
