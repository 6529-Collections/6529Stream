// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceRenderPreparation as Preparation
} from "../../../smart-contracts/domains/preservation/StreamReferenceRenderPreparation.sol";
import {
    StreamReferenceInventoryPreparation as Parts
} from "../../../smart-contracts/domains/preservation/StreamReferenceInventoryPreparation.sol";
import {
    StreamReferenceEnvironmentJson as Json
} from "../../../smart-contracts/domains/records/StreamReferenceEnvironmentJson.sol";
import {
    StreamSnapshotManifestBytes as Bytes
} from "../../../smart-contracts/domains/records/StreamSnapshotManifestBytes.sol";
import {
    StreamSchemaDocumentStore as Store
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    ReferenceEnvironmentJsonFrozen as Frozen
} from "../../helpers/ReferenceEnvironmentJsonFrozen.sol";

interface EnvironmentPreparationVm {
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

/// @dev Real fixed workers/Store and declared mapping. Complete production hosts remain a separate acceptance boundary.
contract EnvironmentPreparationHost {
    mapping(bytes32 => Bytes.Manifest) private inventories;
    address public immutable store;
    bytes32 public immutable storeHash;
    uint256 public immutable deploymentChain;
    bool private entered;

    constructor(address s) {
        store = s;
        storeHash = s.codehash;
        deploymentChain = block.chainid;
    }
    modifier guarded() {
        require(!entered);
        entered = true;
        _;
        entered = false;
    }

    function prepareEnvironment(R.Environment calldata) external guarded returns (bytes32) {
        return Preparation.prepareEnvironment(inventories, store, storeHash, msg.data);
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

    function environment(R.Environment memory e) external view returns (bytes memory) {
        return Preparation.environment(inventories, e);
    }

    function projectedEnvironment(R.Environment memory e) external view returns (bytes memory) {
        bytes32 id = Preparation.environmentIdInternal(e);
        if (inventories[id].contentHash != 0) return Bytes.read(inventories[id]);
        return Preparation.environment(inventories, e);
    }

    function preparedFileInventory(bytes32 id) external view returns (bytes memory) {
        return Bytes.read(inventories[id]);
    }

    function state(bytes32 id) external view returns (bytes32, uint32, uint256, uint256) {
        Bytes.Manifest storage m = inventories[id];
        return (m.contentHash, m.byteLength, m.pointers.length, m.chunkHashes.length);
    }
}

contract EnvironmentEncodingProbe {
    function original(R.Environment memory e, bytes memory packageJSON, bytes memory platformJSON)
        external
        pure
        returns (bytes memory)
    {
        return Frozen.manifestWithAuthenticatedFiles(e, packageJSON, platformJSON);
    }

    function current(R.Environment memory e, bytes memory packageJSON, bytes memory platformJSON)
        external
        pure
        returns (bytes memory)
    {
        return Json.manifestWithAuthenticatedFiles(e, packageJSON, platformJSON);
    }
}

contract StreamReferenceEnvironmentPreparationTest {
    EnvironmentPreparationVm private constant vm =
        EnvironmentPreparationVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private constant CAP = 16777216;
    Store private store;
    EnvironmentPreparationHost private host;
    event log_named_uint(string label, uint256 value);

    function setUp() public {
        store = new Store();
        host = new EnvironmentPreparationHost(address(store));
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

    function _id(EnvironmentPreparationHost target, R.Environment memory e)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_REFERENCE_ENVIRONMENT_PREPARATION_V1"),
                block.chainid,
                address(target),
                e
            )
        );
    }

    function _segment(bytes memory raw, uint256 offset) private pure returns (bytes memory part) {
        uint256 size = raw.length - offset;
        if (size > 8192) size = 8192;
        part = new bytes(size);
        assembly ("memory-safe") {
            let src := add(add(raw, 32), offset)
            let dst := add(part, 32)
            for { let i := 0 } lt(i, size) { i := add(i, 32) } {
                mstore(add(dst, i), mload(add(src, i)))
            }
        }
    }

