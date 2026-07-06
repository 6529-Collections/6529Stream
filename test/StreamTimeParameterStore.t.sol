// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/IStreamTimeParameterHost.sol";
import "../smart-contracts/StreamCadenceProbe.sol";
import "../smart-contracts/StreamTimeParameterStore.sol";
import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";
import "./helpers/GovernedParameterTestMocks.sol";

/// @notice [LTA-GTP] discipline suite: parameterId derivation goldens for the
///         three coordinator genesis rows, timeParameterInfo introspection,
///         registration pins (block floor, wall-clock floor, cadence-probe
///         cross-check), governance-only change paths with 2x raise / half lower
///         bounds, block-floor and wall-clock-floor rejection, cadence-probe-gated
///         lowering, canonical event schemas, and the negative test that no
///         emergency or permissionless conditional path exists for GTPs.
contract StreamTimeParameterStoreTest is CharacterizationTestBase {
    uint256 private constant START_BLOCK = 3_000_000;
    uint256 private constant START_TIMESTAMP = 1_000_000_000;
    uint64 private constant MAX_AGE = 50_400;
    uint64 private constant WINDOW = 1_000;
    bytes32 private constant ACTION_ID = keccak256("test-governance-action");

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
    StreamCadenceProbe private _cadenceProbe;
    StreamTimeParameterStore private _store;

    function setUp() public {
        vm.roll(START_BLOCK);
        vm.warp(START_TIMESTAMP);
        _authority = new MockGovernedParameterAuthority(true);
        _cadenceProbe = _newProbe();

        IStreamTimeParameterHost.TimeParameterConfig[] memory configs =
            new IStreamTimeParameterHost.TimeParameterConfig[](3);
        configs[0] = _config("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 600, 300, 3_600);
        configs[1] = _config("ENTROPY_REVEAL_SLO_BLOCKS", 1_200, 650, 7_200);
        configs[2] = _config("ENTROPY_RECOVERY_STEP_DELAY_BLOCKS", 300, 150, 1_800);
        _store = new StreamTimeParameterStore(address(_authority), configs);
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
            uint64 probeMaxAgeBlocks
        ) = _store.timeParameterInfo(TIMEOUT_ID);
        Assertions.assertEq(value, 600, "timeout value");
        Assertions.assertEq(floorBlocks, 300, "timeout block floor");
        Assertions.assertEq(uint256(wallClockFloorSeconds), 3_600, "timeout wall-clock floor");
        Assertions.assertEq(cadenceProbe, address(_cadenceProbe), "timeout probe binding");
        Assertions.assertEq(uint256(probeMaxAgeBlocks), uint256(MAX_AGE), "timeout recency bound");

        (value, floorBlocks, wallClockFloorSeconds, cadenceProbe, probeMaxAgeBlocks) =
            _store.timeParameterInfo(keccak256("nope"));
        Assertions.assertEq(value, 0, "unknown value");
        Assertions.assertEq(floorBlocks, 0, "unknown block floor");
        Assertions.assertEq(uint256(wallClockFloorSeconds), 0, "unknown wall-clock floor");
        Assertions.assertEq(cadenceProbe, address(0), "unknown probe");
        Assertions.assertEq(uint256(probeMaxAgeBlocks), 0, "unknown recency bound");

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
        IStreamTimeParameterHost.TimeParameterConfig[] memory configs
    ) external returns (StreamTimeParameterStore) {
        return new StreamTimeParameterStore(authority, configs);
    }

    function _expectDeployRevert(
        IStreamTimeParameterHost.TimeParameterConfig memory config,
        bytes memory expectedError,
        string memory message
    ) private {
        IStreamTimeParameterHost.TimeParameterConfig[] memory configs =
            new IStreamTimeParameterHost.TimeParameterConfig[](1);
        configs[0] = config;
        try this.deployStore(address(_authority), configs) returns (StreamTimeParameterStore) {
            Assertions.assertTrue(false, message);
        } catch (bytes memory err) {
            Assertions.assertEq(keccak256(err), keccak256(expectedError), message);
        }
    }

    function testRegistrationInvariantsRejectInvalidConfigs() public {
        // Empty name.
        IStreamTimeParameterHost.TimeParameterConfig memory bad =
            _config("", 600, 300, 3_600);
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
                IStreamTimeParameterHost.TimeParameterProbeMismatch.selector,
                TIMEOUT_ID,
                address(0)
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
        try this.deployStore(address(_authority), dupes) returns (StreamTimeParameterStore) {
            Assertions.assertTrue(false, "duplicate registration");
        } catch (bytes memory err) {
            Assertions.assertEq(
                keccak256(err),
                keccak256(
                    abi.encodeWithSelector(
                        IStreamTimeParameterHost.TimeParameterAlreadyRegistered.selector,
                        TIMEOUT_ID
                    )
                ),
                "duplicate registration error"
            );
        }
    }

    function testAuthorityMarkerAndGovernanceOnly() public {
        // Bad marker rejected at construction.
        MockGovernedParameterAuthority badAuthority = new MockGovernedParameterAuthority(false);
        IStreamTimeParameterHost.TimeParameterConfig[] memory configs =
            new IStreamTimeParameterHost.TimeParameterConfig[](1);
        configs[0] = _config("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 600, 300, 3_600);
        try this.deployStore(address(badAuthority), configs) returns (StreamTimeParameterStore) {
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
        _store.raiseTimeParameter(TIMEOUT_ID, 1_200, ACTION_ID);
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterNotAuthority.selector, stranger
            )
        );
        _store.lowerTimeParameter(TIMEOUT_ID, 300, ACTION_ID);

        // A zero-authority time store has no live change path at all: GTPs have
        // no lost-governance machinery ([LTA-GTP] change discipline 1).
        StreamTimeParameterStore zeroStore = this.deployStore(address(0), configs);
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterNotAuthority.selector, stranger
            )
        );
        zeroStore.raiseTimeParameter(TIMEOUT_ID, 1_200, ACTION_ID);
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
        _store.raiseTimeParameter(TIMEOUT_ID, 600, ACTION_ID);

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
        _store.raiseTimeParameter(TIMEOUT_ID, 1_201, ACTION_ID);

        // Exactly 2x accepted; no cadence record is required for a raise.
        vm.prank(address(_authority));
        _store.raiseTimeParameter(TIMEOUT_ID, 1_200, ACTION_ID);
        Assertions.assertEq(_store.timeParameter(TIMEOUT_ID), 1_200, "raise applied");

        // Unknown parameter.
        bytes32 unknownId = keccak256("unknown");
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterUnknown.selector, unknownId
            )
        );
        _store.raiseTimeParameter(unknownId, 100, ACTION_ID);
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
        _store.lowerTimeParameter(SLO_ID, 599, ACTION_ID);

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
        _store.lowerTimeParameter(SLO_ID, 649, ACTION_ID);

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
        _store.lowerTimeParameter(SLO_ID, 1_200, ACTION_ID);

        // Exactly half, at the block floor, with a passing record: accepted
        // (TIMEOUT row: 600 -> 300 covers 3600s at 12s cadence exactly).
        _cadenceProbe.recordCadenceRun(TIMEOUT_ID, 300);
        vm.prank(address(_authority));
        _store.lowerTimeParameter(TIMEOUT_ID, 300, ACTION_ID);
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
        _store.lowerTimeParameter(SLO_ID, 700, ACTION_ID);

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
                IStreamTimeParameterHost.TimeParameterProbeNotPassing.selector,
                SLO_ID,
                uint256(700)
            )
        );
        _store.lowerTimeParameter(SLO_ID, 700, ACTION_ID);

        // At the observed 12s cadence, 700 blocks cover 8400s >= 7200s: the run
        // passes and the lower executes.
        _finalizeSample(12);
        (, passed) = _cadenceProbe.recordCadenceRun(SLO_ID, 700);
        Assertions.assertTrue(passed, "candidate passes at normal cadence");
        vm.prank(address(_authority));
        _store.lowerTimeParameter(SLO_ID, 700, ACTION_ID);
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
        _store.lowerTimeParameter(SLO_ID, 660, ACTION_ID);
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
        try new StreamCadenceProbe(names, floors, WINDOW, WINDOW - 1) returns (
            StreamCadenceProbe
        ) {
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
        try new StreamCadenceProbe(names, twoFloors, WINDOW, MAX_AGE) returns (
            StreamCadenceProbe
        ) {
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
        vm.recordLogs();
        vm.prank(address(_authority));
        _store.raiseTimeParameter(TIMEOUT_ID, 900, ACTION_ID);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        Assertions.assertEq(logs.length, 1, "single event");
        Assertions.assertEq(logs[0].emitter, address(_store), "emitted by host");
        Assertions.assertEq(logs[0].topics.length, 4, "three indexed topics");
        Assertions.assertEq(
            logs[0].topics[0], TIME_PARAMETER_UPDATED_TOPIC, "canonical signature"
        );
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
        _store.rebindTimeParameterProbe(TIMEOUT_ID, address(successor), ACTION_ID);

        // Unknown parameter.
        bytes32 unknownId = keccak256("unknown");
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterUnknown.selector, unknownId
            )
        );
        _store.rebindTimeParameterProbe(unknownId, address(successor), ACTION_ID);

        // Zero successor.
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterProbeMismatch.selector,
                TIMEOUT_ID,
                address(0)
            )
        );
        _store.rebindTimeParameterProbe(TIMEOUT_ID, address(0), ACTION_ID);

        // A successor pinning a different wall-clock floor for the row cannot be
        // bound: the width a candidate must prove can never drift.
        StreamCadenceProbe wrongPinProbe =
            _singleRowProbe("ENTROPY_REQUEST_TIMEOUT_BLOCKS", 9_999);
        vm.prank(address(_authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterProbeMismatch.selector,
                TIMEOUT_ID,
                address(wrongPinProbe)
            )
        );
        _store.rebindTimeParameterProbe(TIMEOUT_ID, address(wrongPinProbe), ACTION_ID);

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
        _store.rebindTimeParameterProbe(TIMEOUT_ID, address(unservingProbe), ACTION_ID);
    }

    function testCadenceProbeRebindGovernedPathAndEventSchema() public {
        StreamCadenceProbe successor = _newProbe();

        // Governed rebind executes, moves the binding, and emits the
        // schema-versioned rebind event.
        vm.recordLogs();
        vm.prank(address(_authority));
        _store.rebindTimeParameterProbe(TIMEOUT_ID, address(successor), ACTION_ID);
        (,,, address boundProbe,) = _store.timeParameterInfo(TIMEOUT_ID);
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
        _store.lowerTimeParameter(TIMEOUT_ID, 400, ACTION_ID);

        // ...while a passing record on the successor does.
        successor.startCadenceSample();
        vm.roll(block.number + WINDOW);
        vm.warp(block.timestamp + WINDOW * 12);
        successor.finalizeCadenceSample();
        (, bool passed) = successor.recordCadenceRun(TIMEOUT_ID, 400);
        Assertions.assertTrue(passed, "successor run passes");
        vm.prank(address(_authority));
        _store.lowerTimeParameter(TIMEOUT_ID, 400, ACTION_ID);
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
        StreamTimeParameterStore zeroStore = this.deployStore(address(0), configs);

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterNotAuthority.selector, stranger
            )
        );
        zeroStore.rebindTimeParameterProbe(TIMEOUT_ID, address(successor), ACTION_ID);
        (,,, address frozenProbe,) = zeroStore.timeParameterInfo(TIMEOUT_ID);
        Assertions.assertEq(frozenProbe, address(_cadenceProbe), "binding frozen");
    }

    // ------------------------------------------------------------------
    // No emergency / no permissionless conditional path exists for GTPs
    // ([LTA-GTP] change discipline 1; ADR 0012 decision T1)
    // ------------------------------------------------------------------

    function testNoEmergencyOrConditionalPathOnTimeStore() public {
        bytes[] memory attempts = new bytes[](3);
        attempts[0] = abi.encodeWithSignature(
            "emergencyRaiseTimeParameter(bytes32,uint256,bytes32)",
            TIMEOUT_ID,
            uint256(1_200),
            ACTION_ID
        );
        attempts[1] = abi.encodeWithSignature(
            "conditionalRaiseTimeParameter(bytes32,uint256)", TIMEOUT_ID, uint256(1_200)
        );
        attempts[2] = abi.encodeWithSignature(
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

    function _newProbe() private returns (StreamCadenceProbe) {
        string[] memory names = new string[](3);
        names[0] = "ENTROPY_REQUEST_TIMEOUT_BLOCKS";
        names[1] = "ENTROPY_REVEAL_SLO_BLOCKS";
        names[2] = "ENTROPY_RECOVERY_STEP_DELAY_BLOCKS";
        uint64[] memory floors = new uint64[](3);
        floors[0] = 3_600;
        floors[1] = 7_200;
        floors[2] = 1_800;
        return new StreamCadenceProbe(names, floors, WINDOW, MAX_AGE);
    }

    function _singleRowProbe(string memory name, uint64 wallClockFloorSeconds)
        private
        returns (StreamCadenceProbe)
    {
        string[] memory names = new string[](1);
        names[0] = name;
        uint64[] memory floors = new uint64[](1);
        floors[0] = wallClockFloorSeconds;
        return new StreamCadenceProbe(names, floors, WINDOW, MAX_AGE);
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
            probeMaxAgeBlocks: MAX_AGE
        });
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
