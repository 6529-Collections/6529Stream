// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/IStreamTimeParameterHost.sol";
import "../smart-contracts/IStreamTimeParameterProbe.sol";
import "../smart-contracts/IStreamGovernedParameterAuthority.sol";
import "../smart-contracts/IERC165.sol";
import {
    IStreamModuleRegistry,
    ModuleRegistryStatus
} from "../smart-contracts/IStreamModuleRegistry.sol";
import "../smart-contracts/StreamCadenceProbe.sol";
import "../smart-contracts/StreamTimeParameterStore.sol";
import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";
import "./helpers/GovernedParameterTestMocks.sol";

contract SelfCoreTimeParameterStoreHarness is StreamTimeParameterStore {
    constructor(address genesisRegistry, TimeParameterConfig[] memory configs)
        StreamTimeParameterStore(address(0), address(this), genesisRegistry, configs)
    { }
}

interface VmStorage {
    function store(address target, bytes32 slot, bytes32 value) external;
    function mockCall(address callee, bytes calldata data, bytes calldata returnData) external;
}

/// @notice [LTA-GTP] discipline suite: parameterId derivation goldens for the
///         three coordinator genesis rows, timeParameterInfo introspection,
///         registration pins (block floor, wall-clock floor, cadence-probe
///         cross-check), governance-only change paths with 2x raise / half lower
///         bounds, block-floor and wall-clock-floor rejection, cadence-probe-gated
///         lowering, canonical event schemas, and the negative test that no
///         emergency or permissionless conditional path exists for GTPs.
contract StreamTimeParameterStoreTest is CharacterizationTestBase {
    struct TimeStateView {
        uint256 value;
        uint256 floorBlocks;
        uint64 wallClockFloorSeconds;
        address cadenceProbe;
        uint64 probeMaxAgeBlocks;
        uint64 revision;
    }

    uint256 private constant START_BLOCK = 3_000_000;
    uint256 private constant START_TIMESTAMP = 1_000_000_000;
    uint64 private constant MAX_AGE = 50_400;
    uint64 private constant WINDOW = 1_000;
    bytes32 private constant ACTION_ID = keccak256("test-governance-action");
    uint8 private constant DELAYED_LOOSENING = 1;
    uint8 private constant POINTER_REPLACEMENT = 3;
    bytes32 private constant TIME_PARAMETER_SCOPE_V1 =
        0xcb90eddcfa663732d90ca0d1892636ba1216e3900df55acc72d58187eee359a8;
    bytes32 private constant TIME_PARAMETER_STATE_V1 =
        0x2cdcb8724d05b4fa9d1ad4f857f9c5fa49ca997d15870fe7f9df6fbae1402583;
    bytes32 private constant GGP_PROBE_BINDING_V1 =
        0x4efb354b2a3c37f3c74fe57912e40eb08d83026611be9740d785f348cc2332c4;
    bytes4 private constant TIME_PARAMETER_PROBE_INTERFACE_ID = 0xb6c57592;

    // Spec-pinned GTP parameterIds (docs/launch-v1-target-architecture.md
    // identifier catalog; recomputed with `cast keccak`).
    bytes32 private constant TIMEOUT_ID =
        0x63722ca7b016ab346b7839fe4e01fa7e0627bd5fb99531f7dbe5ec8c34e35c8d;
    bytes32 private constant SLO_ID =
        0x823057688d7c18dca4c528004d7912dfe0a32c36528a2cff1eb0e2a9164ab5e0;
    bytes32 private constant RECOVERY_ID =
        0x0be33ccf48a79079b125936b770c51cdd786fd29d574ce9071323b86838bccd8;

    // keccak256("TimeParameterUpdated(uint16,bytes32,address,bytes32,uint256,uint256,uint256)")
    bytes32 private constant TIME_PARAMETER_UPDATED_TOPIC =
        0x503882277086575edc26a1c92db8b562bc44167d8639e30451d231226f1170c0;
    // keccak256("TimeParameterProbed(uint16,bytes32,bytes32,bool,uint256,bytes32)")
    bytes32 private constant TIME_PARAMETER_PROBED_TOPIC =
        0x2c09274a7cd758a564107cad1417a20af410c1640238892465a511f1a8d53b62;
    // keccak256("TimeParameterProbeRebound(uint16,bytes32,address,bytes32,address,address)")
    bytes32 private constant TIME_PARAMETER_PROBE_REBOUND_TOPIC =
        0xfc09efe81fbda50f25673f8de2b4d15983946c16724f27baff1b7c3e21dbc7f4;

    MockGovernedParameterAuthority private _authority;
    MockParameterCorePointer private _core;
    MockParameterModuleRegistry private _moduleRegistry;
    StreamCadenceProbe private _cadenceProbe;
    StreamTimeParameterStore private _store;

    function setUp() public {
        vm.roll(START_BLOCK);
        vm.warp(START_TIMESTAMP);
        _authority = new MockGovernedParameterAuthority(true);
        _core = new MockParameterCorePointer();
        _moduleRegistry = new MockParameterModuleRegistry();
        _cadenceProbe = _newProbe();

        IStreamTimeParameterHost.TimeParameterConfig[] memory configs =
            new IStreamTimeParameterHost.TimeParameterConfig[](3);
        configs[0] = _config("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 600, 300, 3_600);
        configs[1] = _config("ENTROPY_REVEAL_SLO_BLOCKS", 1_200, 650, 7_200);
        configs[2] = _config("ENTROPY_RECOVERY_STEP_DELAY_BLOCKS", 300, 150, 1_800);
        _store = new StreamTimeParameterStore(
            address(_authority), address(_core), address(_moduleRegistry), configs
        );
        _core.setLiveModuleRegistry(address(_moduleRegistry), address(_moduleRegistry));
    }

    // ------------------------------------------------------------------
    // parameterId derivation goldens ([LTA-GTP] definition item 3)
    // ------------------------------------------------------------------

    function testTimeParameterIdDerivationGoldens() public view {
        Assertions.assertEq(
            keccak256(abi.encodePacked("6529STREAM_GTP_", "ENTROPY_REQUEST_TIMEOUT_BLOCKS")),
            TIMEOUT_ID,
            "timeout id"
        );
        Assertions.assertEq(
            keccak256(abi.encodePacked("6529STREAM_GTP_", "ENTROPY_REVEAL_SLO_BLOCKS")),
            SLO_ID,
            "reveal slo id"
        );
        Assertions.assertEq(
            keccak256(abi.encodePacked("6529STREAM_GTP_", "ENTROPY_RECOVERY_STEP_DELAY_BLOCKS")),
            RECOVERY_ID,
            "recovery step delay id"
        );

        bytes32[] memory ids = _store.timeParameterIds();
        Assertions.assertEq(ids.length, 3, "registered count");
        Assertions.assertEq(ids[0], TIMEOUT_ID, "registered timeout id");
        Assertions.assertEq(ids[1], SLO_ID, "registered slo id");
        Assertions.assertEq(ids[2], RECOVERY_ID, "registered recovery id");
    }

    // ------------------------------------------------------------------
    // Introspection ([LTA-GTP] definition item 7)
    // ------------------------------------------------------------------

    function testTimeParameterInfoGoldenAndUnknownZeroed() public {
        (
            uint256 value,
            uint256 floorBlocks,
            uint64 wallClockFloorSeconds,
            address cadenceProbe,
            uint64 probeMaxAgeBlocks,
            uint64 revision
        ) = _store.timeParameterInfo(TIMEOUT_ID);
        Assertions.assertEq(value, 600, "timeout value");
        Assertions.assertEq(floorBlocks, 300, "timeout block floor");
        Assertions.assertEq(uint256(wallClockFloorSeconds), 3_600, "timeout wall-clock floor");
        Assertions.assertEq(cadenceProbe, address(_cadenceProbe), "timeout probe binding");
        Assertions.assertEq(uint256(probeMaxAgeBlocks), uint256(MAX_AGE), "timeout recency bound");
        Assertions.assertEq(uint256(revision), 1, "genesis revision");
        Assertions.assertEq(
            _store.moduleRegistry(), address(_moduleRegistry), "Core-live module registry"
        );

        (value, floorBlocks, wallClockFloorSeconds, cadenceProbe, probeMaxAgeBlocks, revision) =
            _store.timeParameterInfo(keccak256("nope"));
        Assertions.assertEq(value, 0, "unknown value");
        Assertions.assertEq(floorBlocks, 0, "unknown block floor");
        Assertions.assertEq(uint256(wallClockFloorSeconds), 0, "unknown wall-clock floor");
        Assertions.assertEq(cadenceProbe, address(0), "unknown probe");
        Assertions.assertEq(uint256(probeMaxAgeBlocks), 0, "unknown recency bound");
        Assertions.assertEq(uint256(revision), 0, "unknown revision");

        Assertions.assertEq(_store.timeParameter(SLO_ID), 1_200, "live value read");
        bytes32 unknownId = keccak256("unknown");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterUnknown.selector, unknownId
            )
        );
        _store.timeParameter(unknownId);
    }

    // ------------------------------------------------------------------
    // Registration invariants
    // ------------------------------------------------------------------

    function deployStore(
        address authority,
        address core,
        address moduleRegistry,
        IStreamTimeParameterHost.TimeParameterConfig[] memory configs
    ) external returns (StreamTimeParameterStore) {
        return new StreamTimeParameterStore(authority, core, moduleRegistry, configs);
    }

    function _expectDeployRevert(
        IStreamTimeParameterHost.TimeParameterConfig memory config,
        bytes memory expectedError,
        string memory message
    ) private {
        IStreamTimeParameterHost.TimeParameterConfig[] memory configs =
            new IStreamTimeParameterHost.TimeParameterConfig[](1);
        configs[0] = config;
        try this.deployStore(
            address(_authority), address(_core), address(_moduleRegistry), configs
        ) returns (
            StreamTimeParameterStore
        ) {
            Assertions.assertTrue(false, message);
        } catch (bytes memory err) {
            Assertions.assertEq(keccak256(err), keccak256(expectedError), message);
        }
    }

    function _expectInvalidGenesisRegistry(address registry, string memory message) private {
        IStreamTimeParameterHost.TimeParameterConfig[] memory configs =
            new IStreamTimeParameterHost.TimeParameterConfig[](0);
        try this.deployStore(address(_authority), address(_core), registry, configs) returns (
            StreamTimeParameterStore
        ) {
            Assertions.assertTrue(false, message);
        } catch (bytes memory err) {
            Assertions.assertEq(
                keccak256(err),
                keccak256(
                    abi.encodeWithSelector(
                        IStreamTimeParameterHost.TimeParameterInvalidModuleRegistry.selector,
                        registry
                    )
                ),
                message
            );
        }
    }

    function testRegistrationInvariantsRejectInvalidConfigs() public {
        // Empty name.
        IStreamTimeParameterHost.TimeParameterConfig memory bad = _config("", 600, 300, 3_600);
        _expectDeployRevert(
            bad,
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterInvalidConfig.selector, bytes32(0)
            ),
            "empty name"
        );
        // Zero block floor.
        bad = _config("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 600, 0, 3_600);
        _expectDeployRevert(
            bad,
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterInvalidConfig.selector, TIMEOUT_ID
            ),
            "zero block floor"
        );
        // Genesis below the block floor.
        bad = _config("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 299, 300, 3_600);
        _expectDeployRevert(
            bad,
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterInvalidConfig.selector, TIMEOUT_ID
            ),
            "genesis below floor"
        );
        // Zero wall-clock floor.
        bad = _config("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 600, 300, 0);
        _expectDeployRevert(
            bad,
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterInvalidConfig.selector, TIMEOUT_ID
            ),
            "zero wall-clock floor"
        );
        // probeMaxAgeBlocks below the [LTA-GGP-PROBES] rule 6 floor.
        bad = _config("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 600, 300, 3_600);
        bad.probeMaxAgeBlocks = 50_399;
        _expectDeployRevert(
            bad,
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterInvalidConfig.selector, TIMEOUT_ID
            ),
            "probe max age below floor"
        );
        // Zero cadence probe.
        bad = _config("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 600, 300, 3_600);
        bad.cadenceProbe = address(0);
        _expectDeployRevert(
            bad,
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterProbeMismatch.selector, TIMEOUT_ID, address(0)
            ),
            "zero probe"
        );
        // Wall-clock floor disagreeing with the probe's pin.
        bad = _config("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 600, 300, 9_999);
        _expectDeployRevert(
            bad,
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterProbeMismatch.selector,
                TIMEOUT_ID,
                address(_cadenceProbe)
            ),
            "pin mismatch"
        );
        // A row the probe does not serve.
        bad = _config("SOME_FUTURE_WINDOW_BLOCKS", 600, 300, 3_600);
        _expectDeployRevert(
            bad,
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterProbeMismatch.selector,
                keccak256(abi.encodePacked("6529STREAM_GTP_", "SOME_FUTURE_WINDOW_BLOCKS")),
                address(_cadenceProbe)
            ),
            "unserved row"
        );

        // Duplicate registration.
        IStreamTimeParameterHost.TimeParameterConfig[] memory dupes =
            new IStreamTimeParameterHost.TimeParameterConfig[](2);
        dupes[0] = _config("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 600, 300, 3_600);
        dupes[1] = _config("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 700, 300, 3_600);
        try this.deployStore(
            address(_authority), address(_core), address(_moduleRegistry), dupes
        ) returns (
            StreamTimeParameterStore
        ) {
            Assertions.assertTrue(false, "duplicate registration");
        } catch (bytes memory err) {
            Assertions.assertEq(
                keccak256(err),
                keccak256(
                    abi.encodeWithSelector(
                        IStreamTimeParameterHost.TimeParameterAlreadyRegistered.selector, TIMEOUT_ID
                    )
                ),
                "duplicate registration error"
            );
        }
    }

    function testCoreAndGenesisRegistryConstructorAdmission() public {
        IStreamTimeParameterHost.TimeParameterConfig[] memory configs =
            new IStreamTimeParameterHost.TimeParameterConfig[](1);
        configs[0] = _config("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 600, 300, 3_600);

        try this.deployStore(address(_authority), address(_core), address(0), configs) returns (
            StreamTimeParameterStore
        ) {
            Assertions.assertTrue(false, "zero registry");
        } catch (bytes memory err) {
            Assertions.assertEq(
                keccak256(err),
                keccak256(
                    abi.encodeWithSelector(
                        IStreamTimeParameterHost.TimeParameterInvalidModuleRegistry.selector,
                        address(0)
                    )
                ),
                "zero registry error"
            );
        }

        address registryEOA = vm.addr(0xA11CE);
        try this.deployStore(address(_authority), address(_core), registryEOA, configs) returns (
            StreamTimeParameterStore
        ) {
            Assertions.assertTrue(false, "registry EOA");
        } catch (bytes memory err) {
            Assertions.assertEq(
                keccak256(err),
                keccak256(
                    abi.encodeWithSelector(
                        IStreamTimeParameterHost.TimeParameterInvalidModuleRegistry.selector,
                        registryEOA
                    )
                ),
                "registry EOA error"
            );
        }

        try this.deployStore(
            address(_authority), address(0), address(_moduleRegistry), configs
        ) returns (
            StreamTimeParameterStore
        ) {
            Assertions.assertTrue(false, "zero core");
        } catch (bytes memory err) {
            Assertions.assertEq(
                keccak256(err),
                keccak256(
                    abi.encodeWithSelector(
                        IStreamTimeParameterHost.TimeParameterInvalidCore.selector, address(0)
                    )
                ),
                "zero core error"
            );
        }
    }

    function testEip7702DelegatedConstructorBindingsRejected() public {
        IStreamTimeParameterHost.TimeParameterConfig[] memory configs =
            new IStreamTimeParameterHost.TimeParameterConfig[](0);

        address delegatedAuthority = vm.addr(0x770211);
        vm.etch(delegatedAuthority, _eip7702Designation(address(_authority)));
        VmStorage(address(vm))
            .mockCall(
                delegatedAuthority,
                abi.encodeWithSelector(
                    IStreamGovernedParameterAuthority.isStreamGovernedParameterAuthority.selector
                ),
                abi.encode(true)
            );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterInvalidAuthority.selector, delegatedAuthority
            )
        );
        this.deployStore(delegatedAuthority, address(_core), address(_moduleRegistry), configs);

        address delegatedCore = vm.addr(0x770212);
        vm.etch(delegatedCore, _eip7702Designation(address(_core)));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterInvalidCore.selector, delegatedCore
            )
        );
        this.deployStore(address(_authority), delegatedCore, address(_moduleRegistry), configs);

        address delegatedRegistry = vm.addr(0x770213);
        vm.etch(delegatedRegistry, _eip7702Designation(address(_moduleRegistry)));
        VmStorage(address(vm))
            .mockCall(
                delegatedRegistry,
                abi.encodeWithSignature(
                    "supportsInterface(bytes4)", type(IStreamModuleRegistry).interfaceId
                ),
                abi.encode(true)
            );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterInvalidModuleRegistry.selector,
                delegatedRegistry
            )
        );
        this.deployStore(address(_authority), address(_core), delegatedRegistry, configs);
    }

    function testGenesisRegistryERC165AdmissionRejectsMalformedResponses() public {
        MockParameterModuleRegistry registry = new MockParameterModuleRegistry();

        registry.setRawInterfaceResponse(abi.encode(true), true);
        _expectInvalidGenesisRegistry(address(registry), "all-true ERC-165 response accepted");

        registry.setRawInterfaceResponse(bytes(""), true);
        _expectInvalidGenesisRegistry(address(registry), "empty response accepted");

        registry.setRawInterfaceResponse(abi.encode(false), true);
        _expectInvalidGenesisRegistry(address(registry), "false response accepted");

        registry.setRawInterfaceResponse(abi.encode(uint256(2)), true);
        _expectInvalidGenesisRegistry(address(registry), "dirty bool accepted");

        registry.setRawInterfaceResponse(new bytes(33), true);
        _expectInvalidGenesisRegistry(address(registry), "oversized response accepted");

        registry.setRawInterfaceResponse(bytes(""), false);
        registry.setInterfaceUnavailable(true);
        _expectInvalidGenesisRegistry(address(registry), "reverting response accepted");
    }

    function testGenesisAndLiveRegistryERC165ChecksForwardAvailableGas() public {
        MockParameterModuleRegistry registry = new MockParameterModuleRegistry();
        registry.setInterfaceGasToBurn(45_000);
        IStreamTimeParameterHost.TimeParameterConfig[] memory configs =
            new IStreamTimeParameterHost.TimeParameterConfig[](0);

        StreamTimeParameterStore store =
            this.deployStore(address(_authority), address(_core), address(registry), configs);
        _core.setLiveModuleRegistry(address(registry), address(_moduleRegistry));

        Assertions.assertEq(
            store.moduleRegistry(), address(registry), "high-gas live registry rejected"
        );
    }

    function testLiveRegistryERC165AdmissionRejectsAllTrue() public {
        MockParameterModuleRegistry registry = new MockParameterModuleRegistry();
        registry.setRawInterfaceResponse(abi.encode(true), true);
        _core.setLiveModuleRegistry(address(registry), address(_moduleRegistry));

        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterLiveModuleRegistryInvalid.selector,
                address(_core)
            )
        );
        _store.moduleRegistry();
    }

    function testRichTimeStoreRejectsItsOwnDeploymentAddressAsCore() public {
        IStreamTimeParameterHost.TimeParameterConfig[] memory configs =
            new IStreamTimeParameterHost.TimeParameterConfig[](0);
        try new SelfCoreTimeParameterStoreHarness(address(_moduleRegistry), configs) returns (
            SelfCoreTimeParameterStoreHarness
        ) {
            Assertions.assertTrue(false, "self Core accepted");
        } catch (bytes memory err) {
            bytes4 selector;
            assembly ("memory-safe") {
                selector := mload(add(err, 0x20))
            }
            Assertions.assertEq(
                uint256(uint32(selector)),
                uint256(uint32(IStreamTimeParameterHost.TimeParameterInvalidCore.selector)),
                "self Core error"
            );
        }
    }

    function testGenesisCommitmentAllowsNoRegistryRowAndPredictedProbe() public {
        // Remove the live row to prove construction does not call moduleRecord.
        _moduleRegistry.setStatus(address(_cadenceProbe), ModuleRegistryStatus.UNKNOWN);
        IStreamTimeParameterHost.TimeParameterConfig[] memory configs =
            new IStreamTimeParameterHost.TimeParameterConfig[](1);
        configs[0] = _config("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 600, 300, 3_600);
        StreamTimeParameterStore present = this.deployStore(
            address(_authority), address(_core), address(_moduleRegistry), configs
        );
        Assertions.assertEq(present.timeParameter(TIMEOUT_ID), 600, "present probe no row");

        address predictedProbe = vm.addr(0xC2EA7E);
        configs[0].cadenceProbe = predictedProbe;
        configs[0].expectedProbeRuntimeCodeHash = keccak256("predicted cadence runtime");
        configs[0].expectedProbeModuleManifestHash = keccak256("predicted cadence manifest");
        configs[0].expectedProbeDeploymentManifestHash = keccak256("predicted cadence deployment");
        StreamTimeParameterStore predicted = this.deployStore(
            address(_authority), address(_core), address(_moduleRegistry), configs
        );
        (,,, address boundProbe,,) = predicted.timeParameterInfo(TIMEOUT_ID);
        Assertions.assertEq(boundProbe, predictedProbe, "predicted cadence probe committed");

        _moduleRegistry.registerTimeProbe(address(_cadenceProbe));
    }

    function testEip7702DelegatedPresentGenesisProbeRejected() public {
        address delegatedProbe = vm.addr(0x770214);
        vm.etch(delegatedProbe, _eip7702Designation(address(_cadenceProbe)));
        VmStorage(address(vm))
            .mockCall(
                delegatedProbe,
                abi.encodeWithSelector(
                    IStreamTimeParameterProbe.pinnedWallClockFloorSeconds.selector, TIMEOUT_ID
                ),
                abi.encode(uint64(3_600))
            );

        IStreamTimeParameterHost.TimeParameterConfig memory config =
            _config("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 600, 300, 3_600);
        config.cadenceProbe = delegatedProbe;
        config.expectedProbeRuntimeCodeHash = delegatedProbe.codehash;
        _expectDeployRevert(
            config,
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterProbeBindingInvalid.selector,
                TIMEOUT_ID,
                delegatedProbe
            ),
            "delegated present cadence probe accepted"
        );
    }

    function testEip7702DelegatedLiveProbeRejected() public {
        address delegatedProbe = vm.addr(0x770215);
        vm.etch(delegatedProbe, _eip7702Designation(address(_cadenceProbe)));
        VmStorage(address(vm))
            .mockCall(
                delegatedProbe,
                abi.encodeWithSelector(
                    IStreamTimeParameterProbe.pinnedWallClockFloorSeconds.selector, TIMEOUT_ID
                ),
                abi.encode(uint64(3_600))
            );
        _moduleRegistry.registerTimeProbe(delegatedProbe);

        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterProbeBindingInvalid.selector,
                TIMEOUT_ID,
                delegatedProbe
            )
        );
        _store.rebindTimeParameterProbe(TIMEOUT_ID, delegatedProbe);
    }

    function testEip7702DelegatedLiveRegistryPointerRejected() public {
        address delegatedRegistry = vm.addr(0x770216);
        vm.etch(delegatedRegistry, _eip7702Designation(address(_moduleRegistry)));
        _core.setLiveModuleRegistry(delegatedRegistry, address(_moduleRegistry));

        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterLiveModuleRegistryInvalid.selector,
                address(_core)
            )
        );
        _store.moduleRegistry();
    }

    function testGenesisCommitmentRejectsPresentCodeFloorAndHashMismatch() public {
        IStreamTimeParameterHost.TimeParameterConfig memory config =
            _config("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 600, 300, 3_600);
        config.expectedProbeRuntimeCodeHash = keccak256("wrong cadence runtime");
        _expectDeployRevert(
            config,
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterProbeBindingInvalid.selector,
                TIMEOUT_ID,
                address(_cadenceProbe)
            ),
            "wrong expected runtime accepted"
        );

        config = _config("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 600, 300, 9_999);
        _expectDeployRevert(
            config,
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterProbeMismatch.selector,
                TIMEOUT_ID,
                address(_cadenceProbe)
            ),
            "wrong floor pin accepted"
        );
    }

    function testGenesisCommitmentRejectsZeroExpectedFacts() public {
        IStreamTimeParameterHost.TimeParameterConfig memory config =
            _config("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 600, 300, 3_600);
        bytes memory expectedError = abi.encodeWithSelector(
            IStreamTimeParameterHost.TimeParameterInvalidConfig.selector, TIMEOUT_ID
        );

        config.expectedProbeModuleVersion = bytes32(0);
        _expectDeployRevert(config, expectedError, "zero expected version accepted");

        config = _config("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 600, 300, 3_600);
        config.expectedProbeRuntimeCodeHash = bytes32(0);
        _expectDeployRevert(config, expectedError, "zero expected runtime accepted");

        config = _config("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 600, 300, 3_600);
        config.expectedProbeModuleManifestHash = bytes32(0);
        _expectDeployRevert(config, expectedError, "zero expected module manifest accepted");

        config = _config("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 600, 300, 3_600);
        config.expectedProbeDeploymentManifestHash = bytes32(0);
        _expectDeployRevert(config, expectedError, "zero expected deployment manifest accepted");
    }

    function testPrePointerReadsAndOrdinaryRaiseWorkWhileLowerAndRebindFailClosed() public {
        MockParameterCorePointer uninitializedCore = new MockParameterCorePointer();
        IStreamTimeParameterHost.TimeParameterConfig[] memory configs =
            new IStreamTimeParameterHost.TimeParameterConfig[](1);
        configs[0] = _config("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 600, 300, 3_600);
        StreamTimeParameterStore store = new StreamTimeParameterStore(
            address(_authority), address(uninitializedCore), address(_moduleRegistry), configs
        );

        Assertions.assertEq(store.timeParameter(TIMEOUT_ID), 600, "pre-pointer read");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterLiveModuleRegistryInvalid.selector,
                address(uninitializedCore)
            )
        );
        store.moduleRegistry();

        TimeStateView memory state = _timeState(store, TIMEOUT_ID);
        bytes32 scopeHash = _scopeHash(store, TIMEOUT_ID);
        _authority.setCurrentAction(
            true,
            ACTION_ID,
            DELAYED_LOOSENING,
            scopeHash,
            _stateHash(scopeHash, state, 600, address(_cadenceProbe), 1),
            _stateHash(scopeHash, state, 1_000, address(_cadenceProbe), 2)
        );
        vm.prank(address(_authority));
        store.raiseTimeParameter(TIMEOUT_ID, 1_000);
        Assertions.assertEq(store.timeParameter(TIMEOUT_ID), 1_000, "ordinary raise");

        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterLiveModuleRegistryInvalid.selector,
                address(uninitializedCore)
            )
        );
        store.lowerTimeParameter(TIMEOUT_ID, 500);

        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterLiveModuleRegistryInvalid.selector,
                address(uninitializedCore)
            )
        );
        store.rebindTimeParameterProbe(TIMEOUT_ID, address(_cadenceProbe));
    }

    function testMalformedPointerAndV2RecordResponsesFailClosed() public {
        _core.setRawPointerResponse(new bytes(319));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterLiveModuleRegistryInvalid.selector,
                address(_core)
            )
        );
        _store.moduleRegistry();

        _core.setRawPointerResponse(new bytes(321));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterLiveModuleRegistryInvalid.selector,
                address(_core)
            )
        );
        _store.moduleRegistry();

        bytes memory dirtyPointer = abi.encode(
            address(_moduleRegistry),
            address(_moduleRegistry).codehash,
            false,
            keccak256("MODULE_REGISTRY"),
            type(IStreamModuleRegistry).interfaceId,
            address(_moduleRegistry),
            uint8(ModuleRegistryStatus.ACTIVE),
            keccak256("module manifest"),
            keccak256("deployment manifest"),
            uint64(1)
        );
        assembly ("memory-safe") {
            mstore(add(dirtyPointer, 0x60), 2)
        }
        _core.setRawPointerResponse(dirtyPointer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterLiveModuleRegistryInvalid.selector,
                address(_core)
            )
        );
        _store.moduleRegistry();

        bytes memory zeroRevisionPointer = abi.encode(
            address(_moduleRegistry),
            address(_moduleRegistry).codehash,
            false,
            keccak256("MODULE_REGISTRY"),
            type(IStreamModuleRegistry).interfaceId,
            address(_moduleRegistry),
            uint8(ModuleRegistryStatus.ACTIVE),
            keccak256("module manifest"),
            keccak256("deployment manifest"),
            uint64(0)
        );
        _core.setRawPointerResponse(zeroRevisionPointer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterLiveModuleRegistryInvalid.selector,
                address(_core)
            )
        );
        _store.moduleRegistry();

        _core.setLiveModuleRegistry(address(_moduleRegistry), address(_moduleRegistry));
        _moduleRegistry.setRevision(address(_cadenceProbe), 0);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterProbeBindingInvalid.selector,
                TIMEOUT_ID,
                address(_cadenceProbe)
            )
        );
        _store.lowerTimeParameter(TIMEOUT_ID, 300);

        _moduleRegistry.registerTimeProbe(address(_cadenceProbe));
        _moduleRegistry.setRawModuleRecordResponse(hex"00", true);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterProbeBindingInvalid.selector,
                TIMEOUT_ID,
                address(_cadenceProbe)
            )
        );
        _store.lowerTimeParameter(TIMEOUT_ID, 300);

        _moduleRegistry.setRawModuleRecordResponse(bytes(""), false);
        (bool ok, bytes memory dirtyRecord) = address(_moduleRegistry)
            .staticcall(
                abi.encodeWithSelector(
                    IStreamModuleRegistry.moduleRecord.selector, address(_cadenceProbe)
                )
            );
        Assertions.assertTrue(ok, "canonical V2 record read");
        assembly ("memory-safe") {
            mstore(add(dirtyRecord, 0x40), 0x101)
        }
        _moduleRegistry.setRawModuleRecordResponse(dirtyRecord, true);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterProbeBindingInvalid.selector,
                TIMEOUT_ID,
                address(_cadenceProbe)
            )
        );
        _store.lowerTimeParameter(TIMEOUT_ID, 300);

        _moduleRegistry.setRawModuleRecordResponse(new bytes(2_497), true);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterProbeBindingInvalid.selector,
                TIMEOUT_ID,
                address(_cadenceProbe)
            )
        );
        _store.lowerTimeParameter(TIMEOUT_ID, 300);
    }

    function testV2RecordManifestUriBounds() public {
        bytes memory bindingError = abi.encodeWithSelector(
            IStreamTimeParameterHost.TimeParameterProbeBindingInvalid.selector,
            TIMEOUT_ID,
            address(_cadenceProbe)
        );

        _moduleRegistry.setModuleManifestURI(address(_cadenceProbe), "");
        vm.prank(address(_authority));
        vm.expectRevert(bindingError);
        _store.lowerTimeParameter(TIMEOUT_ID, 300);

        _moduleRegistry.setModuleManifestURI(address(_cadenceProbe), _asciiString(2_049));
        vm.prank(address(_authority));
        vm.expectRevert(bindingError);
        _store.lowerTimeParameter(TIMEOUT_ID, 300);

        _moduleRegistry.setModuleManifestURI(address(_cadenceProbe), _asciiString(2_048));
        _finalizeSample(12);
        _cadenceProbe.recordCadenceRun(TIMEOUT_ID, 300);
        _armValueChange(_store, TIMEOUT_ID, 300, ACTION_ID);
        vm.prank(address(_authority));
        _store.lowerTimeParameter(TIMEOUT_ID, 300);
        Assertions.assertEq(_store.timeParameter(TIMEOUT_ID), 300, "2,048-byte URI accepted");
    }

    function testRegistryAToBSameAddressTimeRebindAndOldAUnavailable() public {
        MockParameterModuleRegistry successorRegistry = new MockParameterModuleRegistry();
        successorRegistry.registerTimeProbe(address(_cadenceProbe));

        TimeStateView memory state = _timeState(_store, TIMEOUT_ID);
        bytes32 scopeHash = _scopeHash(_store, TIMEOUT_ID);
        bytes32 oldStateHash = _stateHashAtRegistry(
            _moduleRegistry, scopeHash, state, state.value, state.cadenceProbe, state.revision
        );
        bytes32 newStateHash = _stateHashAtRegistry(
            successorRegistry, scopeHash, state, state.value, state.cadenceProbe, state.revision + 1
        );

        _core.setLiveModuleRegistry(address(successorRegistry), address(_moduleRegistry));
        _authority.setCurrentAction(
            true, ACTION_ID, POINTER_REPLACEMENT, scopeHash, oldStateHash, newStateHash
        );
        vm.prank(address(_authority));
        _store.rebindTimeParameterProbe(TIMEOUT_ID, state.cadenceProbe);

        _finalizeSample(12);
        _cadenceProbe.recordCadenceRun(TIMEOUT_ID, 300);
        TimeStateView memory rebound = _timeState(_store, TIMEOUT_ID);
        oldStateHash = _stateHashAtRegistry(
            successorRegistry,
            scopeHash,
            rebound,
            rebound.value,
            rebound.cadenceProbe,
            rebound.revision
        );
        newStateHash = _stateHashAtRegistry(
            successorRegistry, scopeHash, rebound, 300, rebound.cadenceProbe, rebound.revision + 1
        );
        _authority.setCurrentAction(
            true, ACTION_ID, DELAYED_LOOSENING, scopeHash, oldStateHash, newStateHash
        );
        _moduleRegistry.setUnavailable(true);
        Assertions.assertEq(
            _store.moduleRegistry(), address(successorRegistry), "successor registry live"
        );
        vm.prank(address(_authority));
        _store.lowerTimeParameter(TIMEOUT_ID, 300);
        Assertions.assertEq(_store.timeParameter(TIMEOUT_ID), 300, "old registry not consulted");
    }

    function testProbeDependentLowerRejectsRegistryRevocationAndBindingDrift() public {
        _finalizeSample(12);
        _cadenceProbe.recordCadenceRun(TIMEOUT_ID, 300);

        _moduleRegistry.setStatus(address(_cadenceProbe), ModuleRegistryStatus.DEPRECATED);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterProbeBindingInvalid.selector,
                TIMEOUT_ID,
                address(_cadenceProbe)
            )
        );
        _store.lowerTimeParameter(TIMEOUT_ID, 300);

        _moduleRegistry.setStatus(address(_cadenceProbe), ModuleRegistryStatus.ACTIVE);
        MockParameterModuleRecordV2 memory record =
            _moduleRegistry.moduleRecord(address(_cadenceProbe));
        _moduleRegistry.setManifestHashes(
            address(_cadenceProbe),
            keccak256("drifted-module-manifest"),
            record.deploymentManifestHash
        );
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterProbeBindingInvalid.selector,
                TIMEOUT_ID,
                address(_cadenceProbe)
            )
        );
        _store.lowerTimeParameter(TIMEOUT_ID, 300);
    }

    function testProbeRebindRejectsInactiveAndExactNoopButAllowsBindingRefresh() public {
        StreamCadenceProbe successor = _newProbe();
        _moduleRegistry.setStatus(address(successor), ModuleRegistryStatus.DEPRECATED);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterProbeBindingInvalid.selector,
                TIMEOUT_ID,
                address(successor)
            )
        );
        _store.rebindTimeParameterProbe(TIMEOUT_ID, address(successor));

        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterProbeRebindNoOp.selector,
                TIMEOUT_ID,
                address(_cadenceProbe)
            )
        );
        _store.rebindTimeParameterProbe(TIMEOUT_ID, address(_cadenceProbe));

        TimeStateView memory beforeRefresh = _timeState(_store, TIMEOUT_ID);
        bytes32 scopeHash = _scopeHash(_store, TIMEOUT_ID);
        bytes32 oldStateHash = _stateHash(
            scopeHash,
            beforeRefresh,
            beforeRefresh.value,
            beforeRefresh.cadenceProbe,
            beforeRefresh.revision
        );
        MockParameterModuleRecordV2 memory record =
            _moduleRegistry.moduleRecord(address(_cadenceProbe));
        _moduleRegistry.setManifestHashes(
            address(_cadenceProbe),
            keccak256("successor-registry-binding"),
            record.deploymentManifestHash
        );
        bytes32 newStateHash = _stateHash(
            scopeHash,
            beforeRefresh,
            beforeRefresh.value,
            beforeRefresh.cadenceProbe,
            beforeRefresh.revision + 1
        );
        _authority.setCurrentAction(
            true, ACTION_ID, POINTER_REPLACEMENT, scopeHash, oldStateHash, newStateHash
        );
        vm.prank(address(_authority));
        _store.rebindTimeParameterProbe(TIMEOUT_ID, address(_cadenceProbe));
        TimeStateView memory afterRefresh = _timeState(_store, TIMEOUT_ID);
        Assertions.assertEq(
            uint256(afterRefresh.revision), uint256(beforeRefresh.revision + 1), "refresh revision"
        );
    }

    function testAuthorityMarkerAndGovernanceOnly() public {
        // Bad marker rejected at construction.
        MockGovernedParameterAuthority badAuthority = new MockGovernedParameterAuthority(false);
        IStreamTimeParameterHost.TimeParameterConfig[] memory configs =
            new IStreamTimeParameterHost.TimeParameterConfig[](1);
        configs[0] = _config("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 600, 300, 3_600);
        try this.deployStore(
            address(badAuthority), address(_core), address(_moduleRegistry), configs
        ) returns (
            StreamTimeParameterStore
        ) {
            Assertions.assertTrue(false, "bad authority marker");
        } catch (bytes memory err) {
            Assertions.assertEq(
                keccak256(err),
                keccak256(
                    abi.encodeWithSelector(
                        IStreamTimeParameterHost.TimeParameterInvalidAuthority.selector,
                        address(badAuthority)
                    )
                ),
                "bad authority marker error"
            );
        }

        // Non-authority callers rejected on both change paths.
        address stranger = vm.addr(0xABCD);
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterNotAuthority.selector, stranger
            )
        );
        _store.raiseTimeParameter(TIMEOUT_ID, 1_200);
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterNotAuthority.selector, stranger
            )
        );
        _store.lowerTimeParameter(TIMEOUT_ID, 300);

        // A zero-authority time store has no live change path at all: GTPs have
        // no lost-governance machinery ([LTA-GTP] change discipline 1).
        StreamTimeParameterStore zeroStore =
            this.deployStore(address(0), address(_core), address(_moduleRegistry), configs);
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterNotAuthority.selector, stranger
            )
        );
        zeroStore.raiseTimeParameter(TIMEOUT_ID, 1_200);
    }

    // ------------------------------------------------------------------
    // Governance-V2 target-owned context and anti-replay checks
    // ------------------------------------------------------------------

    function testRaiseRejectsEveryForgedGovernanceContextField() public {
        (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash) =
            _valueTransitionHashes(_store, TIMEOUT_ID, 900);

        _authority.clearCurrentAction();
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterActionNotExecuting.selector
            )
        );
        _store.raiseTimeParameter(TIMEOUT_ID, 900);

        _authority.setCurrentAction(
            true, bytes32(0), DELAYED_LOOSENING, scopeHash, oldStateHash, newStateHash
        );
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamTimeParameterHost.TimeParameterActionIdZero.selector)
        );
        _store.raiseTimeParameter(TIMEOUT_ID, 900);

        _authority.setCurrentAction(true, ACTION_ID, 6, scopeHash, oldStateHash, newStateHash);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterActionClassMismatch.selector,
                DELAYED_LOOSENING,
                uint8(6)
            )
        );
        _store.raiseTimeParameter(TIMEOUT_ID, 900);

        bytes32 forgedScopeHash = keccak256("forged-scope");
        _authority.setCurrentAction(
            true, ACTION_ID, DELAYED_LOOSENING, forgedScopeHash, oldStateHash, newStateHash
        );
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterScopeHashMismatch.selector,
                scopeHash,
                forgedScopeHash
            )
        );
        _store.raiseTimeParameter(TIMEOUT_ID, 900);

        bytes32 forgedOldStateHash = keccak256("forged-old-state");
        _authority.setCurrentAction(
            true, ACTION_ID, DELAYED_LOOSENING, scopeHash, forgedOldStateHash, newStateHash
        );
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterOldStateHashMismatch.selector,
                oldStateHash,
                forgedOldStateHash
            )
        );
        _store.raiseTimeParameter(TIMEOUT_ID, 900);

        bytes32 forgedNewStateHash = keccak256("forged-new-state");
        _authority.setCurrentAction(
            true, ACTION_ID, DELAYED_LOOSENING, scopeHash, oldStateHash, forgedNewStateHash
        );
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterNewStateHashMismatch.selector,
                newStateHash,
                forgedNewStateHash
            )
        );
        _store.raiseTimeParameter(TIMEOUT_ID, 900);
    }

    function testLowerAndProbeRebindRejectEmergencyOrWrongClasses() public {
        _finalizeSample(12);
        _cadenceProbe.recordCadenceRun(TIMEOUT_ID, 300);
        (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash) =
            _valueTransitionHashes(_store, TIMEOUT_ID, 300);
        _authority.setCurrentAction(true, ACTION_ID, 6, scopeHash, oldStateHash, newStateHash);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterActionClassMismatch.selector,
                DELAYED_LOOSENING,
                uint8(6)
            )
        );
        _store.lowerTimeParameter(TIMEOUT_ID, 300);

        StreamCadenceProbe successor = _newProbe();
        (scopeHash, oldStateHash, newStateHash) =
            _probeRebindTransitionHashes(_store, TIMEOUT_ID, address(successor));
        _authority.setCurrentAction(true, ACTION_ID, 6, scopeHash, oldStateHash, newStateHash);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterActionClassMismatch.selector,
                POINTER_REPLACEMENT,
                uint8(6)
            )
        );
        _store.rebindTimeParameterProbe(TIMEOUT_ID, address(successor));

        _authority.setCurrentAction(
            true, ACTION_ID, DELAYED_LOOSENING, scopeHash, oldStateHash, newStateHash
        );
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterActionClassMismatch.selector,
                POINTER_REPLACEMENT,
                DELAYED_LOOSENING
            )
        );
        _store.rebindTimeParameterProbe(TIMEOUT_ID, address(successor));
    }

    function testLowerRejectsEveryForgedGovernanceContextField() public {
        _finalizeSample(12);
        _cadenceProbe.recordCadenceRun(TIMEOUT_ID, 300);
        (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash) =
            _valueTransitionHashes(_store, TIMEOUT_ID, 300);

        _authority.clearCurrentAction();
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterActionNotExecuting.selector
            )
        );
        _store.lowerTimeParameter(TIMEOUT_ID, 300);

        _authority.setCurrentAction(
            true, bytes32(0), DELAYED_LOOSENING, scopeHash, oldStateHash, newStateHash
        );
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamTimeParameterHost.TimeParameterActionIdZero.selector)
        );
        _store.lowerTimeParameter(TIMEOUT_ID, 300);

        bytes32 forgedScopeHash = keccak256("forged-lower-scope");
        _authority.setCurrentAction(
            true, ACTION_ID, DELAYED_LOOSENING, forgedScopeHash, oldStateHash, newStateHash
        );
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterScopeHashMismatch.selector,
                scopeHash,
                forgedScopeHash
            )
        );
        _store.lowerTimeParameter(TIMEOUT_ID, 300);

        bytes32 forgedOldStateHash = keccak256("forged-lower-old-state");
        _authority.setCurrentAction(
            true, ACTION_ID, DELAYED_LOOSENING, scopeHash, forgedOldStateHash, newStateHash
        );
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterOldStateHashMismatch.selector,
                oldStateHash,
                forgedOldStateHash
            )
        );
        _store.lowerTimeParameter(TIMEOUT_ID, 300);

        bytes32 forgedNewStateHash = keccak256("forged-lower-new-state");
        _authority.setCurrentAction(
            true, ACTION_ID, DELAYED_LOOSENING, scopeHash, oldStateHash, forgedNewStateHash
        );
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterNewStateHashMismatch.selector,
                newStateHash,
                forgedNewStateHash
            )
        );
        _store.lowerTimeParameter(TIMEOUT_ID, 300);
    }

    function testProbeRebindRejectsEveryForgedGovernanceContextField() public {
        StreamCadenceProbe successor = _newProbe();
        (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash) =
            _probeRebindTransitionHashes(_store, TIMEOUT_ID, address(successor));

        _authority.clearCurrentAction();
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterActionNotExecuting.selector
            )
        );
        _store.rebindTimeParameterProbe(TIMEOUT_ID, address(successor));

        _authority.setCurrentAction(
            true, bytes32(0), POINTER_REPLACEMENT, scopeHash, oldStateHash, newStateHash
        );
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamTimeParameterHost.TimeParameterActionIdZero.selector)
        );
        _store.rebindTimeParameterProbe(TIMEOUT_ID, address(successor));

        bytes32 forgedScopeHash = keccak256("forged-rebind-scope");
        _authority.setCurrentAction(
            true, ACTION_ID, POINTER_REPLACEMENT, forgedScopeHash, oldStateHash, newStateHash
        );
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterScopeHashMismatch.selector,
                scopeHash,
                forgedScopeHash
            )
        );
        _store.rebindTimeParameterProbe(TIMEOUT_ID, address(successor));

        bytes32 forgedOldStateHash = keccak256("forged-rebind-old-state");
        _authority.setCurrentAction(
            true, ACTION_ID, POINTER_REPLACEMENT, scopeHash, forgedOldStateHash, newStateHash
        );
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterOldStateHashMismatch.selector,
                oldStateHash,
                forgedOldStateHash
            )
        );
        _store.rebindTimeParameterProbe(TIMEOUT_ID, address(successor));

        bytes32 forgedNewStateHash = keccak256("forged-rebind-new-state");
        _authority.setCurrentAction(
            true, ACTION_ID, POINTER_REPLACEMENT, scopeHash, oldStateHash, forgedNewStateHash
        );
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterNewStateHashMismatch.selector,
                newStateHash,
                forgedNewStateHash
            )
        );
        _store.rebindTimeParameterProbe(TIMEOUT_ID, address(successor));

        TimeStateView memory state = _timeState(_store, TIMEOUT_ID);
        Assertions.assertEq(state.cadenceProbe, address(_cadenceProbe), "binding unchanged");
        Assertions.assertEq(uint256(state.revision), 1, "revision unchanged");
    }

    function testRevisionBlocksStaleSameValueABAAction() public {
        (bytes32 staleScopeHash, bytes32 staleOldStateHash, bytes32 staleNewStateHash) =
            _valueTransitionHashes(_store, TIMEOUT_ID, 900);

        _armValueChange(_store, TIMEOUT_ID, 900, keccak256("intervening-raise"));
        vm.prank(address(_authority));
        _store.raiseTimeParameter(TIMEOUT_ID, 900);
        Assertions.assertEq(uint256(_timeState(_store, TIMEOUT_ID).revision), 2, "raise revision");

        _finalizeSample(12);
        _cadenceProbe.recordCadenceRun(TIMEOUT_ID, 600);
        _armValueChange(_store, TIMEOUT_ID, 600, keccak256("intervening-lower"));
        vm.prank(address(_authority));
        _store.lowerTimeParameter(TIMEOUT_ID, 600);
        TimeStateView memory current = _timeState(_store, TIMEOUT_ID);
        Assertions.assertEq(current.value, 600, "ABA restored value");
        Assertions.assertEq(uint256(current.revision), 3, "ABA advanced revision");

        bytes32 currentOldStateHash = _stateHash(
            staleScopeHash, current, current.value, current.cadenceProbe, current.revision
        );
        _authority.setCurrentAction(
            true, ACTION_ID, DELAYED_LOOSENING, staleScopeHash, staleOldStateHash, staleNewStateHash
        );
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterOldStateHashMismatch.selector,
                currentOldStateHash,
                staleOldStateHash
            )
        );
        _store.raiseTimeParameter(TIMEOUT_ID, 900);
    }

    function testRevisionBlocksStaleProbeBindingABAAction() public {
        StreamCadenceProbe successor = _newProbe();
        (bytes32 staleScopeHash, bytes32 staleOldStateHash, bytes32 staleNewStateHash) =
            _probeRebindTransitionHashes(_store, TIMEOUT_ID, address(successor));

        _armProbeRebind(
            _store, TIMEOUT_ID, address(successor), keccak256("intervening-rebind-to-b")
        );
        vm.prank(address(_authority));
        _store.rebindTimeParameterProbe(TIMEOUT_ID, address(successor));
        TimeStateView memory state = _timeState(_store, TIMEOUT_ID);
        Assertions.assertEq(state.cadenceProbe, address(successor), "binding moved A to B");
        Assertions.assertEq(uint256(state.revision), 2, "A to B revision");

        _armProbeRebind(
            _store, TIMEOUT_ID, address(_cadenceProbe), keccak256("intervening-rebind-to-a")
        );
        vm.prank(address(_authority));
        _store.rebindTimeParameterProbe(TIMEOUT_ID, address(_cadenceProbe));
        state = _timeState(_store, TIMEOUT_ID);
        Assertions.assertEq(state.cadenceProbe, address(_cadenceProbe), "binding restored to A");
        Assertions.assertEq(uint256(state.revision), 3, "B to A revision");

        (, bytes32 currentOldStateHash,) =
            _probeRebindTransitionHashes(_store, TIMEOUT_ID, address(successor));
        _authority.setCurrentAction(
            true,
            ACTION_ID,
            POINTER_REPLACEMENT,
            staleScopeHash,
            staleOldStateHash,
            staleNewStateHash
        );
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterOldStateHashMismatch.selector,
                currentOldStateHash,
                staleOldStateHash
            )
        );
        _store.rebindTimeParameterProbe(TIMEOUT_ID, address(successor));
    }

    function testRevisionOverflowRevertsInsteadOfWrapping() public {
        // `_timeParameters` is the host's first ordinary storage variable. In
        // its packed value, slot + 3 holds probeMaxAgeBlocks then revision.
        bytes32 parameterBase = keccak256(abi.encode(TIMEOUT_ID, uint256(0)));
        bytes32 packedRecencyAndRevision =
            bytes32(uint256(MAX_AGE) | (uint256(type(uint64).max) << 64));
        VmStorage(address(vm))
            .store(address(_store), bytes32(uint256(parameterBase) + 3), packedRecencyAndRevision);
        Assertions.assertEq(
            uint256(_timeState(_store, TIMEOUT_ID).revision),
            uint256(type(uint64).max),
            "revision forced to maximum"
        );

        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterRevisionOverflow.selector, TIMEOUT_ID
            )
        );
        _store.raiseTimeParameter(TIMEOUT_ID, 900);
    }

    // ------------------------------------------------------------------
    // Raise/lower bounds ([LTA-GTP] change discipline 2)
    // ------------------------------------------------------------------

    function testRaiseBounds() public {
        // Not a raise.
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterNotARaise.selector,
                TIMEOUT_ID,
                uint256(600),
                uint256(600)
            )
        );
        _store.raiseTimeParameter(TIMEOUT_ID, 600);

        // 2x + 1 rejected.
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterRaiseBoundExceeded.selector,
                TIMEOUT_ID,
                uint256(600),
                uint256(1_201)
            )
        );
        _store.raiseTimeParameter(TIMEOUT_ID, 1_201);

        // Exactly 2x accepted; no cadence record is required for a raise.
        _armValueChange(_store, TIMEOUT_ID, 1_200, ACTION_ID);
        vm.prank(address(_authority));
        _store.raiseTimeParameter(TIMEOUT_ID, 1_200);
        Assertions.assertEq(_store.timeParameter(TIMEOUT_ID), 1_200, "raise applied");

        // Unknown parameter.
        bytes32 unknownId = keccak256("unknown");
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterUnknown.selector, unknownId
            )
        );
        _store.raiseTimeParameter(unknownId, 100);
    }

    function testLowerHalfBoundAndFloorRejection() public {
        // Below half the current value per action: rejected before any probe
        // consultation.
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterLowerBoundExceeded.selector,
                SLO_ID,
                uint256(1_200),
                uint256(599)
            )
        );
        _store.lowerTimeParameter(SLO_ID, 599);

        // Within the half bound but below the immutable block floor: rejected
        // even with a passing cadence record at the proposed value.
        _finalizeSample(12);
        _cadenceProbe.recordCadenceRun(SLO_ID, 649);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterBelowFloor.selector,
                SLO_ID,
                uint256(649),
                uint256(650)
            )
        );
        _store.lowerTimeParameter(SLO_ID, 649);

        // Not a lower.
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterNotALower.selector,
                SLO_ID,
                uint256(1_200),
                uint256(1_200)
            )
        );
        _store.lowerTimeParameter(SLO_ID, 1_200);

        // Exactly half, at the block floor, with a passing record: accepted
        // (TIMEOUT row: 600 -> 300 covers 3600s at 12s cadence exactly).
        _cadenceProbe.recordCadenceRun(TIMEOUT_ID, 300);
        _armValueChange(_store, TIMEOUT_ID, 300, ACTION_ID);
        vm.prank(address(_authority));
        _store.lowerTimeParameter(TIMEOUT_ID, 300);
        Assertions.assertEq(_store.timeParameter(TIMEOUT_ID), 300, "boundary lower applied");
    }

    // ------------------------------------------------------------------
    // Cadence-probe-gated lowering ([LTA-GTP] change discipline 3; wall-clock
    // floor binding in both directions per change discipline 7)
    // ------------------------------------------------------------------

    function testLowerCadenceProbeGates() public {
        // No recorded run at the proposed value.
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterProbeRecordMissing.selector,
                SLO_ID,
                uint256(700)
            )
        );
        _store.lowerTimeParameter(SLO_ID, 700);

        // Fast cadence (6s/block): 700 blocks cover 4200s < the 7200s wall-clock
        // floor, so the run records failed and the lower is rejected — a
        // consensus acceleration cannot silently shrink the window's wall-clock
        // meaning.
        _finalizeSample(6);
        (, bool passed) = _cadenceProbe.recordCadenceRun(SLO_ID, 700);
        Assertions.assertFalse(passed, "candidate fails at fast cadence");
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterProbeNotPassing.selector, SLO_ID, uint256(700)
            )
        );
        _store.lowerTimeParameter(SLO_ID, 700);

        // At the observed 12s cadence, 700 blocks cover 8400s >= 7200s: the run
        // passes and the lower executes.
        _finalizeSample(12);
        (, passed) = _cadenceProbe.recordCadenceRun(SLO_ID, 700);
        Assertions.assertTrue(passed, "candidate passes at normal cadence");
        _armValueChange(_store, SLO_ID, 700, ACTION_ID);
        vm.prank(address(_authority));
        _store.lowerTimeParameter(SLO_ID, 700);
        Assertions.assertEq(_store.timeParameter(SLO_ID), 700, "cadence-gated lower applied");

        // A stale passing record no longer admits.
        (, passed) = _cadenceProbe.recordCadenceRun(SLO_ID, 660);
        Assertions.assertTrue(passed, "fresh record at 660");
        uint64 recordedAt = uint64(block.number);
        vm.roll(block.number + MAX_AGE + 1);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterProbeRecordStale.selector,
                SLO_ID,
                uint256(660),
                recordedAt,
                MAX_AGE
            )
        );
        _store.lowerTimeParameter(SLO_ID, 660);
    }

    // ------------------------------------------------------------------
    // Cadence probe mechanics ([LTA-GTP] definition item 6)
    // ------------------------------------------------------------------

    function testCadenceSampleMechanics() public {
        // Anyone can observe; a maturing sample cannot be restarted.
        vm.prank(vm.addr(0x51));
        _cadenceProbe.startCadenceSample();
        vm.prank(vm.addr(0x52));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamCadenceProbe.StreamCadenceProbeSampleAlreadyPending.selector,
                uint64(block.number)
            )
        );
        _cadenceProbe.startCadenceSample();

        // A shortened observation can never finalize.
        uint64 startBlock = uint64(block.number);
        vm.roll(block.number + WINDOW - 1);
        vm.warp(block.timestamp + (WINDOW - 1) * 12);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamCadenceProbe.StreamCadenceProbeSampleImmature.selector,
                startBlock,
                startBlock + WINDOW
            )
        );
        _cadenceProbe.finalizeCadenceSample();

        // At the full window it finalizes and records the observation.
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
        vm.recordLogs();
        vm.prank(vm.addr(0x53));
        _cadenceProbe.finalizeCadenceSample();
        (uint64 endBlock, uint64 blocksElapsed, uint64 secondsElapsed) =
            _cadenceProbe.latestCadenceSample();
        Assertions.assertEq(uint256(endBlock), block.number, "sample end block");
        Assertions.assertEq(uint256(blocksElapsed), uint256(WINDOW), "sample width");
        Assertions.assertEq(uint256(secondsElapsed), uint256(WINDOW) * 12, "sample seconds");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Assertions.assertEq(logs.length, 1, "sample event");
        Assertions.assertEq(
            logs[0].topics[0],
            keccak256("CadenceSampleRecorded(uint16,uint64,uint64,uint64)"),
            "sample event signature"
        );

        // Nothing left pending.
        vm.expectRevert(
            abi.encodeWithSelector(StreamCadenceProbe.StreamCadenceProbeNoPendingSample.selector)
        );
        _cadenceProbe.finalizeCadenceSample();

        // A window with no elapsed wall-clock time cannot record.
        StreamCadenceProbe fresh = _newProbe();
        fresh.startCadenceSample();
        vm.roll(block.number + WINDOW);
        vm.expectRevert(
            abi.encodeWithSelector(StreamCadenceProbe.StreamCadenceProbeDegenerateSample.selector)
        );
        fresh.finalizeCadenceSample();
    }

    function testCadenceCandidateValidation() public {
        // No finalized sample yet.
        vm.expectRevert(
            abi.encodeWithSelector(StreamCadenceProbe.StreamCadenceProbeNoSample.selector)
        );
        _cadenceProbe.recordCadenceRun(TIMEOUT_ID, 300);

        _finalizeSample(12);

        // Unserved parameter.
        bytes32 unknownId = keccak256("unknown");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamCadenceProbe.StreamCadenceProbeUnknownParameter.selector, unknownId
            )
        );
        _cadenceProbe.recordCadenceRun(unknownId, 300);

        // Zero candidate.
        vm.expectRevert(
            abi.encodeWithSelector(StreamCadenceProbe.StreamCadenceProbeInvalidCandidate.selector)
        );
        _cadenceProbe.recordCadenceRun(TIMEOUT_ID, 0);

        // A stale observation cannot back a candidate verdict.
        (uint64 endBlock,,) = _cadenceProbe.latestCadenceSample();
        vm.roll(block.number + MAX_AGE + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamCadenceProbe.StreamCadenceProbeSampleStale.selector, endBlock, MAX_AGE
            )
        );
        _cadenceProbe.recordCadenceRun(TIMEOUT_ID, 300);

        // A fresh observation restores candidate runs; verdicts land on the
        // wall-clock boundary exactly.
        _finalizeSample(12);
        (, bool passed) = _cadenceProbe.recordCadenceRun(TIMEOUT_ID, 300);
        Assertions.assertTrue(passed, "300 blocks x 12s == 3600s floor");
        (, passed) = _cadenceProbe.recordCadenceRun(TIMEOUT_ID, 299);
        Assertions.assertFalse(passed, "299 blocks x 12s < 3600s floor");
    }

    function testCadenceProbeERC165Identity() public view {
        Assertions.assertEq(
            uint256(uint32(type(IStreamTimeParameterProbe).interfaceId)),
            uint256(uint32(TIME_PARAMETER_PROBE_INTERFACE_ID)),
            "canonical cadence interface id"
        );
        Assertions.assertTrue(
            _cadenceProbe.supportsInterface(type(IStreamTimeParameterProbe).interfaceId),
            "cadence interface supported"
        );
        Assertions.assertTrue(
            _cadenceProbe.supportsInterface(type(IERC165).interfaceId), "ERC165 supported"
        );
        Assertions.assertFalse(
            _cadenceProbe.supportsInterface(0xffffffff), "invalid interface rejected"
        );
    }

    function testCadenceProbeConstructorGuards() public {
        string[] memory names = new string[](1);
        names[0] = "ENTROPY_REQUEST_TIMEOUT_BLOCKS";
        uint64[] memory floors = new uint64[](1);
        floors[0] = 3_600;

        // Window below CADENCE_SAMPLE_FLOOR_BLOCKS.
        try new StreamCadenceProbe(names, floors, 999, MAX_AGE) returns (StreamCadenceProbe) {
            Assertions.assertTrue(false, "window below floor");
        } catch (bytes memory err) {
            Assertions.assertEq(
                keccak256(err),
                keccak256(
                    abi.encodeWithSelector(
                        StreamCadenceProbe.StreamCadenceProbeInvalidConfig.selector
                    )
                ),
                "window below floor error"
            );
        }
        // Sample max age below the window.
        try new StreamCadenceProbe(names, floors, WINDOW, WINDOW - 1) returns (StreamCadenceProbe) {
            Assertions.assertTrue(false, "max age below window");
        } catch (bytes memory err) {
            Assertions.assertEq(
                keccak256(err),
                keccak256(
                    abi.encodeWithSelector(
                        StreamCadenceProbe.StreamCadenceProbeInvalidConfig.selector
                    )
                ),
                "max age below window error"
            );
        }
        // Zero wall-clock pin.
        uint64[] memory zeroFloors = new uint64[](1);
        zeroFloors[0] = 0;
        try new StreamCadenceProbe(names, zeroFloors, WINDOW, MAX_AGE) returns (
            StreamCadenceProbe
        ) {
            Assertions.assertTrue(false, "zero pin");
        } catch (bytes memory err) {
            Assertions.assertEq(
                keccak256(err),
                keccak256(
                    abi.encodeWithSelector(
                        StreamCadenceProbe.StreamCadenceProbeInvalidConfig.selector
                    )
                ),
                "zero pin error"
            );
        }
        // Length mismatch.
        uint64[] memory twoFloors = new uint64[](2);
        twoFloors[0] = 3_600;
        twoFloors[1] = 7_200;
        try new StreamCadenceProbe(names, twoFloors, WINDOW, MAX_AGE) returns (StreamCadenceProbe) {
            Assertions.assertTrue(false, "length mismatch");
        } catch (bytes memory err) {
            Assertions.assertEq(
                keccak256(err),
                keccak256(
                    abi.encodeWithSelector(
                        StreamCadenceProbe.StreamCadenceProbeInvalidConfig.selector
                    )
                ),
                "length mismatch error"
            );
        }
        // Duplicate row.
        string[] memory dupeNames = new string[](2);
        dupeNames[0] = "ENTROPY_REQUEST_TIMEOUT_BLOCKS";
        dupeNames[1] = "ENTROPY_REQUEST_TIMEOUT_BLOCKS";
        try new StreamCadenceProbe(dupeNames, twoFloors, WINDOW, MAX_AGE) returns (
            StreamCadenceProbe
        ) {
            Assertions.assertTrue(false, "duplicate row");
        } catch (bytes memory err) {
            Assertions.assertEq(
                keccak256(err),
                keccak256(
                    abi.encodeWithSelector(
                        StreamCadenceProbe.StreamCadenceProbeInvalidConfig.selector
                    )
                ),
                "duplicate row error"
            );
        }
    }

    // ------------------------------------------------------------------
    // Canonical event schemas ([LTA-GTP] change discipline 4)
    // ------------------------------------------------------------------

    function testTimeParameterUpdatedEventSchema() public {
        _armValueChange(_store, TIMEOUT_ID, 900, ACTION_ID);
        vm.recordLogs();
        vm.prank(address(_authority));
        _store.raiseTimeParameter(TIMEOUT_ID, 900);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        Assertions.assertEq(logs.length, 1, "single event");
        Assertions.assertEq(logs[0].emitter, address(_store), "emitted by host");
        Assertions.assertEq(logs[0].topics.length, 4, "three indexed topics");
        Assertions.assertEq(logs[0].topics[0], TIME_PARAMETER_UPDATED_TOPIC, "canonical signature");
        Assertions.assertEq(logs[0].topics[1], TIMEOUT_ID, "parameterId topic");
        Assertions.assertEq(
            logs[0].topics[2], bytes32(uint256(uint160(address(_store)))), "host topic"
        );
        Assertions.assertEq(logs[0].topics[3], ACTION_ID, "actionId topic");
        (uint16 schemaVersion, uint256 oldValue, uint256 newValue, uint256 floor) =
            abi.decode(logs[0].data, (uint16, uint256, uint256, uint256));
        Assertions.assertEq(uint256(schemaVersion), 1, "schema version");
        Assertions.assertEq(oldValue, 600, "old value");
        Assertions.assertEq(newValue, 900, "new value");
        Assertions.assertEq(floor, 300, "block floor");
    }

    function testTimeParameterProbedEventSchema() public {
        _finalizeSample(12);
        vm.recordLogs();
        (bytes32 probeRunId, bool passed) = _cadenceProbe.recordCadenceRun(TIMEOUT_ID, 300);
        Assertions.assertTrue(passed, "boundary pass");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        Assertions.assertEq(logs.length, 1, "single probe event");
        Assertions.assertEq(logs[0].emitter, address(_cadenceProbe), "record lives on the probe");
        Assertions.assertEq(logs[0].topics.length, 3, "two indexed topics");
        Assertions.assertEq(logs[0].topics[0], TIME_PARAMETER_PROBED_TOPIC, "canonical signature");
        Assertions.assertEq(logs[0].topics[1], TIMEOUT_ID, "parameterId topic");
        Assertions.assertEq(logs[0].topics[2], probeRunId, "probeRunId topic");
        (uint16 schemaVersion, bool eventPassed, uint256 probedValue, bytes32 evidenceHash) =
            abi.decode(logs[0].data, (uint16, bool, uint256, bytes32));
        Assertions.assertEq(uint256(schemaVersion), 1, "schema version");
        Assertions.assertTrue(eventPassed, "event passed flag");
        Assertions.assertEq(probedValue, 300, "event probed value");
        Assertions.assertTrue(evidenceHash != bytes32(0), "evidence committed");

        // The record is consumable through the canonical read.
        (bytes32 storedRunId, bool storedPassed, uint64 probedAtBlock) =
            _cadenceProbe.lastProbeRun(TIMEOUT_ID, 300);
        Assertions.assertEq(storedRunId, probeRunId, "record stored");
        Assertions.assertTrue(storedPassed, "record verdict");
        Assertions.assertEq(uint256(probedAtBlock), block.number, "record block");
    }

    // ------------------------------------------------------------------
    // Governed cadence-probe rebinding ([LTA-GGP-PROBES] rule 3)
    // ------------------------------------------------------------------

    function testCadenceProbeRebindRejections() public {
        StreamCadenceProbe successor = _newProbe();
        address stranger = vm.addr(0x888);

        // Authority-only.
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterNotAuthority.selector, stranger
            )
        );
        _store.rebindTimeParameterProbe(TIMEOUT_ID, address(successor));

        // Unknown parameter.
        bytes32 unknownId = keccak256("unknown");
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterUnknown.selector, unknownId
            )
        );
        _store.rebindTimeParameterProbe(unknownId, address(successor));

        // Zero successor.
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterProbeMismatch.selector, TIMEOUT_ID, address(0)
            )
        );
        _store.rebindTimeParameterProbe(TIMEOUT_ID, address(0));

        // A successor pinning a different wall-clock floor for the row cannot be
        // bound: the width a candidate must prove can never drift.
        StreamCadenceProbe wrongPinProbe = _singleRowProbe("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 9_999);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterProbeMismatch.selector,
                TIMEOUT_ID,
                address(wrongPinProbe)
            )
        );
        _store.rebindTimeParameterProbe(TIMEOUT_ID, address(wrongPinProbe));

        // A probe not serving the row at all is likewise rejected.
        StreamCadenceProbe unservingProbe = _singleRowProbe("ENTROPY_REVEAL_SLO_BLOCKS", 7_200);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterProbeMismatch.selector,
                TIMEOUT_ID,
                address(unservingProbe)
            )
        );
        _store.rebindTimeParameterProbe(TIMEOUT_ID, address(unservingProbe));
    }

    function testCadenceProbeRebindGovernedPathAndEventSchema() public {
        StreamCadenceProbe successor = _newProbe();

        // Governed rebind executes, moves the binding, and emits the
        // schema-versioned rebind event.
        _armProbeRebind(_store, TIMEOUT_ID, address(successor), ACTION_ID);
        vm.recordLogs();
        vm.prank(address(_authority));
        _store.rebindTimeParameterProbe(TIMEOUT_ID, address(successor));
        (,,, address boundProbe,,) = _store.timeParameterInfo(TIMEOUT_ID);
        Assertions.assertEq(boundProbe, address(successor), "binding moved");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        Assertions.assertEq(logs.length, 1, "single rebind event");
        Assertions.assertEq(logs[0].emitter, address(_store), "emitted by host");
        Assertions.assertEq(logs[0].topics.length, 4, "three indexed topics");
        Assertions.assertEq(
            logs[0].topics[0], TIME_PARAMETER_PROBE_REBOUND_TOPIC, "rebind signature"
        );
        Assertions.assertEq(logs[0].topics[1], TIMEOUT_ID, "parameterId topic");
        Assertions.assertEq(
            logs[0].topics[2], bytes32(uint256(uint160(address(_store)))), "host topic"
        );
        Assertions.assertEq(logs[0].topics[3], ACTION_ID, "actionId topic");
        (uint16 schemaVersion, address oldProbe, address newProbe) =
            abi.decode(logs[0].data, (uint16, address, address));
        Assertions.assertEq(uint256(schemaVersion), 1, "schema version");
        Assertions.assertEq(oldProbe, address(_cadenceProbe), "old probe");
        Assertions.assertEq(newProbe, address(successor), "new probe");

        // Execution rechecks consult the successor: a passing record on the OLD
        // probe no longer admits a lower...
        _finalizeSample(12);
        _cadenceProbe.recordCadenceRun(TIMEOUT_ID, 400);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterProbeRecordMissing.selector,
                TIMEOUT_ID,
                uint256(400)
            )
        );
        _store.lowerTimeParameter(TIMEOUT_ID, 400);

        // ...while a passing record on the successor does.
        successor.startCadenceSample();
        vm.roll(block.number + WINDOW);
        vm.warp(block.timestamp + WINDOW * 12);
        successor.finalizeCadenceSample();
        (, bool passed) = successor.recordCadenceRun(TIMEOUT_ID, 400);
        Assertions.assertTrue(passed, "successor run passes");
        _armValueChange(_store, TIMEOUT_ID, 400, ACTION_ID);
        vm.prank(address(_authority));
        _store.lowerTimeParameter(TIMEOUT_ID, 400);
        Assertions.assertEq(_store.timeParameter(TIMEOUT_ID), 400, "successor drives gates");
    }

    function testCadenceProbeRebindDeadWithGovernanceLost() public {
        // With governance lost (zero authority) the binding is frozen — which is
        // why every cadence probe is Permanent-class ([LTA-GGP-PROBES] rule 3).
        StreamCadenceProbe successor = _newProbe();
        address stranger = vm.addr(0x889);
        IStreamTimeParameterHost.TimeParameterConfig[] memory configs =
            new IStreamTimeParameterHost.TimeParameterConfig[](1);
        configs[0] = _config("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 600, 300, 3_600);
        StreamTimeParameterStore zeroStore =
            this.deployStore(address(0), address(_core), address(_moduleRegistry), configs);

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterNotAuthority.selector, stranger
            )
        );
        zeroStore.rebindTimeParameterProbe(TIMEOUT_ID, address(successor));
        (,,, address frozenProbe,,) = zeroStore.timeParameterInfo(TIMEOUT_ID);
        Assertions.assertEq(frozenProbe, address(_cadenceProbe), "binding frozen");
    }

    // ------------------------------------------------------------------
    // No emergency / no permissionless conditional path exists for GTPs
    // ([LTA-GTP] change discipline 1; ADR 0012 decision T1)
    // ------------------------------------------------------------------

    function testGovernanceV2WriterSelectorGoldens() public pure {
        Assertions.assertEq(
            uint256(uint32(IStreamGovernedParameterAuthority.currentAction.selector)),
            uint256(uint32(0x546ea281)),
            "six-return currentAction selector"
        );
        Assertions.assertEq(
            uint256(uint32(IStreamTimeParameterHost.timeParameterInfo.selector)),
            uint256(uint32(0x5f2463b8)),
            "info selector"
        );
        Assertions.assertEq(
            uint256(uint32(IStreamTimeParameterHost.raiseTimeParameter.selector)),
            uint256(uint32(0x046e1fd5)),
            "raise selector"
        );
        Assertions.assertEq(
            uint256(uint32(IStreamTimeParameterHost.lowerTimeParameter.selector)),
            uint256(uint32(0xa4e24c49)),
            "lower selector"
        );
        Assertions.assertEq(
            uint256(uint32(IStreamTimeParameterHost.rebindTimeParameterProbe.selector)),
            uint256(uint32(0xc07b3459)),
            "class-3 manifest-tail trigger selector"
        );
    }

    function testCadenceProbeBindingManifestVectorGolden() public pure {
        bytes32 bindingHash = keccak256(
            abi.encode(
                GGP_PROBE_BINDING_V1,
                address(0x7c90C2A8B5C68deC87bc792423fF2047Daf34526),
                address(0xf671a26eF8866fa4EDA48ffe08b87e9c017698D7),
                bytes32(0x3199d2e98228ed2205303455974f594fcf19602b1f986e0687c568d9925d2ee4),
                bytes4(0xb6c57592),
                bytes32(0x2bfa0192d2880def76c7aefcd8944eb25ff55400603d111496d7f9ee3418e073),
                bytes32(0x6f12d0a70f20831a00f832893734ddb0336b215e0cf8cd1624a1534cef0aeb02),
                bytes32(0x87ca2a1f11e99f9b2396f2b53f63992f403a045a3a7cd116d1f8c54ae317541e),
                bytes32(0xc35b448ac1a5be9889a3fb597640708ac18286b63bf98d31139892d1ed713641)
            )
        );
        Assertions.assertEq(
            bindingHash,
            0xd48ab772d538d6bb4ba37bf36dcfe740632f932b0fac9ea082b237dc98f82b80,
            "system-manifest cadence binding vector"
        );
    }

    function testNoEmergencyOrConditionalPathOnTimeStore() public {
        bytes[] memory attempts = new bytes[](7);
        attempts[0] = abi.encodeWithSignature(
            "emergencyRaiseTimeParameter(bytes32,uint256,bytes32)",
            TIMEOUT_ID,
            uint256(1_200),
            ACTION_ID
        );
        attempts[1] = abi.encodeWithSignature(
            "emergencyRaiseTimeParameter(bytes32,uint256)", TIMEOUT_ID, uint256(1_200)
        );
        attempts[2] = abi.encodeWithSignature(
            "raiseTimeParameter(bytes32,uint256,bytes32)", TIMEOUT_ID, uint256(1_200), ACTION_ID
        );
        attempts[3] = abi.encodeWithSignature(
            "lowerTimeParameter(bytes32,uint256,bytes32)", TIMEOUT_ID, uint256(300), ACTION_ID
        );
        attempts[4] = abi.encodeWithSignature(
            "rebindTimeParameterProbe(bytes32,address,bytes32)",
            TIMEOUT_ID,
            address(_cadenceProbe),
            ACTION_ID
        );
        attempts[5] = abi.encodeWithSignature(
            "conditionalRaiseTimeParameter(bytes32,uint256)", TIMEOUT_ID, uint256(1_200)
        );
        attempts[6] = abi.encodeWithSignature(
            "conditionalRelowerTimeParameter(bytes32,uint256)", TIMEOUT_ID, uint256(300)
        );
        for (uint256 i = 0; i < attempts.length; i++) {
            (bool ok,) = address(_store).call(attempts[i]);
            Assertions.assertFalse(ok, "no such change path exists");
        }
        Assertions.assertEq(_store.timeParameter(TIMEOUT_ID), 600, "value untouched");
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    function _armValueChange(
        StreamTimeParameterStore store,
        bytes32 parameterId,
        uint256 newValue,
        bytes32 actionId
    ) private {
        (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash) =
            _valueTransitionHashes(store, parameterId, newValue);
        _authority.setCurrentAction(
            true, actionId, DELAYED_LOOSENING, scopeHash, oldStateHash, newStateHash
        );
    }

    function _armProbeRebind(
        StreamTimeParameterStore store,
        bytes32 parameterId,
        address newCadenceProbe,
        bytes32 actionId
    ) private {
        (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash) =
            _probeRebindTransitionHashes(store, parameterId, newCadenceProbe);
        _authority.setCurrentAction(
            true, actionId, POINTER_REPLACEMENT, scopeHash, oldStateHash, newStateHash
        );
    }

    function _valueTransitionHashes(
        StreamTimeParameterStore store,
        bytes32 parameterId,
        uint256 newValue
    ) private view returns (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash) {
        TimeStateView memory state = _timeState(store, parameterId);
        scopeHash = _scopeHash(store, parameterId);
        oldStateHash = _stateHash(scopeHash, state, state.value, state.cadenceProbe, state.revision);
        newStateHash =
            _stateHash(scopeHash, state, newValue, state.cadenceProbe, state.revision + 1);
    }

    function _probeRebindTransitionHashes(
        StreamTimeParameterStore store,
        bytes32 parameterId,
        address newCadenceProbe
    ) private view returns (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash) {
        TimeStateView memory state = _timeState(store, parameterId);
        scopeHash = _scopeHash(store, parameterId);
        oldStateHash = _stateHash(scopeHash, state, state.value, state.cadenceProbe, state.revision);
        newStateHash =
            _stateHash(scopeHash, state, state.value, newCadenceProbe, state.revision + 1);
    }

    function _timeState(StreamTimeParameterStore store, bytes32 parameterId)
        private
        view
        returns (TimeStateView memory state)
    {
        (
            state.value,
            state.floorBlocks,
            state.wallClockFloorSeconds,
            state.cadenceProbe,
            state.probeMaxAgeBlocks,
            state.revision
        ) = store.timeParameterInfo(parameterId);
    }

    function _scopeHash(StreamTimeParameterStore store, bytes32 parameterId)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(TIME_PARAMETER_SCOPE_V1, block.chainid, address(store), parameterId)
        );
    }

    function _stateHash(
        bytes32 scopeHash,
        TimeStateView memory state,
        uint256 value,
        address cadenceProbe,
        uint64 revision
    ) private view returns (bytes32) {
        return _stateHashAtRegistry(
            _moduleRegistry, scopeHash, state, value, cadenceProbe, revision
        );
    }

    function _stateHashAtRegistry(
        MockParameterModuleRegistry registry,
        bytes32 scopeHash,
        TimeStateView memory state,
        uint256 value,
        address cadenceProbe,
        uint64 revision
    ) private view returns (bytes32) {
        MockParameterModuleRecordV2 memory record = registry.moduleRecord(cadenceProbe);
        bytes32 runtimeCodeHash = cadenceProbe.codehash;
        bytes32 bindingHash = keccak256(
            abi.encode(
                GGP_PROBE_BINDING_V1,
                address(registry),
                cadenceProbe,
                record.moduleType,
                record.interfaceId,
                record.moduleVersion,
                runtimeCodeHash,
                record.moduleManifestHash,
                record.deploymentManifestHash
            )
        );
        return keccak256(
            abi.encode(
                TIME_PARAMETER_STATE_V1,
                scopeHash,
                value,
                state.floorBlocks,
                state.wallClockFloorSeconds,
                cadenceProbe,
                runtimeCodeHash,
                bindingHash,
                state.probeMaxAgeBlocks,
                revision
            )
        );
    }

    function _newProbe() private returns (StreamCadenceProbe) {
        string[] memory names = new string[](3);
        names[0] = "ENTROPY_REQUEST_TIMEOUT_BLOCKS";
        names[1] = "ENTROPY_REVEAL_SLO_BLOCKS";
        names[2] = "ENTROPY_RECOVERY_STEP_DELAY_BLOCKS";
        uint64[] memory floors = new uint64[](3);
        floors[0] = 3_600;
        floors[1] = 7_200;
        floors[2] = 1_800;
        StreamCadenceProbe probe = new StreamCadenceProbe(names, floors, WINDOW, MAX_AGE);
        _moduleRegistry.registerTimeProbe(address(probe));
        return probe;
    }

    function _singleRowProbe(string memory name, uint64 wallClockFloorSeconds)
        private
        returns (StreamCadenceProbe)
    {
        string[] memory names = new string[](1);
        names[0] = name;
        uint64[] memory floors = new uint64[](1);
        floors[0] = wallClockFloorSeconds;
        StreamCadenceProbe probe = new StreamCadenceProbe(names, floors, WINDOW, MAX_AGE);
        _moduleRegistry.registerTimeProbe(address(probe));
        return probe;
    }

    function _config(
        string memory name,
        uint256 genesisValue,
        uint256 floorBlocks,
        uint64 wallClockFloorSeconds
    ) private view returns (IStreamTimeParameterHost.TimeParameterConfig memory) {
        return IStreamTimeParameterHost.TimeParameterConfig({
            name: name,
            genesisValue: genesisValue,
            floorBlocks: floorBlocks,
            wallClockFloorSeconds: wallClockFloorSeconds,
            cadenceProbe: address(_cadenceProbe),
            probeMaxAgeBlocks: MAX_AGE,
            expectedProbeModuleVersion: bytes32(uint256(1)),
            expectedProbeRuntimeCodeHash: address(_cadenceProbe).codehash,
            expectedProbeModuleManifestHash: keccak256(
                abi.encode("module", address(_cadenceProbe))
            ),
            expectedProbeDeploymentManifestHash: keccak256(
                abi.encode("deployment", address(_cadenceProbe))
            )
        });
    }

    function _eip7702Designation(address delegate) private pure returns (bytes memory) {
        return abi.encodePacked(hex"ef0100", bytes20(delegate));
    }

    function _asciiString(uint256 length) private pure returns (string memory) {
        bytes memory value = new bytes(length);
        for (uint256 i; i < length; ++i) {
            value[i] = "a";
        }
        return string(value);
    }

    /// @dev Observes a full sampling window at `secondsPerBlock` cadence and
    ///      finalizes it as the probe's latest sample.
    function _finalizeSample(uint256 secondsPerBlock) private {
        _cadenceProbe.startCadenceSample();
        vm.roll(block.number + WINDOW);
        vm.warp(block.timestamp + WINDOW * secondsPerBlock);
        _cadenceProbe.finalizeCadenceSample();
    }
}
