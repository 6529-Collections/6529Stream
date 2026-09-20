// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamCollectionMetadataV1.t.sol";
import {
    StreamSnapshotManifestBytes as PayloadBytes
} from "../../../smart-contracts/domains/records/StreamSnapshotManifestBytes.sol";

interface PayloadCapacityVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
}

/// @notice Actual Metadata/Schema/Store and Safe; explicit typed Core/Artist/governance boundaries.
contract StreamCollectionRecordPayloadCapacityTest is CollectionMetadataV1Fixture {
    function _body(uint256 length) internal pure returns (bytes memory data) {
        data = new bytes(length);
        for (uint256 i; i < length; ++i) {
            data[i] = bytes1(uint8(1 + (i * 13 + i / 8192) % 251));
        }
    }

    function _piece(bytes memory data, uint256 start, uint256 length)
        internal
        pure
        returns (bytes memory out)
    {
        out = new bytes(length);
        for (uint256 i; i < length; ++i) {
            out[i] = data[start + i];
        }
    }

    function _assertRoundTrip(bytes32 hash, bytes memory data) internal view {
        (address first, bytes memory restored) = metadata.recordPayload(hash);
        require(
            restored.length == data.length && keccak256(restored) == keccak256(data),
            "whole original bytes"
        );
        uint256 count = (data.length + 8191) / 8192;
        require(metadata.recordPayloadChunkCount(hash) == count, "exact ordered count");
        bytes memory joined;
        for (uint256 i; i < count; ++i) {
            (address pointer, bytes32 chunkHash) = metadata.recordPayloadChunkAt(hash, i);
            uint256 length = data.length - i * 8192;
            if (length > 8192) length = 8192;
            require(pointer.code.length == length + 1, "immutable byte carrier");
            bytes memory part = new bytes(length);
            assembly ("memory-safe") { extcodecopy(pointer, add(part, 32), 1, length) }
            require(keccak256(part) == chunkHash, "independent chunk hash");
            if (i == 0) require(pointer == first, "legacy return is first pointer");
            joined = bytes.concat(joined, part);
        }
        require(keccak256(joined) == keccak256(data), "state-only ordered reconstruction");
    }

    function testExact8192OriginalPointerReceiptAndChain() public {
        bytes memory data = _body(8192);
        IStreamPreservationRecords.CollectionRecord memory r = _record(CURATOR, data);
        bytes32 expected = _oldRecordHash(address(this), r);
        bytes32 chain = keccak256(
            abi.encode(
                bytes32(0x0e7a0feb85d4a4a3e90074703c19de35786e11afaae8f9868aa2a911bcfa1609),
                block.chainid,
                address(metadata),
                uint256(1),
                CURATOR,
                bytes32(0),
                expected,
                uint64(0)
            )
        );
        require(
            metadata.recordCollectionRecordWithPayload(1, r, data) == expected, "old14word record"
        );
        (, IStreamCollectionMetadataV1.RecordReceipt memory receipt) =
            metadata.collectionRecord(expected);
        require(
            receipt.recordChainHash == chain && receipt.recordIndex == 0, "old receipt and chain"
        );
        (address original,) = store.chunk(keccak256(data));
        (address saved, bytes32 savedHash) = metadata.recordPayloadChunkAt(expected, 0);
        require(saved == original && savedHash == keccak256(data), "original whole-payload pointer");
        require(metadata.payloadPointerCount(1) == 1, "original one row");
        _assertRoundTrip(expected, data);
    }

    function testDirect8193And24576RetainFullBytesAndOnlyAcceptedChunkInventory() public {
        for (uint256 j; j < 2; ++j) {
            bytes memory data = _body(j == 0 ? 8193 : 24576);
            IStreamPreservationRecords.CollectionRecord memory r = _record(CURATOR, data);
            bytes32 expected = _oldRecordHash(address(this), r);
            require(metadata.recordCollectionRecordWithPayload(1, r, data) == expected);
            _assertRoundTrip(expected, data);
        }
        // The two payloads share their first chunk; all accepted chunk rows are deduplicated.
        require(metadata.payloadPointerCount(1) == 4, "family chunk inventory");
        (, uint64 count) = metadata.recordChainHash(1, CURATOR);
        require(count == 2);
    }

    function testPermissionlessPreparationNeverAcceptsRecordOrInventory() public {
        bytes memory data = _body(24576);
        vm.prank(address(0x1234));
        bytes32 hash = metadata.prepareRecordPayload(data);
        require(hash == keccak256(data) && metadata.preparedRecordPayloadChunkCount(hash) == 3);
        require(metadata.payloadPointerCount(1) == 0, "preparation is not record admission");
        (, uint64 count) = metadata.recordChainHash(1, CURATOR);
        require(count == 0);
        require(metadata.latestCollectionRecordHashFor(1, CURATOR, subject, address(this)) == 0);
        require(metadata.prepareRecordPayload(data) == hash, "idempotent exact preparation");
        bytes32 accepted =
            metadata.recordCollectionRecordWithPayload(1, _record(CURATOR, data), data);
        _assertRoundTrip(accepted, data);
        require(metadata.payloadPointerCount(1) == 3);
    }

    function testEmptyOversizeAndFalseFullHashLeaveAcceptedInventoryUnchanged() public {
        bytes memory empty;
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.InvalidMetadataRecord.selector)
        );
        metadata.prepareRecordPayload(empty);
        bytes memory data = _body(24577);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.InvalidMetadataRecord.selector)
        );
        metadata.prepareRecordPayload(data);
        IStreamPreservationRecords.CollectionRecord memory r = _record(CURATOR, data);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.InvalidMetadataRecord.selector)
        );
        metadata.recordCollectionRecordWithPayload(1, r, data);
        data = _body(8193);
        r = _record(CURATOR, data);
        r.contentHash.digest = abi.encode(bytes32(uint256(123)));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.InvalidMetadataRecord.selector)
        );
        metadata.recordCollectionRecordWithPayload(1, r, data);
        require(metadata.payloadPointerCount(1) == 0);
        (, uint64 count) = metadata.recordChainHash(1, CURATOR);
        require(count == 0);
    }

    function testCandidateMissingPreparedAndCorruptCarriersNeverFallback() public {
        bytes memory data = _body(8193);
        IStreamPreservationRecords.CollectionRecord memory r = _record(ARTIST, data);
        r.schemaId = keccak256("STREAM_ARTIST_INTERVIEW_V1");
        P.Publication memory p = _publication(address(this), r);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionMetadataV1.MetadataReadFailed.selector, address(store)
            )
        );
        metadata.requireArtistRecordCandidate(p);
        metadata.prepareRecordPayload(data);
        (bytes32 candidate, uint8 kind) = metadata.requireArtistRecordCandidate(p);
        require(candidate == p.candidateRecordHash && kind == 8, "exact original candidate");
        (address pointer,) = metadata.preparedRecordPayloadChunkAt(keccak256(data), 1);
        bytes memory original = pointer.code;
        vm.etch(pointer, hex"00");
        vm.expectRevert(abi.encodeWithSelector(PayloadBytes.SnapshotChunkChanged.selector, pointer));
        metadata.requireArtistRecordCandidate(p);
        vm.expectRevert(abi.encodeWithSelector(PayloadBytes.SnapshotChunkChanged.selector, pointer));
        metadata.prepareRecordPayload(data);
        vm.etch(pointer, original);
        (candidate,) = metadata.requireArtistRecordCandidate(p);
        require(candidate == p.candidateRecordHash);
        require(metadata.payloadPointerCount(1) == 0, "candidate and repair did not publish");
    }

    function testLargeHistoricalBytesSurviveStoreDriftAndChunkBoundsFail() public {
        bytes memory data = _body(24576);
        bytes32 hash = metadata.recordCollectionRecordWithPayload(1, _record(CURATOR, data), data);
        vm.etch(address(store), hex"00");
        _assertRoundTrip(hash, data);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.InvalidMetadataRecord.selector)
        );
        metadata.recordPayloadChunkAt(hash, 3);
    }

    function testIdenticalSignedSafeRetryRollsBackSecondChunkFailure() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 1801;
        keys[1] = 1802;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 2801);
        _grant(1, StreamRecordFamilies.CURATOR, 3, address(safe), true);
        bytes memory data = _body(8193);
        IStreamPreservationRecords.CollectionRecord memory r = _record(CURATOR, data);
        bytes memory callData =
            abi.encodeCall(metadata.recordCollectionRecordWithPayload, (1, r, data));
        bytes32 digest = safe.getTransactionHash(
            address(metadata), 0, callData, 0, 0, 0, 0, address(0), address(0), safe.nonce()
        );
        bytes memory signatures = safeThresholdSignature(keys, digest);
        bytes memory transaction = abi.encodeCall(
            safe.execTransaction,
            (
                address(metadata),
                0,
                callData,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signatures
            )
        );
        bytes memory tail = _piece(data, 8192, 1);
        PayloadCapacityVm(address(vm))
            .mockCall(
                address(store),
                abi.encodeCall(store.publishChunk, (tail)),
                abi.encode(keccak256(tail), address(0xbeef))
            );
        (bool ok,) = address(safe).call(transaction);
        require(!ok && safe.nonce() == 0, "failed original Safe transaction");
        require(
            metadata.payloadPointerCount(1) == 0
                && metadata.preparedRecordPayloadChunkCount(keccak256(data)) == 0
        );
        (, uint64 count) = metadata.recordChainHash(1, CURATOR);
        require(count == 0);
        (address absent,) = store.chunk(keccak256(_piece(data, 0, 8192)));
        require(absent == address(0), "first actual CREATE rolled back");
        PayloadCapacityVm(address(vm)).clearMockedCalls();
        (ok,) = address(safe).call(transaction);
        require(ok && safe.nonce() == 1, "identical saved signature succeeds");
        bytes32 hash = metadata.latestCollectionRecordHashFor(1, CURATOR, subject, address(safe));
        require(hash == _oldRecordHash(address(safe), r));
        _assertRoundTrip(hash, data);
    }

    function testFuzzFullPayloadOriginalHashRoundTrip(uint16 seed) public {
        bytes memory data = _body(uint256(seed) % 24576 + 1);
        IStreamPreservationRecords.CollectionRecord memory r = _record(CURATOR, data);
        bytes32 hash = metadata.recordCollectionRecordWithPayload(1, r, data);
        require(hash == _oldRecordHash(address(this), r));
        _assertRoundTrip(hash, data);
    }
}
