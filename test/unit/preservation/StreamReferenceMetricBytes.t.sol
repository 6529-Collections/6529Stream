// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceMetricBytes as Fast
} from "../../../smart-contracts/domains/preservation/StreamReferenceMetricBytes.sol";
import {
    StreamSnapshotManifestBytes as Original
} from "../../../smart-contracts/domains/records/StreamSnapshotManifestBytes.sol";
import {
    StreamSchemaDocumentStore as Store
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    StreamReferenceModeManifestAdoption as Integrity
} from "../../../smart-contracts/domains/preservation/StreamReferenceModeManifestAdoption.sol";

interface MetricBytesVm {
    function etch(address, bytes calldata) external;
    function readFileBinary(string calldata) external view returns (bytes memory);
}

contract MetricBytesProbe {
    uint256 public beforeCanary = 123;
    mapping(bytes32 => Original.Manifest) private manifests;
    uint256 public afterCanary = 456;
    uint256 public attemptedWrites;
    Store public immutable store = new Store();

    function seed(bytes32 key, bytes memory raw) external {
        for (uint256 offset; offset < raw.length; offset += 8192) {
            uint256 n = raw.length - offset;
            if (n > 8192) n = 8192;
            bytes memory part = new bytes(n);
            for (uint256 j; j < n; j += 32) {
                assembly ("memory-safe") {
                    mstore(add(add(part, 32), j), mload(add(add(raw, 32), add(offset, j))))
                }
            }
            store.publishChunk(part);
        }
        Original.retain(manifests[key], address(store), raw);
    }

    function original(bytes32 key) external view returns (bytes memory) {
        return Original.read(manifests[key]);
    }

    function current(bytes32 key) external view returns (bytes memory) {
        return Fast.read(manifests[key]);
    }

    function prefixed(bytes32 key) external view returns (bytes memory raw) {
        (bytes memory backing, bytes memory payload) = Fast.readContext(manifests[key]);
        require(backing.length == payload.length + 320, "prefix length");
        uint256 a;
        uint256 b;
        assembly ("memory-safe") {
            a := backing
            b := payload
        }
        require(b == a + 320, "prefix alias");
        return payload;
    }

    function intact(bytes32 key) external view returns (bytes32) {
        return Fast.requireIntact(manifests[key]);
    }

    function fixedIntact(bytes32 key) external view returns (bytes32) {
        return Integrity.requireIntact(manifests[key]);
    }

    function pointer(bytes32 key, uint256 index) external view returns (address) {
        return manifests[key].pointers[index];
    }

    function fingerprint(bytes32 key) external view returns (bytes32) {
        return keccak256(abi.encode(beforeCanary, manifests[key], afterCanary, attemptedWrites));
    }

    function mutate(bytes32 key, uint8 kind) external {
        Original.Manifest storage m = manifests[key];
        if (kind == 0) m.byteLength = 0;
        if (kind == 1) m.byteLength = 524289;
        if (kind == 2) m.pointers.pop();
        if (kind == 3) m.chunkHashes.pop();
        if (kind == 4) m.contentHash ^= bytes32(uint256(1));
        if (kind == 5) m.chunkHashes[0] ^= bytes32(uint256(1));
        if (kind == 6) m.pointers[0] = address(0x1234);
        if (kind == 7) (m.pointers[0], m.pointers[1]) = (m.pointers[1], m.pointers[0]);
        if (kind == 8) m.byteLength -= 1;
    }

    function readAndMutate(bytes32 key) external returns (bytes32 h) {
        h = Integrity.requireIntact(manifests[key]);
        ++attemptedWrites;
    }
}

