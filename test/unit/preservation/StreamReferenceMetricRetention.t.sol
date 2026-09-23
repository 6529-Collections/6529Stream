// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamReferenceMetricRetention as Fast
} from "../../../smart-contracts/domains/preservation/StreamReferenceMetricRetention.sol";
import {
    StreamSnapshotManifestBytes as Bytes
} from "../../../smart-contracts/domains/records/StreamSnapshotManifestBytes.sol";
import {
    StreamSchemaDocumentStore as Store
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";

interface MetricRetentionVm {
    function readFileBinary(string calldata path) external view returns (bytes memory);
    function load(address target, bytes32 slot) external view returns (bytes32);
    function store(address target, bytes32 slot, bytes32 value) external;
    function etch(address target, bytes calldata code) external;
}

/// @dev Separate old/new storage paths, surrounded by ordinary storage canaries and a third
/// independently retained record. Descriptor and incomplete-storage setters are test-only;
/// they do not represent external entrypoints of the fixed metric publication host.
contract MetricRetentionProbe {
    uint256 public beforeCanary = 123;
    Bytes.Manifest private original;
    uint256 public betweenCanary = 789;
    Bytes.Manifest private current;
    uint256 public afterCanary = 456;
    Bytes.Manifest private adjacent;
    bytes32 public immutable originalAdjacentManifestHash;
    uint256 public attemptedWrites;
    bool public currentAttempt;

    constructor(Store source) {
        bytes memory neighbor = bytes("independent adjacent canonical manifest");
        source.publishChunk(neighbor);
        Bytes.retain(adjacent, address(source), neighbor);
        originalAdjacentManifestHash = keccak256(abi.encode(adjacent));
    }

    function describe(bytes memory raw) external pure returns (Fast.Payload memory) {
        return _describeGuarded(raw);
    }

    function originalRetain(address source, bytes memory raw) external returns (bytes32) {
        ++attemptedWrites;
        currentAttempt = false;
        return Bytes.retain(original, source, raw);
    }

    function currentRetain(address source, bytes memory raw) external returns (bytes32) {
        ++attemptedWrites;
        currentAttempt = true;
        return Fast.retain(current, source, _describeGuarded(raw));
    }

    function descriptorRetain(address source, Fast.Payload memory descriptor)
        external
        returns (bytes32)
    {
        ++attemptedWrites;
        currentAttempt = true;
        return Fast.retain(current, source, descriptor);
    }

    function manifest(bool useCurrent) external view returns (Bytes.Manifest memory) {
        if (useCurrent) return current;
        return original;
    }

    function read(bool useCurrent) external view returns (bytes memory) {
        if (useCurrent) return Bytes.read(current);
        return Bytes.read(original);
    }

    function neighbor() external view returns (bytes memory) {
        return Bytes.read(adjacent);
    }

    function adjacentManifestHash() external view returns (bytes32) {
        return keccak256(abi.encode(adjacent));
    }

    function fingerprint() external view returns (bytes32) {
        return keccak256(
            abi.encode(
                beforeCanary,
                original,
                betweenCanary,
                current,
                afterCanary,
                adjacent,
                attemptedWrites,
                currentAttempt
            )
        );
    }

    function seedIncompleteManifests() external {
        require(original.byteLength == 0 && current.byteLength == 0, "empty test setup");
        original.contentHash = current.contentHash = keccak256("incomplete original header");
        original.pointers.push(address(0x5151));
        current.pointers.push(address(0x5151));
        original.chunkHashes.push(keccak256("incomplete original chunk"));
        current.chunkHashes.push(keccak256("incomplete original chunk"));
    }

    function _describeGuarded(bytes memory raw) private pure returns (Fast.Payload memory result) {
        bytes memory left = bytes("left memory canary across a complete word boundary");
        bytes memory canonical = abi.encodePacked(raw);
        bytes memory right =
            bytes("right memory canary across a complete word boundary and its tail");
        bytes32 leftHash = keccak256(left);
        bytes32 rightHash = keccak256(right);
        bytes32 rawHash = keccak256(raw);
        uint256 length = canonical.length;
        result = Fast.describe(canonical);
        require(
            keccak256(left) == leftHash && keccak256(right) == rightHash
                && canonical.length == length && keccak256(canonical) == rawHash
                && raw.length == length && keccak256(raw) == rawHash,
            "describe preserves canonical input and neighboring memory"
        );
    }
}

/// @dev Labelled fault observer only: every successful pointer comes from the genuine Store.
/// It observes the actual caller's partial manifest during the third lookup, then can fail.
/// This proves rollback after preceding pushes rather than merely an early empty-state revert.
contract MetricRetentionLateStoreFault {
    error ObservedLateRetentionFault(uint256 priorChunks);
    Store private immutable source;
    MetricRetentionProbe private immutable probe;
    bytes32[] private expected;
    bool public failing = true;

    constructor(Store source_, MetricRetentionProbe probe_, bytes32[] memory hashes) {
        source = source_;
        probe = probe_;
        expected = hashes;
    }

    function disableFault() external {
        failing = false;
    }

    function chunk(bytes32 hash) external view returns (address pointer, uint32 length) {
        uint256 index;
        while (index < expected.length && expected[index] != hash) ++index;
        require(index < expected.length, "only original ordered chunk queries");
        Bytes.Manifest memory observed = probe.manifest(probe.currentAttempt());
        require(
            observed.contentHash == 0 && observed.byteLength == 0
                && observed.pointers.length == index && observed.chunkHashes.length == index,
            "preceding pointer/hash pushes exist before final headers"
        );
        for (uint256 i; i < index; ++i) {
            (address previous,) = source.chunk(expected[i]);
            require(
                observed.pointers[i] == previous && observed.chunkHashes[i] == expected[i],
                "exact original prefix was written before late lookup"
            );
        }
        if (failing && index == 2) revert ObservedLateRetentionFault(2);
        return source.chunk(hash);
    }
}

/// @dev Differential component tests only. The unchanged Bytes.retain/read and actual immutable
/// Store are independent oracles. Explicit row/code fault injection and descriptor wrappers do
/// not establish public-host descriptor admission, metric publication authority, gas capacity,
/// or current-stack/Safe acceptance. Large corpus setup is not a transaction-cap claim.
contract StreamReferenceMetricRetentionTest {
    MetricRetentionVm private constant vm =
        MetricRetentionVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    Store private source;
    MetricRetentionProbe private probe;

    struct Retry {
        bytes originalCall;
        bytes currentCall;
        bytes32 beforeState;
    }

    function setUp() public {
        _fresh();
    }

    function testDescribeBoundariesPreserveInputAndOrderedIndependentSliceHashes() public view {
        uint256[8] memory lengths = [uint256(1), 31, 32, 8191, 8192, 8193, 16385, 524288];
        for (uint256 i; i < lengths.length; ++i) {
            _description(_bytes(lengths[i], bytes32(i)));
        }
    }

    function testRetainBoundariesMatchOriginalManifestAndCompleteBytes() public {
        uint256[8] memory lengths = [uint256(1), 31, 32, 8191, 8192, 8193, 16385, 524288];
        for (uint256 i; i < lengths.length; ++i) {
            _fresh();
            bytes memory raw = _bytes(lengths[i], bytes32(i));
            _publish(raw, type(uint256).max);
            _runPair(address(source), raw);
        }
    }

    function testComplete219264ByteCheckedMetricFixtureMatchesOriginal() public {
        bytes memory raw =
            vm.readFileBinary("test/fixtures/preservation/reference-metric-replay-v1.abi");
        require(raw.length == 219264, "exact checked fixture length, not synthetic 219744");
        require(
            sha256(raw) == hex"919d2fd5eb99d921fc71442d46d2bc6d5bccc0ec77ab503d69bcb70a5f95b1fb",
            "complete checked fixture bytes"
        );
        _publish(raw, type(uint256).max);
        _description(raw);
        _runPair(address(source), raw);
    }

    function testSynthetic219744BytePayloadMatchesOriginal() public {
        bytes memory raw = _bytes(219744, keccak256("synthetic length control only"));
        _publish(raw, type(uint256).max);
        _runPair(address(source), raw);
    }

    function testZerosAndRepeatedChunksKeepOrderedDuplicatePointers() public {
        bytes memory raw = new bytes(16385);
        _publish(raw, type(uint256).max);
        _runPair(address(source), raw);
        Bytes.Manifest memory saved = probe.manifest(true);
        require(
            saved.pointers.length == 3 && saved.pointers[0] == saved.pointers[1]
                && saved.chunkHashes[0] == saved.chunkHashes[1]
                && saved.pointers[2] != saved.pointers[0],
            "zero chunks preserve repeated full segments and distinct one-byte tail"
        );
        _fresh();
        bytes memory full = _bytes(8192, keccak256("nonzero repeated chunk"));
        raw = bytes.concat(full, full, full, _slice(full, 0, 31));
        _publish(raw, type(uint256).max);
        _runPair(address(source), raw);
        saved = probe.manifest(true);
        require(
            saved.pointers.length == 4 && saved.pointers[0] == saved.pointers[1]
                && saved.pointers[1] == saved.pointers[2]
                && saved.chunkHashes[0] == saved.chunkHashes[2]
                && saved.pointers[3] != saved.pointers[0],
            "no deduplication of ordered manifest positions"
        );
    }

    function testZeroAndOverMaximumLengthsMatchOriginalGuardAndRollback() public {
        _pairFailure(address(source), bytes(""), _invalid());
        _pairFailure(address(source), new bytes(524289), _invalid());
        (bool ok, bytes memory reason) =
            address(probe).staticcall(abi.encodeCall(probe.describe, (new bytes(524289))));
        require(
            !ok && keccak256(reason) == keccak256(_invalid()), "describe has the same finite bound"
        );
    }

    function testMissingFirstChunkRollsBackAndRetriesIdenticalCalls() public {
        _missing(0);
    }

    function testMissingMiddleChunkRollsBackAndRetriesIdenticalCalls() public {
        _missing(1);
    }

    function testMissingLastChunkRollsBackAndRetriesIdenticalCalls() public {
        _missing(2);
    }

    function testZeroPointerAndWrongStoredLengthsMatchOriginalThenExactRetry() public {
        for (uint256 fault; fault < 4; ++fault) {
            _fresh();
            bytes memory raw = _bytes(16385, bytes32(fault));
            _publish(raw, type(uint256).max);
            bytes32 hash = keccak256(_slice(raw, 8192, 8192));
            (address pointer, uint32 size) = source.chunk(hash);
            bytes32 slot = _rowSlot(hash);
            bytes32 row = vm.load(address(source), slot);
            _setRow(
                hash,
                fault == 0 ? address(0) : pointer,
                fault == 0 ? size : fault == 1 ? uint32(0) : fault == 2 ? size - 1 : size + 1
            );
            Retry memory retry = _pairFailure(address(source), raw, _unavailable(hash));
            vm.store(address(source), slot, row);
            _retry(retry, raw);
        }
    }

    function testStoredLengthRefusalPrecedesWrongPointerCode() public {
        bytes memory raw = _bytes(16385, keccak256("error precedence"));
        _publish(raw, type(uint256).max);
        bytes32 hash = keccak256(_slice(raw, 8192, 8192));
        bytes32 slot = _rowSlot(hash);
        bytes32 row = vm.load(address(source), slot);
        address wrong = address(0x1234);
        require(wrong.code.length == 0, "explicit missing runtime fault");
        _setRow(hash, wrong, 8191);
        _pairFailure(address(source), raw, _unavailable(hash));
        _setRow(hash, wrong, 8192);
        Retry memory retry = _pairFailure(address(source), raw, _changed(wrong));
        vm.store(address(source), slot, row);
        _retry(retry, raw);
    }

    function testWrongPublishedPointerSameLengthFailsHashThenExactRetry() public {
        bytes memory raw = _bytes(16385, keccak256("wrong immutable pointer"));
        _publish(raw, type(uint256).max);
        bytes32 firstHash = keccak256(_slice(raw, 0, 8192));
        bytes32 middleHash = keccak256(_slice(raw, 8192, 8192));
        (address first,) = source.chunk(firstHash);
        bytes32 slot = _rowSlot(middleHash);
        bytes32 row = vm.load(address(source), slot);
        _setRow(middleHash, first, 8192);
        Retry memory retry = _pairFailure(address(source), raw, _changed(first));
        vm.store(address(source), slot, row);
        _retry(retry, raw);
    }

    function testFirstAndLastRuntimeLengthStopAndDigestFaultsRollbackAndRetry() public {
        for (uint256 position; position < 2; ++position) {
            for (uint256 kind; kind < 4; ++kind) {
                _fresh();
                bytes memory raw = _bytes(16385, bytes32(position * 10 + kind));
                _publish(raw, type(uint256).max);
                uint256 offset = position == 0 ? 0 : 16384;
                uint256 size = position == 0 ? 8192 : 1;
                (address pointer,) = source.chunk(keccak256(_slice(raw, offset, size)));
                bytes memory originalCode = pointer.code;
                bytes memory changed = abi.encodePacked(originalCode);
                if (kind == 0) changed = bytes("");
                if (kind == 1) changed = bytes.concat(changed, hex"00");
                if (kind == 2) changed[0] = 0x01;
                if (kind == 3) changed[changed.length - 1] ^= bytes1(uint8(1));
                vm.etch(pointer, changed);
                Retry memory retry = _pairFailure(address(source), raw, _changed(pointer));
                vm.etch(pointer, originalCode);
                _retry(retry, raw);
            }
        }
    }

    function testNonemptyManifestGuardPrecedesUnavailableStoreAndDescriptorErrors() public {
        bytes memory raw = _bytes(8193, keccak256("finalized manifest"));
        _publish(raw, type(uint256).max);
        _runPair(address(source), raw);
        // Address zero would fail ABI decoding if either path reached Store.chunk.
        _pairFailure(address(0), raw, _invalid());
        Fast.Payload memory malformed = probe.describe(raw);
        malformed.byteLength = 0;
        malformed.chunkHashes = new bytes32[](0);
        _descriptorFailure(address(0), malformed, _invalid());
        _parity(raw);
    }

    function testLateStoreFaultObservesPriorPushesAndEmptyHeadersThenExactRetry() public {
        bytes memory raw = _bytes(16385, keccak256("three distinct prefix observations"));
        _publish(raw, type(uint256).max);
        Fast.Payload memory descriptor = _description(raw);
        MetricRetentionLateStoreFault fault =
            new MetricRetentionLateStoreFault(source, probe, descriptor.chunkHashes);
        Retry memory retry = _pairFailure(
            address(fault),
            raw,
            abi.encodeWithSelector(
                MetricRetentionLateStoreFault.ObservedLateRetentionFault.selector, uint256(2)
            )
        );
        fault.disableFault();
        _retry(retry, raw);
    }

    function testDescriptorLengthAndCountGuardsRejectBeforeStoreLookup() public {
        bytes memory raw = _bytes(16385, keccak256("descriptor count controls"));
        for (uint256 kind; kind < 5; ++kind) {
            Fast.Payload memory p = probe.describe(raw);
            if (kind == 0) p.byteLength = 0;
            if (kind == 1) p.byteLength = 524289;
            if (kind == 2) p.chunkHashes = new bytes32[](0);
            if (kind == 3) p.chunkHashes = new bytes32[](2);
            if (kind == 4) p.chunkHashes = new bytes32[](4);
            _descriptorFailure(address(0), p, _invalid());
        }
        _publish(raw, type(uint256).max);
        _runPair(address(source), raw);
    }

    function testDescriptorChangedPartialLengthRefusesExactTailHash() public {
        bytes memory raw = _bytes(16385, keccak256("partial-length mutant"));
        _publish(raw, type(uint256).max);
        Fast.Payload memory p = probe.describe(raw);
        p.byteLength += 1; // Same three entries, but the actual final Store chunk is one byte.
        _descriptorFailure(address(source), p, _unavailable(p.chunkHashes[2]));
        _runPair(address(source), raw);
    }

    function testDescriptorMissingFirstMiddleLastHashesRejectWithoutStateDrift() public {
        bytes memory raw = _bytes(16385, keccak256("descriptor hash controls"));
        _publish(raw, type(uint256).max);
        for (uint256 i; i < 3; ++i) {
            Fast.Payload memory p = probe.describe(raw);
            bytes32 absent = keccak256(abi.encode("not a published chunk", i));
            (address missing,) = source.chunk(absent);
            require(missing == address(0), "explicit unregistered descriptor hash");
            p.chunkHashes[i] = absent;
            _descriptorFailure(address(source), p, _unavailable(absent));
        }
        // Repairing a descriptor changes the test-only call; this is not an identical retry claim.
        _runPair(address(source), raw);
    }

    function testDescriptorFalseWholeHashIsCaughtByUnchangedReader() public {
        bytes memory raw = _bytes(8193, keccak256("trusted descriptor hash boundary"));
        _publish(raw, type(uint256).max);
        Fast.Payload memory p = probe.describe(raw);
        p.contentHash ^= bytes32(uint256(1));
        require(
            probe.descriptorRetain(address(source), p) == p.contentHash,
            "typed descriptor is trusted"
        );
        require(probe.manifest(true).contentHash == p.contentHash, "supplied header stored exactly");
        _readFailure(true, _invalid());
        require(
            probe.originalRetain(address(source), raw) == keccak256(raw),
            "independent original succeeds"
        );
        _same(probe.read(false), raw);
        _canaries();
    }

    function testDescriptorReorderedHashesWithoutMatchingWholeHashFailOriginalRead() public {
        bytes memory raw = _bytes(16385, keccak256("ordered hash mutant"));
        _publish(raw, type(uint256).max);
        Fast.Payload memory p = probe.describe(raw);
        (p.chunkHashes[0], p.chunkHashes[1]) = (p.chunkHashes[1], p.chunkHashes[0]);
        probe.descriptorRetain(address(source), p);
        _readFailure(true, _invalid());
        require(
            probe.originalRetain(address(source), raw) == keccak256(raw), "original order succeeds"
        );
        _same(probe.read(false), raw);
        _canaries();
    }

    function testDescriptorPermutationMatchesOriginalForCorrespondingCanonicalBytes() public {
        bytes memory raw = _bytes(16385, keccak256("valid reordered canonical bytes"));
        _publish(raw, type(uint256).max);
        Fast.Payload memory p = probe.describe(raw);
        bytes memory reordered =
            bytes.concat(_slice(raw, 8192, 8192), _slice(raw, 0, 8192), _slice(raw, 16384, 1));
        (p.chunkHashes[0], p.chunkHashes[1]) = (p.chunkHashes[1], p.chunkHashes[0]);
        p.contentHash = keccak256(reordered);
        require(
            probe.originalRetain(address(source), reordered) == p.contentHash,
            "original reordered canonical authority"
        );
        require(
            probe.descriptorRetain(address(source), p) == p.contentHash,
            "same typed reordered payload"
        );
        _parity(reordered);
    }

    function testZeroLengthIncompleteStoragePreservesOriginalAppendSemantics() public {
        bytes memory raw = _bytes(32, keccak256("partial storage qualification"));
        _publish(raw, type(uint256).max);
        probe.seedIncompleteManifests();
        require(probe.originalRetain(address(source), raw) == keccak256(raw));
        require(probe.currentRetain(address(source), raw) == keccak256(raw));
        Bytes.Manifest memory oldSaved = probe.manifest(false);
        Bytes.Manifest memory newSaved = probe.manifest(true);
        _same(abi.encode(oldSaved), abi.encode(newSaved));
        require(
            newSaved.byteLength == 32 && newSaved.pointers.length == 2
                && newSaved.chunkHashes.length == 2 && newSaved.pointers[0] == address(0x5151)
                && newSaved.chunkHashes[0] == keccak256("incomplete original chunk"),
            "only original byteLength guard, no invented empty-array requirement"
        );
        _readFailure(false, _invalid());
        _readFailure(true, _invalid());
        _canaries();
    }

    function testFuzzDescribeRetainAndReadMatchOriginal(uint16 length, bytes32 seed) public {
        bytes memory raw = _bytes(1 + uint256(length) % 18000, seed);
        _description(raw);
        _publish(raw, type(uint256).max);
        _runPair(address(source), raw);
    }

    function _fresh() private {
        source = new Store();
        probe = new MetricRetentionProbe(source);
    }

    function _bytes(uint256 length, bytes32 seed) private pure returns (bytes memory raw) {
        raw = new bytes(length);
        for (uint256 i; i < length; i += 32) {
            bytes32 word = keccak256(abi.encode(seed, length, i));
            assembly ("memory-safe") { mstore(add(add(raw, 32), i), word) }
        }
    }

    function _slice(bytes memory raw, uint256 offset, uint256 length)
        private
        pure
        returns (bytes memory part)
    {
        require(offset + length <= raw.length, "independent slice bounds");
        part = new bytes(length);
        for (uint256 i; i < length; ++i) {
            part[i] = raw[offset + i];
        }
    }

    function _description(bytes memory raw) private view returns (Fast.Payload memory p) {
        p = probe.describe(raw);
        require(
            p.contentHash == keccak256(raw) && p.byteLength == raw.length
                && p.chunkHashes.length == (raw.length + 8191) / 8192,
            "exact full digest, width and count from canonical bytes"
        );
        for (uint256 i; i < p.chunkHashes.length; ++i) {
            uint256 n = raw.length - i * 8192;
            if (n > 8192) n = 8192;
            require(
                p.chunkHashes[i] == keccak256(_slice(raw, i * 8192, n)),
                "independent exact slice hash and order"
            );
        }
    }

    function _publish(bytes memory raw, uint256 skip) private {
        for (uint256 offset; offset < raw.length; offset += 8192) {
            if (offset / 8192 == skip) continue;
            uint256 n = raw.length - offset;
            if (n > 8192) n = 8192;
            bytes memory part = _slice(raw, offset, n);
            (bytes32 hash, address pointer) = source.publishChunk(part);
            require(
                hash == keccak256(part) && pointer.code.length == n + 1,
                "actual immutable Store publication"
            );
        }
    }

    function _calls(address store, bytes memory raw) private view returns (Retry memory r) {
        r.originalCall = abi.encodeCall(probe.originalRetain, (store, raw));
        r.currentCall = abi.encodeCall(probe.currentRetain, (store, raw));
        r.beforeState = probe.fingerprint();
    }

    function _pairFailure(address store, bytes memory raw, bytes memory expected)
        private
        returns (Retry memory r)
    {
        r = _calls(store, raw);
        (bool oldOk, bytes memory oldError) = address(probe).call(r.originalCall);
        require(
            !oldOk && keccak256(oldError) == keccak256(expected), "exact unchanged original failure"
        );
        require(
            probe.fingerprint() == r.beforeState, "original writes and neighboring record roll back"
        );
        (bool newOk, bytes memory newError) = address(probe).call(r.currentCall);
        require(
            !newOk && keccak256(newError) == keccak256(expected),
            "exact matching new selector and arguments"
        );
        require(
            probe.fingerprint() == r.beforeState,
            "new pushes, headers, attempt writes and neighbors roll back"
        );
        _canaries();
    }

    function _retry(Retry memory r, bytes memory raw) private {
        require(
            probe.fingerprint() == r.beforeState, "repair touched only the external fault source"
        );
        bytes32 oldInput = keccak256(r.originalCall);
        bytes32 newInput = keccak256(r.currentCall);
        (bool oldOk, bytes memory oldOut) = address(probe).call(r.originalCall);
        (bool newOk, bytes memory newOut) = address(probe).call(r.currentCall);
        require(
            oldOk && newOk && oldOut.length == 32 && newOut.length == 32
                && abi.decode(oldOut, (bytes32)) == keccak256(raw)
                && keccak256(oldOut) == keccak256(newOut) && keccak256(r.originalCall) == oldInput
                && keccak256(r.currentCall) == newInput,
            "complete byte-identical original and new calls succeed after fault repair"
        );
        _parity(raw);
    }

    function _runPair(address store, bytes memory raw) private {
        _retry(_calls(store, raw), raw);
    }

    function _parity(bytes memory raw) private view {
        Bytes.Manifest memory a = probe.manifest(false);
        Bytes.Manifest memory b = probe.manifest(true);
        _same(abi.encode(a), abi.encode(b));
        require(
            b.contentHash == keccak256(raw) && b.byteLength == raw.length
                && b.pointers.length == (raw.length + 8191) / 8192
                && b.chunkHashes.length == b.pointers.length && probe.attemptedWrites() == 2,
            "same complete manifest layout and exactly one successful write per path"
        );
        _same(probe.read(false), raw);
        _same(probe.read(true), raw);
        _canaries();
    }

    function _canaries() private view {
        require(
            probe.beforeCanary() == 123 && probe.betweenCanary() == 789
                && probe.afterCanary() == 456
                && probe.adjacentManifestHash() == probe.originalAdjacentManifestHash(),
            "adjacent storage words remain unchanged"
        );
        _same(probe.neighbor(), bytes("independent adjacent canonical manifest"));
    }

    function _descriptorFailure(address store, Fast.Payload memory p, bytes memory expected)
        private
    {
        bytes32 beforeState = probe.fingerprint();
        (bool ok, bytes memory reason) =
            address(probe).call(abi.encodeCall(probe.descriptorRetain, (store, p)));
        require(!ok && keccak256(reason) == keccak256(expected), "exact typed descriptor refusal");
        require(probe.fingerprint() == beforeState, "descriptor failure restores all host state");
        _canaries();
    }

    function _readFailure(bool current, bytes memory expected) private view {
        (bool ok, bytes memory reason) =
            address(probe).staticcall(abi.encodeCall(probe.read, (current)));
        require(
            !ok && keccak256(reason) == keccak256(expected),
            "unchanged reader rejects inconsistent descriptor bytes"
        );
    }

    function _missing(uint256 index) private {
        bytes memory raw = _bytes(16385, bytes32(index));
        _publish(raw, index);
        uint256 n = index == 2 ? 1 : 8192;
        bytes memory part = _slice(raw, index * 8192, n);
        Retry memory retry = _pairFailure(address(source), raw, _unavailable(keccak256(part)));
        source.publishChunk(part);
        _retry(retry, raw);
    }

    function _rowSlot(bytes32 hash) private pure returns (bytes32) {
        // Actual Store has one mapping at slot zero; its Chunk packs address then uint32 length.
        return keccak256(abi.encode(hash, uint256(0)));
    }

    function _setRow(bytes32 hash, address pointer, uint32 size) private {
        vm.store(
            address(source),
            _rowSlot(hash),
            bytes32(uint256(uint160(pointer)) | (uint256(size) << 160))
        );
        (address actual, uint32 actualSize) = source.chunk(hash);
        require(
            actual == pointer && actualSize == size, "fault targets the actual public Store row"
        );
    }

    function _same(bytes memory a, bytes memory b) private pure {
        require(a.length == b.length && keccak256(a) == keccak256(b), "exact complete bytes");
    }

    function _invalid() private pure returns (bytes memory) {
        return abi.encodeWithSelector(Bytes.InvalidSnapshotManifest.selector);
    }

    function _unavailable(bytes32 hash) private pure returns (bytes memory) {
        return abi.encodeWithSelector(Bytes.SnapshotChunkUnavailable.selector, hash);
    }

    function _changed(address pointer) private pure returns (bytes memory) {
        return abi.encodeWithSelector(Bytes.SnapshotChunkChanged.selector, pointer);
    }
}
