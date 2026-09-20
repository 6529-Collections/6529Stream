// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentFullPreservationPolicyViewPublicationFixture.sol";
import "../helpers/StreamCurrentFullPreservationPolicyViewReferenceFixture.sol";
import {
    StreamMetadataContentAuthorization as VPAuthorization
} from "../../smart-contracts/domains/metadata/StreamMetadataContentAuthorization.sol";
import {
    StreamFinalityViewPreservationSnapshotReadsV1 as VPReadSnapshot
} from "../../smart-contracts/domains/finality/StreamFinalityViewPreservationSnapshotReadsV1.sol";

/// @notice Authored actual-current VIEW cases. Native execution and full finality remain separate.
contract StreamCurrentFullPreservationPolicyViewPublicationTest is
    StreamCurrentFullPreservationPolicyViewReferenceFixture
{
    uint8 private viewPublicationScenario;

    function testActualViewOutputsSnapshotAndRootRemainCurrentAfterOriginalFreeze() public {
        _viewBuildPublication();
        require(
            assemblyCore.collectionFreezeStatus(1), "original Core freeze followed VIEW publication"
        );
        require(
            assemblyViewSnapshotRecord != 0 && assemblyViewOriginalContentRoot != 0,
            "actual original publications"
        );
        require(
            assemblyViewPreservationSnapshot.snapshotLock(fullPolicyViewScope).actionId != 0,
            "original class2 snapshot seal"
        );
        _viewRequireCurrentPublication();
        require(
            !assemblyFinality.collectionFinalityRecord(1).finalized,
            "VIEW source publication is not COLLECTION finality"
        );
    }

    function testActualViewArchiveAndSnapshotCannotReplaceDistinctArtistRootConsent() public {
        viewPublicationScenario = 1;
        _viewBuildPublication();
        require(
            viewPublicationRootConsent != 0 && viewPublicationRootConsent != fullPolicyViewConsent,
            "two distinct original Artist content consents"
        );
        require(
            assemblyRouter.consumedArtistContentConsent(fullPolicyViewConsent)
                && assemblyRouter.consumedArtistContentConsent(viewPublicationRootConsent),
            "both genuine transitions consume their own consent"
        );
    }

    function testActualViewRootRejectsWrongSnapshotRevisionAndPreservesRetry() public {
        viewPublicationScenario = 2;
        _viewBuildPublication();
        _viewRequireCurrentPublication();
    }

    function testActualViewRootRejectsStalePredecessorReplayWhilePublicationRemainsOpen() public {
        viewPublicationScenario = 3;
        _viewBuildPublication();
        _viewRequireCurrentPublication();
    }

    function testActualViewIncompleteCheckpointRejectsSealAndPreservesOrderedRetry() public {
        _viewBuildPublication();
        bytes32 candidate = assemblyViewPreservationCheckpoint.begin(
            fullPolicyViewScope, keccak256("incomplete actual VIEW retry")
        );
        vm.expectRevert(
            abi.encodeWithSelector(VPCheckpoint.ViewCheckpointToken.selector, fullPolicyTokens[1])
        );
        assemblyViewPreservationCheckpoint.append(
            candidate,
            fullPolicyTokens[1],
            viewPublicationJSON[fullPolicyTokens[1]],
            viewPublicationHTML[fullPolicyTokens[1]]
        );
        require(
            assemblyViewPreservationCheckpoint.checkpoint(candidate).nextIndex == 0,
            "out-of-order token cannot advance preparation"
        );
        assemblyViewPreservationCheckpoint.append(
            candidate,
            fullPolicyTokens[0],
            viewPublicationJSON[fullPolicyTokens[0]],
            viewPublicationHTML[fullPolicyTokens[0]]
        );
        vm.expectRevert(
            abi.encodeWithSelector(VPCheckpoint.ViewCheckpointIndex.selector, uint256(1))
        );
        assemblyViewPreservationCheckpoint.seal(candidate);
        VPCheckpoint.Plan memory incomplete =
            assemblyViewPreservationCheckpoint.checkpoint(candidate);
        require(
            incomplete.nextIndex == 1 && incomplete.outputRoot == 0 && incomplete.contentRoot == 0,
            "partial preparation is never complete evidence"
        );
        assemblyViewPreservationCheckpoint.append(
            candidate,
            fullPolicyTokens[1],
            viewPublicationJSON[fullPolicyTokens[1]],
            viewPublicationHTML[fullPolicyTokens[1]]
        );
        assemblyViewPreservationCheckpoint.seal(candidate);
        VPCheckpoint.Plan memory complete =
            assemblyViewPreservationCheckpoint.requireCurrentCheckpoint(candidate);
        require(
            complete.nextIndex == 2 && complete.tokenCount == 2
                && complete.contentRoot
                    == assemblyViewPreservationCheckpoint.checkpoint(viewPublicationCheckpoint)
                    .contentRoot,
            "complete retry preserves actual ordered content"
        );
    }

    function testActualViewSnapshotRejectsProducerDriftButKeepsHistoricalBytes() public {
        _viewBuildPublication();
        bytes memory payload =
            assemblyViewPreservationSnapshot.snapshotPayload(assemblyViewSnapshotRecord);
        bytes32 saved = keccak256(
            abi.encode(assemblyViewPreservationCheckpoint.checkpoint(viewPublicationCheckpoint))
        );
        address producer = address(assemblyViewPreservationRenderer);
        bytes memory originalRuntime = producer.code;
        vm.etch(producer, hex"00");
        vm.expectRevert();
        assemblyViewPreservationCheckpoint.requireCurrentCheckpoint(viewPublicationCheckpoint);
        vm.expectRevert();
        assemblyViewPreservationSnapshot.requireCurrent(
            fullPolicyViewScope, assemblyViewSnapshotRecord, 1
        );
        require(
            keccak256(assemblyViewPreservationSnapshot.snapshotPayload(assemblyViewSnapshotRecord))
                    == keccak256(payload)
                && keccak256(
                    abi.encode(
                        assemblyViewPreservationCheckpoint.checkpoint(viewPublicationCheckpoint)
                    )
                ) == saved,
            "runtime drift leaves exact historical receipts readable"
        );
        vm.etch(producer, originalRuntime);
        _viewRequireCurrentPublication();
    }

    function testActualViewSnapshotSealRejectsFurtherPublicationWithoutChangingHead() public {
        _viewBuildPublication();
        VPSnapshot.Publication memory next = VPSnapshot.Publication(
            fullPolicyViewScope,
            keccak256("forbidden second VIEW snapshot"),
            assemblyViewSnapshotRecord,
            1,
            viewPublicationOutputManifest,
            fullPolicyViewAdoption,
            viewPublicationSnapshotReceipt.sourceHash,
            "urn:fixture:view-preservation:second-snapshot",
            uint64(block.timestamp),
            keccak256("sealed publication cannot advance")
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                VPSnapshot.ViewPreservationSnapshotLocked.selector,
                viewPublicationSnapshotReceipt.scopeSubject
            )
        );
        assemblyViewPreservationSnapshot.publishSnapshot(next);
        require(
            assemblyViewPreservationSnapshot.snapshotCount(fullPolicyViewScope) == 1
                && assemblyViewPreservationSnapshot.currentSnapshot(fullPolicyViewScope).recordHash
                    == assemblyViewSnapshotRecord,
            "sealed source lineage unchanged"
        );
        _viewRequireCurrentPublication();
    }

    function _viewBuildPublication() private {
        _constructFullPolicyPublication();
        bytes32 receipt = assemblyViewPreservationBindingReceiptHash;
        _prepareFullPolicyArtwork();
        require(
            receipt != 0 && assemblyViewPreservationBindingReceiptHash == receipt,
            "one original provider binding across whole VIEW ceremony"
        );
        require(
            assemblyViewPreservationCheckpoint.configuration().servingGas == 9000000
                && assemblyViewPreservationManifest.configuration().checkpointGas == 12000000
                && assemblyViewPreservationSnapshot.dependencies().sourceGas == 14000000,
            "original VIEW nested budgets unchanged"
        );
    }

    /// @notice Source-authored observation entry; callers supply fresh captures for these exact bytes.
    /// @dev This is not a default passing test and does not execute a browser. Inventory, sanction,
    /// finality and confirmation follow through their separately owned complete VIEW profiles.
    function runSuppliedViewReferenceObservation(
        string memory environmentJSON,
        string memory browserJSON,
        string memory capturesJSON
    ) public returns (bytes32) {
        _viewBuildPublication();
        uint256[4] memory caps =
            [uint256(1000000), uint256(16000000), uint256(16000000), uint256(1000000)];
        _viewDeployReference(caps);
        _viewPrepareReferenceDefinitions();
        _viewPublishReference(environmentJSON, browserJSON, capturesJSON);
        _viewRequireCurrentPublication();
        return assemblyViewReferenceRecord;
    }

    function _viewBeforeRootPublication() internal override {
        VPScopedRoot.Publication memory p = _viewRootPublication();
        bytes32 expected =
            VPRoot(address(assemblyRouter)).previewViewPreservationContentRoot(p, address(this));
        require(
            expected != 0 && assemblyRouter.consumedArtistContentConsent(fullPolicyViewConsent),
            "actual adoption complete before separate root"
        );
        if (viewPublicationScenario == 1) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    VPAuthorization.ArtistContentAuthorizationRequired.selector, uint256(1)
                )
            );
            VPRoot(address(assemblyRouter)).publishViewPreservationContentRoot(p);
        } else if (viewPublicationScenario == 2) {
            p.snapshotRevision = 2;
            vm.expectRevert(
                abi.encodeWithSelector(
                    VPReadSnapshot.InvalidViewPreservationSnapshotEvidence.selector
                )
            );
            VPRoot(address(assemblyRouter)).previewViewPreservationContentRoot(p, address(this));
        }
        require(
            VPScopedRoot(address(assemblyRouter)).scopedContentRootHead(fullPolicyViewScope) == 0
                && assemblyViewPreservationSnapshot.currentSnapshot(fullPolicyViewScope).recordHash
                    == assemblyViewSnapshotRecord,
            "failed candidate leaves genuine snapshot and empty root head"
        );
    }

    function _viewAfterRootPublication() internal override {
        if (viewPublicationScenario != 3) return;
        require(
            !assemblyCore.collectionFreezeStatus(1), "replay checked before freeze can mask failure"
        );
        bytes32 priorAggregate = keccak256(
            abi.encode(VPScopedRoot(address(assemblyRouter)).scopedContentRootAggregate(1))
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                VPScopedRoot.ScopedContentRootLineage.selector,
                bytes32(0),
                assemblyViewOriginalContentRoot
            )
        );
        VPRoot(address(assemblyRouter)).publishViewPreservationContentRoot(_viewRootPublication());
        require(
            VPScopedRoot(address(assemblyRouter)).scopedContentRootHead(fullPolicyViewScope)
                    == assemblyViewOriginalContentRoot
                && keccak256(
                    abi.encode(VPScopedRoot(address(assemblyRouter)).scopedContentRootAggregate(1))
                ) == priorAggregate,
            "replay changes neither canonical head nor original aggregate"
        );
    }
}
