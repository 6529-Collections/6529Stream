// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamConservationSelectionFixture.sol";

/// @notice Actual Metadata/Schema/Store; explicit Core/Executor/artist-owner response boundaries.
contract StreamConservationRecordSelectionTest is ConservationSelectionFixture {
    function testOriginalArtistReceiptAndLiteralSelectionCommitment() public ready {
        StreamConservationRecordTypes.Intent memory v = _intent();
        bytes memory payload = StreamArtistIntentJson.serialize(v);
        (bytes32 hash, bytes32 authorization) =
            _publish(IStreamConservationRecordSelection.RecordKind.INTENT, payload, 1);
        vm.prank(RELAYER);
        IStreamConservationRecordSelection.Selection memory s =
            selection.adoptIntent(1, subject, hash, 0, 0, _intentWitness(hash, v));
        (, IStreamCollectionMetadataV1.RecordReceipt memory receipt) =
            metadata.collectionRecord(hash);
        require(s.record.receiptHash == keccak256(abi.encode(receipt)), "complete original receipt");
        require(
            s.record.publication.attestationRecordHash == authorization
                && s.record.publication.authorityClass == 1
                && s.record.publication.requiredCapability == 64 && s.record.recorder == ORIGINAL
                && s.submitter == RELAYER && s.revision == 1
                && s.association.identityRecordHash == IDENTITY,
            "original authorship distinct from submitter"
        );
        require(
            s.interviewStatus == StreamConservationRecordTypes.InterviewStatus.WAIVED
                && s.interview.recordHash == 0 && s.interviewArchiveReferenceHash == 0,
            "explicit waiver never invents interview"
        );
        bytes32 commitment = s.selectionHash;
        s.selectionHash = 0;
        require(
            commitment
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONSERVATION_SELECTION_V1"),
                        block.chainid,
                        address(selection),
                        address(core),
                        address(metadata),
                        address(schemas),
                        address(store),
                        uint256(1),
                        subject,
                        s
                    )
                ),
            "literal complete selection commitment"
        );
        require(
            selection.requireCurrent(1, subject, v.artist.origin, hash, 1).selectionHash
                == commitment,
            "exact current selected evidence"
        );
    }

    function testLifetimeAlternatingChainMaterializesAfterSuccessionAndRejectsRaces() public ready {
        StreamConservationRecordTypes.Intent memory a = _intent();
        (bytes32 ah,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(a),
            1
        );
        StreamConservationRecordTypes.IntentWaiver memory b = _waiver();
        b.predecessor = ah;
        (bytes32 bh,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT_WAIVER,
            StreamArtistIntentWaiverJson.serialize(b),
            1
        );
        StreamConservationRecordTypes.Intent memory c = _intent();
        c.predecessor = bh;
        (bytes32 ch,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(c),
            1
        );
        identityOwner.setIdentity(ESTATE, 3, 3, IDENTITY);
        facade.setSigner(ESTATE);
        vm.warp(block.timestamp + 365 days);
        selection.adoptIntent(1, subject, ah, 0, 0, _intentWitness(ah, a));
        IStreamConservationRecordSelection.IntentWitness memory cw = _intentWitness(ch, c);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConservationRecordSelection.ConservationSelectionConflict.selector
            )
        );
        selection.adoptIntent(1, subject, ch, ah, 1, cw);
        selection.adoptWaiver(1, subject, bh, ah, 1, _waiverWitness(bh, b));
        selection.adoptIntent(1, subject, ch, bh, 2, cw);
        require(
            selection.currentConservation(1, subject, a.artist.origin).record.recordHash == ch,
            "complete original chain materialized after succession"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConservationRecordSelection.ConservationSelectionConflict.selector
            )
        );
        selection.adoptIntent(1, subject, ch, bh, 2, cw);
        require(
            selection.conservationSelectionAt(1, subject, a.artist.origin, 1).record.recordHash
                == ah,
            "all original history retained"
        );
    }

    function testExplicitArtistLockAndEstateHeadPreserveDistinctOriginals() public ready {
        StreamConservationRecordTypes.Intent memory artist = _intent();
        (bytes32 ah,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(artist),
            1
        );
        selection.adoptIntent(1, subject, ah, 0, 0, _intentWitness(ah, artist));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConservationRecordSelection.ConservationSelectionAuthorityRequired.selector
            )
        );
        selection.lockArtistIntent(1, subject, ah, 1);
        vm.prank(ORIGINAL);
        selection.lockArtistIntent(1, subject, ah, 1);
        require(selection.intentLock(1, subject).locker == ORIGINAL, "explicit lock author");
        artist.predecessor = ah;
        (bytes32 later,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(artist),
            1
        );
        IStreamConservationRecordSelection.IntentWitness memory w = _intentWitness(later, artist);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConservationRecordSelection.ConservationHeadLocked.selector
            )
        );
        selection.adoptIntent(1, subject, later, ah, 1, w);
        StreamConservationRecordTypes.IntentWaiver memory estate = _waiver();
        estate.artist.origin = StreamConservationRecordTypes.StatementOrigin.ESTATE_STATEMENT;
        identityOwner.setIdentity(ESTATE, 3, 3, IDENTITY);
        (bytes32 eh,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT_WAIVER,
            StreamArtistIntentWaiverJson.serialize(estate),
            3
        );
        selection.adoptWaiver(1, subject, eh, 0, 0, _waiverWitness(eh, estate));
        require(
            selection.currentConservation(1, subject, artist.artist.origin).record.recordHash == ah
                && selection.currentConservation(1, subject, estate.artist.origin).record.recordHash
                == eh,
            "estate absence never overwrites artist voice"
        );
        selection.requireCurrent(1, subject, artist.artist.origin, ah, 1);
    }

    function testPresentInterviewResolvesExactRecordAndSha256MirrorClaim() public ready {
        StreamConservationRecordTypes.Intent memory v = _intent();
        IStreamConservationRecordSelection.InterviewWitness memory interview;
        (v, interview) = _withInterview(v, _interview(), 1);
        v.interview.record.payload.algorithm = 2;
        v.interview.record.payload.digest =
            abi.encodePacked(sha256(StreamArtistInterviewJson.serialize(interview.interview)));
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        IStreamConservationRecordSelection.IntentWitness memory w = _intentWitness(hash, v);
        w.interview = interview;
        IStreamConservationRecordSelection.Selection memory s =
            selection.adoptIntent(1, subject, hash, 0, 0, w);
        require(
            s.interview.recordHash == v.interview.record.recordHash
                && s.interview.publication.requiredCapability == 1
                && s.interview.publication.authorityClass == 1
                && s.interviewPayloadCorrespondence
                    == IStreamConservationRecordSelection.PayloadCorrespondence.EXACT_JCS_SHA256
                && s.interviewArchiveReferenceHash
                    == keccak256(abi.encode(v.interview.record.payload)),
            "exact recorded interview and separately committed mirror correspondence"
        );
    }

    function testWrongKnownInterviewDigestRejectsAndOpaqueReferenceIsExplicit() public ready {
        StreamConservationRecordTypes.Intent memory v = _intent();
        IStreamConservationRecordSelection.InterviewWitness memory iw;
        (v, iw) = _withInterview(v, _interview(), 1);
        v.interview.record.payload.digest = abi.encodePacked(bytes32(uint256(123)));
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        IStreamConservationRecordSelection.IntentWitness memory w = _intentWitness(hash, v);
        w.interview = iw;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConservationRecordSelection.InvalidConservationRecord.selector,
                v.interview.record.recordHash
            )
        );
        selection.adoptIntent(1, subject, hash, 0, 0, w);
        v.interview.record.payload.algorithm = 5;
        v.interview.record.payload.digest = hex"01701220abcdef";
        (hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        w = _intentWitness(hash, v);
        w.interview = iw;
        IStreamConservationRecordSelection.Selection memory s =
            selection.adoptIntent(1, subject, hash, 0, 0, w);
        require(
            s.interviewPayloadCorrespondence
                    == IStreamConservationRecordSelection.PayloadCorrespondence.UNVERIFIED_REFERENCE
                && s.interviewArchiveReferenceHash
                    == keccak256(abi.encode(v.interview.record.payload)),
            "opaque bytes retained without invented hash verification"
        );
    }

    function testOriginalRecordAndOriginSpoofFailWithoutHeadMutation() public ready {
        StreamConservationRecordTypes.Intent memory v = _intent();
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        IStreamConservationRecordSelection.IntentWitness memory w = _intentWitness(hash, v);
        w.original.uri = "ipfs://same-receipt-wrong-tail";
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConservationRecordSelection.InvalidConservationRecord.selector, hash
            )
        );
        selection.adoptIntent(1, subject, hash, 0, 0, w);
        w = _intentWitness(hash, v);
        selection.adoptIntent(1, subject, hash, 0, 0, w);
        v.predecessor = hash;
        v.artist.origin = StreamConservationRecordTypes.StatementOrigin.ESTATE_STATEMENT;
        (bytes32 spoof,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        w = _intentWitness(spoof, v);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConservationRecordSelection.ConservationAssociationChanged.selector
            )
        );
        selection.adoptIntent(1, subject, spoof, 0, 0, w);
        require(
            selection.currentConservation(
                    1, subject, StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT
                ).record.recordHash == hash,
            "host and origin attacks leave head unchanged"
        );
    }
}
