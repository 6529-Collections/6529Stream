// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamTimeParameterProbe.sol";

/// @notice Permanent-class cadence probe for Governed Time Parameters
///         ([LTA-GTP] definition item 6, under the [LTA-GGP-PROBES] rules).
///         Anyone can (1) record observed block cadence onchain over a sampling
///         window at least `CADENCE_SAMPLE_FLOOR_BLOCKS` wide and (2) record
///         pass/fail for a candidate block count against a served parameter's
///         pinned wall-clock floor at that observed cadence. One cadence probe
///         serves every GTP row of its host — observed cadence is a chain fact,
///         not a per-parameter path (ADR 0013 decision U9).
/// @dev    Permanence posture ([LTA-GGP-PROBES] rules 2, 7, 8): no owner, no
///         upgrade path, no selfdestruct, no pause switch, no fee, no funds, no
///         protocol authority beyond its own probe records, and its executability
///         never depends on any parameter value it probes. The served rows and
///         their wall-clock floors are pinned immutably at construction
///         (caller-independent inputs, rule 4); hosts cross-check the pin at
///         registration via `pinnedWallClockFloorSeconds`. The genuine-observation
///         analog of the genuine-failure rule (rule 5): cadence is measured from
///         chain-supplied `block.number`/`block.timestamp` deltas over an enforced
///         minimum window, a sample can neither be shortened nor shaped by the
///         caller, and a candidate run demands a fresh finalized sample — so a
///         recordable failing run exists only when the candidate genuinely fails
///         to cover the pinned wall-clock floor at honestly observed cadence.
contract StreamCadenceProbe is IStreamTimeParameterProbe {
    /// @notice Schema version carried by every canonical probe-record event.
    uint16 public constant TIME_PARAMETER_PROBE_SCHEMA_VERSION = 1;

    /// @notice Planning floor for the sampling window ([LTA-GTP] definition
    ///         item 6): 1,000 blocks.
    uint64 public constant CADENCE_SAMPLE_FLOOR_BLOCKS = 1_000;

    /// @dev keccak256("6529STREAM_GTP_PROBE_RUN_V1") — probe-run id domain.
    bytes32 private constant _PROBE_RUN_DOMAIN_V1 = keccak256("6529STREAM_GTP_PROBE_RUN_V1");
    /// @dev keccak256("6529STREAM_GTP_PROBE_EVIDENCE_V1") — evidence commitment
    ///      domain for the observed-cadence measurement artifact.
    bytes32 private constant _PROBE_EVIDENCE_DOMAIN_V1 =
        keccak256("6529STREAM_GTP_PROBE_EVIDENCE_V1");

    struct ProbeRun {
        bytes32 probeRunId;
        bool passed;
        uint64 probedAtBlock;
    }

    struct PendingSample {
        uint64 startBlock;
        uint64 startTimestamp;
    }

    struct FinalizedSample {
        uint64 endBlock;
        uint64 blocksElapsed;
        uint64 secondsElapsed;
    }

    /// @notice The enforced sampling-window width in blocks, pinned at deployment
    ///         (at least `CADENCE_SAMPLE_FLOOR_BLOCKS`).
    uint64 public immutable sampleWindowBlocks;

    /// @notice Maximum age (blocks) of the finalized sample a candidate run may
    ///         consume, pinned at deployment.
    uint64 public immutable sampleMaxAgeBlocks;

    mapping(bytes32 => uint64) private _pinnedWallClockFloorSeconds;
    mapping(bytes32 => mapping(uint256 => ProbeRun)) private _runs;
    PendingSample private _pendingSample;
    FinalizedSample private _latestSample;
    uint256 private _runNonce;

    /// @notice Diagnostic record of a finalized cadence observation.
    event CadenceSampleRecorded(
        uint16 schemaVersion, uint64 endBlock, uint64 blocksElapsed, uint64 secondsElapsed
    );

    /// @notice Reverts when the probe is constructed with invalid pins.
    error StreamCadenceProbeInvalidConfig();
    /// @notice Reverts for a parameterId this probe does not serve.
    error StreamCadenceProbeUnknownParameter(bytes32 parameterId);
    /// @notice Reverts when the candidate block count is zero.
    error StreamCadenceProbeInvalidCandidate();
    /// @notice Reverts when a sample is started while one is still maturing.
    error StreamCadenceProbeSampleAlreadyPending(uint64 startBlock);
    /// @notice Reverts when finalization is attempted with no pending sample.
    error StreamCadenceProbeNoPendingSample();
    /// @notice Reverts when the pending sample has not yet spanned the enforced
    ///         window — a shortened observation can never record.
    error StreamCadenceProbeSampleImmature(uint64 startBlock, uint64 requiredEndBlock);
    /// @notice Reverts when a candidate run has no finalized sample to consume.
    error StreamCadenceProbeNoSample();
    /// @notice Reverts when the finalized sample is older than
    ///         `sampleMaxAgeBlocks` — a candidate verdict must reflect fresh
    ///         observed cadence.
    error StreamCadenceProbeSampleStale(uint64 endBlock, uint64 sampleMaxAgeBlocks);
    /// @notice Reverts when the observed window carries no elapsed wall-clock time.
    error StreamCadenceProbeDegenerateSample();

    /// @param parameterNames Bare [LTA-GTP] constant names of every served row;
    ///        ids derive as `keccak256("6529STREAM_GTP_" || name)`.
    /// @param wallClockFloorSecondsByRow The pinned wall-clock floor per row,
    ///        index-aligned with `parameterNames`.
    /// @param sampleWindowBlocks_ Sampling-window width (>= 1,000 blocks).
    /// @param sampleMaxAgeBlocks_ Maximum sample age consumable by candidate runs
    ///        (>= the window width).
    constructor(
        string[] memory parameterNames,
        uint64[] memory wallClockFloorSecondsByRow,
        uint64 sampleWindowBlocks_,
        uint64 sampleMaxAgeBlocks_
    ) {
        if (
            parameterNames.length == 0
                || parameterNames.length != wallClockFloorSecondsByRow.length
                || sampleWindowBlocks_ < CADENCE_SAMPLE_FLOOR_BLOCKS
                || sampleMaxAgeBlocks_ < sampleWindowBlocks_
        ) {
            revert StreamCadenceProbeInvalidConfig();
        }
        sampleWindowBlocks = sampleWindowBlocks_;
        sampleMaxAgeBlocks = sampleMaxAgeBlocks_;

        uint256 count = parameterNames.length;
        for (uint256 i = 0; i < count; ) {
            if (bytes(parameterNames[i]).length == 0 || wallClockFloorSecondsByRow[i] == 0) {
                revert StreamCadenceProbeInvalidConfig();
            }
            bytes32 parameterId =
                keccak256(abi.encodePacked("6529STREAM_GTP_", parameterNames[i]));
            if (_pinnedWallClockFloorSeconds[parameterId] != 0) {
                revert StreamCadenceProbeInvalidConfig();
            }
            _pinnedWallClockFloorSeconds[parameterId] = wallClockFloorSecondsByRow[i];
            unchecked {
                ++i;
            }
        }
    }

    // ---------------------------------------------------------------------
    // Cadence observation (permissionless)
    // ---------------------------------------------------------------------

    /// @notice Opens a cadence observation window at the current block.
    /// @dev    Reverts while a window is still maturing so an observation can
    ///         never be restarted (and thereby shortened or delayed) mid-flight;
    ///         once mature, anyone can finalize it and start the next one.
    function startCadenceSample() external {
        if (_pendingSample.startBlock != 0) {
            revert StreamCadenceProbeSampleAlreadyPending(_pendingSample.startBlock);
        }
        _pendingSample = PendingSample({
            startBlock: uint64(block.number),
            startTimestamp: uint64(block.timestamp)
        });
    }

    /// @notice Finalizes the pending observation once it has spanned at least
    ///         `sampleWindowBlocks`, recording observed cadence onchain.
    function finalizeCadenceSample() external {
        PendingSample memory pending = _pendingSample;
        if (pending.startBlock == 0) {
            revert StreamCadenceProbeNoPendingSample();
        }
        uint64 requiredEndBlock = pending.startBlock + sampleWindowBlocks;
        if (block.number < requiredEndBlock) {
            revert StreamCadenceProbeSampleImmature(pending.startBlock, requiredEndBlock);
        }
        uint64 blocksElapsed = uint64(block.number) - pending.startBlock;
        uint64 secondsElapsed = uint64(block.timestamp) - pending.startTimestamp;
        if (secondsElapsed == 0) {
            revert StreamCadenceProbeDegenerateSample();
        }
        _latestSample = FinalizedSample({
            endBlock: uint64(block.number),
            blocksElapsed: blocksElapsed,
            secondsElapsed: secondsElapsed
        });
        delete _pendingSample;
        emit CadenceSampleRecorded(
            TIME_PARAMETER_PROBE_SCHEMA_VERSION, uint64(block.number), blocksElapsed, secondsElapsed
        );
    }

    /// @notice The latest finalized cadence observation.
    function latestCadenceSample()
        external
        view
        returns (uint64 endBlock, uint64 blocksElapsed, uint64 secondsElapsed)
    {
        FinalizedSample memory sample = _latestSample;
        return (sample.endBlock, sample.blocksElapsed, sample.secondsElapsed);
    }

    // ---------------------------------------------------------------------
    // Candidate runs (permissionless)
    // ---------------------------------------------------------------------

    /// @notice Records pass/fail for `candidateBlocks` against the served
    ///         parameter's pinned wall-clock floor at the freshly observed
    ///         cadence: passes iff
    ///         `candidateBlocks * secondsElapsed >= wallClockFloorSeconds * blocksElapsed`.
    function recordCadenceRun(bytes32 parameterId, uint256 candidateBlocks)
        external
        returns (bytes32 probeRunId, bool passed)
    {
        uint64 wallClockFloor = _pinnedWallClockFloorSeconds[parameterId];
        if (wallClockFloor == 0) {
            revert StreamCadenceProbeUnknownParameter(parameterId);
        }
        if (candidateBlocks == 0) {
            revert StreamCadenceProbeInvalidCandidate();
        }
        FinalizedSample memory sample = _latestSample;
        if (sample.endBlock == 0) {
            revert StreamCadenceProbeNoSample();
        }
        if (block.number - sample.endBlock > sampleMaxAgeBlocks) {
            revert StreamCadenceProbeSampleStale(sample.endBlock, sampleMaxAgeBlocks);
        }

        // Cross-multiplied coverage check — no division, no precision loss:
        // candidate covers the floor iff
        // candidateBlocks * (secondsElapsed / blocksElapsed) >= wallClockFloor.
        passed = candidateBlocks * uint256(sample.secondsElapsed)
            >= uint256(wallClockFloor) * uint256(sample.blocksElapsed);

        unchecked {
            _runNonce += 1;
        }
        probeRunId = keccak256(
            abi.encode(
                _PROBE_RUN_DOMAIN_V1,
                block.chainid,
                address(this),
                parameterId,
                candidateBlocks,
                block.number,
                _runNonce
            )
        );
        _runs[parameterId][candidateBlocks] = ProbeRun({
            probeRunId: probeRunId,
            passed: passed,
            probedAtBlock: uint64(block.number)
        });

        emit TimeParameterProbed(
            TIME_PARAMETER_PROBE_SCHEMA_VERSION,
            parameterId,
            probeRunId,
            passed,
            candidateBlocks,
            keccak256(
                abi.encode(
                    _PROBE_EVIDENCE_DOMAIN_V1,
                    parameterId,
                    candidateBlocks,
                    passed,
                    sample.endBlock,
                    sample.blocksElapsed,
                    sample.secondsElapsed
                )
            )
        );
    }

    // ---------------------------------------------------------------------
    // Canonical reads
    // ---------------------------------------------------------------------

    /// @inheritdoc IStreamTimeParameterProbe
    function lastProbeRun(bytes32 parameterId, uint256 probedValue)
        external
        view
        override
        returns (bytes32 probeRunId, bool passed, uint64 probedAtBlock)
    {
        ProbeRun storage run = _runs[parameterId][probedValue];
        return (run.probeRunId, run.passed, run.probedAtBlock);
    }

    /// @inheritdoc IStreamTimeParameterProbe
    function pinnedWallClockFloorSeconds(bytes32 parameterId) external view override returns (uint64) {
        return _pinnedWallClockFloorSeconds[parameterId];
    }
}
