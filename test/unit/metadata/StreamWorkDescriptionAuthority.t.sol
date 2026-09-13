// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCollectionMetadataV1.t.sol";

/// @notice Actual metadata/schema/store authority intersection; artist and Core are explicit doubles.
/// @dev Payloads deliberately remain opaque here. Exact typed JSON interpretation is separate.
contract StreamWorkDescriptionAuthorityTest is CollectionMetadataV1Fixture {
    bytes32 private constant WORK = keccak256("WORK_DESCRIPTION");
    bytes32 private constant WORK_SCHEMA = keccak256("STREAM_WORK_DESCRIPTION_V1");

    function _configure(uint16 mask) private {
        _register(
            "STREAM_WORK_DESCRIPTION_V1", IStreamSchemaRegistry.DocumentKind.SCHEMA, bytes("{}")
        );
        _admit(WORK, StreamRecordFamilies.CURATOR, mask);
    }

    function _work(bytes memory payload)
        private
        view
        returns (IStreamPreservationRecords.CollectionRecord memory r)
    {
        r = _record(WORK, payload);
        r.schemaId = WORK_SCHEMA;
    }

    function testOnlyExactWorkTypeCanAddArtistBitAndCannotRelabelFamily() public {
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.InvalidMetadataRecord.selector)
        );
        metadata.recordTypeTransition(
            keccak256("ANOTHER_CURATOR_TYPE"), StreamRecordFamilies.CURATOR, 0x010a
        );
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.InvalidMetadataRecord.selector)
        );
        metadata.recordTypeTransition(WORK, StreamRecordFamilies.ARTIST, 2);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.InvalidMetadataRecord.selector)
        );
        metadata.recordTypeTransition(WORK, StreamRecordFamilies.CURATOR, 0x018a);
        _configure(0x010a);
        IStreamCollectionMetadataV1.RecordPolicy memory policy = metadata.recordPolicy(WORK);
        require(
            policy.family == StreamRecordFamilies.CURATOR && policy.authorizationMask == 0x010a
                && policy.admitted,
            "one governed shared policy"
        );
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.InvalidMetadataRecord.selector)
        );
        metadata.recordTypeTransition(WORK, StreamRecordFamilies.CURATOR, 8);
        require(
            StreamRecordFamilies.allowed(StreamRecordFamilies.CURATOR) == 0x0108,
            "other curatorial types unchanged"
        );
    }

    function testArtistCandidateRequiresExplicitPolicyBitWithCuratorHealthyControl() public {
        _configure(8);
        bytes memory payload = bytes("work record");
        IStreamPreservationRecords.CollectionRecord memory r = _work(payload);
        store.publishChunk(payload);
        P.Publication memory p = _publication(address(0xa11ce), r);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.InvalidMetadataRecord.selector)
        );
        metadata.requireArtistRecordCandidate(p);
        bytes32 hash = metadata.recordCollectionRecordWithPayload(1, r, payload);
        (, IStreamCollectionMetadataV1.RecordReceipt memory receipt) =
            metadata.collectionRecord(hash);
        require(receipt.authorizationClass == 3, "curator remains eligible without artist bit");
    }

    function testSharedPolicyDoesNotPermitDirectArtistOrCrossFamilyGrant() public {
        _configure(0x010a);
        address recorder = address(0xa11ce);
        artist.setSigner(recorder);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.MetadataAuthorityRequired.selector)
        );
        metadata.familyWriterTransition(1, StreamRecordFamilies.CURATOR, 1, recorder, true);
        _grant(1, StreamRecordFamilies.RIGHTS, 7, recorder, true);
        bytes memory payload = bytes("authored description");
        IStreamPreservationRecords.CollectionRecord memory r = _work(payload);
        vm.prank(recorder);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.MetadataAuthorityRequired.selector)
        );
        metadata.recordCollectionRecordWithPayload(1, r, payload);
        artist.permit(keccak256("exact artist permit"), _publication(recorder, r));
        bytes32 hash = metadata.recordArtistCollectionRecordWithPayload(
            recorder, 1, r, payload, keccak256("exact artist permit")
        );
        require(hash == _oldRecordHash(recorder, r), "unchanged generic fourteen-word preimage");
    }

    function testArtistAndCuratorKeepDistinctReceiptsHistoryAndOriginalPayloads() public {
        _configure(0x010a);
        address recorder = address(0xa11ce);
        artist.setSigner(recorder);
        bytes memory payload = bytes("same authored bytes");
        IStreamPreservationRecords.CollectionRecord memory r = _work(payload);
        P.Publication memory p = _publication(recorder, r);
        bytes32 authorization = keccak256("artist description permit");
        artist.permit(authorization, p);
        bytes32 artistHash = metadata.recordArtistCollectionRecordWithPayload(
            recorder, 1, r, payload, authorization
        );
        bytes32 curatorHash = metadata.recordCollectionRecordWithPayload(1, r, payload);
        require(
            artistHash != curatorHash && artistHash == p.candidateRecordHash
                && curatorHash == _oldRecordHash(address(this), r),
            "distinct literal original recorder domains"
        );
        (, IStreamCollectionMetadataV1.RecordReceipt memory a) =
            metadata.collectionRecord(artistHash);
        (, IStreamCollectionMetadataV1.RecordReceipt memory c) =
            metadata.collectionRecord(curatorHash);
        require(
            a.authorizationClass == 1 && a.artistAuthorization == authorization
                && a.recorder == recorder && a.recordIndex == 0,
            "saved artist provenance"
        );
        require(
            c.authorizationClass == 3 && c.artistAuthorization == 0 && c.recorder == address(this)
                && c.recordIndex == 1,
            "saved curator provenance"
        );
        require(
            metadata.latestCollectionRecordHashFor(1, WORK, subject, recorder) == artistHash
                && metadata.latestCollectionRecordHashFor(1, WORK, subject, address(this))
                    == curatorHash,
            "per-author latest never cross-author supersession"
        );
        require(metadata.payloadPointerCount(1) == 1, "same family exact bytes share one pointer");
        (, bytes32 family, bytes32 contentHash) = metadata.payloadPointerAt(1, 0);
        require(
            family == StreamRecordFamilies.CURATOR && contentHash == keccak256(payload),
            "original family retained"
        );
        _grant(1, StreamRecordFamilies.CURATOR, 3, address(this), false);
        artist.setSigner(address(0xb0b));
        (, bytes memory original) = metadata.recordPayload(artistHash);
        require(
            keccak256(original) == keccak256(payload),
            "historical artist bytes survive authority change"
        );
        (, original) = metadata.recordPayload(curatorHash);
        require(
            keccak256(original) == keccak256(payload),
            "historical curator bytes survive grant revocation"
        );
    }

    function testExactSchemaRequiredOnDirectAndArtistPathsWithHealthyControl() public {
        _configure(0x010a);
        address recorder = address(0xa11ce);
        artist.setSigner(recorder);
        bytes memory payload = bytes("schema-bound work");
        IStreamPreservationRecords.CollectionRecord memory r = _work(payload);
        r.schemaId = schemaId; // A different, active registered schema.
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.InvalidMetadataRecord.selector)
        );
        metadata.recordCollectionRecordWithPayload(1, r, payload);
        artist.permit(keccak256("wrong-schema"), _publication(recorder, r));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.InvalidMetadataRecord.selector)
        );
        metadata.recordArtistCollectionRecordWithPayload(
            recorder, 1, r, payload, keccak256("wrong-schema")
        );
        require(
            !metadata.consumedArtistAuthorization(keccak256("wrong-schema"))
                && metadata.payloadPointerCount(1) == 0,
            "no bad-schema consumption or index"
        );
        r.schemaId = WORK_SCHEMA;
        artist.permit(keccak256("correct-schema"), _publication(recorder, r));
        metadata.recordArtistCollectionRecordWithPayload(
            recorder, 1, r, payload, keccak256("correct-schema")
        );
    }

    function testLateFailureRollsBackUploadPermitAndHistoryThenReplayRejects() public {
        _configure(0x010a);
        address recorder = address(0xa11ce);
        artist.setSigner(recorder);
        bytes memory payload = bytes("rollback work");
        IStreamPreservationRecords.CollectionRecord memory r = _work(payload);
        r.uri = "javascript:bad";
        bytes32 authorization = keccak256("bad uri");
        artist.permit(authorization, _publication(recorder, r));
        vm.expectRevert(abi.encodeWithSelector(StreamMetadataRenderer.UnsafeMetadataURI.selector));
        metadata.recordArtistCollectionRecordWithPayload(recorder, 1, r, payload, authorization);
        require(
            !metadata.consumedArtistAuthorization(authorization)
                && metadata.payloadPointerCount(1) == 0,
            "late failure rolls back all host state"
        );
        (address pointer,) = store.chunk(keccak256(payload));
        require(pointer == address(0), "new chunk also rolled back");
        r.uri = "ipfs://record";
        authorization = keccak256("valid uri");
        artist.permit(authorization, _publication(recorder, r));
        metadata.recordArtistCollectionRecordWithPayload(recorder, 1, r, payload, authorization);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionMetadataV1.MetadataAuthorizationConsumed.selector, authorization
            )
        );
        metadata.recordArtistCollectionRecordWithPayload(recorder, 1, r, payload, authorization);
    }

    function testThresholdSafeGlobalAdministratorWritesAndReadsWorkDescription() public {
        _configure(0x010a);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 111;
        keys[1] = 222;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 1);
        _grant(0, StreamRecordFamilies.CURATOR, 8, address(account), true);
        bytes memory payload = bytes("Safe-authored curatorial description");
        IStreamPreservationRecords.CollectionRecord memory r = _work(payload);
        executeSafe(
            account,
            keys,
            address(metadata),
            0,
            abi.encodeCall(metadata.recordCollectionRecordWithPayload, (uint256(1), r, payload)),
            0
        );
        bytes32 hash = _oldRecordHash(address(account), r);
        (, IStreamCollectionMetadataV1.RecordReceipt memory receipt) =
            metadata.collectionRecord(hash);
        require(
            receipt.authorizationClass == 8 && receipt.recorder == address(account)
                && receipt.artistAuthorization == 0,
            "global administrator attribution"
        );
        executeSafe(
            account,
            keys,
            address(metadata),
            0,
            abi.encodeCall(metadata.collectionRecord, (hash)),
            0
        );
        executeSafe(
            account, keys, address(metadata), 0, abi.encodeCall(metadata.recordPayload, (hash)), 0
        );
        executeSafe(
            account, keys, address(metadata), 0, abi.encodeCall(metadata.recordPolicy, (WORK)), 0
        );
    }

    function testFuzzSharedArtistRecordPreservesExactHashAndBytes(bytes32 value, uint64 timestamp)
        public
    {
        _configure(0x010a);
        if (timestamp == 0) timestamp = 1;
        address recorder = address(0xa11ce);
        artist.setSigner(recorder);
        bytes memory payload = abi.encode(value);
        IStreamPreservationRecords.CollectionRecord memory r = _work(payload);
        r.effectiveAt = timestamp;
        P.Publication memory p = _publication(recorder, r);
        bytes32 authorization = keccak256("fuzz work description authorization");
        artist.permit(authorization, p);
        bytes32 hash = metadata.recordArtistCollectionRecordWithPayload(
            recorder, 1, r, payload, authorization
        );
        require(hash == _oldRecordHash(recorder, r), "exact original hash");
        (, bytes memory saved) = metadata.recordPayload(hash);
        require(
            keccak256(saved) == keccak256(payload) && saved.length == payload.length,
            "all exact bytes"
        );
    }
}
