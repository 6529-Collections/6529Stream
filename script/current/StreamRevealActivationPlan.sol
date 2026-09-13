// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistActivationPlan.sol";

/// @notice Delayed grants for reveal operations, optionally joined to initial artist activation.
/// @dev Initial deployment uses one five-call batch so both domains share the same delay.
///      Existing deployments may build the three-call reveal batch from their current role state.
library StreamRevealActivationPlan {
    error InvalidRevealActivationPlan();
    error RevealActivationReadbackFailed();

    struct Principals {
        address administrator;
        address revealOwner;
        address treasury;
    }

    struct GlobalState {
        bytes32 chain;
        uint64 revision;
    }

    function build(IStreamRoleRegistry roles, Principals memory principals)
        internal
        view
        returns (StreamArtistActivationPlan.Plan memory plan)
    {
        plan.calls = new GovernanceCall[](3);
        plan.callDatas = new bytes[](3);
        _appendGrants(roles, principals, plan, 0, _globalState(roles));
        _aggregate(plan);
    }

    function buildWithArtist(
        IStreamRoleRegistry roles,
        IStreamGasParameterHost manager,
        address artistAdministrator,
        Principals memory principals
    ) internal view returns (StreamArtistActivationPlan.Plan memory plan) {
        StreamArtistActivationPlan.Plan memory artist =
            StreamArtistActivationPlan.build(roles, manager, artistAdministrator);
        plan.calls = new GovernanceCall[](5);
        plan.callDatas = new bytes[](5);
        for (uint256 i; i < 2; ++i) {
            plan.calls[i] = artist.calls[i];
            plan.callDatas[i] = artist.callDatas[i];
        }
        GlobalState memory global = _globalState(roles);
        _advanceGlobal(roles, global, keccak256("ROLE_ARTIST_REGISTRY_ADMIN"), artistAdministrator);
        _appendGrants(roles, principals, plan, 2, global);
        _aggregate(plan);
    }

    /// @notice Authenticate the saved plan even when the selected action was already executed.
    function execute(
        IStreamGovernanceExecutor executor,
        IStreamRoleRegistry roles,
        IStreamGasParameterHost manager,
        address artistAdministrator,
        Principals memory principals,
        bytes32 actionId,
        StreamArtistActivationPlan.Plan memory plan
    ) internal {
        bool withArtist = address(manager) != address(0);
        uint256 offset = withArtist ? 2 : 0;
        if (plan.calls.length != offset + 3 || plan.callDatas.length != offset + 3) {
            revert InvalidRevealActivationPlan();
        }
        if (withArtist) {
            _validateCall(
                plan,
                0,
                address(roles),
                abi.encodeCall(
                    roles.grantRole, (keccak256("ROLE_ARTIST_REGISTRY_ADMIN"), artistAdministrator)
                )
            );
            _validateCall(
                plan,
                1,
                address(manager),
                abi.encodeCall(
                    manager.raiseGasParameter,
                    (keccak256("6529STREAM_GGP_ARTIST_AUTHORITY_GAS_LIMIT"), uint256(300_000))
                )
            );
        }
        for (uint256 i; i < 3; ++i) {
            (bytes32 role, address holder) = _principal(principals, i);
            _validateCall(
                plan, offset + i, address(roles), abi.encodeCall(roles.grantRole, (role, holder))
            );
        }
        GovernanceAction memory action = executor.governanceAction(actionId);
        if (
            action.actionClass != 1
                || action.callHash != StreamGovernanceBootstrap.governanceCallsHash(plan.calls)
                || action.scopeHash != plan.scopeHash || action.oldValueHash != plan.oldValueHash
                || action.newValueHash != plan.newValueHash
        ) revert InvalidRevealActivationPlan();
        if (action.status != GovernanceActionStatus.EXECUTED) {
            executor.executeGovernanceBatch(actionId, plan.calls, plan.callDatas);
        }
        if (executor.governanceAction(actionId).status != GovernanceActionStatus.EXECUTED) {
            revert RevealActivationReadbackFailed();
        }
        for (uint256 i; i < 3; ++i) {
            (bytes32 role, address holder) = _principal(principals, i);
            if (
                holder.code.length == 0 || !roles.hasRole(role, holder)
                    || (i != 0
                        && (roles.roleHolderCount(role) != 1 || roles.resolveRole(role) != holder))
            ) {
                revert RevealActivationReadbackFailed();
            }
        }
        if (
            withArtist
                && (!roles.hasRole(keccak256("ROLE_ARTIST_REGISTRY_ADMIN"), artistAdministrator)
                    || manager.gasParameter(keccak256("6529STREAM_GGP_ARTIST_AUTHORITY_GAS_LIMIT"))
                        < 300_000)
        ) {
            revert RevealActivationReadbackFailed();
        }
    }

    function _appendGrants(
        IStreamRoleRegistry roles,
        Principals memory principals,
        StreamArtistActivationPlan.Plan memory plan,
        uint256 offset,
        GlobalState memory global
    ) private view {
        for (uint256 i; i < 3; ++i) {
            (bytes32 role, address holder) = _principal(principals, i);
            if (
                holder.code.length == 0 || roles.hasRole(role, holder)
                    || (i != 0 && roles.roleHolderCount(role) != 0)
            ) {
                revert InvalidRevealActivationPlan();
            }
            (plan.calls[offset + i], plan.callDatas[offset + i]) =
                _grant(roles, role, holder, global);
        }
    }

    function _grant(
        IStreamRoleRegistry roles,
        bytes32 role,
        address holder,
        GlobalState memory global
    ) private view returns (GovernanceCall memory call_, bytes memory data) {
        (bytes32 chain, uint64 revision) = roles.roleMutationState(role);
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1"),
                block.chainid,
                address(roles),
                role,
                holder
            )
        );
        bytes32 oldState = _state(roles, scope, false, chain, revision, global);
        chain = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_V1"),
                chain,
                block.chainid,
                address(roles),
                role,
                holder,
                true,
                revision + 1
            )
        );
        _advanceGlobal(roles, global, role, holder);
        data = abi.encodeCall(roles.grantRole, (role, holder));
        call_ = StreamCurrentStackPlan.call(
            address(roles),
            data,
            scope,
            oldState,
            _state(roles, scope, true, chain, revision + 1, global)
        );
    }

    function _advanceGlobal(
        IStreamRoleRegistry roles,
        GlobalState memory global,
        bytes32 role,
        address holder
    ) private view {
        ++global.revision;
        global.chain = keccak256(
            abi.encode(
                keccak256("6529STREAM_GLOBAL_ROLE_MUTATION_V1"),
                global.chain,
                block.chainid,
                address(roles),
                role,
                holder,
                true,
                global.revision
            )
        );
    }

    function _globalState(IStreamRoleRegistry roles)
        private
        view
        returns (GlobalState memory state)
    {
        (state.chain, state.revision) = roles.globalRoleMutationState();
    }

    function _state(
        IStreamRoleRegistry roles,
        bytes32 scope,
        bool granted,
        bytes32 chain,
        uint64 revision,
        GlobalState memory global
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_STATE_V1"),
                block.chainid,
                address(roles),
                scope,
                granted,
                chain,
                revision,
                global.chain,
                global.revision
            )
        );
    }

    function _principal(Principals memory principals, uint256 index)
        private
        pure
        returns (bytes32, address)
    {
        if (index == 0) return (keccak256("ROLE_ENTROPY_ADMIN"), principals.administrator);
        if (index == 1) return (keccak256("ROLE_ENTROPY_REVEAL_OWNER"), principals.revealOwner);
        return (keccak256("ROLE_TREASURY"), principals.treasury);
    }

    function _aggregate(StreamArtistActivationPlan.Plan memory plan) private pure {
        (plan.scopeHash, plan.oldValueHash, plan.newValueHash) =
            StreamGovernanceBootstrap.deriveBatchTransitionHashes(
                plan.calls, StreamGovernanceBootstrap.governanceCallsHash(plan.calls)
            );
    }

    function _validateCall(
        StreamArtistActivationPlan.Plan memory plan,
        uint256 index,
        address target,
        bytes memory data
    ) private pure {
        bytes4 selector;
        assembly ("memory-safe") { selector := mload(add(data, 32)) }
        GovernanceCall memory call_ = plan.calls[index];
        if (
            call_.target != target || call_.value != 0 || call_.selector != selector
                || call_.callDataHash != keccak256(data)
                || keccak256(plan.callDatas[index]) != keccak256(data)
        ) {
            revert InvalidRevealActivationPlan();
        }
    }
}
