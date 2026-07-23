// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/IStreamGasParameterProbe.sol";
import "../../smart-contracts/IStreamGovernedParameterAuthority.sol";
import "../../smart-contracts/IStreamModuleRegistry.sol";
import "../../smart-contracts/IStreamTimeParameterProbe.sol";

/// @notice Minimal governance-executor stand-in for the wiring seam; the real
///         executor is built by the governance wave.
contract MockGovernedParameterAuthority is IStreamGovernedParameterAuthority {
    bool private immutable _valid;

    bool private _executing;
    bytes32 private _actionId;
    uint8 private _actionClass;
    bytes32 private _scopeHash;
    bytes32 private _oldValueHash;
    bytes32 private _newValueHash;

    constructor(bool valid) {
        _valid = valid;
    }

    function isStreamGovernedParameterAuthority() external view override returns (bool) {
        return _valid;
    }

    function setCurrentAction(
        bool executing,
        bytes32 actionId,
        uint8 actionClass,
        bytes32 scopeHash,
        bytes32 oldValueHash,
        bytes32 newValueHash
    ) external {
        _executing = executing;
        _actionId = actionId;
        _actionClass = actionClass;
        _scopeHash = scopeHash;
        _oldValueHash = oldValueHash;
        _newValueHash = newValueHash;
    }

    function clearCurrentAction() external {
        delete _executing;
        delete _actionId;
        delete _actionClass;
        delete _scopeHash;
        delete _oldValueHash;
        delete _newValueHash;
    }

    function currentAction()
        external
        view
        override
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return (_executing, _actionId, _actionClass, _scopeHash, _oldValueHash, _newValueHash);
    }
}

