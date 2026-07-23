// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/IStreamGasParameterHost.sol";
import "../smart-contracts/IStreamModuleRegistry.sol";
import "../smart-contracts/StreamGasParameterStore.sol";
import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";
import "./helpers/GovernedParameterTestMocks.sol";

interface VmGasStorage {
    function store(address target, bytes32 slot, bytes32 value) external;
    function mockCall(address callee, bytes calldata data, bytes calldata returnData) external;
}

contract SelfCoreGasParameterStoreHarness is StreamGasParameterStore {
    constructor(address genesisRegistry, GasParameterConfig[] memory configs)
        StreamGasParameterStore(address(0), address(this), genesisRegistry, configs)
    { }
}

/// @notice [LTA-GGP] requirement 9 host-side conformance matrix: floor rejection,
///         2x per-action raise bound, staged vs probe-gated emergency raise,
///         probe-gated lower at exactly the proposed value, permissionless
///         conditional raise and re-lower with no governance signer for
///         FORWARDING_CAP, scope rejection for FAIL_CLOSED_PRECHECK and
///         MIN_GAS_GATE, gasParameterInfo introspection, canonical change-event
///         schema, and parameterId derivation goldens.
contract StreamGasParameterStoreTest is CharacterizationTestBase {
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

    struct ProbeBindingFacts {
        address probe;
        bytes32 runtimeCodeHash;
        bytes32 bindingHash;
    }

    uint256 private constant START_BLOCK = 1_000_000;
    uint64 private constant MAX_AGE = 50_400;
    bytes32 private constant ACTION_ID = keccak256("test-governance-action");

    // Spec-pinned parameterIds (docs/launch-v1-target-architecture.md identifier
    // catalog; recomputed with `cast keccak` over the string preimages).
    bytes32 private constant ROYALTY_RESOLVER_ID =
        0x9bae92ab1dd0c5535c65125ea4ee7cff3d55fc31fc2555096c2b5eabceb5bcda;
    bytes32 private constant MINT_GATE_ID =
        0xf896db78d4fb703c92d45856189181cb6daa113dada9718f74206095d4fbf817;
    bytes32 private constant FLUSH_GAS_FLOOR_ID =
        0x99168b87a7d39f5ba4862568c012ad3b51c552ec78108b88c6be5f5a6426ebe6;
    bytes32 private constant ENTROPY_REGISTRATION_ID =
        0x51125071e3dfb233a2711689d4cc377bbda429f1356ebc09a58d763548541e17;
    bytes32 private constant VRF_CALLBACK_ID =
        0xb54bc37de6ab63d94434a3fb47e0b24ad67118105c91c59db7b1c58d482f5491;
    bytes32 private constant SALE_ERC1271_ID =
        0x17b207440a43ce0136b5ee0bc3becf37652825825d88c68e1e0750bf59ec914c;
    bytes32 private constant METADATA_ROUTER_ID =
        0x02ad62929eaa837b9d1704745193125454925fd11a6bf273d7bb1faa23272e93;
    bytes32 private constant FINALITY_COMPONENT_READ_ID =
        0xbf54fb4ba4a0942771e26fe4b1f829f8324f6f98ef66e080fd6885b75bdf3221;
    bytes32 private constant ASSET_POLICY_ID =
        0xbfc1f824948b8dc9573791fa40eeb403e7322af41d0967f90518dbbb531bf648;

    // keccak256("GasParameterUpdated(uint16,bytes32,address,bytes32,uint256,uint256,uint256)")
    bytes32 private constant GAS_PARAMETER_UPDATED_TOPIC =
        0x587835584450495af0ebae742cc2f7c3927ade7498ab91baaebb9525d68e14dc;
    // keccak256("GasParameterProbeRebound(uint16,bytes32,address,bytes32,address,address)")
    bytes32 private constant GAS_PARAMETER_PROBE_REBOUND_TOPIC =
        0x339eac0706e5da05ad5682ba742c71b7309497f7e138f8db2e1c022c76bfab8c;

    MockGovernedParameterAuthority private _authority;
    MockParameterCorePointer private _core;
    MockParameterModuleRegistry private _moduleRegistry;
    MockGasProbe private _forwardingProbe;
    MockGasProbe private _mintGateProbe;
    MockGasProbe private _flushFloorProbe;
    MockGasProbe private _zeroStoreProbe;
    StreamGasParameterStore private _store;
    StreamGasParameterStore private _zeroAuthorityStore;

    function setUp() public {
        vm.roll(START_BLOCK);
        _authority = new MockGovernedParameterAuthority(true);
        _core = new MockParameterCorePointer();
        _moduleRegistry = new MockParameterModuleRegistry();
        _forwardingProbe = new MockGasProbe("ROYALTY_RESOLVER_GAS_LIMIT");
        _mintGateProbe = new MockGasProbe("MINT_GATE_GAS_LIMIT");
        _flushFloorProbe = new MockGasProbe("FLUSH_GAS_FLOOR");
        _zeroStoreProbe = new MockGasProbe("ROYALTY_RESOLVER_GAS_LIMIT");
        IStreamGasParameterHost.GasParameterConfig[] memory configs =
            new IStreamGasParameterHost.GasParameterConfig[](3);
        configs[0] =
            _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, address(_forwardingProbe), 1);
        configs[1] = _config("MINT_GATE_GAS_LIMIT", 400_000, 100_000, address(_mintGateProbe), 2);
        configs[2] = _config("FLUSH_GAS_FLOOR", 80_000, 40_000, address(_flushFloorProbe), 3);
        _store = new StreamGasParameterStore(
            address(_authority), address(_core), address(_moduleRegistry), configs
        );

        IStreamGasParameterHost.GasParameterConfig[] memory zeroConfigs =
            new IStreamGasParameterHost.GasParameterConfig[](1);
        zeroConfigs[0] =
            _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, address(_zeroStoreProbe), 1);
        _zeroAuthorityStore = new StreamGasParameterStore(
            address(0), address(_core), address(_moduleRegistry), zeroConfigs
        );

        // Genesis construction above commits expected facts without reading a
        // registry row. The rows and Core pointer become live only afterward.
        _registerProbe(address(_forwardingProbe));
        _registerProbe(address(_mintGateProbe));
        _registerProbe(address(_flushFloorProbe));
        _registerProbe(address(_zeroStoreProbe));
        _core.setLiveModuleRegistry(address(_moduleRegistry), address(_moduleRegistry));
    }

    // ------------------------------------------------------------------
    // parameterId derivation goldens ([LTA-GGP] definition item 5)
    // ------------------------------------------------------------------

    function testParameterIdDerivationGoldens() public view {
        Assertions.assertEq(
            keccak256(abi.encodePacked("6529STREAM_GGP_", "ROYALTY_RESOLVER_GAS_LIMIT")),
            ROYALTY_RESOLVER_ID,
            "royalty resolver id"
        );
        Assertions.assertEq(
            keccak256(abi.encodePacked("6529STREAM_GGP_", "MINT_GATE_GAS_LIMIT")),
            MINT_GATE_ID,
            "mint gate id"
        );
        Assertions.assertEq(
            keccak256(abi.encodePacked("6529STREAM_GGP_", "FLUSH_GAS_FLOOR")),
            FLUSH_GAS_FLOOR_ID,
            "flush gas floor id"
        );
        Assertions.assertEq(
            keccak256(abi.encodePacked("6529STREAM_GGP_", "ENTROPY_REGISTRATION_GAS_LIMIT")),
            ENTROPY_REGISTRATION_ID,
            "entropy registration id"
        );
        Assertions.assertEq(
            keccak256(abi.encodePacked("6529STREAM_GGP_", "VRF_CALLBACK_GAS_LIMIT")),
            VRF_CALLBACK_ID,
            "vrf callback id"
        );
        Assertions.assertEq(
            keccak256(abi.encodePacked("6529STREAM_GGP_", "SALE_ERC1271_GAS_LIMIT")),
            SALE_ERC1271_ID,
            "sale erc1271 id"
        );
        Assertions.assertEq(
            keccak256(abi.encodePacked("6529STREAM_GGP_", "METADATA_ROUTER_GAS_LIMIT")),
            METADATA_ROUTER_ID,
            "metadata router id"
        );
        Assertions.assertEq(
            keccak256(abi.encodePacked("6529STREAM_GGP_", "FINALITY_COMPONENT_READ_GAS")),
            FINALITY_COMPONENT_READ_ID,
            "finality component read id"
        );
        Assertions.assertEq(
            keccak256(abi.encodePacked("6529STREAM_GGP_", "ASSET_POLICY_GAS_LIMIT")),
            ASSET_POLICY_ID,
            "asset policy id"
        );

        // The host derives ids from registered names, so the registered rows
        // carry the pinned ids by construction.
        bytes32[] memory ids = _store.gasParameterIds();
        Assertions.assertEq(ids.length, 3, "registered count");
        Assertions.assertEq(ids[0], ROYALTY_RESOLVER_ID, "registered forwarding id");
        Assertions.assertEq(ids[1], MINT_GATE_ID, "registered mint gate id");
        Assertions.assertEq(ids[2], FLUSH_GAS_FLOOR_ID, "registered flush floor id");
    }

    function testGovernanceV2WriterSelectorGoldens() public pure {
        Assertions.assertEq(
            uint256(uint32(IStreamGasParameterHost.gasParameterInfo.selector)),
            uint256(uint32(bytes4(0xec2ef90a))),
            "gas-parameter info selector"
        );
        Assertions.assertEq(
            uint256(uint32(IStreamGasParameterHost.raiseGasParameter.selector)),
            uint256(uint32(bytes4(0x5c0df7da))),
            "two-argument raise selector"
        );
        Assertions.assertEq(
            uint256(uint32(IStreamGasParameterHost.emergencyRaiseGasParameter.selector)),
            uint256(uint32(bytes4(0x4fa1b5ad))),
            "two-argument emergency selector"
        );
        Assertions.assertEq(
            uint256(uint32(IStreamGasParameterHost.lowerGasParameter.selector)),
            uint256(uint32(bytes4(0x908dc981))),
            "two-argument lower selector"
        );
        Assertions.assertEq(
            uint256(uint32(IStreamGasParameterHost.rebindGasParameterProbe.selector)),
            uint256(uint32(bytes4(0xb98f30e0))),
            "two-argument rebind selector"
        );
        Assertions.assertEq(
            uint256(uint32(IStreamGasParameterHost.conditionalRaiseGasParameter.selector)),
            uint256(uint32(bytes4(0x0671a369))),
            "conditional raise selector"
        );
        Assertions.assertEq(
            uint256(uint32(IStreamGasParameterHost.conditionalRelowerGasParameter.selector)),
            uint256(uint32(bytes4(0x59bf6beb))),
            "conditional re-lower selector"
        );
    }

    function testLegacyThreeArgumentWriterAbisAreAbsent() public {
        bytes[] memory legacyCalls = new bytes[](4);
        legacyCalls[0] = abi.encodeWithSelector(
            bytes4(keccak256("raiseGasParameter(bytes32,uint256,bytes32)")),
            MINT_GATE_ID,
            uint256(500_000),
            ACTION_ID
        );
        legacyCalls[1] = abi.encodeWithSelector(
            bytes4(keccak256("emergencyRaiseGasParameter(bytes32,uint256,bytes32)")),
            MINT_GATE_ID,
            uint256(500_000),
            ACTION_ID
        );
        legacyCalls[2] = abi.encodeWithSelector(
            bytes4(keccak256("lowerGasParameter(bytes32,uint256,bytes32)")),
            MINT_GATE_ID,
            uint256(200_000),
            ACTION_ID
        );
        legacyCalls[3] = abi.encodeWithSelector(
            bytes4(keccak256("rebindGasParameterProbe(bytes32,address,bytes32)")),
            MINT_GATE_ID,
            address(_forwardingProbe),
            ACTION_ID
        );
        for (uint256 i; i < legacyCalls.length; ++i) {
            vm.prank(address(_authority));
            (bool ok,) = address(_store).call(legacyCalls[i]);
            Assertions.assertFalse(ok, "legacy writer ABI must not survive V2 cutover");
        }
        Assertions.assertEq(_store.gasParameter(MINT_GATE_ID), 400_000, "state unchanged");
        (,, address probe,,,) = _store.gasParameterInfo(MINT_GATE_ID);
        Assertions.assertEq(probe, address(_mintGateProbe), "probe unchanged");
    }

    // ------------------------------------------------------------------
    // Introspection ([LTA-GGP] requirement 12)
    // ------------------------------------------------------------------

    function testGasParameterInfoGoldenAndUnknownZeroed() public view {
        (
            uint256 value,
            uint256 floor,
            address probe,
            uint8 failureClass,
            uint64 maxAge,
            uint64 revision
        ) = _store.gasParameterInfo(ROYALTY_RESOLVER_ID);
        Assertions.assertEq(value, 50_000, "fc value");
        Assertions.assertEq(floor, 10_000, "fc floor");
        Assertions.assertEq(probe, address(_forwardingProbe), "fc probe");
        Assertions.assertEq(uint256(failureClass), 1, "fc class FORWARDING_CAP");
        Assertions.assertEq(uint256(maxAge), uint256(MAX_AGE), "fc max age");
        Assertions.assertEq(uint256(revision), 1, "fc genesis revision");

        (value, floor, probe, failureClass, maxAge, revision) =
            _store.gasParameterInfo(MINT_GATE_ID);
        Assertions.assertEq(value, 400_000, "fcp value");
        Assertions.assertEq(floor, 100_000, "fcp floor");
        Assertions.assertEq(probe, address(_mintGateProbe), "fcp probe");
        Assertions.assertEq(uint256(failureClass), 2, "fcp class FAIL_CLOSED_PRECHECK");
        Assertions.assertEq(uint256(maxAge), uint256(MAX_AGE), "fcp max age");
        Assertions.assertEq(uint256(revision), 1, "fcp genesis revision");

        (value, floor, probe, failureClass, maxAge, revision) =
            _store.gasParameterInfo(FLUSH_GAS_FLOOR_ID);
        Assertions.assertEq(value, 80_000, "mgg value");
        Assertions.assertEq(floor, 40_000, "mgg floor");
        Assertions.assertEq(probe, address(_flushFloorProbe), "mgg probe");
        Assertions.assertEq(uint256(failureClass), 3, "mgg class MIN_GAS_GATE");
        Assertions.assertEq(uint256(maxAge), uint256(MAX_AGE), "mgg max age");
        Assertions.assertEq(uint256(revision), 1, "mgg genesis revision");

        // Unregistered parameterId returns the zeroed tuple.
        (value, floor, probe, failureClass, maxAge, revision) =
            _store.gasParameterInfo(keccak256("nope"));
        Assertions.assertEq(value, 0, "unknown value");
        Assertions.assertEq(floor, 0, "unknown floor");
        Assertions.assertEq(probe, address(0), "unknown probe");
        Assertions.assertEq(uint256(failureClass), 0, "unknown class NONE");
        Assertions.assertEq(uint256(maxAge), 0, "unknown max age");
        Assertions.assertEq(uint256(revision), 0, "unknown revision");
    }

    function testGasParameterValueReadRevertsUnknown() public {
        Assertions.assertEq(_store.gasParameter(MINT_GATE_ID), 400_000, "live value");
        bytes32 unknownId = keccak256("unknown");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGasParameterHost.GasParameterUnknown.selector, unknownId)
        );
        _store.gasParameter(unknownId);
    }

    // ------------------------------------------------------------------
    // Registration invariants (deployment-time construction rules)
    // ------------------------------------------------------------------

    function deployStore(
        address authority,
        IStreamGasParameterHost.GasParameterConfig[] memory configs
    ) external returns (StreamGasParameterStore) {
        return
            new StreamGasParameterStore(
                authority, address(_core), address(_moduleRegistry), configs
            );
    }

    function deployStoreWithCoreAndRegistry(
        address authority,
        address core,
        address registry,
        IStreamGasParameterHost.GasParameterConfig[] memory configs
    ) external returns (StreamGasParameterStore) {
        return new StreamGasParameterStore(authority, core, registry, configs);
    }

    function _expectDeployRevert(
        IStreamGasParameterHost.GasParameterConfig memory config,
        bytes memory expectedError,
        string memory message
    ) private {
        IStreamGasParameterHost.GasParameterConfig[] memory configs =
            new IStreamGasParameterHost.GasParameterConfig[](1);
        configs[0] = config;
        try this.deployStore(address(_authority), configs) returns (StreamGasParameterStore) {
            Assertions.assertTrue(false, message);
        } catch (bytes memory err) {
            Assertions.assertEq(keccak256(err), keccak256(expectedError), message);
        }
    }

    function _expectProbeBindingDeployRevert(
        IStreamGasParameterHost.GasParameterConfig memory config,
        string memory message
    ) private {
        IStreamGasParameterHost.GasParameterConfig[] memory configs =
            new IStreamGasParameterHost.GasParameterConfig[](1);
        configs[0] = config;
        try this.deployStore(address(_authority), configs) returns (StreamGasParameterStore) {
            Assertions.assertTrue(false, message);
        } catch (bytes memory err) {
            Assertions.assertEq(
                keccak256(err),
                keccak256(
                    abi.encodeWithSelector(
                        IStreamGasParameterHost.GasParameterProbeBindingInvalid.selector,
                        keccak256(abi.encodePacked("6529STREAM_GGP_", config.name)),
                        config.probe
                    )
                ),
                message
            );
        }
    }

    function _expectInvalidGenesisRegistry(address registry, string memory message) private {
        IStreamGasParameterHost.GasParameterConfig[] memory configs =
            new IStreamGasParameterHost.GasParameterConfig[](0);
        try this.deployStoreWithCoreAndRegistry(
            address(_authority), address(_core), registry, configs
        ) returns (
            StreamGasParameterStore
        ) {
            Assertions.assertTrue(false, message);
        } catch (bytes memory err) {
            Assertions.assertEq(
                keccak256(err),
                keccak256(
                    abi.encodeWithSelector(
                        IStreamGasParameterHost.GasParameterInvalidModuleRegistry.selector, registry
                    )
                ),
                message
            );
        }
    }

    function testRegistrationInvariantsRejectInvalidConfigs() public {
        MockGasProbe probe = new MockGasProbe("ROYALTY_RESOLVER_GAS_LIMIT");

        // Empty name.
        _expectDeployRevert(
            _config("", 50_000, 10_000, address(probe), 1),
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterInvalidConfig.selector, bytes32(0)
            ),
            "empty name"
        );
        // Zero floor.
        _expectDeployRevert(
            _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 0, address(probe), 1),
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterInvalidConfig.selector, ROYALTY_RESOLVER_ID
            ),
            "zero floor"
        );
        // Genesis below floor.
        _expectDeployRevert(
            _config("ROYALTY_RESOLVER_GAS_LIMIT", 9_999, 10_000, address(probe), 1),
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterInvalidConfig.selector, ROYALTY_RESOLVER_ID
            ),
            "genesis below floor"
        );
        // Failure class NONE.
        _expectDeployRevert(
            _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, address(probe), 0),
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterInvalidConfig.selector, ROYALTY_RESOLVER_ID
            ),
            "class none"
        );
        // Failure class out of range.
        _expectDeployRevert(
            _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, address(probe), 4),
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterInvalidConfig.selector, ROYALTY_RESOLVER_ID
            ),
            "class out of range"
        );
        // probeMaxAgeBlocks below PROBE_MAX_AGE_FLOOR_BLOCKS ([LTA-GGP-PROBES] rule 6).
        IStreamGasParameterHost.GasParameterConfig memory shortAge =
            _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, address(probe), 1);
        shortAge.probeMaxAgeBlocks = 50_399;
        _expectDeployRevert(
            shortAge,
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterInvalidConfig.selector, ROYALTY_RESOLVER_ID
            ),
            "probe max age below floor"
        );
        // Zero probe binding.
        _expectDeployRevert(
            _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, address(0), 1),
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeMismatch.selector,
                ROYALTY_RESOLVER_ID,
                address(0)
            ),
            "zero probe"
        );

        // Duplicate registration of the same name.
        IStreamGasParameterHost.GasParameterConfig[] memory dupes =
            new IStreamGasParameterHost.GasParameterConfig[](2);
        dupes[0] = _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, address(probe), 1);
        dupes[1] = _config("ROYALTY_RESOLVER_GAS_LIMIT", 60_000, 10_000, address(probe), 1);
        try this.deployStore(address(_authority), dupes) returns (StreamGasParameterStore) {
            Assertions.assertTrue(false, "duplicate registration");
        } catch (bytes memory err) {
            Assertions.assertEq(
                keccak256(err),
                keccak256(
                    abi.encodeWithSelector(
                        IStreamGasParameterHost.GasParameterAlreadyRegistered.selector,
                        ROYALTY_RESOLVER_ID
                    )
                ),
                "duplicate registration error"
            );
        }

        // probeMaxAgeBlocks at exactly the floor is accepted.
        IStreamGasParameterHost.GasParameterConfig[] memory ok =
            new IStreamGasParameterHost.GasParameterConfig[](1);
        ok[0] = _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, address(probe), 1);
        ok[0].probeMaxAgeBlocks = 50_400;
        StreamGasParameterStore store = this.deployStore(address(_authority), ok);
        Assertions.assertEq(store.gasParameter(ROYALTY_RESOLVER_ID), 50_000, "floor-age store");
    }

    function testRegistrationRejectsMismatchedProbe() public {
        // A probe pinned to a different inventory row cannot be bound.
        MockGasProbe wrongProbe = new MockGasProbe("VRF_CALLBACK_GAS_LIMIT");
        _expectDeployRevert(
            _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, address(wrongProbe), 1),
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeMismatch.selector,
                ROYALTY_RESOLVER_ID,
                address(wrongProbe)
            ),
            "mismatched probe"
        );
    }

    function testAuthorityMarkerValidatedAtConstruction() public {
        MockGovernedParameterAuthority badAuthority = new MockGovernedParameterAuthority(false);
        IStreamGasParameterHost.GasParameterConfig[] memory configs =
            new IStreamGasParameterHost.GasParameterConfig[](1);
        configs[0] =
            _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, address(_zeroStoreProbe), 1);
        try this.deployStore(address(badAuthority), configs) returns (StreamGasParameterStore) {
            Assertions.assertTrue(false, "bad authority marker");
        } catch (bytes memory err) {
            Assertions.assertEq(
                keccak256(err),
                keccak256(
                    abi.encodeWithSelector(
                        IStreamGasParameterHost.GasParameterInvalidAuthority.selector,
                        address(badAuthority)
                    )
                ),
                "bad authority marker error"
            );
        }
    }

    function testEip7702DelegatedConstructorBindingsRejected() public {
        IStreamGasParameterHost.GasParameterConfig[] memory configs =
            new IStreamGasParameterHost.GasParameterConfig[](0);

        address delegatedAuthority = vm.addr(0x770201);
        vm.etch(delegatedAuthority, _eip7702Designation(address(_authority)));
        VmGasStorage(address(vm))
            .mockCall(
                delegatedAuthority,
                abi.encodeWithSignature("isStreamGovernedParameterAuthority()"),
                abi.encode(true)
            );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterInvalidAuthority.selector, delegatedAuthority
            )
        );
        this.deployStoreWithCoreAndRegistry(
            delegatedAuthority, address(_core), address(_moduleRegistry), configs
        );

        address delegatedCore = vm.addr(0x770202);
        vm.etch(delegatedCore, _eip7702Designation(address(_core)));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterInvalidCore.selector, delegatedCore
            )
        );
        this.deployStoreWithCoreAndRegistry(
            address(_authority), delegatedCore, address(_moduleRegistry), configs
        );

        address delegatedRegistry = vm.addr(0x770203);
        vm.etch(delegatedRegistry, _eip7702Designation(address(_moduleRegistry)));
        VmGasStorage(address(vm))
            .mockCall(
                delegatedRegistry,
                abi.encodeWithSignature(
                    "supportsInterface(bytes4)", type(IStreamModuleRegistry).interfaceId
                ),
                abi.encode(true)
            );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterInvalidModuleRegistry.selector,
                delegatedRegistry
            )
        );
        this.deployStoreWithCoreAndRegistry(
            address(_authority), address(_core), delegatedRegistry, configs
        );
    }

    function testCoreAndGenesisRegistryConstructorAdmission() public {
        IStreamGasParameterHost.GasParameterConfig[] memory configs =
            new IStreamGasParameterHost.GasParameterConfig[](1);
        MockGasProbe probe = new MockGasProbe("ROYALTY_RESOLVER_GAS_LIMIT");
        configs[0] = _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, address(probe), 1);

        try this.deployStoreWithCoreAndRegistry(
            address(_authority), address(_core), address(0), configs
        ) returns (
            StreamGasParameterStore
        ) {
            Assertions.assertTrue(false, "zero registry accepted");
        } catch (bytes memory err) {
            Assertions.assertEq(
                keccak256(err),
                keccak256(
                    abi.encodeWithSelector(
                        IStreamGasParameterHost.GasParameterInvalidModuleRegistry.selector,
                        address(0)
                    )
                ),
                "zero registry error"
            );
        }

        address codelessRegistry = vm.addr(0xBADD);
        try this.deployStoreWithCoreAndRegistry(
            address(_authority), address(_core), codelessRegistry, configs
        ) returns (
            StreamGasParameterStore
        ) {
            Assertions.assertTrue(false, "codeless registry accepted");
        } catch (bytes memory err) {
            Assertions.assertEq(
                keccak256(err),
                keccak256(
                    abi.encodeWithSelector(
                        IStreamGasParameterHost.GasParameterInvalidModuleRegistry.selector,
                        codelessRegistry
                    )
                ),
                "codeless registry error"
            );
        }

        try this.deployStoreWithCoreAndRegistry(
            address(_authority), address(0), address(_moduleRegistry), configs
        ) returns (
            StreamGasParameterStore
        ) {
            Assertions.assertTrue(false, "zero core accepted");
        } catch (bytes memory err) {
            Assertions.assertEq(
                keccak256(err),
                keccak256(
                    abi.encodeWithSelector(
                        IStreamGasParameterHost.GasParameterInvalidCore.selector, address(0)
                    )
                ),
                "zero core error"
            );
        }

        address codelessCore = vm.addr(0xC0DE);
        try this.deployStoreWithCoreAndRegistry(
            address(_authority), codelessCore, address(_moduleRegistry), configs
        ) returns (
            StreamGasParameterStore
        ) {
            Assertions.assertTrue(false, "codeless core accepted");
        } catch (bytes memory err) {
            Assertions.assertEq(
                keccak256(err),
                keccak256(
                    abi.encodeWithSelector(
                        IStreamGasParameterHost.GasParameterInvalidCore.selector, codelessCore
                    )
                ),
                "codeless core error"
            );
        }
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
        IStreamGasParameterHost.GasParameterConfig[] memory configs =
            new IStreamGasParameterHost.GasParameterConfig[](0);

        StreamGasParameterStore store = this.deployStoreWithCoreAndRegistry(
            address(_authority), address(_core), address(registry), configs
        );
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
                IStreamGasParameterHost.GasParameterLiveModuleRegistryInvalid.selector,
                address(_core)
            )
        );
        _store.moduleRegistry();
    }

    function testRichGasStoreRejectsItsOwnDeploymentAddressAsCore() public {
        IStreamGasParameterHost.GasParameterConfig[] memory configs =
            new IStreamGasParameterHost.GasParameterConfig[](0);
        try new SelfCoreGasParameterStoreHarness(address(_moduleRegistry), configs) returns (
            SelfCoreGasParameterStoreHarness
        ) {
            Assertions.assertTrue(false, "self Core accepted");
        } catch (bytes memory err) {
            bytes4 selector;
            assembly ("memory-safe") {
                selector := mload(add(err, 0x20))
            }
            Assertions.assertEq(
                uint256(uint32(selector)),
                uint256(uint32(IStreamGasParameterHost.GasParameterInvalidCore.selector)),
                "self Core error"
            );
        }
    }

    function testGenesisCommitmentDoesNotReadRegistryAndAllowsPredictedProbe() public {
        MockGasProbe presentProbe = new MockGasProbe("ROYALTY_RESOLVER_GAS_LIMIT");
        IStreamGasParameterHost.GasParameterConfig[] memory configs =
            new IStreamGasParameterHost.GasParameterConfig[](1);
        configs[0] = _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, address(presentProbe), 1);

        // No registry record exists. Present code is checked only against the
        // expected runtime hash and row pin.
        StreamGasParameterStore present = this.deployStore(address(_authority), configs);
        Assertions.assertEq(present.gasParameter(ROYALTY_RESOLVER_ID), 50_000, "present probe");

        address predictedProbe = vm.addr(0xC2EA7E);
        configs[0].probe = predictedProbe;
        configs[0].expectedProbeRuntimeCodeHash = address(presentProbe).codehash;
        configs[0].expectedProbeModuleManifestHash = keccak256(abi.encode("module", predictedProbe));
        configs[0].expectedProbeDeploymentManifestHash =
            keccak256(abi.encode("deployment", predictedProbe));
        StreamGasParameterStore predicted = this.deployStore(address(_authority), configs);
        (,, address boundProbe,,,) = predicted.gasParameterInfo(ROYALTY_RESOLVER_ID);
        Assertions.assertEq(boundProbe, predictedProbe, "predicted probe committed");

        // The counterfactual commitment becomes usable once the expected code
        // and exact registry row appear at the predicted address.
        vm.etch(predictedProbe, address(presentProbe).code);
        _moduleRegistry.registerGasProbe(predictedProbe);
        MockGasProbe(predictedProbe).setRun(50_000, false, uint64(block.number));
        predicted.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);
        Assertions.assertEq(
            predicted.gasParameter(ROYALTY_RESOLVER_ID), 100_000, "predicted probe activated"
        );
    }

    function testEip7702DelegatedPresentGenesisProbeRejected() public {
        address delegatedProbe = vm.addr(0x770204);
        vm.etch(delegatedProbe, _eip7702Designation(address(_forwardingProbe)));
        VmGasStorage(address(vm))
            .mockCall(
                delegatedProbe,
                abi.encodeWithSelector(IStreamGasParameterProbe.probedParameterId.selector),
                abi.encode(ROYALTY_RESOLVER_ID)
            );

        IStreamGasParameterHost.GasParameterConfig memory config =
            _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, delegatedProbe, 1);
        config.expectedProbeRuntimeCodeHash = delegatedProbe.codehash;
        _expectProbeBindingDeployRevert(config, "delegated present probe accepted");
    }

    function testEip7702DelegatedLiveProbeRejected() public {
        address delegatedProbe = vm.addr(0x770205);
        vm.etch(delegatedProbe, _eip7702Designation(address(_forwardingProbe)));
        VmGasStorage(address(vm))
            .mockCall(
                delegatedProbe,
                abi.encodeWithSelector(IStreamGasParameterProbe.probedParameterId.selector),
                abi.encode(ROYALTY_RESOLVER_ID)
            );
        _moduleRegistry.registerGasProbe(delegatedProbe);

        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeBindingInvalid.selector,
                ROYALTY_RESOLVER_ID,
                delegatedProbe
            )
        );
        _store.rebindGasParameterProbe(ROYALTY_RESOLVER_ID, delegatedProbe);
    }

    function testEip7702DelegatedLiveRegistryPointerRejected() public {
        address delegatedRegistry = vm.addr(0x770206);
        vm.etch(delegatedRegistry, _eip7702Designation(address(_moduleRegistry)));
        _core.setLiveModuleRegistry(delegatedRegistry, address(_moduleRegistry));

        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterLiveModuleRegistryInvalid.selector,
                address(_core)
            )
        );
        _store.moduleRegistry();
    }

    function testGenesisCommitmentRejectsPresentCodeAndRowPinMismatch() public {
        MockGasProbe probe = new MockGasProbe("ROYALTY_RESOLVER_GAS_LIMIT");
        IStreamGasParameterHost.GasParameterConfig memory config =
            _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, address(probe), 1);
        config.expectedProbeRuntimeCodeHash = keccak256("wrong runtime");
        _expectProbeBindingDeployRevert(config, "wrong expected runtime accepted");

        MockGasProbe wrongRow = new MockGasProbe("VRF_CALLBACK_GAS_LIMIT");
        config = _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, address(wrongRow), 1);
        _expectDeployRevert(
            config,
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeMismatch.selector,
                ROYALTY_RESOLVER_ID,
                address(wrongRow)
            ),
            "wrong row pin accepted"
        );
    }

    function testGenesisCommitmentRejectsZeroExpectedFacts() public {
        MockGasProbe probe = new MockGasProbe("ROYALTY_RESOLVER_GAS_LIMIT");
        IStreamGasParameterHost.GasParameterConfig memory config =
            _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, address(probe), 1);
        config.expectedProbeModuleVersion = bytes32(0);
        _expectDeployRevert(
            config,
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterInvalidConfig.selector, ROYALTY_RESOLVER_ID
            ),
            "zero expected version accepted"
        );

        config = _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, address(probe), 1);
        config.expectedProbeRuntimeCodeHash = bytes32(0);
        _expectDeployRevert(
            config,
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterInvalidConfig.selector, ROYALTY_RESOLVER_ID
            ),
            "zero expected runtime accepted"
        );

        config = _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, address(probe), 1);
        config.expectedProbeModuleManifestHash = bytes32(0);
        _expectDeployRevert(
            config,
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterInvalidConfig.selector, ROYALTY_RESOLVER_ID
            ),
            "zero expected module manifest accepted"
        );

        config = _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, address(probe), 1);
        config.expectedProbeDeploymentManifestHash = bytes32(0);
        _expectDeployRevert(
            config,
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterInvalidConfig.selector, ROYALTY_RESOLVER_ID
            ),
            "zero expected deployment manifest accepted"
        );
    }

    // ------------------------------------------------------------------
    // Staged raise ([LTA-GGP] requirement 1)
    // ------------------------------------------------------------------

    function testStagedRaiseRespectsAuthorityAndBound() public {
        // Non-authority callers are rejected.
        address stranger = vm.addr(0xBEEF);
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotAuthority.selector, stranger
            )
        );
        _store.raiseGasParameter(MINT_GATE_ID, 500_000);

        // Zero-authority hosts reject every caller on governed paths.
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotAuthority.selector, stranger
            )
        );
        _zeroAuthorityStore.raiseGasParameter(ROYALTY_RESOLVER_ID, 60_000);

        // Unknown parameter.
        bytes32 unknownId = keccak256("unknown");
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGasParameterHost.GasParameterUnknown.selector, unknownId)
        );
        _store.raiseGasParameter(unknownId, 500_000);

        // A raise must raise.
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotARaise.selector,
                MINT_GATE_ID,
                uint256(400_000),
                uint256(400_000)
            )
        );
        _store.raiseGasParameter(MINT_GATE_ID, 400_000);

        // 2x + 1 is rejected ([LTA-GGP] requirement 1 per-action bound).
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterRaiseBoundExceeded.selector,
                MINT_GATE_ID,
                uint256(400_000),
                uint256(800_001)
            )
        );
        _store.raiseGasParameter(MINT_GATE_ID, 800_001);

        // No probe record is required for a staged raise.
        _armValueAction(MINT_GATE_ID, 500_000, 1);
        vm.prank(address(_authority));
        _store.raiseGasParameter(MINT_GATE_ID, 500_000);
        Assertions.assertEq(_store.gasParameter(MINT_GATE_ID), 500_000, "staged raise applied");
    }

    function testStagedRaiseAtExactDoubleSucceeds() public {
        _armValueAction(MINT_GATE_ID, 800_000, 1);
        vm.prank(address(_authority));
        _store.raiseGasParameter(MINT_GATE_ID, 800_000);
        Assertions.assertEq(_store.gasParameter(MINT_GATE_ID), 800_000, "exact 2x raise");
    }

    function testGovernedRaiseRejectsForgedV2ContextAndRevision() public {
        bytes32 scopeHash = _scopeHash(_store, MINT_GATE_ID);
        bytes32 oldStateHash = _stateHash(_store, MINT_GATE_ID, 400_000, address(_mintGateProbe), 1);
        bytes32 newStateHash = _stateHash(_store, MINT_GATE_ID, 500_000, address(_mintGateProbe), 2);

        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGasParameterHost.GasParameterActionNotExecuting.selector)
        );
        _store.raiseGasParameter(MINT_GATE_ID, 500_000);

        _authority.setCurrentAction(true, bytes32(0), 1, scopeHash, oldStateHash, newStateHash);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGasParameterHost.GasParameterActionIdZero.selector)
        );
        _store.raiseGasParameter(MINT_GATE_ID, 500_000);

        _authority.setCurrentAction(true, ACTION_ID, 6, scopeHash, oldStateHash, newStateHash);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterActionClassMismatch.selector, uint8(1), uint8(6)
            )
        );
        _store.raiseGasParameter(MINT_GATE_ID, 500_000);

        bytes32 forgedScope = keccak256("forged-scope");
        _authority.setCurrentAction(true, ACTION_ID, 1, forgedScope, oldStateHash, newStateHash);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterScopeHashMismatch.selector,
                scopeHash,
                forgedScope
            )
        );
        _store.raiseGasParameter(MINT_GATE_ID, 500_000);

        bytes32 forgedOld = keccak256("forged-old");
        _authority.setCurrentAction(true, ACTION_ID, 1, scopeHash, forgedOld, newStateHash);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterOldStateHashMismatch.selector,
                oldStateHash,
                forgedOld
            )
        );
        _store.raiseGasParameter(MINT_GATE_ID, 500_000);

        // The apparent value transition is still stale when it carries the old
        // revision. This is the ABA-replay backstop.
        bytes32 staleRevisionHash =
            _stateHash(_store, MINT_GATE_ID, 500_000, address(_mintGateProbe), 1);
        _authority.setCurrentAction(true, ACTION_ID, 1, scopeHash, oldStateHash, staleRevisionHash);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNewStateHashMismatch.selector,
                newStateHash,
                staleRevisionHash
            )
        );
        _store.raiseGasParameter(MINT_GATE_ID, 500_000);

        _authority.setCurrentAction(true, ACTION_ID, 1, scopeHash, oldStateHash, newStateHash);
        vm.prank(address(_authority));
        _store.raiseGasParameter(MINT_GATE_ID, 500_000);
        (,,,,, uint64 revision) = _store.gasParameterInfo(MINT_GATE_ID);
        Assertions.assertEq(uint256(revision), 2, "revision increments once");
    }

    function testRevisionOverflowRevertsInsteadOfWrapping() public {
        bytes32 parameterBase = keccak256(abi.encode(MINT_GATE_ID, uint256(0)));
        VmGasStorage(address(vm))
            .store(
                address(_store),
                bytes32(uint256(parameterBase) + 3),
                bytes32(uint256(type(uint64).max))
            );
        (,,,,, uint64 revision) = _store.gasParameterInfo(MINT_GATE_ID);
        Assertions.assertEq(
            uint256(revision), uint256(type(uint64).max), "revision forced to maximum"
        );

        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterRevisionOverflow.selector, MINT_GATE_ID
            )
        );
        _store.raiseGasParameter(MINT_GATE_ID, 500_000);
    }

    function testEmergencyAndLowerRequireTheirExactClasses() public {
        _mintGateProbe.setRun(400_000, false, uint64(block.number));
        _armValueAction(MINT_GATE_ID, 600_000, 1);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterActionClassMismatch.selector, uint8(6), uint8(1)
            )
        );
        _store.emergencyRaiseGasParameter(MINT_GATE_ID, 600_000);

        _mintGateProbe.setRun(200_000, true, uint64(block.number));
        _armValueAction(MINT_GATE_ID, 200_000, 6);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterActionClassMismatch.selector, uint8(1), uint8(6)
            )
        );
        _store.lowerGasParameter(MINT_GATE_ID, 200_000);
    }

    // ------------------------------------------------------------------
    // Emergency raise ([LTA-GGP] requirement 1: probe-gated, raise-only)
    // ------------------------------------------------------------------

    function testEmergencyRaiseRequiresFreshFailingRunAtCurrent() public {
        // No record at the current value: blocked.
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeRecordMissing.selector,
                MINT_GATE_ID,
                uint256(400_000)
            )
        );
        _store.emergencyRaiseGasParameter(MINT_GATE_ID, 600_000);

        // A record at a non-current value does not admit.
        _mintGateProbe.setRun(399_999, false, uint64(block.number));
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeRecordMissing.selector,
                MINT_GATE_ID,
                uint256(400_000)
            )
        );
        _store.emergencyRaiseGasParameter(MINT_GATE_ID, 600_000);

        // A healthy (passing) record at the current value blocks the emergency
        // path: an emergency raise of a healthy parameter is nonconformant.
        _mintGateProbe.setRun(400_000, true, uint64(block.number));
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeHealthy.selector,
                MINT_GATE_ID,
                uint256(400_000)
            )
        );
        _store.emergencyRaiseGasParameter(MINT_GATE_ID, 600_000);

        // A stale failing record does not admit.
        uint64 recordedAt = uint64(block.number);
        _mintGateProbe.setRun(400_000, false, recordedAt);
        vm.roll(block.number + MAX_AGE + 1);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeRecordStale.selector,
                MINT_GATE_ID,
                uint256(400_000),
                recordedAt,
                MAX_AGE
            )
        );
        _store.emergencyRaiseGasParameter(MINT_GATE_ID, 600_000);

        // A fresh failing record at the current value admits — at exactly the
        // recency bound.
        _mintGateProbe.setRun(400_000, false, uint64(block.number));
        vm.roll(block.number + MAX_AGE);
        _armValueAction(MINT_GATE_ID, 600_000, 6);
        vm.prank(address(_authority));
        _store.emergencyRaiseGasParameter(MINT_GATE_ID, 600_000);
        Assertions.assertEq(_store.gasParameter(MINT_GATE_ID), 600_000, "emergency raise applied");
    }

    function testEmergencyRaiseRepeatableWhileFailurePersists() public {
        _mintGateProbe.setRun(400_000, false, uint64(block.number));
        _armValueAction(MINT_GATE_ID, 800_000, 6);
        vm.prank(address(_authority));
        _store.emergencyRaiseGasParameter(MINT_GATE_ID, 800_000);

        // The old record is at the old value; a second step demands fresh proof
        // of failure at the new current value.
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeRecordMissing.selector,
                MINT_GATE_ID,
                uint256(800_000)
            )
        );
        _store.emergencyRaiseGasParameter(MINT_GATE_ID, 1_000_000);

        _mintGateProbe.setRun(800_000, false, uint64(block.number));
        _armValueAction(MINT_GATE_ID, 1_600_000, 6);
        vm.prank(address(_authority));
        _store.emergencyRaiseGasParameter(MINT_GATE_ID, 1_600_000);
        Assertions.assertEq(_store.gasParameter(MINT_GATE_ID), 1_600_000, "repeat emergency");
    }

    function testEmergencyRaiseRaiseOnlyAndBounded() public {
        _mintGateProbe.setRun(400_000, false, uint64(block.number));

        // Raise-only: the emergency path can never lower.
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotARaise.selector,
                MINT_GATE_ID,
                uint256(400_000),
                uint256(300_000)
            )
        );
        _store.emergencyRaiseGasParameter(MINT_GATE_ID, 300_000);

        // Bounded to 2x per action even in an emergency.
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterRaiseBoundExceeded.selector,
                MINT_GATE_ID,
                uint256(400_000),
                uint256(800_001)
            )
        );
        _store.emergencyRaiseGasParameter(MINT_GATE_ID, 800_001);

        // Authority-only.
        address stranger = vm.addr(0xD00D);
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotAuthority.selector, stranger
            )
        );
        _store.emergencyRaiseGasParameter(MINT_GATE_ID, 800_000);
    }

    // ------------------------------------------------------------------
    // Governed lower ([LTA-GGP] requirement 2)
    // ------------------------------------------------------------------

    function testGovernedLowerProbeGatedAtExactValue() public {
        // Not a lower.
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotALower.selector,
                MINT_GATE_ID,
                uint256(400_000),
                uint256(400_000)
            )
        );
        _store.lowerGasParameter(MINT_GATE_ID, 400_000);

        // No record at the proposed value: blocked.
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeRecordMissing.selector,
                MINT_GATE_ID,
                uint256(200_000)
            )
        );
        _store.lowerGasParameter(MINT_GATE_ID, 200_000);

        // A passing record at a nearby-but-different value does not satisfy the
        // exact-value locus.
        _mintGateProbe.setRun(200_001, true, uint64(block.number));
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeRecordMissing.selector,
                MINT_GATE_ID,
                uint256(200_000)
            )
        );
        _store.lowerGasParameter(MINT_GATE_ID, 200_000);

        // A failing record at the proposed value blocks.
        _mintGateProbe.setRun(200_000, false, uint64(block.number));
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeNotPassing.selector,
                MINT_GATE_ID,
                uint256(200_000)
            )
        );
        _store.lowerGasParameter(MINT_GATE_ID, 200_000);

        // A stale passing record blocks.
        uint64 recordedAt = uint64(block.number);
        _mintGateProbe.setRun(200_000, true, recordedAt);
        vm.roll(block.number + MAX_AGE + 1);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeRecordStale.selector,
                MINT_GATE_ID,
                uint256(200_000),
                recordedAt,
                MAX_AGE
            )
        );
        _store.lowerGasParameter(MINT_GATE_ID, 200_000);

        // A fresh passing record at exactly the proposed value admits.
        _mintGateProbe.setRun(200_000, true, uint64(block.number));
        _armValueAction(MINT_GATE_ID, 200_000, 1);
        vm.prank(address(_authority));
        _store.lowerGasParameter(MINT_GATE_ID, 200_000);
        Assertions.assertEq(_store.gasParameter(MINT_GATE_ID), 200_000, "governed lower applied");

        // Non-authority callers are rejected.
        address stranger = vm.addr(0xF00);
        _mintGateProbe.setRun(150_000, true, uint64(block.number));
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotAuthority.selector, stranger
            )
        );
        _store.lowerGasParameter(MINT_GATE_ID, 150_000);
    }

    function testGovernedLowerFloorRejection() public {
        // Even with a fresh passing record at the proposed value, the immutable
        // floor can never be crossed ([LTA-GGP] definition item 2).
        _mintGateProbe.setRun(99_999, true, uint64(block.number));
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterBelowFloor.selector,
                MINT_GATE_ID,
                uint256(99_999),
                uint256(100_000)
            )
        );
        _store.lowerGasParameter(MINT_GATE_ID, 99_999);

        // Lowering to exactly the floor is allowed.
        _mintGateProbe.setRun(200_000, true, uint64(block.number));
        _armValueAction(MINT_GATE_ID, 200_000, 1);
        vm.prank(address(_authority));
        _store.lowerGasParameter(MINT_GATE_ID, 200_000);
        _mintGateProbe.setRun(100_000, true, uint64(block.number));
        _armValueAction(MINT_GATE_ID, 100_000, 1);
        vm.prank(address(_authority));
        _store.lowerGasParameter(MINT_GATE_ID, 100_000);
        Assertions.assertEq(_store.gasParameter(MINT_GATE_ID), 100_000, "lower to floor");
    }

    // ------------------------------------------------------------------
    // Permissionless conditional raise/re-lower ([LTA-GGP] requirement 11)
    // ------------------------------------------------------------------

    function testProbeRunReadsRejectMalformedResponsesWithoutMutation() public {
        (StreamGasParameterStore store, MockAdversarialProbeRun probe) = _adversarialProbeStore();
        probe.setRun(50_000, false, uint64(block.number));

        _assertMalformedRaiseRejected(store, probe, MockAdversarialProbeRun.ResponseMode.Oversized);
        _assertMalformedRaiseRejected(store, probe, MockAdversarialProbeRun.ResponseMode.Short);
        _assertMalformedRaiseRejected(
            store, probe, MockAdversarialProbeRun.ResponseMode.NonCanonicalBool
        );
        _assertMalformedRaiseRejected(
            store, probe, MockAdversarialProbeRun.ResponseMode.NonCanonicalUint64
        );
        _assertMalformedRaiseRejected(store, probe, MockAdversarialProbeRun.ResponseMode.Reverting);

        probe.setResponseMode(MockAdversarialProbeRun.ResponseMode.Canonical);
        store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);
        _assertAdversarialGasState(store, 100_000, 2);

        probe.setRun(60_000, true, uint64(block.number));
        _assertMalformedRelowerRejected(
            store, probe, MockAdversarialProbeRun.ResponseMode.Oversized
        );
        _assertMalformedRelowerRejected(store, probe, MockAdversarialProbeRun.ResponseMode.Short);
        _assertMalformedRelowerRejected(
            store, probe, MockAdversarialProbeRun.ResponseMode.NonCanonicalBool
        );
        _assertMalformedRelowerRejected(
            store, probe, MockAdversarialProbeRun.ResponseMode.NonCanonicalUint64
        );
        _assertMalformedRelowerRejected(
            store, probe, MockAdversarialProbeRun.ResponseMode.Reverting
        );
    }

    function testProbeRunReadsForwardAvailableGasAcrossRaiseAndRelower() public {
        (StreamGasParameterStore store, MockAdversarialProbeRun probe) = _adversarialProbeStore();
        probe.setMinimumReadGas(250_000);

        probe.setRun(50_000, false, uint64(block.number));
        store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);
        _assertAdversarialGasState(store, 100_000, 2);

        probe.setRun(60_000, true, uint64(block.number));
        store.conditionalRelowerGasParameter(ROYALTY_RESOLVER_ID, 60_000);
        _assertAdversarialGasState(store, 60_000, 3);
    }

    function testConditionalRaisePermissionlessZeroSigner() public {
        address stranger = vm.addr(0xA11CE);

        // Blocked without a failing record.
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeRecordMissing.selector,
                ROYALTY_RESOLVER_ID,
                uint256(50_000)
            )
        );
        _zeroAuthorityStore.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);

        // Blocked while the probe reports the guarded path healthy.
        _zeroStoreProbe.setRun(50_000, true, uint64(block.number));
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeHealthy.selector,
                ROYALTY_RESOLVER_ID,
                uint256(50_000)
            )
        );
        _zeroAuthorityStore.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);

        // Bounded to 2x per action.
        _zeroStoreProbe.setRun(50_000, false, uint64(block.number));
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterRaiseBoundExceeded.selector,
                ROYALTY_RESOLVER_ID,
                uint256(50_000),
                uint256(100_001)
            )
        );
        _zeroAuthorityStore.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_001);

        // Admitted on a fresh failing record at the current value, with no
        // governance signer anywhere: the store's authority is address(0).
        Assertions.assertEq(
            _zeroAuthorityStore.governanceAuthority(), address(0), "no governance signer"
        );
        vm.recordLogs();
        vm.prank(stranger);
        _zeroAuthorityStore.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);
        Assertions.assertEq(
            _zeroAuthorityStore.gasParameter(ROYALTY_RESOLVER_ID), 100_000, "conditional raise"
        );

        // The canonical change event carries the pre-registered action id.
        (bytes32 raiseActionId,) =
            _zeroAuthorityStore.conditionalGasParameterActions(ROYALTY_RESOLVER_ID);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Assertions.assertEq(logs.length, 1, "one change event");
        Assertions.assertEq(logs[0].topics[0], GAS_PARAMETER_UPDATED_TOPIC, "canonical topic");
        Assertions.assertEq(logs[0].topics[3], raiseActionId, "pre-registered raise action id");

        // Repeatable while fresh probe runs keep proving failure.
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeRecordMissing.selector,
                ROYALTY_RESOLVER_ID,
                uint256(100_000)
            )
        );
        _zeroAuthorityStore.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 200_000);
        _zeroStoreProbe.setRun(100_000, false, uint64(block.number));
        vm.prank(vm.addr(0xB0B));
        _zeroAuthorityStore.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 200_000);
        Assertions.assertEq(
            _zeroAuthorityStore.gasParameter(ROYALTY_RESOLVER_ID), 200_000, "repeat raise"
        );

        // The conditional path is equally permissionless on a governed host.
        _forwardingProbe.setRun(50_000, false, uint64(block.number));
        vm.prank(stranger);
        _store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);
        Assertions.assertEq(
            _store.gasParameter(ROYALTY_RESOLVER_ID), 100_000, "governed host conditional"
        );
    }

    function testConditionalRelowerPermissionlessZeroSigner() public {
        address stranger = vm.addr(0xCAFE);

        // Walk the value up first (failing record chain), then back down.
        _zeroStoreProbe.setRun(50_000, false, uint64(block.number));
        vm.prank(stranger);
        _zeroAuthorityStore.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);

        // Not a lower.
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotALower.selector,
                ROYALTY_RESOLVER_ID,
                uint256(100_000),
                uint256(100_000)
            )
        );
        _zeroAuthorityStore.conditionalRelowerGasParameter(ROYALTY_RESOLVER_ID, 100_000);

        // Requires a passing record at exactly the proposed value.
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeRecordMissing.selector,
                ROYALTY_RESOLVER_ID,
                uint256(60_000)
            )
        );
        _zeroAuthorityStore.conditionalRelowerGasParameter(ROYALTY_RESOLVER_ID, 60_000);

        // A failing record at the proposed value blocks.
        _zeroStoreProbe.setRun(60_000, false, uint64(block.number));
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeNotPassing.selector,
                ROYALTY_RESOLVER_ID,
                uint256(60_000)
            )
        );
        _zeroAuthorityStore.conditionalRelowerGasParameter(ROYALTY_RESOLVER_ID, 60_000);

        // A stale passing record blocks.
        uint64 recordedAt = uint64(block.number);
        _zeroStoreProbe.setRun(60_000, true, recordedAt);
        vm.roll(block.number + MAX_AGE + 1);
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeRecordStale.selector,
                ROYALTY_RESOLVER_ID,
                uint256(60_000),
                recordedAt,
                MAX_AGE
            )
        );
        _zeroAuthorityStore.conditionalRelowerGasParameter(ROYALTY_RESOLVER_ID, 60_000);

        // Admitted on a fresh passing record at exactly the proposed value, no
        // signer, canonical event carrying the pre-registered re-lower action id.
        _zeroStoreProbe.setRun(60_000, true, uint64(block.number));
        (, bytes32 relowerActionId) =
            _zeroAuthorityStore.conditionalGasParameterActions(ROYALTY_RESOLVER_ID);
        vm.recordLogs();
        vm.prank(vm.addr(0xB0B2));
        _zeroAuthorityStore.conditionalRelowerGasParameter(ROYALTY_RESOLVER_ID, 60_000);
        Assertions.assertEq(
            _zeroAuthorityStore.gasParameter(ROYALTY_RESOLVER_ID), 60_000, "conditional re-lower"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Assertions.assertEq(logs.length, 1, "one change event");
        Assertions.assertEq(logs[0].topics[3], relowerActionId, "pre-registered re-lower id");
    }

    function testConditionalRelowerHalfBoundAndFloor() public {
        address stranger = vm.addr(0xDEED);

        // Raise to 100_000 so half-bound math is clean.
        _zeroStoreProbe.setRun(50_000, false, uint64(block.number));
        vm.prank(stranger);
        _zeroAuthorityStore.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);

        // Below half the current value per action is rejected even with a
        // passing record at the proposed value.
        _zeroStoreProbe.setRun(49_999, true, uint64(block.number));
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterLowerBoundExceeded.selector,
                ROYALTY_RESOLVER_ID,
                uint256(100_000),
                uint256(49_999)
            )
        );
        _zeroAuthorityStore.conditionalRelowerGasParameter(ROYALTY_RESOLVER_ID, 49_999);

        // Exactly half is admitted.
        _zeroStoreProbe.setRun(50_000, true, uint64(block.number));
        vm.prank(stranger);
        _zeroAuthorityStore.conditionalRelowerGasParameter(ROYALTY_RESOLVER_ID, 50_000);
        Assertions.assertEq(
            _zeroAuthorityStore.gasParameter(ROYALTY_RESOLVER_ID), 50_000, "half-step re-lower"
        );

        // The immutable floor binds: walk down to 25_000, then 12_500 is below
        // the 10_000 floor? No — 12_500 is above; step to 12_500, then a further
        // half-step to 6_250 crosses the floor and reverts.
        _zeroStoreProbe.setRun(25_000, true, uint64(block.number));
        vm.prank(stranger);
        _zeroAuthorityStore.conditionalRelowerGasParameter(ROYALTY_RESOLVER_ID, 25_000);
        _zeroStoreProbe.setRun(12_500, true, uint64(block.number));
        vm.prank(stranger);
        _zeroAuthorityStore.conditionalRelowerGasParameter(ROYALTY_RESOLVER_ID, 12_500);
        _zeroStoreProbe.setRun(6_250, true, uint64(block.number));
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterBelowFloor.selector,
                ROYALTY_RESOLVER_ID,
                uint256(6_250),
                uint256(10_000)
            )
        );
        _zeroAuthorityStore.conditionalRelowerGasParameter(ROYALTY_RESOLVER_ID, 6_250);

        // A re-lower can never raise.
        _zeroStoreProbe.setRun(20_000, true, uint64(block.number));
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotALower.selector,
                ROYALTY_RESOLVER_ID,
                uint256(12_500),
                uint256(20_000)
            )
        );
        _zeroAuthorityStore.conditionalRelowerGasParameter(ROYALTY_RESOLVER_ID, 20_000);
    }

    // ------------------------------------------------------------------
    // Scope rejection ([LTA-GGP] requirements 10-11: conditional actions are
    // FORWARDING_CAP-only and absent by construction elsewhere)
    // ------------------------------------------------------------------

    function testConditionalActionsAbsentForFailClosedAndMinGasGate() public {
        address stranger = vm.addr(0xFEED);

        // Even a genuine fresh failing record cannot arm a conditional raise for
        // a FAIL_CLOSED_PRECHECK parameter.
        _mintGateProbe.setRun(400_000, false, uint64(block.number));
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterConditionalActionUnavailable.selector,
                MINT_GATE_ID,
                uint8(2)
            )
        );
        _store.conditionalRaiseGasParameter(MINT_GATE_ID, 800_000);

        // Nor a conditional re-lower with a passing record at the target.
        _mintGateProbe.setRun(200_000, true, uint64(block.number));
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterConditionalActionUnavailable.selector,
                MINT_GATE_ID,
                uint8(2)
            )
        );
        _store.conditionalRelowerGasParameter(MINT_GATE_ID, 200_000);

        // Same for the MIN_GAS_GATE class.
        _flushFloorProbe.setRun(80_000, false, uint64(block.number));
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterConditionalActionUnavailable.selector,
                FLUSH_GAS_FLOOR_ID,
                uint8(3)
            )
        );
        _store.conditionalRaiseGasParameter(FLUSH_GAS_FLOOR_ID, 160_000);

        _flushFloorProbe.setRun(40_000, true, uint64(block.number));
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterConditionalActionUnavailable.selector,
                FLUSH_GAS_FLOOR_ID,
                uint8(3)
            )
        );
        _store.conditionalRelowerGasParameter(FLUSH_GAS_FLOOR_ID, 40_000);

        // No standing action ids exist for either class.
        (bytes32 raiseId, bytes32 relowerId) = _store.conditionalGasParameterActions(MINT_GATE_ID);
        Assertions.assertEq(raiseId, bytes32(0), "fail-closed raise id absent");
        Assertions.assertEq(relowerId, bytes32(0), "fail-closed re-lower id absent");
        (raiseId, relowerId) = _store.conditionalGasParameterActions(FLUSH_GAS_FLOOR_ID);
        Assertions.assertEq(raiseId, bytes32(0), "min-gas-gate raise id absent");
        Assertions.assertEq(relowerId, bytes32(0), "min-gas-gate re-lower id absent");

        // Unknown parameters have no conditional surface either.
        bytes32 unknownId = keccak256("unknown");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGasParameterHost.GasParameterUnknown.selector, unknownId)
        );
        _store.conditionalRaiseGasParameter(unknownId, 1);
    }

    function testConditionalActionIdsGolden() public view {
        // Standing action ids are pre-registered at deployment with a documented
        // derivation, distinct per direction, and stable.
        (bytes32 raiseId, bytes32 relowerId) =
            _store.conditionalGasParameterActions(ROYALTY_RESOLVER_ID);
        bytes32 expectedRaise = keccak256(
            abi.encode(
                keccak256("6529STREAM_GGP_CONDITIONAL_RAISE_V1"),
                block.chainid,
                address(_store),
                ROYALTY_RESOLVER_ID
            )
        );
        bytes32 expectedRelower = keccak256(
            abi.encode(
                keccak256("6529STREAM_GGP_CONDITIONAL_RELOWER_V1"),
                block.chainid,
                address(_store),
                ROYALTY_RESOLVER_ID
            )
        );
        Assertions.assertEq(raiseId, expectedRaise, "raise action id derivation");
        Assertions.assertEq(relowerId, expectedRelower, "re-lower action id derivation");
        Assertions.assertTrue(raiseId != relowerId, "direction-distinct ids");
    }

    function testConditionalPathsIncrementRevisionAndRejectBindingDrift() public {
        _forwardingProbe.setRun(50_000, false, uint64(block.number));
        _store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);
        (,,,,, uint64 revision) = _store.gasParameterInfo(ROYALTY_RESOLVER_ID);
        Assertions.assertEq(uint256(revision), 2, "conditional raise revision");

        _forwardingProbe.setRun(50_000, true, uint64(block.number));
        _store.conditionalRelowerGasParameter(ROYALTY_RESOLVER_ID, 50_000);
        (,,,,, revision) = _store.gasParameterInfo(ROYALTY_RESOLVER_ID);
        Assertions.assertEq(uint256(revision), 3, "conditional re-lower revision");

        _moduleRegistry.setStatus(address(_forwardingProbe), ModuleRegistryStatus.INCIDENT_REVOKED);
        _forwardingProbe.setRun(50_000, false, uint64(block.number));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeBindingInvalid.selector,
                ROYALTY_RESOLVER_ID,
                address(_forwardingProbe)
            )
        );
        _store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);

        _moduleRegistry.registerGasProbe(address(_forwardingProbe));
        _moduleRegistry.setRuntimeCodeHash(address(_forwardingProbe), keccak256("wrong-code"));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeBindingInvalid.selector,
                ROYALTY_RESOLVER_ID,
                address(_forwardingProbe)
            )
        );
        _store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);

        _moduleRegistry.registerGasProbe(address(_forwardingProbe));
        _moduleRegistry.setModuleVersion(address(_forwardingProbe), bytes32(uint256(2)));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeBindingInvalid.selector,
                ROYALTY_RESOLVER_ID,
                address(_forwardingProbe)
            )
        );
        _store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);

        _moduleRegistry.registerGasProbe(address(_forwardingProbe));
        _moduleRegistry.setManifestHashes(
            address(_forwardingProbe), keccak256("changed-module"), keccak256("changed-deployment")
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeBindingInvalid.selector,
                ROYALTY_RESOLVER_ID,
                address(_forwardingProbe)
            )
        );
        _store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);
    }

    function testPrePointerReadsAndOrdinaryRaiseRemainAvailableButEvidenceFailsClosed() public {
        MockParameterCorePointer uninitializedCore = new MockParameterCorePointer();
        MockGasProbe probe = new MockGasProbe("ROYALTY_RESOLVER_GAS_LIMIT");
        IStreamGasParameterHost.GasParameterConfig[] memory configs =
            new IStreamGasParameterHost.GasParameterConfig[](1);
        configs[0] = _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, address(probe), 1);
        StreamGasParameterStore store = new StreamGasParameterStore(
            address(_authority), address(uninitializedCore), address(_moduleRegistry), configs
        );
        _registerProbe(address(probe));

        Assertions.assertEq(store.gasParameter(ROYALTY_RESOLVER_ID), 50_000, "pre-pointer read");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterLiveModuleRegistryInvalid.selector,
                address(uninitializedCore)
            )
        );
        store.moduleRegistry();

        ProbeBindingFacts memory binding = ProbeBindingFacts({
            probe: address(probe),
            runtimeCodeHash: address(probe).codehash,
            bindingHash: _probeBindingHashAt(_moduleRegistry, address(probe))
        });
        bytes32 scopeHash = _scopeHash(store, ROYALTY_RESOLVER_ID);
        _authority.setCurrentAction(
            true,
            ACTION_ID,
            1,
            scopeHash,
            _stateHashWithBinding(store, ROYALTY_RESOLVER_ID, 50_000, binding, 1),
            _stateHashWithBinding(store, ROYALTY_RESOLVER_ID, 60_000, binding, 2)
        );
        vm.prank(address(_authority));
        store.raiseGasParameter(ROYALTY_RESOLVER_ID, 60_000);
        Assertions.assertEq(store.gasParameter(ROYALTY_RESOLVER_ID), 60_000, "ordinary raise");

        probe.setRun(60_000, false, uint64(block.number));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterLiveModuleRegistryInvalid.selector,
                address(uninitializedCore)
            )
        );
        store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);

        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterLiveModuleRegistryInvalid.selector,
                address(uninitializedCore)
            )
        );
        store.emergencyRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);

        probe.setRun(50_000, true, uint64(block.number));
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterLiveModuleRegistryInvalid.selector,
                address(uninitializedCore)
            )
        );
        store.lowerGasParameter(ROYALTY_RESOLVER_ID, 50_000);
    }

    function testMalformedPointerAndV2RecordResponsesFailClosed() public {
        _core.setRawPointerResponse(new bytes(319));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterLiveModuleRegistryInvalid.selector,
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
                IStreamGasParameterHost.GasParameterLiveModuleRegistryInvalid.selector,
                address(_core)
            )
        );
        _store.moduleRegistry();

        _core.setRawPointerResponse(new bytes(321));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterLiveModuleRegistryInvalid.selector,
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
                IStreamGasParameterHost.GasParameterLiveModuleRegistryInvalid.selector,
                address(_core)
            )
        );
        _store.moduleRegistry();

        _core.setLiveModuleRegistry(address(_moduleRegistry), address(_moduleRegistry));
        _moduleRegistry.setRevision(address(_forwardingProbe), 0);
        _forwardingProbe.setRun(50_000, false, uint64(block.number));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeBindingInvalid.selector,
                ROYALTY_RESOLVER_ID,
                address(_forwardingProbe)
            )
        );
        _store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);

        _moduleRegistry.registerGasProbe(address(_forwardingProbe));
        _moduleRegistry.setRawModuleRecordResponse(hex"00", true);
        _forwardingProbe.setRun(50_000, false, uint64(block.number));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeBindingInvalid.selector,
                ROYALTY_RESOLVER_ID,
                address(_forwardingProbe)
            )
        );
        _store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);

        _moduleRegistry.setRawModuleRecordResponse(bytes(""), false);
        (bool ok, bytes memory dirtyRecord) = address(_moduleRegistry)
            .staticcall(
                abi.encodeWithSelector(
                    IStreamModuleRegistry.moduleRecord.selector, address(_forwardingProbe)
                )
            );
        Assertions.assertTrue(ok, "canonical V2 record read");
        assembly ("memory-safe") {
            mstore(add(dirtyRecord, 0x40), 0x101)
        }
        _moduleRegistry.setRawModuleRecordResponse(dirtyRecord, true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeBindingInvalid.selector,
                ROYALTY_RESOLVER_ID,
                address(_forwardingProbe)
            )
        );
        _store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);

        _moduleRegistry.setRawModuleRecordResponse(new bytes(2_497), true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeBindingInvalid.selector,
                ROYALTY_RESOLVER_ID,
                address(_forwardingProbe)
            )
        );
        _store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);
    }

    function testV2RecordManifestUriBounds() public {
        bytes memory bindingError = abi.encodeWithSelector(
            IStreamGasParameterHost.GasParameterProbeBindingInvalid.selector,
            ROYALTY_RESOLVER_ID,
            address(_forwardingProbe)
        );
        _forwardingProbe.setRun(50_000, false, uint64(block.number));

        _moduleRegistry.setModuleManifestURI(address(_forwardingProbe), "");
        vm.expectRevert(bindingError);
        _store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);

        _moduleRegistry.setModuleManifestURI(address(_forwardingProbe), _asciiString(2_049));
        vm.expectRevert(bindingError);
        _store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);

        _moduleRegistry.setModuleManifestURI(address(_forwardingProbe), _asciiString(2_048));
        _store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);
        Assertions.assertEq(
            _store.gasParameter(ROYALTY_RESOLVER_ID), 100_000, "2,048-byte URI accepted"
        );
    }

    function testRegistryAToBSameAddressRebindAndOldAUnavailable() public {
        MockParameterModuleRegistry successorRegistry = new MockParameterModuleRegistry();
        successorRegistry.registerGasProbe(address(_forwardingProbe));

        (uint256 value,, address probe,,, uint64 revision) =
            _store.gasParameterInfo(ROYALTY_RESOLVER_ID);
        bytes32 scopeHash = _scopeHash(_store, ROYALTY_RESOLVER_ID);
        ProbeBindingFacts memory oldBinding = ProbeBindingFacts({
            probe: probe,
            runtimeCodeHash: probe.codehash,
            bindingHash: _probeBindingHashAt(_moduleRegistry, probe)
        });
        ProbeBindingFacts memory newBinding = ProbeBindingFacts({
            probe: probe,
            runtimeCodeHash: probe.codehash,
            bindingHash: _probeBindingHashAt(successorRegistry, probe)
        });

        _core.setLiveModuleRegistry(address(successorRegistry), address(_moduleRegistry));
        _forwardingProbe.setRun(value, false, uint64(block.number));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeBindingInvalid.selector,
                ROYALTY_RESOLVER_ID,
                probe
            )
        );
        _store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, value * 2);

        _authority.setCurrentAction(
            true,
            ACTION_ID,
            3,
            scopeHash,
            _stateHashWithBinding(_store, ROYALTY_RESOLVER_ID, value, oldBinding, revision),
            _stateHashWithBinding(_store, ROYALTY_RESOLVER_ID, value, newBinding, revision + 1)
        );
        vm.prank(address(_authority));
        _store.rebindGasParameterProbe(ROYALTY_RESOLVER_ID, probe);
        Assertions.assertEq(
            _store.moduleRegistry(), address(successorRegistry), "successor registry live"
        );

        _moduleRegistry.setUnavailable(true);
        _store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, value * 2);
        Assertions.assertEq(
            _store.gasParameter(ROYALTY_RESOLVER_ID), value * 2, "old registry not consulted"
        );
    }

    // ------------------------------------------------------------------
    // Governed probe rebinding ([LTA-GGP-PROBES] rule 3)
    // ------------------------------------------------------------------

    function testProbeRebindRejectsForgedTransitionContext() public {
        MockGasProbe successor = new MockGasProbe("ROYALTY_RESOLVER_GAS_LIMIT");
        _registerProbe(address(successor));
        (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash) =
            _rebindTransitionHashes(ROYALTY_RESOLVER_ID, address(successor));

        bytes32 forgedScope = keccak256("forged-rebind-scope");
        _setActionContext(3, forgedScope, oldStateHash, newStateHash);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterScopeHashMismatch.selector,
                scopeHash,
                forgedScope
            )
        );
        _store.rebindGasParameterProbe(ROYALTY_RESOLVER_ID, address(successor));

        bytes32 forgedOldState = keccak256("forged-rebind-old");
        _setActionContext(3, scopeHash, forgedOldState, newStateHash);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterOldStateHashMismatch.selector,
                oldStateHash,
                forgedOldState
            )
        );
        _store.rebindGasParameterProbe(ROYALTY_RESOLVER_ID, address(successor));

        bytes32 forgedNewState = keccak256("forged-rebind-new");
        _setActionContext(3, scopeHash, oldStateHash, forgedNewState);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNewStateHashMismatch.selector,
                newStateHash,
                forgedNewState
            )
        );
        _store.rebindGasParameterProbe(ROYALTY_RESOLVER_ID, address(successor));
    }

    function testProbeRebindSameAddressChangedBindingSucceeds() public {
        (uint256 value,, address probe,,, uint64 revision) =
            _store.gasParameterInfo(ROYALTY_RESOLVER_ID);
        bytes32 scopeHash = _scopeHash(_store, ROYALTY_RESOLVER_ID);
        ProbeBindingFacts memory oldBinding = ProbeBindingFacts({
            probe: probe, runtimeCodeHash: probe.codehash, bindingHash: _probeBindingHash(probe)
        });
        bytes32 oldStateHash =
            _stateHashWithBinding(_store, ROYALTY_RESOLVER_ID, value, oldBinding, revision);

        _moduleRegistry.setModuleVersion(probe, bytes32(uint256(2)));
        ProbeBindingFacts memory newBinding = ProbeBindingFacts({
            probe: probe, runtimeCodeHash: probe.codehash, bindingHash: _probeBindingHash(probe)
        });
        bytes32 newStateHash =
            _stateHashWithBinding(_store, ROYALTY_RESOLVER_ID, value, newBinding, revision + 1);
        _setActionContext(3, scopeHash, oldStateHash, newStateHash);

        vm.prank(address(_authority));
        _store.rebindGasParameterProbe(ROYALTY_RESOLVER_ID, probe);
        (,, address reboundProbe,,, uint64 reboundRevision) =
            _store.gasParameterInfo(ROYALTY_RESOLVER_ID);
        Assertions.assertEq(reboundProbe, probe, "same-address binding retained");
        Assertions.assertEq(uint256(reboundRevision), 2, "changed binding increments revision");

        // The refreshed binding is now the execution locus for permissionless
        // museum-mode repair, proving the new commitment was cached.
        _forwardingProbe.setRun(50_000, false, uint64(block.number));
        _store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);
        (,,,,, reboundRevision) = _store.gasParameterInfo(ROYALTY_RESOLVER_ID);
        Assertions.assertEq(uint256(reboundRevision), 3, "new binding drives conditional path");
    }

    function testProbeRebindRejectsInactiveAndDriftedSuccessor() public {
        MockGasProbe successor = new MockGasProbe("ROYALTY_RESOLVER_GAS_LIMIT");

        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeBindingInvalid.selector,
                ROYALTY_RESOLVER_ID,
                address(successor)
            )
        );
        _store.rebindGasParameterProbe(ROYALTY_RESOLVER_ID, address(successor));

        _registerProbe(address(successor));
        _moduleRegistry.setStatus(address(successor), ModuleRegistryStatus.DEPRECATED);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeBindingInvalid.selector,
                ROYALTY_RESOLVER_ID,
                address(successor)
            )
        );
        _store.rebindGasParameterProbe(ROYALTY_RESOLVER_ID, address(successor));

        _registerProbe(address(successor));
        (bytes32 scopeHash, bytes32 oldStateHash, bytes32 scheduledNewStateHash) =
            _rebindTransitionHashes(ROYALTY_RESOLVER_ID, address(successor));
        _moduleRegistry.setModuleVersion(address(successor), bytes32(uint256(2)));
        (uint256 value,,,,, uint64 revision) = _store.gasParameterInfo(ROYALTY_RESOLVER_ID);
        bytes32 driftedNewStateHash =
            _stateHash(_store, ROYALTY_RESOLVER_ID, value, address(successor), revision + 1);
        _setActionContext(3, scopeHash, oldStateHash, scheduledNewStateHash);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNewStateHashMismatch.selector,
                driftedNewStateHash,
                scheduledNewStateHash
            )
        );
        _store.rebindGasParameterProbe(ROYALTY_RESOLVER_ID, address(successor));

        _registerProbe(address(successor));
        _moduleRegistry.setRuntimeCodeHash(address(successor), keccak256("drifted-runtime"));
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeBindingInvalid.selector,
                ROYALTY_RESOLVER_ID,
                address(successor)
            )
        );
        _store.rebindGasParameterProbe(ROYALTY_RESOLVER_ID, address(successor));
    }

    function testProbeRebindGovernedPath() public {
        MockGasProbe successor = new MockGasProbe("ROYALTY_RESOLVER_GAS_LIMIT");
        _registerProbe(address(successor));
        address stranger = vm.addr(0x777);

        // Authority-only.
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotAuthority.selector, stranger
            )
        );
        _store.rebindGasParameterProbe(ROYALTY_RESOLVER_ID, address(successor));

        // Unknown parameter.
        bytes32 unknownId = keccak256("unknown");
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGasParameterHost.GasParameterUnknown.selector, unknownId)
        );
        _store.rebindGasParameterProbe(unknownId, address(successor));

        // Zero successor.
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeMismatch.selector,
                ROYALTY_RESOLVER_ID,
                address(0)
            )
        );
        _store.rebindGasParameterProbe(ROYALTY_RESOLVER_ID, address(0));

        address codelessSuccessor = vm.addr(0xC0DE1E55);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeBindingInvalid.selector,
                ROYALTY_RESOLVER_ID,
                codelessSuccessor
            )
        );
        _store.rebindGasParameterProbe(ROYALTY_RESOLVER_ID, codelessSuccessor);

        // A successor serving a different inventory row cannot be bound.
        MockGasProbe wrongProbe = new MockGasProbe("VRF_CALLBACK_GAS_LIMIT");
        _registerProbe(address(wrongProbe));
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeMismatch.selector,
                ROYALTY_RESOLVER_ID,
                address(wrongProbe)
            )
        );
        _store.rebindGasParameterProbe(ROYALTY_RESOLVER_ID, address(wrongProbe));

        // Class 6 is emergency-raise-only; a probe rebind rejects it even when
        // every scope/state commitment is otherwise exact.
        _armProbeRebindAction(ROYALTY_RESOLVER_ID, address(successor), 6);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterActionClassMismatch.selector, uint8(3), uint8(6)
            )
        );
        _store.rebindGasParameterProbe(ROYALTY_RESOLVER_ID, address(successor));

        // Governed rebind executes and moves the introspected binding.
        _armProbeRebindAction(ROYALTY_RESOLVER_ID, address(successor), 3);
        vm.recordLogs();
        vm.prank(address(_authority));
        _store.rebindGasParameterProbe(ROYALTY_RESOLVER_ID, address(successor));
        (,, address boundProbe,,,) = _store.gasParameterInfo(ROYALTY_RESOLVER_ID);
        Assertions.assertEq(boundProbe, address(successor), "binding moved");
        (,,,,, uint64 revision) = _store.gasParameterInfo(ROYALTY_RESOLVER_ID);
        Assertions.assertEq(uint256(revision), 2, "rebind revision");

        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeRebindNoOp.selector,
                ROYALTY_RESOLVER_ID,
                address(successor)
            )
        );
        _store.rebindGasParameterProbe(ROYALTY_RESOLVER_ID, address(successor));

        // Rebind event schema golden.
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Assertions.assertEq(logs.length, 1, "single rebind event");
        Assertions.assertEq(logs[0].emitter, address(_store), "emitted by host");
        Assertions.assertEq(logs[0].topics.length, 4, "three indexed topics");
        Assertions.assertEq(
            logs[0].topics[0], GAS_PARAMETER_PROBE_REBOUND_TOPIC, "rebind signature"
        );
        Assertions.assertEq(logs[0].topics[1], ROYALTY_RESOLVER_ID, "parameterId topic");
        Assertions.assertEq(
            logs[0].topics[2], bytes32(uint256(uint160(address(_store)))), "host topic"
        );
        Assertions.assertEq(logs[0].topics[3], ACTION_ID, "actionId topic");
        (uint16 schemaVersion, address oldProbe, address newProbe) =
            abi.decode(logs[0].data, (uint16, address, address));
        Assertions.assertEq(uint256(schemaVersion), 1, "schema version");
        Assertions.assertEq(oldProbe, address(_forwardingProbe), "old probe");
        Assertions.assertEq(newProbe, address(successor), "new probe");

        // Execution rechecks consult the successor: a failing record on the OLD
        // probe no longer admits an emergency raise...
        _forwardingProbe.setRun(50_000, false, uint64(block.number));
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeRecordMissing.selector,
                ROYALTY_RESOLVER_ID,
                uint256(50_000)
            )
        );
        _store.emergencyRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);
        // ...while a failing record on the successor does.
        successor.setRun(50_000, false, uint64(block.number));
        _armValueAction(ROYALTY_RESOLVER_ID, 100_000, 6);
        vm.prank(address(_authority));
        _store.emergencyRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);
        Assertions.assertEq(
            _store.gasParameter(ROYALTY_RESOLVER_ID), 100_000, "successor drives gates"
        );
    }

    function testProbeRebindDeadWithGovernanceLost() public {
        // With governance lost (zero authority) the binding is frozen — which is
        // why every probe is Permanent-class ([LTA-GGP-PROBES] rule 3).
        MockGasProbe successor = new MockGasProbe("ROYALTY_RESOLVER_GAS_LIMIT");
        address stranger = vm.addr(0x778);
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotAuthority.selector, stranger
            )
        );
        _zeroAuthorityStore.rebindGasParameterProbe(ROYALTY_RESOLVER_ID, address(successor));
        (,, address boundProbe,,,) = _zeroAuthorityStore.gasParameterInfo(ROYALTY_RESOLVER_ID);
        Assertions.assertEq(boundProbe, address(_zeroStoreProbe), "binding frozen");
    }

    // ------------------------------------------------------------------
    // Canonical event schema ([LTA-GGP] requirement 4)
    // ------------------------------------------------------------------

    function testGasParameterUpdatedEventSchema() public {
        _armValueAction(MINT_GATE_ID, 500_000, 1);
        vm.recordLogs();
        vm.prank(address(_authority));
        _store.raiseGasParameter(MINT_GATE_ID, 500_000);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        Assertions.assertEq(logs.length, 1, "single event");
        Assertions.assertEq(logs[0].emitter, address(_store), "emitted by host");
        Assertions.assertEq(logs[0].topics.length, 4, "three indexed topics");
        Assertions.assertEq(logs[0].topics[0], GAS_PARAMETER_UPDATED_TOPIC, "canonical signature");
        Assertions.assertEq(logs[0].topics[1], MINT_GATE_ID, "parameterId topic");
        Assertions.assertEq(
            logs[0].topics[2], bytes32(uint256(uint160(address(_store)))), "host topic"
        );
        Assertions.assertEq(logs[0].topics[3], ACTION_ID, "actionId topic");

        (uint16 schemaVersion, uint256 oldValue, uint256 newValue, uint256 floor) =
            abi.decode(logs[0].data, (uint16, uint256, uint256, uint256));
        Assertions.assertEq(uint256(schemaVersion), 1, "schema version");
        Assertions.assertEq(oldValue, 400_000, "old value");
        Assertions.assertEq(newValue, 500_000, "new value");
        Assertions.assertEq(floor, 100_000, "floor");
    }

    function testGasParameterRegisteredEventSchema() public {
        MockGasProbe probe = new MockGasProbe("ROYALTY_RESOLVER_GAS_LIMIT");
        _registerProbe(address(probe));
        IStreamGasParameterHost.GasParameterConfig[] memory configs =
            new IStreamGasParameterHost.GasParameterConfig[](1);
        configs[0] = _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, address(probe), 1);

        vm.recordLogs();
        StreamGasParameterStore store = new StreamGasParameterStore(
            address(0), address(_core), address(_moduleRegistry), configs
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Assertions.assertEq(logs.length, 1, "single registration event");
        Assertions.assertEq(logs[0].emitter, address(store), "emitted by host");
        Assertions.assertEq(
            logs[0].topics[0],
            keccak256(
                "GasParameterRegistered(uint16,bytes32,string,uint256,uint256,address,uint8,uint64,bytes32,bytes32)"
            ),
            "registration signature"
        );
        Assertions.assertEq(logs[0].topics[1], ROYALTY_RESOLVER_ID, "parameterId topic");

        (
            uint16 schemaVersion,
            string memory name,
            uint256 genesisValue,
            uint256 floor,
            address boundProbe,
            uint8 failureClass,
            uint64 maxAge,
            bytes32 raiseId,
            bytes32 relowerId
        ) = abi.decode(
            logs[0].data,
            (uint16, string, uint256, uint256, address, uint8, uint64, bytes32, bytes32)
        );
        Assertions.assertEq(uint256(schemaVersion), 1, "schema version");
        Assertions.assertEq(name, "ROYALTY_RESOLVER_GAS_LIMIT", "name");
        Assertions.assertEq(genesisValue, 50_000, "genesis");
        Assertions.assertEq(floor, 10_000, "floor");
        Assertions.assertEq(boundProbe, address(probe), "probe");
        Assertions.assertEq(uint256(failureClass), 1, "class");
        Assertions.assertEq(uint256(maxAge), uint256(MAX_AGE), "max age");
        Assertions.assertTrue(
            raiseId != bytes32(0) && relowerId != bytes32(0), "conditional ids registered"
        );
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    function _adversarialProbeStore()
        private
        returns (StreamGasParameterStore store, MockAdversarialProbeRun probe)
    {
        probe = new MockAdversarialProbeRun(ROYALTY_RESOLVER_ID, 0);
        IStreamGasParameterHost.GasParameterConfig[] memory configs =
            new IStreamGasParameterHost.GasParameterConfig[](1);
        configs[0] = _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, address(probe), 1);
        store = new StreamGasParameterStore(
            address(0), address(_core), address(_moduleRegistry), configs
        );
        _moduleRegistry.registerGasProbe(address(probe));
    }

    function _assertMalformedRaiseRejected(
        StreamGasParameterStore store,
        MockAdversarialProbeRun probe,
        MockAdversarialProbeRun.ResponseMode responseMode
    ) private {
        probe.setResponseMode(responseMode);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeRecordMissing.selector,
                ROYALTY_RESOLVER_ID,
                uint256(50_000)
            )
        );
        store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 100_000);
        _assertAdversarialGasState(store, 50_000, 1);
    }

    function _assertMalformedRelowerRejected(
        StreamGasParameterStore store,
        MockAdversarialProbeRun probe,
        MockAdversarialProbeRun.ResponseMode responseMode
    ) private {
        probe.setResponseMode(responseMode);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeRecordMissing.selector,
                ROYALTY_RESOLVER_ID,
                uint256(60_000)
            )
        );
        store.conditionalRelowerGasParameter(ROYALTY_RESOLVER_ID, 60_000);
        _assertAdversarialGasState(store, 100_000, 2);
    }

    function _assertAdversarialGasState(
        StreamGasParameterStore store,
        uint256 expectedValue,
        uint64 expectedRevision
    ) private view {
        (uint256 value,,,,, uint64 revision) = store.gasParameterInfo(ROYALTY_RESOLVER_ID);
        Assertions.assertEq(value, expectedValue, "malformed probe changed gas value");
        Assertions.assertEq(
            uint256(revision), uint256(expectedRevision), "malformed probe changed gas revision"
        );
    }

    function _registerProbe(address probe) private {
        _moduleRegistry.registerGasProbe(probe);
    }

    function _probeBindingHash(address probe) private view returns (bytes32) {
        return _probeBindingHashAt(_moduleRegistry, probe);
    }

    function _probeBindingHashAt(MockParameterModuleRegistry registry, address probe)
        private
        view
        returns (bytes32)
    {
        MockParameterModuleRecordV2 memory record = registry.moduleRecord(probe);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_GGP_PROBE_BINDING_V1"),
                address(registry),
                probe,
                record.moduleType,
                record.interfaceId,
                record.moduleVersion,
                probe.codehash,
                record.moduleManifestHash,
                record.deploymentManifestHash
            )
        );
    }

    function _scopeHash(StreamGasParameterStore store, bytes32 parameterId)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_GAS_PARAMETER_SCOPE_V1"),
                block.chainid,
                address(store),
                parameterId
            )
        );
    }

    function _stateHash(
        StreamGasParameterStore store,
        bytes32 parameterId,
        uint256 value,
        address probe,
        uint64 revision
    ) private view returns (bytes32) {
        ProbeBindingFacts memory binding = ProbeBindingFacts({
            probe: probe, runtimeCodeHash: probe.codehash, bindingHash: _probeBindingHash(probe)
        });
        return _stateHashWithBinding(store, parameterId, value, binding, revision);
    }

    function _stateHashWithBinding(
        StreamGasParameterStore store,
        bytes32 parameterId,
        uint256 value,
        ProbeBindingFacts memory binding,
        uint64 revision
    ) private view returns (bytes32) {
        (, uint256 floor,, uint8 failureClass, uint64 maxAge,) = store.gasParameterInfo(parameterId);
        (bytes32 conditionalRaiseId, bytes32 conditionalRelowerId) =
            store.conditionalGasParameterActions(parameterId);
        bytes32 scopeHash = _scopeHash(store, parameterId);
        GasParameterStateCommitment memory state = GasParameterStateCommitment({
            scopeHash: scopeHash,
            value: value,
            floor: floor,
            probe: binding.probe,
            probeRuntimeCodeHash: binding.runtimeCodeHash,
            probeBindingHash: binding.bindingHash,
            failureClass: failureClass,
            probeMaxAgeBlocks: maxAge,
            conditionalRaiseActionId: conditionalRaiseId,
            conditionalRelowerActionId: conditionalRelowerId,
            revision: revision
        });
        return keccak256(abi.encode(keccak256("6529STREAM_GAS_PARAMETER_STATE_V1"), state));
    }

    function _armValueAction(bytes32 parameterId, uint256 newValue, uint8 actionClass) private {
        (uint256 value,, address probe,,, uint64 revision) = _store.gasParameterInfo(parameterId);
        bytes32 scopeHash = _scopeHash(_store, parameterId);
        _setActionContext(
            actionClass,
            scopeHash,
            _stateHash(_store, parameterId, value, probe, revision),
            _stateHash(_store, parameterId, newValue, probe, revision + 1)
        );
    }

    function _armProbeRebindAction(bytes32 parameterId, address newProbe, uint8 actionClass)
        private
    {
        (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash) =
            _rebindTransitionHashes(parameterId, newProbe);
        _setActionContext(actionClass, scopeHash, oldStateHash, newStateHash);
    }

    function _rebindTransitionHashes(bytes32 parameterId, address newProbe)
        private
        view
        returns (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash)
    {
        (uint256 value,, address oldProbe,,, uint64 revision) = _store.gasParameterInfo(parameterId);
        scopeHash = _scopeHash(_store, parameterId);
        oldStateHash = _stateHash(_store, parameterId, value, oldProbe, revision);
        newStateHash = _stateHash(_store, parameterId, value, newProbe, revision + 1);
    }

    function _setActionContext(
        uint8 actionClass,
        bytes32 scopeHash,
        bytes32 oldStateHash,
        bytes32 newStateHash
    ) private {
        _authority.setCurrentAction(
            true, ACTION_ID, actionClass, scopeHash, oldStateHash, newStateHash
        );
    }

    function _config(
        string memory name,
        uint256 genesisValue,
        uint256 floor,
        address probe,
        uint8 failureClass
    ) private view returns (IStreamGasParameterHost.GasParameterConfig memory) {
        bytes32 runtimeCodeHash = probe.codehash;
        if (runtimeCodeHash == bytes32(0)) {
            runtimeCodeHash = keccak256(abi.encode("predicted probe runtime", probe));
        }
        return IStreamGasParameterHost.GasParameterConfig({
            name: name,
            genesisValue: genesisValue,
            floor: floor,
            probe: probe,
            failureClass: failureClass,
            probeMaxAgeBlocks: MAX_AGE,
            expectedProbeModuleVersion: bytes32(uint256(1)),
            expectedProbeRuntimeCodeHash: runtimeCodeHash,
            expectedProbeModuleManifestHash: keccak256(abi.encode("module", probe)),
            expectedProbeDeploymentManifestHash: keccak256(abi.encode("deployment", probe))
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
}
