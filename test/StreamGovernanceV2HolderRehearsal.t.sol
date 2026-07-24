// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/IStreamGasParameterHost.sol";
import "../smart-contracts/IStreamGovernanceExecutor.sol";
import "../smart-contracts/IStreamModuleRegistry.sol";
import "../smart-contracts/IStreamRoleRegistry.sol";
import "../smart-contracts/StreamForwardingCapProbe.sol";
import "../smart-contracts/StreamGasParameterStore.sol";
import "../smart-contracts/StreamGovernanceBootstrap.sol";
import "../smart-contracts/StreamGovernanceExecutor.sol";
import "../smart-contracts/StreamRoleRegistry.sol";
import "../smart-contracts/StreamRoles.sol";
import "./helpers/StreamGovernanceBootstrapHarness.sol";
import "./helpers/StreamGovernanceV2HolderRehearsalMocks.sol";

/// @dev Rehearsal-only terminal target. Its target-side context check proves
///      that the action vetoed below was executable as an exact class-2
///      transition rather than an inert descriptor assembled only for veto.
contract StreamGovernanceV2TerminalFreezeRehearsalTarget {
    bytes32 private constant _SCOPE_DOMAIN =
        keccak256("6529STREAM_HOLDER_REHEARSAL_TERMINAL_SCOPE_V1");
    bytes32 private constant _STATE_DOMAIN =
        keccak256("6529STREAM_HOLDER_REHEARSAL_TERMINAL_STATE_V1");

    IStreamGovernanceExecutor private immutable _governanceAuthority;

    bool public frozen;
    uint64 public revision;

    constructor(IStreamGovernanceExecutor governanceAuthority_) {
        _governanceAuthority = governanceAuthority_;
    }

    function terminalFreeze() external {
        require(msg.sender == address(_governanceAuthority), "terminal governance authority");
        (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash) = transitionHashes();
        (
            bool executing,,
            uint8 actionClass,
            bytes32 currentScopeHash,
            bytes32 currentOldStateHash,
            bytes32 currentNewStateHash
        ) = _governanceAuthority.currentAction();
        require(executing, "terminal context inactive");
        require(
            actionClass == StreamGovernanceActionClasses.TERMINAL_FREEZE, "terminal action class"
        );
        require(currentScopeHash == scopeHash, "terminal scope");
        require(currentOldStateHash == oldStateHash, "terminal old state");
        require(currentNewStateHash == newStateHash, "terminal new state");
        require(!frozen, "terminal already frozen");
        frozen = true;
        revision += 1;
    }

    function transitionHashes()
        public
        view
        returns (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash)
    {
        scopeHash = keccak256(
            abi.encode(_SCOPE_DOMAIN, block.chainid, address(this), this.terminalFreeze.selector)
        );
        oldStateHash = _stateHash(scopeHash, frozen, revision);
        newStateHash = _stateHash(scopeHash, true, revision + 1);
    }

    function _stateHash(bytes32 scopeHash, bool frozen_, uint64 revision_)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(_STATE_DOMAIN, block.chainid, address(this), scopeHash, frozen_, revision_)
        );
    }
}

