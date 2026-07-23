// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamTimeParameterHost.sol";
import "./IStreamTimeParameterProbe.sol";
import "./IStreamGovernedParameterAuthority.sol";
import { IStreamModuleRegistry } from "./IStreamModuleRegistry.sol";

/// @notice Reusable Governed Time Parameter host machinery per
///         `docs/stream-long-term-architecture.md` [LTA-GTP]. Hosts of
///         block-denominated liveness windows (the entropy coordinator's
///         `ENTROPY_REQUEST_TIMEOUT_BLOCKS`, `ENTROPY_REVEAL_SLO_BLOCKS`, and
///         `ENTROPY_RECOVERY_STEP_DELAY_BLOCKS` genesis rows) embed this base;
///         standalone stores deploy `StreamTimeParameterStore`.
/// @dev    Change discipline pins ([LTA-GTP] change discipline 1-4):
///         - every change is governance-only through the canonical action
///           executor seam — by construction this contract has no emergency path
///           and no permissionless conditional raise or re-lower (the
///           lost-governance machinery exists for `FORWARDING_CAP` gas reads
///           only, ADR 0012 decision T1);
///         - raises are bounded to at most 2x current per action, lowers to no
///           less than half current per action, and lowers revert below the
///           immutable block floor;
///         - a lower's execution recheck verifies through the bound cadence probe
///           a recorded passing run at exactly the proposed value within
///           `probeMaxAgeBlocks`, proving the proposed count still covers the
///           parameter's pinned wall-clock floor at the observed cadence — the
///           wall-clock floor thereby binds in both directions (change
///           discipline 7);
///         - `timeParameterInfo` is the canonical host introspection read
///           (definition item 7).
abstract contract StreamTimeParameterHost is IStreamTimeParameterHost {
    /// @notice Schema version carried by every canonical GTP event.
    uint16 public constant TIME_PARAMETER_SCHEMA_VERSION = 1;

    /// @notice Planning floor for `probeMaxAgeBlocks` — cadence probes are
    ///         [LTA-GGP-PROBES] members and inherit rule 6's floor.
    uint64 public constant PROBE_MAX_AGE_FLOOR_BLOCKS = 50_400;

    /// @dev Governance-V2 action classes pinned by ADR 0004.
    uint8 private constant _ACTION_CLASS_DELAYED_LOOSENING = 1;
    uint8 private constant _ACTION_CLASS_POINTER_REPLACEMENT = 3;

    /// @dev Exact [LTA-GTP] scope/state domains and shared authenticated probe
    ///      binding facts. These values are catalog-pinned protocol constants.
    bytes32 private constant _TIME_PARAMETER_SCOPE_V1 =
        0xcb90eddcfa663732d90ca0d1892636ba1216e3900df55acc72d58187eee359a8;
    bytes32 private constant _TIME_PARAMETER_STATE_V1 =
        0x2cdcb8724d05b4fa9d1ad4f857f9c5fa49ca997d15870fe7f9df6fbae1402583;
    bytes32 private constant _GGP_PROBE_BINDING_V1 =
        0x4efb354b2a3c37f3c74fe57912e40eb08d83026611be9740d785f348cc2332c4;
    bytes32 private constant _TIME_PARAMETER_PROBE_MODULE_TYPE =
        0x3199d2e98228ed2205303455974f594fcf19602b1f986e0687c568d9925d2ee4;
    bytes4 private constant _TIME_PARAMETER_PROBE_INTERFACE_ID = 0xb6c57592;
    bytes4 private constant _SUPPORTS_INTERFACE_SELECTOR = 0x01ffc9a7;
    bytes4 private constant _GET_SATELLITE_POINTER_SELECTOR = 0x3528d53c;
    bytes32 private constant _MODULE_REGISTRY_POINTER_TYPE =
        0xde86dd5f33a5b2bd22cfbe7752609f5086a946f705768f7e2e6cb501157a41c4;

    uint256 private constant _CORE_POINTER_RETURN_BYTES = 320;
    uint256 private constant _MAX_MODULE_RECORD_RETURN_BYTES = 2_496;
    uint256 private constant _MAX_MODULE_MANIFEST_URI_BYTES = 2_048;
    uint8 private constant _MODULE_STATUS_ACTIVE = 1;

    struct TimeParameterData {
        uint256 value;
        uint256 floorBlocks;
        uint64 wallClockFloorSeconds;
        address cadenceProbe;
        uint64 probeMaxAgeBlocks;
        uint64 revision;
        bytes32 probeRuntimeCodeHash;
        bytes32 probeBindingHash;
    }

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

    /// @inheritdoc IStreamTimeParameterHost
    address public immutable override governanceAuthority;

    address private immutable _coreRegistrySource;
    address private immutable _genesisModuleRegistry;

    mapping(bytes32 => TimeParameterData) private _timeParameters;
    bytes32[] private _timeParameterIds;

    /// @param authority The canonical governance action executor
    ///        (`IStreamGovernedParameterAuthority` wiring seam), or address(0) for
    ///        a host with no governance whose change paths permanently revert.
    /// @param core_ The immutable, already deployed external Core address that
    ///        owns the live canonical `MODULE_REGISTRY` pointer.
    /// @param genesisModuleRegistry_ The code-bearing genesis registry committed
    ///        into every constructor-time expected cadence-probe binding.
    constructor(address authority, address core_, address genesisModuleRegistry_) {
        if (core_ == address(0) || core_.code.length == 0 || _isEip7702DelegatedEOA(core_)) {
            revert TimeParameterInvalidCore(core_);
        }
        if (
            genesisModuleRegistry_ == address(0) || genesisModuleRegistry_.code.length == 0
                || _isEip7702DelegatedEOA(genesisModuleRegistry_)
                || !_supportsModuleRegistryInterface(genesisModuleRegistry_)
        ) {
            revert TimeParameterInvalidModuleRegistry(genesisModuleRegistry_);
        }
        if (authority != address(0)) {
            if (
                _isEip7702DelegatedEOA(authority)
                    || !IStreamGovernedParameterAuthority(authority)
                        .isStreamGovernedParameterAuthority()
            ) {
                revert TimeParameterInvalidAuthority(authority);
            }
        }
        governanceAuthority = authority;
        _coreRegistrySource = core_;
        _genesisModuleRegistry = genesisModuleRegistry_;
    }

    // ---------------------------------------------------------------------
    // Registration (deployment-time only)
    // ---------------------------------------------------------------------

    /// @dev Registers one Governed Time Parameter. Callable only from constructors
    ///      of embedding hosts; the parameter set, both floors, the cadence-probe
    ///      binding, and the recency bound are fixed at deployment ([LTA-GTP]
    ///      definition items 1-3 and 6).
    function _registerTimeParameter(TimeParameterConfig memory config)
        internal
        returns (bytes32 parameterId)
    {
        if (bytes(config.name).length == 0) {
            revert TimeParameterInvalidConfig(bytes32(0));
        }
        parameterId = keccak256(abi.encodePacked("6529STREAM_GTP_", config.name));

        TimeParameterData storage parameter = _timeParameters[parameterId];
        if (parameter.cadenceProbe != address(0)) {
            revert TimeParameterAlreadyRegistered(parameterId);
        }
        if (
            config.floorBlocks == 0 || config.genesisValue < config.floorBlocks
                || config.wallClockFloorSeconds == 0
                || config.probeMaxAgeBlocks < PROBE_MAX_AGE_FLOOR_BLOCKS
                || config.expectedProbeModuleVersion == bytes32(0)
                || config.expectedProbeRuntimeCodeHash == bytes32(0)
                || config.expectedProbeModuleManifestHash == bytes32(0)
                || config.expectedProbeDeploymentManifestHash == bytes32(0)
        ) {
            revert TimeParameterInvalidConfig(parameterId);
        }
        if (config.cadenceProbe == address(0)) {
            revert TimeParameterProbeMismatch(parameterId, config.cadenceProbe);
        }
        (bytes32 probeRuntimeCodeHash, bytes32 probeBindingHash) =
            _expectedGenesisProbeBinding(parameterId, config);

        parameter.value = config.genesisValue;
        parameter.floorBlocks = config.floorBlocks;
        parameter.wallClockFloorSeconds = config.wallClockFloorSeconds;
        parameter.cadenceProbe = config.cadenceProbe;
        parameter.probeMaxAgeBlocks = config.probeMaxAgeBlocks;
        parameter.revision = 1;
        parameter.probeRuntimeCodeHash = probeRuntimeCodeHash;
        parameter.probeBindingHash = probeBindingHash;

        _timeParameterIds.push(parameterId);

        emit TimeParameterRegistered(
            TIME_PARAMETER_SCHEMA_VERSION,
            parameterId,
            config.name,
            config.genesisValue,
            config.floorBlocks,
            config.wallClockFloorSeconds,
            config.cadenceProbe,
            config.probeMaxAgeBlocks
        );
    }

    // ---------------------------------------------------------------------
    // Introspection ([LTA-GTP] definition item 7)
    // ---------------------------------------------------------------------

    /// @inheritdoc IStreamTimeParameterHost
    function timeParameterInfo(bytes32 parameterId)
        external
        view
        override
        returns (
            uint256 value,
            uint256 floorBlocks,
            uint64 wallClockFloorSeconds,
            address cadenceProbe,
            uint64 probeMaxAgeBlocks,
            uint64 revision
        )
    {
        TimeParameterData storage parameter = _timeParameters[parameterId];
        return (
            parameter.value,
            parameter.floorBlocks,
            parameter.wallClockFloorSeconds,
            parameter.cadenceProbe,
            parameter.probeMaxAgeBlocks,
            parameter.revision
        );
    }

    /// @inheritdoc IStreamTimeParameterHost
    function timeParameter(bytes32 parameterId) public view override returns (uint256 value) {
        TimeParameterData storage parameter = _timeParameters[parameterId];
        if (parameter.cadenceProbe == address(0)) {
            revert TimeParameterUnknown(parameterId);
        }
        return parameter.value;
    }

    /// @inheritdoc IStreamTimeParameterHost
    function timeParameterIds() external view override returns (bytes32[] memory) {
        return _timeParameterIds;
    }

    /// @inheritdoc IStreamTimeParameterHost
    function moduleRegistry() public view override returns (address) {
        return _liveModuleRegistry();
    }

    // ---------------------------------------------------------------------
    // Governed change paths (the only change paths — [LTA-GTP] discipline 1)
    // ---------------------------------------------------------------------

    /// @inheritdoc IStreamTimeParameterHost
    function raiseTimeParameter(bytes32 parameterId, uint256 newValue) external override {
        _requireAuthority();
        TimeParameterData storage parameter = _requireRegistered(parameterId);
        uint256 currentValue = parameter.value;
        if (newValue <= currentValue) {
            revert TimeParameterNotARaise(parameterId, currentValue, newValue);
        }
        if (newValue - currentValue > currentValue) {
            revert TimeParameterRaiseBoundExceeded(parameterId, currentValue, newValue);
        }
        uint64 newRevision = _nextRevision(parameterId, parameter.revision);
        bytes32 scopeHash = _timeParameterScopeHash(parameterId);
        bytes32 oldStateHash = _timeParameterStateHash(
            scopeHash,
            parameter,
            currentValue,
            parameter.cadenceProbe,
            parameter.probeRuntimeCodeHash,
            parameter.probeBindingHash,
            parameter.revision
        );
        bytes32 newStateHash = _timeParameterStateHash(
            scopeHash,
            parameter,
            newValue,
            parameter.cadenceProbe,
            parameter.probeRuntimeCodeHash,
            parameter.probeBindingHash,
            newRevision
        );
        bytes32 actionId = _requireGovernanceContext(
            _ACTION_CLASS_DELAYED_LOOSENING, scopeHash, oldStateHash, newStateHash
        );
        _setValue(parameterId, parameter, newValue, newRevision, actionId);
    }

    /// @inheritdoc IStreamTimeParameterHost
    function lowerTimeParameter(bytes32 parameterId, uint256 newValue) external override {
        _requireAuthority();
        TimeParameterData storage parameter = _requireRegistered(parameterId);
        uint256 currentValue = parameter.value;
        if (newValue >= currentValue) {
            revert TimeParameterNotALower(parameterId, currentValue, newValue);
        }
        // No less than half the current value per action
        // (newValue >= currentValue - newValue avoids overflow).
        if (newValue < currentValue - newValue) {
            revert TimeParameterLowerBoundExceeded(parameterId, currentValue, newValue);
        }
        if (newValue < parameter.floorBlocks) {
            revert TimeParameterBelowFloor(parameterId, newValue, parameter.floorBlocks);
        }
        _requireLiveProbeBinding(parameterId, parameter);
        _requireFreshPassingCadenceRun(parameterId, parameter, newValue);
        uint64 newRevision = _nextRevision(parameterId, parameter.revision);
        bytes32 scopeHash = _timeParameterScopeHash(parameterId);
        bytes32 oldStateHash = _timeParameterStateHash(
            scopeHash,
            parameter,
            currentValue,
            parameter.cadenceProbe,
            parameter.probeRuntimeCodeHash,
            parameter.probeBindingHash,
            parameter.revision
        );
        bytes32 newStateHash = _timeParameterStateHash(
            scopeHash,
            parameter,
            newValue,
            parameter.cadenceProbe,
            parameter.probeRuntimeCodeHash,
            parameter.probeBindingHash,
            newRevision
        );
        bytes32 actionId = _requireGovernanceContext(
            _ACTION_CLASS_DELAYED_LOOSENING, scopeHash, oldStateHash, newStateHash
        );
        _setValue(parameterId, parameter, newValue, newRevision, actionId);
    }

    /// @inheritdoc IStreamTimeParameterHost
    function rebindTimeParameterProbe(bytes32 parameterId, address newCadenceProbe)
        external
        override
    {
        // [LTA-GGP-PROBES] rule 3 (cadence probes are members of that rule set):
        // while governance functions, the binding may move to a successor
        // Permanent-class probe through pointer-replacement class 3. Its exact
        // target/selector is a [GOV-MANIFEST-TAIL] trigger; with governance lost
        // (zero authority) this path is dead and the binding is frozen.
        _requireAuthority();
        TimeParameterData storage parameter = _requireRegistered(parameterId);
        if (newCadenceProbe == address(0)) {
            revert TimeParameterProbeMismatch(parameterId, newCadenceProbe);
        }
        (bytes32 newProbeRuntimeCodeHash, bytes32 newProbeBindingHash) =
            _resolveProbeBinding(parameterId, newCadenceProbe, parameter.wallClockFloorSeconds);
        if (
            newCadenceProbe == parameter.cadenceProbe
                && newProbeRuntimeCodeHash == parameter.probeRuntimeCodeHash
                && newProbeBindingHash == parameter.probeBindingHash
        ) {
            revert TimeParameterProbeRebindNoOp(parameterId, newCadenceProbe);
        }

        uint64 newRevision = _nextRevision(parameterId, parameter.revision);
        bytes32 scopeHash = _timeParameterScopeHash(parameterId);
        bytes32 oldStateHash = _timeParameterStateHash(
            scopeHash,
            parameter,
            parameter.value,
            parameter.cadenceProbe,
            parameter.probeRuntimeCodeHash,
            parameter.probeBindingHash,
            parameter.revision
        );
        bytes32 newStateHash = _timeParameterStateHash(
            scopeHash,
            parameter,
            parameter.value,
            newCadenceProbe,
            newProbeRuntimeCodeHash,
            newProbeBindingHash,
            newRevision
        );
        bytes32 actionId = _requireGovernanceContext(
            _ACTION_CLASS_POINTER_REPLACEMENT, scopeHash, oldStateHash, newStateHash
        );
        address oldCadenceProbe = parameter.cadenceProbe;
        parameter.cadenceProbe = newCadenceProbe;
        parameter.probeRuntimeCodeHash = newProbeRuntimeCodeHash;
        parameter.probeBindingHash = newProbeBindingHash;
        parameter.revision = newRevision;
        emit TimeParameterProbeRebound(
            TIME_PARAMETER_SCHEMA_VERSION,
            parameterId,
            address(this),
            actionId,
            oldCadenceProbe,
            newCadenceProbe
        );
    }

    // ---------------------------------------------------------------------
    // Internal helpers
    // ---------------------------------------------------------------------

    /// @dev Live window read for embedding hosts' liveness/recovery gates.
    function _timeParameterValue(bytes32 parameterId) internal view returns (uint256) {
        return timeParameter(parameterId);
    }

    function _requireAuthority() private view {
        if (governanceAuthority == address(0) || msg.sender != governanceAuthority) {
            revert TimeParameterNotAuthority(msg.sender);
        }
    }

    function _requireRegistered(bytes32 parameterId)
        private
        view
        returns (TimeParameterData storage parameter)
    {
        parameter = _timeParameters[parameterId];
        if (parameter.cadenceProbe == address(0)) {
            revert TimeParameterUnknown(parameterId);
        }
    }

    function _expectedGenesisProbeBinding(bytes32 parameterId, TimeParameterConfig memory config)
        private
        view
        returns (bytes32 runtimeCodeHash, bytes32 bindingHash)
    {
        address cadenceProbe = config.cadenceProbe;
        if (cadenceProbe == address(0)) {
            revert TimeParameterProbeMismatch(parameterId, cadenceProbe);
        }
        runtimeCodeHash = config.expectedProbeRuntimeCodeHash;
        if (cadenceProbe.code.length != 0) {
            if (_isEip7702DelegatedEOA(cadenceProbe) || cadenceProbe.codehash != runtimeCodeHash) {
                revert TimeParameterProbeBindingInvalid(parameterId, cadenceProbe);
            }
            _requireProbeFloor(parameterId, cadenceProbe, config.wallClockFloorSeconds);
        }

        bindingHash = keccak256(
            abi.encode(
                _GGP_PROBE_BINDING_V1,
                _genesisModuleRegistry,
                cadenceProbe,
                _TIME_PARAMETER_PROBE_MODULE_TYPE,
                _TIME_PARAMETER_PROBE_INTERFACE_ID,
                config.expectedProbeModuleVersion,
                runtimeCodeHash,
                config.expectedProbeModuleManifestHash,
                config.expectedProbeDeploymentManifestHash
            )
        );
    }

    function _resolveProbeBinding(
        bytes32 parameterId,
        address cadenceProbe,
        uint64 wallClockFloorSeconds
    ) private view returns (bytes32 runtimeCodeHash, bytes32 bindingHash) {
        if (cadenceProbe == address(0)) {
            revert TimeParameterProbeMismatch(parameterId, cadenceProbe);
        }
        if (cadenceProbe.code.length == 0 || _isEip7702DelegatedEOA(cadenceProbe)) {
            revert TimeParameterProbeBindingInvalid(parameterId, cadenceProbe);
        }

        address liveRegistry = _liveModuleRegistry();
        ModuleRecordV2 memory record = _moduleRecord(liveRegistry, parameterId, cadenceProbe);
        runtimeCodeHash = cadenceProbe.codehash;
        if (
            record.status != _MODULE_STATUS_ACTIVE
                || record.moduleType != _TIME_PARAMETER_PROBE_MODULE_TYPE
                || record.interfaceId != _TIME_PARAMETER_PROBE_INTERFACE_ID
                || record.moduleVersion == bytes32(0) || record.runtimeCodeHash == bytes32(0)
                || record.runtimeCodeHash != runtimeCodeHash
                || record.moduleManifestHash == bytes32(0)
                || record.deploymentManifestHash == bytes32(0) || record.revision == 0
        ) {
            revert TimeParameterProbeBindingInvalid(parameterId, cadenceProbe);
        }

        _requireProbeFloor(parameterId, cadenceProbe, wallClockFloorSeconds);

        bindingHash = keccak256(
            abi.encode(
                _GGP_PROBE_BINDING_V1,
                liveRegistry,
                cadenceProbe,
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
            revert TimeParameterLiveModuleRegistryInvalid(_coreRegistrySource);
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
            revert TimeParameterLiveModuleRegistryInvalid(_coreRegistrySource);
        }
        return facts.target;
    }

    function _moduleRecord(address liveRegistry, bytes32 parameterId, address cadenceProbe)
        private
        view
        returns (ModuleRecordV2 memory record)
    {
        (bool ok, bytes memory data) = _boundedStaticRead(
            liveRegistry,
            abi.encodeWithSelector(IStreamModuleRegistry.moduleRecord.selector, cadenceProbe),
            _MAX_MODULE_RECORD_RETURN_BYTES
        );
        if (!ok || !_isCanonicalModuleRecordEncoding(data)) {
            revert TimeParameterProbeBindingInvalid(parameterId, cadenceProbe);
        }
        record = abi.decode(data, (ModuleRecordV2));
        if (
            keccak256(data) != keccak256(abi.encode(record))
                || bytes(record.moduleManifestURI).length == 0
                || bytes(record.moduleManifestURI).length > _MAX_MODULE_MANIFEST_URI_BYTES
        ) {
            revert TimeParameterProbeBindingInvalid(parameterId, cadenceProbe);
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

    function _requireProbeFloor(
        bytes32 parameterId,
        address cadenceProbe,
        uint64 wallClockFloorSeconds
    ) private view {
        (bool ok, bytes memory data) = _boundedStaticRead(
            cadenceProbe,
            abi.encodeWithSelector(
                IStreamTimeParameterProbe.pinnedWallClockFloorSeconds.selector, parameterId
            ),
            32
        );
        if (!ok || data.length != 32) {
            revert TimeParameterProbeMismatch(parameterId, cadenceProbe);
        }
        uint256 encodedFloor = abi.decode(data, (uint256));
        if (encodedFloor > type(uint64).max) {
            revert TimeParameterProbeMismatch(parameterId, cadenceProbe);
        }
        uint64 pinnedWallClockFloorSeconds = abi.decode(data, (uint64));
        if (
            keccak256(data) != keccak256(abi.encode(pinnedWallClockFloorSeconds))
                || pinnedWallClockFloorSeconds != wallClockFloorSeconds
        ) {
            revert TimeParameterProbeMismatch(parameterId, cadenceProbe);
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

    function _requireLiveProbeBinding(bytes32 parameterId, TimeParameterData storage parameter)
        private
        view
    {
        (bytes32 runtimeCodeHash, bytes32 bindingHash) = _resolveProbeBinding(
            parameterId, parameter.cadenceProbe, parameter.wallClockFloorSeconds
        );
        if (
            runtimeCodeHash != parameter.probeRuntimeCodeHash
                || bindingHash != parameter.probeBindingHash
        ) {
            revert TimeParameterProbeBindingInvalid(parameterId, parameter.cadenceProbe);
        }
    }

    function _timeParameterScopeHash(bytes32 parameterId) private view returns (bytes32) {
        return keccak256(
            abi.encode(_TIME_PARAMETER_SCOPE_V1, block.chainid, address(this), parameterId)
        );
    }

    function _timeParameterStateHash(
        bytes32 scopeHash,
        TimeParameterData storage parameter,
        uint256 value,
        address cadenceProbe,
        bytes32 probeRuntimeCodeHash,
        bytes32 probeBindingHash,
        uint64 revision
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                _TIME_PARAMETER_STATE_V1,
                scopeHash,
                value,
                parameter.floorBlocks,
                parameter.wallClockFloorSeconds,
                cadenceProbe,
                probeRuntimeCodeHash,
                probeBindingHash,
                parameter.probeMaxAgeBlocks,
                revision
            )
        );
    }

    function _nextRevision(bytes32 parameterId, uint64 revision) private pure returns (uint64) {
        if (revision == type(uint64).max) {
            revert TimeParameterRevisionOverflow(parameterId);
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
        if (!executing) {
            revert TimeParameterActionNotExecuting();
        }
        if (currentActionId == bytes32(0)) {
            revert TimeParameterActionIdZero();
        }
        if (actionClass != expectedClass) {
            revert TimeParameterActionClassMismatch(expectedClass, actionClass);
        }
        if (scopeHash != expectedScopeHash) {
            revert TimeParameterScopeHashMismatch(expectedScopeHash, scopeHash);
        }
        if (oldStateHash != expectedOldStateHash) {
            revert TimeParameterOldStateHashMismatch(expectedOldStateHash, oldStateHash);
        }
        if (newStateHash != expectedNewStateHash) {
            revert TimeParameterNewStateHashMismatch(expectedNewStateHash, newStateHash);
        }
        return currentActionId;
    }

    /// @dev Lower gate ([LTA-GTP] change discipline 3): a recorded passing cadence
    ///      run at exactly the proposed value, no older than `probeMaxAgeBlocks`,
    ///      through the cadence probe bound at registration.
    function _requireFreshPassingCadenceRun(
        bytes32 parameterId,
        TimeParameterData storage parameter,
        uint256 proposedValue
    ) private view {
        (bytes32 probeRunId, bool passed, uint64 probedAtBlock) = IStreamTimeParameterProbe(
                parameter.cadenceProbe
            ).lastProbeRun(parameterId, proposedValue);
        if (probeRunId == bytes32(0)) {
            revert TimeParameterProbeRecordMissing(parameterId, proposedValue);
        }
        if (
            probedAtBlock > block.number
                || block.number - probedAtBlock > parameter.probeMaxAgeBlocks
        ) {
            revert TimeParameterProbeRecordStale(
                parameterId, proposedValue, probedAtBlock, parameter.probeMaxAgeBlocks
            );
        }
        if (!passed) {
            revert TimeParameterProbeNotPassing(parameterId, proposedValue);
        }
    }

    function _setValue(
        bytes32 parameterId,
        TimeParameterData storage parameter,
        uint256 newValue,
        uint64 newRevision,
        bytes32 actionId
    ) private {
        uint256 oldValue = parameter.value;
        parameter.value = newValue;
        parameter.revision = newRevision;
        emit TimeParameterUpdated(
            TIME_PARAMETER_SCHEMA_VERSION,
            parameterId,
            address(this),
            actionId,
            oldValue,
            newValue,
            parameter.floorBlocks
        );
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
}
