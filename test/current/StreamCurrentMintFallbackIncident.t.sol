// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamMintFallbackIncidentFixture.sol";

/// @notice Original incident regressions using the shared real preparation/recovery fixture.
contract StreamCurrentMintFallbackIncidentTest is StreamMintFallbackIncidentFixture {
    function testActualSafeIncidentRecoveryAfterTwoRealImportsPreservesBurnAndAllocationGap()
        public
    {
        bytes32 firstRoot = _setupIncident();
        _recoverThroughSafe();
        require(
            tree[0] != firstRoot && ledger.mintImportCommitment(firstRoot).complete
                && ledger.mintImportCommitment(tree[0]).complete
                && ledger.isCompletedMintDescendant(
                    address(ledger), originalArtistManager, address(rescue)
                ),
            "two genuine roots retain the original Artist lineage"
        );
        _assertRecovered();
        _assertHistoryAndCounters(false);
        _configureSuccessorWithFreshConsent();
        _mintAfterRecovery();
        _assertHistoryAndCounters(true);
    }

    function testOwnerBurnDuringDelayMakesRecoveryStaleAndRequiresNewSafeProposal() public {
        _setupIncident();
        (IncidentBatch memory imports, IncidentBatch memory stale) = _scheduleIncident(false);
        bytes32 oldCommitment = stale.calls[1].oldValueHash;
        vm.warp(stale.ready - 1 days);
        vm.prank(BUYER);
        core.burn(1);
        firstTokenBurned = true;
        historicState = _historicState();
        require(core.totalSupply() == 0, "independent owner burn changes committed live supply");
        _assertStranded();
        vm.warp(stale.ready);
        _executeIncidentBatch(imports);
        _assertImported();

        bytes32 before_ = _rollbackState();
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintFallbackRecovery.InvalidFallbackRecoveryContext.selector
            )
        );
        executor.executeGovernanceBatch(stale.action, stale.calls, stale.data);
        require(
            _rollbackState() == before_,
            "exact stale-context failure restores pointer and preparation"
        );
        _rejectIncidentBatchThroughSafe(stale);
        _assertStranded();
        _assertHistoryAndCounters(false);

        IncidentBatch memory fresh;
        (fresh.calls, fresh.data) = _activationPlan(3, INCIDENT_OPERATION);
        _assertRecoveryIntent(fresh.calls[1]);
        require(
            fresh.calls[1].scopeHash == stale.calls[1].scopeHash
                && fresh.calls[1].oldValueHash != oldCommitment
                && fresh.calls[1].newValueHash != stale.calls[1].newValueHash,
            "same incident requires freshly authorized current supply commitments"
        );
        _executeNewRecoveryProposal(fresh, stale.action);
        _assertHistoryAndCounters(false);
        _configureSuccessorWithFreshConsent();
        _mintAfterRecovery();
        _assertHistoryAndCounters(true);
    }

    function testManifestTailFailureRestoresAbortedPreparationAndSafeEnvelope() public {
        _setupIncident();
        (IncidentBatch memory imports, IncidentBatch memory badTail) = _scheduleIncident(true);
        vm.warp(badTail.ready);
        _executeIncidentBatch(imports);
        _assertImported();
        bytes32 before_ = _rollbackState();
        // The exact third-call error proves pointer replacement and recovery both returned first.
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamSystemManifest.GovernanceNewValueHashMismatch.selector,
                badTail.calls[2].newValueHash ^ bytes32(uint256(1)),
                badTail.calls[2].newValueHash
            )
        );
        executor.executeGovernanceBatch(badTail.action, badTail.calls, badTail.data);
        require(
            _rollbackState() == before_,
            "late manifest failure restores the actual aborted preparation"
        );

        // Observe the real Core hook once inside the failed Safe execution and once in the
        // separately authorized successful batch below. The earlier diagnostic is excluded.
        CurrentFallbackIncidentCallVm(address(vm))
            .expectCall(
                address(core),
                abi.encodeCall(core.abortPreparedMintFromManager, (3, INCIDENT_OPERATION)),
                2
            );
        _rejectIncidentBatchThroughSafe(badTail);
        _assertStranded();
        _assertHistoryAndCounters(false);
        IncidentBatch memory fresh;
        (fresh.calls, fresh.data) = _activationPlan(3, INCIDENT_OPERATION);
        _assertRecoveryIntent(fresh.calls[1]);
        require(
            fresh.calls[1].oldValueHash == badTail.calls[1].oldValueHash
                && fresh.calls[1].newValueHash == badTail.calls[1].newValueHash,
            "failed abort leaves exactly the original recovery facts for a new proposal"
        );
        _executeNewRecoveryProposal(fresh, badTail.action);
        _assertHistoryAndCounters(false);
        _configureSuccessorWithFreshConsent();
        _mintAfterRecovery();
        _assertHistoryAndCounters(true);
    }
}