struct MockParameterModuleRecordV2 {
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

/// @notice Mutable Registry-V2 stand-in. It deliberately retains the V1
///         `moduleRecord(address)` selector while returning the revision-appended
///         V2 tuple expected by parameter hosts.
contract MockParameterModuleRegistry {
    bytes32 internal constant GGP_PROBE_MODULE_TYPE =
        0xe358a47f0dcbc7a22cc88ea7cd9ff433ec85ce6d9c7d0dc3f329e98b621cd6c8;
    bytes4 internal constant GGP_PROBE_INTERFACE_ID = 0x0f8c6b0f;
    bytes32 internal constant TIME_PARAMETER_PROBE_MODULE_TYPE =
        0x3199d2e98228ed2205303455974f594fcf19602b1f986e0687c568d9925d2ee4;
    bytes4 internal constant TIME_PARAMETER_PROBE_INTERFACE_ID = 0xb6c57592;

    mapping(address => MockParameterModuleRecordV2) private _records;
    address[] private _modules;
    bytes private _rawModuleRecordResponse;
    bool private _useRawModuleRecordResponse;
    bool private _unavailable;
    bytes private _rawInterfaceResponse;
    bool private _useRawInterfaceResponse;
    bool private _interfaceUnavailable;
    uint256 private _interfaceGasToBurn;

    function registerGasProbe(address probe) external {
        if (_records[probe].status == uint8(ModuleRegistryStatus.UNKNOWN)) {
            _modules.push(probe);
        }
        _records[probe] = MockParameterModuleRecordV2({
            status: uint8(ModuleRegistryStatus.ACTIVE),
            moduleType: GGP_PROBE_MODULE_TYPE,
            moduleVersion: bytes32(uint256(1)),
            interfaceId: GGP_PROBE_INTERFACE_ID,
            moduleGasLimit: 0,
            runtimeCodeHash: probe.codehash,
            deploymentManifestHash: keccak256(abi.encode("deployment", probe)),
            moduleManifestHash: keccak256(abi.encode("module", probe)),
            moduleManifestURI: "ipfs://mock-gas-probe",
            registeredAt: uint64(block.timestamp),
            statusUpdatedAt: uint64(block.timestamp),
            revision: 1
        });
    }

    function registerTimeProbe(address probe) external {
        if (_records[probe].status == uint8(ModuleRegistryStatus.UNKNOWN)) {
            _modules.push(probe);
        }
        _records[probe] = MockParameterModuleRecordV2({
            status: uint8(ModuleRegistryStatus.ACTIVE),
            moduleType: TIME_PARAMETER_PROBE_MODULE_TYPE,
            moduleVersion: bytes32(uint256(1)),
            interfaceId: TIME_PARAMETER_PROBE_INTERFACE_ID,
            moduleGasLimit: 0,
            runtimeCodeHash: probe.codehash,
            deploymentManifestHash: keccak256(abi.encode("deployment", probe)),
            moduleManifestHash: keccak256(abi.encode("module", probe)),
            moduleManifestURI: "ipfs://mock-time-probe",
            registeredAt: uint64(block.timestamp),
            statusUpdatedAt: uint64(block.timestamp),
            revision: 1
        });
    }

    function setStatus(address probe, ModuleRegistryStatus status) external {
        _records[probe].status = uint8(status);
    }

    function setRuntimeCodeHash(address probe, bytes32 runtimeCodeHash) external {
        _records[probe].runtimeCodeHash = runtimeCodeHash;
    }

    function setModuleType(address probe, bytes32 moduleType) external {
        _records[probe].moduleType = moduleType;
    }

    function setInterfaceId(address probe, bytes4 interfaceId) external {
        _records[probe].interfaceId = interfaceId;
    }

    function setModuleVersion(address probe, bytes32 moduleVersion) external {
        _records[probe].moduleVersion = moduleVersion;
    }

    function setManifestHashes(
        address probe,
        bytes32 moduleManifestHash,
        bytes32 deploymentManifestHash
    ) external {
        _records[probe].moduleManifestHash = moduleManifestHash;
        _records[probe].deploymentManifestHash = deploymentManifestHash;
    }

    function setRevision(address probe, uint64 revision) external {
        _records[probe].revision = revision;
    }

    function setModuleManifestURI(address probe, string calldata moduleManifestURI) external {
        _records[probe].moduleManifestURI = moduleManifestURI;
    }

    function setUnavailable(bool unavailable_) external {
        _unavailable = unavailable_;
    }

    function setRawModuleRecordResponse(bytes calldata response, bool enabled) external {
        _rawModuleRecordResponse = response;
        _useRawModuleRecordResponse = enabled;
    }

    function expectedGasProbeFacts(address probe)
        external
        view
        returns (
            bytes32 moduleVersion,
            bytes32 runtimeCodeHash,
            bytes32 moduleManifestHash,
            bytes32 deploymentManifestHash
        )
    {
        return (
            bytes32(uint256(1)),
            probe.codehash,
            keccak256(abi.encode("module", probe)),
            keccak256(abi.encode("deployment", probe))
        );
    }

    function expectedTimeProbeFacts(address probe)
        external
        view
        returns (
            bytes32 moduleVersion,
            bytes32 runtimeCodeHash,
            bytes32 moduleManifestHash,
            bytes32 deploymentManifestHash
        )
    {
        return (
            bytes32(uint256(1)),
            probe.codehash,
            keccak256(abi.encode("module", probe)),
            keccak256(abi.encode("deployment", probe))
        );
    }

    function moduleRecord(address module)
        external
        view
        returns (MockParameterModuleRecordV2 memory)
    {
        if (_unavailable) {
            revert("registry unavailable");
        }
        if (_useRawModuleRecordResponse) {
            bytes memory response = _rawModuleRecordResponse;
            assembly ("memory-safe") {
                return(add(response, 0x20), mload(response))
            }
        }
        return _records[module];
    }

    function isModuleEligible(
        address module,
        bytes32 expectedModuleType,
        bytes4 expectedInterfaceId
    ) external view returns (bool) {
        MockParameterModuleRecordV2 storage record = _records[module];
        return record.status == uint8(ModuleRegistryStatus.ACTIVE)
            && record.moduleType == expectedModuleType && record.interfaceId == expectedInterfaceId
            && record.runtimeCodeHash == module.codehash;
    }

    function moduleRegistryManifest()
        external
        pure
        returns (bytes32 manifestHash, string memory manifestURI, uint64 revision)
    {
        return (bytes32(uint256(1)), "ipfs://mock-registry", 1);
    }

    function moduleCount() external view returns (uint256) {
        return _modules.length;
    }

    function moduleAt(uint256 index) external view returns (address module) {
        return _modules[index];
    }

    function registrationChainHash() external view returns (bytes32 chainHash, uint64 recordCount) {
        return (keccak256(abi.encode(_modules)), uint64(_modules.length));
    }

    function setRawInterfaceResponse(bytes calldata response, bool enabled) external {
        _rawInterfaceResponse = response;
        _useRawInterfaceResponse = enabled;
    }

    function setInterfaceUnavailable(bool unavailable_) external {
        _interfaceUnavailable = unavailable_;
    }

    function setInterfaceGasToBurn(uint256 gasToBurn) external {
        _interfaceGasToBurn = gasToBurn;
    }

    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
        if (_interfaceUnavailable) revert("interface unavailable");
        _burnGas(_interfaceGasToBurn);
        if (_useRawInterfaceResponse) {
            bytes memory response = _rawInterfaceResponse;
            assembly ("memory-safe") {
                return(add(response, 0x20), mload(response))
            }
        }
        return interfaceId == type(IStreamModuleRegistry).interfaceId || interfaceId == 0x01ffc9a7;
    }

