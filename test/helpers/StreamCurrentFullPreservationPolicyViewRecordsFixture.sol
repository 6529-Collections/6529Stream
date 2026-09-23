// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentFullPreservationPolicyViewReferenceFixture
} from "./StreamCurrentFullPreservationPolicyViewReferenceFixture.sol";
import "./StreamCurrentFullPreservationPolicyPreparationFixture.sol";
import {
    IStreamArtistIdentityOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityOwner.sol";

/// @notice Actual records selected for the exact VIEW subject before its preservation checkpoint.
/// @dev The documentary statements are fixture content, not real-world testimony or external
/// archive evidence. Schema admission, op24, metadata append, selections and locks use their
/// original producers and threshold Safes. No COLLECTION selection is inherited by the VIEW.
abstract contract StreamCurrentFullPreservationPolicyViewRecordsFixture is
    StreamCurrentFullPreservationPolicyViewReferenceFixture
{
    StreamWorkRecordTypes.Description internal viewWorkDescription;
    StreamRightsRecordTypes.Statement internal viewRightsStatement;
    StreamConservationRecordTypes.IntentWaiver internal viewIntentWaiver;
    bytes32 internal viewWorkRecord;
    bytes32 internal viewRightsRecord;
    bytes32 internal viewWaiverRecord;
    bytes32 internal viewWaiverAuthorization;
    uint256 internal viewWaiverNonce;
    uint64 internal viewWaiverIndexBefore;
    bytes32 internal viewDescriptionSealAction;
    bytes32 internal viewCollectionRecordsBefore;

    function _publishFullPolicyViewBeforeFreeze() internal virtual override {
        require(
            fullPolicyViewAdoption != 0 && !assemblyCore.collectionFreezeStatus(1)
                && assemblyViewSnapshotRecord == 0 && viewWaiverRecord == 0,
            "VIEW adoption precedes records; records precede checkpoint and freeze"
        );
        viewCollectionRecordsBefore = _viewCollectionRecordsHash();
        // Naming the authenticated published scope does not grant any record-writing authority.
        require(
            assemblyMetadata.registerScopeSubject(
                assemblyMembership.requireScopeMembership(fullPolicyViewScope).sourceRecordHash
            ) == _viewRecordsSubject(),
            "original Metadata admits the exact completed VIEW membership subject"
        );
        _viewSelectWorkAndRights();
        _viewSelectIntentWaiver();
        _viewSealDescriptions();
        _viewLockIntent();
        require(
            _viewCollectionRecordsHash() == viewCollectionRecordsBefore,
            "VIEW records preserve every original COLLECTION selection and lock"
        );
        // The new native op24 precedes all sampled non-sanction presentation bytes.
        super._publishFullPolicyViewBeforeFreeze();
    }

    function _viewRecordsSubject() internal view returns (bytes32) {
        return StreamMetadataSubjects.scopeSubject(
            block.chainid, address(assemblyCore), fullPolicyViewScope
        );
    }

    function _viewSelectWorkAndRights() private {
        bytes32 subject = _viewRecordsSubject();
        require(subject != _assemblySubject(), "separate exact VIEW and COLLECTION subjects");
        // ABI copies prevent a changed VIEW subject from aliasing the original memory witness.
        viewWorkDescription =
            abi.decode(abi.encode(assemblyWorkDescription), (StreamWorkRecordTypes.Description));
        viewWorkDescription.subjectId = subject;
        viewWorkDescription.full.title = "Original two-token VIEW of the prepared artwork";
        bytes memory raw = StreamWorkRecordJson.serialize(viewWorkDescription);
        IStreamPreservationRecords.CollectionRecord memory record = _viewOriginalRecord(
            keccak256("WORK_DESCRIPTION"), StreamWorkRecordDefinitions.SCHEMA_ID, raw
        );
        viewWorkRecord = assemblyMetadata.recordCollectionRecordWithPayload(1, record, raw);
        assemblyWork.selectCurrent(
            1,
            subject,
            viewWorkRecord,
            0,
            0,
            IStreamWorkRecordSelection.Witness(record, viewWorkDescription)
        );

        viewRightsStatement =
            abi.decode(abi.encode(assemblyRightsStatement), (StreamRightsRecordTypes.Statement));
        viewRightsStatement.subjectId = subject;
        raw = StreamRightsRecordJson.serialize(viewRightsStatement);
        record = _viewOriginalRecord(
            keccak256("RIGHTS_STATEMENT"), StreamRightsRecordDefinitions.SCHEMA_ID, raw
        );
        viewRightsRecord = assemblyMetadata.recordCollectionRecordWithPayload(1, record, raw);
        assemblyRights.selectCurrent(1, subject, viewRightsRecord, 0, 0, viewRightsStatement);
    }

    function _viewSelectIntentWaiver() private {
        viewIntentWaiver = abi.decode(
            abi.encode(assemblyIntentWaiver), (StreamConservationRecordTypes.IntentWaiver)
        );
        viewIntentWaiver.subjectId = _viewRecordsSubject();
        viewIntentWaiver.waiverStatement = _viewStatementReference(
            "https://fixtures.example.invalid/view-preservation/explicit-intent-waiver"
        );
        viewIntentWaiver.interview.waiverStatement = _viewStatementReference(
            "https://fixtures.example.invalid/view-preservation/explicit-interview-waiver"
        );
        bytes memory raw = StreamArtistIntentWaiverJson.serialize(viewIntentWaiver);
        IStreamPreservationRecords.CollectionRecord memory record = _viewOriginalRecord(
            keccak256("ARTIST_INTENT_WAIVER"), StreamConservationDefinitions.WAIVER_SCHEMA_ID, raw
        );
        viewWaiverRecord = _viewPublishArtistRecord(record, raw);
        IStreamConservationRecordSelection.WaiverWitness memory witness;
        witness.original = record;
        witness.waiver = viewIntentWaiver;
        assemblyConservation.adoptWaiver(1, _viewRecordsSubject(), viewWaiverRecord, 0, 0, witness);
    }

    function _viewOriginalRecord(bytes32 kind, bytes32 schema, bytes memory raw)
        private
        view
        returns (IStreamPreservationRecords.CollectionRecord memory record)
    {
        record.recordType = kind;
        record.subjectId = _viewRecordsSubject();
        record.schemaId = schema;
        record.effectiveAt = uint64(block.timestamp);
        record.uri = "https://fixtures.example.invalid/view-preservation/original-record";
        record.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encodePacked(keccak256(raw)), keccak256("RFC8785_JCS")
        );
    }

    function _viewStatementReference(string memory uri)
        private
        pure
        returns (StreamConservationRecordTypes.Reference memory result)
    {
        result.algorithm = 1;
        result.canonicalizationId = keccak256("RAW_BYTES");
        result.digest = abi.encodePacked(keccak256(bytes(uri)));
        result.uri = uri;
    }

    function _viewPublishArtistRecord(
        IStreamPreservationRecords.CollectionRecord memory record,
        bytes memory raw
    ) private returns (bytes32 recordHash) {
        require(
            assemblyMetadata.prepareRecordPayload(raw) == keccak256(raw),
            "actual complete payload preparation before original op24"
        );
        (, viewWaiverIndexBefore) = assemblyMetadata.recordChainHash(1, record.recordType);
        AssemblyPublication.Publication memory p;
        p.metadataHost = address(assemblyMetadata);
        p.recorder = address(assemblyArtist);
        p.collectionId = 1;
        p.subjectId = record.subjectId;
        p.recordType = record.recordType;
        p.schemaId = record.schemaId;
        p.canonicalizationId = record.contentHash.canonicalizationId;
        p.payloadAlgorithm = 1;
        p.payloadHash = keccak256(raw);
        p.uriHash = keccak256(bytes(record.uri));
        p.effectiveAt = record.effectiveAt;
        p.candidateRecordHash =
            assemblyMetadata.deriveCollectionRecordHashFor(address(assemblyArtist), 1, record);
        bytes memory statement = abi.encode(uint16(1), p);
        T.Attestation memory attestation = T.Attestation(
            1,
            7,
            record.subjectId,
            p.candidateRecordHash,
            keccak256("6529STREAM_ARTIST_RECORD_PUBLICATION_V1"),
            keccak256(statement),
            record.uri
        );
        T.Authorization memory authorization = _assemblyAuthorization(true);
        viewWaiverNonce = authorization.nonce;
        IStreamArtistIdentityOwner identity = IStreamArtistIdentityOwner(assemblySuite.owners[2]);
        require(!identity.nonceUsed(assemblyArtistId, viewWaiverNonce), "fresh original op24 nonce");
        authorization.signature =
            _assemblyArtistProof(assemblyArtists.attestationDigest(attestation, authorization));
        viewWaiverAuthorization =
            assemblyArtists.recordArtistAttestation(attestation, authorization, statement);
        AssemblyPublication.Evidence memory evidence =
            assemblyArtists.requireRecordPublication(viewWaiverAuthorization, p);
        require(
            evidence.attestationRecordHash == viewWaiverAuthorization
                && evidence.artistId == assemblyArtistId
                && evidence.signer == address(assemblyArtist) && evidence.authorityClass == 1
                && evidence.requiredCapability == 64 && evidence.signedAt == authorization.time
                && evidence.publicationHash == keccak256(abi.encode(p))
                && identity.nonceUsed(assemblyArtistId, viewWaiverNonce)
                && viewWaiverAuthorization != assemblyWaiverAuthorization,
            "new exact VIEW op24 and consumed nonce from original Artist Safe"
        );
        IStreamArtistRecordPublicationOwner.Record memory saved = IStreamArtistRecordPublicationOwner(
                assemblySuite.owners[4]
            ).publicationAttestation(viewWaiverAuthorization);
        require(
            keccak256(abi.encode(saved.publication)) == keccak256(abi.encode(p))
                && keccak256(abi.encode(saved.evidence)) == keccak256(abi.encode(evidence))
                && saved.metadataHostCodeHash == address(assemblyMetadata).codehash,
            "original publication owner retains exact authority and subject"
        );
        recordHash = assemblyMetadata.recordArtistCollectionRecordWithPayload(
            address(assemblyArtist), 1, record, raw, viewWaiverAuthorization
        );
        require(recordHash == p.candidateRecordHash, "exact VIEW candidate admitted");
        _viewRequireWaiverReceipt(recordHash, record, raw);
    }

    function _viewRequireWaiverReceipt(
        bytes32 recordHash,
        IStreamPreservationRecords.CollectionRecord memory record,
        bytes memory raw
    ) private view {
        (
            IStreamPreservationRecords.CollectionRecord memory saved,
            IStreamCollectionMetadataV1.RecordReceipt memory receipt
        ) = assemblyMetadata.collectionRecord(recordHash);
        (bytes32 chain, uint64 count) = assemblyMetadata.recordChainHash(1, record.recordType);
        (, bytes memory payload) = assemblyMetadata.recordPayload(recordHash);
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(record))
                && receipt.collectionId == 1 && receipt.recorder == address(assemblyArtist)
                && receipt.authorizationClass == 1
                && receipt.artistAuthorization == viewWaiverAuthorization
                && receipt.recordIndex == viewWaiverIndexBefore
                && count == viewWaiverIndexBefore + 1 && receipt.recordChainHash == chain
                && chain != 0 && keccak256(payload) == keccak256(raw)
                && assemblyMetadata.recordHashAt(1, record.recordType, viewWaiverIndexBefore)
                    == recordHash
                && assemblyMetadata.latestCollectionRecordHashFor(
                    1, record.recordType, record.subjectId, address(assemblyArtist)
                ) == recordHash
                && assemblyMetadata.consumedArtistAuthorization(viewWaiverAuthorization),
            "actual second lane append and complete VIEW receipt backlinks"
        );
    }

    function _viewSealDescriptions() private {
        IStreamRecordSelectionLock[2] memory selectors = [
            IStreamRecordSelectionLock(address(assemblyWork)),
            IStreamRecordSelectionLock(address(assemblyRights))
        ];
        bytes32[2] memory records = [viewWorkRecord, viewRightsRecord];
        GenesisBatch memory batch;
        batch.actionClass = 2;
        batch.calls = new GovernanceCall[](2);
        batch.callDatas = new bytes[](2);
        for (uint256 i; i < 2; ++i) {
            (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
                selectors[i].selectionLockTransition(1, _viewRecordsSubject(), records[i], 1);
            batch.callDatas[i] = abi.encodeCall(
                selectors[i].lockSelection, (1, _viewRecordsSubject(), records[i], uint64(1))
            );
            batch.calls[i] = StreamCurrentStackPlan.call(
                address(selectors[i]), batch.callDatas[i], scope, oldHash, newHash
            );
        }
        _admitAssemblyBatch(batch);
        viewDescriptionSealAction = _assemblyGovernance(
            batch, "https://fixtures.example.invalid/view-preservation/seal-work-rights"
        );
        for (uint256 i; i < 2; ++i) {
            IStreamRecordSelectionLock.SelectionLock memory seal =
                selectors[i].selectionLock(1, _viewRecordsSubject());
            require(
                seal.locked && seal.recordHash == records[i] && seal.revision == 1
                    && seal.actionId == viewDescriptionSealAction
                    && seal.executor == address(assemblyExecutor)
                    && seal.governanceRoot == address(assemblyRoot),
                "actual class2 VIEW selected-head seal"
            );
        }
    }

    function _viewLockIntent() private {
        uint256 safeNonce = assemblyArtist.nonce();
        require(
            executeSafe(
                assemblyArtist,
                assemblyArtistKeys,
                address(assemblyConservation),
                0,
                abi.encodeCall(
                    assemblyConservation.lockArtistIntent,
                    (1, _viewRecordsSubject(), viewWaiverRecord, uint64(1))
                ),
                0
            ),
            "actual Artist Safe locks exact VIEW intent"
        );
        T.Binding memory b = IStreamArtistBindingOwner(assemblySuite.owners[0]).binding(1);
        IStreamConservationRecordSelection.IntentLock memory locked =
            assemblyConservation.intentLock(1, _viewRecordsSubject());
        require(
            assemblyArtist.nonce() == safeNonce + 1 && locked.locked
                && locked.locker == address(assemblyArtist) && locked.artistId == b.artistId
                && locked.identityRecordHash == b.identityRecordHash
                && locked.bindingHash == b.bindingHash && locked.bindingGeneration == b.generation
                && locked.recordHash == viewWaiverRecord && locked.revision == 1
                && locked.lockedAt == block.timestamp,
            "original Artist authority retained in VIEW intent lock"
        );
    }

    function _viewOriginalHash(bytes32 recordHash) internal view returns (bytes32) {
        (
            IStreamPreservationRecords.CollectionRecord memory r,
            IStreamCollectionMetadataV1.RecordReceipt memory receipt
        ) = assemblyMetadata.collectionRecord(recordHash);
        (address pointer, bytes memory raw) = assemblyMetadata.recordPayload(recordHash);
        return keccak256(abi.encode(r, receipt, pointer, raw));
    }

    function _viewCollectionRecordsHash() internal view returns (bytes32) {
        bytes32 originals = keccak256(
            abi.encode(
                _viewOriginalHash(assemblyWorkRecord),
                _viewOriginalHash(assemblyRightsRecord),
                _viewOriginalHash(assemblyWaiverRecord),
                assemblyWorkDescription,
                assemblyRightsStatement,
                assemblyIntentWaiver,
                IStreamArtistRecordPublicationOwner(assemblySuite.owners[4])
                    .publicationAttestation(assemblyWaiverAuthorization),
                assemblyMetadata.consumedArtistAuthorization(assemblyWaiverAuthorization)
            )
        );
        bytes32 subject = _assemblySubject();
        return keccak256(
            abi.encode(
                originals,
                assemblyWork.currentWork(1, subject),
                assemblyRights.currentRights(1, subject),
                IStreamRecordSelectionLock(address(assemblyWork)).selectionLock(1, subject),
                IStreamRecordSelectionLock(address(assemblyRights)).selectionLock(1, subject),
                assemblyConservation.currentConservation(
                    1, subject, StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT
                ),
                assemblyConservation.intentLock(1, subject)
            )
        );
    }
}
