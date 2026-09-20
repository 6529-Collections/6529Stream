// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistPublicationHydrationFixture.sol";
import {
    StreamArtistRecordPublicationReads
} from "../../../smart-contracts/domains/artist/StreamArtistRecordPublicationReads.sol";
import {
    StreamSnapshotManifestBytes as PayloadBytes
} from "../../../smart-contracts/domains/records/StreamSnapshotManifestBytes.sol";
import {
    StreamMetadataRecordPayloads
} from "../../../smart-contracts/domains/metadata/StreamMetadataRecordPayloads.sol";

interface ArtistPayloadCapacityVm {
    function cool(address) external;
}

contract ArtistPayloadCapacityCandidate {
    function read(T.SuiteConfiguration memory suite_, P.Publication memory p)
        external
        view
        returns (bytes32)
    {
        return StreamArtistRecordPublicationReads.candidate(suite_, p);
    }
}

/// @notice Actual original Artist facade/owners/Archive, Metadata/Schema/Store and threshold Safe.
/// @dev Core/governance/router remain the original explicit typed fixture boundaries. No cutover,
/// mocked permit, replacement signature domain or production Artist mutation is introduced.
contract StreamArtistRecordPayloadCapacityTest is ArtistPublicationHydrationFixture {
    function _source()
        internal
        returns (ArtistCanonicalPublicationFixture f, StreamCollectionMetadataV1 host)
    {
        actualSaleRegistryFixture = true;
        setUp();
        _compactSource();
        _economicHistory();
        _recordRatification();
        f = new ArtistCanonicalPublicationFixture();
        f.deploy(address(core), address(ingress));
        host = f.metadata();
        _saleRegister(
            saleModules,
            factory.governanceAuthority(),
            address(host),
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId
        );
        core.set(keccak256("COLLECTION_METADATA"), address(host), false);
    }

    function _body(uint256 length) internal pure returns (bytes memory data) {
        data = new bytes(length);
        for (uint256 i; i < length; ++i) {
            data[i] = bytes1(uint8(1 + (i * 17 + i / 8192) % 251));
        }
    }

    function _terms(
        ArtistCanonicalPublicationFixture f,
        StreamCollectionMetadataV1 host,
        bytes memory data
    )
        internal
        view
        returns (IStreamPreservationRecords.CollectionRecord memory r, P.Publication memory p)
    {
        r.recordType = keccak256("ARTIST_STATEMENT");
        r.subjectId = StreamMetadataSubjects.scopeSubject(
            block.chainid,
            address(core),
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
        );
        r.schemaId = keccak256("STREAM_ARTIST_INTERVIEW_V1");
        r.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encode(keccak256(data)), f.schemas().RAW_BYTES()
        );
        r.uri = "urn:actual-artist:full-payload";
        r.effectiveAt = uint64(block.timestamp);
        p = P.Publication(
            address(host),
            address(artist),
            1,
            r.subjectId,
            r.recordType,
            r.schemaId,
            r.contentHash.canonicalizationId,
            1,
            keccak256(data),
            keccak256(bytes(r.uri)),
            r.effectiveAt,
            bytes32(0)
        );
        p.candidateRecordHash = _canonicalRecordHash(r, p);
        require(
            p.candidateRecordHash == host.deriveCollectionRecordHashFor(address(artist), 1, r),
            "literal original14word domain"
        );
    }

    function _approve(P.Publication memory p, string memory uri) internal returns (bytes32 record) {
        (T.Attestation memory a, bytes memory statement) = _canonicalAttestation(p, uri);
        record = _recordPublication(p, a, statement);
        P.Evidence memory e = ingress.requireRecordPublication(record, p);
        require(
            e.signer == address(artist) && e.authorityClass == 1
                && e.publicationHash == keccak256(abi.encode(p)),
            "original actual op24 evidence"
        );
    }

    function _coldCandidate(
        ArtistCanonicalPublicationFixture f,
        StreamCollectionMetadataV1 host,
        P.Publication memory p
    ) internal {
        ArtistPayloadCapacityCandidate probe = new ArtistPayloadCapacityCandidate();
        uint256 count = host.preparedRecordPayloadChunkCount(p.payloadHash);
        address[] memory pointers = new address[](count);
        for (uint256 i; i < count; ++i) {
            (pointers[i],) = host.preparedRecordPayloadChunkAt(p.payloadHash, i);
        }
        ArtistPayloadCapacityVm cvm = ArtistPayloadCapacityVm(address(vm));
        for (uint256 i; i < count; ++i) {
            cvm.cool(pointers[i]);
        }
        cvm.cool(address(host));
        cvm.cool(address(f.schemas()));
        cvm.cool(address(f.store()));
        cvm.cool(address(StreamMetadataRecordPayloads));
        cvm.cool(address(PayloadBytes));
        cvm.cool(address(StreamMetadataPublicationEncoding));
        cvm.cool(address(StreamRecordDocumentReads));
        cvm.cool(address(StreamCollectionRecordHashes));
        cvm.cool(address(StreamArtistRecordPublicationReads));
        require(
            probe.read(suite, p) == address(host).codehash, "original bounded actual Artist reader"
        );
    }

    function _publishBoundary(uint256 length) internal {
        (ArtistCanonicalPublicationFixture f, StreamCollectionMetadataV1 host) = _source();
        bytes memory data = _body(length);
        (IStreamPreservationRecords.CollectionRecord memory r, P.Publication memory p) =
            _terms(f, host, data);
        host.prepareRecordPayload(data);
        require(host.payloadPointerCount(1) == 0, "no admission from preparation");
        _coldCandidate(f, host, p);
        bytes32 approval = _approve(p, r.uri);
        require(!host.consumedArtistAuthorization(approval));
        require(
            this.executeTargetSafe(
                address(host),
                abi.encodeCall(
                    host.recordArtistCollectionRecordWithPayload,
                    (address(artist), 1, r, data, approval)
                )
            ),
            "actual Safe publishes exact approved bytes"
        );
        require(host.consumedArtistAuthorization(approval));
        (
            IStreamPreservationRecords.CollectionRecord memory saved,
            IStreamCollectionMetadataV1.RecordReceipt memory receipt
        ) = host.collectionRecord(p.candidateRecordHash);
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(r))
                && receipt.recorder == address(artist) && receipt.authorizationClass == 1,
            "unchanged original record/authority"
        );
        (, bytes memory restored) = host.recordPayload(p.candidateRecordHash);
        require(restored.length == length && keccak256(restored) == p.payloadHash);
        require(host.recordPayloadChunkCount(p.candidateRecordHash) == (length + 8191) / 8192);
    }

    function testActualArtistOriginalCandidate8192() external {
        _publishBoundary(8192);
    }

    function testActualArtistPreparedCandidate8193() external {
        _publishBoundary(8193);
    }

    function testActualArtistPreparedCandidate24576() external {
        _publishBoundary(24576);
    }

    function testActualArtistOversizeNeverCreatesCandidateOrConsumesAuthorization() external {
        (ArtistCanonicalPublicationFixture f, StreamCollectionMetadataV1 host) = _source();
        bytes memory data = _body(24577);
        (, P.Publication memory p) = _terms(f, host, data);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.InvalidMetadataRecord.selector)
        );
        host.prepareRecordPayload(data);
        (bool ok,) =
            address(host).staticcall(abi.encodeCall(host.requireArtistRecordCandidate, (p)));
        require(!ok, "no oversized candidate");
        require(
            host.preparedRecordPayloadChunkCount(p.payloadHash) == 0
                && host.payloadPointerCount(1) == 0
        );
        (, uint64 count) = host.recordChainHash(1, p.recordType);
        require(count == 0);
    }

    function testActualArtistSafeSavedRetryOnCorruptPreparedChunkPreservesOriginalApproval()
        external
    {
        (ArtistCanonicalPublicationFixture f, StreamCollectionMetadataV1 host) = _source();
        bytes memory data = _body(8193);
        (IStreamPreservationRecords.CollectionRecord memory r, P.Publication memory p) =
            _terms(f, host, data);
        host.prepareRecordPayload(data);
        bytes32 approval = _approve(p, r.uri);
        bytes memory callData = abi.encodeCall(
            host.recordArtistCollectionRecordWithPayload, (address(artist), 1, r, data, approval)
        );
        uint256 nonce = artist.nonce();
        bytes32 digest = artist.getTransactionHash(
            address(host), 0, callData, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory signature = safeThresholdSignature(keys, digest);
        bytes memory transaction = abi.encodeCall(
            artist.execTransaction,
            (address(host), 0, callData, 0, 0, 0, 0, address(0), payable(address(0)), signature)
        );
        (address pointer,) = host.preparedRecordPayloadChunkAt(p.payloadHash, 1);
        bytes memory original = pointer.code;
        vm.etch(pointer, hex"00");
        (bool ok,) = address(artist).call(transaction);
        require(
            !ok && artist.nonce() == nonce && !host.consumedArtistAuthorization(approval),
            "original signed Safe failure rolls back"
        );
        require(host.payloadPointerCount(1) == 0);
        (, uint64 count) = host.recordChainHash(1, r.recordType);
        require(count == 0);
        vm.etch(pointer, original);
        (ok,) = address(artist).call(transaction);
        require(
            ok && artist.nonce() == nonce + 1 && host.consumedArtistAuthorization(approval),
            "identical signed retry"
        );
        P.Evidence memory evidence = ingress.requireRecordPublication(approval, p);
        require(
            evidence.publicationHash == keccak256(abi.encode(p)),
            "original op24 association retained"
        );
        (, bytes memory restored) = host.recordPayload(p.candidateRecordHash);
        require(keccak256(restored) == p.payloadHash);
    }
}
