// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/scoped-preservation-boundaries/StreamPreservationPolicyOutputManifestBoundaries.sol";

/// @notice Actual new interpretation documents, SSTORE2 bytes, artifact coverage and manifest consumer.
/// @dev Checkpoint rendering/admission, archive-family receipts, selected Core/Finality and governance
/// are explicit boundaries. These tests do not prove preservation rendering or a finality ceremony.
contract StreamPreservationPolicyOutputManifestV1Test is CharacterizationTestBase {
    bytes32 private constant ARTIST = keccak256("artist");
    bytes32 private constant CP = keccak256("preservation checkpoint");
    bytes32 private constant COLLECTION_PROFILE =
        keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1");
    bytes32 private constant SCOPED_PROFILE =
        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_V1");
    LeafManifestVm private constant mvm =
        LeafManifestVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    CheckpointCoreBoundary private core;
    PreservationManifestProducerBoundary private producer;
    PreservationManifestCheckpointBoundary private checkpoint;
    StreamSchemaRegistry private schemas;
    StreamSchemaDocumentStore private store;
    StreamFinalityArtifactCoverage private artifacts;
    LeafManifestArchiveBoundary private archive;
    MetadataExecutorBoundary private authority;
    StreamPreservationPolicyOutputManifestV1 private verifier;

    // Compiler-generated independent event signature/encoding oracle.
    event OutputManifestVerified(
        uint16 schemaVersion,
        bytes32 indexed recordHash,
        bytes32 indexed planHash,
        V.Manifest manifest
    );

    function setUp() public {
        core = new CheckpointCoreBoundary();
        producer = new PreservationManifestProducerBoundary();
        checkpoint = new PreservationManifestCheckpointBoundary(
            address(core), address(producer), address(new PreservationManifestProducerBoundary())
        );
        authority = new MetadataExecutorBoundary();
        schemas = new StreamSchemaRegistry(address(authority));
        store = StreamSchemaDocumentStore(schemas.chunkStore());
        _register(
            "RAW_BYTES", Schema.DocumentKind.CANONICALIZATION, bytes(schemas.RAW_BYTES_DEFINITION())
        );
        _register(
            "STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V1",
            Schema.DocumentKind.SCHEMA,
            Definitions.document(Definitions.SCHEMA)
        );
        _register(
            "STREAM_ABI_PRESERVATION_POLICY_OUTPUT_MANIFEST_V1",
            Schema.DocumentKind.CANONICALIZATION,
            Definitions.document(Definitions.CANON)
        );
        archive = new LeafManifestArchiveBoundary(address(core), address(authority));
        address predicted =
            mvm.computeCreateAddress(address(this), uint256(mvm.getNonce(address(this))) + 1);
        artifacts = new StreamFinalityArtifactCoverage(
            address(core),
            address(archive),
            address(schemas),
            address(store),
            predicted,
            address(authority),
            IStreamGasParameterHost.GasParameterConfig(
                "FINALITY_ARTIFACT_DEPENDENCY_READ_GAS", 300000, 300000, 2
            )
        );
        address finality =
            address(new LeafManifestFinalityBoundary(address(core), address(artifacts)));
        require(finality == predicted);
        mvm.mockCall(
            address(core),
            abi.encodeCall(
                IStreamCorePointers.getSatellitePointer, (keccak256("ARTWORK_FINALITY_REGISTRY"))
            ),
            abi.encode(
                finality,
                finality.codehash,
                false,
                keccak256("ARTWORK_FINALITY_REGISTRY"),
                bytes4(0),
                address(0),
                uint8(1),
                bytes32(0),
                bytes32(0),
                uint64(1)
            )
        );
        verifier = _deploy();
    }

    function testExactLayoutFullAdmissionAndCompletionIdentity() public {
        _seed(3);
        bytes memory raw = _bytes();
        O.Plan memory p = checkpoint.requireCurrentCheckpoint(CP);
        P.Binding memory binding = checkpoint.outputAt(CP, 0).preservation;
        require(abi.encode(p).length == 448 && abi.encode(binding).length == 288);
        require(
            raw.length == 640 + 3 * 1152 && _word(raw, 18) == bytes32(uint256(608))
                && _word(raw, 19) == bytes32(uint256(3))
        );
        require(keccak256(_slice(raw, 640 + 20 * 32, 288)) == keccak256(abi.encode(binding)));
        O.Output memory first = checkpoint.outputAt(CP, 0);
        O.Output memory second = checkpoint.outputAt(CP, 1);
        require(
            abi.encode(first).length == 1152
                && abi.encode(first.preservationAdmission).length == 224
        );
        require(first.preservationAdmission.versionKey != second.preservationAdmission.versionKey);
        require(
            first.preservation.producer != second.preservation.producer
                && first.preservation.liveRenderer != second.preservation.liveRenderer
        );
        require(
            first.preservation.core == address(core)
                && second.preservation.metadataRouter == checkpoint.metadataRouter()
        );
        require(
            keccak256(_slice(raw, 640 + 1152 + 20 * 32, 288))
                == keccak256(abi.encode(second.preservation))
        );
        require(
            first.entropy.terminal && !first.entropy.finalized && !second.entropy.terminal
                && second.entropy.finalized
        );
        require(
            keccak256(_slice(raw, 640 + 29 * 32, 224))
                == keccak256(abi.encode(first.preservationAdmission))
        );
        (bytes32 plan, bytes32 artifact, bytes32 coverage) = _begin(raw);
        require(verifier.verifyNextOutputs(plan, 1) == 0);
        vm.recordLogs();
        bytes32 record = verifier.verifyNextOutputs(plan, 2);
        Vm.Log[] memory actual = vm.getRecordedLogs();
        V.Manifest memory m = verifier.requireCurrentManifest(record, ARTIST);
        require(abi.encode(m).length == 608);
        require(
            m.checkpointHash == CP && m.checkpointStateHash == keccak256(abi.encode(p))
                && m.manifestHash == keccak256(raw)
        );
        require(
            m.artifactHash == artifact && m.coverageHash == coverage && m.artistId == ARTIST
                && m.byteLength == raw.length
        );
        require(
            m.contentRoot == p.contentRoot && m.outputRoot == p.outputRoot
                && m.inventoryHash == p.inventoryHash && m.policyChainHash == p.policyChainHash
        );
        require(
            m.entropySourceSet == address(checkpoint)
                && m.metadataRouter == checkpoint.metadataRouter()
                && m.preservationProfile == p.preservationProfile
        );
        require(
            keccak256(abi.encode(m.scope)) == keccak256(abi.encode(p.scope)) && m.tokenCount == 3
        );
        require(
            plan
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_PLAN_V1"),
                        block.chainid,
                        address(verifier),
                        address(core),
                        address(checkpoint),
                        address(artifacts),
                        m
                    )
                )
        );
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_VERIFIED_V1"),
                        plan
                    )
                )
        );
        vm.recordLogs();
        emit OutputManifestVerified(1, record, plan, m);
        Vm.Log[] memory oracle = vm.getRecordedLogs();
        require(actual.length == 2 && actual[1].emitter == address(verifier));
        require(
            keccak256(abi.encode(actual[1].topics)) == keccak256(abi.encode(oracle[0].topics))
                && keccak256(actual[1].data) == keccak256(oracle[0].data)
        );
        require(
            verifier.beginManifest(CP, artifact, coverage, ARTIST) == plan
                && verifier.manifestPlan(plan).recordHash == record
        );
        require(
            verifier.outputProfile() == COLLECTION_PROFILE
                && verifier.supportsInterface(type(V).interfaceId)
        );
    }

    function testScopedProfileCarriesExactTokenReleaseAndSeasonTuples() public {
        checkpoint.setProfile(SCOPED_PROFILE);
        verifier = _deploy();
        for (uint8 i = 1; i <= 3; ++i) {
            StreamFinalityScope memory scope = StreamFinalityScope(
                StreamFinalityScopeType(i),
                9,
                i == 1 ? 1 : 0,
                i == 1 ? bytes32(0) : keccak256(abi.encode("scope", i))
            );
            checkpoint.seed(1, scope);
            (bytes32 plan,,) = _begin(_bytes());
            bytes32 record = verifier.verifyNextOutputs(plan, 1);
            require(
                keccak256(abi.encode(verifier.requireCurrentManifest(record, ARTIST).scope))
                    == keccak256(abi.encode(scope))
            );
        }
        require(verifier.outputProfile() == SCOPED_PROFILE);
    }

    function testCrossChunkRowsAndPartitionIndependentRecord() public {
        _seed(12); // Row six crosses the 8192-byte SSTORE2 chunk boundary.
        (bytes32 plan,,) = _begin(_bytes());
        verifier.verifyNextOutputs(plan, 8);
        uint256 saved = vm.snapshotState();
        bytes32 once = verifier.verifyNextOutputs(plan, 4);
        require(vm.revertToState(saved));
        verifier.verifyNextOutputs(plan, 1);
        bytes32 partitioned = verifier.verifyNextOutputs(plan, 3);
        require(
            once == partitioned && verifier.requireCurrentManifest(once, ARTIST).tokenCount == 12
        );
    }

    function testFuzzEveryHeaderWordIncludingRouterProfileOffsetAndCount(uint8 field) public {
        _seed(1);
        bytes memory raw = _bytes();
        raw[uint256(field) % 20 * 32 + 31] ^= 0x01;
        (bytes32 artifact, bytes32 coverage) = _archive(raw, Definitions.SCHEMA, Definitions.CANON);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidOutputManifest.selector));
        verifier.beginManifest(CP, artifact, coverage, ARTIST);
    }

    function testFuzzEveryRowWordIncludingFullAdmission(uint8 field, uint8 byteIndex) public {
        _seed(3);
        bytes memory raw = _bytes();
        raw[640 + 1152 + uint256(field) % 36 * 32 + uint256(byteIndex) % 32] ^= 0x01;
        (bytes32 plan,,) = _begin(raw);
        vm.expectRevert(abi.encodeWithSelector(V.OutputManifestMismatch.selector, uint256(1)));
        verifier.verifyNextOutputs(plan, 3);
        require(
            verifier.manifestPlan(plan).nextIndex == 0
                && verifier.manifestPlan(plan).recordHash == 0
        );
    }

    function testEveryAdmissionWordIsCompared() public {
        _seed(1);
        for (uint256 i; i < 7; ++i) {
            bytes memory raw = _bytes();
            raw[640 + (29 + i) * 32 + 31] ^= 0x01;
            (bytes32 plan,,) = _begin(raw);
            vm.expectRevert(abi.encodeWithSelector(V.OutputManifestMismatch.selector, uint256(0)));
            verifier.verifyNextOutputs(plan, 1);
            require(verifier.manifestPlan(plan).nextIndex == 0);
        }
    }

    function testReorderedOrDuplicatedRowsCannotComplete() public {
        _seed(3);
        for (uint256 mode; mode < 2; ++mode) {
            bytes memory raw = _bytes();
            bytes memory row0 = _slice(raw, 640, 1152);
            for (uint256 i; i < 1152; ++i) {
                if (mode == 0) raw[640 + i] = raw[1792 + i];
                raw[1792 + i] = row0[i];
            }
            (bytes32 plan,,) = _begin(raw);
            vm.expectRevert(
                abi.encodeWithSelector(
                    V.OutputManifestMismatch.selector, mode == 0 ? uint256(0) : uint256(1)
                )
            );
            verifier.verifyNextOutputs(plan, 3);
            require(verifier.manifestPlan(plan).nextIndex == 0);
        }
    }

    function testOldV2TagsAndLayoutTrailingBytesAndWrongArtistRejected() public {
        _seed(1);
        bytes memory raw = _bytes();
        for (uint256 i; i < 4; ++i) {
            bytes memory candidate =
                i == 2 ? _oldBytes() : i == 3 ? bytes.concat(raw, hex"00") : raw;
            (bytes32 artifact, bytes32 coverage) = _archive(
                candidate,
                i == 0 ? keccak256("STREAM_POLICY_OUTPUT_MANIFEST_V2") : Definitions.SCHEMA,
                i == 1 ? keccak256("STREAM_ABI_POLICY_OUTPUT_MANIFEST_V2") : Definitions.CANON
            );
            vm.expectRevert(abi.encodeWithSelector(V.InvalidOutputManifest.selector));
            verifier.beginManifest(CP, artifact, coverage, ARTIST);
        }
        (bytes32 plan,,) = _begin(raw);
        bytes32 record = verifier.verifyNextOutputs(plan, 1);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidOutputManifest.selector));
        verifier.requireCurrentManifest(record, keccak256("other artist"));
    }

    function testOldCheckpointProfileUnknownProfileAndMissingCapabilityRejected() public {
        bytes32[3] memory profiles = [
            keccak256("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2"),
            keccak256("6529STREAM_SCOPED_POLICY_CURRENT_FULL_CONTENT_V2"),
            bytes32(0)
        ];
        for (uint256 i; i < profiles.length; ++i) {
            checkpoint.setProfile(profiles[i]);
            vm.expectRevert(abi.encodeWithSelector(V.InvalidOutputManifest.selector));
            _deploy();
        }
        checkpoint.setProfile(COLLECTION_PROFILE);
        checkpoint.setCapability(false);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidOutputManifest.selector));
        _deploy();
    }

    function testChangedCommonRouterRejectsCurrentAndPreservesHistoricalReceipt() public {
        _seed(1);
        (bytes32 plan,,) = _begin(_bytes());
        bytes32 record = verifier.verifyNextOutputs(plan, 1);
        bytes32 receipt = keccak256(abi.encode(verifier.manifestRecord(record)));
        address saved = checkpoint.metadataRouter();
        checkpoint.setRouter(address(producer));
        vm.expectRevert(abi.encodeWithSelector(V.InvalidOutputManifest.selector));
        verifier.requireCurrentManifest(record, ARTIST);
        require(keccak256(abi.encode(verifier.manifestRecord(record))) == receipt);
        checkpoint.setRouter(saved);
        require(keccak256(abi.encode(verifier.requireCurrentManifest(record, ARTIST))) == receipt);
    }

    function testWrongPreservationProfileRejectedBeforeBeginAndAtCompletion() public {
        _seed(1);
        O.Plan memory p = checkpoint.requireCurrentCheckpoint(CP);
        p.preservationProfile = keccak256("invented preservation projection");
        checkpoint.setPlan(p);
        (bytes32 artifact, bytes32 coverage) =
            _archive(_bytes(), Definitions.SCHEMA, Definitions.CANON);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidOutputManifest.selector));
        verifier.beginManifest(CP, artifact, coverage, ARTIST);
        p.preservationProfile = keccak256("6529STREAM_PRESERVATION_RENDER_V1");
        checkpoint.setPlan(p);
        (bytes32 plan,,) = _begin(_bytes());
        p.preservationProfile = 0;
        checkpoint.setPlan(p);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidOutputManifest.selector));
        verifier.verifyNextOutputs(plan, 1);
        require(verifier.manifestPlan(plan).nextIndex == 0);
        p.preservationProfile = keccak256("6529STREAM_PRESERVATION_RENDER_V1");
        checkpoint.setPlan(p);
        require(verifier.verifyNextOutputs(plan, 1) != 0);
    }

    function testEveryPerRowBindingWordIncludingProducerRuntimeIsCompared() public {
        _seed(2);
        for (uint256 i; i < 9; ++i) {
            bytes memory raw = _bytes();
            raw[640 + 1152 + (20 + i) * 32 + 31] ^= 0x01;
            (bytes32 plan,,) = _begin(raw);
            vm.expectRevert(abi.encodeWithSelector(V.OutputManifestMismatch.selector, uint256(1)));
            verifier.verifyNextOutputs(plan, 2);
            require(verifier.manifestPlan(plan).nextIndex == 0);
        }
    }

    function testSelectedProducersCannotBeSubstitutedBetweenRows() public {
        _seed(2);
        (bytes32 plan,,) = _begin(_bytes());
        O.Output memory first = checkpoint.outputAt(CP, 0);
        O.Output memory second = checkpoint.outputAt(CP, 1);
        P.Binding memory saved = second.preservation;
        second.preservation = first.preservation;
        checkpoint.setRow(1, second);
        vm.expectRevert(abi.encodeWithSelector(V.OutputManifestMismatch.selector, uint256(1)));
        verifier.verifyNextOutputs(plan, 2);
        require(verifier.manifestPlan(plan).nextIndex == 0);
        second.preservation = saved;
        checkpoint.setRow(1, second);
        require(verifier.verifyNextOutputs(plan, 2) != 0);
    }

    function testAdmissionDriftBetweenBeginAndVerifyRollsBackThenExactRetry() public {
        _seed(2);
        (bytes32 plan,,) = _begin(_bytes());
        O.Output memory row = checkpoint.outputAt(CP, 1);
        bytes32 saved = row.preservationAdmission.goldenHash;
        row.preservationAdmission.goldenHash = keccak256("changed current admission");
        checkpoint.setRow(1, row);
        vm.expectRevert(abi.encodeWithSelector(V.OutputManifestMismatch.selector, uint256(1)));
        verifier.verifyNextOutputs(plan, 2);
        require(
            verifier.manifestPlan(plan).nextIndex == 0
                && verifier.manifestPlan(plan).recordHash == 0
        );
        row.preservationAdmission.goldenHash = saved;
        checkpoint.setRow(1, row);
        require(verifier.verifyNextOutputs(plan, 2) != 0);
    }

    function testIncompleteCheckpointAndChangedCompletedPlanRejected() public {
        _seed(2);
        O.Plan memory p = checkpoint.requireCurrentCheckpoint(CP);
        p.nextIndex = 1;
        checkpoint.setPlan(p);
        (bytes32 artifact, bytes32 coverage) =
            _archive(_bytes(), Definitions.SCHEMA, Definitions.CANON);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidOutputManifest.selector));
        verifier.beginManifest(CP, artifact, coverage, ARTIST);
        p.nextIndex = 2;
        checkpoint.setPlan(p);
        (bytes32 plan,,) = _begin(_bytes());
        bytes32 saved = p.policyChainHash;
        p.policyChainHash = keccak256("changed policy set");
        checkpoint.setPlan(p);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidOutputManifest.selector));
        verifier.verifyNextOutputs(plan, 2);
        require(verifier.manifestPlan(plan).nextIndex == 0);
        p.policyChainHash = saved;
        checkpoint.setPlan(p);
        require(verifier.verifyNextOutputs(plan, 2) != 0);
    }

    function testCheckpointCurrentnessFailureAndHistoricalRecordAreSeparate() public {
        _seed(1);
        (bytes32 plan,,) = _begin(_bytes());
        bytes32 record = verifier.verifyNextOutputs(plan, 1);
        bytes32 receipt = keccak256(abi.encode(verifier.manifestRecord(record)));
        checkpoint.setValid(false);
        _expectRead(address(checkpoint), O.requireCurrentCheckpoint.selector);
        verifier.requireCurrentManifest(record, ARTIST);
        require(keccak256(abi.encode(verifier.manifestRecord(record))) == receipt);
        checkpoint.setValid(true);
        require(keccak256(abi.encode(verifier.requireCurrentManifest(record, ARTIST))) == receipt);
    }

    function testLateArchiveDriftRollsBackCursorAndIdenticalRetryAfterRefresh() public {
        _seed(12);
        (bytes32 plan, bytes32 artifact, bytes32 coverage) = _begin(_bytes());
        verifier.verifyNextOutputs(plan, 8);
        bytes memory input = abi.encodeCall(verifier.verifyNextOutputs, (plan, uint256(4)));
        archive.advanceEpoch();
        (bool ok, bytes memory reason) = address(verifier).call(input);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            V.OutputManifestReadFailed.selector,
                            address(artifacts),
                            IStreamFinalityArtifactCoverage.requireArtifactCoverage.selector
                        )
                    )
        );
        require(
            verifier.manifestPlan(plan).nextIndex == 8
                && verifier.manifestPlan(plan).recordHash == 0
        );
        F.Artifact memory a = artifacts.artifact(artifact);
        for (uint32 i; i < a.chunkHashes.length; ++i) {
            artifacts.refreshNextChunk(coverage, i, a.chunkHashes[i]);
        }
        (ok, reason) = address(verifier).call(input);
        require(ok);
        bytes32 record = abi.decode(reason, (bytes32));
        require(verifier.requireCurrentManifest(record, ARTIST).coverageHash == coverage);
    }

    function testChunkRuntimeDriftCannotAdvanceAndRestoredBytesRetry() public {
        _seed(3);
        (bytes32 plan, bytes32 artifact,) = _begin(_bytes());
        verifier.verifyNextOutputs(plan, 1);
        (address pointer,) = artifacts.artifactChunk(artifact, 0);
        bytes memory code = pointer.code;
        vm.etch(pointer, hex"00");
        vm.expectRevert(abi.encodeWithSelector(V.OutputManifestComponentChanged.selector, pointer));
        verifier.verifyNextOutputs(plan, 2);
        require(verifier.manifestPlan(plan).nextIndex == 1);
        vm.etch(pointer, code);
        require(verifier.verifyNextOutputs(plan, 2) != 0);
    }

    function testRetiredDefinitionRejectsCurrentButRetainsExactHistory() public {
        _seed(1);
        (bytes32 plan,,) = _begin(_bytes());
        bytes32 record = verifier.verifyNextOutputs(plan, 1);
        bytes32 receipt = keccak256(abi.encode(verifier.manifestRecord(record)));
        (bytes32 scope, bytes32 old, bytes32 next) =
            schemas.statusTransition(Definitions.SCHEMA, Schema.DocumentStatus.DEPRECATED);
        authority.execute(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus, (Definitions.SCHEMA, Schema.DocumentStatus.DEPRECATED)
            ),
            scope,
            old,
            next
        );
        vm.expectRevert(abi.encodeWithSelector(V.InvalidOutputManifest.selector));
        verifier.requireCurrentManifest(record, ARTIST);
        require(keccak256(abi.encode(verifier.manifestRecord(record))) == receipt);
    }

    function testCheckpointRouterAndOutputReturnWidthsAreExact() public {
        _seed(1);
        bytes memory raw = _bytes();
        (bytes32 artifact, bytes32 coverage) = _archive(raw, Definitions.SCHEMA, Definitions.CANON);
        bytes memory input = abi.encodeCall(O.requireCurrentCheckpoint, (CP));
        bytes memory original = abi.encode(checkpoint.requireCurrentCheckpoint(CP));
        mvm.mockCall(address(checkpoint), input, bytes.concat(original, bytes32(0)));
        _expectRead(address(checkpoint), O.requireCurrentCheckpoint.selector);
        verifier.beginManifest(CP, artifact, coverage, ARTIST);
        mvm.mockCall(address(checkpoint), input, original);
        input = abi.encodeCall(O.metadataRouter, ());
        original = abi.encode(checkpoint.metadataRouter());
        mvm.mockCall(address(checkpoint), input, _slice(original, 0, 31));
        _expectRead(address(checkpoint), O.metadataRouter.selector);
        verifier.beginManifest(CP, artifact, coverage, ARTIST);
        mvm.mockCall(address(checkpoint), input, original);
        bytes32 plan = verifier.beginManifest(CP, artifact, coverage, ARTIST);
        input = abi.encodeCall(O.outputAt, (CP, uint256(0)));
        original = abi.encode(checkpoint.outputAt(CP, 0));
        mvm.mockCall(address(checkpoint), input, _slice(original, 0, 1120));
        _expectRead(address(checkpoint), O.outputAt.selector);
        verifier.verifyNextOutputs(plan, 1);
        require(verifier.manifestPlan(plan).nextIndex == 0);
        mvm.mockCall(address(checkpoint), input, original);
        require(verifier.verifyNextOutputs(plan, 1) != 0);
    }

    function testStrictParentStarvationLeavesCursorUntouchedAndRetrySucceeds() public {
        _seed(1);
        (bytes32 plan,,) = _begin(_bytes());
        bytes memory input = abi.encodeCall(verifier.verifyNextOutputs, (plan, uint256(1)));
        (bool ok, bytes memory result) = address(verifier).call{ gas: 300000 }(input);
        require(!ok && result.length == 68 && bytes4(result) == V.OutputManifestParentGas.selector);
        require(
            verifier.manifestPlan(plan).nextIndex == 0
                && verifier.manifestPlan(plan).recordHash == 0
        );
        (ok, result) = address(verifier).call(input);
        require(ok && abi.decode(result, (bytes32)) != 0);
    }

    function _deploy() private returns (StreamPreservationPolicyOutputManifestV1) {
        return new StreamPreservationPolicyOutputManifestV1(
            address(core),
            address(checkpoint),
            address(artifacts),
            address(authority),
            IStreamGasParameterHost.GasParameterConfig(
                "STATIC_OUTPUT_MANIFEST_READ_GAS", 3000000, 100000, 2
            )
        );
    }

    function _seed(uint256 count) private {
        checkpoint.seed(count, StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0));
    }

    function _bytes() private view returns (bytes memory) {
        O.Plan memory p = checkpoint.requireCurrentCheckpoint(CP);
        O.Output[] memory rows = new O.Output[](p.tokenCount);
        for (uint256 i; i < rows.length; ++i) {
            rows[i] = checkpoint.outputAt(CP, i);
        }
        return abi.encode(
            Definitions.SCHEMA,
            block.chainid,
            address(core),
            address(checkpoint),
            CP,
            keccak256(abi.encode(p)),
            checkpoint.entropySourceSet(),
            p.inventoryHash,
            p.policyChainHash,
            checkpoint.metadataRouter(),
            p.preservationProfile,
            p.scope,
            p.contentRoot,
            p.outputRoot,
            p.tokenCount,
            rows
        );
    }

    function _oldBytes() private view returns (bytes memory) {
        O.Plan memory p = checkpoint.requireCurrentCheckpoint(CP);
        OldOutput.Output[] memory rows = new OldOutput.Output[](p.tokenCount);
        for (uint256 i; i < rows.length; ++i) {
            O.Output memory row = checkpoint.outputAt(CP, i);
            rows[i] = OldOutput.Output(
                row.leaf,
                row.selectionRowHash,
                row.sourceFactsHash,
                row.htmlHash,
                row.entropy,
                row.terminalAdmissionHash
            );
        }
        bytes memory raw = abi.encode(
            Definitions.SCHEMA,
            block.chainid,
            address(core),
            address(checkpoint),
            CP,
            keccak256(abi.encode(p)),
            checkpoint.entropySourceSet(),
            p.inventoryHash,
            p.policyChainHash,
            p.scope,
            p.contentRoot,
            p.outputRoot,
            p.tokenCount,
            rows
        );
        require(raw.length == 576 + 640 * p.tokenCount);
        return raw;
    }

    function _begin(bytes memory raw)
        private
        returns (bytes32 plan, bytes32 artifact, bytes32 coverage)
    {
        (artifact, coverage) = _archive(raw, Definitions.SCHEMA, Definitions.CANON);
        plan = verifier.beginManifest(CP, artifact, coverage, ARTIST);
    }

    function _archive(bytes memory raw, bytes32 schema, bytes32 canon)
        private
        returns (bytes32 artifact, bytes32 coverage)
    {
        F.Artifact memory a;
        a.artistId = ARTIST;
        a.schemaId = schema;
        a.canonicalizationId = canon;
        a.hashAlgorithm = 1;
        a.contentHash = keccak256(raw);
        a.byteLength = uint64(raw.length);
        uint256 count = (raw.length + 8191) / 8192;
        a.chunkHashes = new bytes32[](count);
        a.chunkLengths = new uint32[](count);
        for (uint256 i; i < count; ++i) {
            uint256 take = raw.length - i * 8192;
            if (take > 8192) take = 8192;
            address pointer;
            (a.chunkHashes[i], pointer) = store.publishChunk(_slice(raw, i * 8192, take));
            a.chunkLengths[i] = uint32(take);
            archive.add(a.chunkHashes[i], pointer);
        }
        artifact = artifacts.recordArtifact(a);
        bytes32 plan = artifacts.beginCoverage(
            artifact, keccak256("archive family A"), keccak256("archive family B")
        );
        for (uint32 i; i < count; ++i) {
            coverage = artifacts.coverNextChunk(plan, i, a.chunkHashes[i]);
        }
    }

    function _register(string memory name, Schema.DocumentKind kind, bytes memory payload) private {
        (bytes32 hash,) = store.publishChunk(payload);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        Schema.DocumentSpec memory spec = Schema.DocumentSpec(
            name, kind, hash, schemas.RAW_BYTES(), 0, "", uint32(payload.length)
        );
        (bytes32 scope, bytes32 old, bytes32 next) = schemas.registrationTransition(spec, chunks);
        authority.execute(
            address(schemas),
            abi.encodeCall(schemas.registerDocument, (spec, chunks)),
            scope,
            old,
            next
        );
    }

    function _expectRead(address target, bytes4 selector) private {
        vm.expectRevert(
            abi.encodeWithSelector(V.OutputManifestReadFailed.selector, target, selector)
        );
    }

    function _slice(bytes memory raw, uint256 offset, uint256 length)
        private
        pure
        returns (bytes memory out)
    {
        out = new bytes(length);
        for (uint256 i; i < length; ++i) {
            out[i] = raw[offset + i];
        }
    }

    function _word(bytes memory raw, uint256 index) private pure returns (bytes32 value) {
        assembly ("memory-safe") { value := mload(add(add(raw, 32), mul(index, 32))) }
    }
}
