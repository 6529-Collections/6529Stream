// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { Strings } from "../../../smart-contracts/vendor/openzeppelin/Strings.sol";
import {
    StreamRendererRegistry
} from "../../../smart-contracts/domains/metadata/StreamRendererRegistry.sol";
import {
    IStreamRenderer as R
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamRendererRegistry as V
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamGasParameterHost as G
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
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
    CharacterizationTestBase
} from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";

interface RendererTestVm {
    function mockCallRevert(address target, bytes calldata input, bytes calldata reason) external;
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function clearMockedCalls() external;
}

/// @dev Exact six-word current-action boundary, not a substitute for actual Executor scheduling tests.
contract RendererExecutorBoundary {
    address public root;
    bool private running;
    uint8 private kind;
    bytes32 private scope;
    bytes32 private previous;
    bytes32 private next;

    constructor() {
        root = msg.sender;
    }

    function setRoot(address r) external {
        require(msg.sender == root);
        root = r;
    }

    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }

    function currentAction()
        external
        view
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return running
            ? (true, bytes32(uint256(99)), kind, scope, previous, next)
            : (false, bytes32(0), 0, bytes32(0), bytes32(0), bytes32(0));
    }

    function execute(address target, bytes calldata data, uint8 k, bytes32 s, bytes32 p, bytes32 n)
        external
        returns (bytes memory output)
    {
        require(msg.sender == root && !running, "actual boundary caller");
        running = true;
        kind = k;
        scope = s;
        previous = p;
        next = n;
        (bool ok, bytes memory result) = target.call(data);
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        running = false;
        kind = 0;
        scope = 0;
        previous = 0;
        next = 0;
        return result;
    }
}

/// @dev Synthetic pure renderer for gate mechanics; no artwork/current-Core/analysis acceptance claim.
contract RendererVersionBoundary is R {
    RendererManifest private _manifest;

    constructor(bytes32 schemaHash, bytes32 manifestHash) {
        _manifest = RendererManifest(
            keccak256("test-renderer-family"),
            keccak256("test-renderer-v1"),
            keccak256("TEST_RENDER_CONTEXT_V1"),
            keccak256("STATIC"),
            schemaHash,
            "ipfs://schema",
            "ipfs://manifest",
            manifestHash,
            1024,
            0,
            false
        );
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(R).interfaceId || id == 0x01ffc9a7;
    }

    function rendererVersion() external pure returns (bytes32) {
        return keccak256("test-renderer-v1");
    }

    function renderContextVersion() external pure returns (bytes32) {
        return keccak256("TEST_RENDER_CONTEXT_V1");
    }

    function rendererManifest() external view returns (RendererManifest memory) {
        return _manifest;
    }

    function tokenURI(RenderRequest calldata) external pure returns (string memory) {
        return "data:application/json;base64,e30=";
    }
}

