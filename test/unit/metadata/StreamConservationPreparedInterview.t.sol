// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamConservationSelectionFixture.sol";

contract StreamConservationPreparedInterviewTest is ConservationSelectionFixture {
    function testPreparedOriginalHasLiteralCommitmentAndNoHeadAndIsReusable() public ready {
        (
            StreamConservationRecordTypes.Intent memory v,
            IStreamConservationRecordSelection.InterviewWitness memory iw
        ) = _withInterview(_intent(), _interview(), 1);
        bytes32 interviewHash = v.interview.record.recordHash;
        vm.prank(RELAYER);
        IStreamConservationRecordSelection.PreparedInterview memory p =
            selection.prepareInterview(1, subject, interviewHash, iw);
        bytes32 commitment = p.preparationHash;
        p.preparationHash = 0;
        require(
            commitment
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONSERVATION_INTERVIEW_PREPARATION_V1"),
                        block.chainid,
                        address(selection),
                        address(core),
                        address(metadata),
                        address(schemas),
                        address(store),
                        p
                    )
                ),
            "literal full immutable preparation preimage"
        );
        require(
            selection.currentConservation(1, subject, v.artist.origin).revision == 0,
            "preparation does not choose intent or interview head"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConservationRecordSelection.ConservationSelectionConflict.selector
            )
        );
        selection.prepareInterview(1, subject, interviewHash, iw);
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        IStreamConservationRecordSelection.Selection memory first =
            selection.adoptIntentWithPreparedInterview(
                1, subject, hash, 0, 0, _intentWitness(hash, v)
            );
        require(
            first.interview.recorder == ORIGINAL && first.submitter == address(this),
            "preparer has no authority in selected evidence"
        );
        StreamConservationRecordTypes.IntentWaiver memory waiver = _waiver();
        waiver.predecessor = hash;
        waiver.interview = v.interview;
        (bytes32 next,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT_WAIVER,
            StreamArtistIntentWaiverJson.serialize(waiver),
            1
        );
        selection.adoptWaiverWithPreparedInterview(
            1, subject, next, hash, 1, _waiverWitness(next, waiver)
        );
        require(
            selection.preparedInterview(interviewHash).preparationHash == commitment,
            "reuse does not mutate original preparation"
        );
    }

    function testPreparationFailureRollsBackAndExactOriginalRetries() public ready {
        (
            StreamConservationRecordTypes.Intent memory v,
            IStreamConservationRecordSelection.InterviewWitness memory iw
        ) = _withInterview(_intent(), _interview(), 1);
        bytes32 hash = v.interview.record.recordHash;
        IStreamConservationRecordSelection.InterviewWitness memory bad =
            abi.decode(abi.encode(iw), (IStreamConservationRecordSelection.InterviewWitness));
        bad.interview.languages[0] = "de";
        vm.expectRevert();
        selection.prepareInterview(1, subject, hash, bad);
        bytes memory data = abi.encodeCall(selection.prepareInterview, (1, subject, hash, iw));
        (bool ok,) = address(selection).call{ gas: 100000 }(data);
        require(
            !ok && selection.preparedInterview(hash).preparationHash == 0,
            "failed preparation is not a readiness bit"
        );
        selection.prepareInterview(1, subject, hash, iw);
    }

    function testPreparedPathRequiresCanonicalEmptyNestedWitnessAndExactLocator() public ready {
        (
            StreamConservationRecordTypes.Intent memory v,
            IStreamConservationRecordSelection.InterviewWitness memory iw
        ) = _withInterview(_intent(), _interview(), 1);
        selection.prepareInterview(1, subject, v.interview.record.recordHash, iw);
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        IStreamConservationRecordSelection.IntentWitness memory w = _intentWitness(hash, v);
        w.interview = iw;
        vm.expectRevert();
        selection.adoptIntentWithPreparedInterview(1, subject, hash, 0, 0, w);
        for (uint256 i; i < 5; ++i) {
            StreamConservationRecordTypes.Intent memory bad =
                abi.decode(abi.encode(v), (StreamConservationRecordTypes.Intent));
            if (i == 0) bad.interview.record.chainId += 1;
            if (i == 1) bad.interview.record.core = address(0x1111);
            if (i == 2) bad.interview.record.host = address(0x2222);
            if (i == 3) bad.interview.record.recordHash = keccak256("unprepared original");
            if (i == 4) {
                bad.interview.record.payload.digest = abi.encodePacked(keccak256("false JCS bytes"));
            }
            (bytes32 candidate,) = _publish(
                IStreamConservationRecordSelection.RecordKind.INTENT,
                StreamArtistIntentJson.serialize(bad),
                1
            );
            vm.expectRevert();
            selection.adoptIntentWithPreparedInterview(
                1, subject, candidate, 0, 0, _intentWitness(candidate, bad)
            );
        }
        selection.adoptIntentWithPreparedInterview(1, subject, hash, 0, 0, _intentWitness(hash, v));
    }

    function testPreparedParentStillRequiresCurrentDefinitionsAndAssociation() public ready {
        (
            StreamConservationRecordTypes.Intent memory v,
            IStreamConservationRecordSelection.InterviewWitness memory iw
        ) = _withInterview(_intent(), _interview(), 1);
        bytes32 interviewHash = v.interview.record.recordHash;
        selection.prepareInterview(1, subject, interviewHash, iw);
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        uint256 snapshot = vm.snapshotState();
        _retire(StreamConservationDefinitions.INTERVIEW_PROFILE_ID);
        vm.expectRevert();
        selection.adoptIntentWithPreparedInterview(1, subject, hash, 0, 0, _intentWitness(hash, v));
        require(
            selection.preparedInterview(interviewHash).record.recordHash == interviewHash,
            "retirement preserves raw prepared evidence"
        );
        require(vm.revertToState(snapshot), "restore definitions");
        T.Binding memory b = bindingOwner.binding(1);
        b.bindingHash = keccak256("corrected association");
        bindingOwner.setBinding(b, 2);
        vm.expectRevert();
        selection.adoptIntentWithPreparedInterview(1, subject, hash, 0, 0, _intentWitness(hash, v));
        b.bindingHash = BINDING;
        bindingOwner.setBinding(b, 2);
        selection.adoptIntentWithPreparedInterview(1, subject, hash, 0, 0, _intentWitness(hash, v));
    }

    function testPreparedParentStillEnforcesCASAndOneWayArtistLock() public ready {
        (
            StreamConservationRecordTypes.Intent memory v,
            IStreamConservationRecordSelection.InterviewWitness memory iw
        ) = _withInterview(_intent(), _interview(), 1);
        selection.prepareInterview(1, subject, v.interview.record.recordHash, iw);
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        selection.adoptIntentWithPreparedInterview(1, subject, hash, 0, 0, _intentWitness(hash, v));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConservationRecordSelection.ConservationSelectionConflict.selector
            )
        );
        selection.adoptIntentWithPreparedInterview(1, subject, hash, 0, 0, _intentWitness(hash, v));
        vm.prank(ORIGINAL);
        selection.lockArtistIntent(1, subject, hash, 1);
        v.predecessor = hash;
        (bytes32 next,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConservationRecordSelection.ConservationHeadLocked.selector
            )
        );
        selection.adoptIntentWithPreparedInterview(
            1, subject, next, hash, 1, _intentWitness(next, v)
        );
        require(
            selection.currentConservation(1, subject, v.artist.origin).record.recordHash == hash,
            "prepared original cannot bypass a parent lock"
        );
    }

    function testPreparedCompleteCatalogCannotBypassLaterCatalogRetirement() public ready {
        StreamConservationRecordTypes.Interview memory interview = _interview();
        StreamConservationRecordTypes.Format memory format;
        format.kind = StreamConservationRecordTypes.FormatKind.CATALOG;
        format.formatId = bytes32(uint256(99));
        format.catalog.selectedEntryId = format.formatId;
        format.catalog.name = "PREPARED_INTERVIEW_FORMATS_V1";
        format.catalog.entries = new StreamConservationRecordTypes.CatalogEntry[](2);
        format.catalog.entries[0].entryId = bytes32(uint256(98));
        format.catalog.entries[0].puid = "fmt/199";
        format.catalog.entries[1].entryId = format.formatId;
        format.catalog.entries[1].puid = "fmt/111";
        interview.transcript.format = format;
        bytes32 id = _registerDocument(
            format.catalog.name,
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            StreamConservationFormatJson.catalogDocument(format.catalog),
            StreamWorkRecordDefinitions.CANON_ID
        );
        (
            StreamConservationRecordTypes.Intent memory v,
            IStreamConservationRecordSelection.InterviewWitness memory iw
        ) = _withInterview(_intent(), interview, 1);
        selection.prepareInterview(1, subject, v.interview.record.recordHash, iw);
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        _retire(id);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConservationRecordSelection.ConservationDefinitionUnavailable.selector, id
            )
        );
        selection.adoptIntentWithPreparedInterview(1, subject, hash, 0, 0, _intentWitness(hash, v));
        require(
            selection.preparedInterview(v.interview.record.recordHash).catalogs[0].documentId == id,
            "complete immutable catalog provenance survives eligibility retirement"
        );
    }

    function _retire(bytes32 id) private {
        (bytes32 s, bytes32 o, bytes32 n) =
            schemas.statusTransition(id, IStreamSchemaRegistry.DocumentStatus.DEPRECATED);
        executor.execute(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus, (id, IStreamSchemaRegistry.DocumentStatus.DEPRECATED)
            ),
            s,
            o,
            n
        );
    }
}