/// @notice Executable local evidence for ADR 0004 [GOV-V2-CUTOVER] item 4.
/// @dev This is deliberately not production-holder evidence. It proves against
///      the production executor and production GGP host that calls scheduled and
///      executed by each supported contract-holder class preserve the complete
///      Governance V2 context and target-side emergency-restoration invariants.
contract StreamGovernanceV2HolderRehearsalTest is StreamGovernanceBootstrapHarness {
    struct GasParameterStateCommitment {
        bytes32 scopeHash;
        uint256 value;
        uint256 floor;
        address probe;
        bytes32 probeRuntimeCodeHash;
        bytes32 probeBindingHash;
        uint8 failureClass;
        uint64 probeMaxAgeBlocks;
        bytes32 conditionalRaiseActionId;
        bytes32 conditionalRelowerActionId;
        uint64 revision;
    }

    struct RehearsalAction {
        bytes32 actionId;
        GovernanceCall[] calls;
        bytes[] callDatas;
        bytes32 holderOperationId;
    }

    uint256 private constant _START_BLOCK = 1_000_000;
    uint64 private constant _START_TIME = 2_000_000_000;
    uint64 private constant _PROBE_MAX_AGE_BLOCKS = 50_400;
    uint64 private constant _GOVERNOR_VOTING_DELAY_BLOCKS = 2;
    uint64 private constant _GOVERNOR_VOTING_PERIOD_BLOCKS = 5;
    uint64 private constant _GOVERNOR_QUORUM = 2;
    uint64 private constant _TIMELOCK_DELAY_SECONDS = 2 days;
    uint64 private constant _SAFE_THRESHOLD = 2;
    uint256 private constant _GENESIS_GAS_VALUE = 50_000;
    uint256 private constant _SAFE_RAISED_GAS_VALUE = 75_000;
    uint256 private constant _GOVERNOR_RAISED_GAS_VALUE = 100_000;
    uint256 private constant _GAS_FLOOR = 10_000;
    uint256 private constant _DEGRADED_SCENARIO_MINIMUM_GAS = 250_000;
    uint256 private constant _NATIVE_REHEARSAL_VALUE = 0.25 ether;
    bytes32 private constant _PARAMETER_ID =
        0x9bae92ab1dd0c5535c65125ea4ee7cff3d55fc31fc2555096c2b5eabceb5bcda;
    bytes32 private constant _SAFE_RUNTIME_CODE_HASH =
        0x07afc83f9eb3975b6a6a7a8fab7a53792576182a81549974e08d35f43545f9bb;
    bytes32 private constant _GOVERNOR_RUNTIME_CODE_HASH =
        0x2263d7c9f59bc65f3ff00a0437556480bcc2410eef6c448467773c51e8047873;
    bytes32 private constant _TIMELOCK_RUNTIME_CODE_HASH =
        0xc8e7ad494d651bb45b57dfd91f32d158bc5eefebc729b0d72bacd6361c6ed2b4;
    bytes32 private constant _EMERGENCY_SCOPE_DOMAIN =
        0xb9085dad05460da2726c7e111c53618efbcaf3fefea1e4d419ce162fe04e8d0b;
    bytes32 private constant _EMERGENCY_STATE_DOMAIN =
        0x9e9da69a2ae8579f9356a29767b060277c495f965d4d7ae73169e241232160ae;
    bytes32 private constant _EMERGENCY_RECORD_DOMAIN =
        0xbc91b88f68461f99b3836432e21ee3043827c2937229121ccbb955fee3125004;
    bytes32 private constant _EMERGENCY_CHAIN_DOMAIN =
        0xed9c1773f24c613652817d2dc58a04d22ceda9bb51fade48ea848ae5d322f340;
    bytes32 private constant _ROLE_MUTATION_SCOPE_V1 =
        keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1");
    bytes32 private constant _ROLE_MUTATION_STATE_V1 =
        keccak256("6529STREAM_ROLE_MUTATION_STATE_V1");
    bytes32 private constant _ROLE_MUTATION_RECORD_V1 = keccak256("6529STREAM_ROLE_MUTATION_V1");
    bytes32 private constant _GLOBAL_ROLE_MUTATION_RECORD_V1 =
        keccak256("6529STREAM_GLOBAL_ROLE_MUTATION_V1");
    bytes32 private constant _GOVERNANCE_CONFIG_SCOPE_V1 =
        keccak256("6529STREAM_GOVERNANCE_CONFIG_SCOPE_V1");
    bytes32 private constant _GOVERNANCE_CONFIG_STATE_V1 =
        keccak256("6529STREAM_GOVERNANCE_CONFIG_STATE_V1");
    bytes32 private constant _GOVERNANCE_CONFIG_PROPOSER =
        keccak256("6529STREAM_GOVERNANCE_CONFIG_PROPOSER");
    bytes32 private constant _GOVERNANCE_CONFIG_NATIVE_RECEIVER =
        keccak256("6529STREAM_GOVERNANCE_CONFIG_NATIVE_RECEIVER");

    address private constant _SAFE_OWNER_ONE = address(0xA001);
    address private constant _SAFE_OWNER_TWO = address(0xA002);
    address private constant _SAFE_OWNER_THREE = address(0xA003);
    address private constant _VETO_SAFE_OWNER_ONE = address(0xC001);
    address private constant _VETO_SAFE_OWNER_TWO = address(0xC002);
    address private constant _VETO_SAFE_OWNER_THREE = address(0xC003);
    address private constant _GOVERNOR_VOTER_ONE = address(0xB001);
    address private constant _GOVERNOR_VOTER_TWO = address(0xB002);
    address private constant _GOVERNOR_VOTER_THREE = address(0xB003);

    StreamRoleRegistry private _roleRegistry;
    BootstrapArtifacts private _bootstrap;
    StreamGovernanceExecutor private _executor;
    StreamGovernanceV2SafeRehearsal private _schedulingSafe;
    StreamGovernanceV2SafeRehearsal private _vetoSafe;
    StreamReferenceTimelockRehearsal private _timelock;
    StreamReferenceGovernorRehearsal private _governor;
    StreamGovernanceV2RehearsalCorePointer private _core;
    StreamGovernanceV2RehearsalModuleRegistry private _moduleRegistry;
    StreamGovernanceV2RehearsalGasConsumer private _consumer;
    StreamGovernanceV2TerminalFreezeRehearsalTarget private _terminalTarget;
    StreamForwardingCapProbe private _probe;
    StreamGasParameterStore private _store;

    function setUp() public {
        vm.roll(_START_BLOCK);
        vm.warp(_START_TIME);

        _bootstrap = _deploySealedExecutor(address(this));
        _executor = _bootstrap.executor;
        _roleRegistry = _bootstrap.roleRegistry;

        address[] memory safeOwners = new address[](3);
        safeOwners[0] = _SAFE_OWNER_ONE;
        safeOwners[1] = _SAFE_OWNER_TWO;
        safeOwners[2] = _SAFE_OWNER_THREE;
        _schedulingSafe = new StreamGovernanceV2SafeRehearsal(safeOwners, _SAFE_THRESHOLD);
        address[] memory vetoSafeOwners = new address[](3);
        vetoSafeOwners[0] = _VETO_SAFE_OWNER_ONE;
        vetoSafeOwners[1] = _VETO_SAFE_OWNER_TWO;
        vetoSafeOwners[2] = _VETO_SAFE_OWNER_THREE;
        _vetoSafe = new StreamGovernanceV2SafeRehearsal(vetoSafeOwners, _SAFE_THRESHOLD);

        _timelock = new StreamReferenceTimelockRehearsal(_TIMELOCK_DELAY_SECONDS);
        address[] memory governorVoters = new address[](3);
        governorVoters[0] = _GOVERNOR_VOTER_ONE;
        governorVoters[1] = _GOVERNOR_VOTER_TWO;
        governorVoters[2] = _GOVERNOR_VOTER_THREE;
        _governor = new StreamReferenceGovernorRehearsal(
            governorVoters,
            _GOVERNOR_VOTING_DELAY_BLOCKS,
            _GOVERNOR_VOTING_PERIOD_BLOCKS,
            _GOVERNOR_QUORUM,
            _timelock
        );
        _timelock.bindGovernor(address(_governor));

        _moduleRegistry = new StreamGovernanceV2RehearsalModuleRegistry();
        _core = new StreamGovernanceV2RehearsalCorePointer(address(_moduleRegistry));
        _consumer = new StreamGovernanceV2RehearsalGasConsumer(_DEGRADED_SCENARIO_MINIMUM_GAS);
        _terminalTarget = new StreamGovernanceV2TerminalFreezeRehearsalTarget(_executor);
        _probe = new StreamForwardingCapProbe(
            "ROYALTY_RESOLVER_GAS_LIMIT",
            address(_consumer),
            abi.encodeCall(StreamGovernanceV2RehearsalGasConsumer.guardedRead, ())
        );
        _moduleRegistry.registerGasProbe(address(_probe));
        IStreamGasParameterHost.GasParameterConfig[] memory configs =
            new IStreamGasParameterHost.GasParameterConfig[](1);
        configs[0] = IStreamGasParameterHost.GasParameterConfig({
            name: "ROYALTY_RESOLVER_GAS_LIMIT",
            genesisValue: _GENESIS_GAS_VALUE,
            floor: _GAS_FLOOR,
            probe: address(_probe),
            failureClass: 1,
            probeMaxAgeBlocks: _PROBE_MAX_AGE_BLOCKS,
            expectedProbeModuleVersion: keccak256("STREAM_GOVERNANCE_V2_REHEARSAL_PROBE_V1"),
            expectedProbeRuntimeCodeHash: address(_probe).codehash,
            expectedProbeModuleManifestHash: keccak256(
                abi.encode("rehearsal-module", address(_probe).codehash)
            ),
            expectedProbeDeploymentManifestHash: keccak256(
                abi.encode("rehearsal-deployment", address(_probe).codehash)
            )
        });
        _store = new StreamGasParameterStore(
            address(_executor), address(_core), address(_moduleRegistry), configs
        );

        _grantTerminalVetoRoleThroughRoot(address(_vetoSafe));
        _registerEmergencyEligibility();
        _registerProposerThroughRoot(address(_schedulingSafe));
        _registerProposerThroughRoot(address(_timelock));
    }

    function testBoundSealedExecutorAndHolderPostures() public {
        (bool ok, bytes memory encodedState) = address(_executor)
            .staticcall(abi.encodeCall(_executor.systemManifestBootstrapState, ()));
        require(ok, "bootstrap state read failed");
        BootstrapStateCommitment memory bootstrapState =
            abi.decode(encodedState, (BootstrapStateCommitment));
        require(bootstrapState.bound, "executor not bound");
        require(bootstrapState.isSealed, "executor not sealed");
        require(bootstrapState.sealedPayloadPointer != address(0), "sealed payload missing");

        require(_schedulingSafe.ownerCount() == 3, "scheduling safe owner count");
        require(_schedulingSafe.threshold() == _SAFE_THRESHOLD, "scheduling safe threshold");
        require(_vetoSafe.ownerCount() == 3, "veto safe owner count");
        require(_vetoSafe.threshold() == _SAFE_THRESHOLD, "veto safe threshold");
        require(address(_schedulingSafe) != address(_vetoSafe), "holder safes are distinct");
        require(_schedulingSafe.ownerAt(0) == _SAFE_OWNER_ONE, "scheduling safe owner");
        require(_vetoSafe.ownerAt(0) == _VETO_SAFE_OWNER_ONE, "veto safe owner");
        require(!_schedulingSafe.isOwner(_VETO_SAFE_OWNER_ONE), "veto signer in scheduling safe");
        require(!_vetoSafe.isOwner(_SAFE_OWNER_ONE), "scheduling signer in veto safe");
        require(_governor.voterCount() == 3, "governor voter count");
        require(
            _governor.votingDelayBlocks() == _GOVERNOR_VOTING_DELAY_BLOCKS, "governor voting delay"
        );
        require(
            _governor.votingPeriodBlocks() == _GOVERNOR_VOTING_PERIOD_BLOCKS,
            "governor voting period"
        );
        require(_governor.quorumVotes() == _GOVERNOR_QUORUM, "governor quorum");
        require(address(_governor.timelock()) == address(_timelock), "governor timelock");
        require(_timelock.governor() == address(_governor), "timelock binding");
        require(_timelock.minimumDelaySeconds() == _TIMELOCK_DELAY_SECONDS, "timelock delay");
        require(
            address(_schedulingSafe).codehash == _SAFE_RUNTIME_CODE_HASH, "scheduling safe codehash"
        );
        require(address(_vetoSafe).codehash == _SAFE_RUNTIME_CODE_HASH, "veto safe codehash");
        require(address(_governor).codehash == _GOVERNOR_RUNTIME_CODE_HASH, "governor codehash");
        require(address(_timelock).codehash == _TIMELOCK_RUNTIME_CODE_HASH, "timelock codehash");
        require(
            keccak256(type(StreamGovernanceV2SafeRehearsal).runtimeCode) == _SAFE_RUNTIME_CODE_HASH,
            "safe compilation-unit runtime codehash"
        );
        require(
            keccak256(type(StreamReferenceGovernorRehearsal).runtimeCode)
                == _GOVERNOR_RUNTIME_CODE_HASH,
            "governor compilation-unit runtime codehash"
        );
        require(
            keccak256(type(StreamReferenceTimelockRehearsal).runtimeCode)
                == _TIMELOCK_RUNTIME_CODE_HASH,
            "timelock compilation-unit runtime codehash"
        );

        bytes32 digest = keccak256("GOVERNANCE_V2_HOLDER_REHEARSAL_ERC1271");
        require(
            _schedulingSafe.isValidSignature(digest, "") == bytes4(0xffffffff),
            "scheduling safe accepted below threshold"
        );
        vm.prank(_SAFE_OWNER_ONE);
        _schedulingSafe.approveDigest(digest);
        vm.prank(_SAFE_OWNER_TWO);
        _schedulingSafe.approveDigest(digest);
        require(
            _schedulingSafe.isValidSignature(digest, "") == bytes4(0x1626ba7e),
            "scheduling safe ERC1271 threshold"
        );
        require(
            _roleRegistry.hasRole(StreamRoles.ROLE_TERMINAL_FREEZE_VETO, address(_vetoSafe)),
            "veto safe role"
        );
        require(
            !_roleRegistry.hasRole(StreamRoles.ROLE_TERMINAL_FREEZE_VETO, address(_schedulingSafe)),
            "scheduling safe not veto guardian"
        );
        require(_executor.isProposer(address(_schedulingSafe)), "scheduling safe proposer");
        require(!_executor.isProposer(address(_vetoSafe)), "veto safe not proposer");
        require(_executor.isProposer(address(_timelock)), "timelock proposer");

        require(
            _governor.isValidSignature(digest, "") == bytes4(0xffffffff),
            "governor accepted below quorum"
        );
        vm.prank(_GOVERNOR_VOTER_ONE);
        _governor.approveDigest(digest);
        vm.prank(_GOVERNOR_VOTER_TWO);
        _governor.approveDigest(digest);
        require(
            _governor.isValidSignature(digest, "") == bytes4(0x1626ba7e), "governor ERC1271 quorum"
        );
    }

    function testDedicatedVetoSafeVetoesExecutableTerminalFreeze() public {
        (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash) =
            _terminalTarget.transitionHashes();
        bytes memory callData =
            abi.encodeCall(StreamGovernanceV2TerminalFreezeRehearsalTarget.terminalFreeze, ());
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        calls[0] = GovernanceCall({
            target: address(_terminalTarget),
            value: 0,
            selector: StreamGovernanceV2TerminalFreezeRehearsalTarget.terminalFreeze.selector,
            callDataHash: keccak256(callData),
            scopeHash: scopeHash,
            oldValueHash: oldStateHash,
            newValueHash: newStateHash
        });
        bytes[] memory callDatas = new bytes[](1);
        callDatas[0] = callData;
        _executor.publishGovernanceCallData(callDatas);
        (bytes32 aggregateScope, bytes32 aggregateOld, bytes32 aggregateNew) =
            _aggregateHashes(calls);
        uint64 notBefore = uint64(block.timestamp)
            + _executor.minimumDelay(StreamGovernanceActionClasses.TERMINAL_FREEZE);
        bytes32 actionId = _executor.scheduleGovernanceBatch(
            StreamGovernanceActionClasses.TERMINAL_FREEZE,
            calls,
            aggregateScope,
            aggregateOld,
            aggregateNew,
            notBefore,
            notBefore + 7 days,
            keccak256("dedicated-veto-safe-terminal-freeze"),
            "ipfs://local-governance-v2-holder-rehearsal/veto-safe",
            _bootstrap.manifestHash
        );

        bytes memory vetoCallData = abi.encodeCall(
            _executor.vetoTerminalFreeze, (actionId, keccak256("holder-rehearsal-terminal-veto"))
        );
        uint256 schedulingSafeTransactionId = _prepareSafeCall(
            _schedulingSafe, _SAFE_OWNER_ONE, _SAFE_OWNER_TWO, address(_executor), 0, vetoCallData
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.NotTerminalFreezeVetoGuardian.selector,
                address(_schedulingSafe)
            )
        );
        vm.prank(_SAFE_OWNER_THREE);
        _schedulingSafe.executeTransaction(schedulingSafeTransactionId);

        _vetoSafeInvoke(address(_executor), 0, vetoCallData);

        GovernanceAction memory vetoed = _executor.governanceAction(actionId);
        require(vetoed.status == GovernanceActionStatus.VETOED, "terminal action not vetoed");
        require(vetoed.vetoer == address(_vetoSafe), "dedicated veto safe not recorded");
        require(!_terminalTarget.frozen(), "vetoed terminal transition executed");
        require(!_executor.isProposer(address(_vetoSafe)), "veto safe gained proposer authority");
    }

    function testSafeAndGovernorExecuteClassSixEndToEnd() public {
        (bytes32 safeRunId, bool safeProbePassed) = _probe.recordProbeRun(_GENESIS_GAS_VALUE);
        require(safeRunId != bytes32(0) && !safeProbePassed, "safe failing probe evidence");

        RehearsalAction memory safeAction = _scheduleEmergencyViaSafe(_SAFE_RAISED_GAS_VALUE);
        GovernanceAction memory safeScheduled = _executor.governanceAction(safeAction.actionId);
        require(
            safeScheduled.proposer == address(_schedulingSafe), "safe was not scheduler msg.sender"
        );
        require(
            safeScheduled.actionClass == StreamGovernanceActionClasses.EMERGENCY_RESTORATION,
            "safe action class"
        );
        _executeViaSafe(safeAction, 0);
        GovernanceAction memory safeExecuted = _executor.governanceAction(safeAction.actionId);
        require(
            safeExecuted.executor == address(_schedulingSafe), "safe was not executor msg.sender"
        );
        _assertParameterState(_SAFE_RAISED_GAS_VALUE, 2);
        _assertContextCleared();

        (bytes32 governorRunId, bool governorProbePassed) =
            _probe.recordProbeRun(_SAFE_RAISED_GAS_VALUE);
        require(
            governorRunId != bytes32(0) && !governorProbePassed, "governor failing probe evidence"
        );
        RehearsalAction memory governorAction =
            _scheduleEmergencyViaGovernor(_GOVERNOR_RAISED_GAS_VALUE);
        GovernanceAction memory governorScheduled =
            _executor.governanceAction(governorAction.actionId);
        require(
            governorScheduled.proposer == address(_timelock),
            "timelock was not scheduler msg.sender"
        );
        _assertGovernorLatency(governorAction.holderOperationId);
        governorAction.holderOperationId = _executeViaGovernor(governorAction, 0);
        GovernanceAction memory governorExecuted =
            _executor.governanceAction(governorAction.actionId);
        require(
            governorExecuted.executor == address(_timelock), "timelock was not executor msg.sender"
        );
        _assertGovernorLatency(governorAction.holderOperationId);
        _assertParameterState(_GOVERNOR_RAISED_GAS_VALUE, 3);
        _assertContextCleared();
    }

    function testPassingProbeBlocksClassSixAtTarget() public {
        _consumer.setMinimumGas(1);
        (bytes32 runId, bool passed) = _probe.recordProbeRun(_GENESIS_GAS_VALUE);
        require(runId != bytes32(0) && passed, "passing probe evidence");
        RehearsalAction memory action = _scheduleEmergencyViaSafe(_SAFE_RAISED_GAS_VALUE);
        uint256 transactionId = _prepareSafeExecution(action, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeHealthy.selector,
                _PARAMETER_ID,
                _GENESIS_GAS_VALUE
            )
        );
        vm.prank(_SAFE_OWNER_THREE);
        _schedulingSafe.executeTransaction(transactionId);
        _assertParameterState(_GENESIS_GAS_VALUE, 1);
    }

    function testStaleProbeBlocksClassSixAtTarget() public {
        (bytes32 runId, bool passed) = _probe.recordProbeRun(_GENESIS_GAS_VALUE);
        require(runId != bytes32(0) && !passed, "failing probe evidence");
        (,, uint64 probedAtBlock) = _probe.lastProbeRun(_PARAMETER_ID, _GENESIS_GAS_VALUE);
        vm.roll(uint256(probedAtBlock) + _PROBE_MAX_AGE_BLOCKS + 1);

        RehearsalAction memory action = _scheduleEmergencyViaSafe(_SAFE_RAISED_GAS_VALUE);
        uint256 transactionId = _prepareSafeExecution(action, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeRecordStale.selector,
                _PARAMETER_ID,
                _GENESIS_GAS_VALUE,
                probedAtBlock,
                _PROBE_MAX_AGE_BLOCKS
            )
        );
        vm.prank(_SAFE_OWNER_THREE);
        _schedulingSafe.executeTransaction(transactionId);
        _assertParameterState(_GENESIS_GAS_VALUE, 1);
    }

    function testOverBoundRaiseBlocksClassSixAtTarget() public {
        (bytes32 runId, bool passed) = _probe.recordProbeRun(_GENESIS_GAS_VALUE);
        require(runId != bytes32(0) && !passed, "failing probe evidence");
        uint256 overBoundValue = (_GENESIS_GAS_VALUE * 2) + 1;
        RehearsalAction memory action = _scheduleEmergencyViaSafe(overBoundValue);
        uint256 transactionId = _prepareSafeExecution(action, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterRaiseBoundExceeded.selector,
                _PARAMETER_ID,
                _GENESIS_GAS_VALUE,
                overBoundValue
            )
        );
        vm.prank(_SAFE_OWNER_THREE);
        _schedulingSafe.executeTransaction(transactionId);
        _assertParameterState(_GENESIS_GAS_VALUE, 1);
    }

    function testForgedSixReturnContextBlocksClassSixAtTarget() public {
        (bytes32 runId, bool passed) = _probe.recordProbeRun(_GENESIS_GAS_VALUE);
        require(runId != bytes32(0) && !passed, "failing probe evidence");
        bytes32 expectedOldStateHash = _stateHash(_GENESIS_GAS_VALUE, 1);
        bytes32 forgedOldStateHash = keccak256("forged-governance-v2-old-state");
        RehearsalAction memory action =
            _scheduleEmergencyViaSafe(_SAFE_RAISED_GAS_VALUE, forgedOldStateHash);
        uint256 transactionId = _prepareSafeExecution(action, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterOldStateHashMismatch.selector,
                expectedOldStateHash,
                forgedOldStateHash
            )
        );
        vm.prank(_SAFE_OWNER_THREE);
        _schedulingSafe.executeTransaction(transactionId);
        _assertParameterState(_GENESIS_GAS_VALUE, 1);
    }

    function testSafeAndGovernorExecuteNonzeroNativeTransfer() public {
        _approveNativeReceiverThroughRoot(address(_schedulingSafe));
        _approveNativeReceiverThroughRoot(address(_governor));

        RehearsalAction memory safeAction = _scheduleNativeViaSafe(
            address(_schedulingSafe),
            _NATIVE_REHEARSAL_VALUE,
            uint64(block.timestamp)
                + _executor.minimumDelay(StreamGovernanceActionClasses.FUNDS_RECOVERY)
        );
        GovernanceAction memory safeScheduled = _executor.governanceAction(safeAction.actionId);
        vm.warp(safeScheduled.notBefore);
        vm.deal(address(_schedulingSafe), _NATIVE_REHEARSAL_VALUE);
        _executeViaSafe(safeAction, _NATIVE_REHEARSAL_VALUE);
        require(_schedulingSafe.receivedNative() == _NATIVE_REHEARSAL_VALUE, "safe native receive");
        require(_schedulingSafe.lastNativeSender() == address(_executor), "safe native sender");

        uint64 governorNotBefore = uint64(block.timestamp) + _TIMELOCK_DELAY_SECONDS
            + _executor.minimumDelay(StreamGovernanceActionClasses.FUNDS_RECOVERY);
        RehearsalAction memory governorAction = _scheduleNativeViaGovernor(
            address(_governor), _NATIVE_REHEARSAL_VALUE, governorNotBefore
        );
        GovernanceAction memory governorScheduled =
            _executor.governanceAction(governorAction.actionId);
        require(governorScheduled.proposer == address(_timelock), "native governor scheduler");
        vm.warp(governorScheduled.notBefore);
        vm.deal(address(_governor), _NATIVE_REHEARSAL_VALUE);
        governorAction.holderOperationId =
            _executeViaGovernor(governorAction, _NATIVE_REHEARSAL_VALUE);
        require(_governor.receivedNative() == _NATIVE_REHEARSAL_VALUE, "governor native receive");
        require(_governor.lastNativeSender() == address(_executor), "governor native sender");
        GovernanceAction memory governorExecuted =
            _executor.governanceAction(governorAction.actionId);
        require(governorExecuted.executor == address(_timelock), "native governor executor");
        _assertGovernorLatency(governorAction.holderOperationId);
    }

    /// @dev Exact RoleRegistry V2 transition evidence. The target independently
    ///      enforces this shared scope/state formula against `currentAction()`;
    ///      the rehearsal also verifies the resulting per-role and global
    ///      mutation chains.
    function _grantTerminalVetoRoleThroughRoot(address guardian) private {
        bytes32 role = StreamRoles.ROLE_TERMINAL_FREEZE_VETO;
        require(!_roleRegistry.hasRole(role, guardian), "veto role already granted");
        (bytes32 roleChainHash, uint64 roleRevision) = _roleRegistry.roleMutationState(role);
        (bytes32 globalChainHash, uint64 globalRevision) = _roleRegistry.globalRoleMutationState();
        bytes32 scopeHash = keccak256(
            abi.encode(
                _ROLE_MUTATION_SCOPE_V1, block.chainid, address(_roleRegistry), role, guardian
            )
        );
        bytes32 oldStateHash = _roleMutationStateHash(
            scopeHash, false, roleChainHash, roleRevision, globalChainHash, globalRevision
        );
        uint64 nextRoleRevision = roleRevision + 1;
        uint64 nextGlobalRevision = globalRevision + 1;
        bytes32 nextRoleChainHash = keccak256(
            abi.encode(
                _ROLE_MUTATION_RECORD_V1,
                roleChainHash,
                block.chainid,
                address(_roleRegistry),
                role,
                guardian,
                true,
                nextRoleRevision
            )
        );
        bytes32 nextGlobalChainHash = keccak256(
            abi.encode(
                _GLOBAL_ROLE_MUTATION_RECORD_V1,
                globalChainHash,
                block.chainid,
                address(_roleRegistry),
                role,
                guardian,
                true,
                nextGlobalRevision
            )
        );
        bytes32 newStateHash = _roleMutationStateHash(
            scopeHash,
            true,
            nextRoleChainHash,
            nextRoleRevision,
            nextGlobalChainHash,
            nextGlobalRevision
        );
        bytes memory callData =
            abi.encodeWithSelector(IStreamRoleRegistry.grantRole.selector, role, guardian);
        _executeRootDelayedCall(
            address(_roleRegistry),
            IStreamRoleRegistry.grantRole.selector,
            callData,
            scopeHash,
            oldStateHash,
            newStateHash,
            keccak256("grant-dedicated-veto-safe")
        );

        (bytes32 actualRoleChainHash, uint64 actualRoleRevision) =
            _roleRegistry.roleMutationState(role);
        (bytes32 actualGlobalChainHash, uint64 actualGlobalRevision) =
            _roleRegistry.globalRoleMutationState();
        require(_roleRegistry.hasRole(role, guardian), "veto role grant missing");
        require(actualRoleChainHash == nextRoleChainHash, "role mutation chain");
        require(actualRoleRevision == nextRoleRevision, "role mutation revision");
        require(actualGlobalChainHash == nextGlobalChainHash, "global role mutation chain");
        require(actualGlobalRevision == nextGlobalRevision, "global role mutation revision");
    }

    function _registerProposerThroughRoot(address account) private {
        (bool enabled, uint64 revision, bytes32 oldStateHash) = _executor.proposerConfig(account);
        require(!enabled, "proposer already enabled");
        bytes32 scopeHash = _governanceConfigScope(_GOVERNANCE_CONFIG_PROPOSER, account);
        bytes32 newStateHash =
            _governanceConfigState(_GOVERNANCE_CONFIG_PROPOSER, account, true, revision + 1);
        bytes memory callData =
            abi.encodeCall(StreamGovernanceExecutor.registerProposer, (account, true));
        _executeRootDelayedCall(
            address(_executor),
            StreamGovernanceExecutor.registerProposer.selector,
            callData,
            scopeHash,
            oldStateHash,
            newStateHash,
            keccak256(abi.encode("register-holder-proposer", account))
        );

        (bool currentEnabled, uint64 currentRevision, bytes32 currentStateHash) =
            _executor.proposerConfig(account);
        require(currentEnabled, "proposer registration missing");
        require(currentRevision == revision + 1, "proposer revision");
        require(currentStateHash == newStateHash, "proposer state hash");
    }

    function _approveNativeReceiverThroughRoot(address receiver) private {
        (bool approved, uint64 revision, bytes32 oldStateHash) =
            _executor.approvedNativeReceiverConfig(receiver);
        require(!approved, "native receiver already approved");
        bytes32 scopeHash = _governanceConfigScope(_GOVERNANCE_CONFIG_NATIVE_RECEIVER, receiver);
        bytes32 newStateHash = _governanceConfigState(
            _GOVERNANCE_CONFIG_NATIVE_RECEIVER, receiver, true, revision + 1
        );
        bytes memory callData =
            abi.encodeCall(StreamGovernanceExecutor.setApprovedNativeReceiver, (receiver, true));
        _executeRootDelayedCall(
            address(_executor),
            StreamGovernanceExecutor.setApprovedNativeReceiver.selector,
            callData,
            scopeHash,
            oldStateHash,
            newStateHash,
            keccak256(abi.encode("approve-holder-native-receiver", receiver))
        );

        (bool currentApproved, uint64 currentRevision, bytes32 currentStateHash) =
            _executor.approvedNativeReceiverConfig(receiver);
        require(currentApproved, "native receiver approval missing");
        require(currentRevision == revision + 1, "native receiver revision");
        require(currentStateHash == newStateHash, "native receiver state hash");
    }

    function _executeRootDelayedCall(
        address target,
        bytes4 selector,
        bytes memory callData,
        bytes32 scopeHash,
        bytes32 oldStateHash,
        bytes32 newStateHash,
        bytes32 reasonHash
    ) private returns (bytes32 actionId) {
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        calls[0] = GovernanceCall({
            target: target,
            value: 0,
            selector: selector,
            callDataHash: keccak256(callData),
            scopeHash: scopeHash,
            oldValueHash: oldStateHash,
            newValueHash: newStateHash
        });
        bytes[] memory callDatas = new bytes[](1);
        callDatas[0] = callData;
        _executor.publishGovernanceCallData(callDatas);
        (bytes32 aggregateScope, bytes32 aggregateOld, bytes32 aggregateNew) =
            _aggregateHashes(calls);
        uint64 notBefore = uint64(block.timestamp)
            + _executor.minimumDelay(StreamGovernanceActionClasses.DELAYED_LOOSENING);
        actionId = _executor.scheduleGovernanceBatch(
            StreamGovernanceActionClasses.DELAYED_LOOSENING,
            calls,
            aggregateScope,
            aggregateOld,
            aggregateNew,
            notBefore,
            notBefore + 7 days,
            reasonHash,
            "ipfs://local-governance-v2-holder-rehearsal/root-control",
            _bootstrap.manifestHash
        );
        GovernanceAction memory scheduled = _executor.governanceAction(actionId);
        require(scheduled.proposer == address(this), "control action proposer is not root");
        vm.warp(notBefore);
        _executor.executeGovernanceBatch(actionId, calls, callDatas);
    }

    function _governanceConfigScope(bytes32 configKind, address key)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                _GOVERNANCE_CONFIG_SCOPE_V1, block.chainid, address(_executor), configKind, key
            )
        );
    }

    function _governanceConfigState(bytes32 configKind, address key, bool enabled, uint64 revision)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                _GOVERNANCE_CONFIG_STATE_V1,
                block.chainid,
                address(_executor),
                configKind,
                key,
                enabled,
                revision
            )
        );
    }

    function _roleMutationStateHash(
        bytes32 scopeHash,
        bool granted,
        bytes32 roleChainHash,
        uint64 roleRevision,
        bytes32 globalChainHash,
        uint64 globalRevision
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                _ROLE_MUTATION_STATE_V1,
                block.chainid,
                address(_roleRegistry),
                scopeHash,
                granted,
                roleChainHash,
                roleRevision,
                globalChainHash,
                globalRevision
            )
        );
    }

    function _registerEmergencyEligibility() private {
        uint64 index = 0;
        bytes32 priorChainHash = bytes32(0);
        bytes4 selector = IStreamGasParameterHost.emergencyRaiseGasParameter.selector;
        bytes32 scopeHash = keccak256(
            abi.encode(
                _EMERGENCY_SCOPE_DOMAIN,
                block.chainid,
                address(_executor),
                address(_store),
                selector
            )
        );
        bytes32 oldStateHash = keccak256(
            abi.encode(_EMERGENCY_STATE_DOMAIN, scopeHash, false, bytes32(0), index, priorChainHash)
        );
        bytes32 recordHash = keccak256(
            abi.encode(
                _EMERGENCY_RECORD_DOMAIN, index, address(_store), selector, address(_store).codehash
            )
        );
        bytes32 nextChainHash = keccak256(
            abi.encode(
                _EMERGENCY_CHAIN_DOMAIN,
                block.chainid,
                address(_executor),
                priorChainHash,
                recordHash,
                index
            )
        );
        bytes32 newStateHash = keccak256(
            abi.encode(
                _EMERGENCY_STATE_DOMAIN,
                scopeHash,
                true,
                address(_store).codehash,
                uint64(1),
                nextChainHash
            )
        );
        bytes memory callData = abi.encodeCall(
            _executor.registerEmergencyRestorationEligibility, (address(_store), selector)
        );
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        calls[0] = GovernanceCall({
            target: address(_executor),
            value: 0,
            selector: _executor.registerEmergencyRestorationEligibility.selector,
            callDataHash: keccak256(callData),
            scopeHash: scopeHash,
            oldValueHash: oldStateHash,
            newValueHash: newStateHash
        });
        bytes[] memory callDatas = new bytes[](1);
        callDatas[0] = callData;
        _executor.publishGovernanceCallData(callDatas);
        (bytes32 aggregateScope, bytes32 aggregateOld, bytes32 aggregateNew) =
            _aggregateHashes(calls);
        uint64 notBefore = uint64(block.timestamp)
            + _executor.minimumDelay(StreamGovernanceActionClasses.TERMINAL_FREEZE);
        bytes32 actionId = _executor.scheduleGovernanceBatch(
            StreamGovernanceActionClasses.TERMINAL_FREEZE,
            calls,
            aggregateScope,
            aggregateOld,
            aggregateNew,
            notBefore,
            notBefore + 7 days,
            keccak256("register-rehearsal-emergency-selector"),
            "ipfs://local-governance-v2-holder-rehearsal/eligibility",
            _bootstrap.manifestHash
        );
        vm.warp(notBefore);
        _executor.executeGovernanceBatch(actionId, calls, callDatas);
        (bool eligible, bytes32 codeHash) =
            _executor.emergencyRestorationEligibility(address(_store), selector);
        require(eligible && codeHash == address(_store).codehash, "class six eligibility");
    }

    function _scheduleEmergencyViaSafe(uint256 newValue)
        private
        returns (RehearsalAction memory action)
    {
        return _scheduleEmergencyViaSafe(newValue, _stateHash(_GENESIS_GAS_VALUE, 1));
    }

    function _scheduleEmergencyViaSafe(uint256 newValue, bytes32 oldStateHash)
        private
        returns (RehearsalAction memory action)
    {
        action = _emergencyAction(newValue, oldStateHash);
        _safeInvoke(
            address(_executor),
            0,
            abi.encodeCall(_executor.publishGovernanceCallData, (action.callDatas))
        );
        (bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash) =
            _aggregateHashes(action.calls);
        uint64 notBefore = uint64(block.timestamp);
        bytes memory result = _safeInvoke(
            address(_executor),
            0,
            abi.encodeCall(
                _executor.scheduleGovernanceBatch,
                (
                    StreamGovernanceActionClasses.EMERGENCY_RESTORATION,
                    action.calls,
                    scopeHash,
                    oldValueHash,
                    newValueHash,
                    notBefore,
                    notBefore + 30 days,
                    keccak256(abi.encode("safe-class-six", newValue)),
                    "ipfs://local-governance-v2-holder-rehearsal/safe",
                    _bootstrap.manifestHash
                )
            )
        );
        action.actionId = abi.decode(result, (bytes32));
    }

    function _scheduleEmergencyViaGovernor(uint256 newValue)
        private
        returns (RehearsalAction memory action)
    {
        action = _emergencyAction(newValue, _stateHash(_SAFE_RAISED_GAS_VALUE, 2));
        _executor.publishGovernanceCallData(action.callDatas);
        (bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash) =
            _aggregateHashes(action.calls);
        uint64 notBefore = uint64(block.timestamp) + _TIMELOCK_DELAY_SECONDS;
        bytes memory scheduleData = abi.encodeCall(
            _executor.scheduleGovernanceBatch,
            (
                StreamGovernanceActionClasses.EMERGENCY_RESTORATION,
                action.calls,
                scopeHash,
                oldValueHash,
                newValueHash,
                notBefore,
                notBefore + 30 days,
                keccak256(abi.encode("governor-class-six", newValue)),
                "ipfs://local-governance-v2-holder-rehearsal/governor",
                _bootstrap.manifestHash
            )
        );
        bytes memory result;
        (action.holderOperationId, result) = _governorInvoke(
            address(_executor), 0, scheduleData, keccak256("governor-schedule-class-six")
        );
        action.actionId = abi.decode(result, (bytes32));
    }

    function _emergencyAction(uint256 newValue, bytes32 oldStateHash)
        private
        view
        returns (RehearsalAction memory action)
    {
        bytes memory callData =
            abi.encodeCall(_store.emergencyRaiseGasParameter, (_PARAMETER_ID, newValue));
        action.callDatas = new bytes[](1);
        action.callDatas[0] = callData;
        action.calls = new GovernanceCall[](1);
        action.calls[0] = GovernanceCall({
            target: address(_store),
            value: 0,
            selector: IStreamGasParameterHost.emergencyRaiseGasParameter.selector,
            callDataHash: keccak256(callData),
            scopeHash: _scopeHash(),
            oldValueHash: oldStateHash,
            newValueHash: _stateHash(newValue, _currentRevision() + 1)
        });
    }

    function _scheduleNativeViaSafe(address receiver, uint256 value, uint64 notBefore)
        private
        returns (RehearsalAction memory action)
    {
        action = _nativeAction(receiver, value);
        _safeInvoke(
            address(_executor),
            0,
            abi.encodeCall(_executor.publishGovernanceCallData, (action.callDatas))
        );
        (bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash) =
            _aggregateHashes(action.calls);
        bytes memory result = _safeInvoke(
            address(_executor),
            0,
            abi.encodeCall(
                _executor.scheduleGovernanceBatch,
                (
                    StreamGovernanceActionClasses.FUNDS_RECOVERY,
                    action.calls,
                    scopeHash,
                    oldValueHash,
                    newValueHash,
                    notBefore,
                    notBefore + 7 days,
                    keccak256("safe-native-receive"),
                    "ipfs://local-governance-v2-holder-rehearsal/native-safe",
                    _bootstrap.manifestHash
                )
            )
        );
        action.actionId = abi.decode(result, (bytes32));
    }

    function _scheduleNativeViaGovernor(address receiver, uint256 value, uint64 notBefore)
        private
        returns (RehearsalAction memory action)
    {
        action = _nativeAction(receiver, value);
        _executor.publishGovernanceCallData(action.callDatas);
        (bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash) =
            _aggregateHashes(action.calls);
        bytes memory scheduleData = abi.encodeCall(
            _executor.scheduleGovernanceBatch,
            (
                StreamGovernanceActionClasses.FUNDS_RECOVERY,
                action.calls,
                scopeHash,
                oldValueHash,
                newValueHash,
                notBefore,
                notBefore + 7 days,
                keccak256("governor-native-receive"),
                "ipfs://local-governance-v2-holder-rehearsal/native-governor",
                _bootstrap.manifestHash
            )
        );
        bytes memory result;
        (action.holderOperationId, result) = _governorInvoke(
            address(_executor), 0, scheduleData, keccak256("governor-schedule-native")
        );
        action.actionId = abi.decode(result, (bytes32));
    }

    function _nativeAction(address receiver, uint256 value)
        private
        pure
        returns (RehearsalAction memory action)
    {
        action.callDatas = new bytes[](1);
        action.callDatas[0] = bytes("");
        action.calls = new GovernanceCall[](1);
        bytes32 scopeHash = keccak256(abi.encode("GOVERNANCE_V2_REHEARSAL_NATIVE", receiver));
        action.calls[0] = GovernanceCall({
            target: receiver,
            value: value,
            selector: bytes4(0),
            callDataHash: keccak256(bytes("")),
            scopeHash: scopeHash,
            oldValueHash: keccak256(abi.encode(scopeHash, uint8(0))),
            newValueHash: keccak256(abi.encode(scopeHash, uint8(1), value))
        });
    }

    function _executeViaSafe(RehearsalAction memory action, uint256 value) private {
        uint256 transactionId = _prepareSafeExecution(action, value);
        vm.prank(_SAFE_OWNER_THREE);
        _schedulingSafe.executeTransaction(transactionId);
    }

    function _prepareSafeExecution(RehearsalAction memory action, uint256 value)
        private
        returns (uint256 transactionId)
    {
        bytes memory executeData = abi.encodeCall(
            _executor.executeGovernanceBatch, (action.actionId, action.calls, action.callDatas)
        );
        transactionId = _prepareSafeCall(
            _schedulingSafe,
            _SAFE_OWNER_ONE,
            _SAFE_OWNER_TWO,
            address(_executor),
            value,
            executeData
        );
    }

    function _executeViaGovernor(RehearsalAction memory action, uint256 value)
        private
        returns (bytes32 proposalId)
    {
        bytes memory executeData = abi.encodeCall(
            _executor.executeGovernanceBatch, (action.actionId, action.calls, action.callDatas)
        );
        (proposalId,) = _governorInvoke(
            address(_executor),
            value,
            executeData,
            keccak256(abi.encode("governor-execute", action.actionId))
        );
    }

    function _safeInvoke(address target, uint256 value, bytes memory data)
        private
        returns (bytes memory result)
    {
        return _invokeSafe(
            _schedulingSafe,
            _SAFE_OWNER_ONE,
            _SAFE_OWNER_TWO,
            _SAFE_OWNER_THREE,
            target,
            value,
            data
        );
    }

    function _vetoSafeInvoke(address target, uint256 value, bytes memory data)
        private
        returns (bytes memory result)
    {
        return _invokeSafe(
            _vetoSafe,
            _VETO_SAFE_OWNER_ONE,
            _VETO_SAFE_OWNER_TWO,
            _VETO_SAFE_OWNER_THREE,
            target,
            value,
            data
        );
    }

    function _invokeSafe(
        StreamGovernanceV2SafeRehearsal holder,
        address ownerOne,
        address ownerTwo,
        address executorOwner,
        address target,
        uint256 value,
        bytes memory data
    ) private returns (bytes memory result) {
        uint256 transactionId = _prepareSafeCall(holder, ownerOne, ownerTwo, target, value, data);
        vm.prank(executorOwner);
        return holder.executeTransaction(transactionId);
    }

    function _prepareSafeCall(
        StreamGovernanceV2SafeRehearsal holder,
        address ownerOne,
        address ownerTwo,
        address target,
        uint256 value,
        bytes memory data
    ) private returns (uint256 transactionId) {
        vm.prank(ownerOne);
        transactionId = holder.submitTransaction(target, value, data);
        vm.prank(ownerOne);
        holder.approveTransaction(transactionId);
        vm.prank(ownerTwo);
        holder.approveTransaction(transactionId);
    }

    function _governorInvoke(
        address target,
        uint256 value,
        bytes memory data,
        bytes32 descriptionHash
    ) private returns (bytes32 proposalId, bytes memory result) {
        vm.prank(_GOVERNOR_VOTER_ONE);
        proposalId = _governor.propose(target, value, data, descriptionHash);
        StreamReferenceGovernorRehearsal.Proposal memory proposed = _governor.proposal(proposalId);
        vm.roll(proposed.voteStartBlock);
        vm.prank(_GOVERNOR_VOTER_ONE);
        _governor.castVote(proposalId);
        vm.prank(_GOVERNOR_VOTER_TWO);
        _governor.castVote(proposalId);
        vm.roll(uint256(proposed.voteEndBlock) + 1);
        _governor.queue(proposalId);
        StreamReferenceGovernorRehearsal.Proposal memory queued = _governor.proposal(proposalId);
        vm.warp(queued.readyAt);
        result = _governor.execute(proposalId);
    }

    function _assertGovernorLatency(bytes32 proposalId) private view {
        StreamReferenceGovernorRehearsal.Proposal memory proposal = _governor.proposal(proposalId);
        require(proposal.executed, "governor proposal not executed");
        require(
            proposal.voteStartBlock - proposal.proposedAtBlock == _GOVERNOR_VOTING_DELAY_BLOCKS,
            "proposal voting delay drift"
        );
        require(
            proposal.voteEndBlock - proposal.voteStartBlock == _GOVERNOR_VOTING_PERIOD_BLOCKS,
            "proposal voting period drift"
        );
        require(
            proposal.readyAt - proposal.queuedAt == _TIMELOCK_DELAY_SECONDS,
            "proposal timelock drift"
        );
        require(
            proposal.executedAt - proposal.proposedAt >= _TIMELOCK_DELAY_SECONDS,
            "proposal-to-execution latency"
        );
    }

    function _aggregateHashes(GovernanceCall[] memory calls)
        private
        pure
        returns (bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)
    {
        bytes32 callsHash = keccak256(abi.encode(GOVERNANCE_CALLS_V2, calls));
        bytes32[] memory scopes = new bytes32[](calls.length);
        bytes32[] memory oldValues = new bytes32[](calls.length);
        bytes32[] memory newValues = new bytes32[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            scopes[i] = calls[i].scopeHash;
            oldValues[i] = calls[i].oldValueHash;
            newValues[i] = calls[i].newValueHash;
        }
        scopeHash = keccak256(abi.encode(BATCH_SCOPE_V2, callsHash, scopes));
        oldValueHash = keccak256(abi.encode(BATCH_OLD_STATE_V2, callsHash, oldValues));
        newValueHash = keccak256(abi.encode(BATCH_NEW_STATE_V2, callsHash, newValues));
    }

    function _scopeHash() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_GAS_PARAMETER_SCOPE_V1"),
                block.chainid,
                address(_store),
                _PARAMETER_ID
            )
        );
    }

    function _stateHash(uint256 value, uint64 revision) private view returns (bytes32) {
        StreamGovernanceV2RehearsalModuleRecordV2 memory record =
            _moduleRegistry.moduleRecord(address(_probe));
        bytes32 bindingHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_GGP_PROBE_BINDING_V1"),
                address(_moduleRegistry),
                address(_probe),
                record.moduleType,
                record.interfaceId,
                record.moduleVersion,
                address(_probe).codehash,
                record.moduleManifestHash,
                record.deploymentManifestHash
            )
        );
        (bytes32 conditionalRaiseId, bytes32 conditionalRelowerId) =
            _store.conditionalGasParameterActions(_PARAMETER_ID);
        GasParameterStateCommitment memory state = GasParameterStateCommitment({
            scopeHash: _scopeHash(),
            value: value,
            floor: _GAS_FLOOR,
            probe: address(_probe),
            probeRuntimeCodeHash: address(_probe).codehash,
            probeBindingHash: bindingHash,
            failureClass: 1,
            probeMaxAgeBlocks: _PROBE_MAX_AGE_BLOCKS,
            conditionalRaiseActionId: conditionalRaiseId,
            conditionalRelowerActionId: conditionalRelowerId,
            revision: revision
        });
        return keccak256(abi.encode(keccak256("6529STREAM_GAS_PARAMETER_STATE_V1"), state));
    }

    function _currentRevision() private view returns (uint64 revision) {
        (,,,,, revision) = _store.gasParameterInfo(_PARAMETER_ID);
    }

    function _assertParameterState(uint256 expectedValue, uint64 expectedRevision) private view {
        (uint256 value, uint256 floor, address probe, uint8 failureClass,, uint64 revision) =
            _store.gasParameterInfo(_PARAMETER_ID);
        require(value == expectedValue, "parameter value");
        require(floor == _GAS_FLOOR, "parameter floor");
        require(probe == address(_probe), "parameter probe");
        require(failureClass == 1, "parameter failure class");
        require(revision == expectedRevision, "parameter revision");
    }

    function _assertContextCleared() private view {
        (
            bool executing,
            bytes32 actionId,
            uint8 actionClass,
            bytes32 scopeHash,
            bytes32 oldValueHash,
            bytes32 newValueHash
        ) = _executor.currentAction();
        require(!executing, "context executing");
        require(actionId == bytes32(0), "context action id");
        require(actionClass == 0, "context action class");
        require(scopeHash == bytes32(0), "context scope");
        require(oldValueHash == bytes32(0), "context old");
        require(newValueHash == bytes32(0), "context new");
    }
}
