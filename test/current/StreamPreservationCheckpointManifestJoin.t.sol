// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/PreservationPolicyContentFixtureV1.sol";
import {
    StreamPreservationPolicyOutputManifestV1 as JoinManifest
} from "../../smart-contracts/domains/finality/StreamPreservationPolicyOutputManifestV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as JoinV
} from "../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import {
    StreamPreservationPolicyOutputSchemasV1 as JoinDefinitions
} from "../../smart-contracts/domains/finality/StreamPreservationPolicyOutputSchemasV1.sol";
import {
    StreamFinalityArtifactCoverage as JoinCoverage
} from "../../smart-contracts/domains/preservation/StreamFinalityArtifactCoverage.sol";
import {
    IStreamFinalityArtifactCoverage as JoinCoverageInterface
} from "../../smart-contracts/interfaces/stream/preservation/IStreamFinalityArtifactCoverage.sol";
import {
    StreamFinalityArtifactTypes as JoinF
} from "../../smart-contracts/interfaces/stream/preservation/StreamFinalityArtifactTypes.sol";
import {
    IStreamSchemaRegistry as JoinSchema
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    LeafManifestArchiveBoundary as JoinArchiveBoundary,
    LeafManifestFinalityBoundary as JoinFinalityBoundary
} from "../helpers/scoped-preservation-boundaries/StreamContentLeafManifestBoundaries.sol";
import {
    LeafManifestVm as JoinVm
} from "../helpers/scoped-preservation-boundaries/StreamContentLeafManifestVm.sol";

