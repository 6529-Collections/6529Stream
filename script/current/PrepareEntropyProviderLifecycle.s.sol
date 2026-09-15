// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamGovernanceStagePlan.sol";
import { StreamEntropyLifecyclePlan } from "./StreamEntropyLifecyclePlan.sol";
import {
    IStreamEntropyProviderLifecycle,
    EntropyProviderState
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyProviderLifecycle.sol";

interface EntropyLifecyclePreparationVm {
    function envAddress(string calldata key) external view returns (address);
    function envBytes32(string calldata key) external view returns (bytes32);
    function envString(string calldata key) external view returns (string memory);
    function envUint(string calldata key) external view returns (uint256);
}

interface EntropyLifecycleAuthorityRead {
    function authority() external view returns (address);
}

/// @notice Read-only provider lifecycle plans for the existing saved-stage/Safe workflow.
/// @dev Each classifier admission is its own delayed Executor self-call. Retain each
///      returned encodedPlan and savedPlanHash before signing; this script never broadcasts.
contract PrepareEntropyProviderLifecycle {
    EntropyLifecyclePreparationVm private constant vm =
        EntropyLifecyclePreparationVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    enum Operation {
        ADMIT_BOTH,
        ADMIT_DEPRECATE,
        ADMIT_REVOKE,
        ACTIVATE,
        DEPRECATE,
        REVOKE
    }

    struct Parameters {
        uint64 notBefore;
        uint64 expiresAfter;
        bytes32 reasonHash;
        string reasonURI;
        bytes32 manifestHash;
    }

    struct PreparedStage {
        uint16 schemaVersion;
        bytes encodedPlan;
        bytes32 savedPlanHash;
        StreamGovernanceStagePlan.NextCall publication;
        StreamGovernanceStagePlan.NextCall scheduling;
    }

    error InvalidEntropyLifecycleDependency();
    error ProviderTighteningNotAdmitted(bytes4 selector);
    error UnexpectedProviderTransitionClass(uint8 expected, uint8 actual);

    function run() external view returns (PreparedStage[] memory stages) {
        require(block.chainid == 31337 || block.chainid == 11155111, "engineering chains only");
        uint256 mode = vm.envUint("STREAM_ENTROPY_LIFECYCLE_OPERATION");
        require(mode <= uint256(Operation.REVOKE), "unknown lifecycle operation");
        uint256 ready = vm.envUint("STREAM_STAGE_NOT_BEFORE");
        uint256 expiry = vm.envUint("STREAM_STAGE_EXPIRES_AFTER");
        require(ready <= type(uint64).max && expiry <= type(uint64).max, "stage time out of range");
        Parameters memory parameters = Parameters(
            uint64(ready),
            uint64(expiry),
            vm.envBytes32("STREAM_STAGE_REASON_HASH"),
            vm.envString("STREAM_STAGE_REASON_URI"),
            vm.envBytes32("STREAM_STAGE_MANIFEST_HASH")
        );
        StreamGovernanceExecutor executor =
            StreamGovernanceExecutor(payable(vm.envAddress("STREAM_EXECUTOR")));
        IStreamEntropyProviderLifecycle entropy =
            IStreamEntropyProviderLifecycle(vm.envAddress("STREAM_ENTROPY_COORDINATOR"));
        Operation operation = Operation(mode);
        if (operation == Operation.ADMIT_BOTH) {
            return prepareAdmissions(executor, entropy, parameters);
        }
        stages = new PreparedStage[](1);
        if (operation == Operation.ADMIT_DEPRECATE || operation == Operation.ADMIT_REVOKE) {
            stages[0] = prepareAdmission(
                executor,
                entropy,
                operation == Operation.ADMIT_DEPRECATE
                    ? IStreamEntropyProviderLifecycle.deprecateEntropyProvider.selector
                    : IStreamEntropyProviderLifecycle.revokeEntropyProvider.selector,
                parameters
            );
        } else {
            stages[0] = prepareTransition(
                executor,
                entropy,
                vm.envAddress("STREAM_ENTROPY_PROVIDER"),
                operation == Operation.ACTIVATE
                    ? EntropyProviderState.ACTIVE
                    : operation == Operation.DEPRECATE
                        ? EntropyProviderState.DEPRECATED
                        : EntropyProviderState.INCIDENT_REVOKED,
                parameters
            );
        }
    }

    /// @notice Two saved plans, never a combined two-call governance action.
    function prepareAdmissions(
        StreamGovernanceExecutor executor,
        IStreamEntropyProviderLifecycle entropy,
        Parameters memory parameters
    ) public view returns (PreparedStage[] memory stages) {
        stages = new PreparedStage[](2);
        stages[0] = prepareAdmission(
            executor,
            entropy,
            IStreamEntropyProviderLifecycle.deprecateEntropyProvider.selector,
            parameters
        );
        stages[1] = prepareAdmission(
            executor,
            entropy,
            IStreamEntropyProviderLifecycle.revokeEntropyProvider.selector,
            parameters
        );
    }

    /// @notice Prepare only the outstanding classifier when the other already executed.
    function prepareAdmission(
        StreamGovernanceExecutor executor,
        IStreamEntropyProviderLifecycle entropy,
        bytes4 selector,
        Parameters memory parameters
    ) public view returns (PreparedStage memory) {
        _requireDependencies(executor, entropy);
        GenesisBatch memory batch =
            StreamEntropyLifecyclePlan.admitTightening(executor, address(entropy), selector);
        bytes32 stage = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_PROVIDER_CLASSIFIER_STAGE_V1"),
                block.chainid,
                address(executor),
                address(entropy),
                selector
            )
        );
        return _prepare(executor, stage, batch, parameters);
    }

    /// @notice A fresh canonical transition from observed state, separate from classifier admission.
    function prepareTransition(
        StreamGovernanceExecutor executor,
        IStreamEntropyProviderLifecycle entropy,
        address provider,
        EntropyProviderState next,
        Parameters memory parameters
    ) public view returns (PreparedStage memory) {
        _requireDependencies(executor, entropy);
        require(next != EntropyProviderState.UNKNOWN, "unknown provider state");
        GenesisBatch memory batch;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        if (next == EntropyProviderState.ACTIVE) {
            batch.actionClass = 1;
            (batch.calls[0], batch.callDatas[0]) =
                StreamEntropyLifecyclePlan.activate(entropy, provider, parameters.reasonURI);
        } else {
            bytes4 selector = next == EntropyProviderState.DEPRECATED
                ? IStreamEntropyProviderLifecycle.deprecateEntropyProvider.selector
                : IStreamEntropyProviderLifecycle.revokeEntropyProvider.selector;
            (bool enabled, bytes32 codeHash,,) =
                executor.tighteningCallConfig(address(entropy), selector);
            if (!enabled || codeHash != address(entropy).codehash) {
                revert ProviderTighteningNotAdmitted(selector);
            }
            (bytes32 scope, bytes32 oldHash, bytes32 newHash, uint8 actionClass) =
                entropy.entropyProviderTransition(provider, next, parameters.reasonURI);
            if (actionClass != 0) revert UnexpectedProviderTransitionClass(0, actionClass);
            batch.actionClass = actionClass;
            batch.callDatas[0] = next == EntropyProviderState.DEPRECATED
                ? abi.encodeCall(entropy.deprecateEntropyProvider, (provider, parameters.reasonURI))
                : abi.encodeCall(entropy.revokeEntropyProvider, (provider, parameters.reasonURI));
            batch.calls[0] = StreamCurrentStackPlan.call(
                address(entropy), batch.callDatas[0], scope, oldHash, newHash
            );
        }
        bytes32 stage = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_PROVIDER_TRANSITION_STAGE_V1"),
                block.chainid,
                address(executor),
                address(entropy),
                provider,
                next
            )
        );
        return _prepare(executor, stage, batch, parameters);
    }

    function _requireDependencies(
        StreamGovernanceExecutor executor,
        IStreamEntropyProviderLifecycle entropy
    ) private view {
        if (
            address(executor).code.length == 0 || address(entropy).code.length == 0
                || !entropy.supportsInterface(type(IStreamEntropyProviderLifecycle).interfaceId)
                || entropy.supportsInterface(0xffffffff)
                || EntropyLifecycleAuthorityRead(address(entropy)).authority() != address(executor)
        ) {
            revert InvalidEntropyLifecycleDependency();
        }
    }

    function _prepare(
        StreamGovernanceExecutor executor,
        bytes32 stage,
        GenesisBatch memory batch,
        Parameters memory parameters
    ) private view returns (PreparedStage memory result) {
        StreamGovernanceStagePlan.Plan memory plan =
            StreamGovernanceStagePlan.build(
                executor,
                stage,
                batch,
                parameters.notBefore,
                parameters.expiresAfter,
                parameters.reasonHash,
                parameters.reasonURI,
                parameters.manifestHash
            );
        result.schemaVersion = 2;
        result.encodedPlan = abi.encode(plan);
        result.savedPlanHash = StreamGovernanceStagePlan.planHash(plan);
        result.publication = StreamGovernanceStagePlan.publication(plan, result.savedPlanHash);
        result.scheduling = StreamGovernanceStagePlan.scheduling(plan, result.savedPlanHash);
    }
}
