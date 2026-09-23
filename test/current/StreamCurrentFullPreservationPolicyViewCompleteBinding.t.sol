// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentFullPreservationPolicyViewCompleteFixture.sol";

/// @notice Genuine current-graph and threshold Safe admission of all fixed VIEW sources.
/// @dev Authored cases. Native execution, transaction fit and later finality remain separate.
contract StreamCurrentFullPreservationPolicyViewCompleteBindingTest is
    StreamCurrentFullPreservationPolicyViewCompleteFixture
{
    uint8 private completeScenario;

    function testActualCompleteViewBindingUsesOneSafeActionBeforeAnyPublication() public {
        _constructFullPolicyPublication();
        _viewRequireCompleteBinding();
        require(
            fullPolicyViewAdoption == 0 && viewPublicationCheckpoint == 0
                && assemblyViewSnapshotRecord == 0 && assemblyViewOriginalContentRoot == 0
                && assemblyViewReferenceRecord == 0 && viewRenderInventoryPlan == 0,
            "source admission precedes unpublished future evidence"
        );
        require(
            viewCompleteBindingReceipt.basicBindingRecordHash
                == assemblyViewPreservationBindingReceiptHash,
            "same original once-bound basic receipt"
        );
        StreamRenderCriticalSourceTypes.Dependencies memory original =
            assemblyInventory.dependencies();
        StreamRenderCriticalSourceTypes.Dependencies memory selected = viewInventory.dependencies();
        for (uint256 i; i < 12; ++i) {
            if (i == 5 || i == 6) continue;
            require(
                selected.targets[i] == original.targets[i]
                    && selected.codeHashes[i] == original.codeHashes[i],
                "all shared original source roles remain exact"
            );
        }
        require(
            selected.readGas == 2000000 && selected.sourceGas == 18000000
                && selected.selectionGas == 8000000 && selected.snapshotGas == 18000000
                && selected.referenceGas == 24000000,
            "explicit new diagnostic configuration, not measured transaction acceptance"
        );
        require(
            viewReference.dependencies().readGas == 1000000
                && viewReference.dependencies().sourceGas == 16000000
                && viewReference.dependencies().snapshotGas == 16000000
                && viewReference.dependencies().archiveGas == 1000000
                && viewCompleteConfiguration.validationGas == 16000000
                && viewCompleteDeclaration.readGas == 2000000
                && viewCompleteDeclaration.sourceGas == 4000000,
            "all original C and governed declaration caps remain exact"
        );
    }

    function testActualCompleteViewBindingClosesBothEntryPointsAndBothPreviews() public {
        _constructFullPolicyPublication();
        bytes32 before_ = _viewCompleteRetainedHash();
        bytes memory expected = abi.encodeWithSelector(
            ViewPreservationBindingTypes.ViewPreservationAlreadyBound.selector
        );
        ViewPreservationBinding basic = ViewPreservationBinding(address(assemblyProvider));
        CompleteBinding complete = CompleteBinding(address(assemblyProvider));
        vm.expectRevert(expected);
        basic.viewPreservationBindingTransition(viewCompleteConfiguration, viewCompleteDeclaration);
        vm.expectRevert(expected);
        complete.completeViewPreservationBindingTransition(
            viewCompleteConfiguration, viewCompleteDeclaration, viewCompleteSelection
        );
        vm.expectRevert(expected);
        basic.bindViewPreservation(viewCompleteConfiguration, viewCompleteDeclaration);
        vm.expectRevert(expected);
        complete.bindCompleteViewPreservation(
            viewCompleteConfiguration, viewCompleteDeclaration, viewCompleteSelection
        );
        require(_viewCompleteRetainedHash() == before_, "no second action or appended binding");
    }

    function testActualCompleteViewWrongRuntimePreviewRejectsWithoutConsumingPendingBinding()
        public
    {
        completeScenario = 1;
        _constructFullPolicyPublication();
        _viewRequireCompleteBinding();
    }

    function testActualCompleteViewDirectCallerCannotConsumeOriginalGovernedCapability() public {
        completeScenario = 2;
        _constructFullPolicyPublication();
        _viewRequireCompleteBinding();
    }

    function testActualCompleteViewRejectsRealClass2ActionAuthorizingOnlyBasicProposal() public {
        completeScenario = 3;
        _constructFullPolicyPublication();
        _viewRequireCompleteBinding();
    }

    function testActualCompleteViewRuntimeDriftInvalidatesSelectionButRetainsBothReceipts() public {
        _constructFullPolicyPublication();
        bytes32 historical = _viewCompleteRetainedHash();
        bytes memory referenceRuntime = address(viewReference).code;
        vm.etch(address(viewReference), hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(AssemblyInventory.InventoryRead.selector, address(viewReference))
        );
        CompleteSources(address(assemblyProvider)).viewFinalitySources();
        require(
            _viewCompleteRetainedHash() == historical,
            "historical basic and complete admission remain readable after drift"
        );
        vm.etch(address(viewReference), referenceRuntime);
        _viewRequireCompleteBinding();
    }

    /// @notice Explicit external-observation entry; not a default test or browser execution claim.
    /// @dev All sources were fixed before the one bind. Package members and endpoint witnesses
    /// must correspond to these actual complete preserved inputs and supplied observations.
    function runSuppliedViewInventoryObservation(
        string memory environmentJSON,
        string memory browserJSON,
        string memory capturesJSON,
        string memory packageMembersDirectory
    ) external returns (bytes32 referenceRecord, bytes32 inventoryPlan, bytes32 bundleCoverage) {
        _constructFullPolicyPublication();
        _prepareFullPolicyArtwork();
        viewPackageMembersDirectory = packageMembersDirectory;
        _viewPrepareReferenceDefinitions();
        _viewPublishReference(environmentJSON, browserJSON, capturesJSON);
        AssemblyInventory.Item[][] memory rows = _viewMaterializeInventory();
        _viewCoverCompleteBundle(rows);
        _viewRequireCurrentPublication();
        _viewRequireCompleteBinding();
        return (
            assemblyViewReferenceRecord,
            viewRenderInventoryPlan,
            viewCompleteBundle.coverage.bundleCoverageHash
        );
    }

    function _viewBeforeCompleteBind() internal override {
        CompleteSources sources = CompleteSources(address(assemblyProvider));
        bytes memory unavailable = abi.encodeWithSelector(
            CompleteBindingTypes.ViewPreservationCompleteBindingUnavailable.selector
        );
        vm.expectRevert(unavailable);
        sources.viewFinalitySources();
        vm.expectRevert(unavailable);
        sources.viewFinalitySourcesReceipt();
        ViewPreservationBinding basic = ViewPreservationBinding(address(assemblyProvider));
        require(
            basic.viewPreservationBindingStatus() == 0
                && basic.viewPreservationBindingReceipt().recordHash == 0,
            "both complete getters reject pending original capability"
        );
        CompleteBinding complete = CompleteBinding(address(assemblyProvider));
        if (completeScenario == 1) {
            CompleteSources.Selection memory wrong = viewCompleteSelection;
            wrong.referencePublicationCodeHash =
                bytes32(uint256(wrong.referencePublicationCodeHash) ^ 1);
            vm.expectRevert(
                abi.encodeWithSelector(
                    AssemblyInventory.InventoryRead.selector, address(viewReference)
                )
            );
            complete.completeViewPreservationBindingTransition(
                viewCompleteConfiguration, viewCompleteDeclaration, wrong
            );
        } else if (completeScenario == 2) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    ViewPreservationBindingTypes.ViewPreservationBindingGovernance.selector
                )
            );
            complete.bindCompleteViewPreservation(
                viewCompleteConfiguration, viewCompleteDeclaration, viewCompleteSelection
            );
        } else if (completeScenario == 3) {
            _viewRejectBasicOnlyGovernanceContext();
        }
        require(
            basic.viewPreservationBindingStatus() == 0
                && basic.viewPreservationBindingReceipt().recordHash == 0,
            "failed candidate and unauthorized call leave the one real binding available"
        );
        assemblyVm.recordLogs();
    }

    function _viewRejectBasicOnlyGovernanceContext() private {
        ViewPreservationBindingTypes.Transition memory inner = ViewPreservationBinding(
                address(assemblyProvider)
            ).viewPreservationBindingTransition(viewCompleteConfiguration, viewCompleteDeclaration);
        GenesisBatch memory batch;
        batch.actionClass = 2;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.callDatas[0] = abi.encodeCall(
            CompleteBinding.bindCompleteViewPreservation,
            (viewCompleteConfiguration, viewCompleteDeclaration, viewCompleteSelection)
        );
        batch.calls[0] = StreamCurrentStackPlan.call(
            address(assemblyProvider),
            batch.callDatas[0],
            inner.scopeHash,
            inner.oldValueHash,
            inner.newValueHash
        );
        _admitAssemblyBatch(batch);
        assemblyExecutor.publishGovernanceCallData(batch.callDatas);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            batch.calls, StreamGovernanceBootstrap.governanceCallsHash(batch.calls)
        );
        uint64 at = uint64(block.timestamp + assemblyExecutor.minimumDelay(2));
        string memory reason =
            "https://fixtures.example.invalid/view-preservation/wrong-inner-proposal";
        bytes memory schedule = abi.encodeCall(
            assemblyExecutor.scheduleGovernanceBatch,
            (
                uint8(2),
                batch.calls,
                scope,
                oldHash,
                newHash,
                at,
                at + 7 days,
                keccak256(bytes(reason)),
                reason,
                ASSEMBLY_DEPLOYMENT
            )
        );
        uint256 nonce = assemblyRoot.nonce();
        assemblyVm.recordLogs();
        require(
            executeSafe(assemblyRoot, assemblyRootKeys, address(assemblyExecutor), 0, schedule, 0)
                && assemblyRoot.nonce() == nonce + 1,
            "actual root Safe schedules the wrong inner-proposal context"
        );
        NativeAssemblyVm.Log[] memory logs = assemblyVm.getRecordedLogs();
        bytes32 action;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(assemblyExecutor) || logs[i].topics.length != 4
                    || logs[i].topics[0]
                        != keccak256(
                            "GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)"
                        )
            ) continue;
            GovernanceAction memory saved = assemblyExecutor.governanceAction(logs[i].topics[1]);
            if (
                saved.scopeHash != scope || saved.oldValueHash != oldHash
                    || saved.newValueHash != newHash
            ) continue;
            require(
                action == 0 && saved.status == GovernanceActionStatus.SCHEDULED
                    && saved.proposer == address(assemblyRoot) && saved.notBefore == at,
                "one original scheduled wrong-context action"
            );
            action = logs[i].topics[1];
        }
        require(action != 0, "actual negative action retained");
        assemblyVm.warp(at);
        vm.expectRevert(
            abi.encodeWithSelector(
                ViewPreservationBindingTypes.ViewPreservationBindingGovernance.selector
            )
        );
        assemblyExecutor.executeGovernanceBatch(action, batch.calls, batch.callDatas);
        require(
            assemblyExecutor.governanceAction(action).status == GovernanceActionStatus.SCHEDULED
                && ViewPreservationBinding(address(assemblyProvider))
                        .viewPreservationBindingStatus() == 0,
            "wrong proposal rolls back original action execution and both receipt writes"
        );
    }

    function _viewAfterCompleteBind() internal override {
        NativeAssemblyVm.Log[] memory logs = assemblyVm.getRecordedLogs();
        bytes32 signature =
            keccak256("ViewPreservationCompleteBound(bytes32,bytes32,bytes32,bytes32)");
        uint256 events;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(assemblyProvider) || logs[i].topics.length == 0
                    || logs[i].topics[0] != signature
            ) continue;
            require(
                logs[i].topics.length == 4
                    && logs[i].topics[1] == viewCompleteBindingReceipt.recordHash
                    && logs[i].topics[2] == viewCompleteBindingReceipt.basicBindingRecordHash
                    && logs[i].topics[3] == viewCompleteBindingAction
                    && keccak256(logs[i].data)
                        == keccak256(abi.encode(viewCompleteTransition.newValueHash)),
                "actual complete event binds both receipts to the same full Safe action"
            );
            ++events;
        }
        require(events == 1, "exactly one complete binding event");
    }

    function _viewCompleteRetainedHash() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                ViewPreservationBinding(address(assemblyProvider)).viewPreservationBindingReceipt(),
                CompleteSources(address(assemblyProvider)).viewFinalitySourcesReceipt()
            )
        );
    }
}
