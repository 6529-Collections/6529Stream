// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamGasProbe.sol";

/// @notice Concrete reference probe for `FORWARDING_CAP`-class Governed Gas
///         Parameters ([LTA-GGP] requirement 10): parameters that bound the gas
///         forwarded to a fail-safe read (royalty resolver reads, metadata router
///         reads, entropy view reads, finality component reads). The probe
///         replicates the production guarded path — a bounded `staticcall` of a
///         pinned reference consumer — at the candidate value and records whether
///         the read completes within that cap.
/// @dev    The scenario is pinned at deployment ([LTA-GGP-PROBES] rule 4): target
///         and calldata are fixed, caller-independent, and committed by
///         `scenarioHash`, which every run's `evidenceHash` commits to in turn. The
///         only caller-supplied input is the candidate value itself. The guarded
///         call runs through `_provedStaticcall`, so an under-funded run reverts
///         without recording (rule 5) and a recorded failing run proves the
///         reference read genuinely received `probedValue` and still failed. The
///         probe holds no funds, no protocol authority, and no mutable state
///         beyond its own probe records (rule 8); no production read routes
///         through it.
contract StreamForwardingCapProbe is StreamGasProbe {
    /// @dev keccak256("6529STREAM_GGP_PROBE_EVIDENCE_V1") — evidence commitment
    ///      domain for this probe family's measurement artifact.
    bytes32 private constant _PROBE_EVIDENCE_DOMAIN_V1 =
        keccak256("6529STREAM_GGP_PROBE_EVIDENCE_V1");

    /// @notice The pinned reference consumer whose guarded read the probe executes.
    address public immutable scenarioTarget;

    /// @notice Commitment to the pinned input corpus:
    ///         `keccak256(abi.encode(scenarioTarget, scenarioCallData))`.
    bytes32 public immutable scenarioHash;

    bytes private _scenarioCallData;

    /// @param parameterName The bare [LTA-GGP] constant name this probe serves.
    /// @param target The deployed reference consumer executed by every run.
    /// @param callData The pinned calldata of the guarded read.
    constructor(string memory parameterName, address target, bytes memory callData)
        StreamGasProbe(parameterName)
    {
        if (target == address(0) || target.code.length == 0 || _isEip7702DelegatedEOA(target)) {
            revert StreamGasProbeInvalidScenario();
        }
        scenarioTarget = target;
        _scenarioCallData = callData;
        scenarioHash = keccak256(abi.encode(target, callData));
    }

    /// @notice The pinned calldata executed by every probe run.
    function scenarioCallData() external view returns (bytes memory) {
        return _scenarioCallData;
    }

    /// @dev A `FORWARDING_CAP` run passes when the pinned fail-safe read completes
    ///      within `probedValue` gas; a proved-delivery failure (revert or
    ///      exhaustion at the full probed value) records as a genuine failing run.
    ///      `evidenceHash` commits to the pinned scenario, the candidate value, the
    ///      outcome, the measured gas, and the returndata of the run.
    function _executeGuardedScenario(uint256 probedValue)
        internal
        view
        override
        returns (bool passed, bytes32 evidenceHash)
    {
        (bool success, bytes memory returndata, uint256 gasUsed) =
            _provedStaticcall(scenarioTarget, _scenarioCallData, probedValue);
        passed = success;
        evidenceHash = keccak256(
            abi.encode(
                _PROBE_EVIDENCE_DOMAIN_V1,
                scenarioHash,
                probedValue,
                success,
                gasUsed,
                keccak256(returndata)
            )
        );
    }

    /// @dev A delegated EOA can execute a contract's code today but can clear or
    ///      replace that delegation later, so it cannot be a pinned scenario.
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
