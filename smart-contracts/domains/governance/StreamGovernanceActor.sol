// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Callable contract authority for a development or testnet deployment.
/// @dev A single immutable controller can exercise the role held by this contract.
///      Deploy distinct actors for the root and each terminal guardian. A production
///      profile should supply its chosen multisig/governance contracts instead.
contract StreamGovernanceActor {
    error InvalidController();
    error UnauthorizedController(address caller);
    error InvalidTarget(address target);

    address public immutable controller;

    event GovernanceCallExecuted(address indexed target, uint256 value, bytes4 selector);

    constructor(address controller_) {
        if (controller_ == address(0)) revert InvalidController();
        controller = controller_;
    }

    function execute(address target, uint256 value, bytes calldata data)
        external
        payable
        returns (bytes memory result)
    {
        if (msg.sender != controller) revert UnauthorizedController(msg.sender);
        if (target.code.length == 0) revert InvalidTarget(target);
        bool success;
        (success, result) = target.call{ value: value }(data);
        if (!success) {
            assembly ("memory-safe") {
                revert(add(result, 32), mload(result))
            }
        }
        bytes4 selector = data.length >= 4 ? bytes4(data[:4]) : bytes4(0);
        emit GovernanceCallExecuted(target, value, selector);
    }

    receive() external payable { }
}
