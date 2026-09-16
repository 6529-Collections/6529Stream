// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ArtistRecoveryGovernanceFixture.sol";
import {
    StreamArtistIdentityRecoveryGovernance
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityRecoveryGovernance.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery35
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistDelegationTypes.sol";

/// @dev Actual governance witness consumer only; no artist state or operation35 admission is represented by this target.
contract ActualRecoveryWitnessTarget {
    address public immutable core;
    address public immutable executor;
    address public immutable roles;
    Contest.GovernanceWitness public last;

    constructor(address core_, address executor_, address roles_) {
        core = core_;
        executor = executor_;
        roles = roles_;
    }

    function assertion() external view {
        require(msg.sender == executor, "fixed executor");
    }

    function consume(Recovery35.Context calldata c) external {
        D.CoordinatorContext memory x;
        x.suite.core = core;
        x.suite.roleRegistry = roles;
        x.suite.registry = address(this);
        last = StreamArtistIdentityRecoveryGovernance.read(
            x, executor, msg.sender, keccak256("staged products"), c
        );
    }

    function witness() external view returns (Contest.GovernanceWitness memory) {
        return last;
    }
}

/// @notice Real delayed/sealed governance and global terminal veto around the operation35 reader.
/// @dev Complements actual Artist ingress; this cohort does not claim artist-installed guardians or owner mutation.
contract StreamArtistRecoveryActualGovernanceTest is ArtistRecoveryGovernanceFixture {
    ActualRecoveryWitnessTarget private target;
    bytes32 private constant ARBITER = keccak256("ROLE_ATTRIBUTION_ARBITER");

    function _initializeRecoveryWitness() private {
        (SystemManifestBootstrapBinding memory binding, GenesisBatch[] memory batches) = _plan();
        configuration.executor
            .commitGenesisPlan(configuration.executor.hashGenesisPlan(binding, batches));
        configuration.executor.initializeGenesis(binding, batches);
        target = new ActualRecoveryWitnessTarget(
            address(configuration.core),
            address(configuration.executor),
            address(configuration.roles)
        );
        GovernanceActionPolicyEntry[] memory additions = new GovernanceActionPolicyEntry[](3);
        additions[0] = _entry(1, address(target), target.consume.selector);
        additions[1] = _entry(2, address(target), target.consume.selector);
        additions[2] = _entry(2, address(target), target.assertion.selector);
        for (uint256 i = 1; i < 3; ++i) {
            for (
                uint256 j = i;
                j > 0 && uint256(_key(additions[j])) < uint256(_key(additions[j - 1]));
                --j
            ) {
                (additions[j], additions[j - 1]) = (additions[j - 1], additions[j]);
            }
        }
        (bytes32 candidate, bytes32 catalog, uint256 count, uint64 revision) =
            configuration.executor.governanceActionPolicyState();
        (bytes32 next, bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceActionPolicy.extensionTransition(
            address(configuration.executor), candidate, catalog, count, revision, additions
        );
        GovernanceCall[] memory calls = new GovernanceCall[](2);
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(
            configuration.executor.extendGovernanceActionPolicy,
            (revision, catalog, next, additions)
        );
        calls[0] = StreamCurrentStackPlan.call(
            address(configuration.executor), data[0], scope, oldHash, newHash
        );
        (calls[1], data[1]) = _publication(
            StreamGenesisManifestPlan.readAggregate(configuration.manifest).modules, next
        );
        _runBatch(3, calls, data);
        _arbiter(true);
    }

    function _arbiter(bool grant) private {
        address holder = address(governor);
        StreamRoleRegistry roles = configuration.roles;
        (bytes32 roleChain, uint64 roleRevision) = roles.roleMutationState(ARBITER);
        (bytes32 globalChain, uint64 globalRevision) = roles.globalRoleMutationState();
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1"),
                block.chainid,
                address(roles),
                ARBITER,
                holder
            )
        );
        bytes32 oldState =
            _roleState(scope, !grant, roleChain, roleRevision, globalChain, globalRevision);
        bytes32 nextRole = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_V1"),
                roleChain,
                block.chainid,
                address(roles),
                ARBITER,
                holder,
                grant,
                roleRevision + 1
            )
        );
        bytes32 nextGlobal = keccak256(
            abi.encode(
                keccak256("6529STREAM_GLOBAL_ROLE_MUTATION_V1"),
                globalChain,
                block.chainid,
                address(roles),
                ARBITER,
                holder,
                grant,
                globalRevision + 1
            )
        );
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        bytes[] memory data = new bytes[](1);
        data[0] = grant
            ? abi.encodeCall(roles.grantRole, (ARBITER, holder))
            : abi.encodeCall(roles.revokeRole, (ARBITER, holder));
        calls[0] = StreamCurrentStackPlan.call(
            address(roles),
            data[0],
            scope,
            oldState,
            _roleState(scope, grant, nextRole, roleRevision + 1, nextGlobal, globalRevision + 1)
        );
        _runBatch(1, calls, data);
        require(roles.hasRole(ARBITER, holder) == grant, "actual arbiter mutation");
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
                address(configuration.roles),
                scope,
                granted,
                roleChain,
                roleRevision,
                globalChain,
                globalRevision
            )
        );
    }

    function _batch(bool assertion_)
        private
        view
        returns (GovernanceCall[] memory calls, bytes[] memory data, Recovery35.Context memory c)
    {
        c.scopeHash = keccak256("recovery exact per-call scope");
        c.oldValueHash = keccak256("recovery prior state");
        c.newValueHash = keccak256("recovery admitted intent");
        uint256 n = assertion_ ? 2 : 1;
        calls = new GovernanceCall[](n);
        data = new bytes[](n);
        if (assertion_) {
            data[0] = abi.encodeCall(target.assertion, ());
            calls[0] = StreamCurrentStackPlan.call(
                address(target),
                data[0],
                keccak256("different first call"),
                bytes32(0),
                keccak256(data[0])
            );
        }
        data[n - 1] = abi.encodeCall(target.consume, (c));
        calls[n - 1] = StreamCurrentStackPlan.call(
            address(target), data[n - 1], c.scopeHash, c.oldValueHash, c.newValueHash
        );
    }

    function testActualSealedTerminalWitnessUsesPublishedSecondCallAndDelay() public {
        _initializeRecoveryWitness();
        (GovernanceCall[] memory calls, bytes[] memory data, Recovery35.Context memory c) =
            _batch(true);
        uint256 scheduledAt = block.timestamp;
        (bytes32 id, uint64 ready) = this.scheduleFoundationBatch(2, calls, data);
        require(ready >= scheduledAt + 72 hours, "actual terminal delay");
        require(
            keccak256(abi.encode(configuration.executor.scheduledCallData(id)))
                == keccak256(abi.encode(data)),
            "complete actual published bytes"
        );
        vm.warp(ready - 1);
        vm.expectRevert();
        this.executeFoundationBatch(id, calls, data);
        require(
            target.witness().actionId == 0
                && configuration.executor.governanceAction(id).status
                    == GovernanceActionStatus.SCHEDULED,
            "early rejection"
        );
        vm.warp(ready);
        this.executeFoundationBatch(id, calls, data);
        Contest.GovernanceWitness memory g = target.witness();
        require(
            g.actionId == id && g.actionClass == 2 && g.proposer == address(governor)
                && g.scopeHash == c.scopeHash && g.oldValueHash == c.oldValueHash
                && g.newValueHash == c.newValueHash,
            "actual stored/action/per-call joins"
        );
        GovernanceAction memory action = configuration.executor.governanceAction(id);
        require(
            action.status == GovernanceActionStatus.EXECUTED
                && action.selector == target.assertion.selector
                && action.reasonHash == keccak256("staged products"),
            "first header is not operative call"
        );
        (bytes32 mutation, uint64 revision) = configuration.roles.roleMutationState(ARBITER);
        require(
            g.roleMutationHash == mutation && g.roleRevision == revision,
            "actual current proposer role facts"
        );
        vm.expectRevert();
        this.executeFoundationBatch(id, calls, data);
    }

    function testActualTerminalGuardianVetoIsPermanentAndFreshActionWaitsAgain() public {
        _initializeRecoveryWitness();
        (GovernanceCall[] memory calls, bytes[] memory data,) = _batch(true);
        (bytes32 id, uint64 ready) = this.scheduleFoundationBatch(2, calls, data);
        vm.warp(ready - 1);
        address guardian = configuration.guardians[0];
        StreamGovernanceActor(payable(guardian))
            .execute(
                address(configuration.executor),
                0,
                abi.encodeCall(
                    configuration.executor.vetoTerminalFreeze, (id, keccak256("independent veto"))
                )
            );
        require(
            configuration.executor.governanceAction(id).status == GovernanceActionStatus.VETOED
                && configuration.executor.governanceAction(id).vetoer == guardian,
            "actual separate guardian veto"
        );
        vm.warp(ready);
        vm.expectRevert();
        this.executeFoundationBatch(id, calls, data);
        require(target.witness().actionId == 0, "vetoed action never consumed");
        (bytes32 next, uint64 nextReady) = this.scheduleFoundationBatch(2, calls, data);
        require(
            next != id && nextReady >= block.timestamp + 72 hours, "fresh action fresh full delay"
        );
        vm.warp(nextReady);
        this.executeFoundationBatch(next, calls, data);
        require(
            target.witness().actionId == next
                && configuration.executor.governanceAction(id).status
                    == GovernanceActionStatus.VETOED,
            "no resurrection of vetoed action"
        );
    }

    function testActualOrdinaryClassAndRevokedProposerFailAtWitness() public {
        _initializeRecoveryWitness();
        (GovernanceCall[] memory calls, bytes[] memory data,) = _batch(false);
        (bytes32 ordinary, uint64 ready) = this.scheduleFoundationBatch(1, calls, data);
        vm.warp(ready);
        vm.expectRevert();
        this.executeFoundationBatch(ordinary, calls, data);
        require(target.witness().actionId == 0, "ordinary class cannot authorize35");
        (bytes32 terminal, uint64 terminalReady) = this.scheduleFoundationBatch(2, calls, data);
        _arbiter(false);
        if (block.timestamp < terminalReady) vm.warp(terminalReady);
        vm.expectRevert();
        this.executeFoundationBatch(terminal, calls, data);
        require(
            target.witness().actionId == 0
                && configuration.executor.governanceAction(terminal).status
                    == GovernanceActionStatus.SCHEDULED,
            "revoked current arbiter cannot execute"
        );
        _arbiter(true);
        this.executeFoundationBatch(terminal, calls, data);
        require(
            target.witness().actionId == terminal,
            "same scheduled bytes healthy after restored authority"
        );
    }
}
