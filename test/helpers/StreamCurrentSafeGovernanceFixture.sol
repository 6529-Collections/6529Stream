// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentStackFixture.sol";
import "./OfficialSafeFixture.sol";

/// @notice Real delayed governance and independently derived role transitions for current Safe tests.
abstract contract StreamCurrentSafeGovernanceFixture is
    StreamCurrentStackFixture,
    OfficialSafeFixture
{
    OfficialSafe internal governorSafe;
    uint256[] internal governorKeys;
    bytes32 internal constant GOVERNANCE_REASON = keccak256("current artist governance evidence");

    function _installGovernorSafe(OfficialSafe next, uint256[] memory signingKeys) internal {
        governorSafe = next;
        governorKeys = signingKeys;
        (address previous, bytes32 codeHash, uint64 revision) = executor.governanceRootState();
        bytes memory data = abi.encodeCall(
            executor.rotateGovernanceRoot, (address(next), address(next).codehash)
        );
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_ROOT_SCOPE_V1"), block.chainid, address(executor)
            )
        );
        GovernanceActionRequest memory request = _governanceRequest(
            3,
            address(executor),
            data,
            scope,
            _rootState(previous, codeHash, revision),
            _rootState(address(next), address(next).codehash, revision + 1)
        );
        bytes memory scheduled = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        vm.warp(request.notBefore);
        executor.executeGovernanceAction(abi.decode(scheduled, (bytes32)), data);
        (address actual,,) = executor.governanceRootState();
        require(actual == address(next), "actual Safe governor installed");
    }

    function _rootState(address principal, bytes32 codeHash, uint64 revision)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_ROOT_STATE_V1"),
                block.chainid,
                address(executor),
                principal,
                codeHash,
                revision
            )
        );
    }

    function _governanceRequest(
        uint8 actionClass,
        address target,
        bytes memory data,
        bytes32 scope,
        bytes32 oldState,
        bytes32 newState
    ) internal view returns (GovernanceActionRequest memory request) {
        bytes4 selector;
        assembly ("memory-safe") { selector := mload(add(data, 32)) }
        uint64 ready = uint64(block.timestamp + executor.minimumDelay(actionClass));
        request = GovernanceActionRequest(
            actionClass,
            target,
            0,
            selector,
            data,
            scope,
            oldState,
            newState,
            ready,
            ready + 7 days,
            GOVERNANCE_REASON,
            "urn:stream:current:artist-governance",
            DEPLOYMENT_HASH
        );
    }

    function _scheduleAsGovernor(GovernanceActionRequest memory request)
        internal
        returns (bytes32 id)
    {
        vm.recordLogs();
        require(
            executeSafe(
                governorSafe,
                governorKeys,
                address(executor),
                0,
                abi.encodeCall(executor.scheduleGovernanceAction, (request)),
                0
            ),
            "Safe schedules actual action"
        );
        id = _scheduledAction(vm.getRecordedLogs());
        GovernanceAction memory stored = executor.governanceAction(id);
        require(
            stored.proposer == address(governorSafe)
                && stored.status == GovernanceActionStatus.SCHEDULED
                && stored.target == request.target && stored.selector == request.selector
                && stored.reasonHash == request.reasonHash,
            "exact stored Safe request"
        );
    }

    function _scheduleBatchAsGovernor(
        uint8 actionClass,
        GovernanceCall[] memory calls,
        bytes[] memory data
    ) internal returns (bytes32 id, uint64 ready) {
        require(calls.length == data.length, "matching batch");
        executor.publishGovernanceCallData(data);
        (bytes32 scope, bytes32 oldState, bytes32 newState) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            calls, StreamGovernanceBootstrap.governanceCallsHash(calls)
        );
        ready = uint64(block.timestamp + executor.minimumDelay(actionClass));
        vm.recordLogs();
        require(
            executeSafe(
                governorSafe,
                governorKeys,
                address(executor),
                0,
                abi.encodeCall(
                    executor.scheduleGovernanceBatch,
                    (
                        actionClass,
                        calls,
                        scope,
                        oldState,
                        newState,
                        ready,
                        ready + 7 days,
                        GOVERNANCE_REASON,
                        "urn:stream:current:artist-batch",
                        DEPLOYMENT_HASH
                    )
                ),
                0
            ),
            "Safe schedules actual batch"
        );
        id = _scheduledAction(vm.getRecordedLogs());
    }

    function _scheduledAction(Vm.Log[] memory logs) private view returns (bytes32 id) {
        bytes32 topic = keccak256(
            "GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(executor) && logs[i].topics.length == 4
                    && logs[i].topics[0] == topic
            ) {
                require(id == 0, "one scheduled action");
                id = logs[i].topics[1];
            }
        }
        require(id != 0, "canonical action event");
    }

    /// @dev External void boundary prevents an expected revert being consumed by Safe nonce reads.
    function executeCurrentGovernorCall(address target, bytes calldata data) external {
        require(msg.sender == address(this), "test only");
        require(
            executeSafe(governorSafe, governorKeys, target, 0, data, 0), "Safe target execution"
        );
    }

    function _executeAsGovernor(bytes32 id, bytes memory data) internal {
        this.executeCurrentGovernorCall(
            address(executor), abi.encodeCall(executor.executeGovernanceAction, (id, data))
        );
        require(
            executor.governanceAction(id).status == GovernanceActionStatus.EXECUTED,
            "actual action executed"
        );
    }

    function _govern(GovernanceActionRequest memory request) internal returns (bytes32 id) {
        id = _scheduleAsGovernor(request);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotExecutable.selector,
                id,
                request.notBefore
            )
        );
        executor.executeGovernanceAction(id, request.callData);
        vm.warp(request.notBefore);
        _executeAsGovernor(id, request.callData);
    }

    function _roleCall(bytes32 role, address holder, bool granted)
        internal
        view
        returns (GovernanceCall memory call_, bytes memory data)
    {
        bool oldGranted = roles.hasRole(role, holder);
        require(oldGranted != granted, "real membership transition");
        (bytes32 roleChain, uint64 roleRevision) = roles.roleMutationState(role);
        (bytes32 globalChain, uint64 globalRevision) = roles.globalRoleMutationState();
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1"),
                block.chainid,
                address(roles),
                role,
                holder
            )
        );
        bytes32 oldState =
            _roleState(scope, oldGranted, roleChain, roleRevision, globalChain, globalRevision);
        roleChain = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_V1"),
                roleChain,
                block.chainid,
                address(roles),
                role,
                holder,
                granted,
                roleRevision + 1
            )
        );
        globalChain = keccak256(
            abi.encode(
                keccak256("6529STREAM_GLOBAL_ROLE_MUTATION_V1"),
                globalChain,
                block.chainid,
                address(roles),
                role,
                holder,
                granted,
                globalRevision + 1
            )
        );
        data = granted
            ? abi.encodeCall(roles.grantRole, (role, holder))
            : abi.encodeCall(roles.revokeRole, (role, holder));
        call_ = StreamCurrentStackPlan.call(
            address(roles),
            data,
            scope,
            oldState,
            _roleState(scope, granted, roleChain, roleRevision + 1, globalChain, globalRevision + 1)
        );
    }

    function _setRole(bytes32 role, address holder, bool granted) internal {
        (GovernanceCall memory call_, bytes memory data) = _roleCall(role, holder, granted);
        _govern(
            _governanceRequest(
                1, call_.target, data, call_.scopeHash, call_.oldValueHash, call_.newValueHash
            )
        );
        require(roles.hasRole(role, holder) == granted, "actual role mutation");
    }

    function _roleState(
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
