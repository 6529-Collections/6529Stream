// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface Vm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }

    function addr(uint256 privateKey) external returns (address);
    function chainId(uint256 newChainId) external;
    function deal(address account, uint256 newBalance) external;
    function expectEmit(bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData)
        external;
    function prank(address msgSender) external;
    function roll(uint256 newHeight) external;
    function sign(uint256 privateKey, bytes32 digest)
        external
        returns (uint8 v, bytes32 r, bytes32 s);
    function warp(uint256 newTimestamp) external;
    function expectRevert(bytes calldata revertData) external;
    function expectRevert() external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
    function readFile(string calldata path) external view returns (string memory);
}

abstract contract CharacterizationTestBase {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
}
