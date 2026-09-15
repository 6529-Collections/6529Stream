// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/preservation/StreamArweaveCheckpointVerifier.sol";
import "../../helpers/OfficialSafeFixture.sol";

interface ArchivalTestVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function warp(uint256 timestamp) external;
    function prank(address actor) external;
    function expectRevert(bytes calldata errorData) external;
    function etch(address target, bytes calldata code) external;
    function parseJsonUint(string calldata json, string calldata key)
        external
        pure
        returns (uint256);
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

/// @dev Exact marker/context unit boundary; this fixture does not prove actual timelock execution.
contract ArchivalGovernanceContextFixture {
    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }

    function currentAction()
        external
        pure
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return (false, 0, 0, 0, 0, 0);
    }
}

/// @dev Deliberate ERC1271 adversary, not a substitute for the real Safe cases.
contract CheckpointSignatureAdversary {
    uint8 public mode;

    function setMode(uint8 next) external {
        mode = next;
    }

    function isValidSignature(bytes32, bytes calldata) external view returns (bytes4) {
        uint8 m = mode;
        if (m == 1) assembly ("memory-safe") { return(0, 0) }
        if (m == 2) assembly ("memory-safe") {
            mstore(0, shl(224, 0x1626ba7e))
            return(0, 64)
        }
        if (m == 3) assembly ("memory-safe") { for { } 1 { } { } }
        if (m == 4) revert("signature deliberately rejected");
        if (m == 5) return 0xffffffff;
        return 0x1626ba7e;
    }
}

