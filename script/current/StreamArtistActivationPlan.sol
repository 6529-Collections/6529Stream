// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/interfaces/stream/governance/IStreamRoleRegistry.sol";
import "../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import "./StreamCurrentStackPlan.sol";
import "../../smart-contracts/domains/governance/StreamGovernanceBootstrap.sol";

/// @notice Exact post-genesis artist activation calls for one delayed governance batch.
/// @dev Build after genesis, persist the returned calls with the scheduled action ID,
///      and execute that same plan after its delay. No role or gas guard is bypassed.
library StreamArtistActivationPlan {
    error InvalidActivationPlan();
    error ActivationReadbackFailed();
    bytes32 internal constant ARTIST_ADMIN = keccak256("ROLE_ARTIST_REGISTRY_ADMIN");
    bytes32 internal constant ARTIST_READ_GAS =
        keccak256("6529STREAM_GGP_ARTIST_AUTHORITY_GAS_LIMIT");
    uint256 internal constant ARTIST_READ_VALUE = 300_000;

    struct Plan {
        GovernanceCall[] calls;
        bytes[] callDatas;
        bytes32 scopeHash;
        bytes32 oldValueHash;
        bytes32 newValueHash;
    }

    /// @notice Execute the saved batch, or verify its already executed result on resumption.
    /// @dev No new schedule is created and no transition is recomputed from changed state.
    ///      The selected action must bind these exact role and Manager calls, even on a retry.
    function execute(
        IStreamGovernanceExecutor executor,
        IStreamRoleRegistry roles,
        IStreamGasParameterHost manager,
        address administrator,
        bytes32 actionId,
        Plan memory plan
    ) internal {
        if (
            plan.calls.length != 2 || plan.callDatas.length != 2
                || plan.calls[0].target != address(roles)
                || plan.calls[1].target != address(manager) || plan.calls[0].value != 0
                || plan.calls[1].value != 0 || plan.calls[0].selector != roles.grantRole.selector
                || plan.calls[1].selector != manager.raiseGasParameter.selector
                || keccak256(plan.callDatas[0]) != plan.calls[0].callDataHash
                || keccak256(plan.callDatas[1]) != plan.calls[1].callDataHash
                || keccak256(plan.callDatas[0])
                    != keccak256(abi.encodeCall(roles.grantRole, (ARTIST_ADMIN, administrator)))
                || keccak256(plan.callDatas[1])
                    != keccak256(
                        abi.encodeCall(
                            manager.raiseGasParameter, (ARTIST_READ_GAS, ARTIST_READ_VALUE)
                        )
                    )
        ) revert InvalidActivationPlan();
        GovernanceAction memory action = executor.governanceAction(actionId);
        if (
            action.actionClass != 1
                || action.callHash != StreamGovernanceBootstrap.governanceCallsHash(plan.calls)
                || action.scopeHash != plan.scopeHash || action.oldValueHash != plan.oldValueHash
                || action.newValueHash != plan.newValueHash
        ) revert InvalidActivationPlan();
        if (action.status != GovernanceActionStatus.EXECUTED) {
            executor.executeGovernanceBatch(actionId, plan.calls, plan.callDatas);
        }
        if (
            executor.governanceAction(actionId).status != GovernanceActionStatus.EXECUTED
                || !roles.hasRole(ARTIST_ADMIN, administrator)
                || manager.gasParameter(ARTIST_READ_GAS) < ARTIST_READ_VALUE
        ) revert ActivationReadbackFailed();
    }

    function build(
        IStreamRoleRegistry roles,
        IStreamGasParameterHost manager,
        address administrator
    ) internal view returns (Plan memory plan) {
        require(administrator != address(0), "artist administrator required");
        require(!roles.hasRole(ARTIST_ADMIN, administrator), "artist administrator already active");
        plan.calls = new GovernanceCall[](2);
        plan.callDatas = new bytes[](2);
        (plan.calls[0], plan.callDatas[0]) = _roleGrant(roles, administrator);
        (plan.calls[1], plan.callDatas[1]) = _readBudgetRaise(manager);
        (plan.scopeHash, plan.oldValueHash, plan.newValueHash) =
            StreamGovernanceBootstrap.deriveBatchTransitionHashes(
                plan.calls, StreamGovernanceBootstrap.governanceCallsHash(plan.calls)
            );
    }

    function _roleGrant(IStreamRoleRegistry roles, address administrator)
        private
        view
        returns (GovernanceCall memory call_, bytes memory data)
    {
        (bytes32 roleChain, uint64 roleRevision) = roles.roleMutationState(ARTIST_ADMIN);
        (bytes32 globalChain, uint64 globalRevision) = roles.globalRoleMutationState();
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1"),
                block.chainid,
                address(roles),
                ARTIST_ADMIN,
                administrator
            )
        );
        bytes32 oldState =
            _roleState(roles, scope, false, roleChain, roleRevision, globalChain, globalRevision);
        bytes32 nextRole = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_V1"),
                roleChain,
                block.chainid,
                address(roles),
                ARTIST_ADMIN,
                administrator,
                true,
                roleRevision + 1
            )
        );
        bytes32 nextGlobal = keccak256(
            abi.encode(
                keccak256("6529STREAM_GLOBAL_ROLE_MUTATION_V1"),
                globalChain,
                block.chainid,
                address(roles),
                ARTIST_ADMIN,
                administrator,
                true,
                globalRevision + 1
            )
        );
        data = abi.encodeCall(roles.grantRole, (ARTIST_ADMIN, administrator));
        call_ = StreamCurrentStackPlan.call(
            address(roles),
            data,
            scope,
            oldState,
            _roleState(
                roles, scope, true, nextRole, roleRevision + 1, nextGlobal, globalRevision + 1
            )
        );
    }

    function _readBudgetRaise(IStreamGasParameterHost manager)
        private
        view
        returns (GovernanceCall memory call_, bytes memory data)
    {
        (uint256 value, uint256 floor, uint8 failureClass, uint64 revision) =
            manager.gasParameterInfo(ARTIST_READ_GAS);
        require(
            value == 150_000 && floor == 150_000 && failureClass == 2 && revision == 1,
            "unexpected artist read configuration"
        );
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_GAS_PARAMETER_SCOPE_V2"),
                block.chainid,
                address(manager),
                ARTIST_READ_GAS
            )
        );
        bytes32 domain = keccak256("6529STREAM_GAS_PARAMETER_STATE_V2");
        data = abi.encodeCall(manager.raiseGasParameter, (ARTIST_READ_GAS, ARTIST_READ_VALUE));
        call_ = StreamCurrentStackPlan.call(
            address(manager),
            data,
            scope,
            keccak256(abi.encode(domain, scope, value, floor, failureClass, revision)),
            keccak256(
                abi.encode(domain, scope, ARTIST_READ_VALUE, floor, failureClass, revision + 1)
            )
        );
    }

    function _roleState(
        IStreamRoleRegistry roles,
        bytes32 scope,
        bool granted,
        bytes32 roleChain,
        uint64 roleRevision,
        bytes32 globalChain,
        uint64 globalRevision
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_STATE_V1"),
                block.chainid,
                address(roles),
                scope,
                granted,
                roleChain,
                roleRevision,
                globalChain,
                globalRevision
            )
        );
    }
}
