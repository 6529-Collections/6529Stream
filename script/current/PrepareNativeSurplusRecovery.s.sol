// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativeSurplusRecoveryPlan.sol";

interface NativeSurplusPreparationVm {
    function envBytes(string calldata key) external view returns (bytes memory);
    function envUint(string calldata key) external view returns (uint256);
    function envBytes32(string calldata key) external view returns (bytes32);
    function envString(string calldata key) external view returns (string memory);
}

/// @notice Read-only native-surplus operator workflow for all six current hosts. Never broadcasts.
contract PrepareNativeSurplusRecovery {
    NativeSurplusPreparationVm private constant vm =
        NativeSurplusPreparationVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external view returns (StreamNativeSurplusRecoveryPlan.Prepared memory) {
        require(block.chainid == 31337 || block.chainid == 11155111, "engineering chains only");
        uint256 ready = vm.envUint("STREAM_STAGE_NOT_BEFORE");
        uint256 expiry = vm.envUint("STREAM_STAGE_EXPIRES_AFTER");
        require(ready <= type(uint64).max && expiry <= type(uint64).max, "stage time out of range");
        return prepare(
            abi.decode(vm.envBytes("STREAM_SURPLUS_PINS"), (StreamNativeSurplusRecoveryPlan.Pins)),
            StreamNativeSurplusRecoveryPlan.Parameters(
                vm.envUint("STREAM_SURPLUS_AMOUNT"),
                uint64(ready),
                uint64(expiry),
                vm.envBytes32("STREAM_STAGE_REASON_HASH"),
                vm.envString("STREAM_STAGE_REASON_URI"),
                vm.envBytes32("STREAM_STAGE_MANIFEST_HASH")
            )
        );
    }

    function prepare(
        StreamNativeSurplusRecoveryPlan.Pins memory pins,
        StreamNativeSurplusRecoveryPlan.Parameters memory p
    ) public view returns (StreamNativeSurplusRecoveryPlan.Prepared memory) {
        return StreamNativeSurplusRecoveryPlan.prepare(pins, p);
    }

    function prepareAdmissionInventory(
        StreamNativeSurplusRecoveryPlan.Pins memory pins,
        bytes32 targetProfileHash
    )
        external
        view
        returns (StreamGovernanceCatalogStagePlan.Inventory memory inventory, bytes32 savedHash)
    {
        return StreamNativeSurplusRecoveryPlan.admission(pins, targetProfileHash);
    }

    /// @notice Explicit missing-selector admission with the original mandatory manifest-tail batch.
    /// @dev The retained payload/update and inventory hash must precede signatures; no bytes are published here.
    function prepareAdmissionStage(
        StreamGovernanceCatalogStagePlan.Inventory memory inventory,
        bytes32 savedInventoryHash,
        StreamSystemManifest manifest,
        address payloadRoot,
        StreamSystemManifestUpdate memory update,
        StreamNativeSurplusRecoveryPlan.Parameters memory p
    )
        external
        view
        returns (
            bytes memory encodedPlan,
            bytes32 savedPlanHash,
            StreamGovernanceStagePlan.NextCall memory publication,
            StreamGovernanceStagePlan.NextCall memory scheduling
        )
    {
        require(
            inventory.additions.length == 1
                && inventory.additions[0].selector == NS.sweepNativeSurplus.selector
                && inventory.additions[0].actionClass == 1 && inventory.additions[0].callType == 1
                && inventory.additions[0].valuePolicy == 0 && inventory.additions[0].valueLimit == 0
                && inventory.additions[0].valueSemanticsHash == bytes32(0),
            "not a surplus admission"
        );
        (GenesisBatch memory batch,) = StreamGovernanceCatalogStagePlan.nextBatch(
            inventory, savedInventoryHash, 0, manifest, payloadRoot, update
        );
        StreamGovernanceStagePlan.Plan memory plan = StreamGovernanceStagePlan.build(
            StreamGovernanceExecutor(payable(inventory.executor)),
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_NATIVE_SURPLUS_ADMISSION_STAGE_V1"), savedInventoryHash
                )
            ),
            batch,
            p.notBefore,
            p.expiresAfter,
            p.reasonHash,
            p.reasonURI,
            p.manifestHash
        );
        encodedPlan = abi.encode(plan);
        savedPlanHash = StreamGovernanceStagePlan.planHash(plan);
        publication = StreamGovernanceStagePlan.publication(plan, savedPlanHash);
        scheduling = StreamGovernanceStagePlan.scheduling(plan, savedPlanHash);
    }

    function execution(
        bytes memory encodedRecovery,
        bytes32 savedRecoveryHash,
        bytes32 confirmedActionId
    ) external view returns (bool alreadyExecuted, StreamGovernanceStagePlan.NextCall memory next) {
        return StreamNativeSurplusRecoveryPlan.execution(
            abi.decode(encodedRecovery, (StreamNativeSurplusRecoveryPlan.Saved)),
            savedRecoveryHash,
            confirmedActionId
        );
    }

    function completion(
        bytes memory encodedRecovery,
        bytes32 savedRecoveryHash,
        bytes32 confirmedActionId
    ) external view returns (StreamNativeSurplusRecoveryPlan.Completion memory) {
        return StreamNativeSurplusRecoveryPlan.completion(
            abi.decode(encodedRecovery, (StreamNativeSurplusRecoveryPlan.Saved)),
            savedRecoveryHash,
            confirmedActionId
        );
    }
}