    function _burnGas(uint256 gasToBurn) private view {
        uint256 initialGas = gasleft();
        while (initialGas - gasleft() < gasToBurn) { }
    }
}

/// @notice Configurable Core pointer source. The getter is implemented through
///         fallback so tests can return malformed and overlong byte strings.
contract MockParameterCorePointer {
    bytes32 internal constant MODULE_REGISTRY_POINTER_TYPE =
        0xde86dd5f33a5b2bd22cfbe7752609f5086a946f705768f7e2e6cb501157a41c4;

    bytes private _pointerResponse;
    bool private _unavailable;

    function setLiveModuleRegistry(address target, address historicalRegistry) external {
        _pointerResponse = abi.encode(
            target,
            target.codehash,
            false,
            MODULE_REGISTRY_POINTER_TYPE,
            type(IStreamModuleRegistry).interfaceId,
            historicalRegistry,
            uint8(ModuleRegistryStatus.ACTIVE),
            keccak256("mock-registry-module-manifest"),
            keccak256("mock-registry-deployment-manifest"),
            uint64(1)
        );
    }

    function setRawPointerResponse(bytes calldata response) external {
        _pointerResponse = response;
    }

    function setUnavailable(bool unavailable_) external {
        _unavailable = unavailable_;
    }

    fallback() external {
        if (_unavailable) revert("core unavailable");
        bytes memory response = _pointerResponse;
        assembly ("memory-safe") {
            return(add(response, 0x20), mload(response))
        }
    }
}

