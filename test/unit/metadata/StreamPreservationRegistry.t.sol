// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StaticMetadataRoutingFixture,
    StaticRouteModules
} from "../../helpers/StaticMetadataRoutingFixture.sol";
import { PreservationArtistBoundary } from "./StreamPreservationRenderer.t.sol";
import {
    StreamPreservationRendererV1 as Producer
} from "../../../smart-contracts/domains/metadata/StreamPreservationRendererV1.sol";
import {
    StreamRendererRegistry as Registry
} from "../../../smart-contracts/domains/metadata/StreamRendererRegistry.sol";
import {
    StreamSchemaDocumentStore as Store
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    IStreamSchemaRegistry as Docs
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamRendererRegistry as V
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamPreservationRegistryV1 as P
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPreservationRegistryV1.sol";
import {
    IStreamPreservationRendererV1 as API
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPreservationRendererV1.sol";
import {
    IStreamPreservationAttributionV1 as PA
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPreservationAttributionV1.sol";
import {
    IStreamGasParameterHost as G
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    IStreamRenderer as R
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamStaticMetadataRouter as S
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamPreservationAdmission as AdmissionKey
} from "../../../smart-contracts/domains/metadata/StreamPreservationAdmission.sol";
import { Strings } from "../../../smart-contracts/vendor/openzeppelin/Strings.sol";

interface PreservationGateVm {
    function etch(address, bytes calldata) external;
    function mockCall(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
}

/// @notice Actual Registry/Schema/Store/Router/live+preservation renderer. Artist and analysis are
/// explicit typed test assertions. This proves gate mechanics and genuine execution, not opcode review.
contract StreamPreservationRegistryTest is StaticMetadataRoutingFixture {
    PreservationGateVm private constant gvm =
        PreservationGateVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    Registry private gate;
    Producer private producer;
    PreservationArtistBoundary private projection;
    bytes32 private versionKey;
    uint256 private serial;
    uint16 private producerIndex;
    uint16 private attributionIndex;
    bytes32 private newSchema;

    function setUp() public override {
        super.setUp();
        projection =
            new PreservationArtistBoundary(address(core), address(router), address(attribution));
        producer = new Producer(
            address(renderer),
            address(projection),
            address(executor),
            G.GasParameterConfig("METADATA_DEPENDENCY_READ_GAS", 2000000, 100000, 2),
            G.GasParameterConfig("STATIC_ATTRIBUTION_GAS", 8000000, 8000000, 1)
        );
        V.Target[] memory targets = new V.Target[](2);
        targets[0] = V.Target(
            address(producer), address(producer).codehash, keccak256("PRESERVATION_RENDERER")
        );
        targets[1] = V.Target(
            address(projection), address(projection).codehash, keccak256("PRESERVATION_ATTRIBUTION")
        );
        if (targets[0].target > targets[1].target) {
            V.Target memory swap = targets[0];
            targets[0] = targets[1];
            targets[1] = swap;
        }
        producerIndex = targets[0].target == address(producer) ? 0 : 1;
        attributionIndex = 1 - producerIndex;
        gate = new Registry(
            address(executor),
            address(schemas),
            targets,
            G.GasParameterConfig("METADATA_DEPENDENCY_READ_GAS", 2000000, 100000, 2),
            G.GasParameterConfig("RENDERER_GOLDEN_VECTOR_GAS", 12000000, 100000, 2)
        );
        _doc("RAW_BYTES", Docs.DocumentKind.CANONICALIZATION, bytes(schemas.RAW_BYTES_DEFINITION()));
        V.Registration memory original;
        original.renderer = address(renderer);
        original.manifest = renderer.rendererManifest();
        original.schemaDocument = _doc("ORIGINAL_SCHEMA", Docs.DocumentKind.SCHEMA, bytes("schema"));
        original.contextDocument =
            _doc("ORIGINAL_CONTEXT", Docs.DocumentKind.SCHEMA, bytes("context"));
        original.manifestDocument =
            _doc("ORIGINAL_MANIFEST", Docs.DocumentKind.CATALOG, bytes("manifest"));
        V.Read[] memory oldReads = new V.Read[](0);
        original.analysisDocument = _catalog(
            abi.encode(
                V.Analysis(
                    gate.ANALYSIS_PROFILE(),
                    address(renderer),
                    address(renderer).codehash,
                    _readHash(oldReads),
                    original.manifest.rendererVersion,
                    original.manifest.contextVersion,
                    original.manifest.schemaHash,
                    keccak256("explicit finite synthetic analysis boundary"),
                    keccak256("not full opcode clearance"),
                    true
                )
            )
        );
        V.GoldenVector[] memory oldVectors = new V.GoldenVector[](1);
        oldVectors[0].request.core = address(core);
        oldVectors[0].request.mode = R.MetadataMode.ONCHAIN;
        oldVectors[0].outputHash = keccak256(bytes(renderer.tokenURI(oldVectors[0].request)));
        original.goldenDocument = _catalog(abi.encode(oldVectors));
        (bytes32 scope, bytes32 before_, bytes32 after_) =
            gate.registrationTransition(original, oldReads);
        versionKey = abi.decode(
            executor.execute(
                address(gate),
                abi.encodeCall(gate.registerRenderer, (original, oldReads)),
                scope,
                before_,
                after_
            ),
            (bytes32)
        );
        modules = new StaticRouteModules(address(metadata), address(gate));
        core.setPointer(keccak256("MODULE_REGISTRY"), address(modules));
        S.ConfigInput memory input;
        input.registry = address(gate);
        input.versionKey = versionKey;
        input.config = R.MetadataConfig(
            R.MetadataMode.ONCHAIN, address(renderer), "", "", R.OffchainURIIdMode.TOKEN_ID, false
        );
        bytes32 config = router.setDefaultMetadataConfig(input);
        router.activateStaticMetadata(1, config);
        _mint();
        newSchema = _doc(
            "PRESERVATION_SCHEMA",
            Docs.DocumentKind.SCHEMA,
            bytes("full artwork; only sanctioned state/record/class excluded")
        );
    }

    function _recipe()
        private
        returns (P.PreservationRegistration memory r, V.Read[] memory reads_)
    {
        reads_ = new V.Read[](5);
        reads_[0] = V.Read(producerIndex, API.preservationProfile.selector, 32, true);
        reads_[1] = V.Read(producerIndex, API.preservationBinding.selector, 192, true);
        reads_[2] = V.Read(producerIndex, API.preservationTokenJSON.selector, 16777216, false);
        reads_[3] = V.Read(producerIndex, API.preservationTokenHTML.selector, 16777216, false);
        reads_[4] = V.Read(attributionIndex, PA.preservationAttribution.selector, 32832, false);
        _sort(reads_);
        r.versionKey = versionKey;
        r.binding = P.ProducerBinding(
            address(producer),
            address(producer).codehash,
            keccak256("6529STREAM_PRESERVATION_RENDER_V1"),
            address(core),
            address(router),
            address(renderer),
            address(renderer).codehash,
            address(projection),
            address(projection).codehash
        );
        r.schemaDocument = newSchema;
        r.analysisDocument = _catalog(
            abi.encode(
                P.PreservationAnalysis(
                    keccak256("6529STREAM_PRESERVATION_ANALYSIS_ABI_V1"),
                    r.binding,
                    gate.version(versionKey).registrationHash,
                    keccak256("full artwork; only sanctioned state/record/class excluded"),
                    _readHash(reads_),
                    keccak256("explicit finite synthetic projection analysis boundary"),
                    keccak256("not transitive roster acceptance"),
                    true
                )
            )
        );
        P.PreservationGoldenVector[] memory vectors = new P.PreservationGoldenVector[](2);
        R.RenderRequest memory request = R.RenderRequest(
            address(core),
            91,
            1,
            91,
            keccak256("real boundary seed"),
            R.TokenRenderState.ACTIVE,
            R.MetadataMode.ONCHAIN,
            0,
            0,
            0,
            0,
            router.resolvedMetadataConfig(91).recordHash
        );
        for (uint8 i; i < 2; ++i) {
            vectors[i] = P.PreservationGoldenVector(
                StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0),
                91,
                0,
                i + 2,
                keccak256(bytes(renderer.renderCurrent(request, i + 2)))
            );
        }
        r.goldenDocument = _catalog(abi.encode(vectors));
    }

    function testGovernedSeparateGoldenMatchesActualOldOutputAndRetainsOriginalVersion() public {
        bytes32 oldHash = keccak256(abi.encode(gate.version(versionKey)));
        (P.PreservationRegistration memory r, V.Read[] memory reads_) = _recipe();
        _register(r, reads_);
        (P.ProducerBinding memory binding, P.Admission memory admission) =
            gate.requirePreservation(versionKey, address(producer), r.binding.profile);
        require(
            keccak256(abi.encode(binding)) == keccak256(abi.encode(r.binding)),
            "literal nine producer words"
        );
        require(abi.encode(binding, admission).length == 512, "exact combined tuple");
        bytes32 literal = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRESERVATION_REGISTRATION_V1"),
                block.chainid,
                address(gate),
                address(schemas),
                address(schemas).codehash,
                gate.targetSetHash(),
                gate.version(versionKey).registrationHash,
                r,
                reads_
            )
        );
        require(
            admission.registry == address(gate)
                && admission.registryCodeHash == address(gate).codehash
                && admission.versionKey == versionKey && admission.registrationHash == literal
                && admission.readSetHash == _readHash(reads_)
                && admission.analysisHash == keccak256(schemas.documentBytes(r.analysisDocument))
                && admission.goldenHash == keccak256(schemas.documentBytes(r.goldenDocument)),
            "all seven admission fields"
        );
        require(
            keccak256(abi.encode(gate.version(versionKey))) == oldHash,
            "original evidence unchanged"
        );
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRESERVATION_KEY_V1"),
                versionKey,
                address(producer),
                r.binding.profile
            )
        );
        require(
            gate.preservationKey(versionKey, address(producer), r.binding.profile) == key,
            "literal key"
        );
        require(
            keccak256(abi.encode(gate.preservationRecord(key).registration))
                == keccak256(abi.encode(r)),
            "complete immutable new record"
        );
        P.PreservationRecord memory expected = P.PreservationRecord(
            r,
            literal,
            _readHash(reads_),
            keccak256(schemas.documentBytes(r.analysisDocument)),
            keccak256(schemas.documentBytes(r.goldenDocument)),
            bytes32(uint256(1))
        );
        (bool ok, bytes memory raw) =
            address(gate).staticcall(abi.encodeCall(P.preservationRecord, (key)));
        require(
            ok && raw.length == 576 && keccak256(raw) == keccak256(abi.encode(expected)),
            "literal eighteen-word record including action"
        );
    }

    function testUnknownRecordReturnsExactEighteenZeroWords() public view {
        (bool ok, bytes memory raw) = address(gate)
            .staticcall(
                abi.encodeCall(P.preservationRecord, (keccak256("unknown preservation record")))
            );
        require(
            ok && raw.length == 576 && keccak256(raw) == keccak256(new bytes(576)),
            "empty static record"
        );
    }

    function testOriginalAdmissionDoesNotAuthorizeNewProfileAndForeignCallerCannotRegister()
        public
    {
        (P.PreservationRegistration memory r, V.Read[] memory reads_) = _recipe();
        vm.expectRevert();
        gate.requirePreservation(versionKey, address(producer), r.binding.profile);
        vm.expectRevert(abi.encodeWithSelector(V.RendererGovernanceRequired.selector));
        gate.registerPreservation(r, reads_);
        _register(r, reads_);
        vm.expectRevert();
        this.registerAgain(r, reads_);
    }

    function testWrongProfileAndMissingProducerReadFailBeforeAnyRecord() public {
        (P.PreservationRegistration memory r, V.Read[] memory reads_) = _recipe();
        bytes32 good = r.binding.profile;
        r.binding.profile = keccak256("unregistered projection");
        vm.expectRevert();
        this.registerAgain(r, reads_);
        r.binding.profile = good;
        reads_[0].selector = bytes4(0);
        vm.expectRevert();
        this.registerAgain(r, reads_);
        require(
            gate.preservationRecord(gate.preservationKey(versionKey, address(producer), good))
            .registrationHash == 0,
            "no partial record"
        );
    }

    function testLateActualGoldenFailureRollsBackThenSameRegistrationRetries() public {
        (P.PreservationRegistration memory r, V.Read[] memory reads_) = _recipe();
        projection.setFail(true);
        vm.expectRevert();
        this.registerAgain(r, reads_);
        bytes32 key = gate.preservationKey(versionKey, address(producer), r.binding.profile);
        require(
            gate.preservationRecord(key).registrationHash == 0
                && gate.preservationReads(key).length == 0,
            "late complete rollback"
        );
        projection.setFail(false);
        _register(r, reads_);
        require(gate.preservationRecord(key).registrationHash != 0, "identical registration retry");
    }

    function testRetainedReadRequiresEveryDeclaredActualRuntime() public {
        (P.PreservationRegistration memory r, V.Read[] memory reads_) = _recipe();
        _register(r, reads_);
        bytes memory code = address(projection).code;
        gvm.etch(address(projection), hex"00");
        vm.expectRevert();
        gate.requirePreservation(versionKey, address(producer), r.binding.profile);
        gvm.etch(address(projection), code);
        (, P.Admission memory a) =
            gate.requirePreservation(versionKey, address(producer), r.binding.profile);
        require(a.registrationHash != 0, "retained exact restoration");
    }

    function registerAgain(P.PreservationRegistration calldata r, V.Read[] calldata reads_)
        external
    {
        _register(r, reads_);
    }

    function _register(P.PreservationRegistration memory r, V.Read[] memory reads_) private {
        (bytes32 s, bytes32 p, bytes32 n) = gate.preservationTransition(r, reads_);
        executor.execute(
            address(gate), abi.encodeCall(gate.registerPreservation, (r, reads_)), s, p, n
        );
    }

    function _readHash(V.Read[] memory reads_) private view returns (bytes32) {
        return keccak256(
            abi.encode(keccak256("6529STREAM_RENDERER_READ_SET_V1"), gate.targetSetHash(), reads_)
        );
    }

    function _sort(V.Read[] memory rows) private pure {
        for (uint256 i = 1; i < rows.length; ++i) {
            V.Read memory value = rows[i];
            uint256 j = i;
            while (
                j > 0
                    && (rows[j - 1].targetIndex > value.targetIndex
                        || (rows[j - 1].targetIndex == value.targetIndex
                            && rows[j - 1].selector > value.selector))
            ) {
                rows[j] = rows[j - 1];
                --j;
            }
            rows[j] = value;
        }
    }

    function _catalog(bytes memory payload) private returns (bytes32) {
        return _doc(
            string.concat("PRESERVATION_CATALOG_", Strings.toString(++serial)),
            Docs.DocumentKind.CATALOG,
            payload
        );
    }

    function _doc(string memory name, Docs.DocumentKind kind, bytes memory payload)
        private
        returns (bytes32)
    {
        Store store = Store(schemas.chunkStore());
        (bytes32 hash,) = store.publishChunk(payload);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        Docs.DocumentSpec memory spec =
            Docs.DocumentSpec(name, kind, hash, schemas.RAW_BYTES(), 0, "", uint32(payload.length));
        (bytes32 s, bytes32 before_, bytes32 after_) = schemas.registrationTransition(spec, chunks);
        return abi.decode(
            executor.execute(
                address(schemas),
                abi.encodeCall(schemas.registerDocument, (spec, chunks)),
                s,
                before_,
                after_
            ),
            (bytes32)
        );
    }
}

/// @notice Literal preimage oracle for the fixed four-word key.
contract StreamPreservationKeyTest {
    function testFuzzKeyMatchesOriginalLiteralABI(
        bytes32 version,
        address producer,
        bytes32 profile
    ) public view {
        bytes32 expected = keccak256(
            abi.encode(keccak256("6529STREAM_PRESERVATION_KEY_V1"), version, producer, profile)
        );
        bytes memory canary = abi.encode(version, producer, profile, bytes32(uint256(0x6529)));
        bytes32 before_ = keccak256(canary);
        require(
            PreservationKeyProbe.key(version, producer, profile) == expected,
            "literal four-word key"
        );
        bytes memory after_ = new bytes(128);
        require(
            keccak256(after_) == keccak256(new bytes(128)) && keccak256(canary) == before_,
            "no escaping scratch pointer"
        );
    }
}

library PreservationKeyProbe {
    function key(bytes32 version, address producer, bytes32 profile)
        internal
        pure
        returns (bytes32)
    {
        return AdmissionKey.key(version, producer, profile);
    }
}
