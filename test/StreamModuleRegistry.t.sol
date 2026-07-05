// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/ERC165.sol";
import "../smart-contracts/IStreamGovernanceExecutor.sol";
import "../smart-contracts/IStreamModuleRegistry.sol";
import "../smart-contracts/StreamGovernanceExecutor.sol";
import "../smart-contracts/StreamModuleRegistry.sol";
import "../smart-contracts/StreamRoleRegistry.sol";
import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";

/// @notice Minimal governance-executor stand-in exposing the executing-action
///         context the registry gates on, so registry unit tests can drive
///         lifecycle calls under an arbitrary action class.
contract GovernanceExecutorContextMock {
    bool private _executing;
    bytes32 private _actionId;
    uint8 private _actionClass;

    function currentAction() external view returns (bool, bytes32, uint8) {
        return (_executing, _actionId, _actionClass);
    }

    function callAs(uint8 actionClass, bytes32 actionId, address target, bytes calldata data)
        external
        returns (bytes memory)
    {
        _executing = true;
        _actionId = actionId;
        _actionClass = actionClass;
        (bool success, bytes memory returnData) = target.call(data);
        _executing = false;
        _actionId = bytes32(0);
        _actionClass = 0;
        if (!success) {
            assembly {
                revert(add(returnData, 0x20), mload(returnData))
            }
        }
        return returnData;
    }

    function callOutsideAction(address target, bytes calldata data)
        external
        returns (bytes memory)
    {
        (bool success, bytes memory returnData) = target.call(data);
        if (!success) {
            assembly {
                revert(add(returnData, 0x20), mload(returnData))
            }
        }
        return returnData;
    }
}

contract RegistryModuleMock is ERC165 {
    bytes4 private immutable _extraInterfaceId;

    constructor(bytes4 extraInterfaceId) {
        _extraInterfaceId = extraInterfaceId;
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == _extraInterfaceId || super.supportsInterface(interfaceId);
    }
}

