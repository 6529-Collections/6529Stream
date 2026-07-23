// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/IStreamGasParameterHost.sol";
import "../smart-contracts/IStreamGasParameterProbe.sol";
import "../smart-contracts/IERC165.sol";
import "../smart-contracts/StreamForwardingCapProbe.sol";
import "../smart-contracts/StreamGasParameterStore.sol";
import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";
import "./helpers/GovernedParameterTestMocks.sol";

/// @notice [LTA-GGP-PROBES] probe-integrity matrix against the real
///         `StreamForwardingCapProbe`: the genuine-failure rule (an under-funded
///         run reverts without recording), pinned caller-independent inputs,
///         permissionless callability, canonical `GasParameterProbed` /
///         `lastProbeRun` records hosted on the probe — plus the rule 9
///         zero-signer museum-mode drill executing the probe-and-conditional-raise
///         path and its conditional-re-lower twin end to end.
contract StreamGasProbeTest is CharacterizationTestBase {
    uint256 private constant START_BLOCK = 2_000_000;

    bytes32 private constant ROYALTY_RESOLVER_ID =
        0x9bae92ab1dd0c5535c65125ea4ee7cff3d55fc31fc2555096c2b5eabceb5bcda;

    // keccak256("GasParameterProbed(uint16,bytes32,bytes32,bool,uint256,bytes32)")
    bytes32 private constant GAS_PARAMETER_PROBED_TOPIC =
        0xd9c2055d37293d47f04effc01ed554741da5c02914ffd5c247ee012a7a2be889;

    GasBurningConsumer private _consumer;
    StreamForwardingCapProbe private _probe;
    MockParameterCorePointer private _core;
    MockParameterModuleRegistry private _moduleRegistry;

    function setUp() public {
        vm.roll(START_BLOCK);
        _consumer = new GasBurningConsumer();
        _probe = new StreamForwardingCapProbe(
            "ROYALTY_RESOLVER_GAS_LIMIT", address(_consumer), abi.encodeWithSignature("read()")
        );
        _core = new MockParameterCorePointer();
        _moduleRegistry = new MockParameterModuleRegistry();
        _moduleRegistry.registerGasProbe(address(_probe));
        _core.setLiveModuleRegistry(address(_moduleRegistry), address(_moduleRegistry));
    }

    // ------------------------------------------------------------------
    // Pinned identity and scenario ([LTA-GGP-PROBES] rule 4)
    // ------------------------------------------------------------------

    function testProbeIdentityAndPinnedScenario() public view {
        Assertions.assertEq(_probe.probedParameterId(), ROYALTY_RESOLVER_ID, "derived id");
        Assertions.assertEq(_probe.scenarioTarget(), address(_consumer), "pinned target");
        Assertions.assertEq(
            keccak256(_probe.scenarioCallData()),
            keccak256(abi.encodeWithSignature("read()")),
            "pinned calldata"
        );
        Assertions.assertEq(
            _probe.scenarioHash(),
            keccak256(abi.encode(address(_consumer), abi.encodeWithSignature("read()"))),
            "scenario commitment"
        );
    }

    function testProbeCanonicalErc165Surface() public view {
        bytes4 probeInterfaceId = type(IStreamGasParameterProbe).interfaceId;
        Assertions.assertEq(
            uint256(uint32(probeInterfaceId)),
            uint256(uint32(bytes4(0x0f8c6b0f))),
            "canonical gas-probe interface id"
        );
        Assertions.assertTrue(_probe.supportsInterface(probeInterfaceId), "gas probe interface");
        Assertions.assertTrue(
            _probe.supportsInterface(type(IERC165).interfaceId), "ERC165 interface"
        );
        Assertions.assertFalse(_probe.supportsInterface(0xffffffff), "invalid interface rejected");
    }

    function testProbeConstructionGuards() public {
        // Empty parameter name.
        try new StreamForwardingCapProbe("", address(_consumer), bytes("")) returns (
            StreamForwardingCapProbe
        ) {
            Assertions.assertTrue(false, "empty name should revert");
        } catch (bytes memory err) {
            Assertions.assertEq(
                keccak256(err),
                keccak256(
                    abi.encodeWithSelector(StreamGasProbe.StreamGasProbeInvalidScenario.selector)
                ),
                "empty name error"
            );
        }
        // Target without code.
        try new StreamForwardingCapProbe(
            "ROYALTY_RESOLVER_GAS_LIMIT", vm.addr(0xEE), bytes("")
        ) returns (
            StreamForwardingCapProbe
        ) {
            Assertions.assertTrue(false, "code-less target should revert");
        } catch (bytes memory err) {
            Assertions.assertEq(
                keccak256(err),
                keccak256(
                    abi.encodeWithSelector(StreamGasProbe.StreamGasProbeInvalidScenario.selector)
                ),
                "code-less target error"
            );
        }
        // An EIP-7702 designation is code-bearing but remains controlled by an
        // EOA that can replace or clear the pinned behavior later.
        address delegatedTarget = vm.addr(0x770220);
        vm.etch(delegatedTarget, abi.encodePacked(hex"ef0100", bytes20(address(_consumer))));
        try new StreamForwardingCapProbe(
            "ROYALTY_RESOLVER_GAS_LIMIT", delegatedTarget, abi.encodeWithSignature("read()")
        ) returns (
            StreamForwardingCapProbe
        ) {
            Assertions.assertTrue(false, "delegated target should revert");
        } catch (bytes memory err) {
            Assertions.assertEq(
                keccak256(err),
                keccak256(
                    abi.encodeWithSelector(StreamGasProbe.StreamGasProbeInvalidScenario.selector)
                ),
                "delegated target error"
            );
        }
    }

    // ------------------------------------------------------------------
    // Recording behavior and canonical record surface
    // ------------------------------------------------------------------

    function testPassingRunRecordsOnProbeAndEmitsCanonicalEvent() public {
        vm.recordLogs();
        vm.prank(vm.addr(0x111)); // permissionless: any caller, no role, no fee
        (bytes32 probeRunId, bool passed) = _probe.recordProbeRun(60_000);
        Assertions.assertTrue(passed, "healthy read passes");
        Assertions.assertTrue(probeRunId != bytes32(0), "run id assigned");

        (bytes32 storedRunId, bool storedPassed, uint64 probedAtBlock) =
            _probe.lastProbeRun(ROYALTY_RESOLVER_ID, 60_000);
        Assertions.assertEq(storedRunId, probeRunId, "record on probe");
        Assertions.assertTrue(storedPassed, "record passed");
        Assertions.assertEq(uint256(probedAtBlock), block.number, "record block");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        Assertions.assertEq(logs.length, 1, "single probe event");
        Assertions.assertEq(logs[0].emitter, address(_probe), "record lives on the probe");
        Assertions.assertEq(logs[0].topics.length, 3, "two indexed topics");
        Assertions.assertEq(logs[0].topics[0], GAS_PARAMETER_PROBED_TOPIC, "canonical signature");
        Assertions.assertEq(logs[0].topics[1], ROYALTY_RESOLVER_ID, "parameterId topic");
        Assertions.assertEq(logs[0].topics[2], probeRunId, "probeRunId topic");
        (uint16 schemaVersion, bool eventPassed, uint256 probedValue, bytes32 evidenceHash) =
            abi.decode(logs[0].data, (uint16, bool, uint256, bytes32));
        Assertions.assertEq(uint256(schemaVersion), 1, "schema version");
        Assertions.assertTrue(eventPassed, "event passed flag");
        Assertions.assertEq(probedValue, 60_000, "event probed value");
        Assertions.assertTrue(evidenceHash != bytes32(0), "evidence committed");
    }

    function testGenuineFailingRunRecords() public {
        // Degrade the guarded read past the candidate value: the call genuinely
        // receives 60_000 gas (proved by the delivery guard) and still fails.
        _consumer.setBurnGas(300_000);
        (bytes32 probeRunId, bool passed) = _probe.recordProbeRun(60_000);
        Assertions.assertFalse(passed, "genuine failure recorded");
        (bytes32 storedRunId, bool storedPassed,) = _probe.lastProbeRun(ROYALTY_RESOLVER_ID, 60_000);
        Assertions.assertEq(storedRunId, probeRunId, "failing record stored");
        Assertions.assertFalse(storedPassed, "failing record flag");

        // A later run at the same value overwrites with a fresh verdict and a
        // fresh run id.
        _consumer.setBurnGas(0);
        (bytes32 secondRunId, bool secondPassed) = _probe.recordProbeRun(60_000);
        Assertions.assertTrue(secondPassed, "recovered verdict");
        Assertions.assertTrue(secondRunId != probeRunId, "unique run ids");
    }

    function testCodelessTargetRunRevertsWithoutRecording() public {
        // A genuine failing record exists first: the raise arm is live.
        _consumer.setBurnGas(300_000);
        (bytes32 failingRunId, bool passed) = _probe.recordProbeRun(60_000);
        Assertions.assertFalse(passed, "genuine failure recorded first");

        // The pinned scenario target loses its code (destroyed implementation,
        // SELFDESTRUCT-era target, future-fork code removal). A staticcall to a
        // codeless account vacuously succeeds, so without the guard every run
        // would record a forged PASS at any probedValue — arming permissionless
        // re-lowers on false evidence and making failing runs unrecordable. The
        // run must instead revert with nothing recorded.
        vm.etch(address(_consumer), "");
        Assertions.assertEq(uint256(address(_consumer).code.length), 0, "target code cleared");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamGasProbe.StreamGasProbeCodelessTarget.selector, address(_consumer)
            )
        );
        _probe.recordProbeRun(60_000);

        // The earlier genuine failing record is untouched.
        (bytes32 runId, bool storedPassed,) = _probe.lastProbeRun(ROYALTY_RESOLVER_ID, 60_000);
        Assertions.assertEq(runId, failingRunId, "record unchanged");
        Assertions.assertFalse(storedPassed, "still a failing record");

        // Nor can a forged pass be minted at any other candidate value.
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamGasProbe.StreamGasProbeCodelessTarget.selector, address(_consumer)
            )
        );
        _probe.recordProbeRun(1_000_000);
        (runId,,) = _probe.lastProbeRun(ROYALTY_RESOLVER_ID, 1_000_000);
        Assertions.assertEq(runId, bytes32(0), "no forged record");
    }

    // ------------------------------------------------------------------
    // Genuine-failure rule ([LTA-GGP-PROBES] rule 5)
    // ------------------------------------------------------------------

    function testUnderfundedRunRevertsWithoutRecording() public {
        UnderfundedProbeCaller caller = new UnderfundedProbeCaller();

        // With 200_000 probed, the delivery proof demands roughly
        // (200_000 + 15_000) * 64 / 63 gas inside the probe frame. A 210_000
        // budget cannot prove delivery: the run must revert with nothing
        // recorded — a manufactured under-funded call can never arm an
        // emergency or conditional raise.
        bool ok = caller.tryRecord(address(_probe), 200_000, 210_000);
        Assertions.assertFalse(ok, "under-funded run reverts");
        (bytes32 runId, bool passed, uint64 probedAtBlock) =
            _probe.lastProbeRun(ROYALTY_RESOLVER_ID, 200_000);
        Assertions.assertEq(runId, bytes32(0), "no record written");
        Assertions.assertFalse(passed, "no verdict written");
        Assertions.assertEq(uint256(probedAtBlock), 0, "no block written");

        // Starving the run even harder still records nothing.
        ok = caller.tryRecord(address(_probe), 200_000, 60_000);
        Assertions.assertFalse(ok, "starved run reverts");
        (runId,,) = _probe.lastProbeRun(ROYALTY_RESOLVER_ID, 200_000);
        Assertions.assertEq(runId, bytes32(0), "still no record");

        // The same call with genuine funding records a passing run.
        ok = caller.tryRecord(address(_probe), 200_000, 400_000);
        Assertions.assertTrue(ok, "funded run records");
        (runId, passed,) = _probe.lastProbeRun(ROYALTY_RESOLVER_ID, 200_000);
        Assertions.assertTrue(runId != bytes32(0), "record written");
        Assertions.assertTrue(passed, "funded verdict");
    }

    function testZeroProbedValueRejected() public {
        vm.expectRevert(
            abi.encodeWithSelector(StreamGasProbe.StreamGasProbeInvalidProbedValue.selector)
        );
        _probe.recordProbeRun(0);
    }

    function testLastProbeRunScopedToServedParameter() public {
        _probe.recordProbeRun(60_000);
        (bytes32 runId, bool passed, uint64 probedAtBlock) =
            _probe.lastProbeRun(keccak256("some-other-parameter"), 60_000);
        Assertions.assertEq(runId, bytes32(0), "foreign id zeroed");
        Assertions.assertFalse(passed, "foreign id no verdict");
        Assertions.assertEq(uint256(probedAtBlock), 0, "foreign id no block");
    }

    // ------------------------------------------------------------------
    // Zero-signer museum-mode drill ([LTA-GGP-PROBES] rule 9;
    // [LTA-GGP] requirement 11)
    // ------------------------------------------------------------------

    function testMuseumModeDrillConditionalRaiseAndRelowerEndToEnd() public {
        // A host with no governance at all: authority is address(0), so no
        // governance signer exists anywhere in this drill.
        IStreamGasParameterHost.GasParameterConfig[] memory configs =
            new IStreamGasParameterHost.GasParameterConfig[](1);
        configs[0] = IStreamGasParameterHost.GasParameterConfig({
            name: "ROYALTY_RESOLVER_GAS_LIMIT",
            genesisValue: 60_000,
            floor: 20_000,
            probe: address(_probe),
            failureClass: 1, // FORWARDING_CAP
            probeMaxAgeBlocks: 50_400,
            expectedProbeModuleVersion: bytes32(uint256(1)),
            expectedProbeRuntimeCodeHash: address(_probe).codehash,
            expectedProbeModuleManifestHash: keccak256(abi.encode("module", address(_probe))),
            expectedProbeDeploymentManifestHash: keccak256(
                abi.encode("deployment", address(_probe))
            )
        });
        StreamGasParameterStore store = new StreamGasParameterStore(
            address(0), address(_core), address(_moduleRegistry), configs
        );
        Assertions.assertEq(store.governanceAuthority(), address(0), "no signer");

        // While healthy, a stranger cannot ratchet the cap: the fresh passing
        // record at the current value blocks the conditional raise.
        vm.prank(vm.addr(0x1001));
        _probe.recordProbeRun(60_000);
        vm.prank(vm.addr(0x1002));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeHealthy.selector,
                ROYALTY_RESOLVER_ID,
                uint256(60_000)
            )
        );
        store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 120_000);

        // A repricing degrades the guarded read far past the cap.
        _consumer.setBurnGas(300_000);

        // Anyone walks the cap up: probe the current value, execute the
        // conditional raise, and repeat until the probe passes.
        vm.prank(vm.addr(0x2001));
        (, bool passed) = _probe.recordProbeRun(60_000);
        Assertions.assertFalse(passed, "degraded at 60k");
        vm.prank(vm.addr(0x2002));
        store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 120_000);
        Assertions.assertEq(store.gasParameter(ROYALTY_RESOLVER_ID), 120_000, "step 1");

        vm.prank(vm.addr(0x2003));
        (, passed) = _probe.recordProbeRun(120_000);
        Assertions.assertFalse(passed, "degraded at 120k");
        vm.prank(vm.addr(0x2004));
        store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 240_000);
        Assertions.assertEq(store.gasParameter(ROYALTY_RESOLVER_ID), 240_000, "step 2");

        vm.prank(vm.addr(0x2005));
        (, passed) = _probe.recordProbeRun(240_000);
        Assertions.assertFalse(passed, "degraded at 240k");
        vm.prank(vm.addr(0x2006));
        store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 480_000);
        Assertions.assertEq(store.gasParameter(ROYALTY_RESOLVER_ID), 480_000, "step 3");

        // Service restored: the probe passes at the current value, which also
        // re-locks the raise ratchet.
        vm.prank(vm.addr(0x2007));
        (, passed) = _probe.recordProbeRun(480_000);
        Assertions.assertTrue(passed, "restored at 480k");
        vm.prank(vm.addr(0x2008));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterProbeHealthy.selector,
                ROYALTY_RESOLVER_ID,
                uint256(480_000)
            )
        );
        store.conditionalRaiseGasParameter(ROYALTY_RESOLVER_ID, 960_000);

        // The repricing is reversed; fixed-stipend readers need the cap back
        // down. Anyone walks it down with probe-passing half-steps.
        _consumer.setBurnGas(0);

        vm.prank(vm.addr(0x3001));
        (, passed) = _probe.recordProbeRun(240_000);
        Assertions.assertTrue(passed, "reversal at 240k");
        vm.prank(vm.addr(0x3002));
        store.conditionalRelowerGasParameter(ROYALTY_RESOLVER_ID, 240_000);
        Assertions.assertEq(store.gasParameter(ROYALTY_RESOLVER_ID), 240_000, "walk-down 1");

        vm.prank(vm.addr(0x3003));
        (, passed) = _probe.recordProbeRun(120_000);
        Assertions.assertTrue(passed, "reversal at 120k");
        vm.prank(vm.addr(0x3004));
        store.conditionalRelowerGasParameter(ROYALTY_RESOLVER_ID, 120_000);
        Assertions.assertEq(store.gasParameter(ROYALTY_RESOLVER_ID), 120_000, "walk-down 2");

        vm.prank(vm.addr(0x3005));
        (, passed) = _probe.recordProbeRun(60_000);
        Assertions.assertTrue(passed, "reversal at 60k");
        vm.prank(vm.addr(0x3006));
        store.conditionalRelowerGasParameter(ROYALTY_RESOLVER_ID, 60_000);
        Assertions.assertEq(
            store.gasParameter(ROYALTY_RESOLVER_ID), 60_000, "self-corrected both directions"
        );

        // The floor survives even after total governance loss.
        vm.prank(vm.addr(0x3007));
        _probe.recordProbeRun(19_999);
        vm.prank(vm.addr(0x3008));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterLowerBoundExceeded.selector,
                ROYALTY_RESOLVER_ID,
                uint256(60_000),
                uint256(19_999)
            )
        );
        store.conditionalRelowerGasParameter(ROYALTY_RESOLVER_ID, 19_999);
    }
}
