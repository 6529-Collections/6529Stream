// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/RecoveryGovernanceIntegrationFixture.sol";

/// @notice Actual recovery/governance flows; original finality, artist and owner evidence boundaries remain explicit.
contract StreamRecoveryGovernanceCompositionTest is RecoveryGovernanceIntegrationFixture {
    function testActualRecoveryGovernanceSecondCallOwnerRollbackAndExactRetry() public {
        _initialize();
        (GovernanceCall[] memory calls, bytes[] memory data) = _recoveryBatch();
        (bytes32 id, uint64 ready) = this.scheduleFoundationBatch(2, calls, data);
        require(
            keccak256(abi.encode(configuration.executor.scheduledCallData(id)))
                == keccak256(abi.encode(data)),
            "actual complete published bytes"
        );
        fixture.ownerObservation(id, true, ready + 1);
        vm.expectRevert();
        this.executeFoundationBatch(id, calls, data);
        vm.warp(ready);
        uint256 nonce = governor.nonce();
        vm.expectRevert();
        this.executeFoundationBatch(id, calls, data);
        StreamFinalityRecoveryRequest memory r = fixture.requestFacts();
        (bytes32 head,, uint64 generation) = first.activeFinalityRecovery(r.scope);
        require(
            !first.finalityRecoveryRecord(id).executed && head == 0 && generation == 0
                && first.incompleteFinalityRecoveryRefreshPlanCount() == 0,
            "late owner failure rolls target state back"
        );
        require(
            governor.nonce() == nonce
                && configuration.executor.governanceAction(id).status
                    == GovernanceActionStatus.SCHEDULED,
            "Safe and Executor rollback"
        );
        fixture.ownerObservation(id, true, ready);
        this.executeFoundationBatch(id, calls, data);
        StreamFinalityRecoveryRecord memory saved = first.finalityRecoveryRecord(id);
        require(
            saved.executed && saved.recoveryId == id
                && saved.originalFinalityRecordHash == r.expectedOriginalFinalityRecordHash
                && saved.evidence.artistEvidenceHash == fixture.APPROVAL()
                && saved.evidence.ownerEvidenceHash == fixture.OWNER()
                && saved.evidence.ownerNoticeEndsAt == ready,
            "exact executed target evidence"
        );
        require(
            configuration.executor.governanceAction(id).selector
                == first.assertNoIncompleteFinalityRecoveryRefreshPlans.selector,
            "first index selector distinct from operative second call"
        );
        require(
            first.finalityRecoveryRefreshPlan(id).complete
                && first.incompleteFinalityRecoveryRefreshPlanCount() == 0
                && configuration.core.lastAllocatedTokenId() == 0,
            "actual zero highwater completes empty plan"
        );
        fixture.ownerObservation(id, false, ready + 1);
        require(
            keccak256(abi.encode(first.finalityRecoveryRecord(id))) == keccak256(abi.encode(saved)),
            "immutable consumed history"
        );
        vm.expectRevert();
        this.executeFoundationBatch(id, calls, data);
    }

    function testActualRecoveryGovernancePublishedCardinalityBytesAndRuntimeRestore() public {
        _initialize();
        (GovernanceCall[] memory calls, bytes[] memory data) = _recoveryBatch();
        GovernanceCall memory assertion = calls[0];
        bytes memory assertionData = data[0];
        calls[0] = calls[1];
        data[0] = data[1];
        vm.expectRevert();
        this.scheduleFoundationBatch(2, calls, data);
        calls[0] = assertion;
        data[0] = assertionData;
        bytes memory original = data[1];
        data[1] = bytes.concat(original, hex"00");
        calls[1].callDataHash = keccak256(data[1]);
        vm.expectRevert();
        this.scheduleFoundationBatch(2, calls, data);
        data[1] = original;
        calls[1].callDataHash = keccak256(original);
        (bytes32 id, uint64 ready) = this.scheduleFoundationBatch(2, calls, data);
        fixture.ownerObservation(id, true, ready);
        vm.warp(ready);
        bytes memory code = address(first).code;
        vm.etch(address(first), hex"00");
        vm.expectRevert();
        this.executeFoundationBatch(id, calls, data);
        vm.etch(address(first), code);
        require(
            !first.finalityRecoveryRecord(id).executed
                && configuration.executor.governanceAction(id).status
                    == GovernanceActionStatus.SCHEDULED,
            "runtime failure leaves published action reusable"
        );
        this.executeFoundationBatch(id, calls, data);
        require(first.finalityRecoveryRecord(id).executed, "same runtime/bytes restored");
    }

    function testActualRecoveryGovernanceCutoverPreservesSavedRecordAndRejectsOldCandidate()
        public
    {
        _initialize();
        (GovernanceCall[] memory calls, bytes[] memory data) = _recoveryBatch();
        (bytes32 id, uint64 ready) = this.scheduleFoundationBatch(2, calls, data);
        fixture.ownerObservation(id, true, ready);
        vm.warp(ready);
        this.executeFoundationBatch(id, calls, data);
        bytes32 saved = keccak256(abi.encode(first.finalityRecoveryRecord(id)));
        (calls, data) = _selection(address(second), address(0));
        vm.expectRevert();
        this.scheduleFoundationBatch(3, calls, data);
        (calls, data) = _selection(address(second), address(first));
        _runBatch(3, calls, data);
        require(
            _selected() == address(second)
                && saved == keccak256(abi.encode(first.finalityRecoveryRecord(id))),
            "real old companion assertion and immutable history"
        );
        StreamFinalityRecoveryRequest memory r = fixture.requestFacts();
        vm.expectRevert();
        first.requireArtistRecoveryIntent(
            r.scope, r.expectedOriginalFinalityRecordHash, r.recoveryManifest.contentHash
        );
        (bool pinned,,,, bytes32 recoveryId) =
            first.resolvedFinalityRoute(r.replacementRoute.componentType, r.scope);
        require(
            pinned && recoveryId == id,
            "historical old route survives permitted pointer replacement"
        );
    }
}
