// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamGasParameterProbe.sol";
import "./ERC165.sol";

/// @notice Abstract base for Permanent-class Governed Gas Parameter probes per
///         `docs/stream-long-term-architecture.md` [LTA-GGP-PROBES] rules 1-9.
/// @dev    Permanence posture ([LTA-GGP-PROBES] rules 2 and 8): no owner, no
///         upgrade path, no selfdestruct, no pause switch, no funds, no protocol
///         authority beyond writing its own probe records, and callable by anyone
///         forever with no role, allowlist, or fee. The probe-run record —
///         `GasParameterProbed` plus `lastProbeRun` — lives here on the probe
///         (rule 3; ADR 0012 decision T1); hosts consume it through the probe
///         address bound at parameter registration. A probe's executability never
///         depends on a healthy value of the parameter it probes (rule 7): the
///         base reads no Governed Gas Parameter and the candidate value is
///         supplied by the caller (current-value runs pass the live value read
///         from the host's `gasParameterInfo`).
///
///         Genuine-failure rule (rule 5): concrete probes execute their pinned,
///         caller-independent scenario (rule 4) through `_provedStaticcall`, which
///         proves under EIP-150 63/64 accounting that the guarded execution
///         actually received `probedValue` before it runs. An under-funded,
///         gas-shaped, or otherwise starved run reverts there — before any record
///         is written — so a recordable failing run exists only when the guarded
///         operation was genuinely given the probed value and still failed.
abstract contract StreamGasProbe is IStreamGasParameterProbe, ERC165 {
    /// @notice Schema version carried by every canonical probe-record event.
    uint16 public constant GAS_PARAMETER_PROBE_SCHEMA_VERSION = 1;

    /// @dev keccak256("6529STREAM_GGP_PROBE_RUN_V1") — probe-run id domain.
    bytes32 private constant _PROBE_RUN_DOMAIN_V1 = keccak256("6529STREAM_GGP_PROBE_RUN_V1");

    struct ProbeRun {
        bytes32 probeRunId;
        bool passed;
        uint64 probedAtBlock;
    }

    /// @inheritdoc IStreamGasParameterProbe
    bytes32 public immutable override probedParameterId;

    mapping(uint256 => ProbeRun) private _runs;
    uint256 private _runNonce;

    /// @notice Reverts when the probed candidate value is zero.
    error StreamGasProbeInvalidProbedValue();
    /// @notice Reverts when a probe run cannot prove the guarded execution would
    ///         genuinely receive `probedValue` ([LTA-GGP-PROBES] rule 5). Nothing
    ///         is recorded.
    error StreamGasProbeUnderfunded(uint256 requiredGas, uint256 availableGas);
    /// @notice Reverts when the guarded call's target has no code at run time.
    ///         A staticcall to a codeless account vacuously succeeds, so a pinned
    ///         target that lost its code (destroyed implementation, future-fork
    ///         code removal) would otherwise forge passing runs at any candidate
    ///         value — arming permissionless re-lowers on false evidence — while
    ///         making genuine failing runs unrecordable. Nothing is recorded.
    error StreamGasProbeCodelessTarget(address target);
    /// @notice Reverts when a probe is constructed with an invalid pinned scenario.
    error StreamGasProbeInvalidScenario();

    /// @param parameterName The bare [LTA-GGP] inventory constant name; the probe
    ///        derives `probedParameterId = keccak256("6529STREAM_GGP_" || name)`
    ///        so a mis-derived binding is impossible by construction.
    constructor(string memory parameterName) {
        if (bytes(parameterName).length == 0) {
            revert StreamGasProbeInvalidScenario();
        }
        probedParameterId = keccak256(abi.encodePacked("6529STREAM_GGP_", parameterName));
    }

    /// @notice Advertises the canonical gas-probe read surface required by the
    ///         module registry before a probe can be bound to a host.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IStreamGasParameterProbe).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /// @notice Executes the pinned guarded scenario at `probedValue` and records
    ///         the outcome onchain. Permissionless: no role, allowlist, or fee.
    /// @dev    Reverts without recording when the run cannot prove the guarded
    ///         execution received `probedValue` (genuine-failure rule).
    function recordProbeRun(uint256 probedValue)
        external
        returns (bytes32 probeRunId, bool passed)
    {
        if (probedValue == 0) {
            revert StreamGasProbeInvalidProbedValue();
        }

        bytes32 evidenceHash;
        (passed, evidenceHash) = _executeGuardedScenario(probedValue);

        unchecked {
            _runNonce += 1;
        }
        probeRunId = keccak256(
            abi.encode(
                _PROBE_RUN_DOMAIN_V1,
                block.chainid,
                address(this),
                probedParameterId,
                probedValue,
                block.number,
                _runNonce
            )
        );
        _runs[probedValue] = ProbeRun({
            probeRunId: probeRunId, passed: passed, probedAtBlock: uint64(block.number)
        });

        emit GasParameterProbed(
            GAS_PARAMETER_PROBE_SCHEMA_VERSION,
            probedParameterId,
            probeRunId,
            passed,
            probedValue,
            evidenceHash
        );
    }

    /// @inheritdoc IStreamGasParameterProbe
    function lastProbeRun(bytes32 parameterId, uint256 probedValue)
        external
        view
        override
        returns (bytes32 probeRunId, bool passed, uint64 probedAtBlock)
    {
        if (parameterId != probedParameterId) {
            return (bytes32(0), false, 0);
        }
        ProbeRun storage run = _runs[probedValue];
        return (run.probeRunId, run.passed, run.probedAtBlock);
    }

    // ---------------------------------------------------------------------
    // Guarded execution helpers
    // ---------------------------------------------------------------------

    /// @dev Executes the guarded call with exactly `probedValue` gas after proving
    ///      delivery under EIP-150: at the call site the EVM forwards
    ///      `min(requested, floor(63/64 * (gasleft - upfrontCost)))`, so requiring
    ///      `gasleft() >= (probedValue + overhead) * 64 / 63` with `overhead`
    ///      covering the upfront call cost (account access, memory expansion) and
    ///      the opcodes between the check and the CALL guarantees the callee
    ///      received the full `probedValue`. A caller that under-funds the run
    ///      trips `StreamGasProbeUnderfunded` before the call executes and nothing
    ///      is recorded ([LTA-GGP-PROBES] rule 5).
    ///
    ///      Genuine-execution precondition, inherited by every derived probe: a
    ///      codeless account cannot execute the guarded operation, yet the EVM
    ///      reports its staticcall as a vacuous success. If the pinned target
    ///      ever loses its code, every run reverts here — no forged pass can be
    ///      recorded and the probe never reports the guarded path healthy. The
    ///      check runs before the gas snapshot so its EXTCODESIZE cost never
    ///      skews the delivery proof (it also warms the account, keeping the
    ///      pinned overhead margin conservative).
    function _provedStaticcall(address target, bytes memory callData, uint256 probedValue)
        internal
        view
        returns (bool success, bytes memory returndata, uint256 gasUsed)
    {
        if (target.code.length == 0) {
            revert StreamGasProbeCodelessTarget(target);
        }
        uint256 requiredGas = ((probedValue + _callAccountingOverheadGas()) * 64) / 63;
        uint256 availableGas = gasleft();
        if (availableGas < requiredGas) {
            revert StreamGasProbeUnderfunded(requiredGas, availableGas);
        }
        uint256 gasBefore = gasleft();
        (success, returndata) = target.staticcall{ gas: probedValue }(callData);
        gasUsed = gasBefore - gasleft();
    }

    /// @dev Upfront-cost margin for `_provedStaticcall`'s delivery proof: covers
    ///      cold account access (2600), calldata memory expansion for the pinned
    ///      corpus, and the opcodes between the gas check and the CALL. Generous
    ///      by design — over-margin only demands the prober supply slightly more
    ///      gas; it can never admit an under-funded run. Probes with large pinned
    ///      input corpora must widen it.
    function _callAccountingOverheadGas() internal pure virtual returns (uint256) {
        return 15_000;
    }

    /// @dev Concrete probes execute their pinned, caller-independent scenario
    ///      ([LTA-GGP-PROBES] rule 4) at `probedValue` — through `_provedStaticcall`
    ///      (or an equivalent proved-delivery guard for state-changing guarded
    ///      operations) — and return the outcome plus the `evidenceHash` committing
    ///      to the run's measurement artifact.
    function _executeGuardedScenario(uint256 probedValue)
        internal
        virtual
        returns (bool passed, bytes32 evidenceHash);
}
