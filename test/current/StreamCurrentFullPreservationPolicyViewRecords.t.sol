// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentFullPreservationPolicyViewRecordsFixture.sol";

/// @notice Exact VIEW record selections composed with genuine adoption and preservation publication.
/// @dev Documentary references and inherited analysis/archive reports are fixture evidence.
/// Source-authored only: execution, browser provenance and full finality remain separate evidence.
contract StreamCurrentFullPreservationPolicyViewRecordsTest is
    StreamCurrentFullPreservationPolicyViewRecordsFixture
{
    function testActualViewRecordsAndSealsPrecedeCheckpointWithoutReplacingCollection() public {
        _viewBuildRecords();
        bytes32 subject = _viewRecordsSubject();
        require(subject != _assemblySubject());
        require(
            viewWorkRecord != assemblyWorkRecord && viewRightsRecord != assemblyRightsRecord
                && viewWaiverRecord != assemblyWaiverRecord,
            "exact subjects produce distinct original records"
        );
        require(
            assemblyWork.requireCurrent(1, subject, viewWorkRecord, 1).recordHash == viewWorkRecord
                && assemblyRights.requireCurrent(1, subject, viewRightsRecord, 1).recordHash
                    == viewRightsRecord,
            "both actual exact-subject selections are currently eligible"
        );
        IStreamConservationRecordSelection.Selection memory intent =
            assemblyConservation.requireCurrent(
                1,
                subject,
                StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT,
                viewWaiverRecord,
                1
            );
        require(
            intent.record.kind == IStreamConservationRecordSelection.RecordKind.INTENT_WAIVER
                && intent.interviewStatus == StreamConservationRecordTypes.InterviewStatus.WAIVED
                && intent.interview.recordHash == 0 && intent.interviewArchiveReferenceHash == 0
                && intent.record.publication.attestationRecordHash == viewWaiverAuthorization,
            "original intent and interview waivers are explicit; no invented interview record"
        );
        require(
            IStreamRecordSelectionLock(address(assemblyWork)).selectionLock(1, subject).actionId
                    == viewDescriptionSealAction
                && IStreamRecordSelectionLock(address(assemblyRights))
                .selectionLock(1, subject)
                .actionId == viewDescriptionSealAction && viewDescriptionSealAction != 0,
            "actual class2 batch seals both VIEW descriptions"
        );
        IStreamConservationRecordSelection.IntentLock memory locked =
            assemblyConservation.intentLock(1, subject);
        require(
            locked.locked && locked.locker == address(assemblyArtist)
                && locked.recordHash == viewWaiverRecord && locked.revision == 1
        );
        require(
            _viewCollectionRecordsHash() == viewCollectionRecordsBefore,
            "COLLECTION originals, payloads, current heads and locks are unchanged"
        );
        require(assemblyViewSnapshotRecord != 0 && assemblyViewOriginalContentRoot != 0);
        _viewRequireCurrentPublication();
        require(
            !assemblyFinality.collectionFinalityRecord(1).finalized,
            "record selections and source publication do not confer finality"
        );
    }

    function testActualViewWaiverUsesFreshOp24AndSecondOriginalLaneOccurrence() public {
        _viewBuildRecords();
        bytes32[3] memory original =
            [assemblyWorkRecord, assemblyRightsRecord, assemblyWaiverRecord];
        bytes32[3] memory selected = [viewWorkRecord, viewRightsRecord, viewWaiverRecord];
        bytes32[3] memory types_ = [
            keccak256("WORK_DESCRIPTION"),
            keccak256("RIGHTS_STATEMENT"),
            keccak256("ARTIST_INTENT_WAIVER")
        ];
        for (uint256 i; i < 3; ++i) {
            (
                IStreamPreservationRecords.CollectionRecord memory r,
                IStreamCollectionMetadataV1.RecordReceipt memory receipt
            ) = assemblyMetadata.collectionRecord(selected[i]);
            (bytes32 chain, uint64 count) = assemblyMetadata.recordChainHash(1, types_[i]);
            require(
                count == 2 && receipt.recordIndex == 1 && receipt.recordChainHash == chain
                    && r.subjectId == _viewRecordsSubject()
                    && assemblyMetadata.recordHashAt(1, types_[i], 0) == original[i]
                    && assemblyMetadata.recordHashAt(1, types_[i], 1) == selected[i],
                "one shared original record lane retains both distinct exact subjects"
            );
            (, bytes memory raw) = assemblyMetadata.recordPayload(selected[i]);
            bytes memory expected;
            if (i == 0) expected = StreamWorkRecordJson.serialize(viewWorkDescription);
            else if (i == 1) expected = StreamRightsRecordJson.serialize(viewRightsStatement);
            else expected = StreamArtistIntentWaiverJson.serialize(viewIntentWaiver);
            require(keccak256(raw) == keccak256(expected));
            require(
                assemblyMetadata.deriveCollectionRecordHashFor(receipt.recorder, 1, r)
                    == selected[i],
                "literal original record hash and canonical complete bytes"
            );
        }
        require(
            viewWaiverIndexBefore == 1 && viewWaiverAuthorization != assemblyWaiverAuthorization
        );
        require(
            IStreamArtistIdentityOwner(assemblySuite.owners[2])
                .nonceUsed(assemblyArtistId, viewWaiverNonce)
        );
        IStreamArtistRecordPublicationOwner.Record memory p = IStreamArtistRecordPublicationOwner(
                assemblySuite.owners[4]
            ).publicationAttestation(viewWaiverAuthorization);
        require(
            p.publication.subjectId == _viewRecordsSubject()
                && p.publication.candidateRecordHash == viewWaiverRecord
                && p.evidence.attestationRecordHash == viewWaiverAuthorization
                && p.evidence.signer == address(assemblyArtist) && p.evidence.authorityClass == 1
                && p.evidence.requiredCapability == 64
                && assemblyMetadata.consumedArtistAuthorization(viewWaiverAuthorization)
                && assemblyMetadata.consumedArtistAuthorization(assemblyWaiverAuthorization),
            "independent original op24 authorities remain consumed and addressable"
        );
        (, uint64 interviewCount) =
            assemblyMetadata.recordChainHash(1, keccak256("ARTIST_STATEMENT"));
        require(
            interviewCount == 0, "explicit interview waiver creates no phantom original interview"
        );
    }

    function testActualViewConsumedPublicationAndLockedSafeIntentRejectReplay() public {
        _viewBuildRecords();
        bytes32 before_ = _viewRetainedRecordsHash();
        (IStreamPreservationRecords.CollectionRecord memory original,) =
            assemblyMetadata.collectionRecord(viewWaiverRecord);
        (, bytes memory raw) = assemblyMetadata.recordPayload(viewWaiverRecord);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionMetadataV1.MetadataAuthorizationConsumed.selector,
                viewWaiverAuthorization
            )
        );
        assemblyMetadata.recordArtistCollectionRecordWithPayload(
            address(assemblyArtist), 1, original, raw, viewWaiverAuthorization
        );
        require(_viewRetainedRecordsHash() == before_, "consumed op24 cannot append another record");

        bytes memory callData = abi.encodeCall(
            assemblyConservation.lockArtistIntent,
            (1, _viewRecordsSubject(), viewWaiverRecord, uint64(1))
        );
        // Direct read of the original guard identifies the reason before the Safe wraps it.
        (bool ok, bytes memory reason) = address(assemblyConservation).call(callData);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamConservationRecordSelection.ConservationHeadLocked.selector
                        )
                    ),
            "original exact-subject intent guard rejects a second lock"
        );
        uint256 nonce = assemblyArtist.nonce();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        executeSafe(
            assemblyArtist, assemblyArtistKeys, address(assemblyConservation), 0, callData, 0
        );
        require(
            assemblyArtist.nonce() == nonce && _viewRetainedRecordsHash() == before_,
            "actual Safe failure retains nonce and both scopes' complete original state"
        );
        _viewRequireCurrentPublication();
    }

    function _viewBuildRecords() private {
        _constructFullPolicyPublication();
        _prepareFullPolicyArtwork();
        require(assemblyCore.collectionFreezeStatus(1) && viewWaiverRecord != 0);
    }

    function _viewRetainedRecordsHash() private view returns (bytes32) {
        (bytes32 chain, uint64 count) =
            assemblyMetadata.recordChainHash(1, keccak256("ARTIST_INTENT_WAIVER"));
        return keccak256(
            abi.encode(
                _viewCollectionRecordsHash(),
                _viewOriginalHash(viewWorkRecord),
                _viewOriginalHash(viewRightsRecord),
                _viewOriginalHash(viewWaiverRecord),
                chain,
                count,
                assemblyConservation.currentConservation(
                    1,
                    _viewRecordsSubject(),
                    StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT
                ),
                assemblyConservation.intentLock(1, _viewRecordsSubject()),
                assemblyMetadata.consumedArtistAuthorization(viewWaiverAuthorization)
            )
        );
    }
}
