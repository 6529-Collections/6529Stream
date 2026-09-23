// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceModePayloadPreparation as Preparation
} from "../../../smart-contracts/domains/preservation/StreamReferenceModePayloadPreparation.sol";
import {
    StreamReferenceModePayloadEncoding as Encoding
} from "../../../smart-contracts/domains/preservation/StreamReferenceModePayloadEncoding.sol";
import {
    StreamReferenceRenderPreparation as Environment
} from "../../../smart-contracts/domains/preservation/StreamReferenceRenderPreparation.sol";
import {
    StreamReferenceInventoryPreparation as Parts
} from "../../../smart-contracts/domains/preservation/StreamReferenceInventoryPreparation.sol";
import {
    StreamReferenceEnvironmentJson as Json
} from "../../../smart-contracts/domains/records/StreamReferenceEnvironmentJson.sol";
import {
    StreamSchemaDocumentStore as Store
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    StreamSnapshotManifestBytes as Bytes
} from "../../../smart-contracts/domains/records/StreamSnapshotManifestBytes.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamReferenceModeTypes as M
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceModeTypes.sol";
import {
    IStreamReferenceModePayloadPreparation as P
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamReferenceModePayloadPreparation.sol";
import { ReferenceModeOriginalEncoding as Original } from "./ReferenceModeOriginalEncoding.sol";
import {
    StreamReferenceModeStateReads as StateReads
} from "../../../smart-contracts/domains/preservation/StreamReferenceModeStateReads.sol";

import {
    IStreamReferenceModePublication
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamReferenceModePublication.sol";

interface PayloadPreparationVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function readFile(string calldata) external view returns (string memory);
    function parseJsonBytes(string calldata, string calldata) external pure returns (bytes memory);
    function parseJsonString(string calldata, string calldata) external pure returns (string memory);
    function cool(address) external;
    function chainId(uint256) external;
    function etch(address, bytes calldata) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

/// @dev Real fixed workers and Store with exact compiler-owned roots. This is the bounded stage
/// viability host; current writer/source/real publication acceptance is tested separately.
contract ModePayloadPreparationHost {
    mapping(bytes32 => Bytes.Manifest) private inventories;
    Preparation.State private prepared;
    Bytes.Manifest private adoptedPayload;
    Bytes.Manifest private adoptedPublication;
    address public immutable store;
    bytes32 private immutable storeHash;
    bool private entered;
    mapping(bytes32 => Preparation.Binding) private bindings;
    mapping(bytes32 => Bytes.Manifest) private legacyPayloads;
    mapping(bytes32 => Bytes.Manifest) private legacyPublications;
    mapping(bytes32 => bool) private known;
    bool public failAfterBinding;

    constructor(address s) {
        store = s;
        storeHash = s.codehash;
    }
    modifier guarded() {
        require(!entered);
        entered = true;
        _;
        entered = false;
    }

    function prepareFileInventoryPart(R.PackageFile[] calldata, bool)
        external
        guarded
        returns (bytes32)
    {
        return Parts.preparePart(inventories, store, storeHash, msg.data);
    }

    function prepareFileInventoryFromParts(R.PackageFile[] calldata, bool)
        external
        guarded
        returns (bytes32)
    {
        return Parts.assemble(inventories, store, storeHash, msg.data);
    }

    function prepareEnvironment(R.Environment calldata) external guarded returns (bytes32) {
        return Environment.prepareEnvironment(inventories, store, storeHash, msg.data);
    }

    function prepareModePublication(R.Publication calldata) external guarded returns (bytes32) {
        return Preparation.preparePublication(prepared, inventories, store, storeHash, msg.data);
    }

    function prepareModePayload(
        bytes32,
        R.Receipt calldata,
        R.SourceFacts calldata,
        M.Evidence calldata,
        M.Facts calldata
    ) external guarded returns (bytes32) {
        return Preparation.preparePayload(prepared, inventories, store, storeHash, msg.data);
    }

    function preparedModePublication(bytes32 id)
        external
        view
        returns (P.PublicationDescriptor memory, bytes memory)
    {
        bytes memory raw = Preparation.publicationEncoded(prepared, id);
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }

    function preparedModePayload(bytes32 id) external view returns (bytes memory) {
        return Preparation.payload(prepared, id);
    }

    function lookup(
        R.Publication memory p,
        R.Receipt memory r,
        R.SourceFacts memory s,
        M.Evidence memory e,
        M.Facts memory f
    ) external view returns (bytes memory) {
        bytes memory raw = abi.encode(p);
        return
            Preparation.lookup(
                prepared, inventories, keccak256(raw), uint32(raw.length), r, s, e, f
            );
    }

    function publicationState(bytes32 id) external view returns (bytes32, uint32, uint256) {
        Bytes.Manifest storage m = prepared.publications[id].canonical;
        return (m.contentHash, m.byteLength, m.pointers.length);
    }

    function payloadState(bytes32 id) external view returns (bytes32, uint32, uint256) {
        Bytes.Manifest storage m = prepared.payloads[id];
        return (m.contentHash, m.byteLength, m.pointers.length);
    }

    /// @dev Test-only state host: no writer/source authority is claimed by this bounded worker recipe.
    function adoptByInput(
        R.Publication memory p,
        R.Receipt memory r,
        R.SourceFacts memory s,
        M.Evidence memory e,
        M.Facts memory f
    ) external guarded returns (bytes32) {
        bytes memory raw = abi.encode(p);
        Preparation.Selection memory selected =
            Preparation.selectForWrite(prepared, keccak256(raw), uint32(raw.length), r, s, e, f);
        require(selected.payloadId != 0, "no exact validated-input descriptor");
        Preparation.adopt(
            prepared, inventories, adoptedPayload, adoptedPublication, store, storeHash, selected
        );
        return selected.payloadHash;
    }

    function adoptedBytes() external view returns (bytes memory, bytes memory) {
        return (Bytes.read(adoptedPayload), Bytes.read(adoptedPublication));
    }

    function adoptedState() external view returns (bytes32, uint32, uint256, bytes32) {
        return (
            adoptedPayload.contentHash,
            adoptedPayload.byteLength,
            adoptedPayload.pointers.length,
            adoptedPublication.contentHash
        );
    }

    function bindByInput(
        bytes32 record,
        R.Publication memory p,
        R.Receipt memory r,
        R.SourceFacts memory s,
        M.Evidence memory e,
        M.Facts memory f
    ) external guarded returns (bytes32) {
        require(!known[record], "known record");
        bytes memory raw = abi.encode(p);
        Preparation.Selection memory selected =
            Preparation.selectForWrite(prepared, keccak256(raw), uint32(raw.length), r, s, e, f);
        require(selected.payloadId != 0, "no exact validated-input descriptor");
        Preparation.bind(
            prepared,
            inventories,
            bindings[record],
            legacyPayloads[record],
            legacyPublications[record],
            store,
            storeHash,
            selected
        );
        require(!failAfterBinding, "late transition failure");
        known[record] = true;
        return selected.payloadHash;
    }

    function hashOriginalRecord(R.Publication memory p, R.Receipt memory r, M.Evidence memory e)
        external
        view
        returns (bytes32)
    {
        bytes memory original = abi.encodeWithSelector(
            IStreamReferenceModePublication.publishModeReference.selector, p, e
        );
        return StateReads.recordHash(block.chainid, address(101), address(102), r, original);
    }

    function hashOriginalContext(R.Dependencies memory d, R.Publication memory p)
        external
        view
        returns (bytes32)
    {
        return StateReads.contextHash(
            d, abi.encodeWithSelector(IStreamReferenceModePublication.modeContextHash.selector, p)
        );
    }

    function retainOriginalPublication(bytes32 record, R.Publication memory p, M.Evidence memory e)
        external
    {
        StateReads.retainPublication(
            legacyPublications[record],
            store,
            abi.encodeWithSelector(
                IStreamReferenceModePublication.publishModeReference.selector, p, e
            )
        );
    }

    function readOriginalPublication(bytes32 record) external view returns (bytes memory) {
        return Bytes.read(legacyPublications[record]);
    }

    function setLateBindingFailure(bool value) external {
        failAfterBinding = value;
    }

    function retainLegacy(bytes32 record, bytes memory payload, bytes memory publication) external {
        require(!known[record]);
        Bytes.retain(legacyPayloads[record], store, payload);
        Bytes.retain(legacyPublications[record], store, publication);
        known[record] = true;
    }

    function boundState(bytes32 record) external view returns (bytes32, bytes32, bool) {
        return (bindings[record].publicationId, bindings[record].payloadId, known[record]);
    }

    function boundBytes(bytes32 record) external view returns (bytes memory, bytes memory) {
        require(known[record], "unknown record");
        return (Bytes.read(_payloadForRecord(record)), Bytes.read(_publicationForRecord(record)));
    }

    // The exact two private compiler-typed selectors used by the production publisher.
    function _publicationForRecord(bytes32 hash) private view returns (Bytes.Manifest storage) {
        bytes32 id = _carrierBinding(hash).publicationId;
        if (id == 0) return legacyPublications[hash];
        return prepared.publications[id].canonical;
    }

    function _payloadForRecord(bytes32 hash) private view returns (Bytes.Manifest storage) {
        bytes32 id = _carrierBinding(hash).payloadId;
        if (id == 0) return legacyPayloads[hash];
        return prepared.payloads[id];
    }

    function _carrierBinding(bytes32 hash) private view returns (Preparation.Binding storage b) {
        b = bindings[hash];
        bool absent = b.publicationId == 0;
        if (
            absent != (b.payloadId == 0)
                || (!absent
                    && (legacyPublications[hash].byteLength != 0
                        || legacyPayloads[hash].byteLength != 0))
        ) {
            revert M.InvalidModeEvidence();
        }
    }

    function corruptBinding(
        bytes32 hash,
        bytes32 publicationId,
        bytes32 payloadId,
        uint32 oldLength
    ) external {
        bindings[hash] = Preparation.Binding(publicationId, payloadId);
        legacyPayloads[hash].byteLength = oldLength;
    }

    function swapPreparedChunks(bytes32 id) external {
        Bytes.Manifest storage m = prepared.payloads[id];
        (m.pointers[0], m.pointers[1]) = (m.pointers[1], m.pointers[0]);
        (m.chunkHashes[0], m.chunkHashes[1]) = (m.chunkHashes[1], m.chunkHashes[0]);
    }

    function corruptPayloadHash(bytes32 id, bytes32 value) external {
        prepared.payloads[id].contentHash = value;
    }

    function occupiedPublication(bool occupied) external {
        // Force a late destination guard after payload adoption to observe outer rollback.
        adoptedPublication.byteLength = occupied ? 1 : 0;
    }
}

contract ModePayloadEncodingProbe {
    function original(
        R.Publication memory p,
        R.Receipt memory r,
        R.SourceFacts memory s,
        M.Evidence memory e,
        M.Facts memory f,
        bytes memory environment
    ) external pure returns (bytes memory) {
        return Original.payload(p, r, s, e, f, environment);
    }

    function assembled(
        R.Publication memory p,
        R.Receipt memory r,
        R.SourceFacts memory s,
        M.Evidence memory e,
        M.Facts memory f,
        bytes memory environment
    ) external pure returns (bytes memory) {
        Encoding.normalize(r);
        bytes[5] memory tails =
            [abi.encode(p), abi.encode(s), abi.encode(e), abi.encode(f), abi.encode(environment)];
        return Encoding.assemble(abi.encode(r), tails);
    }
}

contract StreamReferenceModePayloadPreparationTest {
    PayloadPreparationVm private constant vm =
        PayloadPreparationVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private constant CAP = 16777216;
    Store private store;
    ModePayloadPreparationHost private host;
    ModePayloadEncodingProbe private encoding;
    uint256 private originalChain;
    event log_named_uint(string label, uint256 value);

    function setUp() public {
        originalChain = block.chainid;
        store = new Store();
        host = new ModePayloadPreparationHost(address(store));
        encoding = new ModePayloadEncodingProbe();
    }

    function _environment(bool corpus) private view returns (R.Environment memory e) {
        e.objectHash = bytes32(uint256(1));
        e.coverageHash = bytes32(uint256(2));
        e.engineName = "Google Chrome";
        e.engineVersion = "152.0.7977.83";
        e.engineExecutablePath = "engine/chrome.exe";
        e.toolchainName = "reference_capture.py; Python; websockets";
        e.toolchainVersion = "STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1; 3.12.10; 15.0.1";
        e.toolchainPath = "tool/reference_capture.py";
        if (corpus) {
            string memory fixture =
                vm.readFile("test/fixtures/preservation/reference-combined-native-v1.json");
            e.packageFiles =
                abi.decode(vm.parseJsonBytes(fixture, ".packageFilesABI"), (R.PackageFile[]));
            e.platformPrerequisites = abi.decode(
                vm.parseJsonBytes(fixture, ".platformPrerequisitesABI"), (R.PackageFile[])
            );
            e.engineExecutableSha256 =
                bytes32(vm.parseJsonBytes(fixture, ".engineExecutableSha256"));
            e.toolchainSha256 = bytes32(vm.parseJsonBytes(fixture, ".toolchainSha256"));
            e.operatingSystemVersion = vm.parseJsonString(fixture, ".operatingSystemVersion");
            e.licenseNote = vm.parseJsonString(fixture, ".licenseNote");
        } else {
            e.engineExecutableSha256 = bytes32(uint256(3));
            e.toolchainSha256 = bytes32(uint256(4));
            e.packageFiles = new R.PackageFile[](2);
            e.packageFiles[0] = R.PackageFile(e.engineExecutablePath, 10, e.engineExecutableSha256);
            e.packageFiles[1] = R.PackageFile(e.toolchainPath, 11, e.toolchainSha256);
            e.platformPrerequisites = new R.PackageFile[](1);
            e.platformPrerequisites[0] =
                R.PackageFile("C:/Windows/system32/kernel32.dll", 12, bytes32(uint256(5)));
            e.operatingSystemVersion = "explicit fixture";
            e.licenseNote = "undetermined";
        }
        e.operatingSystem = "Windows";
        e.architecture = "AMD64";
        e.viewportWidth = 64;
        e.viewportHeight = 64;
        e.devicePixelRatio = 1;
        e.colorSpace = "srgb";
        e.softwareRasterization = true;
        e.captureProfile = keccak256("STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1");
        bytes memory raw = Json.manifest(e);
        e.manifestHash = keccak256(raw);
        e.manifestBytes = uint32(raw.length);
    }

    function _publication(bool corpus) private view returns (R.Publication memory p) {
        p.collectionId = 1;
        p.referenceId = keccak256("prepared reference");
        p.expectedSourcesHash = keccak256("current original source facts");
        p.snapshotRecordHash = keccak256("original snapshot");
        p.snapshotRevision = 1;
        p.effectiveAt = 100;
        p.environment = _environment(corpus);
        p.captures = new R.Capture[](2);
        for (uint256 i; i < 2; ++i) {
            p.captures[i].environmentManifestHash = p.environment.manifestHash;
            p.captures[i].tokenId = i + 1;
        }
    }

    function _fields()
        private
        view
        returns (R.Receipt memory r, R.SourceFacts memory s, M.Evidence memory e, M.Facts memory f)
    {
        r.collectionId = 1;
        r.recorder = address(this);
        r.authorizationClass = 3;
        r.grantRevision = 1;
        r.sourcesHash = keccak256("current original source facts");
        r.recordHash = keccak256("normalized away");
        s.subject = keccak256("collection subject");
        s.artistId = keccak256("artist");
        e.mode = M.Mode.PERCEPTUAL_TOLERANCE;
        e.perceptual.reportHash = keccak256("report");
        f.mode = e.mode;
        f.evidenceHash = keccak256(abi.encode(e));
    }

    function _part(bytes memory raw, uint256 at) private pure returns (bytes memory part) {
        uint256 n = raw.length - at;
        if (n > 8192) n = 8192;
        part = new bytes(n);
        assembly ("memory-safe") {
            let src := add(add(raw, 32), at)
            let dest := add(part, 32)
            for { let i := 0 } lt(i, n) { i := add(i, 32) } {
                mstore(add(dest, i), mload(add(src, i)))
            }
        }
    }

    function _upload(bytes memory raw, bool omitLast) private {
        for (uint256 at; at < raw.length; at += 8192) {
            if (omitLast && at + 8192 >= raw.length) break;
            store.publishChunk(_part(raw, at));
        }
    }

    function _files(R.PackageFile[] memory rows, bool relative) private {
        for (uint256 start; start < rows.length; start += 64) {
            uint256 n = rows.length - start;
            if (n > 64) n = 64;
            R.PackageFile[] memory part = new R.PackageFile[](n);
            for (uint256 i; i < n; ++i) {
                part[i] = rows[start + i];
            }
            _upload(bytes(Json.files(part, relative)), false);
            host.prepareFileInventoryPart(part, relative);
        }
        _upload(bytes(Json.files(rows, relative)), false);
        host.prepareFileInventoryFromParts(rows, relative);
    }

    function _prepareEnvironment(R.Environment memory e) private returns (bytes memory raw) {
        _files(e.packageFiles, true);
        _files(e.platformPrerequisites, false);
        raw = Json.manifest(e);
        _upload(raw, false);
        host.prepareEnvironment(e);
    }

    function _publicationId(address target, R.Publication memory p) private view returns (bytes32) {
        bytes memory raw = abi.encode(p);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_REFERENCE_MODE_PUBLICATION_PREPARATION_V1"),
                block.chainid,
                target,
                keccak256(raw),
                uint32(raw.length)
            )
        );
    }

    function _payloadId(
        address target,
        R.Publication memory p,
        R.Receipt memory r,
        R.SourceFacts memory s,
        M.Evidence memory e,
        M.Facts memory f
    ) private view returns (bytes32) {
        r.recordHash = 0;
        r.recordChainHash = 0;
        r.payloadHash = 0;
        r.payloadBytes = 0;
        r.recordedAt = 0;
        bytes memory a = abi.encode(p);
        bytes memory b = abi.encode(r);
        bytes memory c = abi.encode(s);
        bytes memory d = abi.encode(e);
        bytes memory g = abi.encode(f);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_REFERENCE_MODE_PAYLOAD_PREPARATION_V1"),
                block.chainid,
                target,
                keccak256(a),
                uint32(a.length),
                keccak256(b),
                uint32(b.length),
                keccak256(c),
                uint32(c.length),
                keccak256(d),
                uint32(d.length),
                keccak256(g),
                uint32(g.length),
                p.environment.manifestHash,
                p.environment.manifestBytes
            )
        );
    }

    function _intrinsic(bytes memory input) private pure returns (uint256 total) {
        total = 21000;
        for (uint256 i; i < input.length; ++i) {
            total += input[i] == 0 ? 4 : 16;
        }
    }

    function _bounded(bytes memory input, bytes memory raw)
        private
        returns (bytes32 id, uint256 total)
    {
        for (uint256 at; at < raw.length; at += 8192) {
            (address pointer,) = store.chunk(keccak256(_part(raw, at)));
            vm.cool(pointer);
        }
        vm.cool(address(store));
        vm.cool(address(host));
        uint256 intrinsic = _intrinsic(input);
        uint256 before = gasleft();
        (bool ok, bytes memory out) = address(host).call{ gas: CAP - intrinsic - 5000 }(input);
        total = before - gasleft() + intrinsic;
        if (!ok) assembly ("memory-safe") { revert(add(out, 32), mload(out)) }
        require(total <= CAP);
        id = abi.decode(out, (bytes32));
    }

    function testOriginalBytesIndependentIdsAndIdempotence() public {
        R.Publication memory p = _publication(false);
        bytes memory environment = _prepareEnvironment(p.environment);
        _upload(abi.encode(p), false);
        bytes32 pid = host.prepareModePublication(p);
        require(pid == _publicationId(address(host), p));
        (P.PublicationDescriptor memory descriptor, bytes memory publication) =
            host.preparedModePublication(pid);
        require(
            descriptor.publicationHash == keccak256(abi.encode(p))
                && keccak256(publication) == descriptor.publicationHash
        );
        (R.Receipt memory r, R.SourceFacts memory s, M.Evidence memory e, M.Facts memory f) =
            _fields();
        bytes memory canonical = encoding.original(p, r, s, e, f, environment);
        _upload(canonical, false);
        bytes32 id = host.prepareModePayload(pid, r, s, e, f);
        require(id == _payloadId(address(host), p, r, s, e, f));
        require(keccak256(host.preparedModePayload(id)) == keccak256(canonical));
        require(keccak256(host.lookup(p, r, s, e, f)) == keccak256(canonical));
        vm.recordLogs();
        require(host.prepareModePublication(p) == pid);
        require(host.prepareModePayload(pid, r, s, e, f) == id);
        require(vm.getRecordedLogs().length == 0, "idempotence is eventless");
        r.recordHash = keccak256("another ignored final receipt hash");
        require(host.prepareModePayload(pid, r, s, e, f) == id);
        r.recorder = address(99);
        require(host.lookup(p, r, s, e, f).length == 0, "writer receipt still binds lookup");
    }

    function testMissingFinalChunksRollbackAndIdenticalRetry() public {
        R.Publication memory p = _publication(false);
        p.manifestURI = new string(12000);
        bytes memory environment = _prepareEnvironment(p.environment);
        bytes memory publication = abi.encode(p);
        bytes32 pid = _publicationId(address(host), p);
        bytes memory call_ = abi.encodeCall(host.prepareModePublication, (p));
        _upload(publication, true);
        (bool ok,) = address(host).call(call_);
        require(!ok);
        (bytes32 hash, uint32 size, uint256 count) = host.publicationState(pid);
        require(hash == 0 && size == 0 && count == 0);
        _upload(publication, false);
        (ok,) = address(host).call(call_);
        require(ok);
        (R.Receipt memory r, R.SourceFacts memory s, M.Evidence memory e, M.Facts memory f) =
            _fields();
        bytes memory canonical = encoding.original(p, r, s, e, f, environment);
        bytes32 id = _payloadId(address(host), p, r, s, e, f);
        call_ = abi.encodeCall(host.prepareModePayload, (pid, r, s, e, f));
        _upload(canonical, true);
        (ok,) = address(host).call(call_);
        require(!ok);
        (hash, size, count) = host.payloadState(id);
        require(hash == 0 && size == 0 && count == 0);
        _upload(canonical, false);
        (ok,) = address(host).call(call_);
        require(ok);
        require(keccak256(host.preparedModePayload(id)) == keccak256(canonical));
    }

    function testPayloadCarrierLengthStopAndHashRefuseBeforeIdenticalRetry() public {
        R.Publication memory p = _publication(false);
        bytes memory environment = _prepareEnvironment(p.environment);
        _upload(abi.encode(p), false);
        bytes32 pid = host.prepareModePublication(p);
        (R.Receipt memory r, R.SourceFacts memory s, M.Evidence memory e, M.Facts memory f) =
            _fields();
        bytes memory canonical = encoding.original(p, r, s, e, f, environment);
        _upload(canonical, false);
        bytes32 id = _payloadId(address(host), p, r, s, e, f);
        bytes memory call_ = abi.encodeCall(host.prepareModePayload, (pid, r, s, e, f));
        (address pointer,) = store.chunk(keccak256(_part(canonical, 0)));
        bytes memory original = pointer.code;
        for (uint256 i; i < 3; ++i) {
            bytes memory changed = abi.encodePacked(original);
            if (i == 0) changed = hex"00";
            else if (i == 1) changed[0] = 0x01;
            else changed[changed.length - 1] ^= 0x01;
            vm.etch(pointer, changed);
            (bool ok, bytes memory error) = address(host).call(call_);
            require(
                !ok
                    && keccak256(error)
                        == keccak256(
                            abi.encodeWithSelector(Bytes.SnapshotChunkChanged.selector, pointer)
                        )
            );
            (bytes32 hash, uint32 size, uint256 count) = host.payloadState(id);
            require(hash == 0 && size == 0 && count == 0);
        }
        vm.etch(pointer, original);
        require(host.prepareModePayload(pid, r, s, e, f) == id);
        require(keccak256(host.preparedModePayload(id)) == keccak256(canonical));
    }

    function testWrongHostChainMissingEnvironmentAndChangedCarrier() public {
        R.Publication memory p = _publication(false);
        _upload(abi.encode(p), false);
        (bool ok,) = address(host).call(abi.encodeCall(host.prepareModePublication, (p)));
        require(!ok, "environment must be authenticated");
        _prepareEnvironment(p.environment);
        bytes32 pid = host.prepareModePublication(p);
        ModePayloadPreparationHost other = new ModePayloadPreparationHost(address(store));
        (R.Receipt memory r, R.SourceFacts memory s, M.Evidence memory e, M.Facts memory f) =
            _fields();
        (ok,) = address(other).call(abi.encodeCall(other.prepareModePayload, (pid, r, s, e, f)));
        require(!ok, "other host cannot import a claimed id");
        // CHAINID is transaction-stable to Solidity's optimizer. Retain the pre-cheat value
        // in fixture storage instead of relying on a local expression across vm.chainId.
        vm.chainId(originalChain + 1);
        (ok,) = address(host).call(abi.encodeCall(host.prepareModePayload, (pid, r, s, e, f)));
        require(!ok, "original chain only");
        vm.chainId(originalChain);
        bytes memory publication = abi.encode(p);
        (address pointer,) = store.chunk(keccak256(_part(publication, 0)));
        bytes memory code = pointer.code;
        vm.etch(pointer, hex"00");
        (ok,) = address(host).call(abi.encodeCall(host.prepareModePublication, (p)));
        require(!ok);
        vm.etch(pointer, code);
        require(host.prepareModePublication(p) == pid);
        p.captures[0].environmentManifestHash = bytes32(uint256(99));
        _upload(abi.encode(p), false);
        (ok,) = address(host).call(abi.encodeCall(host.prepareModePublication, (p)));
        require(!ok, "capture environment mismatch");
    }

    function testFuzzExactOriginalAbiAssembly(bytes calldata raw, uint64 time, bytes32 seed)
        public
        view
    {
        bytes memory environment = raw.length > 2048 ? raw[:2048] : raw;
        R.Publication memory p;
        p.environment.manifestHash = keccak256(environment);
        p.environment.manifestBytes = uint32(environment.length);
        p.manifestURI = string(raw);
        p.effectiveAt = time;
        p.referenceId = seed;
        (R.Receipt memory r, R.SourceFacts memory s, M.Evidence memory e, M.Facts memory f) =
            _fields();
        r.recordedAt = time;
        s.subject = seed;
        e.perceptual.reportURI = string(raw);
        require(
            keccak256(encoding.original(p, r, s, e, f, environment))
                == keccak256(encoding.assembled(p, r, s, e, f, environment))
        );
    }

    function testActual1048RowsStagedTransactionEnvelopes() public {
        R.Publication memory p = _publication(true);
        require(
            p.environment.packageFiles.length == 1048
                && p.environment.platformPrerequisites.length == 102
        );
        bytes memory environment = _prepareEnvironment(p.environment);
        bytes memory publication = abi.encode(p);
        _upload(publication, false);
        (bytes32 pid, uint256 publicationGas) =
            _bounded(abi.encodeCall(host.prepareModePublication, (p)), publication);
        (R.Receipt memory r, R.SourceFacts memory s, M.Evidence memory e, M.Facts memory f) =
            _fields();
        bytes memory canonical = encoding.original(p, r, s, e, f, environment);
        _upload(canonical, false);
        (bytes32 id, uint256 payloadGas) =
            _bounded(abi.encodeCall(host.prepareModePayload, (pid, r, s, e, f)), canonical);
        require(keccak256(host.preparedModePayload(id)) == keccak256(canonical));
        require(keccak256(host.lookup(p, r, s, e, f)) == keccak256(canonical));
        emit log_named_uint("publicationStageWithIntrinsic", publicationGas);
        emit log_named_uint("payloadAssemblyWithIntrinsic", payloadGas);
        emit log_named_uint("exactPayloadBytes", canonical.length);
        // Host/Store/output carriers cooled. Not a fresh RPC transaction, complete transitive
        // cold-access proof, real publisher writer/source acceptance, or unlimited-scope claim.
    }

    function _readyAdoption(bool corpus)
        private
        returns (
            R.Publication memory p,
            R.Receipt memory r,
            R.SourceFacts memory s,
            M.Evidence memory e,
            M.Facts memory f,
            bytes memory canonical,
            bytes32 id
        )
    {
        p = _publication(corpus);
        p.manifestURI = string(new bytes(13000)); // Exercise complete and final-short carriers.
        bytes memory environment = _prepareEnvironment(p.environment);
        _upload(abi.encode(p), false);
        bytes32 publicationId = host.prepareModePublication(p);
        (r, s, e, f) = _fields();
        canonical = encoding.original(p, r, s, e, f, environment);
        _upload(canonical, false);
        id = host.prepareModePayload(publicationId, r, s, e, f);
    }

    function _emptyAdoption() private view {
        (bytes32 hash, uint32 length, uint256 count, bytes32 publicationHash) = host.adoptedState();
        require(hash == 0 && length == 0 && count == 0 && publicationHash == 0);
    }

    function testAdoptionExactOriginalBytesAndDescriptorSubstitutions() public {
        (
            R.Publication memory p,
            R.Receipt memory r,
            R.SourceFacts memory s,
            M.Evidence memory e,
            M.Facts memory f,
            bytes memory canonical,
        ) = _readyAdoption(false);
        bytes32 subject = s.subject;
        s.subject = keccak256("changed fresh source");
        (bool ok,) = address(host).call(abi.encodeCall(host.adoptByInput, (p, r, s, e, f)));
        require(!ok);
        _emptyAdoption();
        s.subject = subject;
        address recorder = r.recorder;
        r.recorder = address(99);
        (ok,) = address(host).call(abi.encodeCall(host.adoptByInput, (p, r, s, e, f)));
        require(!ok);
        _emptyAdoption();
        r.recorder = recorder;
        bytes32 report = e.perceptual.reportHash;
        e.perceptual.reportHash = bytes32(uint256(44));
        (ok,) = address(host).call(abi.encodeCall(host.adoptByInput, (p, r, s, e, f)));
        require(!ok);
        _emptyAdoption();
        e.perceptual.reportHash = report;
        vm.chainId(originalChain + 1);
        (ok,) = address(host).call(abi.encodeCall(host.adoptByInput, (p, r, s, e, f)));
        require(!ok);
        vm.chainId(originalChain);
        _emptyAdoption();
        ModePayloadPreparationHost other = new ModePayloadPreparationHost(address(store));
        (ok,) = address(other).call(abi.encodeCall(other.adoptByInput, (p, r, s, e, f)));
        require(!ok);
        require(host.adoptByInput(p, r, s, e, f) == keccak256(canonical));
        (bytes memory payload, bytes memory publication) = host.adoptedBytes();
        require(keccak256(payload) == keccak256(canonical));
        require(keccak256(publication) == keccak256(abi.encode(p)));
        (ok,) = address(host).call(abi.encodeCall(host.adoptByInput, (p, r, s, e, f)));
        require(!ok, "cannot replace original destination");
    }

    function testAdoptionRejectsOrderedWholeCommitmentAndCorruptedCodeThenRetry() public {
        (
            R.Publication memory p,
            R.Receipt memory r,
            R.SourceFacts memory s,
            M.Evidence memory e,
            M.Facts memory f,
            bytes memory canonical,
            bytes32 id
        ) = _readyAdoption(false);
        bytes memory call_ = abi.encodeCall(host.adoptByInput, (p, r, s, e, f));
        host.swapPreparedChunks(id);
        (bool ok,) = address(host).call(call_);
        require(!ok);
        _emptyAdoption();
        host.swapPreparedChunks(id);
        host.corruptPayloadHash(id, keccak256("forged full-byte hash"));
        (ok,) = address(host).call(call_);
        require(!ok);
        _emptyAdoption();
        host.corruptPayloadHash(id, keccak256(canonical));
        (address pointer,) = store.chunk(keccak256(_part(canonical, 0)));
        bytes memory original = pointer.code;
        vm.etch(pointer, hex"00");
        (ok,) = address(host).call(call_);
        require(!ok);
        _emptyAdoption();
        bytes memory changed = abi.encodePacked(original);
        changed[0] = bytes1(uint8(1));
        vm.etch(pointer, changed);
        (ok,) = address(host).call(call_);
        require(!ok);
        _emptyAdoption();
        changed[0] = 0;
        changed[2] = bytes1(uint8(changed[2]) ^ 1);
        vm.etch(pointer, changed);
        (ok,) = address(host).call(call_);
        require(!ok);
        _emptyAdoption();
        vm.etch(pointer, original);
        require(host.adoptByInput(p, r, s, e, f) == keccak256(canonical));
    }

    function testAdoptionLateDestinationFailureRollsBackPayloadAndIdenticalRetry() public {
        (
            R.Publication memory p,
            R.Receipt memory r,
            R.SourceFacts memory s,
            M.Evidence memory e,
            M.Facts memory f,
            bytes memory canonical,
        ) = _readyAdoption(false);
        bytes memory call_ = abi.encodeCall(host.adoptByInput, (p, r, s, e, f));
        host.occupiedPublication(true);
        (bool ok,) = address(host).call(call_);
        require(!ok);
        _emptyAdoption();
        host.occupiedPublication(false);
        (ok,) = address(host).call(call_);
        require(ok);
        (bytes memory payload, bytes memory publication) = host.adoptedBytes();
        require(
            keccak256(payload) == keccak256(canonical)
                && keccak256(publication) == keccak256(abi.encode(p))
        );
    }

    function testAdoption1048CorpusMutationEnvelope() public {
        (
            R.Publication memory p,
            R.Receipt memory r,
            R.SourceFacts memory s,
            M.Evidence memory e,
            M.Facts memory f,
            bytes memory canonical,
        ) = _readyAdoption(true);
        bytes memory call_ = abi.encodeCall(host.adoptByInput, (p, r, s, e, f));
        (bytes32 hash, uint256 total) = _bounded(call_, canonical);
        require(hash == keccak256(canonical));
        (bytes memory payload, bytes memory publication) = host.adoptedBytes();
        require(keccak256(payload) == hash && keccak256(publication) == keccak256(abi.encode(p)));
        emit log_named_uint("adoptionWorkerWithIntrinsic", total);
        // This host demonstrates exact data transport only; real source/writer admission is separate.
    }

    function _emptyBinding(bytes32 record) private view {
        (bytes32 publication, bytes32 payload, bool known) = host.boundState(record);
        require(publication == 0 && payload == 0 && !known);
    }

    function testBindingMixedLegacyAndImmutablePreparedRecords() public {
        (
            R.Publication memory p,
            R.Receipt memory r,
            R.SourceFacts memory s,
            M.Evidence memory e,
            M.Facts memory f,
            bytes memory canonical,
            bytes32 id
        ) = _readyAdoption(false);
        bytes32 oldRecord = keccak256("original monolithic record");
        bytes32 record = keccak256("original newly authorized record");
        host.retainLegacy(oldRecord, canonical, abi.encode(p));
        (bool ok,) = address(host).call(abi.encodeCall(host.boundBytes, (record)));
        require(!ok, "preparation cannot publish a record");
        require(host.bindByInput(record, p, r, s, e, f) == keccak256(canonical));
        (bytes memory payload, bytes memory publication) = host.boundBytes(record);
        (bytes memory oldPayload, bytes memory oldPublication) = host.boundBytes(oldRecord);
        require(
            keccak256(payload) == keccak256(oldPayload)
                && keccak256(payload) == keccak256(canonical)
        );
        require(
            keccak256(publication) == keccak256(oldPublication)
                && keccak256(publication) == keccak256(abi.encode(p))
        );
        (bytes32 pid, bytes32 savedId, bool known) = host.boundState(record);
        require(known && savedId == id && pid == host.prepareModePublication(p));
        require(id == host.prepareModePayload(pid, r, s, e, f));
        host.corruptBinding(record, pid, 0, 0);
        (ok,) = address(host).call(abi.encodeCall(host.boundBytes, (record)));
        require(!ok);
        host.corruptBinding(record, 0, id, 0);
        (ok,) = address(host).call(abi.encodeCall(host.boundBytes, (record)));
        require(!ok);
        host.corruptBinding(record, pid, id, 1);
        (ok,) = address(host).call(abi.encodeCall(host.boundBytes, (record)));
        require(!ok);
        host.corruptBinding(record, pid, id, 0);
        // Changed inputs create a distinct immutable preparation; they cannot replace this binding.
        p.collectionId += 1;
        _upload(abi.encode(p), false);
        require(host.prepareModePublication(p) != pid);
        (payload, publication) = host.boundBytes(record);
        require(keccak256(payload) == keccak256(canonical));
        require(keccak256(publication) == keccak256(oldPublication));
        (ok,) = address(host).call(abi.encodeCall(host.bindByInput, (record, p, r, s, e, f)));
        require(!ok);
        (ok,) = address(host).call(abi.encodeCall(host.bindByInput, (oldRecord, p, r, s, e, f)));
        require(!ok);
        (address pointer,) = store.chunk(keccak256(_part(canonical, 0)));
        bytes memory original = pointer.code;
        vm.etch(pointer, hex"00");
        (ok,) = address(host).call(abi.encodeCall(host.boundBytes, (record)));
        require(!ok, "binding cannot bypass historical byte integrity");
        vm.etch(pointer, original);
        (payload,) = host.boundBytes(record);
        require(keccak256(payload) == keccak256(canonical));
    }

    function testBindingFreshInputHostChainAndScopeSubstitutions() public {
        (
            R.Publication memory p,
            R.Receipt memory r,
            R.SourceFacts memory s,
            M.Evidence memory e,
            M.Facts memory f,
            bytes memory canonical,
        ) = _readyAdoption(false);
        bytes32 record = keccak256("bound record");
        bytes32 subject = s.subject;
        s.subject = keccak256("changed fresh scope");
        (bool ok,) = address(host).call(abi.encodeCall(host.bindByInput, (record, p, r, s, e, f)));
        require(!ok);
        _emptyBinding(record);
        s.subject = subject;
        address recorder = r.recorder;
        r.recorder = address(99);
        (ok,) = address(host).call(abi.encodeCall(host.bindByInput, (record, p, r, s, e, f)));
        require(!ok);
        _emptyBinding(record);
        r.recorder = recorder;
        bytes32 report = e.perceptual.reportHash;
        e.perceptual.reportHash = bytes32(uint256(44));
        (ok,) = address(host).call(abi.encodeCall(host.bindByInput, (record, p, r, s, e, f)));
        require(!ok);
        _emptyBinding(record);
        e.perceptual.reportHash = report;
        uint256 cid = p.collectionId;
        p.collectionId += 1;
        (ok,) = address(host).call(abi.encodeCall(host.bindByInput, (record, p, r, s, e, f)));
        require(!ok);
        _emptyBinding(record);
        p.collectionId = cid;
        vm.chainId(originalChain + 1);
        (ok,) = address(host).call(abi.encodeCall(host.bindByInput, (record, p, r, s, e, f)));
        require(!ok);
        vm.chainId(originalChain);
        _emptyBinding(record);
        ModePayloadPreparationHost other = new ModePayloadPreparationHost(address(store));
        (ok,) = address(other).call(abi.encodeCall(other.bindByInput, (record, p, r, s, e, f)));
        require(!ok);
        require(host.bindByInput(record, p, r, s, e, f) == keccak256(canonical));
    }

    function testBindingCorruptionAndLateFailureRollBackThenRetry() public {
        (
            R.Publication memory p,
            R.Receipt memory r,
            R.SourceFacts memory s,
            M.Evidence memory e,
            M.Facts memory f,
            bytes memory canonical,
            bytes32 id
        ) = _readyAdoption(false);
        bytes32 record = keccak256("bound record");
        bytes memory call_ = abi.encodeCall(host.bindByInput, (record, p, r, s, e, f));
        host.swapPreparedChunks(id);
        (bool ok,) = address(host).call(call_);
        require(!ok);
        _emptyBinding(record);
        host.swapPreparedChunks(id);
        host.corruptPayloadHash(id, keccak256("forged whole bytes"));
        (ok,) = address(host).call(call_);
        require(!ok);
        _emptyBinding(record);
        host.corruptPayloadHash(id, keccak256(canonical));
        (address pointer,) = store.chunk(keccak256(_part(canonical, 0)));
        bytes memory original = pointer.code;
        vm.etch(pointer, hex"00");
        (ok,) = address(host).call(call_);
        require(!ok);
        _emptyBinding(record);
        bytes memory changed = abi.encodePacked(original);
        changed[0] = bytes1(uint8(1));
        vm.etch(pointer, changed);
        (ok,) = address(host).call(call_);
        require(!ok);
        _emptyBinding(record);
        changed[0] = 0;
        changed[2] = bytes1(uint8(changed[2]) ^ 1);
        vm.etch(pointer, changed);
        (ok,) = address(host).call(call_);
        require(!ok);
        _emptyBinding(record);
        vm.etch(pointer, original);
        host.setLateBindingFailure(true);
        (ok,) = address(host).call(call_);
        require(!ok);
        _emptyBinding(record);
        host.setLateBindingFailure(false);
        (ok,) = address(host).call(call_);
        require(ok);
        (bytes memory payload, bytes memory publication) = host.boundBytes(record);
        require(
            keccak256(payload) == keccak256(canonical)
                && keccak256(publication) == keccak256(abi.encode(p))
        );
        (ok,) = address(host).call(call_);
        require(!ok, "immutable binding");
    }

    function testBinding1048CorpusTransactionEnvelope() public {
        (
            R.Publication memory p,
            R.Receipt memory r,
            R.SourceFacts memory s,
            M.Evidence memory e,
            M.Facts memory f,
            bytes memory canonical,
        ) = _readyAdoption(true);
        bytes32 record = keccak256("bound full corpus record");
        bytes memory call_ = abi.encodeCall(host.bindByInput, (record, p, r, s, e, f));
        (bytes32 hash, uint256 total) = _bounded(call_, canonical);
        require(hash == keccak256(canonical));
        (bytes memory payload, bytes memory publication) = host.boundBytes(record);
        require(keccak256(payload) == hash && keccak256(publication) == keccak256(abi.encode(p)));
        emit log_named_uint("bindingWorkerWithIntrinsic", total);
        // Actual fixed workers/Store; limited named cooling and no actual publisher authority claim.
    }

    function testFuzzOriginalRecordCodec(bytes calldata uri, bytes32 seed, uint64 time)
        public
        view
    {
        if (uri.length > 2048) return;
        R.Publication memory p = _publication(false);
        p.manifestURI = string(uri);
        p.expectedSourcesHash = seed;
        if (uint256(seed) & 1 == 0) {
            p.captures = new R.Capture[](0);
            p.environment.packageFiles = new R.PackageFile[](0);
            p.environment.platformPrerequisites = new R.PackageFile[](0);
        }
        p.referenceId = keccak256(abi.encode(seed, time));
        (R.Receipt memory r,, M.Evidence memory e,) = _fields();
        r.sourcesHash = seed;
        r.recordedAt = time;
        r.payloadHash = keccak256(uri);
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_REFERENCE_MODE_RECORD_V1"),
                block.chainid,
                address(host),
                address(101),
                address(102),
                p,
                r
            )
        );
        require(host.hashOriginalRecord(p, r, e) == expected);
        R.Dependencies memory d;
        d.chainId = block.chainid;
        d.targets[0] = address(101);
        d.targets[6] = address(102);
        d.codeHashes[0] = seed;
        d.codeHashes[6] = keccak256(uri);
        expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_REFERENCE_MODE_CONTEXT_V1"),
                d.chainId,
                address(host),
                d.targets,
                d.codeHashes,
                p.collectionId,
                p.referenceId,
                p.snapshotRecordHash,
                p.snapshotRevision,
                p.captures,
                p.environment
            )
        );
        require(host.hashOriginalContext(d, p) == expected);
    }

    function testOriginalFallbackPublicationBytesAndMissingChunkRetry() public {
        R.Publication memory p = _publication(false);
        p.manifestURI = string(new bytes(13000));
        (,, M.Evidence memory evidence,) = _fields();
        bytes memory raw = abi.encode(p);
        bytes32 record = keccak256("original fallback");
        _upload(raw, true);
        bytes memory input = abi.encodeCall(host.retainOriginalPublication, (record, p, evidence));
        (bool ok,) = address(host).call(input);
        require(!ok);
        _upload(raw, false);
        (ok,) = address(host).call(input);
        require(ok);
        require(keccak256(host.readOriginalPublication(record)) == keccak256(raw));
    }
}
