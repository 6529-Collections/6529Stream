// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../script/current/StreamDeploymentSlot.sol";

interface ProtectedDeploymentSlotVm {
    function isContext(uint8 context) external view returns (bool);
    function startBroadcast(address sender) external;
    function stopBroadcast() external;
    function getNonce(address sender) external view returns (uint64);
}

contract ProtectedSlotProduct {
    address public authority;
    address public constructorCaller;

    constructor(address authority_) {
        authority = authority_;
        constructorCaller = msg.sender;
    }
}

/// @notice Local dry-run proof of real broadcast sender ownership and a later slot CREATE.
contract ProtectedDeploymentSlot {
    ProtectedDeploymentSlotVm private constant vm =
        ProtectedDeploymentSlotVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address private constant SENDER = address(0xC6529);

    function run() external returns (address slotAddress, address productAddress) {
        require(vm.isContext(5) && block.chainid == 31337, "local script simulation only");
        uint64 beforeNonce = vm.getNonce(SENDER);
        vm.startBroadcast(SENDER);
        StreamDeploymentSlot slot = new StreamDeploymentSlot(SENDER);
        vm.stopBroadcast();
        require(
            vm.getNonce(SENDER) == beforeNonce + 1 && slot.operator() == SENDER,
            "explicit broadcast operator"
        );
        address predicted = slot.product();
        bytes memory code =
            bytes.concat(type(ProtectedSlotProduct).creationCode, abi.encode(SENDER));
        vm.startBroadcast(SENDER);
        // An unrelated broadcast CREATE must not change the slot's reserved address.
        new ProtectedSlotProduct(SENDER);
        slot.deploy(code, keccak256(type(ProtectedSlotProduct).runtimeCode));
        vm.stopBroadcast();
        require(
            vm.getNonce(SENDER) == beforeNonce + 3,
            "one slot deployment, unrelated CREATE and slot call"
        );
        require(
            slot.consumed()
                && predicted.codehash == keccak256(type(ProtectedSlotProduct).runtimeCode),
            "exact product code"
        );
        require(
            ProtectedSlotProduct(predicted).authority() == SENDER
                && ProtectedSlotProduct(predicted).constructorCaller() == address(slot),
            "explicit authority distinct from constructor caller"
        );
        return (address(slot), predicted);
    }
}