contract StreamArweaveCheckpointTest is OfficialSafeFixture {
    ArchivalTestVm private constant vm =
        ArchivalTestVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    StreamArweaveCheckpointVerifier private verifier;
    address private governance;
    uint256 private keyA = 0x652901;
    uint256 private keyB = 0x652902;

    function setUp() public {
        vm.warp(1_900_000_000);
        governance = address(new ArchivalGovernanceContextFixture());
        verifier = _deploy(safeVm.addr(keyA), safeVm.addr(keyB));
    }

    function _deploy(address a, address b) private returns (StreamArweaveCheckpointVerifier) {
        A.Observer[] memory list = new A.Observer[](2);
        (a, b) = a < b ? (a, b) : (b, a);
        list[0] = A.Observer(a, keccak256("organization one"));
        list[1] = A.Observer(b, keccak256("organization two"));
        return new StreamArweaveCheckpointVerifier(
            governance,
            list,
            2,
            IStreamGasParameterHost.GasParameterConfig(
                "ARCHIVAL_ERC1271_VERIFY_GAS", 400000, 90000, 2
            )
        );
    }

    function _vector(StreamArweaveCheckpointVerifier target, string memory slot)
        private
        view
        returns (
            A.Checkpoint memory c,
            bytes memory txPath,
            bytes memory dataPath,
            bytes memory payload
        )
    {
        string memory json = safeVm.readFile(
            "test/fixtures/preservation/arweave-single-chunk-v1.json"
        );
        payload = safeVm.parseJsonBytes(json, string.concat(slot, ".payload"));
        txPath = safeVm.parseJsonBytes(json, string.concat(slot, ".transactionPath"));
        dataPath = safeVm.parseJsonBytes(json, string.concat(slot, ".dataPath"));
        c.networkId = target.networkId();
        c.blockHash = new bytes(48);
        c.blockHash[0] = 0x65;
        c.blockHeight = 1_500_000;
        c.transactionRoot =
            bytes32(safeVm.parseJsonBytes(json, string.concat(slot, ".transactionRoot")));
        c.blockDataSize = vm.parseJsonUint(json, string.concat(slot, ".blockDataSize"));
        c.transactionId = keccak256("locally attested synthetic transaction ID");
        c.dataRoot = bytes32(safeVm.parseJsonBytes(json, string.concat(slot, ".dataRoot")));
        c.dataSize = uint64(payload.length);
        c.transactionStart = vm.parseJsonUint(json, string.concat(slot, ".transactionStart"));
        c.transactionEnd = vm.parseJsonUint(json, string.concat(slot, ".transactionEnd"));
        c.observedAt = uint64(block.timestamp);
        c.configurationHash = target.configurationHash();
    }

    function _sign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = safeVm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _proofs(bytes32 digest) private returns (A.ObserverProof[] memory p) {
        p = new A.ObserverProof[](2);
        p[0] = A.ObserverProof(safeVm.addr(keyA), _sign(keyA, digest));
        p[1] = A.ObserverProof(safeVm.addr(keyB), _sign(keyB, digest));
        if (p[0].account > p[1].account) (p[0], p[1]) = (p[1], p[0]);
    }

    function testNativePaddedFirstAndSecondTransactionVectors() public {
        _acceptVector(".first");
        _acceptVector(".second");
    }

    function _acceptVector(string memory slot) private {
        (A.Checkpoint memory c, bytes memory txPath, bytes memory dataPath, bytes memory payload) =
            _vector(verifier, slot);
        bytes32 digest = verifier.checkpointDigest(c);
        A.ObserverProof[] memory proofs = _proofs(digest);
        vm.recordLogs();
        bytes32 hash = verifier.recordCheckpoint(c, txPath, dataPath, payload, proofs);
        A.CheckpointFacts memory f = verifier.checkpointFacts(hash);
        require(
            f.payloadDigest == sha256(payload) && f.contentHash == keccak256(payload)
                && f.dataSize == payload.length,
            "actual bytes"
        );
        A.CheckpointRecord memory r = verifier.checkpointRecord(hash);
        require(
            keccak256(r.transactionPath) == keccak256(txPath)
                && keccak256(r.dataPath) == keccak256(dataPath),
            "paths retained"
        );
        require(
            keccak256(abi.encode(r.certificate)) == keccak256(abi.encode(proofs)),
            "certificate retained"
        );
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARCHIVAL_CHECKPOINT_RECORD_V1"),
                block.chainid,
                address(verifier),
                c,
                sha256(payload),
                keccak256(payload),
                keccak256(txPath),
                keccak256(dataPath)
            )
        );
        require(expected == hash, "record preimage");
        ArchivalTestVm.Log[] memory logs = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(verifier)) {
                ++count;
                require(
                    logs[i].topics.length == 4
                        && logs[i].topics[0]
                            == keccak256(
                                "ArchivalCheckpointRecorded(uint16,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,uint64)"
                            ),
                    "event topic"
                );
                require(
                    logs[i].topics[1] == hash && logs[i].topics[2] == c.transactionId
                        && logs[i].topics[3] == c.configurationHash,
                    "event indices"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                digest,
                                sha256(payload),
                                keccak256(payload),
                                uint64(block.timestamp)
                            )
                        ),
                    "event payload"
                );
            }
        }
        require(count == 1, "one event");
        vm.expectRevert(abi.encodeWithSelector(A.ArchivalRecordExists.selector, hash));
        verifier.recordCheckpoint(c, txPath, dataPath, payload, proofs);
    }

    function testCheckpointDomainIndependentReconstruction() public view {
        (A.Checkpoint memory c,,,) = _vector(verifier, ".first");
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Arweave Checkpoints"),
                keccak256("1"),
                block.chainid,
                address(verifier)
            )
        );
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "StreamArweaveCheckpoint(bytes32 networkId,bytes blockHash,uint64 blockHeight,bytes32 transactionRoot,uint256 blockDataSize,bytes32 transactionId,bytes32 dataRoot,uint64 dataSize,uint256 transactionStart,uint256 transactionEnd,uint64 observedAt,bytes32 configurationHash)"
                ),
                c.networkId,
                keccak256(c.blockHash),
                c.blockHeight,
                c.transactionRoot,
                c.blockDataSize,
                c.transactionId,
                c.dataRoot,
                c.dataSize,
                c.transactionStart,
                c.transactionEnd,
                c.observedAt,
                c.configurationHash
            )
        );
        require(
            verifier.checkpointDigest(c) == keccak256(abi.encodePacked(hex"1901", domain, body)),
            "domain/field order"
        );
    }

    function testQuorumCannotBeOneOrSharedOrganization() public {
        A.Observer[] memory list = verifier.observers();
        IStreamGasParameterHost.GasParameterConfig memory config =
            IStreamGasParameterHost.GasParameterConfig(
                "ARCHIVAL_ERC1271_VERIFY_GAS", 400000, 90000, 2
            );
        vm.expectRevert(abi.encodeWithSelector(A.InvalidArchivalConfiguration.selector));
        new StreamArweaveCheckpointVerifier(governance, list, 1, config);
        list[1].organizationId = list[0].organizationId;
        vm.expectRevert(abi.encodeWithSelector(A.InvalidArchivalConfiguration.selector));
        new StreamArweaveCheckpointVerifier(governance, list, 2, config);
    }

    function testQuorumMissingDuplicateWrongDomainAndHealthyRetry() public {
        (A.Checkpoint memory c, bytes memory txPath, bytes memory dataPath, bytes memory payload) =
            _vector(verifier, ".first");
        A.ObserverProof[] memory good = _proofs(verifier.checkpointDigest(c));
        A.ObserverProof[] memory shortProof = new A.ObserverProof[](1);
        shortProof[0] = good[0];
        vm.expectRevert(abi.encodeWithSelector(A.InvalidCheckpoint.selector));
        verifier.recordCheckpoint(c, txPath, dataPath, payload, shortProof);
        A.ObserverProof[] memory duplicate = new A.ObserverProof[](2);
        duplicate[0] = good[0];
        duplicate[1] = good[0];
        vm.expectRevert(abi.encodeWithSelector(A.InvalidCheckpoint.selector));
        verifier.recordCheckpoint(c, txPath, dataPath, payload, duplicate);
        A.ObserverProof[] memory wrong =
            _proofs(_domainDigest(c, block.chainid + 1, address(verifier)));
        vm.expectRevert(
            abi.encodeWithSelector(A.InvalidArchivalSignature.selector, wrong[0].account)
        );
        verifier.recordCheckpoint(c, txPath, dataPath, payload, wrong);
        wrong = _proofs(_domainDigest(c, block.chainid, address(0x123456)));
        vm.expectRevert(
            abi.encodeWithSelector(A.InvalidArchivalSignature.selector, wrong[0].account)
        );
        verifier.recordCheckpoint(c, txPath, dataPath, payload, wrong);
        require(
            verifier.recordCheckpoint(c, txPath, dataPath, payload, good) != bytes32(0),
            "same healthy certificate"
        );
    }

    function testNativeCorruptionWithValidQuorumAndHealthyRetry() public {
        (A.Checkpoint memory c, bytes memory txPath, bytes memory dataPath, bytes memory payload) =
            _vector(verifier, ".second");
        A.ObserverProof[] memory good = _proofs(verifier.checkpointDigest(c));
        txPath[10] ^= 0x01;
        vm.expectRevert(abi.encodeWithSelector(A.InvalidNativeInclusion.selector));
        verifier.recordCheckpoint(c, txPath, dataPath, payload, good);
        txPath[10] ^= 0x01;
        dataPath[1] ^= 0x01;
        vm.expectRevert(abi.encodeWithSelector(A.InvalidNativeInclusion.selector));
        verifier.recordCheckpoint(c, txPath, dataPath, payload, good);
        dataPath[1] ^= 0x01;
        payload[0] ^= 0x01;
        vm.expectRevert(abi.encodeWithSelector(A.InvalidNativeInclusion.selector));
        verifier.recordCheckpoint(c, txPath, dataPath, payload, good);
        payload[0] ^= 0x01;
        require(
            verifier.recordCheckpoint(c, txPath, dataPath, payload, good) != bytes32(0),
            "same healthy proof"
        );
    }

    function testWrongTransactionRangeAndPayloadSizeNeedNativeProof() public {
        (A.Checkpoint memory c, bytes memory txPath, bytes memory dataPath, bytes memory payload) =
            _vector(verifier, ".second");
        c.transactionStart++;
        c.transactionEnd++;
        A.ObserverProof[] memory proof = _proofs(verifier.checkpointDigest(c));
        vm.expectRevert(abi.encodeWithSelector(A.InvalidNativeInclusion.selector));
        verifier.recordCheckpoint(c, txPath, dataPath, payload, proof);
        c.transactionStart--;
        c.transactionEnd--;
        c.dataSize++;
        proof = _proofs(verifier.checkpointDigest(c));
        vm.expectRevert(abi.encodeWithSelector(A.InvalidNativeInclusion.selector));
        verifier.recordCheckpoint(c, txPath, dataPath, payload, proof);
        c.dataSize--;
        proof = _proofs(verifier.checkpointDigest(c));
        require(
            verifier.recordCheckpoint(c, txPath, dataPath, payload, proof) != bytes32(0),
            "restored exact range"
        );
    }

    function testActualThresholdSafeDirectAndRelayedCheckpointAndReads() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x652911;
        keys[1] = 0x652912;
        SafeComponents memory parts = deploySafeComponents("1.4.1");
        OfficialSafe account = createOfficialSafe(parts, safeOwnerAddresses(keys), 2, 111);
        StreamArweaveCheckpointVerifier v = _deploy(address(account), safeVm.addr(keyA));
        (A.Checkpoint memory c, bytes memory txPath, bytes memory dataPath, bytes memory payload) =
            _vector(v, ".first");
        bytes32 digest = v.checkpointDigest(c);
        A.ObserverProof[] memory p = new A.ObserverProof[](2);
        p[0] = A.ObserverProof(address(account), bytes(""));
        p[1] = A.ObserverProof(safeVm.addr(keyA), _sign(keyA, digest));
        if (p[0].account > p[1].account) (p[0], p[1]) = (p[1], p[0]);
        require(
            executeSafe(
                account,
                keys,
                address(v),
                0,
                abi.encodeCall(v.recordCheckpoint, (c, txPath, dataPath, payload, p)),
                0
            ),
            "direct Safe checkpoint"
        );
        c.blockHeight++;
        digest = v.checkpointDigest(c);
        for (uint256 i; i < 2; ++i) {
            p[i].signature = p[i].account == address(account)
                ? safeThresholdSignature(keys, safeMessageDigest(account, abi.encode(digest)))
                : _sign(keyA, digest);
        }
        bytes32 hash = v.recordCheckpoint(c, txPath, dataPath, payload, p);
        require(
            executeSafe(
                account, keys, address(v), 0, abi.encodeCall(v.checkpointRecord, (hash)), 0
            ),
            "Safe dynamic read"
        );
        require(
            executeSafe(account, keys, address(v), 0, abi.encodeCall(v.checkpointFacts, (hash)), 0),
            "Safe fixed read"
        );
        require(
            executeSafe(account, keys, address(v), 0, abi.encodeCall(v.observers, ()), 0),
            "Safe observer read"
        );
        require(
            executeSafe(account, keys, address(v), 0, abi.encodeCall(v.checkpointDigest, (c)), 0),
            "Safe digest read"
        );
    }

    function testApprovedEmptySafeRelayAndMissingOwnerRejection() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x652951;
        keys[1] = 0x652952;
        SafeComponents memory parts = deploySafeComponents("1.4.1");
        OfficialSafe account = createOfficialSafe(parts, safeOwnerAddresses(keys), 2, 151);
        StreamArweaveCheckpointVerifier v = _deploy(address(account), safeVm.addr(keyA));
        (A.Checkpoint memory c, bytes memory txPath, bytes memory dataPath, bytes memory payload) =
            _vector(v, ".first");
        bytes32 digest = v.checkpointDigest(c);
        uint256[] memory one = new uint256[](1);
        one[0] = keys[0];
        A.ObserverProof[] memory p = new A.ObserverProof[](2);
        p[0] = A.ObserverProof(
            address(account),
            safeThresholdSignature(one, safeMessageDigest(account, abi.encode(digest)))
        );
        p[1] = A.ObserverProof(safeVm.addr(keyA), _sign(keyA, digest));
        if (p[0].account > p[1].account) (p[0], p[1]) = (p[1], p[0]);
        vm.expectRevert(
            abi.encodeWithSelector(A.InvalidArchivalSignature.selector, address(account))
        );
        v.recordCheckpoint(c, txPath, dataPath, payload, p);
        for (uint256 i; i < 2; ++i) {
            if (p[i].account == address(account)) p[i].signature = bytes("");
        }
        vm.expectRevert(
            abi.encodeWithSelector(A.InvalidArchivalSignature.selector, address(account))
        );
        v.recordCheckpoint(c, txPath, dataPath, payload, p);
        require(
            executeSafe(
                account,
                keys,
                parts.signMessage,
                0,
                abi.encodeWithSignature("signMessage(bytes)", abi.encode(digest)),
                1
            ),
            "approve exact Safe message"
        );
        require(
            v.recordCheckpoint(c, txPath, dataPath, payload, p) != bytes32(0),
            "approved-empty relayed certificate"
        );
    }

    function testDesignatedEOAOwnKeyAndWrongKeyRejection() public {
        address observer = safeVm.addr(keyA);
        vm.etch(observer, abi.encodePacked(hex"ef0100", address(0x123456)));
        (A.Checkpoint memory c, bytes memory txPath, bytes memory dataPath, bytes memory payload) =
            _vector(verifier, ".first");
        bytes32 digest = verifier.checkpointDigest(c);
        A.ObserverProof[] memory p = _proofs(digest);
        uint256 index = p[0].account == observer ? 0 : 1;
        bytes memory valid = p[index].signature;
        p[index].signature = _sign(0x111111, digest);
        vm.expectRevert(abi.encodeWithSelector(A.InvalidArchivalSignature.selector, observer));
        verifier.recordCheckpoint(c, txPath, dataPath, payload, p);
        p[index].signature = valid;
        require(
            verifier.recordCheckpoint(c, txPath, dataPath, payload, p) != bytes32(0),
            "designation own-key fallback"
        );
    }

    function testCanonicalSingleChunkMaximumAndOversizeRejection() public {
        (A.Checkpoint memory c,,,) = _vector(verifier, ".first");
        bytes memory payload = new bytes(8192);
        for (uint256 i; i < payload.length; ++i) {
            payload[i] = bytes1(uint8(i));
        }
        bytes32 data = sha256(payload);
        c.dataRoot = _leafForTest(data, payload.length);
        c.dataSize = uint64(payload.length);
        c.transactionStart = 0;
        c.transactionEnd = payload.length;
        c.blockDataSize = payload.length;
        c.transactionRoot = _leafForTest(c.dataRoot, payload.length);
        bytes memory txPath = abi.encodePacked(c.dataRoot, uint256(payload.length));
        bytes memory dataPath = abi.encodePacked(data, uint256(payload.length));
        A.ObserverProof[] memory p = _proofs(verifier.checkpointDigest(c));
        require(
            verifier.recordCheckpoint(c, txPath, dataPath, payload, p) != bytes32(0),
            "maximum complete chunk"
        );
        payload = new bytes(8193);
        c.dataSize = 8193;
        c.transactionEnd = 8193;
        c.blockDataSize = 8193;
        p = _proofs(verifier.checkpointDigest(c));
        vm.expectRevert(abi.encodeWithSelector(A.InvalidNativeInclusion.selector));
        verifier.recordCheckpoint(c, txPath, dataPath, payload, p);
    }

    function testFutureNetworkAndConfigurationGuardsWithSameProofRetry() public {
        (A.Checkpoint memory c, bytes memory txPath, bytes memory dataPath, bytes memory payload) =
            _vector(verifier, ".first");
        A.ObserverProof[] memory p = _proofs(verifier.checkpointDigest(c));
        c.observedAt++;
        vm.expectRevert(abi.encodeWithSelector(A.InvalidCheckpoint.selector));
        verifier.recordCheckpoint(c, txPath, dataPath, payload, p);
        c.observedAt--;
        bytes32 original = c.networkId;
        c.networkId = keccak256("another network");
        vm.expectRevert(abi.encodeWithSelector(A.InvalidCheckpoint.selector));
        verifier.recordCheckpoint(c, txPath, dataPath, payload, p);
        c.networkId = original;
        original = c.configurationHash;
        c.configurationHash = keccak256("another observer config");
        vm.expectRevert(abi.encodeWithSelector(A.InvalidCheckpoint.selector));
        verifier.recordCheckpoint(c, txPath, dataPath, payload, p);
        c.configurationHash = original;
        require(
            verifier.recordCheckpoint(c, txPath, dataPath, payload, p) != bytes32(0),
            "restored actual context"
        );
    }

    function testFuzzNativeLeafRangeIsExact(uint16 sizeSeed, uint64 startSeed) public {
        uint256 size = uint256(sizeSeed) % 8192 + 1;
        uint256 start = uint256(startSeed) * 262144;
        bytes memory payload = new bytes(size);
        payload[0] = 0x65;
        bytes32 data = sha256(payload);
        (A.Checkpoint memory c,,,) = _vector(verifier, ".first");
        c.dataRoot = _leafForTest(data, size);
        c.transactionStart = start;
        c.transactionEnd = start + size;
        c.blockDataSize = start + size;
        c.dataSize = uint64(size);
        bytes32 selected = _leafForTest(c.dataRoot, c.transactionEnd);
        bytes memory txPath;
        if (start == 0) {
            c.transactionRoot = selected;
            txPath = abi.encodePacked(c.dataRoot, c.transactionEnd);
        } else {
            bytes32 prior = _leafForTest(keccak256("prior nonzero root"), start);
            c.transactionRoot = sha256(
                abi.encodePacked(
                    sha256(abi.encodePacked(prior)),
                    sha256(abi.encodePacked(selected)),
                    sha256(abi.encodePacked(start))
                )
            );
            txPath = abi.encodePacked(prior, selected, start, c.dataRoot, c.transactionEnd);
        }
        bytes memory dataPath = abi.encodePacked(data, size);
        A.ObserverProof[] memory p = _proofs(verifier.checkpointDigest(c));
        require(
            verifier.recordCheckpoint(c, txPath, dataPath, payload, p) != bytes32(0),
            "exact bounded native range"
        );
        c.transactionStart++;
        c.transactionEnd++;
        c.blockDataSize++;
        p = _proofs(verifier.checkpointDigest(c));
        vm.expectRevert(abi.encodeWithSelector(A.InvalidNativeInclusion.selector));
        verifier.recordCheckpoint(c, txPath, dataPath, payload, p);
    }

    function _domainDigest(A.Checkpoint memory c, uint256 chain, address target)
        private
        pure
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Arweave Checkpoints"),
                keccak256("1"),
                chain,
                target
            )
        );
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "StreamArweaveCheckpoint(bytes32 networkId,bytes blockHash,uint64 blockHeight,bytes32 transactionRoot,uint256 blockDataSize,bytes32 transactionId,bytes32 dataRoot,uint64 dataSize,uint256 transactionStart,uint256 transactionEnd,uint64 observedAt,bytes32 configurationHash)"
                ),
                c.networkId,
                keccak256(c.blockHash),
                c.blockHeight,
                c.transactionRoot,
                c.blockDataSize,
                c.transactionId,
                c.dataRoot,
                c.dataSize,
                c.transactionStart,
                c.transactionEnd,
                c.observedAt,
                c.configurationHash
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, body));
    }

    function testMalformedERC1271TargetAndParentGasHaveHealthyControls() public {
        CheckpointSignatureAdversary adversary = new CheckpointSignatureAdversary();
        StreamArweaveCheckpointVerifier v = _deploy(address(adversary), safeVm.addr(keyA));
        (A.Checkpoint memory c, bytes memory txPath, bytes memory dataPath, bytes memory payload) =
            _vector(v, ".first");
        for (uint8 mode = 1; mode <= 5; ++mode) {
            c.blockHeight++;
            bytes32 digest = v.checkpointDigest(c);
            A.ObserverProof[] memory p = new A.ObserverProof[](2);
            p[0] = A.ObserverProof(address(adversary), bytes("unit signature boundary"));
            p[1] = A.ObserverProof(safeVm.addr(keyA), _sign(keyA, digest));
            if (p[0].account > p[1].account) (p[0], p[1]) = (p[1], p[0]);
            adversary.setMode(mode);
            vm.expectRevert(
                abi.encodeWithSelector(A.InvalidArchivalSignature.selector, address(adversary))
            );
            v.recordCheckpoint(c, txPath, dataPath, payload, p);
            adversary.setMode(0);
            require(
                v.recordCheckpoint(c, txPath, dataPath, payload, p) != bytes32(0),
                "same-context unit validator control"
            );
        }
        c.blockHeight++;
        bytes32 digest = v.checkpointDigest(c);
        A.ObserverProof[] memory p = new A.ObserverProof[](2);
        p[0] = A.ObserverProof(address(adversary), bytes("unit signature boundary"));
        p[1] = A.ObserverProof(safeVm.addr(keyA), _sign(keyA, digest));
        if (p[0].account > p[1].account) (p[0], p[1]) = (p[1], p[0]);
        (bool ok, bytes memory data) = address(v).call{ gas: 130000 }(
            abi.encodeCall(v.recordCheckpoint, (c, txPath, dataPath, payload, p))
        );
        require(
            !ok && bytes4(data) == A.ArchivalParentGas.selector,
            "explicit parent forwarding failure"
        );
        require(
            v.recordCheckpoint(c, txPath, dataPath, payload, p) != bytes32(0),
            "adequately funded caller"
        );
    }

    function testMaximumNativePathDepthAndRebaseMarkerRejection() public {
        (A.Checkpoint memory c,,, bytes memory payload) = _vector(verifier, ".first");
        uint256 size = payload.length;
        c.transactionStart = 0;
        c.transactionEnd = size;
        c.blockDataSize = size + 32;
        bytes32 root = _leafForTest(c.dataRoot, size);
        bytes memory path = abi.encodePacked(c.dataRoot, size);
        for (uint256 i; i < 32; ++i) {
            bytes32 sibling = keccak256(abi.encode("synthetic sibling", i));
            path = bytes.concat(abi.encodePacked(root, sibling, size + i), path);
            root = sha256(
                abi.encodePacked(
                    sha256(abi.encodePacked(root)),
                    sha256(abi.encodePacked(sibling)),
                    sha256(abi.encodePacked(size + i))
                )
            );
        }
        c.transactionRoot = root;
        bytes memory dataPath = abi.encodePacked(sha256(payload), size);
        A.ObserverProof[] memory p = _proofs(verifier.checkpointDigest(c));
        bytes memory tooDeep = bytes.concat(new bytes(96), path);
        vm.expectRevert(abi.encodeWithSelector(A.InvalidNativeInclusion.selector));
        verifier.recordCheckpoint(c, tooDeep, dataPath, payload, p);
        bytes memory rebased = bytes.concat(new bytes(32), path);
        vm.expectRevert(abi.encodeWithSelector(A.InvalidNativeInclusion.selector));
        verifier.recordCheckpoint(c, rebased, dataPath, payload, p);
        require(
            verifier.recordCheckpoint(c, path, dataPath, payload, p) != bytes32(0),
            "exact32-branch algorithm profile"
        );
    }

    function _leafForTest(bytes32 data, uint256 end) private pure returns (bytes32) {
        return
            sha256(abi.encodePacked(sha256(abi.encodePacked(data)), sha256(abi.encodePacked(end))));
    }
}
