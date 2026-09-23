// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRendererAdmissionValidation as AdmissionValidation
} from "./StreamRendererAdmissionValidation.sol";
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
import {
    IStreamTerminalEntropyRegistry as Terminal
} from "../../interfaces/stream/metadata/IStreamTerminalEntropyRegistry.sol";
import {
    StreamTerminalEntropyAdmission as TerminalAdmission
} from "./StreamTerminalEntropyAdmission.sol";
import {
    IStreamCurrentCitationRegistry as Current
} from "../../interfaces/stream/metadata/IStreamCurrentCitationRegistry.sol";
import {
    StreamCurrentCitationAdmission as CitationAdmission
} from "./StreamCurrentCitationAdmission.sol";

import {
    IStreamPreservationRegistryV1 as Preservation
} from "../../interfaces/stream/metadata/IStreamPreservationRegistryV1.sol";
import {
    StreamPreservationRegistration as PreservationWriter
} from "./StreamPreservationRegistration.sol";
import {
    StreamPreservationAdmission as PreservationAdmission
} from "./StreamPreservationAdmission.sol";

/// @notice Governance-admitted STATIC versions with immutable runtime, source set and evidence.
/// @dev No removal, incident-disable, target substitution or reactivation entry exists. A version
/// remains available to historical pins after deprecation. The deployment's named allowlist is
/// immutable. Gate reports are exact registered analysis assertions, not onchain proof of a
/// program's reachable opcodes; genuine static analysis remains a release admission obligation.
contract StreamRendererRegistry is V, Current, Terminal, Preservation, StreamGasParameterHost {
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
    uint256 public constant MAX_OUTPUT_BYTES = 16777216;
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
    // Fixed namespace keeps both the original registry and derived module storage unchanged.
    bytes32 private constant CITATION_SLOT =
        keccak256("6529STREAM_RENDERER_REGISTRY_CURRENT_CITATION_STORAGE_V1");

    bytes32 private immutable _preservationValidationCodeHash;

    struct CitationState {
        mapping(bytes32 => Current.CurrentRecord) records;
        mapping(bytes32 => Read[]) reads;
    }

    function _citationState() private pure returns (CitationState storage s) {
        bytes32 slot = CITATION_SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function _terminalState() private pure returns (CitationState storage s) {
        bytes32 slot = keccak256("6529STREAM_RENDERER_REGISTRY_TERMINAL_ENTROPY_STORAGE_V1");
        assembly ("memory-safe") { s.slot := slot }
    }

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
                    || !(_role(t.role) || _preservationRole(t.role))
            ) revert InvalidRendererRegistration();
            previous = t.target;
            _targets.push(t);
        }
        governanceAuthorityCodeHash = executor.codehash;
        schemaRegistry = schemas;
        schemaRegistryCodeHash = schemas.codehash;
        targetSetHash = keccak256(abi.encode(targets));
        deploymentChainId = block.chainid;
        if (address(PreservationAdmission).code.length == 0) {
            revert Preservation.InvalidPreservationAdmission();
        }
        _preservationValidationCodeHash = address(PreservationAdmission).codehash;
    }

    function supportsInterface(bytes4 id) public pure virtual returns (bool) {
        return id == type(V).interfaceId || id == type(Current).interfaceId
            || id == type(Terminal).interfaceId || id == type(Preservation).interfaceId
            || id == 0x01ffc9a7;
    }

    function _preservationState() private pure returns (PreservationWriter.State storage s) {
        bytes32 slot = keccak256("6529STREAM_RENDERER_REGISTRY_PRESERVATION_STORAGE_V1");
        assembly ("memory-safe") { s.slot := slot }
    }

    function preservationValidationBinding() external view returns (address, bytes32) {
        return (address(PreservationAdmission), _preservationValidationCodeHash);
    }

    function preservationKey(bytes32 versionKey, address producer, bytes32 profile)
        external
        pure
        returns (bytes32)
    {
        return PreservationAdmission.key(versionKey, producer, profile);
    }

    function registerPreservation(Preservation.PreservationRegistration calldata, Read[] calldata)
        external
    {
        PreservationWriter.registerEncoded(
            _preservationState(), _versions, _targets, _reads, _preservationContext(), msg.data
        );
    }

    function preservationTransition(Preservation.PreservationRegistration calldata, Read[] calldata)
        external
        view
        returns (bytes32, bytes32, bytes32)
    {
        return PreservationWriter.transitionEncoded(
            _preservationState(), _versions, _preservationContext(), msg.data
        );
    }

    function preservationRecord(bytes32 key)
        external
        view
        returns (Preservation.PreservationRecord memory)
    {
        return _preservationState().records[key];
    }

    function preservationReads(bytes32 key) external view returns (Read[] memory) {
        return _preservationState().reads[key];
    }

    function requirePreservation(bytes32 versionKey, address producer, bytes32 profile)
        external
        view
        returns (Preservation.ProducerBinding calldata, Preservation.Admission calldata)
    {
        if (address(PreservationAdmission).codehash != _preservationValidationCodeHash) {
            revert Preservation.PreservationUnavailable(PreservationAdmission.key(
                    versionKey, producer, profile
                ));
        }
        bytes memory raw = Calls.fixedCode(
            address(PreservationAdmission),
            abi.encodeWithSelector(
                PreservationAdmission.requireRegistry.selector,
                address(this),
                versionKey,
                producer,
                profile,
                _gasParameterValue(READ_GAS)
            ),
            512,
            gasleft()
        );
        if (raw.length != 512) revert Preservation.InvalidPreservationAdmission();
        // Terminal raw return: the fixed worker has already produced the exact public tuple.
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }

    function _preservationContext() private view returns (PreservationWriter.Context memory) {
        return PreservationWriter.Context(
            governanceAuthority,
            governanceAuthorityCodeHash,
            schemaRegistry,
            schemaRegistryCodeHash,
            targetSetHash,
            deploymentChainId,
            _gasParameterValue(READ_GAS),
            _gasParameterValue(GOLDEN_GAS)
        );
    }

    function _preservationRole(bytes32 role) private pure returns (bool) {
        return role == keccak256("PRESERVATION_RENDERER")
            || role == keccak256("PRESERVATION_ATTRIBUTION")
            || role == keccak256("PRESERVATION_COMPANION");
    }

    function registerTerminalEntropy(
        Current.CurrentRegistration calldata r,
        Read[] calldata declared
    ) external override {
        Version storage v = _versions[r.versionKey];
        CitationState storage s = _terminalState();
        if (!v.exists || v.deprecated || s.records[r.versionKey].registrationHash != 0) {
            revert Terminal.TerminalEntropyProfileUnavailable(r.versionKey);
        }
        _retained(r.versionKey);
        bytes32 declaration = _terminalDeclaration(r, declared);
        bytes32 action = _governed(
            _terminalScope(r.versionKey), _terminalHash(0), _terminalHash(declaration), 1
        );
        bytes32 setHash = _readSet(declared);
        bytes memory analysis = _document(r.analysisDocument);
        bytes memory golden = _document(r.goldenDocument);
        TerminalAdmission.validate(
            r,
            v,
            declared,
            _targets,
            _reads[r.versionKey],
            setHash,
            analysis,
            golden,
            _gasParameterValue(READ_GAS),
            _gasParameterValue(GOLDEN_GAS)
        );
        s.records[r.versionKey] = Current.CurrentRecord(
            r, declaration, setHash, keccak256(analysis), keccak256(golden), action
        );
        for (uint256 i; i < declared.length; ++i) {
            s.reads[r.versionKey].push(declared[i]);
        }
        emit TerminalEntropyProfileRegistered(
            1, r.versionKey, v.renderer, action, declaration, r, declared
        );
    }

    function terminalEntropyTransition(
        Current.CurrentRegistration calldata r,
        Read[] calldata declared
    ) external view override returns (bytes32, bytes32, bytes32) {
        return (
            _terminalScope(r.versionKey),
            _terminalHash(_terminalState().records[r.versionKey].registrationHash),
            _terminalHash(_terminalDeclaration(r, declared))
        );
    }

    function terminalEntropyRecord(bytes32 key)
        external
        view
        override
        returns (Current.CurrentRecord memory)
    {
        return _terminalState().records[key];
    }

    function terminalEntropyReads(bytes32 key) external view override returns (Read[] memory) {
        return _terminalState().reads[key];
    }

    function requireTerminalEntropy(bytes32 key)
        external
        view
        override
        returns (address renderer, bytes32 runtimeHash, bytes32 profile, bytes4 selector)
    {
        CitationState storage s = _terminalState();
        Current.CurrentRecord storage c = s.records[key];
        if (c.registrationHash == 0 || deploymentChainId != block.chainid) {
            revert Terminal.TerminalEntropyProfileUnavailable(key);
        }
        (renderer, runtimeHash) = _retained(key);
        Read[] storage declared = s.reads[key];
        for (uint256 i; i < declared.length; ++i) {
            Target storage t = _targets[declared[i].targetIndex];
            if (t.target.code.length == 0 || t.target.codehash != t.codeHash) {
                revert Terminal.TerminalEntropyProfileUnavailable(key);
            }
        }
        TerminalAdmission.bindings(c.registration, renderer, _gasParameterValue(READ_GAS));
        return (renderer, runtimeHash, c.registration.profile, c.registration.selector);
    }

    function _terminalDeclaration(Current.CurrentRegistration calldata r, Read[] calldata declared)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_TERMINAL_ENTROPY_REGISTRATION_V1"),
                deploymentChainId,
                address(this),
                schemaRegistry,
                schemaRegistryCodeHash,
                targetSetHash,
                _versions[r.versionKey].registrationHash,
                r,
                declared
            )
        );
    }

    function _terminalScope(bytes32 key) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_TERMINAL_ENTROPY_SCOPE_V1"),
                deploymentChainId,
                address(this),
                key
            )
        );
    }

    function _terminalHash(bytes32 value) private pure returns (bytes32) {
        return keccak256(abi.encode(keccak256("6529STREAM_TERMINAL_ENTROPY_STATE_V1"), value));
    }

    /// @notice Additional class-1 evidence, never a replacement for the immutable original version.
    function registerCurrentCitation(
        Current.CurrentRegistration calldata r,
        Read[] calldata declared
    ) external override {
        Version storage v = _versions[r.versionKey];
        CitationState storage citations = _citationState();
        if (!v.exists || v.deprecated || citations.records[r.versionKey].registrationHash != 0) {
            revert Current.CurrentCitationUnavailable(r.versionKey);
        }
        _retained(r.versionKey);
        bytes32 declaration = _currentDeclaration(r, declared);
        bytes32 action =
            _governed(_currentScope(r.versionKey), _currentState(0), _currentState(declaration), 1);
        bytes32 setHash = _readSet(declared);
        bytes memory analysis = _document(r.analysisDocument);
        bytes memory golden = _document(r.goldenDocument);
        CitationAdmission.validate(
            r,
            v,
            declared,
            _targets,
            _reads[r.versionKey],
            setHash,
            analysis,
            golden,
            _gasParameterValue(READ_GAS),
            _gasParameterValue(GOLDEN_GAS)
        );
        citations.records[r.versionKey] = Current.CurrentRecord(
            r, declaration, setHash, keccak256(analysis), keccak256(golden), action
        );
        for (uint256 i; i < declared.length; ++i) {
            citations.reads[r.versionKey].push(declared[i]);
        }
        emit CurrentCitationRegistered(
            1, r.versionKey, v.renderer, action, declaration, r, declared
        );
    }

    function currentCitationTransition(
        Current.CurrentRegistration calldata r,
        Read[] calldata declared
    ) external view override returns (bytes32 scope, bytes32 previous, bytes32 next) {
        return (
            _currentScope(r.versionKey),
            _currentState(_citationState().records[r.versionKey].registrationHash),
            _currentState(_currentDeclaration(r, declared))
        );
    }

    function currentCitationRecord(bytes32 key)
        external
        view
        override
        returns (Current.CurrentRecord memory)
    {
        return _citationState().records[key];
    }

    function currentCitationReads(bytes32 key) external view override returns (Read[] memory) {
        return _citationState().reads[key];
    }

    function requireCurrentCitation(bytes32 key)
        external
        view
        override
        returns (address renderer, bytes32 runtimeHash, bytes32 profile, bytes4 selector)
    {
        CitationState storage citations = _citationState();
        Current.CurrentRecord storage c = citations.records[key];
        if (c.registrationHash == 0 || deploymentChainId != block.chainid) {
            revert Current.CurrentCitationUnavailable(key);
        }
        (renderer, runtimeHash) = _retained(key);
        // Like the original retained profile, catalogue retirement/deprecation does not erase
        // accepted evidence. Current executable dependencies must still match every declared pin.
        Read[] storage declared = citations.reads[key];
        for (uint256 i; i < declared.length; ++i) {
            Target storage t = _targets[declared[i].targetIndex];
            if (t.target.code.length == 0 || t.target.codehash != t.codeHash) {
                revert Current.CurrentCitationUnavailable(key);
            }
        }
        CitationAdmission.bindingsInternal(c.registration, renderer, _gasParameterValue(READ_GAS));
        return (renderer, runtimeHash, c.registration.profile, c.registration.selector);
    }

    function _currentDeclaration(Current.CurrentRegistration calldata r, Read[] calldata declared)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CURRENT_CITATION_REGISTRATION_V1"),
                deploymentChainId,
                address(this),
                schemaRegistry,
                schemaRegistryCodeHash,
                targetSetHash,
                _versions[r.versionKey].registrationHash,
                r,
                declared
            )
        );
    }

    function _currentScope(bytes32 key) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CURRENT_CITATION_SCOPE_V1"),
                deploymentChainId,
                address(this),
                key
            )
        );
    }

    function _currentState(bytes32 declaration) private pure returns (bytes32) {
        return keccak256(abi.encode(keccak256("6529STREAM_CURRENT_CITATION_STATE_V1"), declaration));
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
        (bytes32 setHash, bytes32 analysis, bytes32 golden) = AdmissionValidation.validate(
            r,
            declared,
            _targets,
            AdmissionValidation.Context(schemaRegistry, schemaRegistryCodeHash, targetSetHash)
        );
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

    function _document(bytes32 id) private view returns (bytes memory payload) {
        F.DocumentFacts memory f = _fact(id, S.DocumentKind.CATALOG);
        if (f.totalBytes == 0 || f.totalBytes > 8192) revert InvalidRendererEvidence(id);
        bytes memory encoded = Calls.read(
            schemaRegistry,
            abi.encodeCall(S.documentBytes, (id)),
            Calls.ReadOptions(64 + ((uint256(f.totalBytes) + 31) / 32) * 32, false),
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
                Calls.ReadOptions(288, true),
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
        // Finite named Artist/C2PA companion profile. A role is a declaration label, not
        // authority or proof of finality safety; exact targets, reads and evidence still bind.
        return role == keccak256("CORE") || role == keccak256("COLLECTION_METADATA")
            || role == keccak256("METADATA_COMPANION") || role == keccak256("DEPENDENCY_REGISTRY")
            || role == keccak256("ENTROPY_COORDINATOR")
            || role == keccak256("STATIC_C2PA_ATTRIBUTION")
            || role == keccak256("C2PA_RECONCILIATION") || role == keccak256("ARTIST_REGISTRY")
            || role == keccak256("ARTIST_STATIC_DISPLAY") || role == keccak256("ARTIST_COORDINATOR")
            || role == keccak256("ARTIST_IDENTITY_OWNER")
            || role == keccak256("ARTIST_BINDING_OWNER")
            || role == keccak256("ARTIST_ATTRIBUTION_OWNER")
            || role == keccak256("ARTIST_COLLABORATOR_RECORDS_OWNER")
            || role == keccak256("ARTIST_ACCEPTANCE_OWNER")
            || role == keccak256("ARTIST_SANCTION_OWNER")
            || role == keccak256("ARTIST_PAYOUT_OWNER")
            || role == keccak256("STATIC_ARTIST_LINEAGE_SOURCE")
            || role == keccak256("STATIC_ARTIST_LINEAGE_CATALOGUE")
            || role == keccak256("STATIC_ARTIST_LINEAGE_COMPANION")
            || role == keccak256("STATIC_ARTIST_LINEAGE_RENDERING");
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
