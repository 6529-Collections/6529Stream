// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamSchemaRegistry
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import "./StreamContentLeafManifest.t.sol";
import { MetadataExecutorBoundary } from "../../helpers/scoped-preservation-boundaries/StreamCollectionMetadataV1Boundaries.sol";
import {
    StreamSchemaRegistry
} from "../../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";
import {
    StreamViewPreservationOutputManifestV1 as Manifest
} from "../../../smart-contracts/domains/finality/StreamViewPreservationOutputManifestV1.sol";
import {
    StreamViewPreservationManifestTypesV1 as M
} from "../../../smart-contracts/interfaces/stream/finality/StreamViewPreservationManifestTypesV1.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as C
} from "../../../smart-contracts/interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    IStreamViewPreservationContentCheckpointV1 as CP
} from "../../../smart-contracts/interfaces/stream/finality/IStreamViewPreservationContentCheckpointV1.sol";
import {
    StreamViewPreservationManifestEncodingV1 as Encoding
} from "../../../smart-contracts/domains/finality/StreamViewPreservationManifestEncodingV1.sol";
import {
    StreamViewPreservationOutputSchemasV1 as Definitions
} from "../../../smart-contracts/domains/finality/StreamViewPreservationOutputSchemasV1.sol";

/// @dev Explicit current checkpoint boundary. Actual observation/source tests are in the sibling suite.
contract PreservationViewManifestCheckpointBoundary {
    C.Configuration private _config;
    C.Plan private _plan;
    bool public valid = true;
    bytes32 public immutable configurationHash;

    constructor(address core) {
        _config.core = core;
        _config.coreCodeHash = core.codehash;
        _config.chainId = block.chainid;
        configurationHash = keccak256(abi.encode(core, address(this), block.chainid));
    }

    function configuration() external view returns (C.Configuration memory) {
        return _config;
    }

    function checkpointProfile() external pure returns (bytes32) {
        return C.PROFILE;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(CP).interfaceId;
    }

    function seed(uint64 count) external {
        _plan = C.Plan(
            StreamFinalityScope(StreamFinalityScopeType.VIEW, 1, 0, keccak256("sealed membership")),
            keccak256("actual typed adoption"),
            keccak256("source"),
            keccak256("membership"),
            keccak256("policy"),
            count,
            count,
            keccak256("rows"),
            keccak256("output root"),
            keccak256("distinct full preservation content tree")
        );
    }

    function setValid(bool yes) external {
        valid = yes;
    }

    function changeSource(bytes32 value) external {
        _plan.sourceContextHash = value;
    }

    function requireCurrentCheckpoint(bytes32) external view returns (C.Plan memory) {
        require(valid, "current checkpoint refused");
        return _plan;
    }

    function outputAt(bytes32, uint256 i) external pure returns (C.Output memory o) {
        o.index = uint64(i);
        o.tokenId = i * 3 + 11;
        o.collectionSerial = i * 7 + 2;
        o.lifecycle = i % 2 == 0 ? 2 : 3;
        o.burned = i % 2 != 0;
        o.servingKind = o.burned ? 2 : 1;
        o.tokenDataHash = keccak256(abi.encode("data", i));
        o.entropy.coordinator = address(0x1234);
        o.entropy.coordinatorCodeHash = keccak256("coordinator");
        o.entropy.policyHash = keccak256(abi.encode("policy", i));
        o.entropy.explicitPolicy = true;
        o.entropy.policy.renderRequirement = 1;
        o.entropy.terminal = true;
        o.entropy.status = 1;
        o.jsonHash = keccak256(abi.encode("json", i));
        o.htmlHash = keccak256(abi.encode("html", i));
        o.jsonBytes = uint32(i + 17);
        o.htmlBytes = uint32(i + 29);
    }
}

