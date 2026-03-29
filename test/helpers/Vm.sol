// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface Vm {
    function prank(address) external;
    function warp(uint256) external;
    function expectRevert(bytes calldata) external;
    function deal(address, uint256) external;
}

address constant HEVM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));