/// @notice Real SchemaRegistry/SSTORE2 documents and upstream threshold Safe; synthetic renderer/Executor.
contract StreamRendererRegistryTest is CharacterizationTestBase, OfficialSafeFixture {
    RendererExecutorBoundary private executor;
    StreamSchemaRegistry private schemas;
    StreamSchemaDocumentStore private store;
    StreamRendererRegistry private registry;
    RendererVersionBoundary private renderer;
    bytes32 private schema;
    bytes32 private context;
    bytes32 private manifest;
    uint256 private serial;

    function setUp() public {
        executor = new RendererExecutorBoundary();
        schemas = new StreamSchemaRegistry(address(executor));
        store = StreamSchemaDocumentStore(schemas.chunkStore());
        _document(
            "RAW_BYTES", S.DocumentKind.CANONICALIZATION, bytes(schemas.RAW_BYTES_DEFINITION())
        );
        schema = _document(
            "TEST_RENDER_SCHEMA_V1", S.DocumentKind.SCHEMA, bytes("{\"type\":\"object\"}")
        );
        context =
            _document("TEST_RENDER_CONTEXT_V1", S.DocumentKind.SCHEMA, bytes("{\"context\":1}"));
        manifest = _document(
            "TEST_RENDER_MANIFEST_V1", S.DocumentKind.CATALOG, bytes("{\"fixture\":true}")
        );
        renderer = new RendererVersionBoundary(
            keccak256(bytes("{\"type\":\"object\"}")), keccak256(bytes("{\"fixture\":true}"))
        );
        V.Target[] memory targets = new V.Target[](1);
        targets[0] =
            V.Target(address(schemas), address(schemas).codehash, keccak256("METADATA_COMPANION"));
        registry = new StreamRendererRegistry(
            address(executor),
            address(schemas),
            targets,
            G.GasParameterConfig("METADATA_DEPENDENCY_READ_GAS", 1500000, 100000, 2),
            G.GasParameterConfig("RENDERER_GOLDEN_VECTOR_GAS", 2000000, 100000, 2)
        );
    }

    function testFullVersionEvidenceAndIndependentCommitments() public {
        (V.Registration memory r, V.Read[] memory reads_) = _recipe();
        bytes32 key = _register(r, reads_);
        bytes32 expectedKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_RENDERER_VERSION_V1"),
                r.manifest.rendererId,
                r.manifest.rendererVersion
            )
        );
        bytes32 declaration = keccak256(
            abi.encode(
                keccak256("6529STREAM_RENDERER_REGISTRATION_V1"),
                block.chainid,
                address(registry),
                address(schemas),
                address(schemas).codehash,
                registry.targetSetHash(),
                r,
                reads_
            )
        );
        V.Version memory v = registry.version(key);
        require(
            key == expectedKey && v.exists && !v.deprecated && v.registrationHash == declaration,
            "original typed declaration"
        );
        require(
            v.runtimeHash == address(renderer).codehash && v.actionId == bytes32(uint256(99)),
            "runtime and actual current action"
        );
        require(
            v.analysisHash == keccak256(schemas.documentBytes(r.analysisDocument))
                && v.goldenHash == keccak256(schemas.documentBytes(r.goldenDocument)),
            "exact retained registered evidence"
        );
        require(
            keccak256(abi.encode(registry.registration(key))) == keccak256(abi.encode(r)),
            "full registration retained"
        );
        require(
            registry.versionCount() == 1 && registry.versionAt(0) == key
                && registry.reads(key).length == 0,
            "complete enumeration"
        );
        (address target, bytes32 hash) = registry.requireAssignable(key);
        require(
            target == address(renderer) && hash == address(renderer).codehash, "new selection pin"
        );
    }

    function testWrongCallerClassScopeAndReplayAreTerminal() public {
        (V.Registration memory r, V.Read[] memory reads_) = _recipe();
        vm.expectRevert(abi.encodeWithSelector(V.RendererGovernanceRequired.selector));
        registry.registerRenderer(r, reads_);
        (bytes32 s, bytes32 p, bytes32 n) = registry.registrationTransition(r, reads_);
        vm.expectRevert(abi.encodeWithSelector(V.RendererGovernanceRequired.selector));
        executor.execute(
            address(registry), abi.encodeCall(registry.registerRenderer, (r, reads_)), 0, s, p, n
        );
        vm.expectRevert(abi.encodeWithSelector(V.RendererGovernanceRequired.selector));
        executor.execute(
            address(registry),
            abi.encodeCall(registry.registerRenderer, (r, reads_)),
            1,
            bytes32(uint256(s) ^ 1),
            p,
            n
        );
        require(registry.versionCount() == 0, "failed writes absent");
        bytes32 key = _register(r, reads_);
        vm.expectRevert(abi.encodeWithSelector(V.RendererAlreadyRegistered.selector, key));
        executor.execute(
            address(registry), abi.encodeCall(registry.registerRenderer, (r, reads_)), 1, s, p, n
        );
    }

    function testDeprecatedVersionRetainsOriginalServingDespiteCatalogRetirement() public {
        (V.Registration memory r, V.Read[] memory reads_) = _recipe();
        bytes32 key = _register(r, reads_);
        (bytes32 s, bytes32 p, bytes32 n) = registry.deprecationTransition(key);
        vm.expectRevert(abi.encodeWithSelector(V.RendererGovernanceRequired.selector));
        executor.execute(
            address(registry), abi.encodeCall(registry.deprecateRenderer, (key)), 1, s, p, n
        );
        executor.execute(
            address(registry), abi.encodeCall(registry.deprecateRenderer, (key)), 0, s, p, n
        );
        (s, p, n) = schemas.statusTransition(r.schemaDocument, S.DocumentStatus.ARCHIVED);
        executor.execute(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus, (r.schemaDocument, S.DocumentStatus.ARCHIVED)
            ),
            1,
            s,
            p,
            n
        );
        vm.expectRevert(abi.encodeWithSelector(V.RendererUnavailable.selector, key));
        registry.requireAssignable(key);
        (address target, bytes32 hash) = registry.requireRetained(key);
        require(
            target == address(renderer) && hash == address(renderer).codehash,
            "historical pin is retained"
        );
        require(
            registry.registration(key).schemaDocument == schema,
            "original record survives retirement"
        );
    }

    function testUnknownOrWrongAnalysisAndGoldenOutputNeverRegisters() public {
        (V.Registration memory r, V.Read[] memory reads_) = _recipe();
        bytes32 original = r.analysisDocument;
        r.analysisDocument = bytes32(uint256(777));
        vm.expectRevert();
        this.registerRecipe(r, reads_);
        r.analysisDocument = original;
        V.GoldenVector[] memory vectors = _vectors();
        vectors[0].outputHash = keccak256("wrong output");
        r.goldenDocument = _catalog(abi.encode(vectors));
        vm.expectRevert(
            abi.encodeWithSelector(V.InvalidRendererEvidence.selector, r.goldenDocument)
        );
        this.registerRecipe(r, reads_);
        require(registry.versionCount() == 0, "failed proof leaves no version");
    }

    function testReadShapesArePinnedSortedAndAnalysisCannotBeReused() public {
        (V.Registration memory r,) = _recipe();
        V.Read[] memory reads_ = new V.Read[](1);
        reads_[0] = V.Read(0, S.document.selector, 33, true);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidRendererRegistration.selector));
        this.registerRecipe(r, reads_);
        reads_[0].maxReturnBytes = 32;
        vm.expectRevert(
            abi.encodeWithSelector(V.InvalidRendererEvidence.selector, r.analysisDocument)
        );
        this.registerRecipe(r, reads_);
        require(registry.versionCount() == 0, "read set change cannot reuse prior analysis");
    }

    function testDynamicClassAndManifestDriftRejected() public {
        (V.Registration memory r, V.Read[] memory reads_) = _recipe();
        r.manifest.rendererClass = keccak256("DYNAMIC");
        vm.expectRevert(abi.encodeWithSelector(V.InvalidRendererRegistration.selector));
        this.registerRecipe(r, reads_);
        r.manifest.rendererClass = keccak256("STATIC");
        r.manifest.maxJSONBytes++;
        vm.expectRevert(abi.encodeWithSelector(V.InvalidRendererRegistration.selector));
        this.registerRecipe(r, reads_);
    }

    function testOversizedAndNoncanonicalRendererReturnRejected() public {
        (V.Registration memory r, V.Read[] memory reads_) = _recipe();
        V.GoldenVector[] memory vectors = _vectors();
        bytes memory call_ = abi.encodeCall(R.tokenURI, (vectors[0].request));
        RendererTestVm(address(vm)).mockCall(address(renderer), call_, new bytes(2048));
        vm.expectRevert();
        this.registerRecipe(r, reads_);
        RendererTestVm(address(vm))
            .mockCall(
                address(renderer),
                call_,
                bytes.concat(abi.encode("data:application/json;base64,e30="), bytes32(0))
            );
        vm.expectRevert();
        this.registerRecipe(r, reads_);
        RendererTestVm(address(vm)).clearMockedCalls();
        require(registry.versionCount() == 0, "malformed returndata cannot publish");
        _register(r, reads_);
    }

    function testActualSafeLateGoldenFailureAndIdenticalRetry() public {
        (V.Registration memory r, V.Read[] memory reads_) = _recipe();
        uint256[] memory keys = new uint256[](2);
        keys[0] = 4101;
        keys[1] = 4102;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 400);
        executor.setRoot(address(account));
        (bytes32 s, bytes32 p, bytes32 n) = registry.registrationTransition(r, reads_);
        bytes memory data = abi.encodeCall(
            executor.execute,
            (
                address(registry),
                abi.encodeCall(registry.registerRenderer, (r, reads_)),
                uint8(1),
                s,
                p,
                n
            )
        );
        bytes32 hash = account.getTransactionHash(
            address(executor), 0, data, 0, 0, 0, 0, address(0), address(0), account.nonce()
        );
        V.GoldenVector[] memory vectors = _vectors();
        RendererTestVm(address(vm))
            .mockCallRevert(
                address(renderer),
                abi.encodeCall(R.tokenURI, (vectors[0].request)),
                abi.encodeWithSignature("GoldenUnavailable()")
            );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.safeRegister(account, keys, data);
        require(account.nonce() == 0 && registry.versionCount() == 0, "Safe and registry rollback");
        RendererTestVm(address(vm)).clearMockedCalls();
        require(
            hash
                == account.getTransactionHash(
                    address(executor), 0, data, 0, 0, 0, 0, address(0), address(0), account.nonce()
                ),
            "same signed CALL"
        );
        this.safeRegister(account, keys, data);
        require(
            account.nonce() == 1 && registry.versionCount() == 1,
            "original threshold authorization succeeds once"
        );
    }

    function safeRegister(OfficialSafe account, uint256[] memory keys, bytes memory data) external {
        require(executeSafe(account, keys, address(executor), 0, data, 0), "Safe CALL");
    }

    function registerRecipe(V.Registration calldata r, V.Read[] calldata reads_)
        external
        returns (bytes32)
    {
        return _register(r, reads_);
    }

    function _register(V.Registration memory r, V.Read[] memory reads_) private returns (bytes32) {
        (bytes32 s, bytes32 p, bytes32 n) = registry.registrationTransition(r, reads_);
        return abi.decode(
            executor.execute(
                address(registry),
                abi.encodeCall(registry.registerRenderer, (r, reads_)),
                1,
                s,
                p,
                n
            ),
            (bytes32)
        );
    }

    function _recipe() private returns (V.Registration memory r, V.Read[] memory reads_) {
        reads_ = new V.Read[](0);
        r.renderer = address(renderer);
        r.manifest = renderer.rendererManifest();
        r.schemaDocument = schema;
        r.contextDocument = context;
        r.manifestDocument = manifest;
        bytes32 setHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_RENDERER_READ_SET_V1"), registry.targetSetHash(), reads_
            )
        );
        V.Analysis memory a = V.Analysis(
            registry.ANALYSIS_PROFILE(),
            address(renderer),
            address(renderer).codehash,
            setHash,
            r.manifest.rendererVersion,
            r.manifest.contextVersion,
            r.manifest.schemaHash,
            keccak256("synthetic test report tool"),
            keccak256("synthetic empty findings"),
            true
        );
        r.analysisDocument = _catalog(abi.encode(a));
        r.goldenDocument = _catalog(abi.encode(_vectors()));
    }

    function _vectors() private pure returns (V.GoldenVector[] memory v) {
        v = new V.GoldenVector[](1);
        v[0].request.tokenId = 1;
        v[0].outputHash = keccak256("data:application/json;base64,e30=");
    }

    function _catalog(bytes memory payload) private returns (bytes32) {
        ++serial;
        return _document(
            string.concat("TEST_CATALOG_", Strings.toString(serial)),
            S.DocumentKind.CATALOG,
            payload
        );
    }

    function _document(string memory name, S.DocumentKind kind, bytes memory payload)
        private
        returns (bytes32)
    {
        (bytes32 hash,) = store.publishChunk(payload);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        S.DocumentSpec memory spec =
            S.DocumentSpec(name, kind, hash, schemas.RAW_BYTES(), 0, "", uint32(payload.length));
        (bytes32 s, bytes32 p, bytes32 n) = schemas.registrationTransition(spec, chunks);
        return abi.decode(
            executor.execute(
                address(schemas),
                abi.encodeCall(schemas.registerDocument, (spec, chunks)),
                1,
                s,
                p,
                n
            ),
            (bytes32)
        );
    }
}
