// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice One operator-owned CREATE coordinate for staged contract assembly.
/// @dev A deployment helper, never a Stream authority. Products must take their
///      intended authorities explicitly: their constructor's msg.sender is this slot.
contract StreamDeploymentSlot {
    error InvalidOperator();
    error OperatorRequired();
    error SlotConsumed();
    error InvalidCreationCode();
    error InvalidRuntimeCommitment();
    error DeploymentFailed();
    error UnexpectedDeploymentAddress();
    error InvalidRuntimeSize(uint256 size);
    error RuntimeMismatch(bytes32 actual, bytes32 expected);

    event ProductDeployed(
        address indexed product, bytes32 indexed creationHash, bytes32 runtimeHash
    );

    address public immutable operator;
    address public immutable product;
    bool public consumed;

    constructor(address operator_) {
        if (operator_ == address(0)) revert InvalidOperator();
        operator = operator_;
        // A newly created contract's first CREATE uses nonce one. No other path creates code.
        product = address(
            uint160(uint256(keccak256(abi.encodePacked(hex"d694", address(this), hex"01"))))
        );
    }

    /// @notice Deploy exact argument-inclusive creation bytes and verify the resulting runtime.
    /// @dev Zero-value only. Any failure rolls back consumption, the created contract and all
    ///      constructor effects; the same coordinate remains available for a corrected retry.
    function deploy(bytes memory creationCode, bytes32 expectedRuntime) external returns (address) {
        if (msg.sender != operator) revert OperatorRequired();
        if (consumed) revert SlotConsumed();
        if (creationCode.length == 0 || creationCode.length > 49_152) revert InvalidCreationCode();
        if (expectedRuntime == bytes32(0)) revert InvalidRuntimeCommitment();
        consumed = true;
        address actual;
        assembly ("memory-safe") {
            actual := create(0, add(creationCode, 32), mload(creationCode))
        }
        if (actual == address(0)) revert DeploymentFailed();
        if (actual != product) revert UnexpectedDeploymentAddress();
        uint256 size = actual.code.length;
        if (size == 0 || size > 24_576) revert InvalidRuntimeSize(size);
        bytes32 runtime = actual.codehash;
        if (runtime != expectedRuntime) revert RuntimeMismatch(runtime, expectedRuntime);
        emit ProductDeployed(actual, keccak256(creationCode), runtime);
        return actual;
    }
}