/// @notice Actual manifest, Schema, Store and ArtifactCoverage; named checkpoint/Archive/Finality boundaries.
contract StreamViewPreservationOutputManifestV1Test is CharacterizationTestBase {
    bytes32 private constant ARTIST = keccak256("artist");
    bytes32 private constant ID = keccak256("view checkpoint");
    CheckpointCoreBoundary private core;
    PreservationViewManifestCheckpointBoundary private checkpoint;
    StreamSchemaRegistry private schemas;
    StreamSchemaDocumentStore private store;
    StreamFinalityArtifactCoverage private artifacts;
    LeafManifestArchiveBoundary private archive;
    MetadataExecutorBoundary private authority;
    Manifest private verifier;
    M.Configuration private config;
    LeafManifestVm private constant mvm =
        LeafManifestVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function setUp() public {
        core = new CheckpointCoreBoundary();
        checkpoint = new PreservationViewManifestCheckpointBoundary(address(core));
        authority = new MetadataExecutorBoundary();
        schemas = new StreamSchemaRegistry(address(authority));
        store = StreamSchemaDocumentStore(schemas.chunkStore());
        _register(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(schemas.RAW_BYTES_DEFINITION())
        );
        _register(
            "STREAM_VIEW_PRESERVATION_OUTPUT_PART_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            Definitions.document(Definitions.PART)
        );
        _register(
            "STREAM_ABI_VIEW_PRESERVATION_OUTPUT_PART_V1",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            Definitions.document(Definitions.PART_CANON)
        );
        _register(
            "STREAM_VIEW_PRESERVATION_OUTPUT_MANIFEST_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            Definitions.document(Definitions.INDEX)
        );
        _register(
            "STREAM_ABI_VIEW_PRESERVATION_OUTPUT_MANIFEST_V1",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            Definitions.document(Definitions.INDEX_CANON)
        );
        _register(
            "STREAM_VIEW_PRESERVATION_CONTENT_LEAF_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            Definitions.document(Definitions.LEAF)
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
        config = M.Configuration(
            address(core),
            address(core).codehash,
            address(checkpoint),
            address(checkpoint).codehash,
            checkpoint.configurationHash(),
            address(artifacts),
            address(artifacts).codehash,
            address(schemas),
            address(schemas).codehash,
            block.chainid,
            3000000,
            4000000
        );
        verifier = new Manifest(config);
        checkpoint.seed(3);
    }

    function _header() private view returns (M.Header memory h) {
        C.Plan memory p = checkpoint.requireCurrentCheckpoint(ID);
        h = M.Header(
            ID,
            keccak256(abi.encode(p)),
            p.scope,
            p.adoptionRecord,
            p.sourceContextHash,
            p.membershipHash,
            p.policyChainHash,
            p.tokenCount,
            p.outputRoot,
            p.contentRoot
        );
    }

    function _part(uint64 first) private view returns (bytes memory raw) {
        M.Header memory h = _header();
        uint256 n = h.tokenCount - first;
        if (n > 64) n = 64;
        C.Output[] memory rows = new C.Output[](n);
        for (uint256 i; i < n; ++i) {
            rows[i] = checkpoint.outputAt(ID, first + i);
        }
        raw = abi.encode(
            keccak256("STREAM_VIEW_PRESERVATION_OUTPUT_PART_V1"),
            config.chainId,
            address(core),
            address(checkpoint),
            checkpoint.configurationHash(),
            h,
            first,
            rows
        );
        require(
            raw.length == 672 + 992 * n
                && keccak256(raw) == keccak256(Encoding.part(config, h, first, rows))
        );
    }

    function _prepare(uint64 first) private returns (bytes32 key) {
        (bytes32 a, bytes32 c) = _archive(_part(first), Definitions.PART, Definitions.PART_CANON);
        key = verifier.preparePart(ID, first, a, c, ARTIST);
    }

    function _descriptor(bytes32 key) private view returns (M.Descriptor memory d) {
        M.Part memory p = verifier.partRecord(key);
        return M.Descriptor(
            key,
            p.carrier.artifactHash,
            p.carrier.coverageHash,
            p.carrier.contentHash,
            p.carrier.byteLength,
            p.first,
            p.count,
            p.firstToken,
            p.lastToken
        );
    }

    function _index(bytes32[] memory keys) private view returns (bytes memory raw) {
        M.Descriptor[] memory ds = new M.Descriptor[](keys.length);
        for (uint256 i; i < keys.length; ++i) {
            ds[i] = _descriptor(keys[i]);
        }
        raw = abi.encode(
            keccak256("STREAM_VIEW_PRESERVATION_OUTPUT_MANIFEST_V1"),
            config.chainId,
            address(core),
            address(checkpoint),
            checkpoint.configurationHash(),
            _header(),
            ARTIST,
            ds
        );
        require(
            raw.length == 672 + 288 * keys.length
                && keccak256(raw) == keccak256(Encoding.index(config, _header(), ARTIST, ds))
        );
    }

    function _begin(bytes memory raw) private returns (bytes32 key) {
        (bytes32 a, bytes32 c) = _archive(raw, Definitions.INDEX, Definitions.INDEX_CANON);
        key = verifier.beginManifest(ID, a, c, ARTIST);
    }

    function _single() private returns (bytes32 part, bytes32 plan) {
        part = _prepare(0);
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = part;
        plan = _begin(_index(keys));
    }

    function testLiteralCompletePartIndexAndRecordWithBurnedDiscriminant() public {
        (bytes32 part, bytes32 plan) = _single();
        M.Part memory p = verifier.partRecord(part);
        require(
            part
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_OUTPUT_PART_VERIFIED_V1"),
                        block.chainid,
                        address(verifier),
                        verifier.configurationHash(),
                        p
                    )
                )
        );
        vm.recordLogs();
        bytes32 record = verifier.verifyNextPart(plan, part);
        M.Plan memory result = verifier.requireCurrentManifest(record, ARTIST);
        M.Descriptor memory d = _descriptor(part);
        bytes32 chain = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_OUTPUT_PART_CHAIN_V1"), plan, _header()
            )
        );
        chain = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_OUTPUT_PART_CHAIN_V1"), chain, uint16(0), d
            )
        );
        require(
            result.partChain == chain && result.nextRow == 3 && result.nextPart == 1
                && result.previousToken == 17
        );
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_OUTPUT_MANIFEST_VERIFIED_V1"),
                        block.chainid,
                        address(verifier),
                        verifier.configurationHash(),
                        plan,
                        chain
                    )
                )
        );
        require(keccak256(abi.encode(verifier.manifestPart(record, 0))) == keccak256(abi.encode(d)));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 2 && logs[1].topics[1] == record && logs[1].topics[2] == plan);
    }

    function testTwoPartsExact64BoundaryAndLastRemainder() public {
        checkpoint.seed(65);
        bytes32 first = _prepare(0);
        bytes32 last = _prepare(64);
        require(verifier.partRecord(first).count == 64 && verifier.partRecord(last).count == 1);
        bytes32[] memory keys = new bytes32[](2);
        keys[0] = first;
        keys[1] = last;
        bytes32 plan = _begin(_index(keys));
        require(verifier.verifyNextPart(plan, first) == 0);
        bytes32 record = verifier.verifyNextPart(plan, last);
        require(verifier.requireCurrentManifest(record, ARTIST).nextRow == 65);
    }

    function testSwappedOmittedDuplicateAndUnalignedPartsRefuse() public {
        checkpoint.seed(65);
        bytes32 first = _prepare(0);
        bytes32 last = _prepare(64);
        bytes32[] memory keys = new bytes32[](2);
        keys[0] = last;
        keys[1] = first;
        bytes32 plan = _begin(_index(keys));
        vm.expectRevert(abi.encodeWithSelector(M.ViewManifestOrder.selector, uint256(0)));
        verifier.verifyNextPart(plan, last);
        vm.expectRevert(abi.encodeWithSelector(M.ViewManifestOrder.selector, uint256(0)));
        verifier.verifyNextPart(plan, first);
        keys[0] = first;
        keys[1] = first;
        plan = _begin(_index(keys));
        verifier.verifyNextPart(plan, first);
        vm.expectRevert(abi.encodeWithSelector(M.ViewManifestOrder.selector, uint256(1)));
        verifier.verifyNextPart(plan, first);
        require(
            verifier.manifestPlan(plan).recordHash == 0 && verifier.manifestPlan(plan).nextRow == 64
        );
        bytes32[] memory omitted = new bytes32[](1);
        omitted[0] = first;
        (bytes32 omittedArtifact, bytes32 omittedCoverage) =
            _archive(_index(omitted), Definitions.INDEX, Definitions.INDEX_CANON);
        vm.expectRevert(abi.encodeWithSelector(M.InvalidViewManifest.selector));
        verifier.beginManifest(ID, omittedArtifact, omittedCoverage, ARTIST);
        vm.expectRevert(abi.encodeWithSelector(M.ViewManifestOrder.selector, uint256(1)));
        verifier.preparePart(ID, 1, bytes32(uint256(1)), bytes32(uint256(1)), ARTIST);
    }

    function testWrongFullHeaderTerminalFieldsAndTrailingBytesAreRejected() public {
        bytes memory raw = _part(0);
        uint256 offset = 32 * 11;
        raw[offset] ^= bytes1(uint8(1));
        (bytes32 a, bytes32 c) = _archive(raw, Definitions.PART, Definitions.PART_CANON);
        vm.expectRevert(abi.encodeWithSelector(M.InvalidViewManifest.selector));
        verifier.preparePart(ID, 0, a, c, ARTIST);
        raw = _part(0);
        raw[672 + 32 * 26 + 31] ^= bytes1(uint8(1));
        (a, c) = _archive(raw, Definitions.PART, Definitions.PART_CANON);
        vm.expectRevert(abi.encodeWithSelector(M.InvalidViewManifest.selector));
        verifier.preparePart(ID, 0, a, c, ARTIST);
        raw = bytes.concat(_part(0), hex"00");
        (a, c) = _archive(raw, Definitions.PART, Definitions.PART_CANON);
        vm.expectRevert(abi.encodeWithSelector(M.InvalidViewManifest.selector));
        verifier.preparePart(ID, 0, a, c, ARTIST);
        require(_prepare(0) != 0);
    }

    function testPreparationHasNoCurrentRecordAndLateIndexFailureRollsBackRetry() public {
        bytes32 part = _prepare(0);
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = part;
        bytes memory raw = _index(keys);
        raw[672 + 32 * 8 + 31] ^= bytes1(uint8(1));
        bytes32 plan = _begin(raw);
        bytes32 beforeHash = keccak256(abi.encode(verifier.manifestPlan(plan)));
        vm.expectRevert(abi.encodeWithSelector(M.ViewManifestOrder.selector, uint256(0)));
        verifier.verifyNextPart(plan, part);
        require(beforeHash == keccak256(abi.encode(verifier.manifestPlan(plan))));
        bytes32 correct = _begin(_index(keys));
        bytes32 record = verifier.verifyNextPart(correct, part);
        require(verifier.requireCurrentManifest(record, ARTIST).recordHash == record);
    }

    function testCurrentCheckpointAndArchiveDriftRetainHistoricalBytes() public {
        (bytes32 part, bytes32 plan) = _single();
        bytes32 record = verifier.verifyNextPart(plan, part);
        bytes32 saved = keccak256(abi.encode(verifier.manifestRecord(record)));
        checkpoint.setValid(false);
        vm.expectRevert();
        verifier.requireCurrentManifest(record, ARTIST);
        require(saved == keccak256(abi.encode(verifier.manifestRecord(record))));
        checkpoint.setValid(true);
        verifier.requireCurrentManifest(record, ARTIST);
        archive.advanceEpoch();
        vm.expectRevert();
        verifier.requireCurrentManifest(record, ARTIST);
        require(saved == keccak256(abi.encode(verifier.manifestRecord(record))));
    }

    function testSourceDriftBetweenPartsCannotCompleteAndExactRestoreSucceeds() public {
        checkpoint.seed(65);
        bytes32 first = _prepare(0);
        bytes32 last = _prepare(64);
        bytes32[] memory keys = new bytes32[](2);
        keys[0] = first;
        keys[1] = last;
        bytes32 plan = _begin(_index(keys));
        verifier.verifyNextPart(plan, first);
        checkpoint.changeSource(keccak256("changed"));
        vm.expectRevert(abi.encodeWithSelector(M.ViewManifestChanged.selector, plan));
        verifier.verifyNextPart(plan, last);
        require(verifier.manifestPlan(plan).nextPart == 1);
        checkpoint.changeSource(keccak256("source"));
        bytes32 record = verifier.verifyNextPart(plan, last);
        require(verifier.requireCurrentManifest(record, ARTIST).nextRow == 65);
    }

    function testCarrierCorruptionRefusesAndRestoredSameCallSucceeds() public {
        (bytes32 part, bytes32 plan) = _single();
        M.Part memory p = verifier.partRecord(part);
        (address pointer,) = artifacts.artifactChunk(p.carrier.artifactHash, 0);
        bytes memory code = pointer.code;
        vm.etch(pointer, hex"00");
        bytes32 beforeHash = keccak256(abi.encode(verifier.manifestPlan(plan)));
        vm.expectRevert();
        verifier.verifyNextPart(plan, part);
        require(beforeHash == keccak256(abi.encode(verifier.manifestPlan(plan))));
        vm.etch(pointer, code);
        bytes32 record = verifier.verifyNextPart(plan, part);
        verifier.requireCurrentManifest(record, ARTIST);
    }

    function testLatePriorPartCorruptionRollsBackFinalPartThenIdenticalRetry() public {
        checkpoint.seed(65);
        bytes32 first = _prepare(0);
        bytes32 last = _prepare(64);
        bytes32[] memory keys = new bytes32[](2);
        keys[0] = first;
        keys[1] = last;
        bytes32 plan = _begin(_index(keys));
        verifier.verifyNextPart(plan, first);
        M.Part memory p = verifier.partRecord(first);
        (address pointer,) = artifacts.artifactChunk(p.carrier.artifactHash, 0);
        bytes memory code = pointer.code;
        bytes32 beforeHash = keccak256(abi.encode(verifier.manifestPlan(plan)));
        vm.etch(pointer, hex"00");
        vm.expectRevert();
        verifier.verifyNextPart(plan, last);
        require(beforeHash == keccak256(abi.encode(verifier.manifestPlan(plan))));
        vm.etch(pointer, code);
        bytes32 record = verifier.verifyNextPart(plan, last);
        require(verifier.requireCurrentManifest(record, ARTIST).nextRow == 65);
    }

    function testIdempotenceAndPreparationNeverExposeAcceptedHistory() public {
        (bytes32 part, bytes32 plan) = _single();
        M.Part memory p = verifier.partRecord(part);
        M.Plan memory q = verifier.manifestPlan(plan);
        vm.recordLogs();
        require(
            verifier.preparePart(ID, 0, p.carrier.artifactHash, p.carrier.coverageHash, ARTIST)
                == part
        );
        require(
            verifier.beginManifest(ID, q.carrier.artifactHash, q.carrier.coverageHash, ARTIST)
                == plan
        );
        require(vm.getRecordedLogs().length == 0);
        vm.expectRevert(abi.encodeWithSelector(M.ViewManifestUnknown.selector, plan));
        verifier.requireCurrentManifest(plan, ARTIST);
        bytes32 record = verifier.verifyNextPart(plan, part);
        vm.expectRevert(abi.encodeWithSelector(M.ViewManifestOrder.selector, uint256(1)));
        verifier.verifyNextPart(plan, part);
        require(verifier.manifestRecord(record).recordHash == record);
    }

    function testHostChainArtistAndConfigurationDoNotAlias() public {
        (bytes32 part, bytes32 plan) = _single();
        Manifest other = new Manifest(config);
        require(other.configurationHash() != verifier.configurationHash());
        vm.expectRevert(abi.encodeWithSelector(M.ViewManifestUnknown.selector, part));
        other.partRecord(part);
        bytes32 record = verifier.verifyNextPart(plan, part);
        vm.expectRevert(abi.encodeWithSelector(M.InvalidViewManifest.selector));
        verifier.requireCurrentManifest(record, keccak256("foreign artist"));
        uint256 chain = config.chainId;
        vm.chainId(chain + 1);
        vm.expectRevert(abi.encodeWithSelector(M.InvalidViewManifest.selector));
        verifier.requireCurrentManifest(record, ARTIST);
        vm.chainId(chain);
        verifier.requireCurrentManifest(record, ARTIST);
    }

    function testMaximumScopeFinalPartAndIndexBoundsWithoutSamplingClaim() public {
        checkpoint.seed(16384);
        bytes memory raw = _part(16320);
        require(raw.length == 64160);
        M.Header memory h = _header();
        M.Descriptor[] memory descriptors = new M.Descriptor[](256);
        bytes memory index = Encoding.index(config, h, ARTIST, descriptors);
        require(index.length == 74400);
        checkpoint.seed(16385);
        vm.expectRevert(abi.encodeWithSelector(M.InvalidViewManifest.selector));
        verifier.preparePart(ID, 0, bytes32(uint256(1)), bytes32(uint256(1)), ARTIST);
        checkpoint.seed(0);
        vm.expectRevert(abi.encodeWithSelector(M.InvalidViewManifest.selector));
        verifier.beginManifest(ID, bytes32(uint256(1)), bytes32(uint256(1)), ARTIST);
    }

    function testFuzzLiteralPartAndIndexGrammar(uint64 first, bytes32 hash, uint64 byteSize)
        public
        view
    {
        C.Output[] memory rows = new C.Output[](2);
        rows[0] = checkpoint.outputAt(ID, 0);
        rows[1] = checkpoint.outputAt(ID, 1);
        rows[1].entropy.policyHash = hash;
        rows[1].entropy.policy.revision = byteSize;
        M.Header memory h = _header();
        bytes memory expected = abi.encode(
            keccak256("STREAM_VIEW_PRESERVATION_OUTPUT_PART_V1"),
            config.chainId,
            address(core),
            address(checkpoint),
            checkpoint.configurationHash(),
            h,
            first,
            rows
        );
        require(keccak256(expected) == keccak256(Encoding.part(config, h, first, rows)));
        M.Descriptor[] memory parts = new M.Descriptor[](1);
        parts[0].contentHash = hash;
        parts[0].byteLength = byteSize;
        expected = abi.encode(
            keccak256("STREAM_VIEW_PRESERVATION_OUTPUT_MANIFEST_V1"),
            config.chainId,
            address(core),
            address(checkpoint),
            checkpoint.configurationHash(),
            h,
            ARTIST,
            parts
        );
        require(keccak256(expected) == keccak256(Encoding.index(config, h, ARTIST, parts)));
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
