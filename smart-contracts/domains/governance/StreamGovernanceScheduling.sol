// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamGovernanceManifest.sol";
import { StreamGovernanceRecoveryPolicy } from "./StreamGovernanceRecoveryPolicy.sol";

/// @notice Linked scheduling validation and record encoding for the immutable Executor.
/// @dev Storage references point to the Executor's existing fields. This library does
///      not own execution context, counters, or a new storage layout. Public methods
///      run by DELEGATECALL, preserving the original caller and action-ID domain.
library StreamGovernanceScheduling {
    struct Runtime {
        address owner;
        address bootstrapAuthority;
        uint256 nonce;
        uint256 pendingCount;
        bool executing;
        bytes32 genesisPlanHash;
        bool genesisInitialized;
    }

    struct Prepared {
        bytes32 actionId;
        bytes32 callsHash;
        address callDataPointer;
        uint256 totalValue;
        bool privilegedProposer;
    }

    /// @notice Validate the complete schedule before the Executor consumes its nonce.
    function prepare(
        StreamGovernancePolicy.AdminState storage admin,
        StreamGovernanceBootstrap.PolicyState storage policy,
        StreamGovernanceActionPolicy.State storage actionPolicy,
        StreamGovernanceManifest.LifecycleState storage manifest,
        Runtime memory runtime,
        StreamGovernanceBootstrap.ScheduleContext memory ctx,
        GovernanceCall[] memory calls
    ) public returns (Prepared memory prepared) {
        if (runtime.executing) {
            revert IStreamGovernanceExecutor.GovernanceSchedulingDuringExecution();
        }
        if (runtime.genesisPlanHash != bytes32(0) && !runtime.genesisInitialized) {
            revert IStreamGenesisInitializer.InvalidGenesisPlan();
        }
        bool bootstrapAuthority =
            manifest.bound && !manifest.isSealed && msg.sender == runtime.bootstrapAuthority;
        prepared.privilegedProposer = bootstrapAuthority || msg.sender == runtime.owner;
        if (manifest.isSealed) StreamGovernanceManifest.requireGovernanceRootCodeHash(manifest);
        if (!prepared.privilegedProposer && !admin.proposers[msg.sender]) {
            revert IStreamGovernanceExecutor.GovernanceActorNotAuthorized(msg.sender);
        }
        if (!manifest.bound) revert IStreamGovernanceExecutor.SystemManifestBootstrapNotBound();
        if (!manifest.isSealed) {
            if (msg.sender != runtime.bootstrapAuthority) {
                revert IStreamGovernanceExecutor.GenesisBootstrapActorRequired(msg.sender);
            }
            if (runtime.pendingCount != 0) {
                revert IStreamGovernanceExecutor.PendingGovernanceActionExists(runtime.pendingCount);
            }
            StreamGovernanceManifest.requireBootstrapCodeHashes(manifest);
        }

        prepared.callDataPointer = StreamGovernanceBootstrap.requirePublishedCallData(policy, calls);
        bytes[] memory callDatas =
            StreamGovernanceBootstrap.readCanonicalCallDatas(prepared.callDataPointer);
        prepared.totalValue = StreamGovernanceBootstrap.validateCalls(
            policy,
            address(manifest.roleRegistry),
            manifest.systemManifestSatellite,
            ctx.actionClass,
            calls,
            callDatas,
            IStreamGovernanceExecutor.sealSystemManifestBootstrap.selector
        );
        prepared.callsHash = StreamGovernanceBootstrap.governanceCallsHash(calls);
        {
            (bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash) =
                StreamGovernanceBootstrap.deriveBatchTransitionHashes(calls, prepared.callsHash);
            if (ctx.scopeHash != scopeHash) {
                revert IStreamGovernanceExecutor.BatchScopeHashMismatch(scopeHash, ctx.scopeHash);
            }
            if (ctx.oldValueHash != oldValueHash) {
                revert IStreamGovernanceExecutor.BatchOldValueHashMismatch(
                    oldValueHash, ctx.oldValueHash
                );
            }
            if (ctx.newValueHash != newValueHash) {
                revert IStreamGovernanceExecutor.BatchNewValueHashMismatch(
                    newValueHash, ctx.newValueHash
                );
            }
        }
        // The atomic committed initializer alone has immediate windows.
        if (runtime.genesisInitialized && !manifest.isSealed) {
            if (!bootstrapAuthority) revert IStreamGenesisInitializer.InvalidGenesisPlan();
        } else {
            StreamGovernanceBootstrap.validateActionWindow(
                ctx.actionClass, ctx.notBefore, ctx.expiresAfter
            );
        }
        prepared.actionId = StreamGovernanceBootstrap.governanceActionId(
            StreamGovernanceBootstrap.ActionIdentity({
                actionClass: ctx.actionClass,
                callsHash: prepared.callsHash,
                scopeHash: ctx.scopeHash,
                oldValueHash: ctx.oldValueHash,
                newValueHash: ctx.newValueHash,
                nonce: runtime.nonce,
                notBefore: ctx.notBefore,
                expiresAfter: ctx.expiresAfter,
                reasonHash: ctx.reasonHash,
                manifestHash: ctx.manifestHash
            })
        );
        StreamGovernanceManifest.validateManifestTailComposition(
            policy,
            admin,
            manifest,
            prepared.actionId,
            msg.sender,
            ctx.actionClass,
            calls,
            !manifest.isSealed,
            true,
            prepared.privilegedProposer,
            IStreamGovernanceExecutor.sealSystemManifestBootstrap.selector,
            IStreamGovernanceExecutor.registerSystemManifestTailTrigger.selector
        );
        StreamGovernanceActionPolicy.validateCalls(
            actionPolicy,
            manifest.actionPolicyCandidateProfileHash,
            manifest.actionPolicyCatalogHash,
            manifest.actionPolicyEntryCount,
            ctx.actionClass,
            calls,
            callDatas
        );
        StreamGovernanceRecoveryPolicy.validate(
            manifest.core, manifest.coreCodeHash, ctx.actionClass, calls, callDatas
        );
        if (ctx.actionClass == StreamGovernanceActionClasses.TERMINAL_FREEZE) {
            StreamGovernanceManifest.requireBoundRoleRegistry(manifest);
            StreamGovernanceBootstrap.validateTerminalFreezeGuardians(manifest.roleRegistry, calls);
        }
    }

    /// @notice Persist the action at its existing mapping slot after validation.
    function storeAction(
        GovernanceAction storage action,
        StreamGovernanceBootstrap.ScheduleContext memory ctx,
        GovernanceCall memory firstCall,
        Prepared memory prepared
    ) public {
        if (action.status != GovernanceActionStatus.NONE) {
            revert IStreamGovernanceExecutor.GovernanceActionNotScheduled(prepared.actionId);
        }
        action.status = GovernanceActionStatus.SCHEDULED;
        action.actionClass = ctx.actionClass;
        action.target = firstCall.target;
        action.value = prepared.totalValue;
        action.selector = firstCall.selector;
        action.callHash = prepared.callsHash;
        action.scopeHash = ctx.scopeHash;
        action.oldValueHash = ctx.oldValueHash;
        action.newValueHash = ctx.newValueHash;
        action.notBefore = ctx.notBefore;
        action.expiresAfter = ctx.expiresAfter;
        action.proposer = msg.sender;
        action.reasonHash = ctx.reasonHash;
        action.reasonURI = ctx.reasonURI;
        action.manifestHash = ctx.manifestHash;
    }
}
