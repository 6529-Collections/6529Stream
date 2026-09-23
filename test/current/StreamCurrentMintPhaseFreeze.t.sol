// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentMintPolicyGraceFixture.sol";
import "../../smart-contracts/interfaces/stream/mint/IStreamMintPhaseFreeze.sol";
import "../../smart-contracts/interfaces/stream/mint/IStreamMintLedgerPhaseFreeze.sol";
import "../../script/current/StreamMintPhaseFreezePlan.sol";

/// @notice Original current Artist, Governor Safe, Manager, Ledger and ticket gate freeze flows.
/// @dev The inherited external entropy provider is a double. Native execution remains pending
/// the coordinator's frozen combined capture; these cases do not replace Ledger import coverage.
contract StreamCurrentMintPhaseFreezeTest is CurrentMintPolicyGraceFixture {
    function setUp() public override {
        super.setUp();
        GenesisBatch memory classification = StreamMintPhaseFreezePlan.classifier(executor, manager);
        require(
            classification.actionClass == 0 && classification.calls.length == 1,
            "exact tightening classifier admission"
        );
        (bytes32 id, uint64 ready) = _scheduleBatchAsGovernor(
            classification.actionClass, classification.calls, classification.callDatas
        );
        vm.warp(ready);
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(
                executor.executeGovernanceBatch,
                (id, classification.calls, classification.callDatas)
            )
        );
        require(
            executor.isFreezeSelector(address(manager), IStreamMintPhaseFreeze.freezePhase.selector)
                && manager.supportsInterface(type(IStreamMintPhaseFreeze).interfaceId)
                && ledger.supportsInterface(type(IStreamMintLedgerPhaseFreeze).interfaceId)
                && manager.supportsInterface(type(IStreamMintManager).interfaceId),
            "registered terminal selector and additive original capabilities"
        );
    }

    function testDelayedFreezeBindsActualPolicyPreservesGraceAndOriginalTicketMint() public {
        (
            IStreamMintManager.MintBatch memory batch,
            StreamMintTicketTypes.MintTicket memory ticket
        ) = _graceRequest(101, graceMintSafe);
        bytes memory proof = _graceProof(ticket);
        uint64 deadline = uint64(block.timestamp + 12 days);
        bytes32 frozenPolicy =
            _rotateGrace(address(graceNextSafe), true, _graceExecutors(2), deadline);
        bytes32 terms = _immutableTerms();
        GovernanceActionRequest memory request = _freezeRequest(GRACE_PHASE);
        require(request.notBefore >= block.timestamp + 72 hours, "original terminal veto floor");
        bytes32 action = _scheduleAsGovernor(request);
        require(!_frozen(), "scheduling is not freezing");
        vm.warp(request.notBefore - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotExecutable.selector,
                action,
                request.notBefore
            )
        );
        executor.executeGovernanceAction(action, request.callData);
        vm.warp(request.notBefore);
        vm.recordLogs();
        _executeAsGovernor(action, request.callData);
        _assertFreezeEvent(vm.getRecordedLogs(), frozenPolicy);
        _assertCanonicalFreeze(frozenPolicy);
        require(
            _immutableTerms() == terms && manager.phasePolicyHash(1, GRACE_PHASE) == frozenPolicy,
            "freeze preserves immutable terms and current policy identity"
        );
        _assertGrace(batch.expectedPolicyHash, 2, deadline);
        bytes memory mintCall = _graceMintCall(batch, proof, false);
        _graceMint(
            batch,
            proof,
            false,
            graceMintSafe,
            _graceSafeSignature(graceMintSafe, address(manager), mintCall)
        );
        require(
            core.ownerOf(1) == address(graceMintSafe)
                && ledger.counterValue(_graceCounterKey(graceMintSafe)) == 1,
            "freeze does not disable original live predecessor ticket or current accounting"
        );
    }

    function testFreezeVetoByActualScopedGuardianSafeKeepsPhaseMutable() public {
        (bytes32 scope,,) = _freezeHashes(GRACE_PHASE);
        _grantScopedVeto(scope);
        GovernanceActionRequest memory request = _freezeRequest(GRACE_PHASE);
        bytes32 action = _scheduleAsGovernor(request);
        vm.warp(request.notBefore - 1);
        bytes32 reason = keccak256("actual guardian vetoes this terminal phase decision");
        bytes memory vetoCall = abi.encodeCall(executor.vetoTerminalFreeze, (action, reason));
        require(
            _graceSafeCall(
                graceThirdSafe,
                address(executor),
                vetoCall,
                _graceSafeSignature(graceThirdSafe, address(executor), vetoCall)
            ),
            "independent guardian Safe exercises original veto"
        );
        GovernanceAction memory stored = executor.governanceAction(action);
        require(
            stored.status == GovernanceActionStatus.VETOED
                && stored.vetoer == address(graceThirdSafe) && !_frozen(),
            "veto records actual guardian and leaves phase unfrozen"
        );
        vm.warp(request.notBefore);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotScheduled.selector, action
            )
        );
        executor.executeGovernanceAction(action, request.callData);
        _rotateGrace(address(graceNextSafe), true, _graceExecutors(2), 0);
        require(
            manager.phaseExecutor(1, GRACE_PHASE, address(graceNextSafe)), "vetoed phase can add"
        );
    }

    function testFreezeFailureRestoresLedgerAndExactSignedGovernorEnvelopeRetries() public {
        GovernanceActionRequest memory disable = _ordinaryRequest(
            address(ledger), abi.encodeCall(ledger.setLedgerWriter, (address(manager), false))
        );
        GovernanceActionRequest memory restore = _ordinaryRequest(
            address(ledger), abi.encodeCall(ledger.setLedgerWriter, (address(manager), true))
        );
        bytes32 disableId = _scheduleAsGovernor(disable);
        bytes32 restoreId = _scheduleAsGovernor(restore);
        GovernanceActionRequest memory request = _freezeRequest(GRACE_PHASE);
        bytes32 freezeId = _scheduleAsGovernor(request);
        bytes32 policy = manager.phasePolicyHash(1, GRACE_PHASE);
        bytes32 terms = _immutableTerms();
        vm.warp(request.notBefore);
        // These already scheduled calls are permissionlessly executable. They do not advance
        // the Governor Safe nonce, allowing an identical signed freeze envelope to retry.
        executor.executeGovernanceAction(disableId, disable.callData);
        bytes memory callData =
            abi.encodeCall(executor.executeGovernanceAction, (freezeId, request.callData));
        bytes memory signature = _graceSafeSignature(governorSafe, address(executor), callData);
        uint256 safeNonce = governorSafe.nonce();
        _graceSafeFailure(governorSafe, address(executor), callData, signature);
        require(
            !_frozen() && _freezeLedger().frozenPhaseCount(address(manager)) == 0
                && manager.phasePolicyHash(1, GRACE_PHASE) == policy && _immutableTerms() == terms
                && executor.governanceAction(freezeId).status == GovernanceActionStatus.SCHEDULED
                && governorSafe.nonce() == safeNonce,
            "failed actual Ledger freeze restores action, Manager, canonical list and Safe nonce"
        );
        executor.executeGovernanceAction(restoreId, restore.callData);
        vm.recordLogs();
        require(
            _graceSafeCall(governorSafe, address(executor), callData, signature),
            "byte-identical Governor signature succeeds after original writer restoration"
        );
        _assertFreezeEvent(vm.getRecordedLogs(), policy);
        _assertCanonicalFreeze(policy);
        require(
            executor.governanceAction(freezeId).status == GovernanceActionStatus.EXECUTED
                && governorSafe.nonce() == safeNonce + 1,
            "successful terminal transition consumes one actual Safe nonce"
        );
    }

    function testFrozenNoOpsPreserveGraceAndNonzeroNoOpCannotExtendOrClearIt() public {
        bytes32 original = manager.phasePolicyHash(1, GRACE_PHASE);
        uint64 deadline = uint64(block.timestamp + 15 days);
        bytes32 policy = _rotateGrace(address(graceNextSafe), true, _graceExecutors(2), deadline);
        _freeze();
        _govern(_rotationRequest(address(graceMintSafe), true, 0));
        _govern(
            _ordinaryRequest(
                address(manager),
                abi.encodeCall(
                    manager.setPhaseExecutor, (1, GRACE_PHASE, address(graceNextSafe), true)
                )
            )
        );
        _govern(_rotationRequest(address(graceThirdSafe), false, 0));
        _assertGrace(original, 2, deadline);
        require(
            manager.phasePolicyHash(1, GRACE_PHASE) == policy && _frozen(), "no-op keeps policy"
        );
        uint64 extension = uint64(block.timestamp + 20 days);
        _rejectAction(
            _rotationRequest(address(graceMintSafe), true, extension),
            abi.encodeWithSelector(IStreamMintLedger.InvalidPolicyGrace.selector, extension)
        );
        _rejectAction(
            _rotationRequest(address(graceThirdSafe), false, extension),
            abi.encodeWithSelector(IStreamMintLedger.InvalidPolicyGrace.selector, extension)
        );
        _assertGrace(original, 2, deadline);
        require(_freezeManager().phaseExecutors(1, GRACE_PHASE).length == 2, "same executor set");
    }

    function testFrozenAdditionsAndRemovedExecutorReadditionAreDenied() public {
        _rotateGrace(address(graceNextSafe), true, _graceExecutors(2), 0);
        _freeze();
        bytes32 terms = _immutableTerms();
        _recordGracePolicy(_gracePolicy(_graceExecutors(3)));
        _rejectAction(
            _rotationRequest(address(graceThirdSafe), true, 0),
            _frozenExecutorError(address(graceThirdSafe))
        );
        _rejectAction(
            _ordinaryRequest(
                address(manager),
                abi.encodeCall(
                    manager.setPhaseExecutor, (1, GRACE_PHASE, address(graceThirdSafe), true)
                )
            ),
            _frozenExecutorError(address(graceThirdSafe))
        );
        // Both one- and two-executor policy consents were recorded before freezing.
        // Original Artist policy consent is itself replay-protected by the exact tuple.
        _govern(_rotationRequest(address(graceNextSafe), false, 0));
        artists.requireMintConsent(1, GRACE_PHASE, _gracePolicy(_graceExecutors(2)));
        _rejectAction(
            _rotationRequest(address(graceNextSafe), true, 0),
            _frozenExecutorError(address(graceNextSafe))
        );
        address[] memory actual = _freezeManager().phaseExecutors(1, GRACE_PHASE);
        require(
            _frozen() && actual.length == 1 && actual[0] == address(graceMintSafe)
                && !manager.phaseExecutor(1, GRACE_PHASE, address(graceNextSafe))
                && !manager.phaseExecutor(1, GRACE_PHASE, address(graceThirdSafe))
                && _immutableTerms() == terms,
            "Artist consent cannot bypass irreversible executor restriction"
        );
    }

    function testFrozenRemovalStillRequiresActualArtistConsentAndExactSafeRetry() public {
        _rotateGrace(address(graceNextSafe), true, _graceExecutors(2), 0);
        _freeze();
        (
            IStreamMintManager.MintBatch memory removed,
            StreamMintTicketTypes.MintTicket memory removedTicket
        ) = _graceRequest(102, graceMintSafe);
        (
            IStreamMintManager.MintBatch memory retained,
            StreamMintTicketTypes.MintTicket memory retainedTicket
        ) = _graceRequest(103, graceNextSafe);
        bytes memory removedProof = _graceProof(removedTicket);
        bytes memory retainedProof = _graceProof(retainedTicket);
        address[] memory remaining = new address[](1);
        remaining[0] = address(graceNextSafe);
        bytes32 nextPolicy = _gracePolicy(remaining);
        uint64 deadline = uint64(block.timestamp + 12 days);
        GovernanceActionRequest memory request =
            _rotationRequest(address(graceMintSafe), false, deadline);
        bytes32 action = _scheduleAsGovernor(request);
        vm.warp(request.notBefore);
        bytes memory callData =
            abi.encodeCall(executor.executeGovernanceAction, (action, request.callData));
        bytes memory signature = _graceSafeSignature(governorSafe, address(executor), callData);
        _graceSafeFailure(governorSafe, address(executor), callData, signature);
        require(
            _frozen() && manager.phaseExecutor(1, GRACE_PHASE, address(graceMintSafe))
                && manager.phasePolicyHash(1, GRACE_PHASE) == removed.expectedPolicyHash
                && executor.governanceAction(action).status == GovernanceActionStatus.SCHEDULED,
            "missing exact Artist removal consent rolls back policy and executor"
        );
        _recordGracePolicy(nextPolicy);
        require(
            _graceSafeCall(governorSafe, address(executor), callData, signature),
            "unchanged Governor signature retries after original Artist consent"
        );
        artists.requireMintConsent(1, GRACE_PHASE, nextPolicy);
        _assertGrace(removed.expectedPolicyHash, 3, deadline);
        vm.prank(address(graceMintSafe));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintManager.UnauthorizedMintExecutor.selector,
                uint256(1),
                GRACE_PHASE,
                address(graceMintSafe)
            )
        );
        manager.previewSingleStepMintOperation(removed, removedProof);
        bytes memory retainedCall = _graceMintCall(retained, retainedProof, false);
        _graceMint(
            retained,
            retainedProof,
            false,
            graceNextSafe,
            _graceSafeSignature(graceNextSafe, address(manager), retainedCall)
        );
        require(
            _frozen() && core.ownerOf(1) == address(graceNextSafe)
                && !manager.isAuthorizationUsed(removed.authorizationId),
            "live predecessor admits remaining Safe without reviving removed executor"
        );
    }

    function testFrozenPauseAndUnpauseKeepPolicyAndFreezeWhileStoppingMint() public {
        _freeze();
        bytes32 policy = manager.phasePolicyHash(1, GRACE_PHASE);
        bytes32 terms = _immutableTerms();
        (
            IStreamMintManager.MintBatch memory batch,
            StreamMintTicketTypes.MintTicket memory ticket
        ) = _graceRequest(104, graceMintSafe);
        bytes memory proof = _graceProof(ticket);
        _govern(
            _ordinaryRequest(
                address(manager), abi.encodeCall(manager.setPhasePaused, (1, GRACE_PHASE, true))
            )
        );
        vm.prank(address(graceMintSafe));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintManager.MintPhasePaused.selector, uint256(1), GRACE_PHASE
            )
        );
        manager.previewSingleStepMintOperation(batch, proof);
        require(
            _frozen() && manager.phasePolicyHash(1, GRACE_PHASE) == policy
                && _immutableTerms() == terms
                && !manager.isAuthorizationUsed(batch.authorizationId),
            "operational pause preserves frozen identity and consumes nothing"
        );
        _govern(
            _ordinaryRequest(
                address(manager), abi.encodeCall(manager.setPhasePaused, (1, GRACE_PHASE, false))
            )
        );
        bytes memory mintCall = _graceMintCall(batch, proof, true);
        _graceMint(
            batch,
            proof,
            true,
            graceMintSafe,
            _graceSafeSignature(graceMintSafe, address(manager), mintCall)
        );
        _assertCanonicalFreeze(policy);
        require(_immutableTerms() == terms, "unpause never loosens frozen policy terms");
    }

    function testDuplicateAndUnconfiguredFreezeFailWithoutNewCanonicalReceipt() public {
        GovernanceActionRequest memory original = _freezeRequest(GRACE_PHASE);
        _govern(original);
        _rejectAction(
            original,
            abi.encodeWithSelector(
                IStreamMintPhaseFreeze.MintPhaseAlreadyFrozen.selector, uint256(1), GRACE_PHASE
            )
        );
        bytes32 missing = keccak256("not a configured phase");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintManager.MintPhaseDoesNotExist.selector, uint256(1), missing
            )
        );
        _freezeManager().phaseFreezeTransitionHashes(1, missing);
        _rejectAction(
            _freezeRequestUnchecked(missing),
            abi.encodeWithSelector(
                IStreamMintManager.MintPhaseDoesNotExist.selector, uint256(1), missing
            )
        );
        require(
            _freezeLedger().frozenPhaseCount(address(manager)) == 1
                && !_freezeManager().phaseFrozen(1, missing),
            "only configured first freeze enters canonical enumeration"
        );
    }

    function testOwnerAndWrongClassCannotBypassTerminalDelay() public {
        bytes memory callData = abi.encodeCall(IStreamMintPhaseFreeze.freezePhase, (1, GRACE_PHASE));
        _graceSafeFailure(
            governorSafe,
            address(manager),
            callData,
            _graceSafeSignature(governorSafe, address(manager), callData)
        );
        GovernanceActionRequest memory request = _freezeRequest(GRACE_PHASE);
        request.actionClass = 1;
        request.notBefore = uint64(block.timestamp + executor.minimumDelay(1));
        request.expiresAfter = request.notBefore + 7 days;
        bytes memory scheduleCall = abi.encodeCall(executor.scheduleGovernanceAction, (request));
        _graceSafeFailure(
            governorSafe,
            address(executor),
            scheduleCall,
            _graceSafeSignature(governorSafe, address(executor), scheduleCall)
        );
        require(!_frozen(), "Governor Safe is not direct Manager owner or a shorter-class bypass");
        _freeze();
        require(_frozen(), "actual class2 path remains executable after denied bypasses");
    }

    function testStaleScheduledFreezeCannotFreezePolicyAfterRealExecutorRemoval() public {
        bytes32 scheduledPolicy = _rotateGrace(address(graceNextSafe), true, _graceExecutors(2), 0);
        GovernanceActionRequest memory stale = _freezeRequest(GRACE_PHASE);
        bytes32 action = _scheduleAsGovernor(stale);
        // Returning to the original executor set reuses its existing exact Artist record.
        _govern(_rotationRequest(address(graceNextSafe), false, 0));
        bytes32 current = manager.phasePolicyHash(1, GRACE_PHASE);
        require(current == _gracePolicy(_graceExecutors(1)), "actual consented one-executor policy");
        require(
            current != scheduledPolicy && !_frozen(), "real removal changes pending freeze policy"
        );
        vm.warp(stale.notBefore);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintPhaseFreeze.MintPhaseFreezeGovernanceInvalid.selector)
        );
        executor.executeGovernanceAction(action, stale.callData);
        require(
            !_frozen() && _freezeLedger().frozenPhaseCount(address(manager)) == 0
                && executor.governanceAction(action).status == GovernanceActionStatus.SCHEDULED
                && manager.phasePolicyHash(1, GRACE_PHASE) == current,
            "stale exact commitment cannot freeze a different current policy"
        );
        _freeze();
        _assertCanonicalFreeze(current);
    }

    function testFrozenRemovalKeepsOriginalThirtyDayBoundAndRealZeroClearsGrace() public {
        bytes32 predecessor = manager.phasePolicyHash(1, GRACE_PHASE);
        uint64 oldDeadline = uint64(block.timestamp + 20 days);
        _rotateGrace(address(graceNextSafe), true, _graceExecutors(2), oldDeadline);
        _freeze();
        bytes32 terms = _immutableTerms();
        address[] memory remaining = new address[](1);
        remaining[0] = address(graceNextSafe);
        _recordGracePolicy(_gracePolicy(remaining));
        // Class1 execution occurs two days later; 33 days now remains above the
        // original 30-day execution-relative maximum, without altering that maximum.
        uint64 tooLong = uint64(block.timestamp + 33 days);
        _rejectAction(
            _rotationRequest(address(graceMintSafe), false, tooLong),
            abi.encodeWithSelector(IStreamMintLedger.InvalidPolicyGrace.selector, tooLong)
        );
        _assertGrace(predecessor, 2, oldDeadline);
        require(
            manager.phaseExecutor(1, GRACE_PHASE, address(graceMintSafe)),
            "rejected removal rolls back"
        );
        _govern(
            _ordinaryRequest(
                address(manager),
                abi.encodeCall(
                    manager.setPhaseExecutor, (1, GRACE_PHASE, address(graceMintSafe), false)
                )
            )
        );
        _assertGrace(0, 0, 0);
        require(
            _frozen() && _immutableTerms() == terms
                && !manager.phaseExecutor(1, GRACE_PHASE, address(graceMintSafe))
                && manager.phaseExecutor(1, GRACE_PHASE, address(graceNextSafe)),
            "real zero-grace removal tightens executors and clears predecessor without unfreezing"
        );
    }

    function _freeze() private {
        _govern(_freezeRequest(GRACE_PHASE));
        require(_frozen(), "actual terminal transition");
    }

    function _freezeRequest(bytes32 phaseId) private view returns (GovernanceActionRequest memory) {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = _freezeHashes(phaseId);
        (bytes32 actualScope, bytes32 actualOld, bytes32 actualNew) =
            _freezeManager().phaseFreezeTransitionHashes(1, phaseId);
        require(
            scope == actualScope && oldHash == actualOld && newHash == actualNew,
            "literal independent chain Core Manager Ledger phase and policy transition"
        );
        return _freezeRequestUnchecked(phaseId);
    }

    function _freezeRequestUnchecked(bytes32 phaseId)
        private
        view
        returns (GovernanceActionRequest memory)
    {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = _freezeHashes(phaseId);
        return _governanceRequest(
            2,
            address(manager),
            abi.encodeCall(IStreamMintPhaseFreeze.freezePhase, (1, phaseId)),
            scope,
            oldHash,
            newHash
        );
    }

    function _freezeHashes(bytes32 phaseId)
        private
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_PHASE_FREEZE_SCOPE_V1"),
                block.chainid,
                address(core),
                address(manager),
                address(ledger),
                uint256(1),
                phaseId
            )
        );
        bytes32 policy = manager.phasePolicyHash(1, phaseId);
        bytes32 domain = keccak256("6529STREAM_MINT_PHASE_FREEZE_STATE_V1");
        oldHash = keccak256(abi.encode(domain, scope, false, policy));
        newHash = keccak256(abi.encode(domain, scope, true, policy));
    }

    function _ordinaryRequest(address target, bytes memory data)
        private
        view
        returns (GovernanceActionRequest memory)
    {
        return _governanceRequest(
            1, target, data, keccak256(abi.encode(target, data)), 0, keccak256(data)
        );
    }

    function _rejectAction(GovernanceActionRequest memory request, bytes memory expected) private {
        // Re-scheduling a failed/duplicate transition still uses a fresh timing envelope.
        request.notBefore = uint64(block.timestamp + executor.minimumDelay(request.actionClass));
        request.expiresAfter = request.notBefore + 7 days;
        bytes32 action = _scheduleAsGovernor(request);
        vm.warp(request.notBefore);
        vm.expectRevert(expected);
        executor.executeGovernanceAction(action, request.callData);
        require(
            executor.governanceAction(action).status == GovernanceActionStatus.SCHEDULED,
            "target rejection rolls actual action status back"
        );
    }

    function _grantScopedVeto(bytes32 scope) private {
        bytes32 role = executor.terminalFreezeVetoRole(scope);
        (GovernanceCall memory transition,) = _roleCall(role, address(graceThirdSafe), true);
        bytes memory data = abi.encodeCall(
            roles.grantScopedRole,
            (StreamRoles.ROLE_TERMINAL_FREEZE_VETO, scope, address(graceThirdSafe))
        );
        _govern(
            _governanceRequest(
                1,
                address(roles),
                data,
                transition.scopeHash,
                transition.oldValueHash,
                transition.newValueHash
            )
        );
        require(roles.hasRole(role, address(graceThirdSafe)), "actual scoped guardian assignment");
    }

    function _immutableTerms() private view returns (bytes32) {
        (bool exists, IStreamMintManager.MintPhaseConfig memory config) =
            manager.phase(1, GRACE_PHASE);
        config.paused = false;
        return keccak256(
            abi.encode(
                exists,
                config,
                manager.phaseGate(1, GRACE_PHASE),
                manager.phaseCounterIds(1, GRACE_PHASE),
                manager.counterConfig(1, GRACE_PHASE, GRACE_COUNTER),
                ledger.registeredCounterPolicy(address(manager), 1, GRACE_PHASE, GRACE_COUNTER)
            )
        );
    }

    function _assertCanonicalFreeze(bytes32 frozenPolicy) private view {
        IStreamMintLedgerPhaseFreeze.PhaseFreeze memory receipt =
            _freezeLedger().phaseFreeze(address(manager), 1, GRACE_PHASE);
        (uint256 collection, bytes32 phaseId) = _freezeLedger().frozenPhaseAt(address(manager), 0);
        require(
            _frozen() && receipt.policyHash == frozenPolicy && receipt.configurationHash != 0
                && _freezeLedger().frozenPhaseCount(address(manager)) == 1 && collection == 1
                && phaseId == GRACE_PHASE,
            "one durable canonical Ledger freeze binds exact policy and phase"
        );
    }

    function _assertFreezeEvent(Vm.Log[] memory logs, bytes32 frozenPolicy) private view {
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(manager) && logs[i].topics.length == 3
                    && logs[i].topics[0]
                        == keccak256("MintPhaseFrozen(uint16,uint256,bytes32,bool,bytes32)")
            ) {
                ++found;
                require(
                    logs[i].topics[1] == bytes32(uint256(1)) && logs[i].topics[2] == GRACE_PHASE
                        && keccak256(logs[i].data)
                            == keccak256(abi.encode(uint16(1), true, frozenPolicy)),
                    "exact original Manager schema phase final flag and frozen policy event"
                );
            }
        }
        require(found == 1, "one terminal Manager receipt");
    }

    function _frozenExecutorError(address changed) private pure returns (bytes memory) {
        return abi.encodeWithSelector(
            IStreamMintPhaseFreeze.MintPhaseFrozenExecutor.selector,
            uint256(1),
            GRACE_PHASE,
            changed
        );
    }

    function _frozen() private view returns (bool) {
        return _freezeManager().phaseFrozen(1, GRACE_PHASE);
    }

    function _freezeManager() private view returns (IStreamMintPhaseFreeze) {
        return IStreamMintPhaseFreeze(address(manager));
    }

    function _freezeLedger() private view returns (IStreamMintLedgerPhaseFreeze) {
        return IStreamMintLedgerPhaseFreeze(address(ledger));
    }
}
