// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { ScopedPolicyContentFixtureV2 } from "./StreamScopedPolicyContentCheckpointV2.t.sol";
import {
    StreamScopedPolicyContentCheckpointV2
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyContentCheckpointV2.sol";
import "./StreamContentLeafManifest.t.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as E
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
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
    StreamScopedPolicyOutputManifestV2
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyOutputManifestV2.sol";
import {
    IStreamScopedPolicyContentCheckpointV2 as O
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyContentCheckpointV2.sol";
import {
    IStreamScopedPolicyOutputManifestV2 as V
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyOutputManifestV2.sol";
import {
    StreamScopedPolicyOutputSchemasV2 as Definitions
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyOutputSchemasV2.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    IStreamPolicyOutputManifestV2 as OriginalOutput
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPolicyOutputManifestV2.sol";

/// @dev Explicit checkpoint computation boundary; actual producer/renderer recipes live in the sibling suite.
contract ScopedPolicyOutputCheckpointBoundary {
    address public immutable core;
    O.Plan private _plan;
    O.Output[] private _rows;
    bool public valid = true;

    constructor(address c) {
        core = c;
    }

    function PROFILE() external pure returns (bytes32) {
        return keccak256("6529STREAM_SCOPED_POLICY_CURRENT_FULL_CONTENT_V2");
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(O).interfaceId;
    }

    function entropySourceSet() external view returns (address) {
        return address(this);
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
                leaves[i].animationHash,
                E.TokenReadiness(
                    address(this),
                    address(this).codehash,
                    keccak256(abi.encode("full policy H", i)),
                    1,
                    0,
                    0,
                    1,
                    true,
                    false,
                    0
                ),
                keccak256(abi.encode("terminal admission", i))
            );
            _rows.push(row);
            chain = keccak256(
                abi.encode(keccak256("6529STREAM_SCOPED_POLICY_FULL_OUTPUTS_V2"), chain, i, row)
            );
        }
        _plan = O.Plan(
            keccak256("selection"),
            keccak256("selected complete plan"),
            keccak256("complete inventory"),
            keccak256("full frozen policy chain"),
            StreamFinalityScope(
                StreamFinalityScopeType.RELEASE, 1, 0, keccak256("actual scope boundary")
            ),
            uint64(count),
            uint64(count),
            keccak256("leaf chain"),
            StreamTokenContentTree.root(block.chainid, core, leaves),
            chain
        );
    }

    function setScope(StreamFinalityScope calldata scope) external {
        _plan.scope = scope;
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

/// @notice Actual scoped V2 registered interpretation bytes, SSTORE2 artifacts, archival aggregator and verifier.
/// @dev Checkpoint rendering, original archive family receipts and selected Finality/Core are named boundaries.
contract StreamScopedPolicyOutputManifestV2Test is CharacterizationTestBase, OfficialSafeFixture {
    bytes32 private constant ARTIST = keccak256("artist");
    bytes32 private constant CP = keccak256("checkpoint");
    CheckpointCoreBoundary private core;
    ScopedPolicyOutputCheckpointBoundary private checkpoint;
    StreamSchemaRegistry private schemas;
    StreamSchemaDocumentStore private store;
    StreamFinalityArtifactCoverage private artifacts;
    LeafManifestArchiveBoundary private archive;
    MetadataExecutorBoundary private authority;
    StreamScopedPolicyOutputManifestV2 private verifier;
    LeafManifestVm private constant mvm =
        LeafManifestVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function setUp() public {
        core = new CheckpointCoreBoundary();
        checkpoint = new ScopedPolicyOutputCheckpointBoundary(address(core));
        authority = new MetadataExecutorBoundary();
        schemas = new StreamSchemaRegistry(address(authority));
        store = StreamSchemaDocumentStore(schemas.chunkStore());
        _register(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(schemas.RAW_BYTES_DEFINITION())
        );
        _register(
            "STREAM_SCOPED_POLICY_OUTPUT_MANIFEST_V2",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            Definitions.document(Definitions.SCHEMA)
        );
        _register(
            "STREAM_ABI_SCOPED_POLICY_OUTPUT_MANIFEST_V2",
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
        verifier = new StreamScopedPolicyOutputManifestV2(
            address(core),
            address(checkpoint),
            address(artifacts),
            address(authority),
            IStreamGasParameterHost.GasParameterConfig(
                "STATIC_OUTPUT_MANIFEST_READ_GAS", 3000000, 100000, 2
            )
        );
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
                && m.outputRoot == p.outputRoot && m.entropySourceSet == address(checkpoint)
                && m.inventoryHash == p.inventoryHash && m.policyChainHash == p.policyChainHash
                && m.scope.scopeType == StreamFinalityScopeType.RELEASE
                && m.scope.scopeId == p.scope.scopeId && m.tokenCount == 3
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 2 && logs[1].emitter == address(verifier));
        require(
            logs[1].topics[1] == record && logs[1].topics[2] == plan
                && keccak256(logs[1].data) == keccak256(abi.encode(uint16(2), m))
        );
        require(
            verifier.beginManifest(CP, artifact, coverage, ARTIST) == plan
                && verifier.manifestPlan(plan).recordHash == record
        );
    }

    function testAllThreeCanonicalScopesAndDistinctOriginalCapability() public {
        require(verifier.supportsInterface(type(V).interfaceId));
        require(!verifier.supportsInterface(type(OriginalOutput).interfaceId));
        require(verifier.outputProfile() == verifier.scopedOutputProfile());
        require(
            verifier.outputProfile()
                == keccak256("6529STREAM_SCOPED_POLICY_CURRENT_FULL_CONTENT_V2")
        );
        require(verifier.SCHEMA_ID() != keccak256("STREAM_POLICY_OUTPUT_MANIFEST_V2"));
        bytes32 prior;
        for (uint8 kind = 1; kind <= 3; ++kind) {
            checkpoint.seed(1);
            StreamFinalityScope memory scope = StreamFinalityScope(
                StreamFinalityScopeType(kind),
                1,
                kind == 1 ? 1 : 0,
                kind == 1 ? bytes32(0) : bytes32(uint256(1))
            );
            checkpoint.setScope(scope);
            (bytes32 plan,,) = _begin(_bytes());
            bytes32 record = verifier.verifyNextOutputs(plan, 1);
            V.Manifest memory m = verifier.requireCurrentManifest(record, ARTIST);
            require(keccak256(abi.encode(m.scope)) == keccak256(abi.encode(scope)));
            require(record != prior, "scope kind participates in exact record identity");
            prior = record;
        }
    }

    function testCollectionViewMalformedScopeAndTokenMultiplicityRefused() public {
        StreamFinalityScope[7] memory bad = [
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0),
            StreamFinalityScope(StreamFinalityScopeType.VIEW, 1, 0, bytes32(uint256(1))),
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 0, 0),
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 1, bytes32(uint256(1))),
            StreamFinalityScope(StreamFinalityScopeType.RELEASE, 1, 1, bytes32(uint256(1))),
            StreamFinalityScope(StreamFinalityScopeType.SEASON, 1, 0, 0),
            StreamFinalityScope(StreamFinalityScopeType.SEASON, 0, 0, bytes32(uint256(1)))
        ];
        for (uint256 i; i < bad.length; ++i) {
            checkpoint.seed(1);
            checkpoint.setScope(bad[i]);
            (bytes32 artifact, bytes32 coverage) =
                _archive(_bytes(), Definitions.SCHEMA, Definitions.CANON);
            vm.expectRevert();
            verifier.beginManifest(CP, artifact, coverage, ARTIST);
        }
        checkpoint.seed(2);
        checkpoint.setScope(StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 1, 0));
        (bytes32 artifact, bytes32 coverage) =
            _archive(_bytes(), Definitions.SCHEMA, Definitions.CANON);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidOutputManifest.selector));
        verifier.beginManifest(CP, artifact, coverage, ARTIST);
    }

    function testScopeChangeInvalidatesCurrentRecordAndPreservesOriginalHistory() public {
        checkpoint.seed(1);
        (bytes32 plan,,) = _begin(_bytes());
        bytes32 record = verifier.verifyNextOutputs(plan, 1);
        V.Manifest memory saved = verifier.manifestRecord(record);
        checkpoint.setScope(
            StreamFinalityScope(StreamFinalityScopeType.SEASON, 1, 0, saved.scope.scopeId)
        );
        vm.expectRevert(abi.encodeWithSelector(V.InvalidOutputManifest.selector));
        verifier.requireCurrentManifest(record, ARTIST);
        require(
            keccak256(abi.encode(verifier.manifestRecord(record))) == keccak256(abi.encode(saved))
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

    function testFuzzEveryLeafPolicyAndAdmissionWordCompared(uint8 field, uint8 index) public {
        checkpoint.seed(3);
        bytes memory raw = _bytes();
        raw[576 + 640 + uint256(field) % 20 * 32 + uint256(index) % 32] ^= 0x01;
        (bytes32 plan,,) = _begin(raw);
        vm.expectRevert(abi.encodeWithSelector(V.OutputManifestMismatch.selector, uint256(1)));
        verifier.verifyNextOutputs(plan, 3);
        require(verifier.manifestPlan(plan).nextIndex == 0);
    }

    function testFuzzHeaderPolicyScopeOffsetAndCountCannotBeSubstituted(uint8 field) public {
        checkpoint.seed(1);
        bytes memory raw = _bytes();
        raw[uint256(field) % 18 * 32 + 31] ^= 0x01;
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
            O(source).entropySourceSet(),
            p.inventoryHash,
            p.policyChainHash,
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

/// @notice Actual scoped factory -> source set -> rendered checkpoint -> preserved manifest.
/// @dev Core/Artist/governance/module/version admission, selected Finality and the two original
/// archive-family receipts are named boundaries; this is not a complete finality ceremony.
contract StreamScopedPolicyOutputJoinedV2Test is ScopedPolicyContentFixtureV2 {
    bytes32 private constant JOINED_ARTIST = keccak256("joined scoped output artist");
    StreamSchemaRegistry private joinedSchemas;
    StreamSchemaDocumentStore private joinedStore;
    StreamFinalityArtifactCoverage private joinedArtifacts;
    LeafManifestArchiveBoundary private joinedArchive;
    MetadataExecutorBoundary private joinedAuthority;
    LeafManifestVm private constant joinedVm =
        LeafManifestVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testActualFactoryTerminalAndFinalizedOutputsIntoCoveredManifest() public {
        _scopedFixture(1, true);
        _joinedDeploy();
        (StreamScopedPolicyOutputManifestV2 verifier, bytes32 record) = _joinedComplete(2);
        V.Manifest memory m = verifier.requireCurrentManifest(record, JOINED_ARTIST);
        require(m.scope.scopeType == StreamFinalityScopeType.RELEASE && m.tokenCount == 2);
        O host = O(verifier.contentCheckpoint());
        O.Output memory terminal = host.outputAt(m.checkpointHash, 0);
        O.Output memory finalized = host.outputAt(m.checkpointHash, 1);
        require(
            terminal.entropy.terminal && !terminal.entropy.finalized && terminal.entropy.seed == 0
        );
        require(
            !finalized.entropy.terminal && finalized.entropy.finalized
                && finalized.entropy.status == 5 && finalized.entropy.seed != 0
        );
        require(host.sourceFactory() == address(scopedFactory));
        require(host.entropySourceSet() == m.entropySourceSet);
        require(E(m.entropySourceSet).factory() == address(scopedFactory));
        require(m.inventoryHash == E(m.entropySourceSet).originalInventoryHash());
        require(m.policyChainHash == E(m.entropySourceSet).originalPolicyChainHash());
    }

    function testActualFactoryDriftRefusesCurrentManifestAndRetainsExactHistory() public {
        _scopedFixture(2, true);
        _joinedDeploy();
        (StreamScopedPolicyOutputManifestV2 verifier, bytes32 record) = _joinedComplete(1);
        V.Manifest memory saved = verifier.requireCurrentManifest(record, JOINED_ARTIST);
        require(saved.scope.scopeType == StreamFinalityScopeType.TOKEN && saved.tokenCount == 1);
        bytes memory original = address(scopedFactory).code;
        vm.etch(address(scopedFactory), hex"00");
        vm.expectRevert();
        verifier.requireCurrentManifest(record, JOINED_ARTIST);
        require(
            keccak256(abi.encode(verifier.manifestRecord(record))) == keccak256(abi.encode(saved))
        );
        vm.etch(address(scopedFactory), original);
        require(
            keccak256(abi.encode(verifier.requireCurrentManifest(record, JOINED_ARTIST)))
                == keccak256(abi.encode(saved))
        );
    }

    function _joinedComplete(uint8 kind)
        private
        returns (StreamScopedPolicyOutputManifestV2 verifier, bytes32 record)
    {
        StreamFinalityScope memory scope = _scopedScope(kind);
        (StreamScopedPolicyContentCheckpointV2 host, bytes32 selected) = _scopedCapture(scope);
        bytes32 checkpoint = host.begin(selected, keccak256("joined scoped output"));
        host.append(checkpoint, _scopedPayload(scope));
        O.Plan memory p = host.requireCurrentCheckpoint(checkpoint);
        O.Output[] memory rows = new O.Output[](p.tokenCount);
        for (uint256 i; i < rows.length; ++i) {
            rows[i] = host.outputAt(checkpoint, i);
        }
        bytes memory raw = abi.encode(
            Definitions.SCHEMA,
            block.chainid,
            address(core),
            address(host),
            checkpoint,
            keccak256(abi.encode(p)),
            host.entropySourceSet(),
            p.inventoryHash,
            p.policyChainHash,
            p.scope,
            p.contentRoot,
            p.outputRoot,
            p.tokenCount,
            rows
        );
        (bytes32 artifact, bytes32 coverage) =
            _joinedArchive(raw, Definitions.SCHEMA, Definitions.CANON);
        verifier = new StreamScopedPolicyOutputManifestV2(
            address(core),
            address(host),
            address(joinedArtifacts),
            address(joinedAuthority),
            // Complete two-row reads reserve the original 16m render cap and preceding
            // policy/selection work. Fixture configuration is not a transaction-gas claim.
            IStreamGasParameterHost.GasParameterConfig(
                "STATIC_OUTPUT_MANIFEST_READ_GAS", 32000000, 100000, 2
            )
        );
        bytes32 plan = verifier.beginManifest(checkpoint, artifact, coverage, JOINED_ARTIST);
        record = verifier.verifyNextOutputs(plan, p.tokenCount);
        require(
            record != 0
                && verifier.requireCurrentManifest(record, JOINED_ARTIST).manifestHash
                    == keccak256(raw)
        );
    }

    function _joinedDeploy() private {
        joinedAuthority = new MetadataExecutorBoundary();
        joinedSchemas = new StreamSchemaRegistry(address(joinedAuthority));
        joinedStore = StreamSchemaDocumentStore(joinedSchemas.chunkStore());
        _joinedRegister(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(joinedSchemas.RAW_BYTES_DEFINITION())
        );
        _joinedRegister(
            "STREAM_SCOPED_POLICY_OUTPUT_MANIFEST_V2",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            Definitions.document(Definitions.SCHEMA)
        );
        _joinedRegister(
            "STREAM_ABI_SCOPED_POLICY_OUTPUT_MANIFEST_V2",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            Definitions.document(Definitions.CANON)
        );
        joinedArchive = new LeafManifestArchiveBoundary(address(core), address(joinedAuthority));
        address predicted = joinedVm.computeCreateAddress(
            address(this), uint256(joinedVm.getNonce(address(this))) + 1
        );
        joinedArtifacts = new StreamFinalityArtifactCoverage(
            address(core),
            address(joinedArchive),
            address(joinedSchemas),
            address(joinedStore),
            predicted,
            address(joinedAuthority),
            IStreamGasParameterHost.GasParameterConfig(
                "FINALITY_ARTIFACT_DEPENDENCY_READ_GAS", 300000, 300000, 2
            )
        );
        address finality =
            address(new LeafManifestFinalityBoundary(address(core), address(joinedArtifacts)));
        require(finality == predicted);
        joinedVm.mockCall(
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
    }

    function _joinedArchive(bytes memory raw, bytes32 schema, bytes32 canon)
        private
        returns (bytes32 artifact, bytes32 coverage)
    {
        F.Artifact memory a;
        a.artistId = JOINED_ARTIST;
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
            (a.chunkHashes[i], pointer) = joinedStore.publishChunk(part);
            a.chunkLengths[i] = uint32(take);
            joinedArchive.add(a.chunkHashes[i], pointer);
        }
        artifact = joinedArtifacts.recordArtifact(a);
        bytes32 plan = joinedArtifacts.beginCoverage(
            artifact, keccak256("archive family A"), keccak256("archive family B")
        );
        for (uint32 i; i < count; ++i) {
            coverage = joinedArtifacts.coverNextChunk(plan, i, a.chunkHashes[i]);
        }
    }

    function _joinedRegister(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory payload
    ) private {
        (bytes32 hash,) = joinedStore.publishChunk(payload);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name, kind, hash, joinedSchemas.RAW_BYTES(), 0, "", uint32(payload.length)
        );
        (bytes32 scope, bytes32 old, bytes32 next) =
            joinedSchemas.registrationTransition(spec, chunks);
        joinedAuthority.execute(
            address(joinedSchemas),
            abi.encodeCall(joinedSchemas.registerDocument, (spec, chunks)),
            scope,
            old,
            next
        );
    }
}