/// @notice Probe stand-in with settable records, for exercising host-side gate
///         logic in isolation. Probe-side integrity is covered against the real
///         `StreamForwardingCapProbe`.
contract MockGasProbe is IStreamGasParameterProbe {
    struct Run {
        bytes32 probeRunId;
        bool passed;
        uint64 probedAtBlock;
    }

    bytes32 public immutable override probedParameterId;
    mapping(uint256 => Run) private _runs;
    uint256 private _nonce;

    constructor(string memory parameterName) {
        probedParameterId = keccak256(abi.encodePacked("6529STREAM_GGP_", parameterName));
    }

    function setRun(uint256 probedValue, bool passed, uint64 probedAtBlock) external {
        _nonce += 1;
        _runs[probedValue] = Run({
            probeRunId: keccak256(abi.encode(address(this), probedValue, passed, _nonce)),
            passed: passed,
            probedAtBlock: probedAtBlock
        });
    }

    function clearRun(uint256 probedValue) external {
        delete _runs[probedValue];
    }

    function lastProbeRun(bytes32 parameterId, uint256 probedValue)
        external
        view
        override
        returns (bytes32 probeRunId, bool passed, uint64 probedAtBlock)
    {
        if (parameterId != probedParameterId) {
            return (bytes32(0), false, 0);
        }
        Run storage run = _runs[probedValue];
        return (run.probeRunId, run.passed, run.probedAtBlock);
    }
}

    /// @notice Probe-record responder that can emit raw ABI edge cases while
    ///         retaining stable runtime code and registration bindings.
    contract MockAdversarialProbeRun is IStreamGasParameterProbe, IStreamTimeParameterProbe {
        enum ResponseMode {
            Canonical,
            Oversized,
            Short,
            NonCanonicalBool,
            NonCanonicalUint64,
            Reverting
        }

        bytes32 public immutable override probedParameterId;
        uint64 private immutable _wallClockFloorSeconds;

        ResponseMode private _responseMode;
        uint256 private _minimumReadGas;
        uint256 private _probedValue;
        bytes32 private _probeRunId;
        bool private _passed;
        uint64 private _probedAtBlock;

        constructor(bytes32 parameterId, uint64 wallClockFloorSeconds) {
            probedParameterId = parameterId;
            _wallClockFloorSeconds = wallClockFloorSeconds;
        }

        function setRun(uint256 probedValue, bool passed, uint64 probedAtBlock) external {
            _probedValue = probedValue;
            _passed = passed;
            _probedAtBlock = probedAtBlock;
            _probeRunId = keccak256(
                abi.encode(address(this), probedValue, passed, probedAtBlock, block.number)
            );
        }

        function setResponseMode(ResponseMode responseMode) external {
            _responseMode = responseMode;
        }

        function setMinimumReadGas(uint256 minimumReadGas) external {
            _minimumReadGas = minimumReadGas;
        }

        function pinnedWallClockFloorSeconds(bytes32 parameterId)
            external
            view
            override
            returns (uint64)
        {
            return parameterId == probedParameterId ? _wallClockFloorSeconds : 0;
        }

        function lastProbeRun(bytes32 parameterId, uint256 probedValue)
            external
            view
            override(IStreamGasParameterProbe, IStreamTimeParameterProbe)
            returns (bytes32 probeRunId, bool passed, uint64 probedAtBlock)
        {
            if (gasleft() < _minimumReadGas) revert("probe read gas-starved");

            bool servesRun = parameterId == probedParameterId && probedValue == _probedValue;
            probeRunId = servesRun ? _probeRunId : bytes32(0);
            passed = servesRun && _passed;
            probedAtBlock = servesRun ? _probedAtBlock : 0;

            ResponseMode responseMode = _responseMode;
            if (responseMode == ResponseMode.Reverting) revert("probe read unavailable");
            if (responseMode == ResponseMode.Canonical) {
                return (probeRunId, passed, probedAtBlock);
            }

            uint256 responseLength = responseMode == ResponseMode.Oversized
                ? 128
                : responseMode == ResponseMode.Short ? 64 : 96;
            uint256 encodedPassed = responseMode == ResponseMode.NonCanonicalBool
                ? 2
                : passed ? 1 : 0;
            uint256 encodedBlock = responseMode == ResponseMode.NonCanonicalUint64
                ? uint256(type(uint64).max) + 1
                : uint256(probedAtBlock);
            bytes memory response = new bytes(responseLength);
            assembly ("memory-safe") {
                mstore(add(response, 0x20), probeRunId)
                mstore(add(response, 0x40), encodedPassed)
                if gt(responseLength, 0x40) { mstore(add(response, 0x60), encodedBlock) }
                if eq(responseLength, 0x80) { mstore(add(response, 0x80), 1) }
                return(add(response, 0x20), responseLength)
            }
        }
    }

        /// @notice Reference consumer whose read cost is tunable, standing in for a
        ///         guarded fail-safe read (royalty resolver / metadata router class).
        contract GasBurningConsumer {
            uint256 public burnGas;

            function setBurnGas(uint256 newBurnGas) external {
                burnGas = newBurnGas;
            }

            function read() external view returns (uint256 acc) {
                uint256 target = burnGas;
                uint256 start = gasleft();
                while (start - gasleft() < target) {
                    acc = uint256(keccak256(abi.encode(acc)));
                }
            }
        }

        /// @notice Wrapper that invokes a probe run under a caller-chosen gas budget, so
        ///         tests can prove an under-funded run reverts without recording.
        contract UnderfundedProbeCaller {
            function tryRecord(address probe, uint256 probedValue, uint256 gasBudget)
                external
                returns (bool ok)
            {
                (ok,) = probe.call{ gas: gasBudget }(
                    abi.encodeWithSignature("recordProbeRun(uint256)", probedValue)
                );
            }
        }