/// @dev Actual immutable Store and original public reader are independent byte/error oracles.
/// High-budget setup of the maximum corpus is not a per-transaction publication capacity claim.
contract StreamReferenceMetricBytesTest {
    MetricBytesVm constant vm =
        MetricBytesVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 constant KEY = keccak256("first typed manifest");
    bytes32 constant OTHER = keccak256("adjacent independent typed manifest");
    MetricBytesProbe private probe;

    function setUp() public {
        probe = new MetricBytesProbe();
    }

    function _bytes(uint256 length) private pure returns (bytes memory raw) {
        raw = new bytes(length);
        for (uint256 i; i < length; i += 32) {
            bytes32 word = keccak256(abi.encode(i, length));
            assembly ("memory-safe") { mstore(add(add(raw, 32), i), word) }
        }
    }

    function _parity(bytes32 key, bytes memory expected) private view {
        bytes32 before_ = probe.fingerprint(key);
        require(keccak256(probe.original(key)) == keccak256(expected));
        require(keccak256(probe.current(key)) == keccak256(expected));
        require(keccak256(probe.prefixed(key)) == keccak256(expected));
        require(probe.intact(key) == keccak256(expected));
        require(probe.fixedIntact(key) == keccak256(expected));
        require(
            probe.fingerprint(key) == before_ && probe.beforeCanary() == 123
                && probe.afterCanary() == 456
        );
    }

    function _failure(bytes32 key, bytes memory expected) private view {
        (bool oldOk, bytes memory oldError) =
            address(probe).staticcall(abi.encodeCall(probe.original, (key)));
        (bool newOk, bytes memory newError) =
            address(probe).staticcall(abi.encodeCall(probe.current, (key)));
        (bool fixedOk, bytes memory fixedError) =
            address(probe).staticcall(abi.encodeCall(probe.fixedIntact, (key)));
        (bool prefixOk, bytes memory prefixError) =
            address(probe).staticcall(abi.encodeCall(probe.prefixed, (key)));
        require(!prefixOk && keccak256(prefixError) == keccak256(expected));
        require(
            !oldOk && !newOk && keccak256(oldError) == keccak256(expected)
                && keccak256(newError) == keccak256(expected) && !fixedOk
                && keccak256(fixedError) == keccak256(expected)
        );
    }

    function testBoundaryLengthsMaximumAndTypedNamespaces() public {
        uint256[8] memory lengths = [uint256(1), 31, 32, 8191, 8192, 8193, 16385, 524288];
        for (uint256 i; i < lengths.length; ++i) {
            bytes32 key = keccak256(abi.encode(KEY, i));
            bytes memory raw = _bytes(lengths[i]);
            probe.seed(key, raw);
            _parity(key, raw);
        }
        _failure(OTHER, abi.encodeWithSelector(Original.InvalidSnapshotManifest.selector));
    }

    function testFullRetainedSupplementBytesMatchOriginal() public {
        bytes memory raw =
            vm.readFileBinary("test/fixtures/preservation/reference-metric-replay-v1.abi");
        require(raw.length > 200000);
        probe.seed(KEY, raw);
        probe.seed(OTHER, bytes("separate original record"));
        _parity(KEY, raw);
        _parity(OTHER, bytes("separate original record"));
    }

    function testMalformedCountSizeOrderHashesAndWrongSlotMatchOriginalErrors() public {
        for (uint8 kind; kind < 9; ++kind) {
            MetricBytesProbe local = new MetricBytesProbe();
            local.seed(KEY, _bytes(8193));
            address first = local.pointer(KEY, 0);
            address last = local.pointer(KEY, 1);
            local.mutate(KEY, kind);
            (bool oldOk, bytes memory a) =
                address(local).staticcall(abi.encodeCall(local.original, (KEY)));
            (bool newOk, bytes memory b) =
                address(local).staticcall(abi.encodeCall(local.current, (KEY)));
            (bool fixedOk, bytes memory c) =
                address(local).staticcall(abi.encodeCall(local.fixedIntact, (KEY)));
            bytes memory expected = kind <= 4 || kind == 8
                ? abi.encodeWithSelector(Original.InvalidSnapshotManifest.selector)
                : abi.encodeWithSelector(
                    Original.SnapshotChunkChanged.selector,
                    kind == 6 ? address(0x1234) : kind == 7 ? last : first
                );
            require(
                !oldOk && !newOk && keccak256(a) == keccak256(expected)
                    && keccak256(b) == keccak256(expected) && !fixedOk
                    && keccak256(c) == keccak256(expected)
            );
        }
    }

    function testExactLengthStopAndDigestCorruptionThenRestore() public {
        bytes memory raw = _bytes(8193);
        probe.seed(KEY, raw);
        address p = probe.pointer(KEY, 1);
        bytes memory code = p.code;
        for (uint256 i; i < 3; ++i) {
            bytes memory changed = abi.encodePacked(code);
            if (i == 0) changed = bytes("");
            if (i == 1) changed[0] = 0x01;
            if (i == 2) changed[1] = bytes1(uint8(changed[1]) ^ 1);
            vm.etch(p, changed);
            _failure(KEY, abi.encodeWithSelector(Original.SnapshotChunkChanged.selector, p));
            vm.etch(p, code);
            _parity(KEY, raw);
        }
    }

    function testForcedStaticCallReadsCannotMutateHostOrManifest() public {
        bytes memory raw = _bytes(16385);
        probe.seed(KEY, raw);
        bytes32 before_ = probe.fingerprint(KEY);
        (bool ok, bytes memory out) =
            address(probe).staticcall(abi.encodeCall(probe.current, (KEY)));
        require(ok && keccak256(abi.decode(out, (bytes))) == keccak256(raw));
        (bool denied,) =
            address(probe).staticcall{ gas: 3000000 }(abi.encodeCall(probe.readAndMutate, (KEY)));
        require(!denied && probe.attemptedWrites() == 0 && probe.fingerprint(KEY) == before_);
        _parity(KEY, raw);
    }

    function testFuzzOriginalByteParity(uint16 length, bytes32 seed) public {
        uint256 size = 1 + uint256(length) % 18000;
        bytes memory raw = _bytes(size);
        if (size >= 32) assembly ("memory-safe") { mstore(add(raw, 32), seed) }
        probe.seed(KEY, raw);
        _parity(KEY, raw);
    }
}