    function _upload(bytes memory raw, bool omitLast) private {
        for (uint256 i; i < raw.length; i += 8192) {
            if (omitLast && i + 8192 >= raw.length) break;
            store.publishChunk(_segment(raw, i));
        }
    }

    function _files(EnvironmentPreparationHost target, R.PackageFile[] memory rows, bool relative)
        private
    {
        for (uint256 i; i < rows.length; i += 64) {
            uint256 n = rows.length - i;
            if (n > 64) n = 64;
            R.PackageFile[] memory part = new R.PackageFile[](n);
            for (uint256 j; j < n; ++j) {
                part[j] = rows[i + j];
            }
            _upload(bytes(Json.files(part, relative)), false);
            target.prepareFileInventoryPart(part, relative);
        }
        _upload(bytes(Json.files(rows, relative)), false);
        target.prepareFileInventoryFromParts(rows, relative);
    }

    function _filesFor(EnvironmentPreparationHost target, R.Environment memory e) private {
        _files(target, e.packageFiles, true);
        _files(target, e.platformPrerequisites, false);
    }

    function _empty(EnvironmentPreparationHost target, bytes32 id) private view {
        (bytes32 h, uint32 n, uint256 a, uint256 b) = target.state(id);
        require(h == 0 && n == 0 && a == 0 && b == 0, "atomic state");
    }

    function _fails(EnvironmentPreparationHost target, R.Environment memory e) private {
        (bool ok,) = address(target).call(abi.encodeCall(target.prepareEnvironment, (e)));
        require(!ok, "expected refusal");
        _empty(target, _id(target, e));
    }

