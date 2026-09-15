// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamGovernanceStagePlan.sol";

interface SavedStageVm {
    function envAddress(string calldata key) external view returns (address);
    function envBytes(string calldata key) external view returns (bytes memory);
    function envBytes32(string calldata key) external view returns (bytes32);
    function startBroadcast(address broadcaster) external;
    function stopBroadcast() external;
}

/// @notice Execute the exact retained zero-value stage, or verify an already executed attempt.
/// @dev Load the hash from the original pre-signing journal, not a hash of replacement input.
///      The action ID must come from a confirmed matching schedule receipt. Read back the
///      stage's target state after this script before reporting product activation.
contract ExecuteSavedGovernanceStage {
    SavedStageVm private constant vm = SavedStageVm(
        address(uint160(uint256(keccak256("hevm cheat code"))))
    );

    function run() external returns (bool executedNow) {
        require(block.chainid == 31337 || block.chainid == 11155111, "engineering chains only");
        StreamGovernanceStagePlan.Plan memory p = abi.decode(
            vm.envBytes("STREAM_STAGE_PLAN"), (StreamGovernanceStagePlan.Plan)
        );
        bytes32 savedHash = vm.envBytes32("STREAM_STAGE_SAVED_HASH");
        bytes32 actionId = vm.envBytes32("STREAM_STAGE_ACTION_ID");
        GovernanceActionStatus status = StreamGovernanceStagePlan.verifyAction(p, actionId, savedHash);
        if (status == GovernanceActionStatus.EXECUTED) return false;
        address sender = vm.envAddress("STREAM_STAGE_EXECUTION_SENDER");
        require(sender != address(0), "execution sender required");
        vm.startBroadcast(sender);
        executedNow = StreamGovernanceStagePlan.execute(p, actionId, savedHash);
        vm.stopBroadcast();
    }
}
