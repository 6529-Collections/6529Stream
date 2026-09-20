// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Optional executor-policy rotation with bounded predecessor authorization continuity.
/// @dev Additive ERC165 capability; the permanent IStreamMintManager ID is unchanged.
interface IStreamMintPolicyGrace {
    /// @notice Changes one executor and registers the new policy with predecessor grace.
    /// @dev Requires the Manager owner and current Artist consent for the resulting policy.
    ///      The governed deployment admits this exact selector as DELAYED_LOOSENING.
    ///      Only the immediately preceding policy is retained, through the inclusive deadline.
    ///      Ledger rejects deadlines more than 30 days from execution; a past deadline is
    ///      already expired. Zero clears grace on a real policy rotation. An unchanged executor
    ///      with nonzero grace reverts; with zero it is a no-op and does not clear existing grace.
    ///      Current executor admission, counters, gates and Artist authority still apply.
    function setPhaseExecutorWithGrace(
        uint256 collectionId,
        bytes32 phaseId,
        address executor,
        bool allowed,
        uint64 graceUntil
    ) external;
}
