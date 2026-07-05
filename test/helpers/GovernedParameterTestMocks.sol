// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/IStreamGasParameterProbe.sol";
import "../../smart-contracts/IStreamGovernedParameterAuthority.sol";

/// @notice Minimal governance-executor stand-in for the wiring seam; the real
///         executor is built by the governance wave.
contract MockGovernedParameterAuthority is IStreamGovernedParameterAuthority {
    bool private immutable _valid;

    constructor(bool valid) {
        _valid = valid;
    }

    function isStreamGovernedParameterAuthority() external view override returns (bool) {
        return _valid;
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
        (ok, ) = probe.call{ gas: gasBudget }(
            abi.encodeWithSignature("recordProbeRun(uint256)", probedValue)
        );
    }
}
