// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/IStreamGasParameterHost.sol";
import "../smart-contracts/StreamGasParameterStore.sol";
import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";
import "./helpers/GovernedParameterTestMocks.sol";

/// @notice [LTA-GGP] requirement 9 host-side conformance matrix: floor rejection,
///         2x per-action raise bound, staged vs probe-gated emergency raise,
///         probe-gated lower at exactly the proposed value, permissionless
///         conditional raise and re-lower with no governance signer for
///         FORWARDING_CAP, scope rejection for FAIL_CLOSED_PRECHECK and
///         MIN_GAS_GATE, gasParameterInfo introspection, canonical change-event
///         schema, and parameterId derivation goldens.
contract StreamGasParameterStoreTest is CharacterizationTestBase {
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

    MockGovernedParameterAuthority private _authority;
    MockGasProbe private _forwardingProbe;
    MockGasProbe private _mintGateProbe;
    MockGasProbe private _flushFloorProbe;
    MockGasProbe private _zeroStoreProbe;
    StreamGasParameterStore private _store;
    StreamGasParameterStore private _zeroAuthorityStore;

    function setUp() public {
        vm.roll(START_BLOCK);
        _authority = new MockGovernedParameterAuthority(true);
        _forwardingProbe = new MockGasProbe("ROYALTY_RESOLVER_GAS_LIMIT");
        _mintGateProbe = new MockGasProbe("MINT_GATE_GAS_LIMIT");
        _flushFloorProbe = new MockGasProbe("FLUSH_GAS_FLOOR");
        _zeroStoreProbe = new MockGasProbe("ROYALTY_RESOLVER_GAS_LIMIT");

        IStreamGasParameterHost.GasParameterConfig[] memory configs =
            new IStreamGasParameterHost.GasParameterConfig[](3);
        configs[0] = _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, address(_forwardingProbe), 1);
        configs[1] = _config("MINT_GATE_GAS_LIMIT", 400_000, 100_000, address(_mintGateProbe), 2);
        configs[2] = _config("FLUSH_GAS_FLOOR", 80_000, 40_000, address(_flushFloorProbe), 3);
        _store = new StreamGasParameterStore(address(_authority), configs);

        IStreamGasParameterHost.GasParameterConfig[] memory zeroConfigs =
            new IStreamGasParameterHost.GasParameterConfig[](1);
        zeroConfigs[0] =
            _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, address(_zeroStoreProbe), 1);
        _zeroAuthorityStore = new StreamGasParameterStore(address(0), zeroConfigs);
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

    // ------------------------------------------------------------------
    // Introspection ([LTA-GGP] requirement 12)
    // ------------------------------------------------------------------

    function testGasParameterInfoGoldenAndUnknownZeroed() public view {
        (uint256 value, uint256 floor, address probe, uint8 failureClass, uint64 maxAge) =
            _store.gasParameterInfo(ROYALTY_RESOLVER_ID);
        Assertions.assertEq(value, 50_000, "fc value");
        Assertions.assertEq(floor, 10_000, "fc floor");
        Assertions.assertEq(probe, address(_forwardingProbe), "fc probe");
        Assertions.assertEq(uint256(failureClass), 1, "fc class FORWARDING_CAP");
        Assertions.assertEq(uint256(maxAge), uint256(MAX_AGE), "fc max age");

        (value, floor, probe, failureClass, maxAge) = _store.gasParameterInfo(MINT_GATE_ID);
        Assertions.assertEq(value, 400_000, "fcp value");
        Assertions.assertEq(floor, 100_000, "fcp floor");
        Assertions.assertEq(probe, address(_mintGateProbe), "fcp probe");
        Assertions.assertEq(uint256(failureClass), 2, "fcp class FAIL_CLOSED_PRECHECK");
        Assertions.assertEq(uint256(maxAge), uint256(MAX_AGE), "fcp max age");

        (value, floor, probe, failureClass, maxAge) = _store.gasParameterInfo(FLUSH_GAS_FLOOR_ID);
        Assertions.assertEq(value, 80_000, "mgg value");
        Assertions.assertEq(floor, 40_000, "mgg floor");
        Assertions.assertEq(probe, address(_flushFloorProbe), "mgg probe");
        Assertions.assertEq(uint256(failureClass), 3, "mgg class MIN_GAS_GATE");
        Assertions.assertEq(uint256(maxAge), uint256(MAX_AGE), "mgg max age");

        // Unregistered parameterId returns the zeroed tuple.
        (value, floor, probe, failureClass, maxAge) = _store.gasParameterInfo(keccak256("nope"));
        Assertions.assertEq(value, 0, "unknown value");
        Assertions.assertEq(floor, 0, "unknown floor");
        Assertions.assertEq(probe, address(0), "unknown probe");
        Assertions.assertEq(uint256(failureClass), 0, "unknown class NONE");
        Assertions.assertEq(uint256(maxAge), 0, "unknown max age");
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
        return new StreamGasParameterStore(authority, configs);
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
        _store.raiseGasParameter(MINT_GATE_ID, 500_000, ACTION_ID);

        // Zero-authority hosts reject every caller on governed paths.
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotAuthority.selector, stranger
            )
        );
        _zeroAuthorityStore.raiseGasParameter(ROYALTY_RESOLVER_ID, 60_000, ACTION_ID);

        // Unknown parameter.
        bytes32 unknownId = keccak256("unknown");
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGasParameterHost.GasParameterUnknown.selector, unknownId)
        );
        _store.raiseGasParameter(unknownId, 500_000, ACTION_ID);

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
        _store.raiseGasParameter(MINT_GATE_ID, 400_000, ACTION_ID);

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
        _store.raiseGasParameter(MINT_GATE_ID, 800_001, ACTION_ID);

        // No probe record is required for a staged raise.
        vm.prank(address(_authority));
        _store.raiseGasParameter(MINT_GATE_ID, 500_000, ACTION_ID);
        Assertions.assertEq(_store.gasParameter(MINT_GATE_ID), 500_000, "staged raise applied");
    }

    function testStagedRaiseAtExactDoubleSucceeds() public {
        vm.prank(address(_authority));
        _store.raiseGasParameter(MINT_GATE_ID, 800_000, ACTION_ID);
        Assertions.assertEq(_store.gasParameter(MINT_GATE_ID), 800_000, "exact 2x raise");
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
        _store.emergencyRaiseGasParameter(MINT_GATE_ID, 600_000, ACTION_ID);

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
        _store.emergencyRaiseGasParameter(MINT_GATE_ID, 600_000, ACTION_ID);

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
        _store.emergencyRaiseGasParameter(MINT_GATE_ID, 600_000, ACTION_ID);

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
        _store.emergencyRaiseGasParameter(MINT_GATE_ID, 600_000, ACTION_ID);

        // A fresh failing record at the current value admits — at exactly the
        // recency bound.
        _mintGateProbe.setRun(400_000, false, uint64(block.number));
        vm.roll(block.number + MAX_AGE);
        vm.prank(address(_authority));
        _store.emergencyRaiseGasParameter(MINT_GATE_ID, 600_000, ACTION_ID);
        Assertions.assertEq(_store.gasParameter(MINT_GATE_ID), 600_000, "emergency raise applied");
    }

    function testEmergencyRaiseRepeatableWhileFailurePersists() public {
        _mintGateProbe.setRun(400_000, false, uint64(block.number));
        vm.prank(address(_authority));
        _store.emergencyRaiseGasParameter(MINT_GATE_ID, 800_000, ACTION_ID);

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
        _store.emergencyRaiseGasParameter(MINT_GATE_ID, 1_000_000, ACTION_ID);

        _mintGateProbe.setRun(800_000, false, uint64(block.number));
        vm.prank(address(_authority));
        _store.emergencyRaiseGasParameter(MINT_GATE_ID, 1_600_000, ACTION_ID);
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
        _store.emergencyRaiseGasParameter(MINT_GATE_ID, 300_000, ACTION_ID);

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
        _store.emergencyRaiseGasParameter(MINT_GATE_ID, 800_001, ACTION_ID);

        // Authority-only.
        address stranger = vm.addr(0xD00D);
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotAuthority.selector, stranger
            )
        );
        _store.emergencyRaiseGasParameter(MINT_GATE_ID, 800_000, ACTION_ID);
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
        _store.lowerGasParameter(MINT_GATE_ID, 400_000, ACTION_ID);

        // No record at the proposed value: blocked.
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeRecordMissing.selector,
                MINT_GATE_ID,
                uint256(200_000)
            )
        );
        _store.lowerGasParameter(MINT_GATE_ID, 200_000, ACTION_ID);

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
        _store.lowerGasParameter(MINT_GATE_ID, 200_000, ACTION_ID);

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
        _store.lowerGasParameter(MINT_GATE_ID, 200_000, ACTION_ID);

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
        _store.lowerGasParameter(MINT_GATE_ID, 200_000, ACTION_ID);

        // A fresh passing record at exactly the proposed value admits.
        _mintGateProbe.setRun(200_000, true, uint64(block.number));
        vm.prank(address(_authority));
        _store.lowerGasParameter(MINT_GATE_ID, 200_000, ACTION_ID);
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
        _store.lowerGasParameter(MINT_GATE_ID, 150_000, ACTION_ID);
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
        _store.lowerGasParameter(MINT_GATE_ID, 99_999, ACTION_ID);

        // Lowering to exactly the floor is allowed.
        _mintGateProbe.setRun(200_000, true, uint64(block.number));
        vm.prank(address(_authority));
        _store.lowerGasParameter(MINT_GATE_ID, 200_000, ACTION_ID);
        _mintGateProbe.setRun(100_000, true, uint64(block.number));
        vm.prank(address(_authority));
        _store.lowerGasParameter(MINT_GATE_ID, 100_000, ACTION_ID);
        Assertions.assertEq(_store.gasParameter(MINT_GATE_ID), 100_000, "lower to floor");
    }

    // ------------------------------------------------------------------
    // Permissionless conditional raise/re-lower ([LTA-GGP] requirement 11)
    // ------------------------------------------------------------------

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
        (bytes32 raiseId, bytes32 relowerId) =
            _store.conditionalGasParameterActions(MINT_GATE_ID);
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

    // ------------------------------------------------------------------
    // Canonical event schema ([LTA-GGP] requirement 4)
    // ------------------------------------------------------------------

    function testGasParameterUpdatedEventSchema() public {
        vm.recordLogs();
        vm.prank(address(_authority));
        _store.raiseGasParameter(MINT_GATE_ID, 500_000, ACTION_ID);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        Assertions.assertEq(logs.length, 1, "single event");
        Assertions.assertEq(logs[0].emitter, address(_store), "emitted by host");
        Assertions.assertEq(logs[0].topics.length, 4, "three indexed topics");
        Assertions.assertEq(
            logs[0].topics[0], GAS_PARAMETER_UPDATED_TOPIC, "canonical signature"
        );
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
        IStreamGasParameterHost.GasParameterConfig[] memory configs =
            new IStreamGasParameterHost.GasParameterConfig[](1);
        configs[0] = _config("ROYALTY_RESOLVER_GAS_LIMIT", 50_000, 10_000, address(probe), 1);

        vm.recordLogs();
        StreamGasParameterStore store = new StreamGasParameterStore(address(0), configs);
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

    function _config(
        string memory name,
        uint256 genesisValue,
        uint256 floor,
        address probe,
        uint8 failureClass
    ) private pure returns (IStreamGasParameterHost.GasParameterConfig memory) {
        return IStreamGasParameterHost.GasParameterConfig({
            name: name,
            genesisValue: genesisValue,
            floor: floor,
            probe: probe,
            failureClass: failureClass,
            probeMaxAgeBlocks: MAX_AGE
        });
    }
}
