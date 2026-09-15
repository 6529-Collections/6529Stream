// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamConservationPublicationReads.sol";
import "./StreamArtistIntentJson.sol";
import "./StreamArtistIntentWaiverJson.sol";
import "./StreamArtistInterviewJson.sol";

/// @notice Complete typed conservation meaning over authenticated original records.
/// @dev External source statements remain attributed claims; original op24 evidence is retained.
library StreamConservationRecordReads {
    struct Prepared {
        IStreamConservationRecordSelection.Selection selection;
        IStreamConservationRecordSelection.CatalogPin[] catalogs;
    }

    function intent(
        StreamConservationRecordContext.Dependencies memory d,
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        IStreamConservationRecordSelection.IntentWitness calldata witness,
        IStreamConservationRecordSelection.PreparedInterview memory prepared
    ) public view returns (Prepared memory p) {
        p.selection.record = StreamConservationPublicationReads.recorded(
            d,
            collectionId,
            subjectId,
            recordHash,
            witness.original,
            IStreamConservationRecordSelection.RecordKind.INTENT
        );
        StreamArtistIntentJson.requireExact(
            witness.intent,
            StreamConservationPublicationReads.payload(
                d, recordHash, p.selection.record.payloadHash
            )
        );
        if (witness.intent.subjectId != subjectId) {
            revert IStreamConservationRecordSelection.InvalidConservationRecord(recordHash);
        }
        p.selection.predecessor = witness.intent.predecessor;
        p.selection.association = StreamConservationRecordContext.association(d, collectionId);
        _artist(p.selection, witness.intent.artist);
        (p.selection.interview, p.catalogs, p.selection.interviewPayloadCorrespondence) = _interview(
            d,
            collectionId,
            subjectId,
            p.selection.association,
            witness.intent.interview,
            witness.interview,
            prepared
        );
        p.selection.interviewStatus = witness.intent.interview.status;
        if (
            witness.intent.interview.status == StreamConservationRecordTypes.InterviewStatus.PRESENT
        ) {
            p.selection.interviewArchiveReferenceHash =
                keccak256(abi.encode(witness.intent.interview.record.payload));
        }
        p.selection.catalogsHash = keccak256(abi.encode(p.catalogs));
    }

    function waiver(
        StreamConservationRecordContext.Dependencies memory d,
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        IStreamConservationRecordSelection.WaiverWitness calldata witness,
        IStreamConservationRecordSelection.PreparedInterview memory prepared
    ) public view returns (Prepared memory p) {
        p.selection.record = StreamConservationPublicationReads.recorded(
            d,
            collectionId,
            subjectId,
            recordHash,
            witness.original,
            IStreamConservationRecordSelection.RecordKind.INTENT_WAIVER
        );
        StreamArtistIntentWaiverJson.requireExact(
            witness.waiver,
            StreamConservationPublicationReads.payload(
                d, recordHash, p.selection.record.payloadHash
            )
        );
        if (witness.waiver.subjectId != subjectId) {
            revert IStreamConservationRecordSelection.InvalidConservationRecord(recordHash);
        }
        p.selection.predecessor = witness.waiver.predecessor;
        p.selection.association = StreamConservationRecordContext.association(d, collectionId);
        _artist(p.selection, witness.waiver.artist);
        (p.selection.interview, p.catalogs, p.selection.interviewPayloadCorrespondence) = _interview(
            d,
            collectionId,
            subjectId,
            p.selection.association,
            witness.waiver.interview,
            witness.interview,
            prepared
        );
        p.selection.interviewStatus = witness.waiver.interview.status;
        if (
            witness.waiver.interview.status == StreamConservationRecordTypes.InterviewStatus.PRESENT
        ) {
            p.selection.interviewArchiveReferenceHash =
                keccak256(abi.encode(witness.waiver.interview.record.payload));
        }
        p.selection.catalogsHash = keccak256(abi.encode(p.catalogs));
    }

    function requireSelected(
        StreamConservationRecordContext.Dependencies memory d,
        uint256 collectionId,
        IStreamConservationRecordSelection.Selection memory selected,
        IStreamConservationRecordSelection.CatalogPin[] memory catalogs
    ) public view {
        IStreamConservationRecordSelection.Association memory current =
            StreamConservationRecordContext.association(d, collectionId);
        if (keccak256(abi.encode(current)) != keccak256(abi.encode(selected.association))) {
            revert IStreamConservationRecordSelection.ConservationAssociationChanged();
        }
        if (keccak256(abi.encode(catalogs)) != selected.catalogsHash) {
            revert IStreamConservationRecordSelection.ConservationSelectionConflict();
        }
        for (uint256 i; i < catalogs.length; ++i) {
            StreamConservationRecordContext.definition(
                d,
                catalogs[i].documentId,
                IStreamSchemaRegistry.DocumentKind.CATALOG,
                catalogs[i].contentHash,
                catalogs[i].totalBytes,
                StreamWorkRecordDefinitions.CANON_ID,
                false
            );
        }
    }

    function _artist(
        IStreamConservationRecordSelection.Selection memory selected,
        StreamConservationRecordTypes.ArtistClaim memory claim
    ) private pure {
        _sameAssociation(selected.association, selected.record);
        if (
            claim.artistId != selected.association.artistId
                || claim.bindingHash != selected.association.bindingHash
                || claim.bindingGeneration != selected.association.generation
                || (claim.origin == StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT
                        ? selected.record.publication.authorityClass != 1
                        : selected.record.publication.authorityClass != 3)
        ) {
            revert IStreamConservationRecordSelection.ConservationAssociationChanged();
        }
        selected.origin = claim.origin;
    }

    function _sameAssociation(
        IStreamConservationRecordSelection.Association memory a,
        IStreamConservationRecordSelection.RecordEvidence memory e
    ) private pure {
        if (
            a.artistId == 0 || e.publication.artistId != a.artistId
                || e.publication.bindingHash != a.bindingHash
                || e.publication.bindingGeneration != a.generation
        ) {
            revert IStreamConservationRecordSelection.ConservationAssociationChanged();
        }
    }

    function _interview(
        StreamConservationRecordContext.Dependencies memory d,
        uint256 collectionId,
        bytes32 subjectId,
        IStreamConservationRecordSelection.Association memory a,
        StreamConservationRecordTypes.InterviewEntry memory entry,
        IStreamConservationRecordSelection.InterviewWitness calldata witness,
        IStreamConservationRecordSelection.PreparedInterview memory prepared
    )
        private
        view
        returns (
            IStreamConservationRecordSelection.RecordEvidence memory e,
            IStreamConservationRecordSelection.CatalogPin[] memory catalogs,
            IStreamConservationRecordSelection.PayloadCorrespondence correspondence
        )
    {
        if (entry.status == StreamConservationRecordTypes.InterviewStatus.WAIVED) {
            IStreamConservationRecordSelection.InterviewWitness memory empty;
            if (
                prepared.preparationHash != 0
                    || keccak256(abi.encode(witness)) != keccak256(abi.encode(empty))
            ) {
                revert IStreamConservationRecordSelection.InvalidConservationRecord(0);
            }
            return (e, new IStreamConservationRecordSelection.CatalogPin[](0), correspondence);
        }
        StreamConservationRecordTypes.InterviewRecord memory locator = entry.record;
        if (
            locator.chainId != d.chainId || locator.core != d.targets[0]
                || locator.host != d.targets[1]
                || locator.schemaId != StreamConservationDefinitions.INTERVIEW_SCHEMA_ID
                || locator.profileHash != StreamConservationDefinitions.INTERVIEW_PROFILE_HASH
        ) {
            revert IStreamConservationRecordSelection.InvalidConservationRecord(locator.recordHash);
        }
        if (prepared.preparationHash == 0) {
            prepared = prepareInterview(d, collectionId, subjectId, locator.recordHash, witness);
        } else {
            IStreamConservationRecordSelection.InterviewWitness memory empty;
            if (
                keccak256(abi.encode(witness)) != keccak256(abi.encode(empty))
                    || prepared.collectionId != collectionId || prepared.subjectId != subjectId
                    || prepared.record.recordHash != locator.recordHash
                    || prepared.record.kind
                        != IStreamConservationRecordSelection.RecordKind.INTERVIEW
            ) {
                revert IStreamConservationRecordSelection.InvalidConservationRecord(locator.recordHash);
            }
            for (uint256 i; i < prepared.catalogs.length; ++i) {
                IStreamConservationRecordSelection.CatalogPin memory pin = prepared.catalogs[i];
                StreamConservationRecordContext.definition(
                    d,
                    pin.documentId,
                    IStreamSchemaRegistry.DocumentKind.CATALOG,
                    pin.contentHash,
                    pin.totalBytes,
                    StreamWorkRecordDefinitions.CANON_ID,
                    false
                );
            }
        }
        if (keccak256(abi.encode(a)) != keccak256(abi.encode(prepared.association))) {
            revert IStreamConservationRecordSelection.ConservationAssociationChanged();
        }
        e = prepared.record;
        catalogs = prepared.catalogs;
        _sameAssociation(a, e);
        bytes memory payload =
            StreamConservationPublicationReads.payload(d, e.recordHash, e.payloadHash);
        // Known JCS digest algorithms have an actual local correspondence check. All other
        // algorithms/canonicalizations remain attributed claims for a later archival verifier.
        // No digest match establishes retrieval, URI availability or archive delivery.
        if (
            locator.payload.canonicalizationId == StreamWorkRecordDefinitions.CANON_ID
                && (locator.payload.algorithm == 1 || locator.payload.algorithm == 2)
        ) {
            bytes32 digest = locator.payload.algorithm == 1 ? keccak256(payload) : sha256(payload);
            if (locator.payload.digest.length != 32 || bytes32(locator.payload.digest) != digest) {
                revert IStreamConservationRecordSelection.InvalidConservationRecord(locator.recordHash);
            }
            correspondence = locator.payload.algorithm == 1
                ? IStreamConservationRecordSelection.PayloadCorrespondence.EXACT_JCS_KECCAK256
                : IStreamConservationRecordSelection.PayloadCorrespondence.EXACT_JCS_SHA256;
        }
    }

    function prepareInterview(
        StreamConservationRecordContext.Dependencies memory d,
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        IStreamConservationRecordSelection.InterviewWitness calldata witness
    ) public view returns (IStreamConservationRecordSelection.PreparedInterview memory p) {
        if (witness.interview.subjectId != subjectId) {
            revert IStreamConservationRecordSelection.InvalidConservationRecord(recordHash);
        }
        p.collectionId = collectionId;
        p.subjectId = subjectId;
        p.record = StreamConservationPublicationReads.recorded(
            d,
            collectionId,
            subjectId,
            recordHash,
            witness.original,
            IStreamConservationRecordSelection.RecordKind.INTERVIEW
        );
        bytes memory payload =
            StreamConservationPublicationReads.payload(d, recordHash, p.record.payloadHash);
        StreamArtistInterviewJson.requireExact(witness.interview, payload);
        p.association = StreamConservationRecordContext.association(d, collectionId);
        _sameAssociation(p.association, p.record);
        uint256 count = witness.interview.transcript.format.kind
            == StreamConservationRecordTypes.FormatKind.CATALOG
            ? 1
            : 0;
        for (uint256 i; i < witness.interview.captures.length; ++i) {
            if (
                witness.interview.captures[i].payload.format.kind
                    == StreamConservationRecordTypes.FormatKind.CATALOG
            ) ++count;
        }
        p.catalogs = new IStreamConservationRecordSelection.CatalogPin[](count);
        uint256 cursor;
        if (
            witness.interview.transcript.format.kind
                == StreamConservationRecordTypes.FormatKind.CATALOG
        ) {
            p.catalogs[cursor++] = _catalog(d, witness.interview.transcript.format.catalog);
        }
        for (uint256 i; i < witness.interview.captures.length; ++i) {
            StreamConservationRecordTypes.Format memory format =
            witness.interview.captures[i].payload.format;
            if (format.kind == StreamConservationRecordTypes.FormatKind.CATALOG) {
                p.catalogs[cursor++] = _catalog(d, format.catalog);
            }
        }
    }

    function _catalog(
        StreamConservationRecordContext.Dependencies memory d,
        StreamConservationRecordTypes.Catalog memory catalog
    ) private view returns (IStreamConservationRecordSelection.CatalogPin memory pin) {
        bytes memory bytes_ = StreamConservationFormatJson.catalogDocument(catalog);
        pin.documentId = keccak256(bytes(catalog.name));
        pin.contentHash = keccak256(bytes_);
        pin.totalBytes = bytes_.length;
        bytes memory original = StreamConservationRecordContext.definition(
            d,
            pin.documentId,
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            pin.contentHash,
            pin.totalBytes,
            StreamWorkRecordDefinitions.CANON_ID,
            false
        );
        StreamRecordJson.requirePayload(bytes_, original);
    }
}
