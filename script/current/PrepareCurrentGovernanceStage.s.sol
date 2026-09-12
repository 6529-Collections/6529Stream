// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamGovernanceStagePlan.sol";

interface StagePreparationVm {
    function envAddress(string calldata key) external view returns (address);
    function envBytes(string calldata key) external view returns (bytes memory);
    function envBytes32(string calldata key) external view returns (bytes32);
    function envString(string calldata key) external view returns (string memory);
    function envUint(string calldata key) external view returns (uint256);
}

/// @notice Prepare and retain a version2 stage before publishing or asking its root to sign.
/// @dev This script performs no broadcast. A caller supplies a batch built from observed
///      target state; actual scheduling still enforces catalog admission and transitions.
contract PrepareCurrentGovernanceStage {
    StagePreparationVm private constant vm = StagePreparationVm(
        address(uint160(uint256(keccak256("hevm cheat code"))))
    );

    struct PreparedStage {
        uint16 schemaVersion;
        bytes encodedPlan;
        bytes32 savedPlanHash;
        StreamGovernanceStagePlan.NextCall publication;
        StreamGovernanceStagePlan.NextCall scheduling;
    }

    function run() external view returns (PreparedStage memory result) {
        require(block.chainid == 31337 || block.chainid == 11155111, "engineering chains only");
        uint256 ready = vm.envUint("STREAM_STAGE_NOT_BEFORE");
        uint256 expiry = vm.envUint("STREAM_STAGE_EXPIRES_AFTER");
        require(ready <= type(uint64).max && expiry <= type(uint64).max, "stage time out of range");
        StreamGovernanceStagePlan.Plan memory p = StreamGovernanceStagePlan.build(
            StreamGovernanceExecutor(payable(vm.envAddress("STREAM_EXECUTOR"))),
            vm.envBytes32("STREAM_STAGE_ID"),
            abi.decode(vm.envBytes("STREAM_STAGE_BATCH"), (GenesisBatch)),
            uint64(ready), uint64(expiry),
            vm.envBytes32("STREAM_STAGE_REASON_HASH"), vm.envString("STREAM_STAGE_REASON_URI"),
            vm.envBytes32("STREAM_STAGE_MANIFEST_HASH")
        );
        result.schemaVersion = 2;
        result.encodedPlan = abi.encode(p);
        result.savedPlanHash = StreamGovernanceStagePlan.planHash(p);
        result.publication = StreamGovernanceStagePlan.publication(p, result.savedPlanHash);
        result.scheduling = StreamGovernanceStagePlan.scheduling(p, result.savedPlanHash);
    }
}
