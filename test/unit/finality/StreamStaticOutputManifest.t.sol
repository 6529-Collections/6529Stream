// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamContentLeafManifest.t.sol";
import {
    StaticGasSource,
    StaticGasRouter,
    StaticGasAttribution,
    StaticGasSelection
} from "./StreamStaticContentGasBudget.t.sol";
import { StreamRendererV1 } from "../../../smart-contracts/domains/metadata/StreamRendererV1.sol";
import {
    StreamStaticContentCheckpoint
} from "../../../smart-contracts/domains/finality/StreamStaticContentCheckpoint.sol";
import {
    IStreamRenderer as R
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";

import {
    IStreamSchemaRegistry
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import { MetadataExecutorBoundary } from "../../helpers/scoped-preservation-boundaries/StreamCollectionMetadataV1Boundaries.sol";
import {
    StreamSchemaRegistry
} from "../../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";
import {
    StreamStaticOutputManifest
} from "../../../smart-contracts/domains/finality/StreamStaticOutputManifest.sol";
import {
    IStreamStaticContentCheckpoint as O
} from "../../../smart-contracts/interfaces/stream/finality/IStreamStaticContentCheckpoint.sol";
import {
    IStreamStaticOutputManifest as V
} from "../../../smart-contracts/interfaces/stream/finality/IStreamStaticOutputManifest.sol";
import {
    StreamStaticOutputSchemas as Definitions
} from "../../../smart-contracts/domains/finality/StreamStaticOutputSchemas.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @dev Explicit checkpoint computation boundary; actual producer/renderer recipes live in the sibling suite.
contract StaticOutputCheckpointBoundary {
    address public immutable core;
    O.Plan private _plan;
    O.Output[] private _rows;
    bool public valid = true;

    constructor(address c) {
        core = c;
    }

    function seed(uint256 count) external {
        delete _rows;
        bytes32 chain;
        StreamTokenContentLeaf[] memory leaves = new StreamTokenContentLeaf[](count);
        for (uint256 i; i < count; ++i) {
            leaves[i] = StreamTokenContentLeaf(
                i + 1,
                keccak256(abi.encode("json", i)),
                keccak256(abi.encode("image", i)),
                keccak256(abi.encode("html", i)),
                0,
                keccak256(abi.encode("token data", i))
            );
            O.Output memory row = O.Output(
                leaves[i],
                keccak256(abi.encode("selection", i)),
                keccak256(abi.encode("source", i)),
                leaves[i].animationHash
            );
            _rows.push(row);
            chain = keccak256(
                abi.encode(keccak256("6529STREAM_STATIC_FULL_OUTPUTS_V1"), chain, i, row)
            );
        }
        _plan = O.Plan(
            keccak256("selection"),
            keccak256("selected complete plan"),
            StreamFinalityScope(
                StreamFinalityScopeType.RELEASE, 1, 0, keccak256("published subset")
            ),
            uint64(count),
            uint64(count),
            keccak256("leaf chain"),
            StreamTokenContentTree.root(block.chainid, core, leaves),
            chain
        );
    }

    function setValid(bool value) external {
        valid = value;
    }

    function requireCurrentCheckpoint(bytes32) external view returns (O.Plan memory) {
        require(valid);
        return _plan;
    }

    function outputAt(bytes32, uint256 index) external view returns (O.Output memory) {
        return _rows[index];
    }
}

/// @notice Actual registered interpretation bytes, SSTORE2 artifacts, complete archival aggregator and verifier.
/// @dev Checkpoint rendering, original archive family receipts and selected Finality/Core are named boundaries.
contract StreamStaticOutputManifestTest is CharacterizationTestBase, OfficialSafeFixture {
    bytes32 private constant ARTIST = keccak256("artist");
    bytes32 private constant CP = keccak256("checkpoint");
    CheckpointCoreBoundary private core;
    StaticOutputCheckpointBoundary private checkpoint;
    StreamSchemaRegistry private schemas;
    StreamSchemaDocumentStore private store;
    StreamFinalityArtifactCoverage private artifacts;
    LeafManifestArchiveBoundary private archive;
    MetadataExecutorBoundary private authority;
    StreamStaticOutputManifest private verifier;
    LeafManifestVm private constant mvm =
        LeafManifestVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function setUp() public {
        core = new CheckpointCoreBoundary();
        checkpoint = new StaticOutputCheckpointBoundary(address(core));
        authority = new MetadataExecutorBoundary();
        schemas = new StreamSchemaRegistry(address(authority));
        store = StreamSchemaDocumentStore(schemas.chunkStore());
        _register(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(schemas.RAW_BYTES_DEFINITION())
        );
        _register(
            "STREAM_STATIC_OUTPUT_MANIFEST_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            Definitions.document(Definitions.SCHEMA)
        );
        _register(
            "STREAM_ABI_STATIC_OUTPUT_MANIFEST_V1",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
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
        verifier = new StreamStaticOutputManifest(
            address(core),
            address(checkpoint),
            address(artifacts),
            address(authority),
            IStreamGasParameterHost.GasParameterConfig(
                "STATIC_OUTPUT_MANIFEST_READ_GAS", 3000000, 100000, 2
            )
        );
    }

    function testActualRendererCheckpointRowsCoveredAndRevalidated() public {
        StaticGasSource entropy = new StaticGasSource();
        StaticGasRouter route = new StaticGasRouter(address(core));
        StaticGasAttribution display = new StaticGasAttribution(address(core), address(route));
        StreamRendererV1.Deployment memory d;
        d.sources = StreamRendererV1.Sources(
            address(core),
            address(route),
            address(core),
            address(entropy),
            address(0),
            address(display)
        );
        d.readGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 2000000, 100000, 2
        );
        d.attributionGas = IStreamGasParameterHost.GasParameterConfig(
            "STATIC_ATTRIBUTION_GAS", 8000000, 8000000, 1
        );
        d.manifest = R.RendererManifest(
            keccak256("6529STREAM_RENDERER_V1"),
            keccak256("6529STREAM_STATIC_RENDERER_V1"),
            keccak256("STREAM_CONTEXT_V1"),
            keccak256("STATIC"),
            keccak256("schema"),
            "ipfs://schema",
            "ipfs://manifest",
            keccak256("manifest"),
            16777216,
            16777216,
            false
        );
        route.bind(new StreamRendererV1(d));
        core.configure(address(route), address(entropy));
        StaticGasSelection selected = new StaticGasSelection(address(core), address(route));
        StreamStaticContentCheckpoint actual = new StreamStaticContentCheckpoint(
            address(selected),
            address(0),
            IStreamGasParameterHost.GasParameterConfig(
                "STATIC_CONTENT_READ_GAS", 1000000, 100000, 2
            ),
            IStreamGasParameterHost.GasParameterConfig(
                    "STATIC_CONTENT_RENDER_GAS", 30000000, 100000, 2
                )
        );
        bytes32 id = actual.begin(keccak256("actual selected row"), 0);
        O.Payload[] memory payload = new O.Payload[](1);
        payload[0] = O.Payload(1, "", bytes(route.tokenHTML(1)));
        actual.append(id, payload);
        bytes memory raw = _manifestBytes(address(actual), id);
        (bytes32 artifact, bytes32 coverage) = _archive(raw, Definitions.SCHEMA, Definitions.CANON);
        StreamStaticOutputManifest joined = new StreamStaticOutputManifest(
            address(core),
            address(actual),
            address(artifacts),
            address(authority),
            IStreamGasParameterHost.GasParameterConfig(
                "STATIC_OUTPUT_MANIFEST_READ_GAS", 50000000, 100000, 2
            )
        );
        bytes32 plan = joined.beginManifest(id, artifact, coverage, ARTIST);
        bytes32 record = joined.verifyNextOutputs(plan, 1);
        O.Plan memory observed = actual.requireCurrentCheckpoint(id);
        V.Manifest memory result = joined.requireCurrentManifest(record, ARTIST);
        require(
            result.manifestHash == keccak256(raw) && result.contentRoot == observed.contentRoot
                && result.outputRoot == observed.outputRoot
        );
        display.setFail(true);
        vm.expectRevert();
        joined.requireCurrentManifest(record, ARTIST);
        require(joined.manifestRecord(record).outputRoot == observed.outputRoot);
    }

    function testCompletePreservedRowsScopeAndOriginalCompletionIdentity() public {
        checkpoint.seed(3);
        bytes memory raw = _bytes();
        (bytes32 plan, bytes32 artifact, bytes32 coverage) = _begin(raw);
        require(verifier.verifyNextOutputs(plan, 1) == 0);
        vm.recordLogs();
        bytes32 record = verifier.verifyNextOutputs(plan, 2);
        V.Manifest memory m = verifier.requireCurrentManifest(record, ARTIST);
        O.Plan memory p = checkpoint.requireCurrentCheckpoint(CP);
        require(
            m.checkpointHash == CP && m.checkpointStateHash == keccak256(abi.encode(p))
                && m.manifestHash == keccak256(raw) && m.artifactHash == artifact
                && m.coverageHash == coverage && m.contentRoot == p.contentRoot
                && m.outputRoot == p.outputRoot
                && m.scope.scopeType == StreamFinalityScopeType.RELEASE
                && m.scope.scopeId == p.scope.scopeId && m.tokenCount == 3
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 2 && logs[1].emitter == address(verifier));
        require(
            logs[1].topics[1] == record && logs[1].topics[2] == plan
                && keccak256(logs[1].data) == keccak256(abi.encode(uint16(1), m))
        );
        require(
            verifier.beginManifest(CP, artifact, coverage, ARTIST) == plan
                && verifier.manifestPlan(plan).recordHash == record
        );
    }

    function testCrossChunkCompleteRowAndPartitionIndependentRecord() public {
        checkpoint.seed(30);
        (bytes32 plan,,) = _begin(_bytes());
        verifier.verifyNextOutputs(plan, 16);
        verifier.verifyNextOutputs(plan, 10);
        uint256 saved = vm.snapshotState();
        bytes32 first = verifier.verifyNextOutputs(plan, 4);
        require(vm.revertToState(saved));
        verifier.verifyNextOutputs(plan, 1);
        bytes32 second = verifier.verifyNextOutputs(plan, 3);
        require(first == second && verifier.requireCurrentManifest(first, ARTIST).tokenCount == 30);
    }

    function testFuzzEveryOriginalLeafAndCompanionWordCompared(uint8 field, uint8 index) public {
        checkpoint.seed(3);
        bytes memory raw = _bytes();
        raw[480 + 288 + uint256(field) % 9 * 32 + uint256(index) % 32] ^= 0x01;
        (bytes32 plan,,) = _begin(raw);
        vm.expectRevert(abi.encodeWithSelector(V.OutputManifestMismatch.selector, uint256(1)));
        verifier.verifyNextOutputs(plan, 3);
        require(verifier.manifestPlan(plan).nextIndex == 0);
    }

    function testFuzzHeaderScopeOffsetAndCountCannotBeSubstituted(uint8 field) public {
        checkpoint.seed(1);
        bytes memory raw = _bytes();
        raw[uint256(field) % 15 * 32 + 31] ^= 0x01;
        (bytes32 artifact, bytes32 coverage) = _archive(raw, Definitions.SCHEMA, Definitions.CANON);
        vm.expectRevert();
        verifier.beginManifest(CP, artifact, coverage, ARTIST);
    }

    function testOldSchemaTrailingBytesAndWrongArtistRefused() public {
        checkpoint.seed(1);
        bytes memory raw = _bytes();
        for (uint256 i; i < 3; ++i) {
            (bytes32 artifact, bytes32 coverage) = _archive(
                i == 2 ? bytes.concat(raw, hex"00") : raw,
                i == 0 ? keccak256("STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1") : Definitions.SCHEMA,
                i == 1 ? keccak256("STREAM_ABI_TOKEN_CONTENT_LEAF_MANIFEST_V1") : Definitions.CANON
            );
            vm.expectRevert();
            verifier.beginManifest(CP, artifact, coverage, ARTIST);
        }
        (bytes32 plan,,) = _begin(raw);
        bytes32 record = verifier.verifyNextOutputs(plan, 1);
        vm.expectRevert();
        verifier.requireCurrentManifest(record, keccak256("other artist"));
    }

    function testRetiredDefinitionAndChangedOutputRejectCurrentButKeepHistory() public {
        checkpoint.seed(1);
        (bytes32 plan,,) = _begin(_bytes());
        bytes32 record = verifier.verifyNextOutputs(plan, 1);
        checkpoint.setValid(false);
        vm.expectRevert();
        verifier.requireCurrentManifest(record, ARTIST);
        checkpoint.setValid(true);
        (bytes32 scope, bytes32 old, bytes32 next) = schemas.statusTransition(
            Definitions.SCHEMA, IStreamSchemaRegistry.DocumentStatus.DEPRECATED
        );
        authority.execute(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus,
                (Definitions.SCHEMA, IStreamSchemaRegistry.DocumentStatus.DEPRECATED)
            ),
            scope,
            old,
            next
        );
        vm.expectRevert();
        verifier.requireCurrentManifest(record, ARTIST);
        require(verifier.manifestRecord(record).tokenCount == 1);
    }

    function testChunkRuntimeMutationAndMalformedDefinitionAreTerminal() public {
        checkpoint.seed(3);
        (bytes32 plan, bytes32 artifact,) = _begin(_bytes());
        verifier.verifyNextOutputs(plan, 1);
        (address pointer,) = artifacts.artifactChunk(artifact, 0);
        bytes memory code = pointer.code;
        vm.etch(pointer, hex"00");
        vm.expectRevert();
        verifier.verifyNextOutputs(plan, 2);
        require(verifier.manifestPlan(plan).nextIndex == 1);
        vm.etch(pointer, code);
        mvm.mockCall(
            address(schemas),
            abi.encodeCall(IStreamSchemaRegistry.documentBytes, (Definitions.SCHEMA)),
            abi.encode(bytes("invented meaning"))
        );
        vm.expectRevert();
        verifier.verifyNextOutputs(plan, 2);
        require(verifier.manifestPlan(plan).nextIndex == 1);
    }

    function testActualSafeLateArchiveFailureAndIdenticalRetry() public {
        checkpoint.seed(3);
        (bytes32 plan, bytes32 artifact, bytes32 coverage) = _begin(_bytes());
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x652931;
        keys[1] = 0x652932;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 999);
        bytes memory input = abi.encodeCall(verifier.verifyNextOutputs, (plan, uint256(3)));
        uint256 nonce = account.nonce();
        bytes32 digest = account.getTransactionHash(
            address(verifier), 0, input, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory signatures = safeThresholdSignature(keys, digest);
        archive.advanceEpoch();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        account.execTransaction(
            address(verifier), 0, input, 0, 0, 0, 0, address(0), payable(address(0)), signatures
        );
        require(
            account.nonce() == nonce && verifier.manifestPlan(plan).nextIndex == 0
                && verifier.manifestPlan(plan).recordHash == 0
        );
        F.Artifact memory a = artifacts.artifact(artifact);
        for (uint32 i; i < a.chunkHashes.length; ++i) {
            artifacts.refreshNextChunk(coverage, i, a.chunkHashes[i]);
        }
        require(
            account.execTransaction(
                address(verifier), 0, input, 0, 0, 0, 0, address(0), payable(address(0)), signatures
            )
        );
        require(
            account.nonce() == nonce + 1
                && verifier.requireCurrentManifest(verifier.manifestPlan(plan).recordHash, ARTIST)
                .coverageHash == coverage
        );
    }

    function _bytes() private view returns (bytes memory) {
        return _manifestBytes(address(checkpoint), CP);
    }

    function _manifestBytes(address source, bytes32 id) private view returns (bytes memory) {
        O.Plan memory p = O(source).requireCurrentCheckpoint(id);
        O.Output[] memory rows = new O.Output[](p.tokenCount);
        for (uint256 i; i < rows.length; ++i) {
            rows[i] = O(source).outputAt(id, i);
        }
        return abi.encode(
            Definitions.SCHEMA,
            block.chainid,
            address(core),
            source,
            id,
            keccak256(abi.encode(p)),
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
            bytes memory part = new bytes(take);
            for (uint256 j; j < take; ++j) {
                part[j] = raw[i * 8192 + j];
            }
            address pointer;
            (a.chunkHashes[i], pointer) = store.publishChunk(part);
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

    function _register(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory payload
    ) private {
        (bytes32 hash,) = store.publishChunk(payload);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
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
}