/// @notice Real V1 checkpoint -> exact full-row manifest -> SSTORE2 artifact/coverage -> verifier.
/// @dev Native entropy policies/finalization, factory CREATE, membership, selection, checkpoint,
/// Schema/Store, ArtifactCoverage and manifest verification are actual contracts. Preservation
/// output and per-version Registry admission are authenticated typed boundaries, seeded by the
/// inherited Router/Renderer. Core identities, Artist authorization, scoped governance, selected
/// Finality and independent archival-family receipts remain the named inherited boundaries.
/// This does not claim actual preservation rendering, Artist, real governance/finality ceremony,
/// independent archival providers, or transaction-gas acceptance. No frozen suite cap is changed.
contract StreamPreservationCheckpointManifestJoinTest is PreservationPolicyContentFixtureV1 {
    JoinVm private constant jvm = JoinVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant JOIN_ARTIST = keccak256("artist");
    bytes32 private constant MANIFEST_READ =
        keccak256("6529STREAM_GGP_STATIC_OUTPUT_MANIFEST_READ_GAS");
    JoinCoverage private joinCoverage;
    JoinArchiveBoundary private joinArchive;
    StreamSchemaDocumentStore private joinStore;

    struct Joined {
        Capture capture;
        JoinManifest verifier;
        bytes raw;
        bytes32 artifact;
        bytes32 coverage;
        bytes32 plan;
    }

    event OutputManifestVerified(
        uint16 schemaVersion,
        bytes32 indexed recordHash,
        bytes32 indexed planHash,
        JoinV.Manifest manifest
    );

    function testCheckpointManifestJoinAllCanonicalScopesAndOriginalGasMismatch() external {
        _joinFixture();
        for (uint8 kind; kind < 4; ++kind) {
            Joined memory j = _prepareJoin(kind, kind == 0);
            vm.recordLogs();
            bytes32 record = j.verifier.verifyNextOutputs(j.plan, j.capture.producers.length);
            Vm.Log[] memory emitted = vm.getRecordedLogs();
            _assertJoined(j, record);
            JoinV.Manifest memory m = j.verifier.manifestRecord(record);
            vm.recordLogs();
            emit OutputManifestVerified(1, record, j.plan, m);
            Vm.Log[] memory oracle = vm.getRecordedLogs();
            require(
                emitted.length == 2 && emitted[1].emitter == address(j.verifier),
                "real advance and completion events"
            );
            require(
                keccak256(abi.encode(emitted[1].topics)) == keccak256(abi.encode(oracle[0].topics))
                    && keccak256(emitted[1].data) == keccak256(oracle[0].data),
                "literal full manifest completion event"
            );
            require(
                j.verifier.beginManifest(j.capture.id, j.artifact, j.coverage, JOIN_ARTIST)
                        == j.plan && j.verifier.manifestPlan(j.plan).recordHash == record,
                "same original input retains completed plan"
            );
        }
    }

    function testCheckpointManifestJoinAdmissionAndOutputDriftPreserveHistoryAndRestore() external {
        _joinFixture();
        Joined memory j = _prepareJoin(2, false);
        bytes32 record = j.verifier.verifyNextOutputs(j.plan, 2);
        _assertJoined(j, record);
        bytes32 savedCheckpoint = _history(j.capture);
        bytes32 savedManifest = keccak256(abi.encode(j.verifier.manifestRecord(record)));
        PreservationTypes.Admission memory admitted = _admission(j.capture, 1);
        bytes memory originalAdmission = abi.encode(_binding(j.capture, 1), admitted);
        admitted.goldenHash = keccak256("different typed executed-golden admission");
        _setAdmission(j.capture, 1, abi.encode(_binding(j.capture, 1), admitted));
        _expectCheckpointFailure(j);
        j.verifier.requireCurrentManifest(record, JOIN_ARTIST);
        require(
            _history(j.capture) == savedCheckpoint
                && keccak256(abi.encode(j.verifier.manifestRecord(record))) == savedManifest,
            "admission currentness refusal cannot rewrite either historical receipt"
        );
        _setAdmission(j.capture, 1, originalAdmission);
        _assertJoined(j, record);
        uint256 token = j.capture.host.outputAt(j.capture.id, 1).leaf.tokenId;
        string memory json = j.capture.producers[1].preservationTokenJSON(token);
        string memory html = j.capture.producers[1].preservationTokenHTML(token);
        j.capture.producers[1].setBytes(token, string(abi.encodePacked(" ", json)), html);
        _expectCheckpointFailure(j);
        j.verifier.requireCurrentManifest(record, JOIN_ARTIST);
        require(
            _history(j.capture) == savedCheckpoint
                && keccak256(abi.encode(j.verifier.manifestRecord(record))) == savedManifest,
            "changed actual producer bytes fail current admission and preserve saved full rows"
        );
        j.capture.producers[1].setBytes(token, json, html);
        _assertJoined(j, record);
    }

    function testCheckpointManifestJoinLateCoverageRollbackAndIdenticalCalldataRetry() external {
        _joinFixture();
        Joined memory j = _prepareJoin(3, false);
        require(j.verifier.verifyNextOutputs(j.plan, 1) == 0, "real partial full-row verification");
        bytes memory input = abi.encodeCall(JoinV.verifyNextOutputs, (j.plan, uint256(1)));
        bytes32 savedPlan = keccak256(abi.encode(j.verifier.manifestPlan(j.plan)));
        bytes32 savedCheckpoint = _history(j.capture);
        bytes32 savedCoverage = keccak256(abi.encode(joinCoverage.coverage(j.coverage)));
        bytes32 savedArtifact = keccak256(abi.encode(joinCoverage.artifact(j.artifact)));
        joinArchive.advanceEpoch();
        (bool ok, bytes memory result) = address(j.verifier).call(input);
        require(
            !ok
                && keccak256(result)
                    == keccak256(
                        abi.encodeWithSelector(
                            JoinV.OutputManifestReadFailed.selector,
                            address(joinCoverage),
                            JoinCoverageInterface.requireArtifactCoverage.selector
                        )
                    ),
            "real final currentness path reaches stale artifact coverage"
        );
        require(
            keccak256(abi.encode(j.verifier.manifestPlan(j.plan))) == savedPlan
                && j.verifier.manifestPlan(j.plan).nextIndex == 1
                && j.verifier.manifestPlan(j.plan).recordHash == 0,
            "late rejection atomically rolls the tentative cursor back"
        );
        require(
            _history(j.capture) == savedCheckpoint
                && keccak256(abi.encode(joinCoverage.coverage(j.coverage))) == savedCoverage
                && keccak256(abi.encode(joinCoverage.artifact(j.artifact))) == savedArtifact,
            "no checkpoint, original coverage or artifact history mutation"
        );
        JoinF.Artifact memory a = joinCoverage.artifact(j.artifact);
        for (uint32 i; i < a.chunkHashes.length; ++i) {
            joinCoverage.refreshNextChunk(j.coverage, i, a.chunkHashes[i]);
        }
        (ok, result) = address(j.verifier).call(input);
        require(ok, "same saved verifier calldata retries after actual complete coverage refresh");
        bytes32 record = abi.decode(result, (bytes32));
        _assertJoined(j, record);
        require(
            keccak256(abi.encode(joinCoverage.coverage(j.coverage))) == savedCoverage
                && joinCoverage.currentCoverageValidation(j.coverage).validationEpoch
                    == joinArchive.coverageValidationEpoch(),
            "new validation head preserves original immutable coverage receipt"
        );
    }

    function _joinFixture() private {
        // Real original native disabled/finalized policies, actual factory/current source routes.
        _scopedFixture(1, true);
        _scopedDocument(
            "STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V1",
            false,
            JoinDefinitions.document(JoinDefinitions.SCHEMA)
        );
        _scopedDocument(
            "STREAM_ABI_PRESERVATION_POLICY_OUTPUT_MANIFEST_V1",
            true,
            JoinDefinitions.document(JoinDefinitions.CANON)
        );
        joinStore = StreamSchemaDocumentStore(schemas.chunkStore());
        joinArchive = JoinArchiveBoundary(
            _artistArtifactCreate(
                "test/helpers/scoped-preservation-boundaries/StreamContentLeafManifestBoundaries.sol:LeafManifestArchiveBoundary",
                abi.encode(address(core), address(executor))
            )
        );
        address predicted =
            jvm.computeCreateAddress(address(this), uint256(jvm.getNonce(address(this))) + 1);
        joinCoverage = JoinCoverage(
            _artistArtifactCreate(
                "smart-contracts/domains/preservation/StreamFinalityArtifactCoverage.sol:StreamFinalityArtifactCoverage",
                abi.encode(
                    address(core),
                    address(joinArchive),
                    address(schemas),
                    address(joinStore),
                    predicted,
                    address(executor),
                    IStreamGasParameterHost.GasParameterConfig(
                        "FINALITY_ARTIFACT_DEPENDENCY_READ_GAS", 300000, 300000, 2
                    )
                )
            )
        );
        address finality = _artistArtifactCreate(
            "test/helpers/scoped-preservation-boundaries/StreamContentLeafManifestBoundaries.sol:LeafManifestFinalityBoundary",
            abi.encode(address(core), address(joinCoverage))
        );
        require(finality == predicted, "actual fixed CREATE dependency binding");
        _scopedPointer(keccak256("ARTWORK_FINALITY_REGISTRY"), finality, bytes4(0));
        require(
            joinCoverage.core() == address(core) && joinCoverage.chunkStore() == address(joinStore)
                && joinCoverage.schemaRegistry() == address(schemas)
                && joinCoverage.archivalCoverage() == address(joinArchive)
                && joinCoverage.finalityRegistry() == finality,
            "all real artifact coverage dependency edges"
        );
    }

    function _prepareJoin(uint8 kind, bool originalMismatch) private returns (Joined memory j) {
        j.capture = _capture(_scope(kind), true);
        j.capture.host.append(j.capture.id, _payload(j.capture));
        _assertComplete(j.capture);
        j.raw = _manifestBytes(j.capture);
        (j.artifact, j.coverage) = _archiveManifest(j.raw);
        if (originalMismatch) _originalGasMismatch(j);
        j.verifier = _manifest(j.capture, 16000000);
        _raiseManifestGas(j.verifier);
        require(
            j.verifier.core() == address(core)
                && j.verifier.contentCheckpoint() == address(j.capture.host)
                && j.verifier.artifactCoverage() == address(joinCoverage)
                && j.verifier.schemaRegistry() == address(schemas)
                && j.verifier.checkpointCodeHash() == address(j.capture.host).codehash
                && j.verifier.coverageCodeHash() == address(joinCoverage).codehash
                && j.verifier.schemaCodeHash() == address(schemas).codehash,
            "real verifier pins checkpoint/coverage/schema"
        );
        j.plan = j.verifier.beginManifest(j.capture.id, j.artifact, j.coverage, JOIN_ARTIST);
        require(
            j.plan == _planHash(j.verifier, _expectedManifest(j)),
            "literal original V1 plan commitment"
        );
    }

    function _originalGasMismatch(Joined memory j) private {
        // Preserve the original 3m -> checkpoint 8m/read,16m/render mismatch as a negative.
        JoinManifest low = _manifest(j.capture, 3000000);
        require(
            IStreamGasParameterHost(address(j.capture.host))
                    .gasParameter(keccak256("6529STREAM_GGP_STATIC_CONTENT_READ_GAS")) == 8000000
                && IStreamGasParameterHost(address(j.capture.host))
                    .gasParameter(keccak256("6529STREAM_GGP_STATIC_CONTENT_RENDER_GAS"))
                == 16000000,
            "original checkpoint parameters are unchanged"
        );
        bytes32 plan = _planHash(low, _expectedManifest(j));
        bytes32 before_ = keccak256(abi.encode(low.manifestPlan(plan)));
        vm.expectRevert(
            abi.encodeWithSelector(
                JoinV.OutputManifestReadFailed.selector,
                address(j.capture.host),
                Preservation.requireCurrentCheckpoint.selector
            )
        );
        low.beginManifest(j.capture.id, j.artifact, j.coverage, JOIN_ARTIST);
        JoinV.Plan memory absent = low.manifestPlan(plan);
        require(
            keccak256(abi.encode(absent)) == before_ && absent.nextIndex == 0
                && absent.recordHash == 0 && absent.manifest.tokenCount == 0,
            "original incompatible read budget produces no plan/cursor/record writes"
        );
        bytes32 record = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_VERIFIED_V1"), plan
            )
        );
        vm.expectRevert(abi.encodeWithSelector(JoinV.OutputManifestUnknown.selector, record));
        low.manifestRecord(record);
        require(
            low.gasParameter(MANIFEST_READ) == 3000000,
            "negative instance remains at original parameter"
        );
    }

    function _manifest(Capture memory c, uint256 readGas) private returns (JoinManifest) {
        return JoinManifest(
            _artistArtifactCreate(
                "smart-contracts/domains/finality/StreamPreservationPolicyOutputManifestV1.sol:StreamPreservationPolicyOutputManifestV1",
                abi.encode(
                    address(core),
                    address(c.host),
                    address(joinCoverage),
                    address(executor),
                    IStreamGasParameterHost.GasParameterConfig(
                        "STATIC_OUTPUT_MANIFEST_READ_GAS", readGas, 100000, 2
                    )
                )
            )
        );
    }

    function _raiseManifestGas(JoinManifest verifier) private {
        require(
            verifier.DEPENDENCY_READ_GAS() == MANIFEST_READ
                && verifier.governanceAuthority() == address(executor),
            "original fixed GGP identity and authority"
        );
        (uint256 value, uint256 floor, uint8 failure, uint64 revision) =
            verifier.gasParameterInfo(MANIFEST_READ);
        require(
            value == 16000000 && floor == 100000 && failure == 2 && revision == 1,
            "fresh explicit genesis gas configuration"
        );
        // Original StreamGasParameterHost V2 literal scope/state domains; no direct storage write.
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                address(verifier),
                MANIFEST_READ
            )
        );
        bytes32 old = _gasState(scope, value, floor, failure, revision);
        bytes32 next = _gasState(scope, uint256(32000000), floor, failure, uint64(2));
        vm.recordLogs();
        executor.execute(
            address(verifier),
            abi.encodeCall(
                IStreamGasParameterHost.raiseGasParameter, (MANIFEST_READ, uint256(32000000))
            ),
            scope,
            old,
            next
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        (value, floor, failure, revision) = verifier.gasParameterInfo(MANIFEST_READ);
        require(
            value == 32000000 && floor == 100000 && failure == 2 && revision == 2,
            "actual class1 governed monotonic setter effect"
        );
        require(
            logs.length == 1 && logs[0].emitter == address(verifier) && logs[0].topics.length == 4
                && logs[0].topics[0]
                    == keccak256(
                        "GasParameterUpdated(uint16,bytes32,address,bytes32,uint256,uint256,uint256)"
                    ) && logs[0].topics[1] == MANIFEST_READ
                && logs[0].topics[2] == bytes32(uint256(uint160(address(verifier))))
                && logs[0].topics[3] == bytes32(uint256(1))
                && keccak256(logs[0].data)
                    == keccak256(
                        abi.encode(uint16(2), uint256(16000000), uint256(32000000), uint256(100000))
                    ),
            "original gas setter event and exact active action"
        );
    }

    function _gasState(bytes32 scope, uint256 value, uint256 floor, uint8 failure, uint64 revision)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                bytes32(0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c),
                scope,
                value,
                floor,
                failure,
                revision
            )
        );
    }

    function _manifestBytes(Capture memory c) private view returns (bytes memory raw) {
        Preservation.Plan memory p = c.host.requireCurrentCheckpoint(c.id);
        Preservation.Output[] memory rows = new Preservation.Output[](p.tokenCount);
        for (uint256 i; i < rows.length; ++i) {
            rows[i] = c.host.outputAt(c.id, i);
        }
        raw = abi.encode(
            JoinDefinitions.SCHEMA,
            block.chainid,
            address(core),
            address(c.host),
            c.id,
            keccak256(abi.encode(p)),
            c.host.entropySourceSet(),
            p.inventoryHash,
            p.policyChainHash,
            c.host.metadataRouter(),
            p.preservationProfile,
            p.scope,
            p.contentRoot,
            p.outputRoot,
            p.tokenCount,
            rows
        );
        require(
            raw.length == 640 + 1152 * rows.length && _word(raw, 18) == bytes32(uint256(608))
                && _word(raw, 19) == bytes32(rows.length),
            "literal original19-word head and dynamic count"
        );
        for (uint256 i; i < rows.length; ++i) {
            require(
                abi.encode(rows[i]).length == 1152
                    && keccak256(_slice(raw, 640 + 1152 * i, 1152))
                        == keccak256(abi.encode(rows[i]))
                    && keccak256(_slice(raw, 640 + 1152 * i + 640, 288))
                        == keccak256(abi.encode(rows[i].preservation))
                    && keccak256(_slice(raw, 640 + 1152 * i + 928, 224))
                        == keccak256(abi.encode(rows[i].preservationAdmission)),
                "all36 original output words, including every binding and admission word"
            );
        }
    }

    function _archiveManifest(bytes memory raw)
        private
        returns (bytes32 artifact, bytes32 coverage)
    {
        JoinF.Artifact memory a;
        a.artistId = JOIN_ARTIST;
        a.schemaId = JoinDefinitions.SCHEMA;
        a.canonicalizationId = JoinDefinitions.CANON;
        a.hashAlgorithm = 1;
        a.contentHash = keccak256(raw);
        a.byteLength = uint64(raw.length);
        uint256 count = (raw.length + 8191) / 8192;
        a.chunkHashes = new bytes32[](count);
        a.chunkLengths = new uint32[](count);
        for (uint256 i; i < count; ++i) {
            uint256 size = raw.length - i * 8192;
            if (size > 8192) size = 8192;
            address pointer;
            (a.chunkHashes[i], pointer) = joinStore.publishChunk(_slice(raw, i * 8192, size));
            a.chunkLengths[i] = uint32(size);
            joinArchive.add(a.chunkHashes[i], pointer);
        }
        artifact = joinCoverage.recordArtifact(a);
        require(
            artifact
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_FINALITY_ARTIFACT_V1"),
                        block.chainid,
                        address(joinCoverage),
                        address(core),
                        a
                    )
                ),
            "literal exact whole-object artifact identity"
        );
        bytes32 plan = joinCoverage.beginCoverage(
            artifact, keccak256("archive family A"), keccak256("archive family B")
        );
        for (uint32 i; i < count; ++i) {
            coverage = joinCoverage.coverNextChunk(plan, i, a.chunkHashes[i]);
        }
        JoinF.Plan memory completed = joinCoverage.coveragePlan(plan);
        require(
            completed.nextIndex == count && completed.completionHash == coverage
                && coverage
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_FINALITY_ARTIFACT_COVERAGE_COMPLETE_V1"),
                            plan,
                            artifact,
                            completed.validationEpoch,
                            completed.evidenceChainHash,
                            completed.nextIndex
                        )
                    ),
            "actual ordered complete coverage and literal original completion identity"
        );
    }

    function _expectedManifest(Joined memory j) private view returns (JoinV.Manifest memory) {
        Preservation.Plan memory p = j.capture.host.checkpoint(j.capture.id);
        return JoinV.Manifest(
            j.capture.id,
            keccak256(abi.encode(p)),
            j.capture.host.entropySourceSet(),
            p.inventoryHash,
            p.policyChainHash,
            address(router),
            p.preservationProfile,
            j.artifact,
            j.coverage,
            JOIN_ARTIST,
            p.contentRoot,
            p.outputRoot,
            keccak256(j.raw),
            p.scope,
            p.tokenCount,
            uint64(j.raw.length)
        );
    }

    function _planHash(JoinManifest verifier, JoinV.Manifest memory m)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_PLAN_V1"),
                block.chainid,
                address(verifier),
                address(core),
                verifier.contentCheckpoint(),
                address(joinCoverage),
                m
            )
        );
    }

    function _assertJoined(Joined memory j, bytes32 record) private view {
        _assertComplete(j.capture);
        JoinV.Manifest memory current = j.verifier.requireCurrentManifest(record, JOIN_ARTIST);
        JoinV.Manifest memory expected = _expectedManifest(j);
        require(
            keccak256(abi.encode(current)) == keccak256(abi.encode(expected))
                && keccak256(abi.encode(j.verifier.manifestRecord(record)))
                    == keccak256(abi.encode(expected)),
            "all original manifest fields join exact actual checkpoint rows and artifact"
        );
        require(
            j.plan == _planHash(j.verifier, current)
                && record
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_VERIFIED_V1"),
                            j.plan
                        )
                    ) && j.verifier.manifestPlan(j.plan).nextIndex == current.tokenCount,
            "literal completion identity covers every original row"
        );
        JoinF.Artifact memory a = joinCoverage.artifact(j.artifact);
        JoinF.Coverage memory covered =
            joinCoverage.requireArtifactCoverage(j.coverage, JOIN_ARTIST, j.artifact);
        require(
            a.artistId == JOIN_ARTIST && a.contentHash == keccak256(j.raw)
                && a.byteLength == j.raw.length && a.schemaId == JoinDefinitions.SCHEMA
                && a.canonicalizationId == JoinDefinitions.CANON
                && covered.completionHash == j.coverage && covered.artifactHash == j.artifact
                && covered.artistId == a.artistId && covered.contentHash == a.contentHash
                && covered.byteLength == a.byteLength && covered.schemaId == a.schemaId
                && covered.canonicalizationId == a.canonicalizationId
                && covered.chunkCount == a.chunkHashes.length
                && covered.firstFamilyRecordHash == keccak256("archive family A")
                && covered.secondFamilyRecordHash == keccak256("archive family B"),
            "full artifact and exact two-family receipt join"
        );
        require(
            keccak256(schemas.documentBytes(JoinDefinitions.SCHEMA))
                    == keccak256(JoinDefinitions.document(JoinDefinitions.SCHEMA))
                && keccak256(schemas.documentBytes(JoinDefinitions.CANON))
                    == keccak256(JoinDefinitions.document(JoinDefinitions.CANON))
                && schemas.document(JoinDefinitions.SCHEMA).status
                    == JoinSchema.DocumentStatus.ACTIVE
                && schemas.document(JoinDefinitions.CANON).status
                    == JoinSchema.DocumentStatus.ACTIVE,
            "actual exact original V1 interpretation documents remain current"
        );
        for (uint32 i; i < a.chunkHashes.length; ++i) {
            (address pointer, bytes32 pin) = joinCoverage.artifactChunk(j.artifact, i);
            bytes memory code = pointer.code;
            require(
                pointer.codehash == pin && code.length == uint256(a.chunkLengths[i]) + 1
                    && code[0] == 0
                    && keccak256(_slice(code, 1, a.chunkLengths[i])) == a.chunkHashes[i]
                    && a.chunkHashes[i]
                        == keccak256(_slice(j.raw, uint256(i) * 8192, a.chunkLengths[i])),
                "actual SSTORE2 code bytes equal the complete canonical manifest"
            );
        }
    }

    function _expectCheckpointFailure(Joined memory j) private {
        vm.expectRevert(
            abi.encodeWithSelector(
                JoinV.OutputManifestReadFailed.selector,
                address(j.capture.host),
                Preservation.requireCurrentCheckpoint.selector
            )
        );
    }

    function _slice(bytes memory raw, uint256 start, uint256 size)
        private
        pure
        returns (bytes memory result)
    {
        result = new bytes(size);
        for (uint256 i; i < size; ++i) {
            result[i] = raw[start + i];
        }
    }

    function _word(bytes memory raw, uint256 index) private pure returns (bytes32 result) {
        assembly ("memory-safe") { result := mload(add(add(raw, 32), mul(index, 32))) }
    }
}