contract StreamModuleRegistryTest is CharacterizationTestBase {
    using Assertions for address;
    using Assertions for bool;
    using Assertions for bytes32;
    using Assertions for string;
    using Assertions for uint256;

    event StreamModuleRegistered(
        uint16 schemaVersion,
        address indexed module,
        bytes32 indexed moduleType,
        bytes4 indexed interfaceId,
        bytes32 moduleVersion,
        uint32 moduleGasLimit,
        bytes32 runtimeCodeHash,
        bytes32 deploymentManifestHash,
        bytes32 moduleManifestHash,
        string moduleManifestURI,
        bytes32 recordChainHash
    );

    event StreamModuleStatusChanged(
        uint16 schemaVersion,
        address indexed module,
        bytes32 indexed moduleType,
        ModuleRegistryStatus status,
        bytes32 reasonHash,
        string reasonURI
    );

    bytes4 private constant MODULE_INTERFACE_ID = bytes4(keccak256("stream.test.module"));
    bytes32 private constant MODULE_TYPE = keccak256("STREAM_RENDERER");
    bytes32 private constant MODULE_VERSION = bytes32(uint256(1));
    bytes32 private constant DEPLOYMENT_MANIFEST_HASH = keccak256("deployment-manifest");
    bytes32 private constant MODULE_MANIFEST_HASH = keccak256("module-manifest");
    string private constant MODULE_MANIFEST_URI = "ipfs://module-manifest";
    bytes32 private constant REGISTRY_MANIFEST_HASH = keccak256("registry-manifest");
    string private constant REGISTRY_MANIFEST_URI = "ipfs://registry-manifest";
    uint64 private constant BASE_TIME = 1_000_000;

    uint8 private constant IMMEDIATE = StreamGovernanceActionClasses.IMMEDIATE_TIGHTENING;
    uint8 private constant LOOSENING = StreamGovernanceActionClasses.DELAYED_LOOSENING;
    uint8 private constant TERMINAL = StreamGovernanceActionClasses.TERMINAL_FREEZE;

    GovernanceExecutorContextMock private executorMock;
    StreamModuleRegistry private registry;
    RegistryModuleMock private module;

    function setUp() public {
        vm.warp(BASE_TIME);
        executorMock = new GovernanceExecutorContextMock();
        registry = new StreamModuleRegistry(
            IStreamGovernanceExecutor(address(executorMock)),
            REGISTRY_MANIFEST_HASH,
            REGISTRY_MANIFEST_URI
        );
        module = new RegistryModuleMock(MODULE_INTERFACE_ID);
    }

    // ---------------------------------------------------------------- helpers

    function _registration(address moduleAddress)
        private
        view
        returns (StreamModuleRegistration memory registration)
    {
        registration.module = moduleAddress;
        registration.moduleType = MODULE_TYPE;
        registration.moduleVersion = MODULE_VERSION;
        registration.interfaceId = MODULE_INTERFACE_ID;
        registration.moduleGasLimit = 400_000;
        // FIX D: governance pins the live codehash at review time; the default
        // registration mirrors that. Tests exercising zero/mismatch pins
        // override this field explicitly.
        registration.expectedRuntimeCodeHash = moduleAddress.codehash;
        registration.deploymentManifestHash = DEPLOYMENT_MANIFEST_HASH;
        registration.moduleManifestHash = MODULE_MANIFEST_HASH;
        registration.moduleManifestURI = MODULE_MANIFEST_URI;
    }

    function _register(StreamModuleRegistration memory registration) private {
        _callRegistry(
            LOOSENING, abi.encodeCall(StreamModuleRegistry.registerModule, (registration))
        );
    }

    function _setStatus(
        uint8 actionClass,
        address moduleAddress,
        ModuleRegistryStatus newStatus,
        bytes32 reasonHash
    ) private {
        _callRegistry(
            actionClass,
            abi.encodeCall(
                StreamModuleRegistry.setModuleStatus,
                (moduleAddress, newStatus, reasonHash, "ipfs://reason")
            )
        );
    }

    function _callRegistry(uint8 actionClass, bytes memory data) private {
        executorMock.callAs(actionClass, keccak256("mock-action"), address(registry), data);
    }

    function _expectedChainHash(
        bytes32 previousChainHash,
        address moduleAddress,
        bytes32 runtimeCodeHash,
        uint64 recordIndex
    ) private view returns (bytes32) {
        bytes32 recordHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_REGISTRATION_RECORD_V1(),
                moduleAddress,
                MODULE_TYPE,
                MODULE_INTERFACE_ID,
                MODULE_VERSION,
                runtimeCodeHash,
                DEPLOYMENT_MANIFEST_HASH,
                MODULE_MANIFEST_HASH
            )
        );
        return keccak256(
            abi.encode(
                registry.STREAM_RECORD_CHAIN_V1(),
                uint256(block.chainid),
                address(registry),
                uint256(0),
                keccak256("MODULE_REGISTRATION"),
                previousChainHash,
                recordHash,
                recordIndex
            )
        );
    }

    // ------------------------------------------------------------ registration

    function testRegisterModuleStoresRecordAndChainsRegistration() public {
        bytes32 expectedChain =
            _expectedChainHash(bytes32(0), address(module), address(module).codehash, 0);

        vm.expectEmit(true, true, true, true);
        emit StreamModuleRegistered(
            1,
            address(module),
            MODULE_TYPE,
            MODULE_INTERFACE_ID,
            MODULE_VERSION,
            400_000,
            address(module).codehash,
            DEPLOYMENT_MANIFEST_HASH,
            MODULE_MANIFEST_HASH,
            MODULE_MANIFEST_URI,
            expectedChain
        );
        _register(_registration(address(module)));

        StreamModuleRecord memory record = registry.moduleRecord(address(module));
        uint256(uint8(record.status))
            .assertEq(uint256(uint8(ModuleRegistryStatus.ACTIVE)), "status active");
        record.moduleType.assertEq(MODULE_TYPE, "module type");
        record.moduleVersion.assertEq(MODULE_VERSION, "module version");
        bytes32(record.interfaceId).assertEq(bytes32(MODULE_INTERFACE_ID), "interface id");
        uint256(record.moduleGasLimit).assertEq(400_000, "gas limit");
        record.runtimeCodeHash.assertEq(address(module).codehash, "runtime code hash");
        record.deploymentManifestHash.assertEq(DEPLOYMENT_MANIFEST_HASH, "deployment manifest hash");
        record.moduleManifestHash.assertEq(MODULE_MANIFEST_HASH, "module manifest hash");
        record.moduleManifestURI.assertEq(MODULE_MANIFEST_URI, "module manifest URI");
        uint256(record.registeredAt).assertEq(BASE_TIME, "registeredAt");
        uint256(record.statusUpdatedAt).assertEq(BASE_TIME, "statusUpdatedAt");

        // Requirement 6 enumeration index.
        registry.moduleCount().assertEq(1, "module count");
        registry.moduleAt(0).assertEq(address(module), "module at 0");

        // Requirement 7 accumulator: recordCount equals moduleCount.
        (bytes32 chainHash, uint64 recordCount) = registry.registrationChainHash();
        chainHash.assertEq(expectedChain, "registration chain hash");
        uint256(recordCount).assertEq(registry.moduleCount(), "recordCount == moduleCount");
    }

    function testRegistrationChainAccumulatesAcrossModules() public {
        RegistryModuleMock second = new RegistryModuleMock(MODULE_INTERFACE_ID);
        RegistryModuleMock third = new RegistryModuleMock(MODULE_INTERFACE_ID);
        _register(_registration(address(module)));
        _register(_registration(address(second)));
        _register(_registration(address(third)));

        // Replaying the three registration facts reproduces the stored head.
        bytes32 replayed =
            _expectedChainHash(bytes32(0), address(module), address(module).codehash, 0);
        replayed = _expectedChainHash(replayed, address(second), address(second).codehash, 1);
        replayed = _expectedChainHash(replayed, address(third), address(third).codehash, 2);

        (bytes32 chainHash, uint64 recordCount) = registry.registrationChainHash();
        chainHash.assertEq(replayed, "replayed chain head matches");
        uint256(recordCount).assertEq(3, "record count");
        registry.moduleCount().assertEq(3, "module count");
        registry.moduleAt(0).assertEq(address(module), "enumeration order 0");
        registry.moduleAt(1).assertEq(address(second), "enumeration order 1");
        registry.moduleAt(2).assertEq(address(third), "enumeration order 2");
    }

    function testReRegisteringKnownModuleReverts() public {
        _register(_registration(address(module)));
        // [LTA-REGISTRY] requirement 6: the index is append-only.
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamModuleRegistry.ModuleAlreadyRegistered.selector, address(module)
            )
        );
        _register(_registration(address(module)));

        // Status changes never reopen registration.
        _setStatus(IMMEDIATE, address(module), ModuleRegistryStatus.DEPRECATED, keccak256("d"));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamModuleRegistry.ModuleAlreadyRegistered.selector, address(module)
            )
        );
        _register(_registration(address(module)));
    }

    function testRegistrationRequiresGovernedLoosening() public {
        StreamModuleRegistration memory registration = _registration(address(module));
        bytes memory data = abi.encodeCall(StreamModuleRegistry.registerModule, (registration));

        // Direct calls are not the governance executor.
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamModuleRegistry.NotGovernanceExecutor.selector, address(this)
            )
        );
        registry.registerModule(registration);

        // Executor calls outside an executing action revert.
        vm.expectRevert(
            abi.encodeWithSelector(StreamModuleRegistry.NoExecutingGovernanceAction.selector)
        );
        executorMock.callOutsideAction(address(registry), data);

        // Registration is loosening: IMMEDIATE_TIGHTENING cannot register.
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamModuleRegistry.WrongGovernanceActionClass.selector, IMMEDIATE
            )
        );
        _callRegistry(IMMEDIATE, data);

        // Nor can any non-loosening class.
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamModuleRegistry.WrongGovernanceActionClass.selector, TERMINAL
            )
        );
        _callRegistry(TERMINAL, data);
    }

    function testRegistrationValidation() public {
        // Zero module address.
        StreamModuleRegistration memory registration = _registration(address(0));
        vm.expectRevert(
            abi.encodeWithSelector(StreamModuleRegistry.InvalidModule.selector, address(0))
        );
        _register(registration);

        // Codeless module address.
        registration = _registration(address(0xDEAD02));
        vm.expectRevert(
            abi.encodeWithSelector(StreamModuleRegistry.InvalidModule.selector, address(0xDEAD02))
        );
        _register(registration);

        // Zero module type.
        registration = _registration(address(module));
        registration.moduleType = bytes32(0);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamModuleRegistry.InvalidModuleRecord.selector, address(module)
            )
        );
        _register(registration);

        // Zero module version.
        registration = _registration(address(module));
        registration.moduleVersion = bytes32(0);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamModuleRegistry.InvalidModuleRecord.selector, address(module)
            )
        );
        _register(registration);

        // Zero module manifest hash.
        registration = _registration(address(module));
        registration.moduleManifestHash = bytes32(0);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamModuleRegistry.InvalidModuleRecord.selector, address(module)
            )
        );
        _register(registration);

        // Invalid interface IDs.
        registration = _registration(address(module));
        registration.interfaceId = bytes4(0);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamModuleRegistry.InvalidModuleRecord.selector, address(module)
            )
        );
        _register(registration);
        registration = _registration(address(module));
        registration.interfaceId = 0xffffffff;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamModuleRegistry.InvalidModuleRecord.selector, address(module)
            )
        );
        _register(registration);

        // FIX D: a zero codehash pin is rejected (execution-time pinning is
        // mandatory; governance must pin the live codehash at review time).
        registration = _registration(address(module));
        registration.expectedRuntimeCodeHash = bytes32(0);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamModuleRegistry.InvalidModuleRecord.selector, address(module)
            )
        );
        _register(registration);

        // Module that does not advertise the declared interface.
        RegistryModuleMock wrongInterface = new RegistryModuleMock(bytes4(keccak256("other")));
        registration = _registration(address(wrongInterface));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamModuleRegistry.ModuleInterfaceUnsupported.selector,
                address(wrongInterface),
                MODULE_INTERFACE_ID
            )
        );
        _register(registration);

        // Codehash pin mismatch.
        registration = _registration(address(module));
        registration.expectedRuntimeCodeHash = keccak256("wrong-codehash");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamModuleRegistry.ModuleCodehashMismatch.selector,
                address(module),
                keccak256("wrong-codehash"),
                address(module).codehash
            )
        );
        _register(registration);

        // Matching codehash pin registers.
        registration = _registration(address(module));
        registration.expectedRuntimeCodeHash = address(module).codehash;
        _register(registration);
        registry.moduleCount().assertEq(1, "pinned registration landed");
    }

    function testZeroGasLimitMeansUnbounded() public {
        // [LTA-REGISTRY] requirement 3: zero is a legal no-bound value.
        StreamModuleRegistration memory registration = _registration(address(module));
        registration.moduleGasLimit = 0;
        _register(registration);
        uint256(registry.moduleRecord(address(module)).moduleGasLimit)
            .assertEq(0, "zero gas limit stored");
        registry.isModuleEligible(address(module), MODULE_TYPE, MODULE_INTERFACE_ID)
            .assertTrue("zero gas limit module eligible");
    }

    // ---------------------------------------------------------- status machine

    function testStatusMachineTighteningAndLoosening() public {
        _register(_registration(address(module)));
        uint64 registeredAt = uint64(block.timestamp);
        vm.warp(BASE_TIME + 1 days);

        // Tightening under IMMEDIATE_TIGHTENING with a reasoned event.
        vm.expectEmit(true, true, true, true);
        emit StreamModuleStatusChanged(
            1,
            address(module),
            MODULE_TYPE,
            ModuleRegistryStatus.DEPRECATED,
            keccak256("sunset"),
            "ipfs://reason"
        );
        _setStatus(IMMEDIATE, address(module), ModuleRegistryStatus.DEPRECATED, keccak256("sunset"));

        StreamModuleRecord memory record = registry.moduleRecord(address(module));
        uint256(uint8(record.status))
            .assertEq(uint256(uint8(ModuleRegistryStatus.DEPRECATED)), "deprecated");
        uint256(record.statusUpdatedAt).assertEq(BASE_TIME + 1 days, "statusUpdatedAt moved");
        uint256(record.registeredAt).assertEq(registeredAt, "registeredAt immutable");

        // Loosening back to ACTIVE requires DELAYED_LOOSENING.
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamModuleRegistry.WrongGovernanceActionClass.selector, IMMEDIATE
            )
        );
        _setStatus(IMMEDIATE, address(module), ModuleRegistryStatus.ACTIVE, keccak256("revive"));
        _setStatus(LOOSENING, address(module), ModuleRegistryStatus.ACTIVE, keccak256("revive"));
        uint256(uint8(registry.moduleRecord(address(module)).status))
            .assertEq(uint256(uint8(ModuleRegistryStatus.ACTIVE)), "reactivated");

        // Incident revocation is IMMEDIATE_TIGHTENING.
        _setStatus(
            IMMEDIATE, address(module), ModuleRegistryStatus.INCIDENT_REVOKED, keccak256("inc")
        );
        uint256(uint8(registry.moduleRecord(address(module)).status))
            .assertEq(uint256(uint8(ModuleRegistryStatus.INCIDENT_REVOKED)), "incident revoked");

        // Recovery from incident revocation is loosening.
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamModuleRegistry.WrongGovernanceActionClass.selector, IMMEDIATE
            )
        );
        _setStatus(IMMEDIATE, address(module), ModuleRegistryStatus.DEPRECATED, keccak256("r"));
        _setStatus(LOOSENING, address(module), ModuleRegistryStatus.DEPRECATED, keccak256("r"));

        // Tightening may also ride a delayed action (stricter than required).
        _setStatus(
            LOOSENING, address(module), ModuleRegistryStatus.INCIDENT_REVOKED, keccak256("i2")
        );
        uint256(uint8(registry.moduleRecord(address(module)).status))
            .assertEq(
                uint256(uint8(ModuleRegistryStatus.INCIDENT_REVOKED)), "re-revoked via delayed"
            );
    }

    function testStatusMachineRejectsInvalidTransitions() public {
        // Unregistered module.
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamModuleRegistry.ModuleNotRegistered.selector, address(module)
            )
        );
        _setStatus(IMMEDIATE, address(module), ModuleRegistryStatus.DEPRECATED, keccak256("x"));

        _register(_registration(address(module)));

        // No transition back to UNKNOWN: entries are never deleted.
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamModuleRegistry.InvalidStatusTransition.selector,
                address(module),
                ModuleRegistryStatus.ACTIVE,
                ModuleRegistryStatus.UNKNOWN
            )
        );
        _setStatus(IMMEDIATE, address(module), ModuleRegistryStatus.UNKNOWN, keccak256("x"));

        // No same-status no-op writes.
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamModuleRegistry.InvalidStatusTransition.selector,
                address(module),
                ModuleRegistryStatus.ACTIVE,
                ModuleRegistryStatus.ACTIVE
            )
        );
        _setStatus(LOOSENING, address(module), ModuleRegistryStatus.ACTIVE, keccak256("x"));
    }

    function testStatusChangesNeverRemoveRecordsOrEnumeration() public {
        _register(_registration(address(module)));
        _setStatus(
            IMMEDIATE, address(module), ModuleRegistryStatus.INCIDENT_REVOKED, keccak256("inc")
        );

        // Record facts and the enumeration entry survive incident revocation.
        StreamModuleRecord memory record = registry.moduleRecord(address(module));
        record.moduleType.assertEq(MODULE_TYPE, "type survives");
        record.moduleVersion.assertEq(MODULE_VERSION, "version survives");
        record.runtimeCodeHash.assertEq(address(module).codehash, "code hash survives");
        record.moduleManifestURI.assertEq(MODULE_MANIFEST_URI, "manifest URI survives");
        registry.moduleCount().assertEq(1, "enumeration survives");
        registry.moduleAt(0).assertEq(address(module), "entry survives");
        (, uint64 recordCount) = registry.registrationChainHash();
        uint256(recordCount).assertEq(1, "chain lane untouched by status change");
    }

    // ------------------------------------------------------------- eligibility

    function testIsModuleEligible() public {
        registry.isModuleEligible(address(module), MODULE_TYPE, MODULE_INTERFACE_ID)
            .assertFalse("unknown module not eligible");
        _register(_registration(address(module)));
        registry.isModuleEligible(address(module), MODULE_TYPE, MODULE_INTERFACE_ID)
            .assertTrue("active module eligible");
        registry.isModuleEligible(address(module), keccak256("OTHER_TYPE"), MODULE_INTERFACE_ID)
            .assertFalse("wrong module type");
        registry.isModuleEligible(address(module), MODULE_TYPE, bytes4(keccak256("other")))
            .assertFalse("wrong interface id");

        _setStatus(IMMEDIATE, address(module), ModuleRegistryStatus.DEPRECATED, keccak256("d"));
        registry.isModuleEligible(address(module), MODULE_TYPE, MODULE_INTERFACE_ID)
            .assertFalse("deprecated not eligible for new assignments");
        _setStatus(LOOSENING, address(module), ModuleRegistryStatus.ACTIVE, keccak256("a"));
        _setStatus(
            IMMEDIATE, address(module), ModuleRegistryStatus.INCIDENT_REVOKED, keccak256("i")
        );
        registry.isModuleEligible(address(module), MODULE_TYPE, MODULE_INTERFACE_ID)
            .assertFalse("incident-revoked not eligible");
    }

    // ------------------------------------------------------- manifest and misc

    function testRegistryManifestGovernedUpdate() public {
        (bytes32 manifestHash, string memory manifestURI) = registry.moduleRegistryManifest();
        manifestHash.assertEq(REGISTRY_MANIFEST_HASH, "constructor manifest hash");
        manifestURI.assertEq(REGISTRY_MANIFEST_URI, "constructor manifest URI");

        bytes memory data = abi.encodeCall(
            StreamModuleRegistry.setModuleRegistryManifest,
            (keccak256("registry-manifest-v2"), "ipfs://registry-manifest-v2")
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamModuleRegistry.NotGovernanceExecutor.selector, address(this)
            )
        );
        registry.setModuleRegistryManifest(keccak256("registry-manifest-v2"), "x");

        vm.expectRevert(
            abi.encodeWithSelector(
                StreamModuleRegistry.WrongGovernanceActionClass.selector, IMMEDIATE
            )
        );
        _callRegistry(IMMEDIATE, data);

        _callRegistry(LOOSENING, data);
        (manifestHash, manifestURI) = registry.moduleRegistryManifest();
        manifestHash.assertEq(keccak256("registry-manifest-v2"), "updated manifest hash");
        manifestURI.assertEq("ipfs://registry-manifest-v2", "updated manifest URI");
    }

    function testModuleEnumerationBounds() public {
        vm.expectRevert(
            abi.encodeWithSelector(StreamModuleRegistry.ModuleIndexOutOfBounds.selector, 0)
        );
        registry.moduleAt(0);
    }

    function testSupportsCanonicalRegistryInterface() public {
        registry.supportsInterface(type(IStreamModuleRegistry).interfaceId)
            .assertTrue("canonical registry interface");
        registry.supportsInterface(0xffffffff).assertFalse("invalid interface");
    }
}

