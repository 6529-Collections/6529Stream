// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamConservationSelectionFixture.sol";

contract StreamConservationSelectionBoundariesTest is ConservationSelectionFixture {
    function testAllNineDefinitionsRetireWithoutErasingSelectedHistory() public ready {
        StreamConservationRecordTypes.Intent memory v = _intent();
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        selection.adoptIntent(1, subject, hash, 0, 0, _intentWitness(hash, v));
        bytes32[9] memory ids = [
            StreamConservationDefinitions.INTENT_SCHEMA_ID,
            StreamConservationDefinitions.INTENT_PROFILE_ID,
            StreamConservationDefinitions.WAIVER_SCHEMA_ID,
            StreamConservationDefinitions.WAIVER_PROFILE_ID,
            StreamConservationDefinitions.INTERVIEW_SCHEMA_ID,
            StreamConservationDefinitions.INTERVIEW_PROFILE_ID,
            StreamConservationDefinitions.CATALOG_SCHEMA_ID,
            StreamConservationDefinitions.CATALOG_PROFILE_ID,
            StreamWorkRecordDefinitions.CANON_ID
        ];
        for (uint256 i; i < ids.length; ++i) {
            uint256 snapshot = vm.snapshotState();
            _retire(ids[i]);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamConservationRecordSelection.ConservationDefinitionUnavailable.selector,
                    ids[i]
                )
            );
            selection.requireCurrent(1, subject, v.artist.origin, hash, 1);
            require(
                selection.conservationSelectionAt(1, subject, v.artist.origin, 1).record.recordHash
                    == hash,
                "retired definitions preserve history"
            );
            require(vm.revertToState(snapshot), "restore original definition");
        }
        selection.requireCurrent(1, subject, v.artist.origin, hash, 1);
    }

    function testCompleteInterviewCatalogAndUnselectedEntryAreAuthenticated() public ready {
        StreamConservationRecordTypes.Interview memory interview = _interview();
        StreamConservationRecordTypes.Format memory f;
        f.kind = StreamConservationRecordTypes.FormatKind.CATALOG;
        f.formatId = bytes32(uint256(7));
        f.catalog.name = "AUTHENTIC_CONSERVATION_FORMATS_V1";
        f.catalog.selectedEntryId = f.formatId;
        f.catalog.entries = new StreamConservationRecordTypes.CatalogEntry[](2);
        f.catalog.entries[0].entryId = bytes32(uint256(6));
        f.catalog.entries[0].puid = "fmt/199";
        f.catalog.entries[1].entryId = f.formatId;
        f.catalog.entries[1].puid = "fmt/111";
        interview.transcript.format = f;
        bytes memory catalog = StreamConservationFormatJson.catalogDocument(f.catalog);
        bytes32 id = _registerDocument(
            f.catalog.name,
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            catalog,
            StreamWorkRecordDefinitions.CANON_ID
        );
        StreamConservationRecordTypes.Intent memory v = _intent();
        IStreamConservationRecordSelection.InterviewWitness memory iw;
        (v, iw) = _withInterview(v, interview, 1);
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        IStreamConservationRecordSelection.IntentWitness memory w = _intentWitness(hash, v);
        w.interview = iw;
        // A mutation of an unselected entry does not change the visible selected mapping,
        // but must still fail the complete catalog commitment in the recorded interview bytes.
        w.interview.interview.transcript.format.catalog.entries[0].puid = "fmt/200";
        vm.expectRevert();
        selection.adoptIntent(1, subject, hash, 0, 0, w);
        w.interview.interview.transcript.format.catalog.entries[0].puid = "fmt/199";
        selection.adoptIntent(1, subject, hash, 0, 0, w);
        IStreamConservationRecordSelection.CatalogPin memory pin =
            selection.selectionCatalogAt(1, subject, v.artist.origin, 1, 0);
        require(
            pin.documentId == id && pin.contentHash == keccak256(catalog)
                && pin.totalBytes == catalog.length
                && selection.selectionCatalogCount(1, subject, v.artist.origin, 1) == 1,
            "complete registered catalog pin"
        );
        _retire(id);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConservationRecordSelection.ConservationDefinitionUnavailable.selector, id
            )
        );
        selection.requireCurrent(1, subject, v.artist.origin, hash, 1);
        require(
            selection.selectionCatalogAt(1, subject, v.artist.origin, 1, 0).contentHash
                == keccak256(catalog),
            "catalog history remains exact"
        );
    }

    function testDeclaredEstateRetainsOriginalArtistInterviewAuthor() public ready {
        StreamConservationRecordTypes.Intent memory v = _intent();
        IStreamConservationRecordSelection.InterviewWitness memory iw;
        (v, iw) = _withInterview(v, _interview(), 1);
        v.artist.origin = StreamConservationRecordTypes.StatementOrigin.ESTATE_STATEMENT;
        identityOwner.setIdentity(ESTATE, 3, 3, IDENTITY);
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            3
        );
        IStreamConservationRecordSelection.IntentWitness memory w = _intentWitness(hash, v);
        w.interview = iw;
        IStreamConservationRecordSelection.Selection memory s =
            selection.adoptIntent(1, subject, hash, 0, 0, w);
        require(
            s.record.recorder == ESTATE && s.record.publication.authorityClass == 3
                && s.interview.recorder == ORIGINAL && s.interview.publication.authorityClass == 1,
            "estate statement cannot relabel interview author"
        );
    }

    function testMalformedReceiptsAndDetachedEvidenceDoNotCreateHead() public ready {
        StreamConservationRecordTypes.Intent memory v = _intent();
        (bytes32 hash, bytes32 authorization) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        (, IStreamCollectionMetadataV1.RecordReceipt memory receipt) =
            metadata.collectionRecord(hash);
        bytes memory input =
            abi.encodeCall(IStreamCollectionRecordReceipts.collectionRecordReceipt, (hash));
        bytes memory healthy = abi.encode(receipt);
        IStreamConservationRecordSelection.IntentWitness memory w = _intentWitness(hash, v);
        for (uint256 i; i < 5; ++i) {
            bytes memory bad = abi.encode(receipt);
            if (i == 0) bad = new bytes(32);
            if (i == 1) bad = bytes.concat(healthy, hex"00");
            if (i == 2) assembly ("memory-safe") { mstore(add(bad, 96), 256) }
            if (i == 3) assembly ("memory-safe") { mstore(add(bad, 160), shl(64, 1)) }
            if (i == 4) bad = new bytes(9000);
            cvm.mockCall(address(metadata), input, bad);
            vm.expectRevert();
            selection.adoptIntent(1, subject, hash, 0, 0, w);
            cvm.clearMockedCalls();
        }
        IStreamArtistRecordPublicationOwner.Record memory saved =
            attributionOwner.publicationAttestation(authorization);
        for (uint256 i; i < 5; ++i) {
            IStreamArtistRecordPublicationOwner.Record memory bad =
                abi.decode(abi.encode(saved), (IStreamArtistRecordPublicationOwner.Record));
            if (i == 0) bad.evidence.requiredCapability = 1;
            if (i == 1) bad.evidence.signer = RELAYER;
            if (i == 2) bad.evidence.authorityClass = 4;
            if (i == 3) bad.publication.uriHash = bytes32(uint256(17));
            if (i == 4) bad.metadataHostCodeHash = bytes32(uint256(19));
            cvm.mockCall(
                address(attributionOwner),
                abi.encodeCall(
                    IStreamArtistRecordPublicationOwner.publicationAttestation, (authorization)
                ),
                abi.encode(bad)
            );
            vm.expectRevert();
            selection.adoptIntent(1, subject, hash, 0, 0, w);
            cvm.clearMockedCalls();
        }
        require(
            selection.currentConservation(1, subject, v.artist.origin).revision == 0,
            "all failures leave no head"
        );
        selection.adoptIntent(1, subject, hash, 0, 0, w);
    }

    function testStatementBytesAndSubjectStateMustMatchActualOp24() public ready {
        StreamConservationRecordTypes.Intent memory v = _intent();
        (bytes32 hash, bytes32 authorization) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        IStreamConservationRecordSelection.IntentWitness memory w = _intentWitness(hash, v);
        T.AttestationRecord memory attestation = attributionOwner.attestationRecord(authorization);
        T.AttestationRecord memory wrong = attestation;
        wrong.subjectStateHash = 0;
        cvm.mockCall(
            address(attributionOwner),
            abi.encodeCall(IStreamArtistAttributionOwner.attestationRecord, (authorization)),
            abi.encode(wrong)
        );
        vm.expectRevert();
        selection.adoptIntent(1, subject, hash, 0, 0, w);
        cvm.clearMockedCalls();
        cvm.mockCall(
            address(attributionOwner),
            abi.encodeCall(
                IStreamArtistAttributionOwner.statementBytes, (attestation.statementHash)
            ),
            abi.encode(new bytes(416))
        );
        vm.expectRevert();
        selection.adoptIntent(1, subject, hash, 0, 0, w);
        cvm.clearMockedCalls();
        selection.adoptIntent(1, subject, hash, 0, 0, w);
    }

    function testInactiveInterviewWitnessAndExactOptionalCaptureCannotBeIgnored() public ready {
        StreamConservationRecordTypes.Intent memory v = _intent();
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        IStreamConservationRecordSelection.IntentWitness memory w = _intentWitness(hash, v);
        w.interview.interview.predecessor = bytes32(uint256(22));
        vm.expectRevert();
        selection.adoptIntent(1, subject, hash, 0, 0, w);
        StreamConservationRecordTypes.Interview memory interview = _interview();
        interview.captures = new StreamConservationRecordTypes.Capture[](1);
        interview.captures[0].kind = StreamConservationRecordTypes.CaptureKind.AUDIO;
        interview.captures[0].payload = interview.transcript;
        interview.captures[0].payload.content = _ref("ipfs://audio");
        (v, w.interview) = _withInterview(v, interview, 1);
        (hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        w.original = originals[hash];
        w.intent = v;
        w.interview.interview.captures[0].payload.content.uri = "ipfs://substituted-audio";
        vm.expectRevert();
        selection.adoptIntent(1, subject, hash, 0, 0, w);
        w.interview.interview.captures[0].payload.content.uri = "ipfs://audio";
        selection.adoptIntent(1, subject, hash, 0, 0, w);
    }

    function testAssociationAndProviderChangeStopNewConsumptionButKeepRawHistory() public ready {
        StreamConservationRecordTypes.Intent memory v = _intent();
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        IStreamConservationRecordSelection.Selection memory s =
            selection.adoptIntent(1, subject, hash, 0, 0, _intentWitness(hash, v));
        T.Binding memory b = bindingOwner.binding(1);
        b.generation = 2;
        b.bindingHash = keccak256("replacement");
        bindingOwner.setBinding(b, 2);
        attributionOwner.setBinding(b, 2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConservationRecordSelection.ConservationAssociationChanged.selector
            )
        );
        selection.requireCurrent(1, subject, v.artist.origin, hash, 1);
        vm.etch(address(metadata), hex"00");
        require(
            keccak256(abi.encode(selection.currentConservation(1, subject, v.artist.origin)))
                    == keccak256(abi.encode(s))
                && keccak256(
                    abi.encode(selection.conservationSelectionAt(1, subject, v.artist.origin, 1))
                ) == keccak256(abi.encode(s)),
            "local history is independent of live providers"
        );
    }

    function testFuzzWrongPredecessorNeverConsumesCurrentRevision(bytes32 other) public ready {
        StreamConservationRecordTypes.Intent memory v = _intent();
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        selection.adoptIntent(1, subject, hash, 0, 0, _intentWitness(hash, v));
        if (other == hash) other = bytes32(uint256(other) ^ 1);
        v.predecessor = other;
        recordURI = "ipfs://distinct-predecessor-candidate";
        (bytes32 next,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        IStreamConservationRecordSelection.IntentWitness memory w = _intentWitness(next, v);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConservationRecordSelection.ConservationSelectionConflict.selector
            )
        );
        selection.adoptIntent(1, subject, next, hash, 1, w);
        require(
            selection.currentConservation(1, subject, v.artist.origin).revision == 1,
            "arbitrary wrong predecessor never consumes CAS"
        );
    }

    function testMalformedLaterAuthorAppendCannotVetoExactPredecessorAndSanctionedAssociation()
        public
        ready
    {
        StreamConservationRecordTypes.Intent memory v = _intent();
        (bytes32 first,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        selection.adoptIntent(1, subject, first, 0, 0, _intentWitness(first, v));
        v.predecessor = first;
        (bytes32 next,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        (bytes32 hostile,) =
            _publish(IStreamConservationRecordSelection.RecordKind.INTENT, bytes("{}"), 1);
        require(hostile != next, "distinct later generic append");
        attributionOwner.setBinding(bindingOwner.binding(1), 3);
        selection.adoptIntent(1, subject, next, first, 1, _intentWitness(next, v));
        selection.requireCurrent(1, subject, v.artist.origin, next, 2);
        attributionOwner.setBinding(bindingOwner.binding(1), 4);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConservationRecordSelection.ConservationAssociationChanged.selector
            )
        );
        selection.requireCurrent(1, subject, v.artist.origin, next, 2);
        require(
            selection.currentConservation(1, subject, v.artist.origin).record.recordHash == next,
            "live association rejection does not erase original selected history"
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
