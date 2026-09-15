// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import { IStreamRenderer as R } from "../../interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamRendererRegistry as V
} from "../../interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamSchemaRegistry as S
} from "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamSchemaDocumentFacts as F
} from "../../interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import {
    IStreamGovernedParameterAuthority as G
} from "../../interfaces/stream/parameters/IStreamGovernedParameterAuthority.sol";
import { StreamGasParameterHost } from "../parameters/StreamGasParameterHost.sol";
import { StreamRendererCalls as Calls } from "./StreamRendererCalls.sol";

/// @notice Governance-admitted STATIC versions with immutable runtime, source set and evidence.
/// @dev No removal, incident-disable, target substitution or reactivation entry exists. A version
/// remains available to historical pins after deprecation. The deployment's named allowlist is
/// immutable. Gate reports are exact registered analysis assertions, not onchain proof of a
/// program's reachable opcodes; genuine static analysis remains a release admission obligation.
contract StreamRendererRegistry is V, StreamGasParameterHost {
    bytes32 public constant ANALYSIS_PROFILE =
        keccak256("6529STREAM_STATIC_RENDERER_ANALYSIS_ABI_V1");
    bytes32 public constant READ_GAS = keccak256("6529STREAM_GGP_METADATA_DEPENDENCY_READ_GAS");
    bytes32 public constant GOLDEN_GAS = keccak256("6529STREAM_GGP_RENDERER_GOLDEN_VECTOR_GAS");
    bytes32 private constant SCOPE = keccak256("6529STREAM_RENDERER_REGISTRY_SCOPE_V1");
    bytes32 private constant STATE = keccak256("6529STREAM_RENDERER_REGISTRY_STATE_V1");
    bytes32 private constant REGISTRATION = keccak256("6529STREAM_RENDERER_REGISTRATION_V1");
    bytes32 private constant READ_SET = keccak256("6529STREAM_RENDERER_READ_SET_V1");
    uint256 public constant MAX_TARGETS = 64;
    uint256 public constant MAX_READS = 128;
    uint256 public constant MAX_VECTORS = 16;
    uint256 public constant MAX_OUTPUT_BYTES = 1048576;
    bytes32 public immutable governanceAuthorityCodeHash;
    address public immutable schemaRegistry;
    bytes32 public immutable schemaRegistryCodeHash;
    bytes32 public immutable targetSetHash;
    uint256 public immutable deploymentChainId;
    Target[] private _targets;
    mapping(bytes32 => Version) private _versions;
    mapping(bytes32 => Registration) private _registrations;
    mapping(bytes32 => Read[]) private _reads;
    bytes32[] private _keys;

    constructor(
        address executor,
        address schemas,
        Target[] memory targets,
        GasParameterConfig memory readGas,
        GasParameterConfig memory goldenGas
    ) StreamGasParameterHost(executor) {
        if (
            executor.code.length == 0 || schemas.code.length == 0
                || !S(schemas).supportsInterface(type(F).interfaceId)
                || S(schemas).governanceAuthority() != executor || targets.length == 0
                || targets.length > MAX_TARGETS || readGas.failureClass != 2
                || goldenGas.failureClass != 2 || _registerGasParameter(readGas) != READ_GAS
                || _registerGasParameter(goldenGas) != GOLDEN_GAS
        ) {
            revert InvalidRendererRegistration();
        }
        address previous;
        for (uint256 i; i < targets.length; ++i) {
            Target memory t = targets[i];
            if (
                t.target <= previous || t.target.code.length == 0 || t.target.codehash != t.codeHash
                    || !_role(t.role)
            ) revert InvalidRendererRegistration();
            previous = t.target;
            _targets.push(t);
        }
        governanceAuthorityCodeHash = executor.codehash;
        schemaRegistry = schemas;
        schemaRegistryCodeHash = schemas.codehash;
        targetSetHash = keccak256(abi.encode(targets));
        deploymentChainId = block.chainid;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(V).interfaceId || id == 0x01ffc9a7;
    }

    function registerRenderer(Registration calldata r, Read[] calldata declared)
        external
        override
        returns (bytes32 key)
    {
        key = _key(r.manifest);
        if (_versions[key].exists) revert RendererAlreadyRegistered(key);
        bytes32 declaration = _declaration(r, declared);
        bytes32 action = _governed(_scope(key), _state(0, false), _state(declaration, false), 1);
        _manifest(r);
        bytes32 setHash = _readSet(declared);
        bytes32 analysis = _analysis(r, setHash);
        bytes32 golden = _golden(r);
        // External renderer calls above are STATICCALLs. No target can mutate the registry
        // or its schema/evidence state between validation and this single immutable insertion.
        _versions[key] = Version(
            true,
            false,
            r.renderer,
            r.renderer.codehash,
            declaration,
            setHash,
            analysis,
            golden,
            action
        );
        _registrations[key] = r;
        for (uint256 i; i < declared.length; ++i) {
            _reads[key].push(declared[i]);
        }
        _keys.push(key);
        emit RendererRegistered(1, key, r.renderer, action, declaration, r, declared);
    }

    function deprecateRenderer(bytes32 key) external override {
        Version storage v = _versions[key];
        if (!v.exists) revert UnknownRenderer(key);
        if (v.deprecated) revert RendererUnavailable(key);
        bytes32 action = _governed(
            _scope(key), _state(v.registrationHash, false), _state(v.registrationHash, true), 0
        );
        v.deprecated = true;
        emit RendererDeprecated(1, key, action);
    }

    function version(bytes32 key) external view override returns (Version memory) {
        return _versions[key];
    }

    function registration(bytes32 key) external view override returns (Registration memory) {
        if (!_versions[key].exists) revert UnknownRenderer(key);
        return _registrations[key];
    }

    function reads(bytes32 key) external view override returns (Read[] memory) {
        if (!_versions[key].exists) revert UnknownRenderer(key);
        return _reads[key];
    }

    function targetCount() external view override returns (uint256) {
        return _targets.length;
    }

    function targetAt(uint256 index) external view override returns (Target memory) {
        return _targets[index];
    }

    function versionCount() external view override returns (uint256) {
        return _keys.length;
    }

    function versionAt(uint256 index) external view override returns (bytes32) {
        return _keys[index];
    }

    function requireAssignable(bytes32 key)
        external
        view
        override
        returns (address renderer, bytes32 runtimeHash)
    {
        Version storage v = _versions[key];
        if (v.deprecated) revert RendererUnavailable(key);
        return _retained(key);
    }

    function requireRetained(bytes32 key)
        external
        view
        override
        returns (address renderer, bytes32 runtimeHash)
    {
        return _retained(key);
    }

    function _retained(bytes32 key) private view returns (address renderer, bytes32 runtimeHash) {
        Version storage v = _versions[key];
        if (!v.exists) revert UnknownRenderer(key);
        if (v.renderer.code.length == 0 || v.renderer.codehash != v.runtimeHash) {
            revert RendererUnavailable(key);
        }
        // Retirement of a schema/catalog is not a historical-rendering veto. The registration
        // retains its exact hashes. Runtime drift is terminal, never a different version fallback.
        return (v.renderer, v.runtimeHash);
    }

    function registrationTransition(Registration calldata r, Read[] calldata declared)
        external
        view
        override
        returns (bytes32 scope, bytes32 previous, bytes32 next)
    {
        bytes32 key = _key(r.manifest);
        Version storage v = _versions[key];
        return (
            _scope(key),
            _state(v.registrationHash, v.deprecated),
            _state(_declaration(r, declared), false)
        );
    }

    function deprecationTransition(bytes32 key)
        external
        view
        override
        returns (bytes32 scope, bytes32 previous, bytes32 next)
    {
        Version storage v = _versions[key];
        if (!v.exists) revert UnknownRenderer(key);
        return
            (
                _scope(key),
                _state(v.registrationHash, v.deprecated),
                _state(v.registrationHash, true)
            );
    }

    function _manifest(Registration calldata r) private view {
        R.RendererManifest calldata m = r.manifest;
        if (
            r.renderer.code.length == 0 || m.rendererId == 0 || m.rendererVersion == 0
                || m.contextVersion == 0 || m.rendererClass != keccak256("STATIC")
                || m.schemaHash == 0 || m.manifestHash == 0 || m.deprecated
                || bytes(m.schemaURI).length > 2048 || bytes(m.manifestURI).length > 2048
                || m.maxJSONBytes == 0 || m.maxJSONBytes > MAX_OUTPUT_BYTES
                || m.maxHTMLBytes > MAX_OUTPUT_BYTES || r.contextDocument != m.contextVersion
        ) revert InvalidRendererRegistration();
        uint256 cap = _gasParameterValue(READ_GAS);
        if (
            !abi.decode(
                    Calls.read(
                        r.renderer,
                        abi.encodeCall(IERC165.supportsInterface, (type(R).interfaceId)),
                        32,
                        true,
                        cap
                    ),
                    (bool)
                )
                || abi.decode(
                        Calls.read(
                            r.renderer, abi.encodeCall(R.rendererVersion, ()), 32, true, cap
                        ),
                        (bytes32)
                    ) != m.rendererVersion
                || abi.decode(
                        Calls.read(
                            r.renderer, abi.encodeCall(R.renderContextVersion, ()), 32, true, cap
                        ),
                        (bytes32)
                    ) != m.contextVersion
        ) {
            revert InvalidRendererRegistration();
        }
        bytes memory encoded =
            Calls.read(r.renderer, abi.encodeCall(R.rendererManifest, ()), 4576, false, cap);
        R.RendererManifest memory actual = abi.decode(encoded, (R.RendererManifest));
        if (
            keccak256(encoded) != keccak256(abi.encode(actual))
                || keccak256(abi.encode(actual)) != keccak256(abi.encode(m))
        ) {
            revert InvalidRendererRegistration();
        }
        if (
            _fact(r.schemaDocument, S.DocumentKind.SCHEMA).contentHash != m.schemaHash
                || _fact(r.manifestDocument, S.DocumentKind.CATALOG).contentHash != m.manifestHash
        ) {
            revert InvalidRendererEvidence(r.manifestDocument);
        }
        _fact(r.contextDocument, S.DocumentKind.SCHEMA);
    }

    function _readSet(Read[] calldata declared) private view returns (bytes32) {
        if (declared.length > MAX_READS) revert InvalidRendererRegistration();
        uint256 previous;
        for (uint256 i; i < declared.length; ++i) {
            Read calldata r = declared[i];
            uint256 order = (uint256(r.targetIndex) << 32) | uint32(r.selector);
            if (
                r.targetIndex >= _targets.length || r.selector == 0 || (i != 0 && order <= previous)
                    || r.maxReturnBytes == 0 || r.maxReturnBytes > MAX_OUTPUT_BYTES
                    || (r.exact && r.maxReturnBytes % 32 != 0)
            ) revert InvalidRendererRegistration();
            Target storage t = _targets[r.targetIndex];
            if (t.target.code.length == 0 || t.target.codehash != t.codeHash) {
                revert InvalidRendererRegistration();
            }
            previous = order;
        }
        return keccak256(abi.encode(READ_SET, targetSetHash, declared));
    }

    function _analysis(Registration calldata r, bytes32 setHash) private view returns (bytes32) {
        bytes memory payload = _document(r.analysisDocument);
        Analysis memory a = abi.decode(payload, (Analysis));
        if (
            keccak256(payload) != keccak256(abi.encode(a)) || a.profile != ANALYSIS_PROFILE
                || a.renderer != r.renderer || a.runtimeHash != r.renderer.codehash
                || a.readSetHash != setHash || a.rendererVersion != r.manifest.rendererVersion
                || a.contextVersion != r.manifest.contextVersion
                || a.schemaHash != r.manifest.schemaHash || a.toolHash == 0 || a.findingsHash == 0
                || !a.passed
        ) {
            revert InvalidRendererEvidence(r.analysisDocument);
        }
        return keccak256(payload);
    }

    function _golden(Registration calldata r) private view returns (bytes32) {
        bytes memory payload = _document(r.goldenDocument);
        GoldenVector[] memory vectors = abi.decode(payload, (GoldenVector[]));
        if (
            keccak256(payload) != keccak256(abi.encode(vectors)) || vectors.length == 0
                || vectors.length > MAX_VECTORS
        ) {
            revert InvalidRendererEvidence(r.goldenDocument);
        }
        uint256 maximum = 29 + 4 * ((uint256(r.manifest.maxJSONBytes) + 2) / 3);
        for (uint256 i; i < vectors.length; ++i) {
            if (vectors[i].outputHash == 0) revert InvalidRendererEvidence(r.goldenDocument);
            bytes memory output = Calls.read(
                r.renderer,
                abi.encodeCall(R.tokenURI, (vectors[i].request)),
                64 + ((maximum + 31) / 32) * 32,
                false,
                _gasParameterValue(GOLDEN_GAS)
            );
            string memory uri = Calls.stringResult(output, maximum);
            if (keccak256(bytes(uri)) != vectors[i].outputHash) {
                revert InvalidRendererEvidence(r.goldenDocument);
            }
        }
        return keccak256(payload);
    }

    function _document(bytes32 id) private view returns (bytes memory payload) {
        F.DocumentFacts memory f = _fact(id, S.DocumentKind.CATALOG);
        if (f.totalBytes == 0 || f.totalBytes > 8192) revert InvalidRendererEvidence(id);
        bytes memory encoded = Calls.read(
            schemaRegistry,
            abi.encodeCall(S.documentBytes, (id)),
            64 + ((uint256(f.totalBytes) + 31) / 32) * 32,
            false,
            _gasParameterValue(READ_GAS)
        );
        payload = abi.decode(encoded, (bytes));
        if (
            payload.length != f.totalBytes || keccak256(payload) != f.contentHash
                || keccak256(encoded) != keccak256(abi.encode(payload))
        ) revert InvalidRendererEvidence(id);
    }

    function _fact(bytes32 id, S.DocumentKind kind)
        private
        view
        returns (F.DocumentFacts memory f)
    {
        if (schemaRegistry.codehash != schemaRegistryCodeHash || id == 0) revert InvalidRendererEvidence(id);
        f = abi.decode(
            Calls.read(
                schemaRegistry,
                abi.encodeCall(F.documentFacts, (id)),
                288,
                true,
                _gasParameterValue(READ_GAS)
            ),
            (F.DocumentFacts)
        );
        if (
            !f.exists || f.kind != kind || f.status != S.DocumentStatus.ACTIVE || f.contentHash == 0
        ) {
            revert InvalidRendererEvidence(id);
        }
    }

    function _role(bytes32 role) private pure returns (bool) {
        return role == keccak256("CORE") || role == keccak256("COLLECTION_METADATA")
            || role == keccak256("METADATA_COMPANION") || role == keccak256("DEPENDENCY_REGISTRY")
            || role == keccak256("ENTROPY_COORDINATOR");
    }

    function _key(R.RendererManifest calldata m) private pure returns (bytes32) {
        return keccak256(
            abi.encode(keccak256("6529STREAM_RENDERER_VERSION_V1"), m.rendererId, m.rendererVersion)
        );
    }

    function _declaration(Registration calldata r, Read[] calldata declared)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                REGISTRATION,
                deploymentChainId,
                address(this),
                schemaRegistry,
                schemaRegistryCodeHash,
                targetSetHash,
                r,
                declared
            )
        );
    }

    function _scope(bytes32 key) private view returns (bytes32) {
        return keccak256(abi.encode(SCOPE, deploymentChainId, address(this), key));
    }

    function _state(bytes32 declaration, bool deprecated) private pure returns (bytes32) {
        return keccak256(abi.encode(STATE, declaration, deprecated));
    }

    function _governed(bytes32 scope, bytes32 previous, bytes32 next, uint8 kind)
        private
        view
        returns (bytes32 id)
    {
        if (
            block.chainid != deploymentChainId || msg.sender != governanceAuthority
                || msg.sender.codehash != governanceAuthorityCodeHash
        ) revert RendererGovernanceRequired();
        (bool executing, bytes32 action, uint8 actionClass, bytes32 s, bytes32 p, bytes32 n) =
            G(governanceAuthority).currentAction();
        if (
            !executing || action == 0 || actionClass != kind || s != scope || p != previous
                || n != next
        ) {
            revert RendererGovernanceRequired();
        }
        return action;
    }
}
