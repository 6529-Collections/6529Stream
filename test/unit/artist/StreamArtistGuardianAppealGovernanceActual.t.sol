// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistGuardianAppealAuthority
} from "../../../smart-contracts/domains/artist/StreamArtistGuardianAppealAuthority.sol";
import "../../helpers/ArtistRecoveryGovernanceFixture.sol";
import {
    StreamArtistRecoveryActionReads as Reads
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryActionReads.sol";
import {
    StreamArtistGuardianAppealGovernance as Governance
} from "../../../smart-contracts/domains/artist/StreamArtistGuardianAppealGovernance.sol";
import {
    StreamArtistRecoveryActionTypes as ActionPrep
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery35
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistDelegationTypes.sol";

/// @dev Actual action authentication consumer only, without Identity association or signer authority.
contract ActualGuardianAppealTarget {
    address public immutable core;
    address public immutable executor;
    address public immutable roles;
    bytes32 public immutable executorCodeHash;
    ActionPrep.Witness private prepared;
    bytes32 private requestHash;
    Contest.GovernanceWitness private last;

    constructor(address c, address e, address r) {
        core = c;
        executor = e;
        roles = r;
        executorCodeHash = e.codehash;
    }

    function assertion() external view {
        require(msg.sender == executor, "fixed executor");
    }

    function context() public view returns (Recovery35.Context memory c) {
        c.scopeHash = keccak256("actual preparation scope");
        c.oldValueHash = keccak256(
            abi.encode(
                keccak256("prior guardian fixture"),
                StreamArtistGuardianAppealAuthority.current(executor, roles)
            )
        );
        c.newValueHash = keccak256("exact recovery request fixture");
    }

    function register(
        bytes32 id,
        GovernanceCall[] calldata calls,
        Recovery35.Request calldata p,
        T.Authorization calldata a
    ) external {
        prepared = Reads.prepareAppeal(
            ActionPrep.Environment(address(this), executor, executorCodeHash, roles),
            id,
            calls,
            p,
            a,
            context()
        );
        requestHash = keccak256(abi.encode(p, a));
    }

    function recoverArtistIdentity(Recovery35.Request calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        require(keccak256(abi.encode(p, a)) == requestHash, "registered calldata");
        D.CoordinatorContext memory x;
        x.suite.core = core;
        x.suite.roleRegistry = roles;
        x.suite.registry = address(this);
        last = Governance.read(x, executor, msg.sender, p.reasonHash, context());
        require(last.actionId == prepared.actionId, "active same action");
        Reads.requireExecuted(prepared);
        return keccak256(abi.encode(last));
    }

    function witness()
        external
        view
        returns (ActionPrep.Witness memory, Contest.GovernanceWitness memory)
    {
        return (prepared, last);
    }

    function scheduled() external view {
        Reads.requireScheduled(prepared);
    }

    function terminal() external view returns (bool) {
        return Reads.terminal(prepared);
    }
}

/// @dev Real delayed Executor/catalog/roles/full publication paired with the exact action reader; Identity owner mutation is separate evidence.
contract StreamArtistGuardianAppealGovernanceActualTest is ArtistRecoveryGovernanceFixture {
    ActualGuardianAppealTarget private target;
    bytes32 private constant APPEAL = keccak256("ROLE_ATTRIBUTION_APPEAL");

    function _initializeRecoveryWitness() private {
        (SystemManifestBootstrapBinding memory binding, GenesisBatch[] memory batches) = _plan();
        configuration.executor
            .commitGenesisPlan(configuration.executor.hashGenesisPlan(binding, batches));
        configuration.executor.initializeGenesis(binding, batches);
        target = new ActualGuardianAppealTarget(
            address(configuration.core),
            address(configuration.executor),
            address(configuration.roles)
        );
        GovernanceActionPolicyEntry[] memory additions = new GovernanceActionPolicyEntry[](3);
        additions[0] = _entry(1, address(target), target.recoverArtistIdentity.selector);
        additions[1] = _entry(2, address(target), target.recoverArtistIdentity.selector);
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
        _appeal(true);
    }

    function _appeal(bool grant) private {
        address holder = address(governor);
        StreamRoleRegistry roles = configuration.roles;
        (bytes32 roleChain, uint64 roleRevision) = roles.roleMutationState(APPEAL);
        (bytes32 globalChain, uint64 globalRevision) = roles.globalRoleMutationState();
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1"),
                block.chainid,
                address(roles),
                APPEAL,
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
                APPEAL,
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
                APPEAL,
                holder,
                grant,
                globalRevision + 1
            )
        );
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        bytes[] memory data = new bytes[](1);
        data[0] = grant
            ? abi.encodeCall(roles.grantRole, (APPEAL, holder))
            : abi.encodeCall(roles.revokeRole, (APPEAL, holder));
        calls[0] = StreamCurrentStackPlan.call(
            address(roles),
            data[0],
            scope,
            oldState,
            _roleState(scope, grant, nextRole, roleRevision + 1, nextGlobal, globalRevision + 1)
        );
        _runBatch(1, calls, data);
        require(roles.hasRole(APPEAL, holder) == grant, "actual appeal mutation");
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

    function _batch()
        private
        view
        returns (
            GovernanceCall[] memory calls,
            bytes[] memory data,
            Recovery35.Request memory p,
            T.Authorization memory a
        )
    {
        p.artistId = keccak256("fixture artist");
        p.newAddress = address(0x7777);
        p.vestedAuthorityClass = 1;
        p.reasonHash = keccak256("staged products");
        p.evidenceHash = keccak256("full action evidence");
        a = T.Authorization(7, uint64(block.timestamp + 30 days), hex"010203");
        Recovery35.Context memory c = target.context();
        calls = new GovernanceCall[](2);
        data = new bytes[](2);
        data[0] = abi.encodeCall(target.assertion, ());
        calls[0] = StreamCurrentStackPlan.call(
            address(target), data[0], keccak256("other scope"), 0, keccak256("asserted")
        );
        data[1] = abi.encodeCall(target.recoverArtistIdentity, (p, a));
        calls[1] = StreamCurrentStackPlan.call(
            address(target), data[1], c.scopeHash, c.oldValueHash, c.newValueHash
        );
    }

    function testActualRootAppealPublishedAssociationAndStrictExecution() public {
        _initializeRecoveryWitness();
        (
            GovernanceCall[] memory calls,
            bytes[] memory data,
            Recovery35.Request memory p,
            T.Authorization memory a
        ) = _batch();
        (bytes32 id, uint64 ready) = this.scheduleFoundationBatch(2, calls, data);
        require(
            keccak256(abi.encode(configuration.executor.scheduledCallData(id)))
                == keccak256(abi.encode(data)),
            "all published calldata exact"
        );
        bytes32 original = calls[0].callDataHash;
        calls[0].callDataHash = keccak256("unpublished");
        vm.expectRevert();
        target.register(id, calls, p, a);
        calls[0].callDataHash = original;
        target.register(id, calls, p, a);
        (ActionPrep.Witness memory w, Contest.GovernanceWitness memory g) = target.witness();
        require(
            w.actionId == id && w.callsHash == StreamGovernanceBootstrap.governanceCallsHash(calls)
                && w.callIndex == 1 && w.callDataHash == keccak256(data[1]) && g.actionId == 0,
            "actual second call association"
        );
        require(
            w.proposer == address(governor)
                && w.minimumDelay == configuration.executor.minimumDelay(2) && w.notBefore == ready,
            "original proposer and whole delay"
        );
        vm.expectRevert();
        target.recoverArtistIdentity(p, a);
        vm.expectRevert();
        this.executeFoundationBatch(id, calls, data);
        vm.warp(ready);
        target.scheduled();
        this.executeFoundationBatch(id, calls, data);
        (w, g) = target.witness();
        require(
            g.actionId == id && g.scopeHash == calls[1].scopeHash
                && g.oldValueHash == calls[1].oldValueHash
                && g.newValueHash == calls[1].newValueHash && target.terminal(),
            "actual active current-call and executed joins"
        );
        vm.expectRevert();
        target.recoverArtistIdentity(p, a);
        vm.expectRevert();
        this.executeFoundationBatch(id, calls, data);
    }

    function testActualRootAppealLateRegistrationAndGlobalVetoStayDistinct() public {
        _initializeRecoveryWitness();
        (
            GovernanceCall[] memory calls,
            bytes[] memory data,
            Recovery35.Request memory p,
            T.Authorization memory a
        ) = _batch();
        (bytes32 late, uint64 ready) = this.scheduleFoundationBatch(2, calls, data);
        vm.warp(block.timestamp + 1);
        vm.expectRevert();
        target.register(late, calls, p, a);
        (bytes32 id, uint64 nextReady) = this.scheduleFoundationBatch(2, calls, data);
        target.register(id, calls, p, a);
        require(nextReady > ready, "fresh full registration interval");
        StreamGovernanceActor(payable(configuration.guardians[0]))
            .execute(
                address(configuration.executor),
                0,
                abi.encodeCall(
                    configuration.executor.vetoTerminalFreeze,
                    (id, keccak256("independent global veto"))
                )
            );
        require(target.terminal(), "actual global veto terminal");
        vm.expectRevert();
        target.scheduled();
        vm.warp(nextReady);
        vm.expectRevert();
        this.executeFoundationBatch(id, calls, data);
        (, Contest.GovernanceWitness memory g) = target.witness();
        require(g.actionId == 0, "never executed");
    }

    function testActualRootAppealRevocationAndRegrantCannotReviveAction() public {
        _initializeRecoveryWitness();
        (
            GovernanceCall[] memory calls,
            bytes[] memory data,
            Recovery35.Request memory p,
            T.Authorization memory a
        ) = _batch();
        (bytes32 id, uint64 ready) = this.scheduleFoundationBatch(2, calls, data);
        target.register(id, calls, p, a);
        _appeal(false);
        vm.warp(ready);
        vm.expectRevert();
        this.executeFoundationBatch(id, calls, data);
        require(
            configuration.executor.governanceAction(id).status == GovernanceActionStatus.SCHEDULED
        );
        _appeal(true);
        require(
            block.timestamp <= configuration.executor.governanceAction(id).expiresAfter,
            "original action still executable by time"
        );
        require(
            configuration.roles.hasRole(APPEAL, address(governor)), "actual appeal role regranted"
        );
        (address currentRoot,,) = configuration.executor.governanceRootState();
        require(
            currentRoot == address(governor) && configuration.executor.owner() == currentRoot,
            "root unchanged"
        );
        require(
            target.context().oldValueHash != calls[1].oldValueHash,
            "specific original context invalidation"
        );
        vm.expectRevert();
        this.executeFoundationBatch(id, calls, data);
        (, Contest.GovernanceWitness memory g) = target.witness();
        require(g.actionId == 0, "changed root appeal chain invalidates original scheduled context");
    }
}
