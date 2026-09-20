// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceMetricReadExecution as ReadExecution
} from "../../../smart-contracts/domains/preservation/StreamReferenceMetricReadExecution.sol";
import {
    StreamReferenceMetricExecution as Execution
} from "../../../smart-contracts/domains/preservation/StreamReferenceMetricExecution.sol";
import {
    StreamReferenceMetricStorage as Storage
} from "../../../smart-contracts/domains/preservation/StreamReferenceMetricStorage.sol";
import {
    StreamReferenceMetricProof as Proof
} from "../../../smart-contracts/domains/preservation/StreamReferenceMetricProof.sol";
import {
    StreamReferenceModePreparation as Preparation
} from "../../../smart-contracts/domains/preservation/StreamReferenceModePreparation.sol";
import {
    StreamReferenceModeProof as ModeProof
} from "../../../smart-contracts/domains/preservation/StreamReferenceModeProof.sol";
import {
    StreamReferenceModeInput as Input
} from "../../../smart-contracts/domains/preservation/StreamReferenceModeInput.sol";
import {
    StreamReferenceModeStateReads as StateReads
} from "../../../smart-contracts/domains/preservation/StreamReferenceModeStateReads.sol";
import {
    StreamReferenceRenderSourceReads as Source
} from "../../../smart-contracts/domains/preservation/StreamReferenceRenderSourceReads.sol";
import {
    StreamSnapshotManifestBytes as Bytes
} from "../../../smart-contracts/domains/records/StreamSnapshotManifestBytes.sol";
import {
    StreamSchemaDocumentStore as Store
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    StreamWorkRecordContext as Definitions
} from "../../../smart-contracts/domains/records/StreamWorkRecordContext.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamReferenceModeTypes as M
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceModeTypes.sol";
import {
    StreamReferenceMetricTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceMetricTypes.sol";
import {
    IStreamReferenceMetricSupplement as I
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamReferenceMetricSupplement.sol";

interface MetricExecutionVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function readFile(string calldata) external view returns (string memory);
    function parseJsonBytes(string calldata, string calldata) external pure returns (bytes memory);
    function warp(uint256) external;
    function mockCall(address, bytes calldata, bytes calldata) external;
    function mockCallRevert(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
    function etch(address, bytes calldata) external;
    function expectRevert(bytes calldata) external;
}

/// @dev Explicit typed selected-Metadata grant boundary, not actual Writer authority integration.
contract MetricExecutionAuthorityBoundary {
    bool public enabled = true;

    function setEnabled(bool value) external {
        enabled = value;
    }

    function familyWriter(uint256, bytes32, uint8, address) external view returns (bool, uint64) {
        return (enabled, 1);
    }
}

/// @dev Same host/domain for old and new paths; actual immutable Store bytes and metric proof.
/// Source/facts/registered-definition producers are explicitly mocked by the test, never promoted
/// to current Artist/Router/schema or actual publication acceptance.
contract MetricExecutionHarness {
    Store public store;
    R.Dependencies private d;
    M.Dependencies private bindings;
    Bytes.Manifest private publication;
    Bytes.Manifest private evidence;
    Bytes.Manifest private payload;
    M.Facts private facts;
    R.Receipt private receipt;
    R.Lock private lock;
    Storage.State private legacy;
    Storage.State private checked;

    constructor(Store s, address authority) {
        store = s;
        d.chainId = block.chainid;
        d.targets[0] = address(this);
        d.targets[1] = authority;
        d.targets[3] = address(s);
        d.readGas = 600000;
        d.sourceGas = 14000000;
        for (uint256 i; i < 7; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
    }

    function context(R.Publication memory p) external view returns (bytes32) {
        return Input.contextHash(d, p);
    }

    function seed(
        R.Publication memory p,
        M.Evidence memory e,
        R.SourceFacts memory source,
        M.Facts memory f
    ) external {
        facts = f;
        _retain(publication, abi.encode(p));
        _retain(evidence, abi.encode(e));
        _retain(payload, abi.encode("exact retained output", p.collectionId, p.referenceId));
        receipt.recordHash = keccak256("original reference");
        receipt.collectionId = p.collectionId;
        receipt.revision = 1;
        receipt.sourcesHash = ModeProof.sourceHash(d, bindings, source, f);
        receipt.payloadHash = payload.contentHash;
    }

    function originalHash() external view returns (bytes32) {
        return receipt.recordHash;
    }

    function payloadPointer() external view returns (address) {
        return payload.pointers[0];
    }

    function setLocked(bool value) external {
        lock.actionId = value ? keccak256("locked") : bytes32(0);
    }

    function exists(bool fresh) external view returns (bool) {
        return fresh
            ? checked.receipts[receipt.recordHash].supplementHash != 0
            : legacy.receipts[receipt.recordHash].supplementHash != 0;
    }

    function upload(bytes memory raw, uint256 count) external {
        for (uint256 i; i < count; ++i) {
            store.publishChunk(_part(raw, i));
        }
    }

    function publish(bool fresh, bytes calldata original)
        external
        returns (bytes32 hash, uint256 used)
    {
        uint256 before = gasleft();
        if (fresh) {
            hash = Execution.publish(
                checked, d, bindings, publication, evidence, facts, payload, receipt, lock, original
            );
        } else {
            Preparation.requireCurrent(d, bindings, publication, evidence, facts, payload, receipt);
            if (lock.actionId != 0) revert R.ReferenceLocked();
            (uint8 cls, uint64 rev) =
                StateReads.authority(d.targets[1], receipt.collectionId, msg.sender, d.readGas);
            hash = Storage.publish(
                legacy,
                Storage.Context(d, receipt, msg.sender, cls, rev),
                publication,
                evidence,
                original
            );
        }
        used = before - gasleft();
    }

    function requireSupplement(bool fresh) external view returns (bytes memory out, uint256 used) {
        uint256 before = gasleft();
        if (fresh) {
            out = ReadExecution.requireEncoded(
                checked, d, bindings, publication, evidence, facts, payload, receipt
            );
        } else {
            Preparation.requireCurrent(d, bindings, publication, evidence, facts, payload, receipt);
            out = Storage.requireEncoded(legacy, d, receipt.recordHash, publication, evidence);
        }
        used = before - gasleft();
    }

    function stored(bool fresh) external view returns (bytes memory) {
        return fresh
            ? Storage.encoded(checked, receipt.recordHash)
            : Storage.encoded(legacy, receipt.recordHash);
    }

    function standaloneCurrent() external view {
        Preparation.requireCurrent(d, bindings, publication, evidence, facts, payload, receipt);
    }

    function setSupplementManifestHash(bool fresh, bytes32 value) external {
        if (fresh) checked.payloads[receipt.recordHash].contentHash = value;
        else legacy.payloads[receipt.recordHash].contentHash = value;
    }

    function _retain(Bytes.Manifest storage target, bytes memory raw) private {
        for (uint256 i; i < (raw.length + 8191) / 8192; ++i) {
            store.publishChunk(_part(raw, i));
        }
        Bytes.retain(target, address(store), raw);
    }

    function _part(bytes memory raw, uint256 i) private pure returns (bytes memory out) {
        uint256 offset = i * 8192;
        uint256 n = raw.length - offset;
        if (n > 8192) n = 8192;
        out = new bytes(n);
        for (uint256 j; j < n; j += 32) {
            assembly ("memory-safe") {
                mstore(add(add(out, 32), j), mload(add(add(raw, 32), add(offset, j))))
            }
        }
    }
}

contract MetricExecutionProofProbe {
    function oldProof(
        R.Publication memory p,
        M.Evidence memory e,
        bytes32 context,
        T.Supplement memory s
    ) external view returns (bytes32, bytes32) {
        return Proof.requireEvidence(p, e, context, s);
    }

    function newProof(
        R.Publication memory p,
        M.Evidence memory e,
        bytes32 context,
        T.Supplement memory s
    ) external view returns (bytes32, bytes32) {
        return Proof.requireCompact(Proof.compact(p, e, context), s);
    }
}

/// @notice Transport equivalence with literal original domains and complete1048-member corpus.
/// @dev Rebound replay is synthetic test evidence; no new archived execution is asserted.
contract StreamReferenceMetricExecutionTest {
    MetricExecutionVm private constant vm =
        MetricExecutionVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    MetricExecutionHarness private host;
    MetricExecutionAuthorityBoundary private authority;
    MetricExecutionProofProbe private probe;
    R.Publication private publication;
    M.Evidence private evidence;
    R.SourceFacts private source;
    M.Facts private facts;
    T.Supplement private supplement;
    bytes private original;
    bytes32 private contextHash;
    event log_named_uint(string key, uint256 value);

    function setUp() public {
        authority = new MetricExecutionAuthorityBoundary();
        host = new MetricExecutionHarness(new Store(), address(authority));
        probe = new MetricExecutionProofProbe();
        T.Supplement memory s = abi.decode(
            vm.readFileBinary("test/fixtures/preservation/reference-metric-replay-v1.abi"),
            (T.Supplement)
        );
        vm.warp(s.replay.executedAt);
        R.Publication memory p;
        p.collectionId = 1;
        p.referenceId = keccak256("reference");
        p.environment.objectHash = s.runtime.environmentObjectHash;
        p.environment.manifestHash = s.runtime.environmentManifestHash;
        string memory corpus =
            vm.readFile("test/fixtures/preservation/reference-combined-native-v1.json");
        p.environment.packageFiles =
            abi.decode(vm.parseJsonBytes(corpus, ".packageFilesABI"), (R.PackageFile[]));
        p.environment.platformPrerequisites =
            abi.decode(vm.parseJsonBytes(corpus, ".platformPrerequisitesABI"), (R.PackageFile[]));
        require(
            p.environment.packageFiles.length == 1048
                && p.environment.platformPrerequisites.length == 102
        );
        // The same complete corpus is the input. Its684 metric-prefixed members must match
        // the retained runtime exactly; the other364 remain in the context preimage.
        p.environment.viewportWidth = 16;
        p.environment.viewportHeight = 16;
        p.environment.devicePixelRatio = 1;
        p.captures = new R.Capture[](1);
        p.captures[0].repeatCaptureSha256 = [
            bytes32(0x67f5c738d0805c210ffc7294b4eb21cec527dc14d3fb028f315a0a16a078182b),
            bytes32(0xd410dd8d32b5dc55f03dde6cb0367ba31682a49a1af9a0c15308527a41c6838b)
        ];
        M.Evidence memory e;
        e.mode = M.Mode.PERCEPTUAL_TOLERANCE;
        e.perceptual.metric.implementationHash =
        0xdf70cb98b947f970bd117c6e7343c1471c9059efa9e36a8248e33c0e59b51aff;
        e.perceptual.metric.parametersHash =
        0x1284b35afa316cb69d790a354cefdeb19d00a37116b1ec25e2ded88a1f59add3;
        e.perceptual.threshold = 990000000;
        e.perceptual.evaluatedAt = 1;
        e.perceptual.reportHash = keccak256("explicit synthetic metric report");
        contextHash = host.context(p);
        s.replay.contextHash = contextHash;
        s.replay.reportHash = e.perceptual.reportHash;
        s.replay.inputManifest = Proof.inputManifest(p, e.perceptual, contextHash);
        s.replay.inputsHash = keccak256(s.replay.inputManifest);
        (,,,,,,, bytes memory diagnostic) = abi.decode(
            s.replay.transcript,
            (bytes32, bytes32, bytes32, bytes32, bytes32, uint64, uint32, bytes)
        );
        s.replay.transcript = abi.encode(
            keccak256("6529STREAM_METRIC_TRANSCRIPT_V1"),
            s.replay.runtimeHash,
            contextHash,
            s.replay.reportHash,
            s.replay.inputsHash,
            s.replay.executedAt,
            s.replay.exitCode,
            diagnostic
        );
        publication = p;
        evidence = e;
        supplement = s;
        source.subject = keccak256("scoped transport source");
        source.mintedEver = 2;
        facts.mode = M.Mode.PERCEPTUAL_TOLERANCE;
        facts.evidenceHash = keccak256(abi.encode(e));
        _boundaries();
        host.seed(p, e, source, facts);
        original = abi.encodeCall(I.publishMetricSupplement, (host.originalHash(), s));
        bytes memory raw = abi.encode(s);
        host.upload(raw, (raw.length + 8191) / 8192);
    }

    function _boundaries() private {
        vm.mockCall(
            address(Source),
            abi.encodeWithSelector(Source.requireModeSourceInputs.selector),
            abi.encode(source)
        );
        vm.mockCall(
            address(ModeProof),
            abi.encodeWithSelector(ModeProof.requireEvidenceProjected.selector),
            abi.encode(facts)
        );
        vm.mockCall(
            address(Definitions),
            abi.encodeWithSelector(Definitions.definition.selector),
            abi.encode(bytes("explicit definition boundary"))
        );
    }

    function testFullCorpusLiteralProofAndReceiptParity() public {
        (bytes32 a, bytes32 b) = probe.oldProof(publication, evidence, contextHash, supplement);
        (bytes32 c, bytes32 d) = probe.newProof(publication, evidence, contextHash, supplement);
        require(a == c && b == d);
        require(
            a
                == keccak256(
                    abi.encode(keccak256("6529STREAM_METRIC_RUNTIME_V1"), supplement.runtime)
                )
        );
        require(
            b == keccak256(abi.encode(keccak256("6529STREAM_METRIC_REPLAY_V1"), supplement.replay))
        );
        (bytes32 oldHash,) = host.publish(false, original);
        (bytes32 newHash,) = host.publish(true, original);
        require(oldHash == newHash && keccak256(host.stored(false)) == keccak256(host.stored(true)));
        (bytes memory oldReceipt,) = host.requireSupplement(false);
        (bytes memory newReceipt,) = host.requireSupplement(true);
        require(keccak256(oldReceipt) == keccak256(newReceipt));
        T.Receipt memory r = abi.decode(newReceipt, (T.Receipt));
        r.supplementHash = 0;
        require(
            newHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_METRIC_SUPPLEMENT_V1"),
                        block.chainid,
                        address(host),
                        address(host),
                        address(authority),
                        r
                    )
                )
        );
        host.standaloneCurrent();
    }

    function testLinkedStoredProofUsesExactHostNamespaceUnderStaticCall() public {
        host.publish(false, original);
        host.publish(true, original);
        (bytes memory raw, T.Receipt memory savedReceipt) =
            abi.decode(host.stored(true), (bytes, T.Receipt));
        bytes32 retained = keccak256(raw);
        host.setSupplementManifestHash(false, bytes32(uint256(1)));
        (bool oldBad,) = address(host).staticcall(abi.encodeCall(host.requireSupplement, (false)));
        (bool freshGood, bytes memory result) =
            address(host).staticcall(abi.encodeCall(host.requireSupplement, (true)));
        require(!oldBad && freshGood);
        (bytes memory encoded,) = abi.decode(result, (bytes, uint256));
        // Currentness returns only the original Receipt; stored() also returns full bytes.
        require(keccak256(encoded) == keccak256(abi.encode(savedReceipt)));
        host.setSupplementManifestHash(false, retained);
        host.setSupplementManifestHash(true, bytes32(uint256(1)));
        (bool oldGood,) = address(host).staticcall(abi.encodeCall(host.requireSupplement, (false)));
        (bool freshBad, bytes memory error) =
            address(host).staticcall(abi.encodeCall(host.requireSupplement, (true)));
        require(
            oldGood && !freshBad
                && keccak256(error)
                    == keccak256(abi.encodeWithSelector(Bytes.InvalidSnapshotManifest.selector))
        );
        host.setSupplementManifestHash(true, retained);
        (bytes memory restored,) = host.requireSupplement(true);
        require(keccak256(restored) == keccak256(abi.encode(savedReceipt)));
        (bytes memory oldRaw, T.Receipt memory oldReceipt) =
            abi.decode(host.stored(false), (bytes, T.Receipt));
        require(keccak256(oldRaw) == retained);
        require(keccak256(abi.encode(oldReceipt)) == keccak256(abi.encode(savedReceipt)));
    }

    function testFreshFramesReportWholeOperationCost() public {
        (bytes32 a, uint256 oldGas) = host.publish(false, original);
        (bytes32 b, uint256 newGas) = host.publish(true, original);
        require(a == b);
        emit log_named_uint("legacyPublishExecution", oldGas);
        emit log_named_uint("sameCallPublishExecution", newGas);
        (bytes memory oldBytes, uint256 oldRead) = host.requireSupplement(false);
        (bytes memory newBytes, uint256 newRead) = host.requireSupplement(true);
        require(keccak256(oldBytes) == keccak256(newBytes));
        emit log_named_uint("legacyRequireExecution", oldRead);
        emit log_named_uint("sameCallRequireExecution", newRead);
        // These are execution diagnostics with shared warmed dependencies, not transaction
        // capacity or a cold current graph. Original native14 envelopes stay mandatory.
    }

    function testSourceDriftPrecedesLockAndAuthorityAndCannotLeaveReceipt() public {
        R.SourceFacts memory changed = source;
        changed.subject = keccak256("source changed");
        vm.mockCall(
            address(Source),
            abi.encodeWithSelector(Source.requireModeSourceInputs.selector),
            abi.encode(changed)
        );
        host.setLocked(true);
        authority.setEnabled(false);
        _bothFail(abi.encodeWithSelector(M.InvalidModeEvidence.selector));
        require(!host.exists(false) && !host.exists(true));
        _boundaries();
        host.setLocked(false);
        authority.setEnabled(true);
        (bytes32 a,) = host.publish(false, original);
        (bytes32 b,) = host.publish(true, original);
        require(a == b);
    }

    function testLockedThenWriterAndDefinitionErrorOrderExact() public {
        host.setLocked(true);
        authority.setEnabled(false);
        _bothFail(abi.encodeWithSelector(R.ReferenceLocked.selector));
        host.setLocked(false);
        _bothFail(abi.encodeWithSelector(R.ReferenceAuthority.selector, address(this)));
        authority.setEnabled(true);
        bytes memory reason =
            abi.encodeWithSignature("DefinitionUnavailable(bytes32)", keccak256("test"));
        vm.mockCallRevert(
            address(Definitions), abi.encodeWithSelector(Definitions.definition.selector), reason
        );
        _bothFail(reason);
    }

    function testFullPayloadIntegrityAndIdenticalRetry() public {
        address pointer = host.payloadPointer();
        bytes memory saved = pointer.code;
        vm.etch(pointer, hex"00");
        _bothFail(abi.encodeWithSelector(Bytes.SnapshotChunkChanged.selector, pointer));
        require(!host.exists(false) && !host.exists(true));
        vm.etch(pointer, saved);
        (bytes32 a,) = host.publish(false, original);
        (bytes32 b,) = host.publish(true, original);
        require(a == b);
    }

    function testReplayAndEnvironmentMutationMatchOriginalErrors() public {
        T.Supplement memory s = supplement;
        s.replay.contextHash ^= bytes32(uint256(1));
        _proofBothFail(publication, evidence, s);
        s = supplement;
        s.runtime.members[20].sha256Digest ^= bytes32(uint256(1));
        _proofBothFail(publication, evidence, s);
        R.Publication memory p = publication;
        p.environment.objectHash ^= bytes32(uint256(1));
        _proofBothFail(p, evidence, supplement);
        M.Evidence memory e = evidence;
        e.mode = M.Mode.CURATED_EQUIVALENCE;
        _proofBothFail(publication, e, supplement);
    }

    function testEmptyAndMissingReplayMatchOriginalErrors() public {
        R.Publication memory p = publication;
        p.captures = new R.Capture[](0);
        _proofBothFail(p, evidence, supplement);
        T.Supplement memory s = supplement;
        s.replay.transcript = new bytes(0);
        _proofBothFail(publication, evidence, s);
        s = supplement;
        s.sources[0].content = new bytes(0);
        _proofBothFail(publication, evidence, s);
    }

    function testEveryProjectedFieldHasTheOriginalMeaning() public {
        R.Publication memory p = publication;
        p.environment.viewportWidth += 1;
        _proofBothFail(p, evidence, supplement);
        p = publication;
        p.environment.viewportHeight += 1;
        _proofBothFail(p, evidence, supplement);
        p = publication;
        p.environment.devicePixelRatio = 2;
        _proofBothFail(p, evidence, supplement);
        p = publication;
        p.environment.manifestHash ^= bytes32(uint256(1));
        _proofBothFail(p, evidence, supplement);
        p = publication;
        p.captures[0].repeatCaptureSha256[0] ^= bytes32(uint256(1));
        _proofBothFail(p, evidence, supplement);
        p = publication;
        p.captures[0].repeatCaptureSha256[1] ^= bytes32(uint256(1));
        _proofBothFail(p, evidence, supplement);
        M.Evidence memory e = evidence;
        e.perceptual.metric.implementationHash ^= bytes32(uint256(1));
        _proofBothFail(publication, e, supplement);
        e = evidence;
        e.perceptual.metric.parametersHash ^= bytes32(uint256(1));
        _proofBothFail(publication, e, supplement);
        e = evidence;
        e.perceptual.threshold -= 1;
        _proofBothFail(publication, e, supplement);
        e = evidence;
        e.perceptual.evaluatedAt += 1;
        _proofBothFail(publication, e, supplement);
        e = evidence;
        e.perceptual.reportHash ^= bytes32(uint256(1));
        _proofBothFail(publication, e, supplement);
        bytes32 changedContext = contextHash ^ bytes32(uint256(1));
        (bool a, bytes memory x) = address(probe)
            .staticcall(
                abi.encodeCall(probe.oldProof, (publication, evidence, changedContext, supplement))
            );
        (bool b, bytes memory y) = address(probe)
            .staticcall(
                abi.encodeCall(probe.newProof, (publication, evidence, changedContext, supplement))
            );
        require(!a && !b && keccak256(x) == keccak256(y));
    }

    function testUnprojectedFieldsAreStillInTheCompleteCurrentContext() public view {
        R.Publication memory p = publication;
        bytes32 before = host.context(p);
        p.environment.platformPrerequisites[0].sha256Digest ^= bytes32(uint256(1));
        p.environment.engineName = "changed complete environment";
        p.captures[0].animationHTML = bytes("changed complete HTML");
        require(host.context(p) != before, "omitted transport fields lost from current context");
        // Only the stateless metric algorithm ignores these fields. The unchanged complete
        // currentness context above changes and would require a newly matching replay.
        (bytes32 a, bytes32 b) = probe.oldProof(p, evidence, contextHash, supplement);
        (bytes32 c, bytes32 d) = probe.newProof(p, evidence, contextHash, supplement);
        require(a == c && b == d);
    }

    function testFuzzParameterMutationRetainsOriginalRefusal(bytes32 changed) public {
        T.Supplement memory s = supplement;
        s.parameters = abi.encode(changed);
        _proofBothFail(publication, evidence, s);
    }

    function _bothFail(bytes memory expected) private {
        (bool a, bytes memory x) =
            address(host).call(abi.encodeCall(host.publish, (false, original)));
        (bool b, bytes memory y) =
            address(host).call(abi.encodeCall(host.publish, (true, original)));
        require(
            !a && !b && keccak256(x) == keccak256(expected) && keccak256(y) == keccak256(expected)
        );
    }

    function _proofBothFail(R.Publication memory p, M.Evidence memory e, T.Supplement memory s)
        private
    {
        (bool a, bytes memory x) =
            address(probe).staticcall(abi.encodeCall(probe.oldProof, (p, e, contextHash, s)));
        (bool b, bytes memory y) =
            address(probe).staticcall(abi.encodeCall(probe.newProof, (p, e, contextHash, s)));
        require(!a && !b && keccak256(x) == keccak256(y));
    }
}
