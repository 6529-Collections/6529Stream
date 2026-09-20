// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceInventoryPreparation as Parts
} from "../../../smart-contracts/domains/preservation/StreamReferenceInventoryPreparation.sol";
import {
    StreamReferenceRenderPreparation as Original
} from "../../../smart-contracts/domains/preservation/StreamReferenceRenderPreparation.sol";
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

interface StagedInventoryVm {
    function readFile(string calldata) external view returns (string memory);
    function parseJsonBytes(string calldata, string calldata) external pure returns (bytes memory);
    function chainId(uint256) external;
    function cool(address) external;
}

/// @dev Exact compiler-declared mapping and fixed worker; complete publication hosts measured separately.
contract InventoryPreparationHost {
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

    function prepareOriginal(R.PackageFile[] calldata rows, bool relative)
        external
        guarded
        returns (bytes32)
    {
        return Original.prepare(inventories, store, storeHash, rows, relative);
    }

    function originalId(R.PackageFile[] calldata rows, bool relative)
        external
        view
        returns (bytes32)
    {
        return Original.inventoryId(rows, relative);
    }

    function read(bytes32 id) external view returns (bytes memory) {
        return Bytes.read(inventories[id]);
    }

    function state(bytes32 id) external view returns (bytes32, uint32, uint256, uint256) {
        Bytes.Manifest storage m = inventories[id];
        return (m.contentHash, m.byteLength, m.pointers.length, m.chunkHashes.length);
    }
}

