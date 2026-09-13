// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamWorkSelectionFixture.sol";

/// @notice Actual Metadata/Schema/Store, with explicit Core/Executor/artist-owner response fixtures.
contract StreamWorkRecordSelectionTest is WorkSelectionFixture {
    function testCuratorHeadHasIndependentLiteralCommitmentAndExactEvent() public ready {
        StreamWorkRecordTypes.Description memory d = _named();
        bytes32 hash = _curatorPublish(d);
        (, IStreamCollectionMetadataV1.RecordReceipt memory receipt) =
            metadata.collectionRecord(hash);
        IStreamWorkRecordSelection.Selection memory expected;
        expected.recordHash = hash;
        expected.payloadHash = keccak256(StreamWorkRecordJson.serialize(d));
        expected.submitter = address(this);
        expected.mode = IStreamWorkRecordSelection.AdoptionMode.CURATOR_GRANT;
        expected.grantScope = 1;
        expected.grantRevision = 1;
        expected.revision = 1;
        expected.recordIndex = receipt.recordIndex;
        expected.recordChainHash = receipt.recordChainHash;
        expected.selectedAt = uint64(block.timestamp);
        expected.selectorAuthorizationClass = 3;
        expected.recorder = address(this);
        expected.recorderAuthorizationClass = 3;
        expected.creatorKind = StreamWorkRecordTypes.CreatorKind.NAMED;
        expected.selectionHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_WORK_SELECTION_V1"),
                block.chainid,
                address(selection),
                address(core),
                address(metadata),
                address(schemas),
                address(store),
                uint256(1),
                subject,
                expected
            )
        );
        vm.recordLogs();
        IStreamWorkRecordSelection.Selection memory actual =
            selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
        require(
            keccak256(abi.encode(actual)) == keccak256(abi.encode(expected)),
            "full independent selected tuple"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            logs.length == 1 && logs[0].emitter == address(selection) && logs[0].topics.length == 4,
            "one exact emitter/topics"
        );
        require(
            logs[0].topics[0]
                == keccak256(
                    "WorkRecordSelected(uint256,bytes32,bytes32,(bytes32,bytes32,bytes32,address,uint8,uint256,uint64,uint64,uint64,bytes32,uint64,uint8,address,uint8,uint8,uint8,(bytes32,bytes32,uint64,bytes32),(bytes32,bytes32,bytes32,uint64,address,uint8,uint32,uint64,bytes32),bytes32,bytes32,bytes32,bytes32))"
                ),
            "literal event signature"
        );
        require(
            logs[0].topics[1] == bytes32(uint256(1)) && logs[0].topics[2] == subject
                && logs[0].topics[3] == hash,
            "all indexed values"
        );
        require(keccak256(logs[0].data) == keccak256(abi.encode(expected)), "all event fields");
        require(
            keccak256(abi.encode(selection.requireCurrent(1, subject, hash, 1)))
                == keccak256(abi.encode(expected)),
            "current exact tuple"
        );
    }

    function testPermissionlessArtistAdoptionRetainsOriginalPublicationAcrossRotation()
        public
        ready
    {
        _bound(1, BINDING, 2);
        StreamWorkRecordTypes.Description memory d = _artistDescription();
        (bytes32 hash, bytes32 authorization) = _artistPublish(d);
        IStreamArtistRecordPublicationOwner.Record memory original =
            attributionOwner.publicationAttestation(authorization);
        facade.setSigner(address(0x1234));
        identityOwner.setIdentity(address(0x1234), 3, 3, IDENTITY);
        vm.warp(block.timestamp + 365 days);
        vm.prank(RELAYER);
        IStreamWorkRecordSelection.Selection memory saved =
            selection.adoptArtistRecord(1, subject, hash, 0, 0, _witness(hash, d));
        require(
            saved.submitter == RELAYER && saved.recorder == ORIGINAL
                && saved.selectorAuthorizationClass == 0 && saved.grantRevision == 0
                && saved.grantScope == 0
                && saved.mode == IStreamWorkRecordSelection.AdoptionMode.ARTIST_RECORD_ADOPTION,
            "delivery is not new authority"
        );
        require(
            saved.artistPublicationEvidenceHash == keccak256(abi.encode(original))
                && keccak256(abi.encode(saved.artistPublication))
                    == keccak256(abi.encode(original.evidence))
                && saved.creatorAssociation.identityRecordHash == IDENTITY
                && metadata.consumedArtistAuthorization(authorization),
            "complete original evidence retained"
        );
        selection.requireCurrent(1, subject, hash, 1);
    }

    function testArtistCannotBridgeCuratorOrRacingSuccessorAndSameProofRetries() public ready {
        _bound(1, BINDING, 2);
        StreamWorkRecordTypes.Description memory artistWork = _artistDescription();
        (bytes32 oldArtist,) = _artistPublish(artistWork);
        StreamWorkRecordTypes.Description memory curatorWork = _absence(0);
        bytes32 curatorHash = _curatorPublish(curatorWork);
        selection.selectCurrent(1, subject, curatorHash, 0, 0, _witness(curatorHash, curatorWork));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamWorkRecordSelection.WorkSelectionConflict.selector)
        );
        selection.adoptArtistRecord(
            1, subject, oldArtist, curatorHash, 1, _witness(oldArtist, artistWork)
        );
        artistWork.predecessor = curatorHash;
        (bytes32 next,) = _artistPublish(artistWork);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamWorkRecordSelection.WorkSelectionConflict.selector)
        );
        selection.adoptArtistRecord(1, subject, next, curatorHash, 0, _witness(next, artistWork));
        require(
            selection.currentWork(1, subject).recordHash == curatorHash, "failed CAS has no write"
        );
        selection.adoptArtistRecord(1, subject, next, curatorHash, 1, _witness(next, artistWork));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamWorkRecordSelection.WorkSelectionConflict.selector)
        );
        selection.adoptArtistRecord(1, subject, next, curatorHash, 1, _witness(next, artistWork));
        require(selection.currentWork(1, subject).revision == 2, "one accepted advancement");
    }

    function testOpaqueAuthorLatestAppendCannotVetoExactValidRecord() public ready {
        _bound(1, BINDING, 2);
        StreamWorkRecordTypes.Description memory d = _artistDescription();
        (bytes32 hash,) = _artistPublish(d);
        bytes memory opaque = bytes("{\"not\":\"WORK\"}");
        bytes32 later = metadata.recordCollectionRecordWithPayload(1, _workRecord(opaque), opaque);
        require(later != hash, "unrelated generic append");
        selection.adoptArtistRecord(1, subject, hash, 0, 0, _witness(hash, d));
        selection.requireCurrent(1, subject, hash, 1);
    }

    function testNamedCreatorCannotOverrideExistingArtistAndAbsenceIsExplicit() public ready {
        StreamWorkRecordTypes.Description memory d = _named();
        bytes32 hash = _curatorPublish(d);
        _bound(1, BINDING, 2);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamWorkRecordSelection.WorkAssociationChanged.selector)
        );
        selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
        d = _absence(0);
        hash = _curatorPublish(d);
        IStreamWorkRecordSelection.Selection memory s =
            selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
        require(
            s.form == StreamWorkRecordTypes.Form.DESCRIPTION_ABSENT
                && s.creatorAssociation.artistId == 0,
            "absence never fabricates a creator"
        );
    }

    function testAssociationChangeStopsConsumptionButNeverErasesRawHistory() public ready {
        _bound(1, BINDING, 3);
        StreamWorkRecordTypes.Description memory d = _artistDescription();
        (bytes32 hash,) = _artistPublish(d);
        IStreamWorkRecordSelection.Selection memory original =
            selection.adoptArtistRecord(1, subject, hash, 0, 0, _witness(hash, d));
        _bound(2, keccak256("replacement binding"), 2);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamWorkRecordSelection.WorkAssociationChanged.selector)
        );
        selection.requireCurrent(1, subject, hash, 1);
        vm.etch(address(metadata), hex"00");
        require(
            keccak256(abi.encode(selection.currentWork(1, subject)))
                    == keccak256(abi.encode(original))
                && keccak256(abi.encode(selection.workSelectionAt(1, subject, 1)))
                    == keccak256(abi.encode(original)),
            "provider-independent history"
        );
    }
}
