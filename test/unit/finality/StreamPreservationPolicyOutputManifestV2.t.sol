// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/scoped-preservation-boundaries/StreamPreservationPolicyOutputManifestBoundaries.sol";
import {
    StreamPreservationPolicyOutputManifestV2 as FamilyManifest
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyOutputManifestV2.sol";
import {
    StreamPreservationPolicyOutputSchemasV2 as FamilyDefinitions
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyOutputSchemasV2.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Family
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";

/// @dev Actual schema documents, immutable chunks, artifact coverage and V2 manifest verifier.
/// Checkpoint/currentness/producer admission, archive-family receipts, Core/Finality and governance
/// remain explicit synthetic boundaries. No real renderer, op17 or finality admission is claimed.
contract StreamPreservationPolicyOutputManifestV2Test is CharacterizationTestBase {
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
    FamilyManifest private verifier;

    function setUp() public {
        core = new CheckpointCoreBoundary();
        producer = new PreservationManifestProducerBoundary();
        checkpoint = new PreservationManifestCheckpointBoundary(
            address(core), address(producer), address(new PreservationManifestProducerBoundary())
        );
        checkpoint.setProfile(Family.COLLECTION_CHECKPOINT_PROFILE);
        mvm.mockCall(
            address(checkpoint),
            abi.encodeWithSignature("preservationOutputProfile()"),
            abi.encode(Family.FAMILY_PROFILE)
        );
        authority = new MetadataExecutorBoundary();
        schemas = new StreamSchemaRegistry(address(authority));
        store = StreamSchemaDocumentStore(schemas.chunkStore());
        _register(
            "RAW_BYTES", Schema.DocumentKind.CANONICALIZATION, bytes(schemas.RAW_BYTES_DEFINITION())
        );
        _register(
            "STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2",
            Schema.DocumentKind.SCHEMA,
            FamilyDefinitions.document(FamilyDefinitions.SCHEMA)
        );
        _register(
            "STREAM_ABI_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2",
            Schema.DocumentKind.CANONICALIZATION,
            FamilyDefinitions.document(FamilyDefinitions.CANON)
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

    function testV2DefinitionsSeparateManifestAndCanonButPreserveExactLeaf() public pure {
        require(FamilyDefinitions.SCHEMA != Definitions.SCHEMA);
        require(FamilyDefinitions.CANON != Definitions.CANON);
        require(
            keccak256(FamilyDefinitions.document(FamilyDefinitions.SCHEMA))
                != keccak256(Definitions.document(Definitions.SCHEMA))
        );
        require(
            keccak256(FamilyDefinitions.document(FamilyDefinitions.CANON))
                != keccak256(Definitions.document(Definitions.CANON))
        );
        require(FamilyDefinitions.LEAF_SCHEMA == Definitions.LEAF_SCHEMA);
        require(
            keccak256(FamilyDefinitions.document(FamilyDefinitions.LEAF_SCHEMA))
                == keccak256(Definitions.document(Definitions.LEAF_SCHEMA))
        );
    }

    function testV2FullManifestRetainsActualRowsAndLiteralNewDomains() public {
        _seed(2);
        bytes memory raw = _bytes();
        require(raw.length == 640 + 1152 * 2);
        require(_word(raw, 0) == FamilyDefinitions.SCHEMA);
        require(_word(raw, 10) == Family.FAMILY_PROFILE);
        require(verifier.outputProfile() == Family.OUTPUT_MANIFEST_PROFILE);
        require(verifier.checkpointProfile() == Family.COLLECTION_CHECKPOINT_PROFILE);
        (bytes32 plan,,) = _begin(raw);
        V.Manifest memory m = verifier.manifestPlan(plan).manifest;
        require(
            plan
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_PLAN_V2"),
                        block.chainid,
                        address(verifier),
                        address(core),
                        address(checkpoint),
                        address(artifacts),
                        m
                    )
                )
        );
        bytes32 record = verifier.verifyNextOutputs(plan, 2);
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_VERIFIED_V2"),
                        plan
                    )
                )
        );
        require(
            keccak256(abi.encode(verifier.requireCurrentManifest(record, ARTIST)))
                == keccak256(abi.encode(m))
        );
        require(checkpoint.outputAt(CP, 0).preservation.profile == Family.ORIGINAL_PROFILE);
        require(checkpoint.outputAt(CP, 1).preservation.profile == Family.CURRENT_ARTIST_PROFILE);
    }

    function testV2BothCheckpointScopesHaveOneOutputCapability() public {
        checkpoint.setProfile(Family.SCOPED_CHECKPOINT_PROFILE);
        FamilyManifest scoped = _deploy();
        require(scoped.checkpointProfile() == Family.SCOPED_CHECKPOINT_PROFILE);
        require(scoped.outputProfile() == verifier.outputProfile());
        require(scoped.SCHEMA_ID() == verifier.SCHEMA_ID());
    }

    function testV1AndV2RejectCrossedCheckpointCapabilities() public {
        vm.expectRevert(abi.encodeWithSelector(V.InvalidOutputManifest.selector));
        new StreamPreservationPolicyOutputManifestV1(
            address(core),
            address(checkpoint),
            address(artifacts),
            address(authority),
            IStreamGasParameterHost.GasParameterConfig(
                "STATIC_OUTPUT_MANIFEST_READ_GAS", 3000000, 100000, 2
            )
        );
        checkpoint.setProfile(COLLECTION_PROFILE);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidOutputManifest.selector));
        _deploy();
        StreamPreservationPolicyOutputManifestV1 original = new StreamPreservationPolicyOutputManifestV1(
            address(core),
            address(checkpoint),
            address(artifacts),
            address(authority),
            IStreamGasParameterHost.GasParameterConfig(
                "STATIC_OUTPUT_MANIFEST_READ_GAS", 3000000, 100000, 2
            )
        );
        require(original.outputProfile() == COLLECTION_PROFILE);
        require(
            original.SCHEMA_ID() == Definitions.SCHEMA
                && original.CANONICALIZATION_ID() == Definitions.CANON
        );
    }

    function testV2ConstructorRejectsCrossedFamilyCapability() public {
        mvm.mockCall(
            address(checkpoint),
            abi.encodeWithSignature("preservationOutputProfile()"),
            abi.encode(Family.ORIGINAL_PROFILE)
        );
        vm.expectRevert(abi.encodeWithSelector(V.InvalidOutputManifest.selector));
        _deploy();
    }

    function testV2RejectsOriginalAndUnknownFamilyHeaders() public {
        _seed(1);
        bytes memory raw = _bytes();
        assembly ("memory-safe") { mstore(add(raw, 352), 0) }
        _rejectBegin(raw, FamilyDefinitions.SCHEMA, FamilyDefinitions.CANON);
        raw = _bytes();
        bytes32 old = Family.ORIGINAL_PROFILE;
        assembly ("memory-safe") { mstore(add(raw, 352), old) }
        _rejectBegin(raw, FamilyDefinitions.SCHEMA, FamilyDefinitions.CANON);
    }

    function testV2RejectsOldSchemaAndCanonEvenWithV2Rows() public {
        _seed(1);
        _rejectBegin(_bytes(), Definitions.SCHEMA, FamilyDefinitions.CANON);
        _rejectBegin(_bytes(), FamilyDefinitions.SCHEMA, Definitions.CANON);
    }

    function testV2RejectsPlanFamilyAtBeginAndCompletionWithoutCursorWrites() public {
        _seed(1);
        (bytes32 plan,,) = _begin(_bytes());
        O.Plan memory p = checkpoint.requireCurrentCheckpoint(CP);
        p.preservationProfile = Family.ORIGINAL_PROFILE;
        checkpoint.setPlan(p);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidOutputManifest.selector));
        verifier.verifyNextOutputs(plan, 1);
        require(verifier.manifestPlan(plan).nextIndex == 0);
        _rejectBegin(_bytes(), FamilyDefinitions.SCHEMA, FamilyDefinitions.CANON);
        p.preservationProfile = Family.FAMILY_PROFILE;
        checkpoint.setPlan(p);
        require(verifier.verifyNextOutputs(plan, 1) != 0);
    }

    function testV2ExactRowComparisonCannotRelabelProducerAndRetriesIdentically() public {
        _seed(2);
        bytes memory raw = _bytes();
        (bytes32 plan,,) = _begin(raw);
        O.Output memory row = checkpoint.outputAt(CP, 1);
        row.preservation.profile = Family.ORIGINAL_PROFILE;
        checkpoint.setRow(1, row);
        vm.expectRevert(abi.encodeWithSelector(V.OutputManifestMismatch.selector, uint256(1)));
        verifier.verifyNextOutputs(plan, 2);
        require(verifier.manifestPlan(plan).nextIndex == 0);
        row.preservation.profile = Family.CURRENT_ARTIST_PROFILE;
        checkpoint.setRow(1, row);
        require(verifier.verifyNextOutputs(plan, 2) != 0);
    }

    function testV2HistoricalManifestRetainedWhenCurrentPlanDrifts() public {
        _seed(1);
        (bytes32 plan,,) = _begin(_bytes());
        bytes32 record = verifier.verifyNextOutputs(plan, 1);
        bytes32 retained = keccak256(abi.encode(verifier.manifestRecord(record)));
        O.Plan memory p = checkpoint.requireCurrentCheckpoint(CP);
        p.preservationProfile = Family.ORIGINAL_PROFILE;
        checkpoint.setPlan(p);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidOutputManifest.selector));
        verifier.requireCurrentManifest(record, ARTIST);
        require(keccak256(abi.encode(verifier.manifestRecord(record))) == retained);
    }

    function _rejectBegin(bytes memory raw, bytes32 schema, bytes32 canon) private {
        // Use real admitted document bytes for the intentionally crossed archive tags too.
        if (schema == Definitions.SCHEMA && !schemas.document(schema).exists) {
            _register(
                "STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V1",
                Schema.DocumentKind.SCHEMA,
                Definitions.document(schema)
            );
        }
        if (canon == Definitions.CANON && !schemas.document(canon).exists) {
            _register(
                "STREAM_ABI_PRESERVATION_POLICY_OUTPUT_MANIFEST_V1",
                Schema.DocumentKind.CANONICALIZATION,
                Definitions.document(canon)
            );
        }
        (bytes32 artifact, bytes32 coverage) = _archive(raw, schema, canon);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidOutputManifest.selector));
        verifier.beginManifest(CP, artifact, coverage, ARTIST);
    }

    function _seed(uint256 count) private {
        checkpoint.seed(count, StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0));
        O.Plan memory p = checkpoint.requireCurrentCheckpoint(CP);
        p.preservationProfile = Family.FAMILY_PROFILE;
        bytes32 chain;
        for (uint256 i; i < count; ++i) {
            O.Output memory row = checkpoint.outputAt(CP, i);
            row.preservation.profile =
                i % 2 == 0 ? Family.ORIGINAL_PROFILE : Family.CURRENT_ARTIST_PROFILE;
            checkpoint.setRow(i, row);
            chain = keccak256(
                abi.encode(keccak256("6529STREAM_PRESERVATION_POLICY_OUTPUTS_V1"), chain, i, row)
            );
        }
        p.outputRoot = chain;
        checkpoint.setPlan(p);
    }

    function _deploy() private returns (FamilyManifest) {
        return new FamilyManifest(
            address(core),
            address(checkpoint),
            address(artifacts),
            address(authority),
            IStreamGasParameterHost.GasParameterConfig(
                "STATIC_OUTPUT_MANIFEST_READ_GAS", 3000000, 100000, 2
            )
        );
    }

    function _bytes() private view returns (bytes memory) {
        O.Plan memory p = checkpoint.requireCurrentCheckpoint(CP);
        O.Output[] memory rows = new O.Output[](p.tokenCount);
        for (uint256 i; i < rows.length; ++i) {
            rows[i] = checkpoint.outputAt(CP, i);
        }
        return abi.encode(
            FamilyDefinitions.SCHEMA,
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

    function _begin(bytes memory raw)
        private
        returns (bytes32 plan, bytes32 artifact, bytes32 coverage)
    {
        (artifact, coverage) = _archive(raw, FamilyDefinitions.SCHEMA, FamilyDefinitions.CANON);
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