/// @notice End-to-end: registry lifecycle driven through the real staged
///         governance executor ([LTA-REGISTRY] requirement 5).
contract StreamModuleRegistryGovernanceIntegrationTest is CharacterizationTestBase {
    using Assertions for address;
    using Assertions for bool;
    using Assertions for uint256;

    bytes4 private constant MODULE_INTERFACE_ID = bytes4(keccak256("stream.test.module"));
    uint64 private constant BASE_TIME = 1_000_000;

    StreamRoleRegistry private roleRegistry;
    StreamGovernanceExecutor private executor;
    StreamModuleRegistry private registry;
    RegistryModuleMock private module;

    function setUp() public {
        vm.warp(BASE_TIME);
        roleRegistry = new StreamRoleRegistry();
        executor = new StreamGovernanceExecutor(roleRegistry);
        registry = new StreamModuleRegistry(
            executor, keccak256("registry-manifest"), "ipfs://registry-manifest"
        );
        module = new RegistryModuleMock(MODULE_INTERFACE_ID);
    }

    function _scheduleRegistryCall(uint8 actionClass, bytes memory data, uint64 notBefore)
        private
        returns (bytes32 actionId, GovernanceCall[] memory calls, bytes[] memory callDatas)
    {
        calls = new GovernanceCall[](1);
        bytes4 selector;
        assembly {
            selector := mload(add(data, 0x20))
        }
        calls[0] = GovernanceCall({
            target: address(registry), value: 0, selector: selector, callDataHash: keccak256(data)
        });
        callDatas = new bytes[](1);
        callDatas[0] = data;
        executor.publishGovernanceCallData(callDatas);
        actionId = executor.scheduleGovernanceBatch(
            actionClass,
            calls,
            keccak256("registry-scope"),
            bytes32(0),
            keccak256("new-value"),
            notBefore,
            notBefore + 7 days,
            keccak256("reason"),
            "ipfs://reason",
            keccak256("manifest")
        );
    }

    function testRegistrationThroughDelayedLooseningAction() public {
        StreamModuleRegistration memory registration;
        registration.module = address(module);
        registration.moduleType = keccak256("STREAM_RENDERER");
        registration.moduleVersion = bytes32(uint256(1));
        registration.interfaceId = MODULE_INTERFACE_ID;
        registration.moduleGasLimit = 0;
        registration.expectedRuntimeCodeHash = address(module).codehash;
        registration.deploymentManifestHash = keccak256("deployment-manifest");
        registration.moduleManifestHash = keccak256("module-manifest");
        registration.moduleManifestURI = "ipfs://module-manifest";

        uint64 notBefore = uint64(block.timestamp) + 48 hours;
        (bytes32 actionId, GovernanceCall[] memory calls, bytes[] memory callDatas) = _scheduleRegistryCall(
            StreamGovernanceActionClasses.DELAYED_LOOSENING,
            abi.encodeCall(StreamModuleRegistry.registerModule, (registration)),
            notBefore
        );

        vm.warp(notBefore);
        executor.executeGovernanceBatch(actionId, calls, callDatas);

        registry.moduleCount().assertEq(1, "registered through staged action");
        registry.moduleAt(0).assertEq(address(module), "enumerated");
        registry.isModuleEligible(
                address(module), keccak256("STREAM_RENDERER"), MODULE_INTERFACE_ID
            ).assertTrue("eligible after governed registration");
    }

    function testIncidentRevocationThroughImmediateTightening() public {
        // Register first through the delayed path.
        testRegistrationThroughDelayedLooseningAction();

        bytes memory data = abi.encodeCall(
            StreamModuleRegistry.setModuleStatus,
            (
                address(module),
                ModuleRegistryStatus.INCIDENT_REVOKED,
                keccak256("incident"),
                "ipfs://incident"
            )
        );
        // Incident revocation is tightening-classified for zero-delay staging.
        executor.setTighteningCall(
            address(registry), StreamModuleRegistry.setModuleStatus.selector, true
        );
        uint64 notBefore = uint64(block.timestamp);
        (bytes32 actionId, GovernanceCall[] memory calls, bytes[] memory callDatas) = _scheduleRegistryCall(
            StreamGovernanceActionClasses.IMMEDIATE_TIGHTENING, data, notBefore
        );
        executor.executeGovernanceBatch(actionId, calls, callDatas);

        uint256(uint8(registry.moduleRecord(address(module)).status))
            .assertEq(
                uint256(uint8(ModuleRegistryStatus.INCIDENT_REVOKED)),
                "incident revoked with zero delay"
            );
        registry.isModuleEligible(
                address(module), keccak256("STREAM_RENDERER"), MODULE_INTERFACE_ID
            ).assertFalse("revoked module ineligible");
        registry.moduleCount().assertEq(1, "record retained after revocation");
    }
}
