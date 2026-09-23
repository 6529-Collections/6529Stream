// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    CharacterizationTestBase
} from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";
import { RendererExecutorBoundary, RendererTestVm } from "./StreamRendererRegistry.t.sol";
import {
    StreamRendererRegistry
} from "../../../smart-contracts/domains/metadata/StreamRendererRegistry.sol";
import {
    StreamSchemaRegistry
} from "../../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";
import {
    StreamSchemaDocumentStore
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    IStreamSchemaRegistry as S
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamRendererRegistry as V
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamRenderer as R
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamTerminalEntropyRenderer as T
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamTerminalEntropyRenderer.sol";
import {
    IStreamTerminalEntropyRegistry as A
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamTerminalEntropyRegistry.sol";
import {
    IStreamCurrentCitationRegistry as C
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCurrentCitationRegistry.sol";
import {
    IStreamGasParameterHost as G
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamTerminalEntropyEncoding as Encoding
} from "../../../smart-contracts/domains/metadata/StreamTerminalEntropyEncoding.sol";
import {
    StreamTerminalEntropyValidation as Validation
} from "../../../smart-contracts/domains/metadata/StreamTerminalEntropyValidation.sol";
import { Strings } from "../../../smart-contracts/vendor/openzeppelin/Strings.sol";

contract TerminalRegistryDependency {
    function marker() external pure returns (uint256) {
        return 1;
    }
}

/// @dev Deliberately synthetic output/analysis source for actual Registry mechanics. It does not
/// establish artwork independence, actual token identity or whole-program STATIC conformance.
contract TerminalRegistryRenderer is R, T {
    address private immutable c;
    address private immutable e;
    bytes32 private immutable schema;
    bytes32 private immutable manifest;

    constructor(address core, address entropy, bytes32 s, bytes32 m) {
        c = core;
        e = entropy;
        schema = s;
        manifest = m;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(R).interfaceId || id == type(T).interfaceId;
    }

    function rendererVersion() external pure returns (bytes32) {
        return keccak256("TERMINAL_REGISTRY_TEST_V1");
    }

    function renderContextVersion() external pure returns (bytes32) {
        return keccak256("TERMINAL_REGISTRY_CONTEXT");
    }

    function rendererManifest() external view returns (RendererManifest memory) {
        return RendererManifest(
            keccak256("terminal test renderer"),
            keccak256("TERMINAL_REGISTRY_TEST_V1"),
            keccak256("TERMINAL_REGISTRY_CONTEXT"),
            keccak256("STATIC"),
            schema,
            "urn:test:schema",
            "urn:test:manifest",
            manifest,
            1024,
            1024,
            false
        );
    }

    function tokenURI(RenderRequest calldata) external pure returns (string memory) {
        return "data:application/json;base64,e30=";
    }

    function terminalEntropyProfile() external pure returns (bytes32) {
        return keccak256("6529STREAM_TERMINAL_ENTROPY_RENDER_V1");
    }

    function terminalEncodingBinding() external view returns (address, bytes32) {
        return (address(Encoding), address(Encoding).codehash);
    }

    function terminalPolicyBinding() external view returns (address, address, bytes32) {
        return (c, e, e.codehash);
    }

    function terminalValidationBinding() external view returns (address, bytes32) {
        return (address(Validation), address(Validation).codehash);
    }

    function renderTerminal(RenderRequest calldata, uint8 mode)
        external
        pure
        returns (string memory)
    {
        require(mode < 4);
        return mode == 3
            ? "<html>terminal fixture</html>"
            : mode == 1 ? "data:application/json;base64,e30=" : "{}";
    }
}

/// @notice Actual Registry/Schema/Store and threshold-two Safe. Renderer, Core, entropy and the
/// executing governance context are explicit typed boundaries, not current artwork acceptance.
contract StreamTerminalEntropyRegistryTest is CharacterizationTestBase, OfficialSafeFixture {
    RendererExecutorBoundary private executor;
    StreamSchemaRegistry private schemas;
    StreamSchemaDocumentStore private store;
    StreamRendererRegistry private registry;
    TerminalRegistryRenderer private renderer;
    address private core;
    address private entropy;
    bytes32 private schema;
    bytes32 private context;
    bytes32 private manifest;
    bytes32 private key;
    uint256 private serial;
    mapping(address => uint16) private targetIndex;
    bytes32 private constant PROFILE = keccak256("6529STREAM_TERMINAL_ENTROPY_RENDER_V1");
    bytes32 private constant ANALYSIS = keccak256("6529STREAM_TERMINAL_ENTROPY_ANALYSIS_ABI_V1");

    function setUp() public {
        executor = new RendererExecutorBoundary();
        schemas = new StreamSchemaRegistry(address(executor));
        store = StreamSchemaDocumentStore(schemas.chunkStore());
        _document(
            "RAW_BYTES", S.DocumentKind.CANONICALIZATION, bytes(schemas.RAW_BYTES_DEFINITION())
        );
        schema = _document("TERMINAL_REGISTRY_SCHEMA", S.DocumentKind.SCHEMA, bytes("{}"));
        context = _document("TERMINAL_REGISTRY_CONTEXT", S.DocumentKind.SCHEMA, bytes("{}"));
        manifest = _document("TERMINAL_REGISTRY_MANIFEST", S.DocumentKind.CATALOG, bytes("{}"));
        core = address(new TerminalRegistryDependency());
        entropy = address(new TerminalRegistryDependency());
        renderer = new TerminalRegistryRenderer(core, entropy, keccak256("{}"), keccak256("{}"));
        V.Target[] memory targets = new V.Target[](5);
        targets[0] =
            V.Target(address(schemas), address(schemas).codehash, keccak256("METADATA_COMPANION"));
        targets[1] = V.Target(core, core.codehash, keccak256("CORE"));
        targets[2] = V.Target(entropy, entropy.codehash, keccak256("ENTROPY_COORDINATOR"));
        targets[3] =
            V.Target(address(Encoding), address(Encoding).codehash, keccak256("METADATA_COMPANION"));
        targets[4] = V.Target(
            address(Validation), address(Validation).codehash, keccak256("METADATA_COMPANION")
        );
        for (uint256 i = 1; i < targets.length; ++i) {
            V.Target memory value = targets[i];
            uint256 j = i;
            while (j > 0 && targets[j - 1].target > value.target) {
                targets[j] = targets[j - 1];
                --j;
            }
            targets[j] = value;
        }
        for (uint16 i; i < targets.length; ++i) {
            targetIndex[targets[i].target] = i;
        }
        registry = new StreamRendererRegistry(
            address(executor),
            address(schemas),
            targets,
            G.GasParameterConfig("METADATA_DEPENDENCY_READ_GAS", 1500000, 100000, 2),
            G.GasParameterConfig("RENDERER_GOLDEN_VECTOR_GAS", 2000000, 100000, 2)
        );
        _original();
    }

    function testTerminalProfileRequiresSeparateGovernedEvidenceAndLeavesOriginalExact() public {
        V.Version memory old = registry.version(key);
        bytes32 original = keccak256(abi.encode(registry.registration(key)));
        vm.expectRevert();
        registry.requireTerminalEntropy(key);
        (C.CurrentRegistration memory r, V.Read[] memory reads_) = _recipe();
        _register(r, reads_);
        (address actual, bytes32 runtime, bytes32 profile, bytes4 selector) =
            registry.requireTerminalEntropy(key);
        require(
            actual == address(renderer) && runtime == address(renderer).codehash
                && profile == PROFILE && selector == T.renderTerminal.selector,
            "exact separate output admission"
        );
        C.CurrentRecord memory saved = registry.terminalEntropyRecord(key);
        bytes32 declaration = keccak256(
            abi.encode(
                keccak256("6529STREAM_TERMINAL_ENTROPY_REGISTRATION_V1"),
                block.chainid,
                address(registry),
                address(schemas),
                address(schemas).codehash,
                registry.targetSetHash(),
                old.registrationHash,
                r,
                reads_
            )
        );
        require(
            saved.registrationHash == declaration && saved.actionId == bytes32(uint256(99)),
            "literal new declaration and executing action"
        );
        require(
            saved.analysisHash == keccak256(schemas.documentBytes(r.analysisDocument))
                && saved.goldenHash == keccak256(schemas.documentBytes(r.goldenDocument)),
            "exact evidence bytes"
        );
        require(
            keccak256(abi.encode(registry.version(key))) == keccak256(abi.encode(old))
                && keccak256(abi.encode(registry.registration(key))) == original,
            "original record byte equality"
        );
        require(
            registry.currentCitationRecord(key).registrationHash == 0,
            "separate namespace not citation authority"
        );
        vm.expectRevert();
        this.registerRecipe(r, reads_);
    }

    function testTerminalProfileRejectsForeignProfileAnalysisAndNoIndependenceClaim() public {
        (C.CurrentRegistration memory r, V.Read[] memory reads_) = _recipe();
        r.profile = keccak256("6529STREAM_CURRENT_BASE_CITATION_V1");
        vm.expectRevert();
        this.registerRecipe(r, reads_);
        r.profile = PROFILE;
        A.TerminalAnalysis memory a =
            abi.decode(schemas.documentBytes(r.analysisDocument), (A.TerminalAnalysis));
        a.entropyIndependent = false;
        r.analysisDocument = _catalog(abi.encode(a));
        vm.expectRevert();
        this.registerRecipe(r, reads_);
        a.entropyIndependent = true;
        a.bindings.originalRegistrationHash = keccak256("foreign original");
        r.analysisDocument = _catalog(abi.encode(a));
        vm.expectRevert();
        this.registerRecipe(r, reads_);
        require(
            registry.terminalEntropyRecord(key).registrationHash == 0,
            "rejected evidence unregistered"
        );
    }

    function testTerminalReadsetCannotSubstituteDelegatedGetterOrWrongCanonicalReturnSize() public {
        (C.CurrentRegistration memory r, V.Read[] memory reads_) = _recipe();
        for (uint256 i; i < reads_.length; ++i) {
            if (reads_[i].selector == 0x40016975) {
                reads_[i].selector = 0x48ff96eb;
                reads_[i].maxReturnBytes = 384;
            }
        }
        _sort(reads_);
        vm.expectRevert();
        this.registerRecipe(r, reads_);
        (r, reads_) = _recipe();
        for (uint256 i; i < reads_.length; ++i) {
            if (reads_[i].selector == 0x40016975) reads_[i].maxReturnBytes = 480;
        }
        vm.expectRevert();
        this.registerRecipe(r, reads_);
    }

    function testTerminalLateGoldenFailureRollsBackSafeAndExactTransactionRetries() public {
        (C.CurrentRegistration memory r, V.Read[] memory reads_) = _recipe();
        uint256[] memory keys = new uint256[](2);
        keys[0] = 8901;
        keys[1] = 8902;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 8903);
        executor.setRoot(address(safe));
        (bytes32 scope, bytes32 prior, bytes32 next) = registry.terminalEntropyTransition(r, reads_);
        bytes memory call_ = abi.encodeCall(
            executor.execute,
            (
                address(registry),
                abi.encodeCall(registry.registerTerminalEntropy, (r, reads_)),
                uint8(1),
                scope,
                prior,
                next
            )
        );
        bytes32 hash = safe.getTransactionHash(
            address(executor), 0, call_, 0, 0, 0, 0, address(0), address(0), safe.nonce()
        );
        R.RenderRequest memory request;
        request.tokenId = 1;
        RendererTestVm(address(vm))
            .mockCallRevert(
                address(renderer),
                abi.encodeCall(T.renderTerminal, (request, uint8(3))),
                hex"deadbeef"
            );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.safeRegister(safe, keys, call_);
        require(
            safe.nonce() == 0 && registry.terminalEntropyRecord(key).registrationHash == 0,
            "late atomic rollback"
        );
        RendererTestVm(address(vm)).clearMockedCalls();
        require(
            hash
                == safe.getTransactionHash(
                    address(executor), 0, call_, 0, 0, 0, 0, address(0), address(0), safe.nonce()
                ),
            "identical signed transaction"
        );
        this.safeRegister(safe, keys, call_);
        require(
            safe.nonce() == 1 && registry.terminalEntropyRecord(key).registrationHash != 0,
            "once-only actual Safe success"
        );
    }

    function testTerminalCurrentReadRejectsExactDependencyRuntimeDrift() public {
        (C.CurrentRegistration memory r, V.Read[] memory reads_) = _recipe();
        _register(r, reads_);
        registry.requireTerminalEntropy(key);
        vm.etch(entropy, hex"00");
        vm.expectRevert();
        registry.requireTerminalEntropy(key);
        require(
            registry.terminalEntropyRecord(key).registrationHash != 0,
            "historical admission retained"
        );
        registry.requireRetained(key);
    }

    function safeRegister(OfficialSafe account, uint256[] memory keys, bytes memory data) external {
        require(executeSafe(account, keys, address(executor), 0, data, 0), "Safe CALL");
    }

    function registerRecipe(C.CurrentRegistration calldata r, V.Read[] calldata reads_) external {
        _register(r, reads_);
    }

    function _register(C.CurrentRegistration memory r, V.Read[] memory reads_) private {
        (bytes32 scope, bytes32 prior, bytes32 next) = registry.terminalEntropyTransition(r, reads_);
        executor.execute(
            address(registry),
            abi.encodeCall(registry.registerTerminalEntropy, (r, reads_)),
            1,
            scope,
            prior,
            next
        );
    }

    function _original() private {
        V.Registration memory r;
        r.renderer = address(renderer);
        r.manifest = renderer.rendererManifest();
        r.schemaDocument = schema;
        r.contextDocument = context;
        r.manifestDocument = manifest;
        V.Read[] memory reads_ = new V.Read[](0);
        V.Analysis memory a = V.Analysis(
            registry.ANALYSIS_PROFILE(),
            address(renderer),
            address(renderer).codehash,
            _readHash(reads_),
            r.manifest.rendererVersion,
            r.manifest.contextVersion,
            r.manifest.schemaHash,
            keccak256("synthetic original tool"),
            keccak256("synthetic findings"),
            true
        );
        r.analysisDocument = _catalog(abi.encode(a));
        V.GoldenVector[] memory vectors = new V.GoldenVector[](1);
        vectors[0].request.tokenId = 1;
        vectors[0].outputHash = keccak256("data:application/json;base64,e30=");
        r.goldenDocument = _catalog(abi.encode(vectors));
        (bytes32 scope, bytes32 prior, bytes32 next) = registry.registrationTransition(r, reads_);
        key = abi.decode(
            executor.execute(
                address(registry),
                abi.encodeCall(registry.registerRenderer, (r, reads_)),
                1,
                scope,
                prior,
                next
            ),
            (bytes32)
        );
    }

    function _recipe() private returns (C.CurrentRegistration memory r, V.Read[] memory reads_) {
        reads_ = new V.Read[](11);
        reads_[0] = V.Read(1, bytes4(keccak256("tokenCollectionIdentity(uint256)")), 128, true);
        reads_[1] = V.Read(1, bytes4(keccak256("coordinatorAtMint(uint256)")), 32, true);
        reads_[2] = V.Read(1, bytes4(keccak256("tokenLifecycle(uint256)")), 32, true);
        reads_[3] = V.Read(1, bytes4(keccak256("collectionFreezeStatus(uint256)")), 32, true);
        reads_[4] = V.Read(1, bytes4(keccak256("collectionSupplyMode(uint256)")), 32, true);
        reads_[5] = V.Read(1, bytes4(keccak256("collectionStatus(uint256)")), 32, true);
        reads_[6] = V.Read(2, 0x40016975, 512, true);
        reads_[7] = V.Read(2, 0x01ffc9a7, 32, true);
        reads_[8] = V.Read(2, bytes4(keccak256("core()")), 32, true);
        reads_[9] = V.Read(3, Encoding.render.selector, 1024, false);
        reads_[10] = V.Read(4, Validation.validate.selector, 480, true);
        for (uint256 i; i < reads_.length; ++i) {
            uint16 old = reads_[i].targetIndex;
            reads_[i].targetIndex = targetIndex[
                old == 1
                    ? core
                    : old == 2 ? entropy : old == 3 ? address(Encoding) : address(Validation)
            ];
        }
        _sort(reads_);
        r = C.CurrentRegistration(
            key,
            PROFILE,
            T.renderTerminal.selector,
            address(Encoding),
            address(Encoding).codehash,
            0,
            0
        );
        A.TerminalAnalysis memory a = A.TerminalAnalysis(
            C.CurrentAnalysis(
                ANALYSIS,
                PROFILE,
                T.renderTerminal.selector,
                address(renderer),
                address(renderer).codehash,
                address(Encoding),
                address(Encoding).codehash,
                _readHash(reads_),
                registry.version(key).registrationHash,
                keccak256("synthetic terminal analysis tool"),
                keccak256("synthetic independence assertion"),
                true
            ),
            true
        );
        r.analysisDocument = _catalog(abi.encode(a));
        C.CurrentGoldenVector[] memory vectors = new C.CurrentGoldenVector[](4);
        for (uint8 i; i < 4; ++i) {
            vectors[i].request.tokenId = 1;
            vectors[i].mode = i;
            vectors[i].outputHash = keccak256(
                bytes(
                    i == 3
                        ? "<html>terminal fixture</html>"
                        : i == 1 ? "data:application/json;base64,e30=" : "{}"
                )
            );
        }
        r.goldenDocument = _catalog(abi.encode(vectors));
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

    function _readHash(V.Read[] memory rows) private view returns (bytes32) {
        return keccak256(
            abi.encode(keccak256("6529STREAM_RENDERER_READ_SET_V1"), registry.targetSetHash(), rows)
        );
    }

    function _catalog(bytes memory payload) private returns (bytes32) {
        return _document(
            string.concat("TERMINAL_TEST_CATALOG_", Strings.toString(++serial)),
            S.DocumentKind.CATALOG,
            payload
        );
    }

    function _document(string memory name, S.DocumentKind kind, bytes memory payload)
        private
        returns (bytes32)
    {
        (bytes32 h,) = store.publishChunk(payload);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = h;
        S.DocumentSpec memory spec =
            S.DocumentSpec(name, kind, h, schemas.RAW_BYTES(), 0, "", uint32(payload.length));
        (bytes32 scope, bytes32 prior, bytes32 next) = schemas.registrationTransition(spec, chunks);
        return abi.decode(
            executor.execute(
                address(schemas),
                abi.encodeCall(schemas.registerDocument, (spec, chunks)),
                1,
                scope,
                prior,
                next
            ),
            (bytes32)
        );
    }
}
