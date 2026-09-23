// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { CollectionMetadataV1Fixture } from "../metadata/StreamCollectionMetadataV1.t.sol";
import {
    StreamPreservationRecordsV1
} from "../../../smart-contracts/domains/preservation/StreamPreservationRecordsV1.sol";
import {
    IStreamPreservationRecordsV1 as V
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamPreservationRecordsV1.sol";
import {
    IStreamPreservationRecords as R
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    StreamRecordFamilies as Families
} from "../../../smart-contracts/domains/records/StreamRecordFamilies.sol";
import {
    StreamSnapshotManifestBytes as Bytes
} from "../../../smart-contracts/domains/records/StreamSnapshotManifestBytes.sol";
import {
    IStreamGasParameterHost
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    IStreamCollectionMetadataV1 as Metadata
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamSchemaRegistry
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import { OfficialSafe } from "../../helpers/OfficialSafeFixture.sol";

interface PreservationFailureVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
}

contract PreservationRegistryBoundary {
    address public host;
    address public metadata;
    bool public hostEnabled = true;
    bool public metadataEnabled = true;

    constructor(address h, address m) {
        host = h;
        metadata = m;
    }

    function set(bool h, bool m) external {
        hostEnabled = h;
        metadataEnabled = m;
    }

    function isModuleEligible(address target, bytes32 kind, bytes4 id)
        external
        view
        returns (bool)
    {
        if (target == host) {
            return hostEnabled && kind == keccak256("PRESERVATION_RECORDS")
                && id == type(V).interfaceId;
        }
        return target == metadata && metadataEnabled && kind == keccak256("COLLECTION_METADATA")
            && id == type(Metadata).interfaceId;
    }
}

/// @notice Actual Metadata/Schema/Store/payload host and 2-of-2 upstream Safe.
/// @dev Core, Artist, registry selection and Executor are explicit typed boundaries; full genesis is separate.
contract StreamPreservationRecordsV1Test is CollectionMetadataV1Fixture {
    StreamPreservationRecordsV1 private preservation;
    PreservationRegistryBoundary private registry;
    bytes32 private constant ARCHIVE = keccak256("ARCHIVE_FIXTURE");

    function _newHost() private {
        StreamPreservationRecordsV1.Configuration memory c;
        c.core = address(core);
        c.metadata = address(metadata);
        c.executor = address(executor);
        c.deploymentManifestHash = keccak256("preservation fixture deployment");
        c.manifestHash = keccak256("preservation fixture manifest");
        c.manifestURI = "ipfs://preservation";
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        preservation = new StreamPreservationRecordsV1(c);
        registry = new PreservationRegistryBoundary(address(preservation), address(metadata));
        core.setPointer(keccak256("MODULE_REGISTRY"), address(registry));
        _admit(ARCHIVE, Families.ARCHIVE, uint16(1) << 6);
        _grant(1, Families.ARCHIVE, 6, address(this), true);
    }

    function _payload(uint256 length) private pure returns (bytes memory p) {
        p = new bytes(length);
        for (uint256 i; i < length; ++i) {
            p[i] = bytes1(uint8(i * 37 + i / 8192));
        }
    }

    function _literal(address recorder, R.CollectionRecord memory r)
        private
        view
        returns (bytes32)
    {
        bytes32[14] memory w;
        w[0] = keccak256("6529stream.preservation-record.v2");
        w[1] = bytes32(block.chainid);
        w[2] = bytes32(uint256(uint160(address(preservation))));
        w[3] = bytes32(uint256(uint160(address(core))));
        w[4] = bytes32(uint256(uint160(recorder)));
        w[5] = bytes32(uint256(1));
        w[6] = r.recordType;
        w[7] = r.subjectId;
        w[8] = keccak256(
            abi.encode(
                r.contentHash.algorithm,
                keccak256(r.contentHash.digest),
                r.contentHash.canonicalizationId
            )
        );
        w[9] = keccak256(bytes(r.uri));
        w[10] = r.schemaId;
        w[11] = r.signatureScheme;
        w[12] = keccak256(
            abi.encode(
                r.signatureHash.algorithm,
                keccak256(r.signatureHash.digest),
                r.signatureHash.canonicalizationId
            )
        );
        w[13] = bytes32(uint256(r.effectiveAt));
        return keccak256(abi.encode(w));
    }

    function testFull24576BytesOriginalHashChainAndStateOnlyPointers() public {
        _newHost();
        bytes memory data = _payload(24576);
        R.CollectionRecord memory r = _record(ARCHIVE, data);
        bytes32 hash = preservation.recordCollectionRecordWithPayload(1, r, data);
        require(hash == _literal(address(this), r), "original fourteen words/host");
        (R.CollectionRecord memory saved, V.Receipt memory receipt) =
            preservation.collectionRecord(hash);
        require(keccak256(abi.encode(saved)) == keccak256(abi.encode(r)), "complete original tuple");
        require(
            receipt.recorder == address(this) && receipt.authorizationClass == 6
                && receipt.grantCollectionId == 1 && receipt.grantRevision == 1,
            "actual original authority"
        );
        bytes32 chain = keccak256(
            abi.encode(
                keccak256("6529STREAM_RECORD_CHAIN_V1"),
                block.chainid,
                address(preservation),
                uint256(1),
                ARCHIVE,
                bytes32(0),
                hash,
                uint64(0)
            )
        );
        (bytes32 actual, uint64 count) = preservation.recordChainHash(1, ARCHIVE);
        require(
            actual == chain && count == 1 && receipt.recordChainHash == chain
                && preservation.recordHashAt(1, ARCHIVE, 0) == hash,
            "original lane domain"
        );
        (address first, bytes memory recovered) = preservation.recordPayload(hash);
        require(
            keccak256(recovered) == keccak256(data) && recovered.length == 24576
                && first != address(0)
        );
        require(
            preservation.recordPayloadChunkCount(hash) == 3
                && preservation.payloadPointerCount(1) == 3
        );
        bytes memory reconstructed;
        for (uint256 i; i < 3; ++i) {
            (address pointer, bytes32 chunkHash) = preservation.recordPayloadChunkAt(hash, i);
            (address indexedPointer, bytes32 family, bytes32 indexedHash) =
                preservation.payloadPointerAt(1, i);
            require(
                pointer == indexedPointer && family == Families.ARCHIVE && chunkHash == indexedHash
            );
            bytes memory part = new bytes(8192);
            assembly ("memory-safe") { extcodecopy(pointer, add(part, 32), 1, 8192) }
            require(keccak256(part) == chunkHash);
            reconstructed = bytes.concat(reconstructed, part);
        }
        require(keccak256(reconstructed) == keccak256(data), "no event or live Store read needed");
    }

    function testBoundsDigestSignatureAndUnregisteredSchemaFailWithoutRows() public {
        _newHost();
        bytes memory data = _payload(24577);
        R.CollectionRecord memory r = _record(ARCHIVE, data);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidPreservationRecord.selector));
        preservation.recordCollectionRecordWithPayload(1, r, data);
        data = bytes("payload");
        r = _record(ARCHIVE, data);
        r.contentHash.digest = abi.encode(bytes32(uint256(1)));
        vm.expectRevert(abi.encodeWithSelector(V.InvalidPreservationRecord.selector));
        preservation.recordCollectionRecordWithPayload(1, r, data);
        r = _record(ARCHIVE, data);
        r.signatureScheme = keccak256("not a verified signature");
        vm.expectRevert(abi.encodeWithSelector(V.InvalidPreservationRecord.selector));
        preservation.recordCollectionRecordWithPayload(1, r, data);
        r = _record(ARCHIVE, data);
        r.schemaId = keccak256("absent");
        vm.expectRevert();
        preservation.recordCollectionRecordWithPayload(1, r, data);
        require(preservation.payloadPointerCount(1) == 0);
    }

    function testCatalogFamilyAndExactGrantScopeCannotBeBypassed() public {
        _newHost();
        bytes memory data = bytes("payload");
        R.CollectionRecord memory r = _record(ARCHIVE, data);
        _grant(1, Families.ARCHIVE, 6, address(this), false);
        _grant(2, Families.ARCHIVE, 6, address(this), true);
        vm.expectRevert(abi.encodeWithSelector(V.PreservationAuthorityRequired.selector));
        preservation.recordCollectionRecordWithPayload(1, r, data);
        _grant(0, Families.ARCHIVE, 6, address(this), true);
        bytes32 h = preservation.recordCollectionRecordWithPayload(1, r, data);
        (, V.Receipt memory receipt) = preservation.collectionRecord(h);
        require(receipt.grantCollectionId == 0 && receipt.authorizationClass == 6);
        r = _record(RIGHTS, data);
        _grant(1, Families.RIGHTS, 7, address(this), true);
        vm.expectRevert(abi.encodeWithSelector(V.PreservationAuthorityRequired.selector));
        preservation.recordCollectionRecordWithPayload(1, r, data);
        r = _record(ARTIST, data);
        vm.expectRevert(abi.encodeWithSelector(V.PreservationAuthorityRequired.selector));
        preservation.recordCollectionRecordWithPayload(1, r, data);
    }

    function testTokenAndMediaSubjectsCanonicalAndPreparedRefused() public {
        _newHost();
        core.setToken(7, address(this), 1);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidPreservationRecord.selector));
        preservation.registerTokenSubject(7);
        core.setToken(7, address(this), 2);
        bytes32 token = preservation.registerTokenSubject(7);
        require(
            token
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SUBJECT_TOKEN_V1"),
                        block.chainid,
                        address(core),
                        uint256(7)
                    )
                )
        );
        bytes memory data = bytes("token");
        R.CollectionRecord memory r = _record(ARCHIVE, data);
        r.subjectId = token;
        preservation.recordCollectionRecordWithPayload(1, r, data);
        core.setToken(7, address(0), 3);
        require(preservation.registerTokenSubject(7) == token, "burn retains original identity");
        bytes32 media = preservation.registerMediaSubject(1, keccak256("object"));
        require(
            media
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SUBJECT_MEDIA_V1"),
                        block.chainid,
                        address(core),
                        uint256(1),
                        keccak256("object")
                    )
                )
        );
        r.subjectId = media;
        preservation.recordCollectionRecordWithPayload(1, r, data);
        r.subjectId = preservation.registerMediaSubject(2, keccak256("object"));
        vm.expectRevert(abi.encodeWithSelector(V.UnknownPreservationSubject.selector, r.subjectId));
        preservation.recordCollectionRecordWithPayload(1, r, data);
    }

    function testHistoricalBytesSurviveSelectionSchemaAndStoreDrift() public {
        _newHost();
        bytes memory data = _payload(8193);
        R.CollectionRecord memory r = _record(ARCHIVE, data);
        bytes32 hash = preservation.recordCollectionRecordWithPayload(1, r, data);
        (bytes32 s, bytes32 o, bytes32 n) =
            schemas.statusTransition(schemaId, IStreamSchemaRegistry.DocumentStatus.ARCHIVED);
        executor.execute(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus, (schemaId, IStreamSchemaRegistry.DocumentStatus.ARCHIVED)
            ),
            s,
            o,
            n
        );
        core.setPointer(keccak256("COLLECTION_METADATA"), address(0));
        vm.etch(address(store), hex"00");
        (, bytes memory readback) = preservation.recordPayload(hash);
        require(keccak256(readback) == keccak256(data));
        r.effectiveAt = 2;
        vm.expectRevert(abi.encodeWithSelector(V.PreservationHostNotSelected.selector));
        preservation.recordCollectionRecordWithPayload(1, r, data);
    }

    function testAdmissionRejectsUnselectedMetadataAndRetiredEitherHost() public {
        _newHost();
        bytes memory data = bytes("payload");
        R.CollectionRecord memory r = _record(ARCHIVE, data);
        registry.set(false, true);
        vm.expectRevert(abi.encodeWithSelector(V.PreservationHostNotSelected.selector));
        preservation.recordCollectionRecordWithPayload(1, r, data);
        registry.set(true, false);
        vm.expectRevert(abi.encodeWithSelector(V.PreservationHostNotSelected.selector));
        preservation.recordCollectionRecordWithPayload(1, r, data);
        registry.set(true, true);
        core.setPointer(keccak256("COLLECTION_METADATA"), address(0));
        vm.expectRevert(abi.encodeWithSelector(V.PreservationHostNotSelected.selector));
        preservation.recordCollectionRecordWithPayload(1, r, data);
    }

    function testPerRecorderHeadsReplayAndAcceptedPointerDedup() public {
        _newHost();
        bytes memory data = bytes("same bytes");
        R.CollectionRecord memory r = _record(ARCHIVE, data);
        bytes32 first = preservation.recordCollectionRecordWithPayload(1, r, data);
        vm.expectRevert(abi.encodeWithSelector(V.DuplicatePreservationRecord.selector, first));
        preservation.recordCollectionRecordWithPayload(1, r, data);
        address other = address(0xbeef);
        _grant(1, Families.ARCHIVE, 6, other, true);
        vm.prank(other);
        bytes32 second = preservation.recordCollectionRecordWithPayload(1, r, data);
        require(
            first != second
                && preservation.latestCollectionRecordHashFor(1, ARCHIVE, subject, address(this))
                    == first
                && preservation.latestCollectionRecordHashFor(1, ARCHIVE, subject, other) == second
        );
        require(preservation.payloadPointerCount(1) == 1);
        (, uint64 count) = preservation.recordChainHash(1, ARCHIVE);
        require(count == 2);
    }

    function testSafeIdenticalSignedRetryAfterSecondChunkFailureRollsBackAllWrites() public {
        _newHost();
        uint256[] memory keys = new uint256[](2);
        keys[0] = 1701;
        keys[1] = 1702;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 2701);
        _grant(1, Families.ARCHIVE, 6, address(safe), true);
        bytes memory data = _payload(8193);
        R.CollectionRecord memory r = _record(ARCHIVE, data);
        bytes memory callData =
            abi.encodeCall(preservation.recordCollectionRecordWithPayload, (1, r, data));
        bytes32 digest = safe.getTransactionHash(
            address(preservation), 0, callData, 0, 0, 0, 0, address(0), address(0), safe.nonce()
        );
        bytes memory signature = safeThresholdSignature(keys, digest);
        bytes memory transaction = abi.encodeCall(
            safe.execTransaction,
            (
                address(preservation),
                0,
                callData,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signature
            )
        );
        bytes memory tail = new bytes(1);
        tail[0] = data[8192];
        PreservationFailureVm(address(vm))
            .mockCall(
                address(store),
                abi.encodeCall(store.publishChunk, (tail)),
                abi.encode(keccak256(tail), address(0xbeef))
            );
        (bool ok,) = address(safe).call(transaction);
        require(!ok && safe.nonce() == 0, "original Safe failure and nonce rollback");
        require(preservation.payloadPointerCount(1) == 0);
        (, uint64 count) = preservation.recordChainHash(1, ARCHIVE);
        require(count == 0);
        bytes memory first = new bytes(8192);
        for (uint256 i; i < 8192; ++i) {
            first[i] = data[i];
        }
        (address absent,) = store.chunk(keccak256(first));
        require(absent == address(0), "first actual chunk creation rolled back");
        PreservationFailureVm(address(vm)).clearMockedCalls();
        (ok,) = address(safe).call(transaction);
        require(ok && safe.nonce() == 1, "same signed transaction succeeds");
        bytes32 hash =
            preservation.latestCollectionRecordHashFor(1, ARCHIVE, subject, address(safe));
        (, V.Receipt memory receipt) = preservation.collectionRecord(hash);
        require(receipt.recorder == address(safe) && receipt.authorizationClass == 6);
        (, bytes memory recovered) = preservation.recordPayload(hash);
        require(keccak256(recovered) == keccak256(data));
    }

    function testFuzzFullPayloadRoundTrip(uint16 seed) public {
        _newHost();
        uint256 length = uint256(seed) % 24576 + 1;
        bytes memory data = _payload(length);
        bytes32 hash =
            preservation.recordCollectionRecordWithPayload(1, _record(ARCHIVE, data), data);
        (, bytes memory recovered) = preservation.recordPayload(hash);
        require(recovered.length == length && keccak256(recovered) == keccak256(data));
    }
}