contract StreamReferenceInventoryPreparationTest {
    StagedInventoryVm private constant vm =
        StagedInventoryVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private constant CAP = 16777216;
    Store private store;
    InventoryPreparationHost private host;
    event log_named_uint(string label, uint256 value);

    function setUp() public {
        store = new Store();
        host = new InventoryPreparationHost(address(store));
    }

    function _intrinsic(bytes memory raw) private pure returns (uint256 gas_) {
        gas_ = 21000;
        for (uint256 i; i < raw.length; ++i) {
            gas_ += raw[i] == 0 ? 4 : 16;
        }
    }

    function _bounded(address target, bytes memory input)
        private
        returns (bytes memory result, uint256 used)
    {
        uint256 intrinsic = _intrinsic(input);
        vm.cool(address(Parts));
        vm.cool(address(Bytes));
        vm.cool(address(Json));
        vm.cool(target);
        uint256 before = gasleft();
        (bool ok, bytes memory returned) = target.call{ gas: CAP - intrinsic - 5000 }(input);
        used = before - gasleft() + intrinsic;
        if (!ok) assembly ("memory-safe") { revert(add(returned, 32), mload(returned)) }
        require(used <= CAP, "transaction envelope");
        return (returned, used);
    }

    function _slice(R.PackageFile[] memory rows, uint256 offset, uint256 count)
        private
        pure
        returns (R.PackageFile[] memory part)
    {
        part = new R.PackageFile[](count);
        for (uint256 i; i < count; ++i) {
            part[i] = rows[offset + i];
        }
    }

    function _segment(bytes memory data, uint256 start) private pure returns (bytes memory part) {
        uint256 n = data.length - start;
        if (n > 8192) n = 8192;
        part = new bytes(n);
        assembly ("memory-safe") {
            let source := add(add(data, 32), start)
            let target := add(part, 32)
            for { let i := 0 } lt(i, n) { i := add(i, 32) } {
                mstore(add(target, i), mload(add(source, i)))
            }
        }
    }

    function _upload(bytes memory raw, bool omitLast) private returns (uint256 maximum) {
        for (uint256 i; i < raw.length; i += 8192) {
            if (omitLast && i + 8192 >= raw.length) break;
            bytes memory input = abi.encodeCall(store.publishChunk, (_segment(raw, i)));
            (, uint256 used) = _bounded(address(store), input);
            if (used > maximum) maximum = used;
        }
    }

    function _coolChunks(bytes memory raw) private {
        for (uint256 i; i < raw.length; i += 8192) {
            (address pointer,) = store.chunk(keccak256(_segment(raw, i)));
            if (pointer != address(0)) vm.cool(pointer);
        }
        vm.cool(address(store));
    }

    function _parts(R.PackageFile[] memory rows, bool relative) private returns (uint256 maximum) {
        bytes[] memory originals = new bytes[]((rows.length + 63) / 64);
        for (uint256 i; i < rows.length; i += 64) {
            uint256 n = rows.length - i;
            if (n > 64) n = 64;
            R.PackageFile[] memory part = _slice(rows, i, n);
            bytes memory raw = bytes(Json.files(part, relative));
            _upload(raw, false);
            _coolChunks(raw);
            originals[i / 64] = raw;
            (, uint256 used) = _bounded(
                address(host), abi.encodeCall(host.prepareFileInventoryPart, (part, relative))
            );
            if (used > maximum) maximum = used;
        }
        for (uint256 i; i < originals.length; ++i) {
            _coolChunks(originals[i]);
        }
    }

    function _rows(uint256 n) private pure returns (R.PackageFile[] memory rows) {
        rows = new R.PackageFile[](n);
        for (uint256 i; i < n; ++i) {
            bytes memory path = bytes(
                "000/abcdefghijklmnopqrstuvwxyz/abcdefghijklmnopqrstuvwxyz/abcdefghijklmnopqrstuvwxyz/file.py"
            );
            path[0] = bytes1(uint8(48 + i / 100));
            path[1] = bytes1(uint8(48 + i / 10 % 10));
            path[2] = bytes1(uint8(48 + i % 10));
            rows[i] = R.PackageFile(string(path), uint64(i), bytes32(i + 1));
        }
    }

    function _fails(InventoryPreparationHost target, R.PackageFile[] memory rows, bool relative)
        private
    {
        (bool ok,) = address(target)
            .call(abi.encodeCall(target.prepareFileInventoryFromParts, (rows, relative)));
        require(!ok, "unbound parts must refuse");
    }

    function testActual1048PackageEveryStageAndFinalizerEnvelope() public {
        string memory fixture =
            vm.readFile("test/fixtures/preservation/reference-combined-native-v1.json");
        R.PackageFile[] memory rows =
            abi.decode(vm.parseJsonBytes(fixture, ".packageFilesABI"), (R.PackageFile[]));
        require(rows.length == 1048);
        bytes memory canonical = bytes(Json.files(rows, true));
        uint256 maximumUpload = _upload(canonical, false);
        uint256 maximumPart = _parts(rows, true);
        _coolChunks(canonical);
        (bytes memory returned, uint256 finalGas) = _bounded(
            address(host), abi.encodeCall(host.prepareFileInventoryFromParts, (rows, true))
        );
        bytes32 id = abi.decode(returned, (bytes32));
        require(id == host.originalId(rows, true));
        require(keccak256(host.read(id)) == keccak256(canonical), "exact complete canonical bytes");
        emit log_named_uint("maximumFullArrayChunkTransaction", maximumUpload);
        emit log_named_uint("maximumPartTransaction", maximumPart);
        emit log_named_uint("finalizerTransaction", finalGas);
    }

    function testSwappedOmittedDuplicateTruncatedAndSubstitutedRows() public {
        R.PackageFile[] memory rows = _rows(65);
        _parts(rows, true);
        _upload(bytes(Json.files(rows, true)), false);
        _fails(host, _slice(rows, 1, 64), true);
        _fails(host, _slice(rows, 0, 63), true);
        R.PackageFile memory saved = rows[64];
        rows[64] = rows[63];
        _fails(host, rows, true);
        rows[64] = saved;
        (rows[0], rows[1]) = (rows[1], rows[0]);
        _fails(host, rows, true);
        (rows[0], rows[1]) = (rows[1], rows[0]);
        rows[64].sha256Digest = bytes32(uint256(999));
        _fails(host, rows, true);
    }

    function testWrongHostChainRelativeAndExistingIdentity() public {
        R.PackageFile[] memory rows = _rows(65);
        _parts(rows, true);
        bytes memory canonical = bytes(Json.files(rows, true));
        _upload(canonical, false);
        _fails(new InventoryPreparationHost(address(store)), rows, true);
        _fails(host, rows, false);
        // Read the immutable fixture anchor: CHAINID may be re-read by the optimizer
        // across a cheatcode, because ordinary transactions cannot change it.
        uint256 chain = host.deploymentChain();
        vm.chainId(chain + 1);
        _fails(host, rows, true);
        vm.chainId(chain);
        bytes32 id = host.prepareFileInventoryFromParts(rows, true);
        require(
            host.prepareFileInventoryFromParts(rows, true) == id
                && host.prepareOriginal(rows, true) == id
        );
        require(keccak256(host.read(id)) == keccak256(canonical));
    }

    function testOriginalInventoryExistsBeforeStages() public {
        R.PackageFile[] memory rows = _rows(2);
        bytes memory raw = bytes(Json.files(rows, true));
        _upload(raw, false);
        bytes32 id = host.prepareOriginal(rows, true);
        require(host.prepareFileInventoryFromParts(rows, true) == id);
    }

    function testLateMissingFullChunkRollsBackAndRetries() public {
        R.PackageFile[] memory rows = _rows(65);
        _parts(rows, true);
        bytes memory raw = bytes(Json.files(rows, true));
        require(raw.length > 8192);
        _upload(raw, true);
        bytes32 id = host.originalId(rows, true);
        _fails(host, rows, true);
        (bytes32 hash, uint32 length, uint256 pointers, uint256 hashes) = host.state(id);
        require(hash == 0 && length == 0 && pointers == 0 && hashes == 0, "atomic late failure");
        _upload(raw, false);
        require(host.prepareFileInventoryFromParts(rows, true) == id);
    }

    function testPartBoundsAndEmptyOriginal() public {
        (bool empty,) =
            address(host).call(abi.encodeCall(host.prepareFileInventoryPart, (_rows(0), true)));
        (bool tooMany,) =
            address(host).call(abi.encodeCall(host.prepareFileInventoryPart, (_rows(65), true)));
        require(!empty && !tooMany);
        _upload(bytes("[]"), false);
        bytes32 id = host.prepareFileInventoryFromParts(_rows(0), true);
        require(keccak256(host.read(id)) == keccak256("[]"));
    }
}
