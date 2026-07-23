// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ERC165.sol";
import "./IERC165.sol";
import "./IStreamGovernanceExecutor.sol";
import "./IStreamModuleRegistry.sol";

/// @notice Canonical protocol v1 module registry implementing
///         `docs/stream-long-term-architecture.md` [LTA-REGISTRY]: append-only
///         enumeration (requirement 6), the registration record-chain lane
///         under [CMC-RECORD-CHAIN] (requirement 7), and governed lifecycle
///         changes through the staged governance executor (requirement 5).
/// @dev Successor of the superseded draft `StreamMintModuleRegistry` surface.
///     Every lifecycle mutation must arrive as a call from the governance
///     executor inside an executing action of the correct ADR 0004 class:
///     registration and status loosening require `DELAYED_LOOSENING`; status
///     tightening (deprecation, incident revocation) may execute under
///     `IMMEDIATE_TIGHTENING` or `DELAYED_LOOSENING`. Records are never
///     deleted; registering an already-known module reverts.
contract StreamModuleRegistry is ERC165, IStreamModuleRegistry {
    /// @notice Typed registration record domain ([LTA-REGISTRY] requirement 7;
    ///         pinned in [LTA-DOMAINS]).
    bytes32 public constant STREAM_MODULE_REGISTRATION_RECORD_V1 =
        keccak256("6529STREAM_MODULE_REGISTRATION_RECORD_V1");
    /// @notice Record-chain accumulator domain shared verbatim from
    ///         `docs/collection-metadata-contract.md` [CMC-RECORD-CHAIN].
    bytes32 public constant STREAM_RECORD_CHAIN_V1 = keccak256("6529STREAM_RECORD_CHAIN_V1");
    /// @notice Registration lane record type ([LTA-REGISTRY] requirement 7).
    bytes32 public constant MODULE_REGISTRATION_RECORD_TYPE = keccak256("MODULE_REGISTRATION");
    /// @notice Registration lane scope key ([CMC-RECORD-CHAIN] rule 5).
    uint256 public constant MODULE_REGISTRATION_SCOPE_KEY = 0;

    /// @notice Schema version carried by registry lifecycle events.
    uint16 public constant SCHEMA_VERSION = 1;
    /// @notice Reverts when a module address is invalid for registry policy.
    error InvalidModule(address module);
    /// @notice Reverts when registration facts are incomplete or unsupported.
    error InvalidModuleRecord(address module);
    /// @notice Reverts when registering an already-known module
    ///         ([LTA-REGISTRY] requirement 6: the index is append-only).
    error ModuleAlreadyRegistered(address module);
    /// @notice Reverts when mutating lifecycle state of an unregistered module.
    error ModuleNotRegistered(address module);
    /// @notice Reverts when a module does not advertise the declared interface.
    error ModuleInterfaceUnsupported(address module, bytes4 interfaceId);
    /// @notice Reverts when a module's codehash differs from a supplied pin.
    error ModuleCodehashMismatch(address module, bytes32 expected, bytes32 actual);
    /// @notice Reverts when a status transition is not in the pinned machine.
    error InvalidStatusTransition(
        address module, ModuleRegistryStatus current, ModuleRegistryStatus requested
    );
    /// @notice Reverts when the caller is not the governance executor.
    error NotGovernanceExecutor(address caller);
    /// @notice Reverts when the executor is not executing a governed action.
    error NoExecutingGovernanceAction();
    /// @notice Reverts when the executing action class does not authorize the
    ///         lifecycle change ([LTA-REGISTRY] requirement 5).
    error WrongGovernanceActionClass(uint8 actionClass);
    /// @notice Reverts when an enumeration index is out of bounds.
    error ModuleIndexOutOfBounds(uint256 index);
    /// @notice Reverts when constructed with a zero governance executor.
    error ZeroGovernanceExecutor();

    /// @notice Emitted when the registry's own manifest commitment changes.
    event StreamModuleRegistryManifestUpdated(
        uint16 schemaVersion, bytes32 manifestHash, string manifestURI
    );

    /// @notice Staged governance executor gating every lifecycle mutation.
    IStreamGovernanceExecutor public immutable governanceExecutor;

    mapping(address => StreamModuleRecord) private _records;
    address[] private _modules;
    bytes32 private _registrationChainHash;
    uint64 private _registrationRecordCount;
    bytes32 private _manifestHash;
    string private _manifestURI;

    constructor(
        IStreamGovernanceExecutor governanceExecutor_,
        bytes32 manifestHash_,
        string memory manifestURI_
    ) {
        if (address(governanceExecutor_) == address(0)) {
            revert ZeroGovernanceExecutor();
        }
        governanceExecutor = governanceExecutor_;
        _manifestHash = manifestHash_;
        _manifestURI = manifestURI_;
    }

    /// @notice Registers a new module under a `DELAYED_LOOSENING` governed
    ///         action; append-only, so a known module address reverts
    ///         ([LTA-REGISTRY] requirements 5-7).
    function registerModule(StreamModuleRegistration calldata registration) external {
        _checkGovernedClass(true);
        address module = registration.module;
        if (module == address(0) || module.code.length == 0) {
            revert InvalidModule(module);
        }
        if (_records[module].status != ModuleRegistryStatus.UNKNOWN) {
            revert ModuleAlreadyRegistered(module);
        }
        if (
            registration.moduleType == bytes32(0) || registration.moduleVersion == bytes32(0)
                || registration.moduleManifestHash == bytes32(0)
        ) {
            revert InvalidModuleRecord(module);
        }
        if (registration.interfaceId == bytes4(0) || registration.interfaceId == 0xffffffff) {
            revert InvalidModuleRecord(module);
        }
        // FIX D: governance reads the live codehash before scheduling and pins
        // it in the action at review time; execution-time pinning is mandatory,
        // so a zero pin (accept whatever code is live at execution) is rejected.
        if (registration.expectedRuntimeCodeHash == bytes32(0)) {
            revert InvalidModuleRecord(module);
        }
        if (!_supportsInterface(module, registration.interfaceId)) {
            revert ModuleInterfaceUnsupported(module, registration.interfaceId);
        }
        bytes32 runtimeCodeHash = module.codehash;
        if (registration.expectedRuntimeCodeHash != runtimeCodeHash) {
            revert ModuleCodehashMismatch(
                module, registration.expectedRuntimeCodeHash, runtimeCodeHash
            );
        }

        StreamModuleRecord storage record = _records[module];
        record.status = ModuleRegistryStatus.ACTIVE;
        record.moduleType = registration.moduleType;
        record.moduleVersion = registration.moduleVersion;
        record.interfaceId = registration.interfaceId;
        record.moduleGasLimit = registration.moduleGasLimit;
        record.runtimeCodeHash = runtimeCodeHash;
        record.deploymentManifestHash = registration.deploymentManifestHash;
        record.moduleManifestHash = registration.moduleManifestHash;
        record.moduleManifestURI = registration.moduleManifestURI;
        record.registeredAt = uint64(block.timestamp);
        record.statusUpdatedAt = uint64(block.timestamp);

        // [LTA-REGISTRY] requirement 6: a registration appends exactly one entry.
        uint64 recordIndex = uint64(_modules.length);
        _modules.push(module);

        // [LTA-REGISTRY] requirement 7: the accumulator updates before
        // StreamModuleRegistered is emitted and the event carries the hash.
        bytes32 newChainHash = _appendRegistrationRecord(registration, runtimeCodeHash, recordIndex);

        emit StreamModuleRegistered(
            SCHEMA_VERSION,
            module,
            registration.moduleType,
            registration.interfaceId,
            registration.moduleVersion,
            registration.moduleGasLimit,
            runtimeCodeHash,
            registration.deploymentManifestHash,
            registration.moduleManifestHash,
            registration.moduleManifestURI,
            newChainHash
        );
    }

    /// @dev Chains the typed registration record hash into the requirement 7
    ///     accumulator lane (`scopeKey = 0`,
    ///     `recordType = keccak256("MODULE_REGISTRATION")`, `recordIndex` equal
    ///     to the requirement 6 enumeration index).
    function _appendRegistrationRecord(
        StreamModuleRegistration calldata registration,
        bytes32 runtimeCodeHash,
        uint64 recordIndex
    ) private returns (bytes32 newChainHash) {
        bytes32 recordHash = keccak256(
            abi.encode(
                STREAM_MODULE_REGISTRATION_RECORD_V1,
                registration.module,
                registration.moduleType,
                registration.interfaceId,
                registration.moduleVersion,
                runtimeCodeHash,
                registration.deploymentManifestHash,
                registration.moduleManifestHash
            )
        );
        newChainHash = keccak256(
            abi.encode(
                STREAM_RECORD_CHAIN_V1,
                uint256(block.chainid),
                address(this),
                MODULE_REGISTRATION_SCOPE_KEY,
                MODULE_REGISTRATION_RECORD_TYPE,
                _registrationChainHash,
                recordHash,
                recordIndex
            )
        );
        _registrationChainHash = newChainHash;
        _registrationRecordCount = recordIndex + 1;
    }

    /// @notice Changes a registered module's lifecycle status under governed
    ///         action-class rules; never edits or removes the record entry.
    function setModuleStatus(
        address module,
        ModuleRegistryStatus newStatus,
        bytes32 reasonHash,
        string calldata reasonURI
    ) external {
        StreamModuleRecord storage record = _records[module];
        if (record.status == ModuleRegistryStatus.UNKNOWN) {
            revert ModuleNotRegistered(module);
        }
        if (newStatus == ModuleRegistryStatus.UNKNOWN || newStatus == record.status) {
            revert InvalidStatusTransition(module, record.status, newStatus);
        }
        // Loosening moves toward less restriction (INCIDENT_REVOKED >
        // DEPRECATED > ACTIVE) and requires DELAYED_LOOSENING; tightening may
        // also ride a delayed action ([LTA-REGISTRY] requirement 5).
        _checkGovernedClass(_statusRank(newStatus) < _statusRank(record.status));
        record.status = newStatus;
        record.statusUpdatedAt = uint64(block.timestamp);
        emit StreamModuleStatusChanged(
            SCHEMA_VERSION, module, record.moduleType, newStatus, reasonHash, reasonURI
        );
    }

    /// @notice Updates the registry's own manifest commitment under a
    ///         `DELAYED_LOOSENING` governed action.
    function setModuleRegistryManifest(bytes32 manifestHash, string calldata manifestURI) external {
        _checkGovernedClass(true);
        _manifestHash = manifestHash;
        _manifestURI = manifestURI;
        emit StreamModuleRegistryManifestUpdated(SCHEMA_VERSION, manifestHash, manifestURI);
    }

    /// @inheritdoc IStreamModuleRegistry
    function moduleRecord(address module)
        external
        view
        override
        returns (StreamModuleRecord memory)
    {
        return _records[module];
    }

    /// @inheritdoc IStreamModuleRegistry
    function isModuleEligible(
        address module,
        bytes32 expectedModuleType,
        bytes4 expectedInterfaceId
    ) external view override returns (bool) {
        StreamModuleRecord storage record = _records[module];
        return record.status == ModuleRegistryStatus.ACTIVE
            && record.moduleType == expectedModuleType && record.interfaceId == expectedInterfaceId
            && module.codehash == record.runtimeCodeHash;
    }

    /// @inheritdoc IStreamModuleRegistry
    function moduleRegistryManifest()
        external
        view
        override
        returns (bytes32 manifestHash, string memory manifestURI)
    {
        return (_manifestHash, _manifestURI);
    }

    /// @inheritdoc IStreamModuleRegistry
    function moduleCount() external view override returns (uint256) {
        return _modules.length;
    }

    /// @inheritdoc IStreamModuleRegistry
    function moduleAt(uint256 index) external view override returns (address module) {
        if (index >= _modules.length) {
            revert ModuleIndexOutOfBounds(index);
        }
        return _modules[index];
    }

    /// @inheritdoc IStreamModuleRegistry
    function registrationChainHash()
        external
        view
        override
        returns (bytes32 chainHash, uint64 recordCount)
    {
        return (_registrationChainHash, _registrationRecordCount);
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IStreamModuleRegistry).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /// @dev Requires the call to arrive from the governance executor inside an
    ///     executing action whose class authorizes the mutation. Loosening
    ///     requires `DELAYED_LOOSENING`; tightening accepts
    ///     `IMMEDIATE_TIGHTENING` or `DELAYED_LOOSENING`.
    function _checkGovernedClass(bool loosening) private view {
        if (msg.sender != address(governanceExecutor)) {
            revert NotGovernanceExecutor(msg.sender);
        }
        (bool executing,, uint8 actionClass) = governanceExecutor.currentAction();
        if (!executing) {
            revert NoExecutingGovernanceAction();
        }
        if (loosening) {
            if (actionClass != StreamGovernanceActionClasses.DELAYED_LOOSENING) {
                revert WrongGovernanceActionClass(actionClass);
            }
        } else {
            if (
                actionClass != StreamGovernanceActionClasses.IMMEDIATE_TIGHTENING
                    && actionClass != StreamGovernanceActionClasses.DELAYED_LOOSENING
            ) {
                revert WrongGovernanceActionClass(actionClass);
            }
        }
    }

    function _statusRank(ModuleRegistryStatus status) private pure returns (uint8) {
        if (status == ModuleRegistryStatus.ACTIVE) {
            return 0;
        }
        if (status == ModuleRegistryStatus.DEPRECATED) {
            return 1;
        }
        return 2; // INCIDENT_REVOKED
    }

    /// @dev Forwards available gas so opcode repricing cannot strand governed
    ///      registration. Returndata is never allocated dynamically: only an
    ///      exact 32-byte canonical `true` is accepted, so every failure mode
    ///      leaves the registry unchanged.
    function _supportsInterface(address module, bytes4 interfaceId) private view returns (bool) {
        bytes memory payload = abi.encodeCall(IERC165.supportsInterface, (interfaceId));
        bool success;
        uint256 returnSize;
        uint256 raw;
        assembly ("memory-safe") {
            success := staticcall(gas(), module, add(payload, 0x20), mload(payload), 0, 0)
            returnSize := returndatasize()
            if and(success, eq(returnSize, 0x20)) {
                returndatacopy(0, 0, 0x20)
                raw := mload(0)
            }
        }
        return success && returnSize == 32 && raw == 1;
    }
}
