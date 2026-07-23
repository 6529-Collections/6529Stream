// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamGasParameterHost.sol";
import "./IStreamGasParameterProbe.sol";
import "./IStreamGovernedParameterAuthority.sol";
import "./IStreamModuleRegistry.sol";

/// @notice Reusable rich standalone Governed Gas Parameter host machinery per
///         `docs/stream-long-term-architecture.md` [LTA-GGP] requirements 1-12.
///         Satellites that need the rich enumeration and convenience reads may
///         embed this base; standalone parameter stores (for example the split
///         factory parameter store) deploy `StreamGasParameterStore`.
/// @dev    This is not Core's byte-minimal [LTA-GGP-CORE] implementation. Core
///         owns its fixed four-row inventory and exact minimal ABI separately and
///         must not inherit this rich profile.
///
///         Design pins:
///         - values are storage-backed reads, never immutables or compiled-in
///           constants (definition item 1; ADR 0010 decision D1);
///         - per-parameter floors are fixed at registration and can never be
///           crossed (definition item 2);
///         - `parameterId = keccak256("6529STREAM_GGP_" || name)` is derived from
///           the registered name, never supplied (definition item 5);
///         - every raise (staged, emergency, conditional) is bounded to at most
///           2x current per action (requirement 1);
///         - the emergency raise is raise-only and admitted only against a fresh
///           failing probe run at the current value (requirement 1);
///         - governed lowers recheck a fresh passing probe run at exactly the
///           proposed value and revert below the floor (requirement 2);
///         - permissionless conditional raise/re-lower standing actions exist for
///           `FORWARDING_CAP` rows only and are registered at deployment — there
///           is no path that registers them for any other class (requirements
///           10-11; ADR 0012 decision T1; ADR 0014 decision V7);
///         - `gasParameterInfo` introspection is the normative lost-governance
///           source of floor, probe, class, and recency bound (requirement 12).
abstract contract StreamGasParameterHost is IStreamGasParameterHost {
    /// @notice Schema version carried by every canonical GGP event.
    uint16 public constant GAS_PARAMETER_SCHEMA_VERSION = 1;

    /// @notice Failure-direction class ids pinned by [LTA-GGP] requirement 12.
    uint8 public constant FAILURE_CLASS_NONE = 0;
    uint8 public constant FAILURE_CLASS_FORWARDING_CAP = 1;
    uint8 public constant FAILURE_CLASS_FAIL_CLOSED_PRECHECK = 2;
    uint8 public constant FAILURE_CLASS_MIN_GAS_GATE = 3;

    /// @notice Planning floor for `probeMaxAgeBlocks` ([LTA-GGP-PROBES] rule 6):
    ///         roughly seven days at twelve-second cadence, generous by design so
    ///         a lost-governance recency bound never strands the conditional paths.
    uint64 public constant PROBE_MAX_AGE_FLOOR_BLOCKS = 50_400;

    /// @dev Standing-action id domains for the pre-registered conditional raise and
    ///      re-lower ([LTA-GGP] requirement 11). These identify permissionless
    ///      standing actions in the guardian-module spirit ([LTA-GUARDIAN]); they are
    ///      not staged-operation preimages, which remain owned solely by
    ///      [GOV-ACTION-ID]. keccak256("6529STREAM_GGP_CONDITIONAL_RAISE_V1") and
    ///      keccak256("6529STREAM_GGP_CONDITIONAL_RELOWER_V1").
    bytes32 private constant _CONDITIONAL_RAISE_DOMAIN_V1 =
        0x88d201cde2efee286ecd558414d10dd0599848f47e6dcdfa51a2e0287e4fb2eb;
    bytes32 private constant _CONDITIONAL_RELOWER_DOMAIN_V1 =
        0xb30115be75ee59eeed3fa156242dc7c0eda20b383f4f251c8adcfa616b2276a1;

    /// @dev Production-exact target transition domains from [LTA-GGP-CORE].
    bytes32 private constant _GAS_PARAMETER_SCOPE_DOMAIN_V1 =
        0x8d8b74997070792410ba6f4dd511d967fec29b82366868401baa2bfb3681da69;
    bytes32 private constant _GAS_PARAMETER_STATE_DOMAIN_V1 =
        0xa16fd6b2f079cdf0a8f1a952c35496a693958895d1782fecc8b6440e06594977;
    bytes32 private constant _PROBE_BINDING_DOMAIN_V1 =
        0x4efb354b2a3c37f3c74fe57912e40eb08d83026611be9740d785f348cc2332c4;

    bytes32 private constant _GGP_PROBE_MODULE_TYPE =
        0xe358a47f0dcbc7a22cc88ea7cd9ff433ec85ce6d9c7d0dc3f329e98b621cd6c8;
    bytes4 private constant _GGP_PROBE_INTERFACE_ID = 0x0f8c6b0f;
    bytes4 private constant _SUPPORTS_INTERFACE_SELECTOR = 0x01ffc9a7;
    bytes4 private constant _GET_SATELLITE_POINTER_SELECTOR = 0x3528d53c;
    bytes32 private constant _MODULE_REGISTRY_POINTER_TYPE =
        0xde86dd5f33a5b2bd22cfbe7752609f5086a946f705768f7e2e6cb501157a41c4;

    uint256 private constant _CORE_POINTER_RETURN_BYTES = 320;
    uint256 private constant _MAX_MODULE_RECORD_RETURN_BYTES = 2_496;
    uint256 private constant _MAX_MODULE_MANIFEST_URI_BYTES = 2_048;
    uint8 private constant _MODULE_STATUS_ACTIVE = 1;

    uint8 private constant _ACTION_CLASS_DELAYED_LOOSENING = 1;
    uint8 private constant _ACTION_CLASS_POINTER_REPLACEMENT = 3;
    uint8 private constant _ACTION_CLASS_EMERGENCY_RESTORATION = 6;

    struct GasParameterData {
        uint256 value;
        uint256 floor;
        address probe;
        uint8 failureClass;
        uint64 probeMaxAgeBlocks;
        uint64 revision;
        bytes32 probeRuntimeCodeHash;
        bytes32 probeBindingHash;
        bytes32 conditionalRaiseActionId;
        bytes32 conditionalRelowerActionId;
    }

    /// @dev Static tuple matching the eleven fields after
    ///      `STREAM_GAS_PARAMETER_STATE_V1` in the production-exact state hash.
    struct GasParameterStateCommitment {
        bytes32 scopeHash;
        uint256 value;
        uint256 floor;
        address probe;
        bytes32 probeRuntimeCodeHash;
        bytes32 probeBindingHash;
        uint8 failureClass;
        uint64 probeMaxAgeBlocks;
        bytes32 conditionalRaiseActionId;
        bytes32 conditionalRelowerActionId;
        uint64 revision;
    }

    /// @dev Exact ten-word return of Core's production pointer getter.
    struct CorePointerFacts {
        address target;
        bytes32 codeHash;
        bool frozen;
        bytes32 moduleType;
        bytes4 interfaceId;
        address registry;
        uint8 registryStatus;
        bytes32 moduleManifestHash;
        bytes32 deploymentManifestHash;
        uint64 revision;
    }

    /// @dev Registry-V2 record shape. The canonical registry interface retains
    ///      the V1 selector while appending this monotonic revision to returndata.
    struct ModuleRecordV2 {
        uint8 status;
        bytes32 moduleType;
        bytes32 moduleVersion;
        bytes4 interfaceId;
        uint32 moduleGasLimit;
        bytes32 runtimeCodeHash;
        bytes32 deploymentManifestHash;
        bytes32 moduleManifestHash;
        string moduleManifestURI;
        uint64 registeredAt;
        uint64 statusUpdatedAt;
        uint64 revision;
    }

    /// @inheritdoc IStreamGasParameterHost
    address public immutable override governanceAuthority;

    address private immutable _coreRegistrySource;
    address private immutable _genesisModuleRegistry;

    mapping(bytes32 => GasParameterData) private _gasParameters;
    bytes32[] private _gasParameterIds;

    /// @param authority The canonical Governance-V2 executor, or address(0) for
    ///        a host with no governance whose governed entry points permanently
    ///        revert.
    /// @param core_ The immutable, already deployed external Core address that
    ///        owns the live canonical `MODULE_REGISTRY` pointer. This rich host
    ///        is not a construction base for Core itself.
    /// @param genesisModuleRegistry_ The code-bearing registry address committed
    ///        into every deployment-time expected probe binding. It is historical
    ///        after Core initializes its live pointer.
    constructor(address authority, address core_, address genesisModuleRegistry_) {
        if (authority != address(0)) {
            if (
                _isEip7702DelegatedEOA(authority)
                    || !IStreamGovernedParameterAuthority(authority)
                        .isStreamGovernedParameterAuthority()
            ) {
                revert GasParameterInvalidAuthority(authority);
            }
        }
        if (core_ == address(0) || core_.code.length == 0 || _isEip7702DelegatedEOA(core_)) {
            revert GasParameterInvalidCore(core_);
        }
        if (
            genesisModuleRegistry_ == address(0) || genesisModuleRegistry_.code.length == 0
                || _isEip7702DelegatedEOA(genesisModuleRegistry_)
                || !_supportsModuleRegistryInterface(genesisModuleRegistry_)
        ) {
            revert GasParameterInvalidModuleRegistry(genesisModuleRegistry_);
        }
        governanceAuthority = authority;
        _coreRegistrySource = core_;
        _genesisModuleRegistry = genesisModuleRegistry_;
    }

    // ---------------------------------------------------------------------
    // Registration (deployment-time only)
    // ---------------------------------------------------------------------

    /// @dev Registers one Governed Gas Parameter. Callable only from constructors
    ///      of embedding hosts — there is no external registration surface, so the
    ///      parameter set and every floor, probe binding, class, and standing
    ///      conditional action are fixed at deployment ([LTA-GGP] definition
    ///      items 2 and 6; requirement 11).
    function _registerGasParameter(GasParameterConfig memory config)
        internal
        returns (bytes32 parameterId)
    {
        if (bytes(config.name).length == 0) {
            revert GasParameterInvalidConfig(bytes32(0));
        }
        parameterId = keccak256(abi.encodePacked("6529STREAM_GGP_", config.name));

        GasParameterData storage parameter = _gasParameters[parameterId];
        if (parameter.failureClass != FAILURE_CLASS_NONE) {
            revert GasParameterAlreadyRegistered(parameterId);
        }
        if (
            config.floor == 0 || config.genesisValue < config.floor
                || config.failureClass < FAILURE_CLASS_FORWARDING_CAP
                || config.failureClass > FAILURE_CLASS_MIN_GAS_GATE
                || config.probeMaxAgeBlocks < PROBE_MAX_AGE_FLOOR_BLOCKS
                || config.expectedProbeModuleVersion == bytes32(0)
                || config.expectedProbeRuntimeCodeHash == bytes32(0)
                || config.expectedProbeModuleManifestHash == bytes32(0)
                || config.expectedProbeDeploymentManifestHash == bytes32(0)
        ) {
            revert GasParameterInvalidConfig(parameterId);
        }
        (bytes32 probeRuntimeCodeHash, bytes32 probeBindingHash) =
            _expectedGenesisProbeBinding(parameterId, config);

        parameter.value = config.genesisValue;
        parameter.floor = config.floor;
        parameter.probe = config.probe;
        parameter.failureClass = config.failureClass;
        parameter.probeMaxAgeBlocks = config.probeMaxAgeBlocks;
        parameter.revision = 1;
        parameter.probeRuntimeCodeHash = probeRuntimeCodeHash;
        parameter.probeBindingHash = probeBindingHash;

        // Requirement 11: the standing conditional raise and re-lower are
        // registered here, at deployment, for FORWARDING_CAP rows and only for
        // FORWARDING_CAP rows. No code path registers them for
        // FAIL_CLOSED_PRECHECK or MIN_GAS_GATE, so their existence for those
        // classes is impossible by construction (ADR 0012 decision T1).
        if (config.failureClass == FAILURE_CLASS_FORWARDING_CAP) {
            parameter.conditionalRaiseActionId = keccak256(
                abi.encode(_CONDITIONAL_RAISE_DOMAIN_V1, block.chainid, address(this), parameterId)
            );
            parameter.conditionalRelowerActionId = keccak256(
                abi.encode(
                    _CONDITIONAL_RELOWER_DOMAIN_V1, block.chainid, address(this), parameterId
                )
            );
        }

        _gasParameterIds.push(parameterId);

        emit GasParameterRegistered(
            GAS_PARAMETER_SCHEMA_VERSION,
            parameterId,
            config.name,
            config.genesisValue,
            config.floor,
            config.probe,
            config.failureClass,
            config.probeMaxAgeBlocks,
            parameter.conditionalRaiseActionId,
            parameter.conditionalRelowerActionId
        );
    }

    // ---------------------------------------------------------------------
    // Introspection ([LTA-GGP] requirement 12)
    // ---------------------------------------------------------------------

    /// @inheritdoc IStreamGasParameterHost
    function gasParameterInfo(bytes32 parameterId)
        external
        view
        override
        returns (
            uint256 value,
            uint256 floor,
            address probe,
            uint8 failureClass,
            uint64 probeMaxAgeBlocks,
            uint64 revision
        )
    {
        GasParameterData storage parameter = _gasParameters[parameterId];
        return (
            parameter.value,
            parameter.floor,
            parameter.probe,
            parameter.failureClass,
            parameter.probeMaxAgeBlocks,
            parameter.revision
        );
    }

    /// @inheritdoc IStreamGasParameterHost
    function gasParameter(bytes32 parameterId) public view override returns (uint256 value) {
        GasParameterData storage parameter = _gasParameters[parameterId];
        if (parameter.failureClass == FAILURE_CLASS_NONE) {
            revert GasParameterUnknown(parameterId);
        }
        return parameter.value;
    }

    /// @inheritdoc IStreamGasParameterHost
    function gasParameterIds() external view override returns (bytes32[] memory) {
        return _gasParameterIds;
    }

    /// @inheritdoc IStreamGasParameterHost
    function conditionalGasParameterActions(bytes32 parameterId)
        external
        view
        override
        returns (bytes32 conditionalRaiseActionId, bytes32 conditionalRelowerActionId)
    {
        GasParameterData storage parameter = _gasParameters[parameterId];
        return (parameter.conditionalRaiseActionId, parameter.conditionalRelowerActionId);
    }

    /// @inheritdoc IStreamGasParameterHost
    function moduleRegistry() public view override returns (address) {
        return _liveModuleRegistry();
    }

    // ---------------------------------------------------------------------
    // Governed paths (Governance-V2 target-side class/context enforcement)
    // ---------------------------------------------------------------------

    /// @inheritdoc IStreamGasParameterHost
    function raiseGasParameter(bytes32 parameterId, uint256 newValue) external override {
        _requireAuthorityCaller();
        GasParameterData storage parameter = _requireRegistered(parameterId);
        _checkRaiseBound(parameterId, parameter.value, newValue);
        _setGovernedValue(parameterId, parameter, newValue, _ACTION_CLASS_DELAYED_LOOSENING);
    }

    /// @inheritdoc IStreamGasParameterHost
    function emergencyRaiseGasParameter(bytes32 parameterId, uint256 newValue) external override {
        _requireAuthorityCaller();
        GasParameterData storage parameter = _requireRegistered(parameterId);
        // Raise-only + 2x bound first: an emergency action can never lower.
        _checkRaiseBound(parameterId, parameter.value, newValue);
        // Health-probe gate: only a fresh failing run at the current value —
        // genuine degradation proof under [LTA-GGP-PROBES] rule 5 — admits the
        // raise; a healthy parameter can never be emergency-raised.
        _requireFreshFailingRunAtCurrent(parameterId, parameter);
        _setGovernedValue(parameterId, parameter, newValue, _ACTION_CLASS_EMERGENCY_RESTORATION);
    }

    /// @inheritdoc IStreamGasParameterHost
    function lowerGasParameter(bytes32 parameterId, uint256 newValue) external override {
        _requireAuthorityCaller();
        GasParameterData storage parameter = _requireRegistered(parameterId);
        if (newValue >= parameter.value) {
            revert GasParameterNotALower(parameterId, parameter.value, newValue);
        }
        if (newValue < parameter.floor) {
            revert GasParameterBelowFloor(parameterId, newValue, parameter.floor);
        }
        _requireFreshPassingRunAtExactValue(parameterId, parameter, newValue);
        _setGovernedValue(parameterId, parameter, newValue, _ACTION_CLASS_DELAYED_LOOSENING);
    }

    /// @inheritdoc IStreamGasParameterHost
    function rebindGasParameterProbe(bytes32 parameterId, address newProbe) external override {
        // [LTA-GGP-PROBES] rule 3: while governance functions, the binding may
        // move to a successor Permanent-class probe through the normal delay
        // class; with governance lost (zero authority) this path is dead and the
        // binding is frozen.
        _requireAuthorityCaller();
        GasParameterData storage parameter = _requireRegistered(parameterId);
        (bytes32 newRuntimeCodeHash, bytes32 newBindingHash) =
            _resolveProbeBinding(parameterId, newProbe);
        address oldProbe = parameter.probe;
        if (
            newProbe == oldProbe && newRuntimeCodeHash == parameter.probeRuntimeCodeHash
                && newBindingHash == parameter.probeBindingHash
        ) {
            revert GasParameterProbeRebindNoOp(parameterId, newProbe);
        }
        uint64 nextRevision = _nextRevision(parameterId, parameter.revision);
        bytes32 scopeHash = _scopeHash(parameterId);
        bytes32 oldStateHash = _stateHash(scopeHash, parameter);
        bytes32 newStateHash = _stateHash(
            scopeHash,
            parameter,
            parameter.value,
            newProbe,
            newRuntimeCodeHash,
            newBindingHash,
            nextRevision
        );
        bytes32 actionId = _requireGovernanceContext(
            _ACTION_CLASS_POINTER_REPLACEMENT, scopeHash, oldStateHash, newStateHash
        );
        parameter.probe = newProbe;
        parameter.probeRuntimeCodeHash = newRuntimeCodeHash;
        parameter.probeBindingHash = newBindingHash;
        parameter.revision = nextRevision;
        emit GasParameterProbeRebound(
            GAS_PARAMETER_SCHEMA_VERSION, parameterId, address(this), actionId, oldProbe, newProbe
        );
    }

    // ---------------------------------------------------------------------
    // Permissionless conditional paths ([LTA-GGP] requirement 11,
    // FORWARDING_CAP only)
    // ---------------------------------------------------------------------

    /// @inheritdoc IStreamGasParameterHost
    function conditionalRaiseGasParameter(bytes32 parameterId, uint256 newValue) external override {
        GasParameterData storage parameter = _requireRegistered(parameterId);
        bytes32 standingActionId = parameter.conditionalRaiseActionId;
        if (standingActionId == bytes32(0)) {
            revert GasParameterConditionalActionUnavailable(parameterId, parameter.failureClass);
        }
        _checkRaiseBound(parameterId, parameter.value, newValue);
        _requireFreshFailingRunAtCurrent(parameterId, parameter);
        _setValue(parameterId, parameter, newValue, standingActionId);
    }

    /// @inheritdoc IStreamGasParameterHost
    function conditionalRelowerGasParameter(bytes32 parameterId, uint256 newValue)
        external
        override
    {
        GasParameterData storage parameter = _requireRegistered(parameterId);
        bytes32 standingActionId = parameter.conditionalRelowerActionId;
        if (standingActionId == bytes32(0)) {
            revert GasParameterConditionalActionUnavailable(parameterId, parameter.failureClass);
        }
        uint256 currentValue = parameter.value;
        if (newValue >= currentValue) {
            revert GasParameterNotALower(parameterId, currentValue, newValue);
        }
        // Symmetric per-action bound: no lower than half the current value
        // (newValue >= currentValue - newValue avoids overflow).
        if (newValue < currentValue - newValue) {
            revert GasParameterLowerBoundExceeded(parameterId, currentValue, newValue);
        }
        if (newValue < parameter.floor) {
            revert GasParameterBelowFloor(parameterId, newValue, parameter.floor);
        }
        _requireFreshPassingRunAtExactValue(parameterId, parameter, newValue);
        _setValue(parameterId, parameter, newValue, standingActionId);
    }

    // ---------------------------------------------------------------------
    // Internal helpers
    // ---------------------------------------------------------------------

    /// @dev Live value read for embedding hosts' guarded paths and EIP-150 63/64
    ///      prechecks ([LTA-GGP] requirement 5): always the current storage value.
    function _gasParameterValue(bytes32 parameterId) internal view returns (uint256) {
        return gasParameter(parameterId);
    }

    function _requireAuthorityCaller() private view {
        if (governanceAuthority == address(0) || msg.sender != governanceAuthority) {
            revert GasParameterNotAuthority(msg.sender);
        }
    }

    function _requireRegistered(bytes32 parameterId)
        private
        view
        returns (GasParameterData storage parameter)
    {
        parameter = _gasParameters[parameterId];
        if (parameter.failureClass == FAILURE_CLASS_NONE) {
            revert GasParameterUnknown(parameterId);
        }
    }

    function _checkRaiseBound(bytes32 parameterId, uint256 currentValue, uint256 newValue)
        private
        pure
    {
        if (newValue <= currentValue) {
            revert GasParameterNotARaise(parameterId, currentValue, newValue);
        }
        // At most 2x per action (newValue - currentValue <= currentValue avoids
        // overflow) — [LTA-GGP] requirement 1.
        if (newValue - currentValue > currentValue) {
            revert GasParameterRaiseBoundExceeded(parameterId, currentValue, newValue);
        }
    }

    function _scopeHash(bytes32 parameterId) private view returns (bytes32) {
        return keccak256(
            abi.encode(_GAS_PARAMETER_SCOPE_DOMAIN_V1, block.chainid, address(this), parameterId)
        );
    }

    function _stateHash(bytes32 scopeHash, GasParameterData storage parameter)
        private
        view
        returns (bytes32)
    {
        return _stateHash(
            scopeHash,
            parameter,
            parameter.value,
            parameter.probe,
            parameter.probeRuntimeCodeHash,
            parameter.probeBindingHash,
            parameter.revision
        );
    }

    function _stateHash(
        bytes32 scopeHash,
        GasParameterData storage parameter,
        uint256 value,
        address probe,
        bytes32 probeRuntimeCodeHash,
        bytes32 probeBindingHash,
        uint64 revision
    ) private view returns (bytes32) {
        GasParameterStateCommitment memory state =
            GasParameterStateCommitment({
                scopeHash: scopeHash,
                value: value,
                floor: parameter.floor,
                probe: probe,
                probeRuntimeCodeHash: probeRuntimeCodeHash,
                probeBindingHash: probeBindingHash,
                failureClass: parameter.failureClass,
                probeMaxAgeBlocks: parameter.probeMaxAgeBlocks,
                conditionalRaiseActionId: parameter.conditionalRaiseActionId,
                conditionalRelowerActionId: parameter.conditionalRelowerActionId,
                revision: revision
            });
        return keccak256(abi.encode(_GAS_PARAMETER_STATE_DOMAIN_V1, state));
    }

    function _nextRevision(bytes32 parameterId, uint64 revision) private pure returns (uint64) {
        if (revision == type(uint64).max) {
            revert GasParameterRevisionOverflow(parameterId);
        }
        unchecked {
            return revision + 1;
        }
    }

    function _requireGovernanceContext(
        uint8 expectedClass,
        bytes32 expectedScopeHash,
        bytes32 expectedOldStateHash,
        bytes32 expectedNewStateHash
    ) private view returns (bytes32 actionId) {
        (
            bool executing,
            bytes32 currentActionId,
            uint8 actionClass,
            bytes32 scopeHash,
            bytes32 oldStateHash,
            bytes32 newStateHash
        ) = IStreamGovernedParameterAuthority(governanceAuthority).currentAction();
        if (!executing) revert GasParameterActionNotExecuting();
        if (currentActionId == bytes32(0)) revert GasParameterActionIdZero();
        if (actionClass != expectedClass) {
            revert GasParameterActionClassMismatch(expectedClass, actionClass);
        }
        if (scopeHash != expectedScopeHash) {
            revert GasParameterScopeHashMismatch(expectedScopeHash, scopeHash);
        }
        if (oldStateHash != expectedOldStateHash) {
            revert GasParameterOldStateHashMismatch(expectedOldStateHash, oldStateHash);
        }
        if (newStateHash != expectedNewStateHash) {
            revert GasParameterNewStateHashMismatch(expectedNewStateHash, newStateHash);
        }
        return currentActionId;
    }

    function _expectedGenesisProbeBinding(bytes32 parameterId, GasParameterConfig memory config)
        private
        view
        returns (bytes32 runtimeCodeHash, bytes32 bindingHash)
    {
        address probe = config.probe;
        if (probe == address(0)) {
            revert GasParameterProbeMismatch(parameterId, probe);
        }
        runtimeCodeHash = config.expectedProbeRuntimeCodeHash;
        if (probe.code.length != 0) {
            if (_isEip7702DelegatedEOA(probe) || probe.codehash != runtimeCodeHash) {
                revert GasParameterProbeBindingInvalid(parameterId, probe);
            }
            _requireProbeParameterId(parameterId, probe);
        }

        bindingHash = keccak256(
            abi.encode(
                _PROBE_BINDING_DOMAIN_V1,
                _genesisModuleRegistry,
                probe,
                _GGP_PROBE_MODULE_TYPE,
                _GGP_PROBE_INTERFACE_ID,
                config.expectedProbeModuleVersion,
                runtimeCodeHash,
                config.expectedProbeModuleManifestHash,
                config.expectedProbeDeploymentManifestHash
            )
        );
    }

    function _resolveProbeBinding(bytes32 parameterId, address probe)
        private
        view
        returns (bytes32 runtimeCodeHash, bytes32 bindingHash)
    {
        if (probe == address(0)) {
            revert GasParameterProbeMismatch(parameterId, probe);
        }
        if (probe.code.length == 0 || _isEip7702DelegatedEOA(probe)) {
            revert GasParameterProbeBindingInvalid(parameterId, probe);
        }

        address liveRegistry = _liveModuleRegistry();
        ModuleRecordV2 memory record = _moduleRecord(liveRegistry, parameterId, probe);

        runtimeCodeHash = probe.codehash;
        if (
            record.status != _MODULE_STATUS_ACTIVE || record.moduleType != _GGP_PROBE_MODULE_TYPE
                || record.interfaceId != _GGP_PROBE_INTERFACE_ID
                || record.moduleVersion == bytes32(0) || record.runtimeCodeHash == bytes32(0)
                || record.runtimeCodeHash != runtimeCodeHash
                || record.moduleManifestHash == bytes32(0)
                || record.deploymentManifestHash == bytes32(0) || record.revision == 0
        ) {
            revert GasParameterProbeBindingInvalid(parameterId, probe);
        }

        _requireProbeParameterId(parameterId, probe);

        bindingHash = keccak256(
            abi.encode(
                _PROBE_BINDING_DOMAIN_V1,
                liveRegistry,
                probe,
                record.moduleType,
                record.interfaceId,
                record.moduleVersion,
                runtimeCodeHash,
                record.moduleManifestHash,
                record.deploymentManifestHash
            )
        );
    }

    function _liveModuleRegistry() private view returns (address liveRegistry) {
        (bool ok, bytes memory data) = _boundedStaticRead(
            _coreRegistrySource,
            abi.encodeWithSelector(_GET_SATELLITE_POINTER_SELECTOR, _MODULE_REGISTRY_POINTER_TYPE),
            _CORE_POINTER_RETURN_BYTES
        );
        if (
            !ok || data.length != _CORE_POINTER_RETURN_BYTES
                || !_isCanonicalCorePointerEncoding(data)
        ) {
            revert GasParameterLiveModuleRegistryInvalid(_coreRegistrySource);
        }
        CorePointerFacts memory facts = abi.decode(data, (CorePointerFacts));
        if (
            keccak256(data) != keccak256(abi.encode(facts)) || facts.target == address(0)
                || facts.target.code.length == 0 || _isEip7702DelegatedEOA(facts.target)
                || facts.target.codehash != facts.codeHash
                || facts.moduleType != _MODULE_REGISTRY_POINTER_TYPE
                || facts.interfaceId != type(IStreamModuleRegistry).interfaceId
                || !_supportsModuleRegistryInterface(facts.target) || facts.registry == address(0)
                || facts.registryStatus != _MODULE_STATUS_ACTIVE
                || facts.moduleManifestHash == bytes32(0)
                || facts.deploymentManifestHash == bytes32(0) || facts.revision == 0
        ) {
            revert GasParameterLiveModuleRegistryInvalid(_coreRegistrySource);
        }
        return facts.target;
    }

    function _moduleRecord(address liveRegistry, bytes32 parameterId, address probe)
        private
        view
        returns (ModuleRecordV2 memory record)
    {
        (bool ok, bytes memory data) = _boundedStaticRead(
            liveRegistry,
            abi.encodeWithSelector(IStreamModuleRegistry.moduleRecord.selector, probe),
            _MAX_MODULE_RECORD_RETURN_BYTES
        );
        if (!ok || !_isCanonicalModuleRecordEncoding(data)) {
            revert GasParameterProbeBindingInvalid(parameterId, probe);
        }
        record = abi.decode(data, (ModuleRecordV2));
        if (
            keccak256(data) != keccak256(abi.encode(record))
                || bytes(record.moduleManifestURI).length == 0
                || bytes(record.moduleManifestURI).length > _MAX_MODULE_MANIFEST_URI_BYTES
        ) {
            revert GasParameterProbeBindingInvalid(parameterId, probe);
        }
    }

    function _isCanonicalCorePointerEncoding(bytes memory data) private pure returns (bool valid) {
        assembly ("memory-safe") {
            valid := 1
            if shr(160, mload(add(data, 0x20))) { valid := 0 }
            if gt(mload(add(data, 0x60)), 1) { valid := 0 }
            if and(mload(add(data, 0xa0)), sub(shl(224, 1), 1)) { valid := 0 }
            if shr(160, mload(add(data, 0xc0))) { valid := 0 }
            if shr(8, mload(add(data, 0xe0))) { valid := 0 }
            if shr(64, mload(add(data, 0x140))) { valid := 0 }
        }
    }

    function _isCanonicalModuleRecordEncoding(bytes memory data) private pure returns (bool valid) {
        uint256 dataLength = data.length;
        if (dataLength < 448 || dataLength > _MAX_MODULE_RECORD_RETURN_BYTES) return false;
        assembly ("memory-safe") {
            valid := 1
            if iszero(eq(mload(add(data, 0x20)), 0x20)) { valid := 0 }
            if shr(8, mload(add(data, 0x40))) { valid := 0 }
            if and(mload(add(data, 0xa0)), sub(shl(224, 1), 1)) { valid := 0 }
            if shr(32, mload(add(data, 0xc0))) { valid := 0 }
            if iszero(eq(mload(add(data, 0x140)), 0x180)) { valid := 0 }
            if shr(64, mload(add(data, 0x160))) { valid := 0 }
            if shr(64, mload(add(data, 0x180))) { valid := 0 }
            if shr(64, mload(add(data, 0x1a0))) { valid := 0 }
            let stringLength := mload(add(data, 0x1c0))
            if or(iszero(stringLength), gt(stringLength, 0x800)) { valid := 0 }
            if iszero(eq(dataLength, add(0x1c0, and(add(stringLength, 0x1f), not(0x1f))))) {
                valid := 0
            }
        }
    }

    /// @dev Exact EIP-7702 designations are mutable EOA delegation markers, not
    ///      durable protocol code identities. They must never satisfy an
    ///      immutable or codehash-pinned host binding.
    function _isEip7702DelegatedEOA(address account) private view returns (bool delegated) {
        if (account.code.length != 23) return false;
        bytes3 prefix;
        assembly ("memory-safe") {
            extcodecopy(account, 0, 0, 3)
            prefix := mload(0)
        }
        return prefix == 0xef0100;
    }

    function _requireProbeParameterId(bytes32 parameterId, address probe) private view {
        (bool ok, bytes memory data) = _boundedStaticRead(
            probe, abi.encodeWithSelector(IStreamGasParameterProbe.probedParameterId.selector), 32
        );
        if (!ok || data.length != 32 || abi.decode(data, (bytes32)) != parameterId) {
            revert GasParameterProbeMismatch(parameterId, probe);
        }
    }

    function _boundedStaticRead(address target, bytes memory callData, uint256 maxReturnBytes)
        private
        view
        returns (bool success, bytes memory returnData)
    {
        assembly ("memory-safe") {
            success := staticcall(gas(), target, add(callData, 0x20), mload(callData), 0x00, 0x00)
            let returnSize := returndatasize()
            switch and(success, iszero(gt(returnSize, maxReturnBytes)))
            case 0 {
                success := 0
                returnData := mload(0x40)
                mstore(returnData, 0)
                mstore(0x40, add(returnData, 0x20))
            }
            default {
                returnData := mload(0x40)
                mstore(returnData, returnSize)
                returndatacopy(add(returnData, 0x20), 0x00, returnSize)
                mstore(0x40, and(add(add(returnData, 0x20), add(returnSize, 0x1f)), not(0x1f)))
            }
        }
    }

    function _supportsModuleRegistryInterface(address registry) private view returns (bool) {
        (bool requiredOk, bytes memory requiredData) = _boundedStaticRead(
            registry,
            abi.encodeWithSelector(
                _SUPPORTS_INTERFACE_SELECTOR, type(IStreamModuleRegistry).interfaceId
            ),
            32
        );
        if (!requiredOk || requiredData.length != 32 || abi.decode(requiredData, (uint256)) != 1) {
            return false;
        }
        (bool invalidOk, bytes memory invalidData) = _boundedStaticRead(
            registry, abi.encodeWithSelector(_SUPPORTS_INTERFACE_SELECTOR, bytes4(0xffffffff)), 32
        );
        return invalidOk && invalidData.length == 32 && abi.decode(invalidData, (uint256)) == 0;
    }

    function _requireCurrentProbeBinding(bytes32 parameterId, GasParameterData storage parameter)
        private
        view
    {
        (bytes32 runtimeCodeHash, bytes32 bindingHash) =
            _resolveProbeBinding(parameterId, parameter.probe);
        if (
            runtimeCodeHash != parameter.probeRuntimeCodeHash
                || bindingHash != parameter.probeBindingHash
        ) {
            revert GasParameterProbeBindingInvalid(parameterId, parameter.probe);
        }
    }

    /// @dev Emergency/conditional raise gate: a recorded failing run at the current
    ///      value, no older than `probeMaxAgeBlocks`, through the probe bound at
    ///      registration ([LTA-GGP] requirement 1).
    function _requireFreshFailingRunAtCurrent(
        bytes32 parameterId,
        GasParameterData storage parameter
    ) private view {
        _requireCurrentProbeBinding(parameterId, parameter);
        uint256 currentValue = parameter.value;
        (bytes32 probeRunId, bool passed, uint64 probedAtBlock) =
            IStreamGasParameterProbe(parameter.probe).lastProbeRun(parameterId, currentValue);
        if (probeRunId == bytes32(0)) {
            revert GasParameterProbeRecordMissing(parameterId, currentValue);
        }
        if (
            probedAtBlock > block.number
                || block.number - probedAtBlock > parameter.probeMaxAgeBlocks
        ) {
            revert GasParameterProbeRecordStale(
                parameterId, currentValue, probedAtBlock, parameter.probeMaxAgeBlocks
            );
        }
        if (passed) {
            revert GasParameterProbeHealthy(parameterId, currentValue);
        }
    }

    /// @dev Lower/re-lower gate: a recorded passing run at exactly the proposed
    ///      value, no older than `probeMaxAgeBlocks` ([LTA-GGP] requirement 2).
    function _requireFreshPassingRunAtExactValue(
        bytes32 parameterId,
        GasParameterData storage parameter,
        uint256 proposedValue
    ) private view {
        _requireCurrentProbeBinding(parameterId, parameter);
        (bytes32 probeRunId, bool passed, uint64 probedAtBlock) =
            IStreamGasParameterProbe(parameter.probe).lastProbeRun(parameterId, proposedValue);
        if (probeRunId == bytes32(0)) {
            revert GasParameterProbeRecordMissing(parameterId, proposedValue);
        }
        if (
            probedAtBlock > block.number
                || block.number - probedAtBlock > parameter.probeMaxAgeBlocks
        ) {
            revert GasParameterProbeRecordStale(
                parameterId, proposedValue, probedAtBlock, parameter.probeMaxAgeBlocks
            );
        }
        if (!passed) {
            revert GasParameterProbeNotPassing(parameterId, proposedValue);
        }
    }

    function _setGovernedValue(
        bytes32 parameterId,
        GasParameterData storage parameter,
        uint256 newValue,
        uint8 actionClass
    ) private {
        uint64 nextRevision = _nextRevision(parameterId, parameter.revision);
        bytes32 scopeHash = _scopeHash(parameterId);
        bytes32 oldStateHash = _stateHash(scopeHash, parameter);
        bytes32 newStateHash = _stateHash(
            scopeHash,
            parameter,
            newValue,
            parameter.probe,
            parameter.probeRuntimeCodeHash,
            parameter.probeBindingHash,
            nextRevision
        );
        bytes32 actionId =
            _requireGovernanceContext(actionClass, scopeHash, oldStateHash, newStateHash);
        _writeValue(parameterId, parameter, newValue, nextRevision, actionId);
    }

    function _setValue(
        bytes32 parameterId,
        GasParameterData storage parameter,
        uint256 newValue,
        bytes32 actionId
    ) private {
        uint64 nextRevision = _nextRevision(parameterId, parameter.revision);
        _writeValue(parameterId, parameter, newValue, nextRevision, actionId);
    }

    function _writeValue(
        bytes32 parameterId,
        GasParameterData storage parameter,
        uint256 newValue,
        uint64 nextRevision,
        bytes32 actionId
    ) private {
        uint256 oldValue = parameter.value;
        parameter.value = newValue;
        parameter.revision = nextRevision;
        emit GasParameterUpdated(
            GAS_PARAMETER_SCHEMA_VERSION,
            parameterId,
            address(this),
            actionId,
            oldValue,
            newValue,
            parameter.floor
        );
    }
}