    function testOriginalFallbackExactBytesAndEventlessIdempotence() public {
        R.Environment memory e = _environment(false);
        _filesFor(host, e);
        bytes memory expected = Json.manifest(e);
        require(keccak256(host.environment(e)) == keccak256(expected), "original fallback");
        _upload(expected, false);
        vm.recordLogs();
        bytes32 id = host.prepareEnvironment(e);
        EnvironmentPreparationVm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 1);
        require(logs[0].emitter == address(host) && logs[0].topics[1] == id);
        require(
            keccak256(logs[0].data)
                == keccak256(abi.encode(uint16(1), e.manifestHash, e.manifestBytes))
        );
        require(id == _id(host, e));
        require(keccak256(host.preparedFileInventory(id)) == keccak256(expected));
        require(keccak256(host.environment(e)) == keccak256(expected), "prepared bytes");
        vm.recordLogs();
        require(host.prepareEnvironment(e) == id);
        require(vm.getRecordedLogs().length == 0);
    }

    function testMissingInventoriesWrongHashLengthAndLateChunkRollback() public {
        R.Environment memory e = _environment(false);
        _fails(host, e);
        _filesFor(host, e);
        bytes memory note = new bytes(9000);
        for (uint256 i; i < note.length; ++i) {
            note[i] = "a";
        }
        e.licenseNote = string(note);
        bytes memory expected = Json.manifest(e);
        e.manifestHash = keccak256(expected);
        e.manifestBytes = uint32(expected.length);
        require(expected.length > 8192, "late chunk after prior state writes");
        _upload(expected, true);
        _fails(host, e);
        _upload(expected, false);
        bytes32 h = e.manifestHash;
        e.manifestHash = bytes32(uint256(9));
        _fails(host, e);
        e.manifestHash = h;
        e.manifestBytes++;
        _fails(host, e);
        e.manifestBytes--;
        require(host.prepareEnvironment(e) == _id(host, e), "identical retry");
    }

    function testCompleteTypedMutationCrossHostAndChainCannotReusePreparation() public {
        R.Environment memory e = _environment(false);
        _filesFor(host, e);
        _upload(Json.manifest(e), false);
        bytes32 id = host.prepareEnvironment(e);
        e.engineVersion = "changed";
        require(_id(host, e) != id);
        _fails(host, e);
        e.engineVersion = "152.0.7977.83";
        e.packageFiles[0].byteSize++;
        _fails(host, e);
        e.packageFiles[0].byteSize--;
        EnvironmentPreparationHost other = new EnvironmentPreparationHost(address(store));
        require(_id(other, e) != id);
        _fails(other, e);
        vm.chainId(host.deploymentChain() + 1);
        require(_id(host, e) != id);
        _fails(host, e);
        vm.chainId(host.deploymentChain());
        require(
            host.prepareEnvironment(e) == id && keccak256(host.environment(e)) == e.manifestHash
        );
        // Coverage is a live publisher obligation. It is absent from canonical JSON but
        // remains part of the complete preparation identity, and cannot reuse that entry.
        e.coverageHash = bytes32(uint256(22));
        bytes32 otherId = _id(host, e);
        require(otherId != id);
        _empty(host, otherId);
        require(host.prepareEnvironment(e) == otherId);
    }

    function testStoreAndRetainedChunkRuntimeChangesStillRefuse() public {
        R.Environment memory e = _environment(false);
        _filesFor(host, e);
        bytes memory raw = Json.manifest(e);
        _upload(raw, false);
        host.prepareEnvironment(e);
        bytes memory code = address(store).code;
        vm.etch(address(store), hex"00");
        (bool ok,) = address(host).call(abi.encodeCall(host.prepareEnvironment, (e)));
        require(!ok);
        vm.etch(address(store), code);
        (address pointer,) = store.chunk(keccak256(_segment(raw, 0)));
        vm.etch(pointer, hex"00");
        (ok,) = address(host).staticcall(abi.encodeCall(host.environment, (e)));
        require(!ok, "saved bytes must remain intact");
        (ok,) = address(host).call(abi.encodeCall(host.prepareEnvironment, (e)));
        require(!ok, "repeat verifies intact bytes");
    }

    function testActual1048MemberPreparationEnvelopeAndExactRead() public {
        R.Environment memory e = _environment(true);
        _filesFor(host, e);
        bytes memory expected = Json.manifest(e);
        _upload(expected, false);
        bytes memory input = abi.encodeCall(host.prepareEnvironment, (e));
        uint256 intrinsic = 21000;
        for (uint256 i; i < input.length; ++i) {
            intrinsic += input[i] == 0 ? 4 : 16;
        }
        for (uint256 i; i < expected.length; i += 8192) {
            (address ptr,) = store.chunk(keccak256(_segment(expected, i)));
            vm.cool(ptr);
        }
        vm.cool(address(store));
        vm.cool(address(host));
        vm.cool(address(Preparation));
        vm.cool(address(Bytes));
        vm.cool(address(Json));
        uint256 before = gasleft();
        (bool ok, bytes memory returned) = address(host).call{ gas: CAP - intrinsic - 5000 }(input);
        uint256 used = before - gasleft() + intrinsic;
        if (!ok) assembly ("memory-safe") { revert(add(returned, 32), mload(returned)) }
        require(used <= CAP && abi.decode(returned, (bytes32)) == _id(host, e));
        emit log_named_uint("environmentPreparationWithIntrinsic", used);
        // Build calldata before measurement so the test's large accumulated heap cannot
        // mislabel its own ABI allocation as a fresh transaction's callee cost.
        input = abi.encodeCall(host.projectedEnvironment, (e));
        intrinsic = 21000;
        for (uint256 i; i < input.length; ++i) {
            intrinsic += input[i] == 0 ? 4 : 16;
        }
        vm.cool(address(host));
        vm.cool(address(Preparation));
        vm.cool(address(Bytes));
        for (uint256 i; i < expected.length; i += 8192) {
            (address ptr,) = store.chunk(keccak256(_segment(expected, i)));
            vm.cool(ptr);
        }
        address target = address(host);
        uint256 cap = CAP - intrinsic - 5000;
        before = gasleft();
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), 0, 0)
        }
        uint256 readGas = before - gasleft() + intrinsic;
        assembly ("memory-safe") {
            returned := mload(0x40)
            mstore(returned, returndatasize())
            returndatacopy(add(returned, 32), 0, returndatasize())
            mstore(0x40, and(add(add(returned, 63), returndatasize()), not(31)))
        }
        require(ok && readGas <= CAP, "bounded prepared read");
        bytes memory saved = abi.decode(returned, (bytes));
        require(keccak256(saved) == keccak256(expected));
        emit log_named_uint("preparedEnvironmentCalleeWithIntrinsic", readGas);
    }

    function _encodingParity(
        EnvironmentEncodingProbe probe,
        R.Environment memory e,
        bytes memory packageJSON,
        bytes memory platformJSON
    ) private view {
        (bool a, bytes memory old) = address(probe)
            .staticcall(abi.encodeCall(probe.original, (e, packageJSON, platformJSON)));
        (bool b, bytes memory current) =
            address(probe).staticcall(abi.encodeCall(probe.current, (e, packageJSON, platformJSON)));
        require(
            a == b && keccak256(old) == keccak256(current),
            "original environment bytes/error parity"
        );
    }

    function testOriginalEnvironmentSerializationErrorsAndMaximum() public {
        EnvironmentEncodingProbe probe = new EnvironmentEncodingProbe();
        bytes memory invalidUtf8 = hex"ff";
        R.Environment memory e = _environment(false);
        bytes memory packageJSON = bytes(Json.files(e.packageFiles, true));
        bytes memory platformJSON = bytes(Json.files(e.platformPrerequisites, false));
        _encodingParity(probe, e, packageJSON, platformJSON);
        e.objectHash = 0;
        _encodingParity(probe, e, packageJSON, platformJSON);
        e.objectHash = bytes32(uint256(1));
        e.viewportWidth = 4097;
        _encodingParity(probe, e, packageJSON, platformJSON);
        e.viewportWidth = 64;
        e.engineExecutablePath = "missing";
        _encodingParity(probe, e, packageJSON, platformJSON);
        e.engineExecutablePath = "engine/chrome.exe";
        e.architecture = string(invalidUtf8);
        _encodingParity(probe, e, packageJSON, platformJSON);
        e.architecture = "AMD64";
        e.licenseNote = string(invalidUtf8);
        _encodingParity(probe, e, packageJSON, platformJSON);
        e.licenseNote = string(new bytes(16385));
        _encodingParity(probe, e, packageJSON, platformJSON);
        e.licenseNote = "undetermined";
        _encodingParity(probe, e, new bytes(524288), platformJSON);
    }

    function testFuzzOriginalEnvironmentStringBytes(bytes memory note) public {
        EnvironmentEncodingProbe probe = new EnvironmentEncodingProbe();
        R.Environment memory e = _environment(false);
        e.licenseNote = string(note);
        _encodingParity(
            probe,
            e,
            bytes(Json.files(e.packageFiles, true)),
            bytes(Json.files(e.platformPrerequisites, false))
        );
    }

    function testActual1048EnvironmentOriginalByteParity() public {
        EnvironmentEncodingProbe probe = new EnvironmentEncodingProbe();
        R.Environment memory e = _environment(true);
        bytes memory packageJSON = bytes(Json.files(e.packageFiles, true));
        bytes memory platformJSON = bytes(Json.files(e.platformPrerequisites, false));
        uint256 before = gasleft();
        bytes memory old = probe.original(e, packageJSON, platformJSON);
        uint256 oldGas = before - gasleft();
        before = gasleft();
        bytes memory current = probe.current(e, packageJSON, platformJSON);
        uint256 currentGas = before - gasleft();
        require(
            keccak256(old) == keccak256(current) && currentGas < oldGas,
            "exact complete corpus bytes/saving"
        );
        emit log_named_uint("originalEnvironmentSerialization", oldGas);
        emit log_named_uint("singleAllocationEnvironmentSerialization", currentGas);
    }
}
